//! /api/settings (+ /api/version, /api/plugins) — runtime config, wire-compatible with
//! Ignis c9656b8 (settings.js/version.js/plugins.js). State is injected via Extension so
//! tests don't race on process env / a shared settings file.

use crate::registry::VaultRegistry;
use axum::{
    extract::Path,
    http::StatusCode,
    response::{IntoResponse, Json, Response},
    routing::{get, post},
    Extension, Router,
};
use serde::{Deserialize, Serialize};
use crate::plugins::PluginDescriptor;
use serde_json::{json, Value};
use std::path::PathBuf;
use std::sync::{Arc, RwLock};

/// Hard ceiling for request bodies (Ignis settings.js MAX_BODY_BACKSTOP = 500 MB).
const MAX_BODY_BACKSTOP: u64 = 500 * 1024 * 1024;
const PROXY_MODES: [&str; 3] = ["any", "allowlist", "disabled"];
/// Keys that come from env only and are never persisted to the settings file (Ignis ENV_ONLY_KEYS).
const ENV_ONLY_KEYS: [&str; 2] = ["wsOrigins", "proxyAllowPrivate"];

/// Effective server settings. Field order/names match Ignis settings.js DEFAULTS.
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Settings {
    pub content_cache_bytes: u64,
    pub input_cache_bytes: u64,
    pub input_cache_ttl_ms: u64,
    /// NO-OP in Ignite: write-coalescing was retired (dCritiqueCorrectness #3). Kept as a
    /// wire-compat key with Ignis's default so the client sees the expected shape.
    pub write_coalesce_ms: u64,
    pub max_body_bytes: u64,
    pub proxy_mode: String,
    pub proxy_allowlist: Vec<String>,
    pub direct_fetch_hosts: Vec<String>,
    pub ws_origins: Vec<String>,
    pub proxy_allow_private: Vec<String>,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            content_cache_bytes: 50 * 1024 * 1024,
            input_cache_bytes: 200 * 1024 * 1024,
            input_cache_ttl_ms: 5 * 60 * 1000,
            write_coalesce_ms: 0,
            max_body_bytes: 50 * 1024 * 1024,
            proxy_mode: "any".to_string(),
            proxy_allowlist: vec![],
            direct_fetch_hosts: vec![],
            ws_origins: vec![],
            proxy_allow_private: vec![],
        }
    }
}

fn parse_list(raw: &str) -> Vec<String> {
    raw.split(',')
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .map(|s| s.to_string())
        .collect()
}

/// Injectable settings state: the effective settings + the data_root the file persists under.
#[derive(Clone)]
pub struct SettingsState {
    inner: Arc<RwLock<Settings>>,
    data_root: PathBuf,
}

impl SettingsState {
    pub fn from_env() -> Self {
        let data_root =
            PathBuf::from(std::env::var("DATA_ROOT").unwrap_or_else(|_| "./data".to_string()));
        Self::load(data_root)
    }

    /// Build the effective settings: DEFAULTS <- env overrides <- persisted file.
    pub fn load(data_root: PathBuf) -> Self {
        let mut s = Settings::default();
        if let Ok(v) = std::env::var("WRITE_COALESCE_MS") {
            if let Ok(n) = v.parse::<u64>() {
                s.write_coalesce_ms = n;
            }
        }
        if let Ok(v) = std::env::var("WS_ORIGINS") {
            s.ws_origins = parse_list(&v);
        }
        if let Ok(v) = std::env::var("PROXY_ALLOW_PRIVATE_HOSTS") {
            s.proxy_allow_private = parse_list(&v);
        }
        if let Ok(txt) = std::fs::read_to_string(data_root.join("server-settings.json")) {
            if let Ok(parsed) = serde_json::from_str::<Value>(&txt) {
                apply_persisted(&mut s, &parsed);
            }
        }
        Self {
            inner: Arc::new(RwLock::new(s)),
            data_root,
        }
    }

    fn snapshot(&self) -> Settings {
        self.inner.read().unwrap().clone()
    }
}

/// Apply the known, non-env-only keys from a parsed settings file onto `s`.
fn apply_persisted(s: &mut Settings, parsed: &Value) {
    // reuse the validated merge, ignoring errors (a hand-edited file shouldn't crash startup)
    let _ = merge_clean(s, parsed);
}

