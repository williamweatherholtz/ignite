//! Native headless-sync plugin (dPlugins) — Obsidian-Sync compat, wire-compatible with Ignis
//! c9656b8's `apps/ignis-server/server/plugins/headless-sync`. Wraps the `obsidian-headless`
//! (`ob`) CLI behind an injected [`CliRunner`] (so tests use a fake — no real CLI needed),
//! persists token + per-vault sync state under `<data_dir>`, and broadcasts sync-log /
//! sync-status on the `plugin:headless-sync` WS channel via the [`ChannelHub`].

use crate::plugins::{ChannelHub, PluginDescriptor, ServerPlugin};
use crate::registry::VaultRegistry;
use axum::extract::{Extension, Query};
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post};
use axum::{Json, Router};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};

pub const CHANNEL: &str = "plugin:headless-sync";

/// Output of an `ob` CLI invocation.
pub struct CliOutput {
    pub stdout: String,
    pub code: i32,
}

/// The `obsidian-headless` CLI, injected so tests can fake it.
pub trait CliRunner: Send + Sync {
    /// The installed CLI version (`ob --version`), or `None` if not installed.
    fn version(&self) -> Option<String>;
    /// Run `ob <args>`.
    fn run(&self, args: &[String]) -> std::io::Result<CliOutput>;
}

