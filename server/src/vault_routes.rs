//! Read-only vault routes + the /api/bootstrap cold-start bundle, wire-compatible with
//! Ignis c9656b8 (vault.js / bootstrap.js). Vault id == name == the vault directory name;
//! `path` is the on-disk vault path; `platform` is node-style (process.platform); `version`
//! is OBSIDIAN_VERSION. Served from the warm registry/index; no registry mutation here
//! (create/rename/remove is a later sprint).

use crate::index::tree_to_value;
use crate::registry::VaultRegistry;
use axum::{
    extract::{Query, State},
    http::StatusCode,
    response::Json,
    routing::{delete, get, post},
    Router,
};
use serde::Deserialize;
use serde_json::{json, Value};
use std::sync::Arc;

/// Node's `process.platform` value for this OS (Ignis emits process.platform).
fn node_platform() -> &'static str {
    match std::env::consts::OS {
        "macos" => "darwin",
        "windows" => "win32",
        other => other, // "linux", "freebsd", ...
    }
}

/// The Obsidian version Ignis reports (config.obsidianVersion); env-overridable.
fn obsidian_version() -> String {
    std::env::var("OBSIDIAN_VERSION").unwrap_or_else(|_| "1.12.7".to_string())
}

#[derive(Deserialize)]
struct VaultQuery {
    vault: Option<String>,
}

/// `{id, name, path}` for a vault — the vault-list / vaultList entry shape.
fn vault_summary(reg: &VaultRegistry, name: &str) -> Value {
    let path = reg
        .get(name)
        .map(|i| i.root().to_string_lossy().into_owned())
        .unwrap_or_default();
    json!({ "id": name, "name": name, "path": path })
}

/// `{id, name, path, platform, version}` — the vault/info + bootstrap.vault shape.
fn vault_info_value(reg: &VaultRegistry, name: &str) -> Value {
    let path = reg
        .get(name)
        .map(|i| i.root().to_string_lossy().into_owned())
        .unwrap_or_default();
    json!({
        "id": name,
        "name": name,
        "path": path,
        "platform": node_platform(),
        "version": obsidian_version(),
    })
}

/// The default vault id when `?vault` is omitted: the first discovered vault.
fn default_vault(reg: &VaultRegistry) -> Option<String> {
    reg.names().into_iter().next()
}

async fn vault_list(State(reg): State<Arc<VaultRegistry>>) -> Json<Value> {
    let list: Vec<Value> = reg.names().iter().map(|n| vault_summary(&reg, n)).collect();
    Json(json!(list))
}

async fn vault_info(
    State(reg): State<Arc<VaultRegistry>>,
    Query(q): Query<VaultQuery>,
) -> Result<Json<Value>, StatusCode> {
    let name = q
        .vault
        .or_else(|| default_vault(&reg))
        .ok_or(StatusCode::NOT_FOUND)?;
    if reg.get(&name).is_none() {
        return Err(StatusCode::NOT_FOUND);
    }
    Ok(Json(vault_info_value(&reg, &name)))
}

async fn bootstrap(
    State(reg): State<Arc<VaultRegistry>>,
    Query(q): Query<VaultQuery>,
) -> Result<Json<Value>, StatusCode> {
    let name = q
        .vault
        .or_else(|| default_vault(&reg))
        .ok_or(StatusCode::NOT_FOUND)?;
    let index = reg.get(&name).ok_or(StatusCode::NOT_FOUND)?;
    let vault_list: Vec<Value> = reg.names().iter().map(|n| vault_summary(&reg, n)).collect();
    Ok(Json(json!({
        "vault": vault_info_value(&reg, &name),
        "vaultList": vault_list,
        "tree": tree_to_value(&index.tree()),
        "plugins": [],
        "virtualPlugins": [],
        "settings": {
            "contentCacheBytes": 52_428_800,   // 50 MiB  (Ignis DEFAULTS)
            "inputCacheBytes": 209_715_200,     // 200 MiB
            "inputCacheTtlMs": 300_000,         // 5 min
            "directFetchHosts": [],
        },
    })))
}

#[derive(Deserialize)]
struct CreateBody {
    name: String,
}

#[derive(Deserialize)]
struct RenameBody {
    vault: String,
    name: String,
}

type VaultErr = (StatusCode, Json<Value>);

fn err(status: StatusCode, msg: &str) -> VaultErr {
    (status, Json(json!({ "error": msg })))
}

