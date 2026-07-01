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
    routing::get,
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

/// The read-only vault + cold-start routes, to be `.merge()`d into the app router.
pub fn routes() -> Router<Arc<VaultRegistry>> {
    Router::new()
        .route("/api/vault/list", get(vault_list))
        .route("/api/vault/info", get(vault_info))
        .route("/api/bootstrap", get(bootstrap))
}