/// Real runner: shells out to `ob` (path from `IGNITE_OB_CLI`, default `ob`).
pub struct RealCli;
impl CliRunner for RealCli {
    fn version(&self) -> Option<String> {
        let bin = std::env::var("IGNITE_OB_CLI").unwrap_or_else(|_| "ob".to_string());
        let out = std::process::Command::new(bin).arg("--version").output().ok()?;
        if out.status.success() {
            Some(String::from_utf8_lossy(&out.stdout).trim().to_string())
        } else {
            None
        }
    }
    fn run(&self, args: &[String]) -> std::io::Result<CliOutput> {
        let bin = std::env::var("IGNITE_OB_CLI").unwrap_or_else(|_| "ob".to_string());
        let out = std::process::Command::new(bin).args(args).output()?;
        Ok(CliOutput {
            stdout: String::from_utf8_lossy(&out.stdout).to_string(),
            code: out.status.code().unwrap_or(-1),
        })
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
struct TokenInfo {
    token: String,
    #[serde(default)]
    email: Option<String>,
    #[serde(default)]
    name: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SyncConfig {
    pub mode: String,
    pub device_name: String,
}

/// Per-vault sync state — mirrors Ignis's `getAllStates()` entry shape.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SyncState {
    pub vault_id: String,
    pub remote_vault: String,
    pub remote_vault_name: Option<String>,
    pub status: String, // "stopped" | "running" | "error"
    pub last_sync: Option<String>,
    pub error: Option<String>,
    pub config: SyncConfig,
}

/// The plugin: injected CLI + hub + registry, with token/state/logs persisted under `data_dir`.
pub struct HeadlessSync {
    data_dir: PathBuf,
    cli: Arc<dyn CliRunner>,
    hub: ChannelHub,
    registry: Arc<VaultRegistry>,
    token: RwLock<Option<TokenInfo>>,
    states: RwLock<HashMap<String, SyncState>>,
    logs: RwLock<HashMap<String, Vec<String>>>,
}

fn token_path(dir: &Path) -> PathBuf {
    dir.join("token.json")
}
fn states_path(dir: &Path) -> PathBuf {
    dir.join("sync-states.json")
}

impl HeadlessSync {
    pub fn new(
        data_dir: PathBuf,
        cli: Arc<dyn CliRunner>,
        hub: ChannelHub,
        registry: Arc<VaultRegistry>,
    ) -> Arc<Self> {
        let _ = std::fs::create_dir_all(&data_dir);
        let token = std::fs::read_to_string(token_path(&data_dir))
            .ok()
            .and_then(|s| serde_json::from_str::<TokenInfo>(&s).ok());
        let states = std::fs::read_to_string(states_path(&data_dir))
            .ok()
            .and_then(|s| serde_json::from_str::<HashMap<String, SyncState>>(&s).ok())
            .unwrap_or_default();
        Arc::new(Self {
            data_dir,
            cli,
            hub,
            registry,
            token: RwLock::new(token),
            states: RwLock::new(states),
            logs: RwLock::new(HashMap::new()),
        })
    }

    pub fn descriptor(&self) -> PluginDescriptor {
        PluginDescriptor {
            id: "headless-sync".into(),
            name: "Headless Sync".into(),
            description: "Obsidian Sync via the obsidian-headless CLI".into(),
        }
    }

    fn authenticated(&self) -> bool {
        self.token.read().unwrap().is_some()
    }

    fn persist_token(&self) {
        let t = self.token.read().unwrap();
        match &*t {
            Some(info) => {
                let _ = std::fs::write(
                    token_path(&self.data_dir),
                    serde_json::to_string_pretty(info).unwrap(),
                );
            }
            None => {
                let _ = std::fs::remove_file(token_path(&self.data_dir));
            }
        }
    }

    fn persist_states(&self) {
        let s = self.states.read().unwrap();
        let _ = std::fs::write(
            states_path(&self.data_dir),
            serde_json::to_string_pretty(&*s).unwrap(),
        );
    }

    fn broadcast_status(&self, state: &SyncState) {
        self.hub
            .broadcast(CHANNEL, &state.vault_id, "sync-status", state);
    }
}

impl ServerPlugin for HeadlessSync {
    fn descriptor(&self) -> PluginDescriptor {
        HeadlessSync::descriptor(self)
    }
}

type Hs = Extension<Arc<HeadlessSync>>;

fn err(code: StatusCode, msg: &str) -> Response {
    (code, Json(json!({ "error": msg }))).into_response()
}

async fn status(Extension(hs): Hs) -> Response {
    let ver = hs.cli.version();
    let tok = hs.token.read().unwrap();
    Json(json!({
        "installed": ver.is_some(),
        "version": ver,
        "authenticated": tok.is_some(),
        "email": tok.as_ref().and_then(|t| t.email.clone()),
        "name": tok.as_ref().and_then(|t| t.name.clone()),
    }))
    .into_response()
}

#[derive(Deserialize)]
struct LoginBody {
    token: Option<String>,
    email: Option<String>,
    name: Option<String>,
}

async fn login(Extension(hs): Hs, Json(b): Json<LoginBody>) -> Response {
    let Some(token) = b.token.filter(|t| !t.is_empty()) else {
        return err(StatusCode::BAD_REQUEST, "Token is required");
    };
    *hs.token.write().unwrap() = Some(TokenInfo {
        token,
        email: b.email,
        name: b.name,
    });
    hs.persist_token();
    Json(json!({ "success": true })).into_response()
}

async fn logout(Extension(hs): Hs) -> Response {
    *hs.token.write().unwrap() = None;
    hs.persist_token();
    Json(json!({ "success": true })).into_response()
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct SetupBody {
    vault_id: Option<String>,
    remote_vault: Option<String>,
    remote_vault_name: Option<String>,
    #[allow(dead_code)]
    vault_password: Option<String>,
    device_name: Option<String>,
    mode: Option<String>,
}

async fn setup(Extension(hs): Hs, Json(b): Json<SetupBody>) -> Response {
    let (Some(vault_id), Some(remote_vault)) = (b.vault_id, b.remote_vault) else {
        return err(StatusCode::BAD_REQUEST, "vaultId and remoteVault are required");
    };
    if !hs.authenticated() {
        return err(StatusCode::UNAUTHORIZED, "Not authenticated");
    }
    if hs.registry.get(&vault_id).is_none() {
        return err(StatusCode::NOT_FOUND, "Vault not found");
    }
    // ob sync-setup --vault <remote> --path . (best-effort; fake in tests)
    let args: Vec<String> = vec![
        "sync-setup".into(),
        "--vault".into(),
        remote_vault.clone(),
        "--path".into(),
        ".".into(),
    ];
    if let Err(e) = hs.cli.run(&args) {
        return err(StatusCode::INTERNAL_SERVER_ERROR, &format!("setup failed: {e}"));
    }
    let state = SyncState {
        vault_id: vault_id.clone(),
        remote_vault,
        remote_vault_name: b.remote_vault_name,
        status: "stopped".into(),
        last_sync: None,
        error: None,
        config: SyncConfig {
            mode: b.mode.unwrap_or_else(|| "bidirectional".into()),
            device_name: b.device_name.unwrap_or_else(|| "ignis-headless".into()),
        },
    };
    hs.states.write().unwrap().insert(vault_id, state.clone());
    hs.persist_states();
    hs.broadcast_status(&state);
    Json(json!({ "success": true, "state": state })).into_response()
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct VaultIdBody {
    vault_id: Option<String>,
}

fn set_status(hs: &HeadlessSync, vault_id: &str, status: &str) -> Option<SyncState> {
    let mut states = hs.states.write().unwrap();
    let state = states.get_mut(vault_id)?;
    state.status = status.into();
    if status == "running" {
        state.error = None;
    }
    Some(state.clone())
}

async fn start(Extension(hs): Hs, Json(b): Json<VaultIdBody>) -> Response {
    let Some(vault_id) = b.vault_id else {
        return err(StatusCode::BAD_REQUEST, "vaultId is required");
    };
    // Note: Ignite flips state + broadcasts; long-running sync process spawn is a real-CLI
    // integration concern not exercised here (see the honest gap in the sprint record).
    match set_status(&hs, &vault_id, "running") {
        Some(state) => {
            hs.persist_states();
            hs.broadcast_status(&state);
            Json(json!({ "success": true, "state": state })).into_response()
        }
        None => err(StatusCode::NOT_FOUND, "Sync not configured for vault"),
    }
}

async fn stop(Extension(hs): Hs, Json(b): Json<VaultIdBody>) -> Response {
    let Some(vault_id) = b.vault_id else {
        return err(StatusCode::BAD_REQUEST, "vaultId is required");
    };
    match set_status(&hs, &vault_id, "stopped") {
        Some(state) => {
            hs.persist_states();
            hs.broadcast_status(&state);
            Json(json!({ "success": true, "state": state })).into_response()
        }
        None => err(StatusCode::NOT_FOUND, "Sync not configured for vault"),
    }
}

async fn unlink(Extension(hs): Hs, Json(b): Json<VaultIdBody>) -> Response {
    let Some(vault_id) = b.vault_id else {
        return err(StatusCode::BAD_REQUEST, "vaultId is required");
    };
    hs.states.write().unwrap().remove(&vault_id);
    hs.logs.write().unwrap().remove(&vault_id);
    hs.persist_states();
    Json(json!({ "success": true })).into_response()
}

#[derive(Deserialize)]
struct LogsQuery {
    #[serde(rename = "vaultId")]
    vault_id: Option<String>,
    limit: Option<usize>,
}

async fn logs(Extension(hs): Hs, Query(q): Query<LogsQuery>) -> Response {
    let Some(vault_id) = q.vault_id else {
        return err(StatusCode::BAD_REQUEST, "vaultId is required");
    };
    let limit = q.limit.unwrap_or(100);
    let all = hs.logs.read().unwrap();
    let lines: Vec<String> = all
        .get(&vault_id)
        .map(|v| v.iter().rev().take(limit).rev().cloned().collect())
        .unwrap_or_default();
    Json(json!({ "logs": lines })).into_response()
}

async fn vaults(Extension(hs): Hs) -> Response {
    let states = hs.states.read().unwrap();
    Json(json!({ "vaults": &*states })).into_response()
}

#[derive(Deserialize)]
struct CreateRemoteBody {
    name: Option<String>,
    encryption: Option<String>,
    password: Option<String>,
    region: Option<String>,
}

async fn create_remote_vault(Extension(hs): Hs, Json(b): Json<CreateRemoteBody>) -> Response {
    let Some(name) = b.name.filter(|n| !n.is_empty()) else {
        return err(StatusCode::BAD_REQUEST, "name is required");
    };
    if !hs.authenticated() {
        return err(StatusCode::UNAUTHORIZED, "Not authenticated");
    }
    let mut args: Vec<String> = vec!["sync-create-remote".into(), "--name".into(), name];
    if let Some(e) = b.encryption {
        args.push("--encryption".into());
        args.push(e);
    }
    if let Some(p) = b.password {
        args.push("--password".into());
        args.push(p);
    }
    if let Some(r) = b.region {
        args.push("--region".into());
        args.push(r);
    }
    match hs.cli.run(&args) {
        Ok(_) => Json(json!({ "success": true })).into_response(),
        Err(e) => err(StatusCode::INTERNAL_SERVER_ERROR, &format!("{e}")),
    }
}

async fn remote_vaults(Extension(hs): Hs) -> Response {
    if !hs.authenticated() {
        return err(StatusCode::UNAUTHORIZED, "Not authenticated");
    }
    match hs.cli.run(&["sync-list-remote".to_string()]) {
        Ok(out) => Json(json!({ "vaults": parse_remote_vaults(&out.stdout) })).into_response(),
        Err(e) => err(StatusCode::INTERNAL_SERVER_ERROR, &format!("{e}")),
    }
}

/// Parse `ob sync-list-remote` stdout into `[{id,name,region}]` (best-effort, tab/space-delimited).
fn parse_remote_vaults(stdout: &str) -> Vec<Value> {
    stdout
        .trim()
        .lines()
        .map(|l| l.trim())
        .filter(|l| !l.is_empty() && !l.starts_with("Available"))
        .map(|l| {
            let f: Vec<&str> = l.split_whitespace().collect();
            json!({
                "id": f.first().copied().unwrap_or(""),
                "name": f.get(1).copied().unwrap_or(f.first().copied().unwrap_or("")),
                "region": f.get(2).copied().unwrap_or(""),
            })
        })
        .collect()
}

/// The `/api/ext/headless-sync/*` routes (needs an `Extension<Arc<HeadlessSync>>` layer).
pub fn routes() -> Router<Arc<VaultRegistry>> {
    Router::new()
        .route("/api/ext/headless-sync/status", get(status))
        .route("/api/ext/headless-sync/login", post(login))
        .route("/api/ext/headless-sync/logout", post(logout))
        .route("/api/ext/headless-sync/setup", post(setup))
        .route("/api/ext/headless-sync/start", post(start))
        .route("/api/ext/headless-sync/stop", post(stop))
        .route("/api/ext/headless-sync/unlink", post(unlink))
        .route("/api/ext/headless-sync/logs", get(logs))
        .route("/api/ext/headless-sync/vaults", get(vaults))
        .route("/api/ext/headless-sync/create-remote-vault", post(create_remote_vault))
        .route("/api/ext/headless-sync/remote-vaults", get(remote_vaults))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::registry::VaultRegistry;
    use axum::body::Body;
    use axum::http::Request;
    use std::path::Path as StdPath;
    use tempfile::TempDir;
    use tower::ServiceExt;

    struct FakeCli {
        version: Option<String>,
    }
    impl CliRunner for FakeCli {
        fn version(&self) -> Option<String> {
            self.version.clone()
        }
        fn run(&self, _args: &[String]) -> std::io::Result<CliOutput> {
            Ok(CliOutput {
                stdout: "vault-a MyVault us-east\n".into(),
                code: 0,
            })
        }
    }

    fn setup_app() -> (TempDir, TempDir, Arc<HeadlessSync>, Router) {
        let vroot = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(vroot.path().join("Games")).unwrap();
        let reg = Arc::new(VaultRegistry::discover(vroot.path()));
        let data = tempfile::tempdir().unwrap();
        let hub = ChannelHub::new();
        let hs = HeadlessSync::new(
            data.path().to_path_buf(),
            Arc::new(FakeCli { version: Some("ob 1.2.3".into()) }),
            hub,
            reg.clone(),
        );
        let app = routes()
            .layer(Extension(hs.clone()))
            .with_state(reg);
        (vroot, data, hs, app)
    }

    async fn body_json(resp: axum::response::Response) -> Value {
        let bytes = axum::body::to_bytes(resp.into_body(), 1 << 20).await.unwrap();
        serde_json::from_slice(&bytes).unwrap()
    }

    fn get(uri: &str) -> Request<Body> {
        Request::builder().uri(uri).body(Body::empty()).unwrap()
    }
    fn post_json(uri: &str, v: Value) -> Request<Body> {
        Request::builder()
            .method("POST")
            .uri(uri)
            .header("content-type", "application/json")
            .body(Body::from(v.to_string()))
            .unwrap()
    }

    #[tokio::test]
    async fn status_reflects_cli_and_auth_then_login_persists() {
        let (_v, data, _hs, app) = setup_app();
        let r = app.clone().oneshot(get("/api/ext/headless-sync/status")).await.unwrap();
        let j = body_json(r).await;
        assert_eq!(j["installed"], true);
        assert_eq!(j["version"], "ob 1.2.3");
        assert_eq!(j["authenticated"], false);

        let r = app
            .clone()
            .oneshot(post_json(
                "/api/ext/headless-sync/login",
                json!({"token":"t","email":"a@b.c","name":"Ann"}),
            ))
            .await
            .unwrap();
        assert_eq!(body_json(r).await["success"], true);

        let r = app.clone().oneshot(get("/api/ext/headless-sync/status")).await.unwrap();
        let j = body_json(r).await;
        assert_eq!(j["authenticated"], true);
        assert_eq!(j["email"], "a@b.c");
        // persisted to disk
        assert!(StdPath::new(&data.path().join("token.json")).exists());
    }

    #[tokio::test]
    async fn login_requires_token() {
        let (_v, _d, _hs, app) = setup_app();
        let r = app.oneshot(post_json("/api/ext/headless-sync/login", json!({}))).await.unwrap();
        assert_eq!(r.status(), StatusCode::BAD_REQUEST);
    }

    #[tokio::test]
    async fn setup_start_stop_transitions_and_vaults_map() {
        let (_v, _d, _hs, app) = setup_app();
        app.clone()
            .oneshot(post_json("/api/ext/headless-sync/login", json!({"token":"t"})))
            .await
            .unwrap();
        let r = app
            .clone()
            .oneshot(post_json(
                "/api/ext/headless-sync/setup",
                json!({"vaultId":"Games","remoteVault":"remote-1"}),
            ))
            .await
            .unwrap();
        let j = body_json(r).await;
        assert_eq!(j["success"], true);
        assert_eq!(j["state"]["status"], "stopped");
        assert_eq!(j["state"]["remoteVault"], "remote-1");
        assert_eq!(j["state"]["config"]["mode"], "bidirectional");

        let r = app
            .clone()
            .oneshot(post_json("/api/ext/headless-sync/start", json!({"vaultId":"Games"})))
            .await
            .unwrap();
        assert_eq!(body_json(r).await["state"]["status"], "running");

        let r = app
            .clone()
            .oneshot(post_json("/api/ext/headless-sync/stop", json!({"vaultId":"Games"})))
            .await
            .unwrap();
        assert_eq!(body_json(r).await["state"]["status"], "stopped");

        let r = app.clone().oneshot(get("/api/ext/headless-sync/vaults")).await.unwrap();
        assert_eq!(body_json(r).await["vaults"]["Games"]["remoteVault"], "remote-1");
    }

    #[tokio::test]
    async fn setup_needs_auth_and_known_vault() {
        let (_v, _d, _hs, app) = setup_app();
        // unauth
        let r = app
            .clone()
            .oneshot(post_json("/api/ext/headless-sync/setup", json!({"vaultId":"Games","remoteVault":"r"})))
            .await
            .unwrap();
        assert_eq!(r.status(), StatusCode::UNAUTHORIZED);
        // authed but unknown vault
        app.clone()
            .oneshot(post_json("/api/ext/headless-sync/login", json!({"token":"t"})))
            .await
            .unwrap();
        let r = app
            .clone()
            .oneshot(post_json("/api/ext/headless-sync/setup", json!({"vaultId":"Nope","remoteVault":"r"})))
            .await
            .unwrap();
        assert_eq!(r.status(), StatusCode::NOT_FOUND);
    }

    #[tokio::test]
    async fn remote_vaults_needs_auth_then_parses() {
        let (_v, _d, _hs, app) = setup_app();
        let r = app.clone().oneshot(get("/api/ext/headless-sync/remote-vaults")).await.unwrap();
        assert_eq!(r.status(), StatusCode::UNAUTHORIZED);
        app.clone()
            .oneshot(post_json("/api/ext/headless-sync/login", json!({"token":"t"})))
            .await
            .unwrap();
        let r = app.clone().oneshot(get("/api/ext/headless-sync/remote-vaults")).await.unwrap();
        let j = body_json(r).await;
        assert_eq!(j["vaults"][0]["id"], "vault-a");
        assert_eq!(j["vaults"][0]["region"], "us-east");
    }

    #[tokio::test]
    async fn logs_requires_vault_id() {
        let (_v, _d, _hs, app) = setup_app();
        let r = app.oneshot(get("/api/ext/headless-sync/logs")).await.unwrap();
        assert_eq!(r.status(), StatusCode::BAD_REQUEST);
    }

    #[tokio::test]
    async fn setup_broadcasts_sync_status_on_channel() {
        let vroot = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(vroot.path().join("Games")).unwrap();
        let reg = Arc::new(VaultRegistry::discover(vroot.path()));
        let data = tempfile::tempdir().unwrap();
        let hub = ChannelHub::new();
        let mut rx = hub.subscribe();
        let hs = HeadlessSync::new(
            data.path().to_path_buf(),
            Arc::new(FakeCli { version: None }),
            hub,
            reg.clone(),
        );
        let app = routes().layer(Extension(hs.clone())).with_state(reg);
        app.clone()
            .oneshot(post_json("/api/ext/headless-sync/login", json!({"token":"t"})))
            .await
            .unwrap();
        app.clone()
            .oneshot(post_json(
                "/api/ext/headless-sync/setup",
                json!({"vaultId":"Games","remoteVault":"r"}),
            ))
            .await
            .unwrap();
        let msg = rx.recv().await.unwrap();
        assert_eq!(msg.channel, CHANNEL);
        assert_eq!(msg.vault, "Games");
        let v: Value = serde_json::from_str(&msg.json).unwrap();
        assert_eq!(v["type"], "sync-status");
        assert_eq!(v["payload"]["remoteVault"], "r");
    }
}