/// Vault-name rules, matching Ignis vault.js `isValidVaultName` / `WINDOWS_RESERVED`
/// (`/^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\..*)?$/i`): non-empty, <= 255 chars, no
/// `/ \ : * ? " < > |`, no leading '.', not a Windows reserved device name.
fn is_valid_vault_name(name: &str) -> bool {
    if name.is_empty() || name.len() > 255 {
        return false;
    }
    if name
        .chars()
        .any(|c| matches!(c, '/' | '\\' | ':' | '*' | '?' | '"' | '<' | '>' | '|'))
    {
        return false;
    }
    if name.starts_with('.') {
        return false;
    }
    let base = name.split('.').next().unwrap_or(name).to_ascii_lowercase();
    let reserved = matches!(base.as_str(), "con" | "prn" | "aux" | "nul")
        || (base.len() == 4
            && (base.starts_with("com") || base.starts_with("lpt"))
            && matches!(base.as_bytes()[3], b'1'..=b'9'));
    !reserved
}

/// POST /api/vault/create { name } — create <vaultRoot>/<name> + .obsidian, register it live.
async fn vault_create(
    State(reg): State<Arc<VaultRegistry>>,
    Json(body): Json<CreateBody>,
) -> Result<Json<Value>, VaultErr> {
    let name = body.name;
    if !is_valid_vault_name(&name) {
        return Err(err(StatusCode::BAD_REQUEST, "Invalid vault name"));
    }
    let path = reg.vault_root().join(&name);
    match std::fs::create_dir(&path) {
        Ok(()) => {}
        Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => {
            return Err(err(StatusCode::CONFLICT, "Vault already exists"));
        }
        Err(_) => return Err(err(StatusCode::INTERNAL_SERVER_ERROR, "create failed")),
    }
    if std::fs::create_dir(path.join(".obsidian")).is_err() {
        return Err(err(StatusCode::INTERNAL_SERVER_ERROR, "create failed"));
    }
    reg.insert_vault(name.clone(), &path);
    Ok(Json(
        json!({ "ok": true, "id": name, "path": path.to_string_lossy() }),
    ))
}

/// POST /api/vault/rename { vault, name } — rename the dir on disk + re-key the registry.
async fn vault_rename(
    State(reg): State<Arc<VaultRegistry>>,
    Json(body): Json<RenameBody>,
) -> Result<Json<Value>, VaultErr> {
    let RenameBody { vault, name } = body;
    if !is_valid_vault_name(&name) {
        return Err(err(StatusCode::BAD_REQUEST, "Invalid vault name"));
    }
    if !reg.contains(&vault) {
        return Err(err(StatusCode::NOT_FOUND, "Vault not found"));
    }
    let old_path = reg.vault_root().join(&vault);
    let new_path = reg.vault_root().join(&name);
    if new_path.exists() {
        return Err(err(
            StatusCode::CONFLICT,
            "A vault with that name already exists",
        ));
    }
    if std::fs::rename(&old_path, &new_path).is_err() {
        return Err(err(StatusCode::INTERNAL_SERVER_ERROR, "rename failed"));
    }
    reg.remove_vault(&vault);
    reg.insert_vault(name.clone(), &new_path);
    Ok(Json(
        json!({ "ok": true, "id": name, "path": new_path.to_string_lossy() }),
    ))
}

/// DELETE /api/vault/remove?vault=<id> — recursively delete the dir + drop the live index.
async fn vault_remove(
    State(reg): State<Arc<VaultRegistry>>,
    Query(q): Query<VaultQuery>,
) -> Result<Json<Value>, VaultErr> {
    let name = q
        .vault
        .ok_or_else(|| err(StatusCode::NOT_FOUND, "Vault not found"))?;
    if !reg.contains(&name) {
        return Err(err(StatusCode::NOT_FOUND, "Vault not found"));
    }
    let path = reg.vault_root().join(&name);
    if std::fs::remove_dir_all(&path).is_err() {
        return Err(err(StatusCode::INTERNAL_SERVER_ERROR, "remove failed"));
    }
    reg.remove_vault(&name);
    Ok(Json(json!({ "ok": true })))
}