/// Validate + merge a partial settings object into `s`. Returns Err(message) on the first
/// invalid field (matches Ignis settings.js validate()). Env-only keys are ignored.
fn merge_clean(s: &mut Settings, body: &Value) -> Result<(), String> {
    let obj = body.as_object().ok_or("body must be an object")?;

    if let Some(v) = obj.get("proxyMode") {
        let m = v.as_str().unwrap_or("");
        if !PROXY_MODES.contains(&m) {
            return Err(format!(
                "proxyMode must be one of: {}",
                PROXY_MODES.join(", ")
            ));
        }
        s.proxy_mode = m.to_string();
    }

    for key in [
        "contentCacheBytes",
        "inputCacheBytes",
        "inputCacheTtlMs",
        "writeCoalesceMs",
        "maxBodyBytes",
    ] {
        let Some(v) = obj.get(key) else { continue };
        let n = v
            .as_u64()
            .ok_or_else(|| format!("{key} must be a non-negative integer"))?;
        if key == "maxBodyBytes" && !(1..=MAX_BODY_BACKSTOP).contains(&n) {
            return Err(format!(
                "maxBodyBytes must be between 1 and {MAX_BODY_BACKSTOP}"
            ));
        }
        match key {
            "contentCacheBytes" => s.content_cache_bytes = n,
            "inputCacheBytes" => s.input_cache_bytes = n,
            "inputCacheTtlMs" => s.input_cache_ttl_ms = n,
            "writeCoalesceMs" => s.write_coalesce_ms = n,
            "maxBodyBytes" => s.max_body_bytes = n,
            _ => {}
        }
    }

    for key in ["proxyAllowlist", "directFetchHosts"] {
        let Some(v) = obj.get(key) else { continue };
        let arr = v
            .as_array()
            .ok_or_else(|| format!("{key} must be an array of non-empty strings"))?;
        let mut out = Vec::new();
        for item in arr {
            let sv = item
                .as_str()
                .map(|x| x.trim())
                .filter(|x| !x.is_empty())
                .ok_or_else(|| format!("{key} must be an array of non-empty strings"))?;
            out.push(sv.to_string());
        }
        match key {
            "proxyAllowlist" => s.proxy_allowlist = out,
            "directFetchHosts" => s.direct_fetch_hosts = out,
            _ => {}
        }
    }

    Ok(())
}

/// Persist the non-env-only keys to <data_root>/server-settings.json.
fn persist(state: &SettingsState, s: &Settings) -> std::io::Result<()> {
    std::fs::create_dir_all(&state.data_root)?;
    let mut v = serde_json::to_value(s).unwrap();
    if let Some(obj) = v.as_object_mut() {
        for k in ENV_ONLY_KEYS {
            obj.remove(k);
        }
    }
    std::fs::write(
        state.data_root.join("server-settings.json"),
        serde_json::to_vec_pretty(&v).unwrap(),
    )
}

async fn get_settings(Extension(state): Extension<SettingsState>) -> Json<Settings> {
    Json(state.snapshot())
}

async fn post_settings(
    Extension(state): Extension<SettingsState>,
    Json(body): Json<Value>,
) -> Response {
    let mut s = state.snapshot();
    if let Err(e) = merge_clean(&mut s, &body) {
        return (StatusCode::BAD_REQUEST, Json(json!({ "error": e }))).into_response();
    }
    if let Err(e) = persist(&state, &s) {
        return (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({ "error": format!("failed to persist settings: {e}") })),
        )
            .into_response();
    }
    *state.inner.write().unwrap() = s.clone();
    Json(s).into_response()
}

async fn get_version() -> Json<Value> {
    let version =
        std::env::var("IGNITE_VERSION").unwrap_or_else(|_| env!("CARGO_PKG_VERSION").to_string());
    let build = std::env::var("IGNITE_BUILD").unwrap_or_else(|_| "dev".to_string());
    let obsidian_version =
        std::env::var("OBSIDIAN_VERSION").unwrap_or_else(|_| "1.12.7".to_string());
    Json(json!({ "version": version, "build": build, "obsidianVersion": obsidian_version }))
}

async fn get_plugins(plugins: Option<Extension<Arc<Vec<PluginDescriptor>>>>) -> Json<Value> {
    // Lists the registered ServerPlugins (injected by app.rs); empty if none are registered
    // (e.g. settings_routes' own tests build the router without the plugin layer).
    let Some(Extension(list)) = plugins else {
        return Json(json!([]));
    };
    let arr: Vec<Value> = list
        .iter()
        .map(|p| {
            json!({
                "id": p.id,
                "name": p.name,
                "description": p.description,
                "hasBundledPlugin": false,
                "bundledPluginId": Value::Null,
                "enabledVaults": [],
                "loaded": true,
            })
        })
        .collect();
    Json(Value::Array(arr))
}

/// Both enable/disable behave the same here: require a vault, then fail because no server
/// plugin is registered yet. Matches Ignis's shapes (400 "Missing vault ID" / error on unknown).
fn plugin_toggle(id: &str, body: &Value) -> Response {
    let has_vault = body
        .get("vault")
        .and_then(|v| v.as_str())
        .is_some_and(|s| !s.is_empty());
    if !has_vault {
        return (
            StatusCode::BAD_REQUEST,
            Json(json!({ "error": "Missing vault ID" })),
        )
            .into_response();
    }
    (
        StatusCode::BAD_REQUEST,
        Json(json!({ "error": format!("Unknown plugin: {id}") })),
    )
        .into_response()
}

async fn plugin_enable(Path(id): Path<String>, Json(body): Json<Value>) -> Response {
    plugin_toggle(&id, &body)
}

async fn plugin_disable(Path(id): Path<String>, Json(body): Json<Value>) -> Response {
    plugin_toggle(&id, &body)
}

pub fn routes() -> Router<Arc<VaultRegistry>> {
    Router::new()
        .route("/api/settings", get(get_settings).post(post_settings))
        .route("/api/version", get(get_version))
        .route("/api/plugins", get(get_plugins))
        .route("/api/plugins/{id}/enable", post(plugin_enable))
        .route("/api/plugins/{id}/disable", post(plugin_disable))
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::body::Body;
    use axum::http::Request;
    use tempfile::tempdir;
    use tower::ServiceExt;

    fn test_app(data_root: PathBuf) -> Router {
        let reg = Arc::new(VaultRegistry::discover(&data_root)); // empty reg is fine; settings ignores it
        Router::new()
            .merge(routes())
            .layer(Extension(SettingsState::load(data_root)))
            .with_state(reg)
    }

    async fn send(app: Router, req: Request<Body>) -> (StatusCode, Value) {
        let resp = app.oneshot(req).await.unwrap();
        let status = resp.status();
        let bytes = axum::body::to_bytes(resp.into_body(), usize::MAX)
            .await
            .unwrap();
        let v = serde_json::from_slice(&bytes).unwrap_or(Value::Null);
        (status, v)
    }

    #[tokio::test]
    async fn get_settings_returns_defaults() {
        let dir = tempdir().unwrap();
        let (status, v) = send(
            test_app(dir.path().to_path_buf()),
            Request::builder()
                .uri("/api/settings")
                .body(Body::empty())
                .unwrap(),
        )
        .await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(v["contentCacheBytes"], 52_428_800);
        assert_eq!(v["inputCacheBytes"], 209_715_200);
        assert_eq!(v["proxyMode"], "any");
        assert!(v["proxyAllowlist"].is_array());
        assert!(v["directFetchHosts"].is_array());
        assert_eq!(v["writeCoalesceMs"], 0);
    }

    #[tokio::test]
    async fn post_valid_persists_and_round_trips() {
        let dir = tempdir().unwrap();
        let root = dir.path().to_path_buf();
        let (status, v) = send(
            test_app(root.clone()),
            Request::builder()
                .method("POST")
                .uri("/api/settings")
                .header("content-type", "application/json")
                .body(Body::from(
                    r#"{"proxyMode":"disabled","maxBodyBytes":1234}"#,
                ))
                .unwrap(),
        )
        .await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(v["proxyMode"], "disabled");
        assert_eq!(v["maxBodyBytes"], 1234);
        // a fresh load from the same data_root reflects the persisted change
        let (_s, v2) = send(
            test_app(root),
            Request::builder()
                .uri("/api/settings")
                .body(Body::empty())
                .unwrap(),
        )
        .await;
        assert_eq!(v2["proxyMode"], "disabled");
        assert_eq!(v2["maxBodyBytes"], 1234);
    }

    #[tokio::test]
    async fn post_invalid_proxy_mode_400() {
        let dir = tempdir().unwrap();
        let (status, _v) = send(
            test_app(dir.path().to_path_buf()),
            Request::builder()
                .method("POST")
                .uri("/api/settings")
                .header("content-type", "application/json")
                .body(Body::from(r#"{"proxyMode":"bogus"}"#))
                .unwrap(),
        )
        .await;
        assert_eq!(status, StatusCode::BAD_REQUEST);
    }

    #[tokio::test]
    async fn post_invalid_maxbody_400() {
        let dir = tempdir().unwrap();
        let (status, _v) = send(
            test_app(dir.path().to_path_buf()),
            Request::builder()
                .method("POST")
                .uri("/api/settings")
                .header("content-type", "application/json")
                .body(Body::from(r#"{"maxBodyBytes":0}"#))
                .unwrap(),
        )
        .await;
        assert_eq!(status, StatusCode::BAD_REQUEST);
    }

    #[tokio::test]
    async fn version_has_three_fields() {
        let dir = tempdir().unwrap();
        let (status, v) = send(
            test_app(dir.path().to_path_buf()),
            Request::builder()
                .uri("/api/version")
                .body(Body::empty())
                .unwrap(),
        )
        .await;
        assert_eq!(status, StatusCode::OK);
        assert!(v["version"].is_string());
        assert!(v["build"].is_string());
        assert!(v["obsidianVersion"].is_string());
    }

    #[tokio::test]
    async fn plugins_is_empty_array() {
        let dir = tempdir().unwrap();
        let (status, v) = send(
            test_app(dir.path().to_path_buf()),
            Request::builder()
                .uri("/api/plugins")
                .body(Body::empty())
                .unwrap(),
        )
        .await;
        assert_eq!(status, StatusCode::OK);
        assert!(v.as_array().unwrap().is_empty());
    }

    #[tokio::test]
    async fn plugin_enable_unknown_is_error() {
        let dir = tempdir().unwrap();
        let (status, _v) = send(
            test_app(dir.path().to_path_buf()),
            Request::builder()
                .method("POST")
                .uri("/api/plugins/whatever/enable")
                .header("content-type", "application/json")
                .body(Body::from(r#"{"vault":"Games"}"#))
                .unwrap(),
        )
        .await;
        // no server plugins exist yet -> not ok
        assert_ne!(status, StatusCode::OK);
    }
}