/// The vault + cold-start routes, to be `.merge()`d into the app router.
pub fn routes() -> Router<Arc<VaultRegistry>> {
    Router::new()
        .route("/api/vault/list", get(vault_list))
        .route("/api/vault/info", get(vault_info))
        .route("/api/bootstrap", get(bootstrap))
        .route("/api/vault/create", post(vault_create))
        .route("/api/vault/rename", post(vault_rename))
        .route("/api/vault/remove", delete(vault_remove))
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::body::Body;
    use axum::http::Request;
    use tower::ServiceExt;

    fn router_over(vroot: &std::path::Path) -> (Arc<VaultRegistry>, Router) {
        let reg = Arc::new(VaultRegistry::discover(vroot));
        let router = Router::new().merge(routes()).with_state(reg.clone());
        (reg, router)
    }

    async fn send(router: Router, method: &str, uri: &str, body: &str) -> (StatusCode, Value) {
        let req = Request::builder()
            .method(method)
            .uri(uri)
            .header("content-type", "application/json")
            .body(Body::from(body.to_string()))
            .unwrap();
        let resp = router.oneshot(req).await.unwrap();
        let status = resp.status();
        let bytes = axum::body::to_bytes(resp.into_body(), usize::MAX)
            .await
            .unwrap();
        (
            status,
            serde_json::from_slice(&bytes).unwrap_or(Value::Null),
        )
    }

    #[tokio::test]
    async fn create_makes_a_live_vault() {
        let dir = tempfile::tempdir().unwrap();
        let (reg, router) = router_over(dir.path());
        let (status, body) = send(
            router,
            "POST",
            "/api/vault/create",
            r#"{"name":"NewVault"}"#,
        )
        .await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(body["ok"], true);
        assert_eq!(body["id"], "NewVault");
        assert!(dir.path().join("NewVault").join(".obsidian").is_dir());
        assert!(reg.get("NewVault").is_some(), "registered as a live vault");
        assert!(reg.names().contains(&"NewVault".to_string()));
    }

    #[tokio::test]
    async fn create_rejects_invalid_names() {
        for bad in [
            "../evil", ".hidden", "CON", "com1", "a/b", "a:b", "", "lpt9",
        ] {
            let dir = tempfile::tempdir().unwrap();
            let (_reg, router) = router_over(dir.path());
            let payload = format!(r#"{{"name":{}}}"#, serde_json::to_string(bad).unwrap());
            let (status, _) = send(router, "POST", "/api/vault/create", &payload).await;
            assert_eq!(
                status,
                StatusCode::BAD_REQUEST,
                "name {bad:?} must be rejected"
            );
        }
    }

    #[tokio::test]
    async fn create_duplicate_conflicts() {
        let dir = tempfile::tempdir().unwrap();
        let (_reg, router) = router_over(dir.path());
        let (s1, _) = send(
            router.clone(),
            "POST",
            "/api/vault/create",
            r#"{"name":"V"}"#,
        )
        .await;
        assert_eq!(s1, StatusCode::OK);
        let (s2, _) = send(router, "POST", "/api/vault/create", r#"{"name":"V"}"#).await;
        assert_eq!(s2, StatusCode::CONFLICT);
    }

    #[tokio::test]
    async fn rename_moves_the_vault() {
        let dir = tempfile::tempdir().unwrap();
        let (reg, router) = router_over(dir.path());
        send(
            router.clone(),
            "POST",
            "/api/vault/create",
            r#"{"name":"V"}"#,
        )
        .await;
        let (status, body) = send(
            router,
            "POST",
            "/api/vault/rename",
            r#"{"vault":"V","name":"W"}"#,
        )
        .await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(body["id"], "W");
        assert!(reg.get("V").is_none(), "old name dropped");
        assert!(reg.get("W").is_some(), "new name present");
        assert!(dir.path().join("W").is_dir() && !dir.path().join("V").exists());
    }

    #[tokio::test]
    async fn remove_deletes_the_vault() {
        let dir = tempfile::tempdir().unwrap();
        let (reg, router) = router_over(dir.path());
        send(
            router.clone(),
            "POST",
            "/api/vault/create",
            r#"{"name":"V"}"#,
        )
        .await;
        let (status, body) = send(router, "DELETE", "/api/vault/remove?vault=V", "").await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(body["ok"], true);
        assert!(reg.get("V").is_none());
        assert!(!dir.path().join("V").exists(), "dir deleted");
    }

    #[tokio::test]
    async fn rename_and_remove_unknown_vault_404() {
        let dir = tempfile::tempdir().unwrap();
        let (_reg, router) = router_over(dir.path());
        let (s1, _) = send(
            router.clone(),
            "POST",
            "/api/vault/rename",
            r#"{"vault":"Nope","name":"W"}"#,
        )
        .await;
        assert_eq!(s1, StatusCode::NOT_FOUND);
        let (s2, _) = send(router, "DELETE", "/api/vault/remove?vault=Nope", "").await;
        assert_eq!(s2, StatusCode::NOT_FOUND);
    }
}
