//! The axum HTTP surface. Grows route by route; sprint 1 serves GET /api/fs/tree.

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
use std::sync::Arc;

#[derive(Deserialize)]
struct TreeQuery {
    vault: Option<String>,
}

/// GET /api/fs/tree?vault=<name> — serve the vault's warm tree as Ignis JSON.
/// 400 if `vault` is missing, 404 if the vault is unknown.
async fn fs_tree(
    State(reg): State<Arc<VaultRegistry>>,
    Query(q): Query<TreeQuery>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let vault = q.vault.ok_or(StatusCode::BAD_REQUEST)?;
    let index = reg.get(&vault).ok_or(StatusCode::NOT_FOUND)?;
    Ok(Json(tree_to_value(&index.tree())))
}

/// Build the application router over a discovered [`VaultRegistry`].
pub fn app(reg: Arc<VaultRegistry>) -> Router {
    Router::new()
        .route("/api/fs/tree", get(fs_tree))
        .route("/ws", get(crate::ws::ws_handler))
        .merge(crate::fs_routes::routes())
        .merge(crate::vault_routes::routes())
        .layer(tower_http::compression::CompressionLayer::new())
        .with_state(reg)
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::body::Body;
    use axum::http::Request;
    use std::fs;
    use tempfile::tempdir;
    use tower::ServiceExt; // for `oneshot`

    fn registry_with_one_vault() -> (tempfile::TempDir, Arc<VaultRegistry>) {
        let dir = tempdir().unwrap();
        let vroot = dir.path();
        fs::create_dir(vroot.join("Games")).unwrap();
        fs::write(vroot.join("Games").join("a.md"), b"hello").unwrap(); // 5 bytes
        let reg = Arc::new(VaultRegistry::discover(vroot));
        (dir, reg)
    }

    #[tokio::test]
    async fn fs_tree_returns_ignis_json_for_a_known_vault() {
        let (_dir, reg) = registry_with_one_vault();
        let resp = app(reg)
            .oneshot(
                Request::builder()
                    .uri("/api/fs/tree?vault=Games")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(resp.status(), StatusCode::OK);
        let bytes = axum::body::to_bytes(resp.into_body(), usize::MAX)
            .await
            .unwrap();
        let v: serde_json::Value = serde_json::from_slice(&bytes).unwrap();
        assert_eq!(v["a.md"]["type"], "file");
        assert_eq!(v["a.md"]["size"], 5);
    }

    #[tokio::test]
    async fn fs_tree_404_for_unknown_vault() {
        let (_dir, reg) = registry_with_one_vault();
        let resp = app(reg)
            .oneshot(
                Request::builder()
                    .uri("/api/fs/tree?vault=Nope")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(resp.status(), StatusCode::NOT_FOUND);
    }

    #[tokio::test]
    async fn fs_tree_400_when_vault_param_missing() {
        let (_dir, reg) = registry_with_one_vault();
        let resp = app(reg)
            .oneshot(
                Request::builder()
                    .uri("/api/fs/tree")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(resp.status(), StatusCode::BAD_REQUEST);
    }

    async fn fetch_tree(reg: &Arc<VaultRegistry>) -> serde_json::Value {
        let resp = app(Arc::clone(reg))
            .oneshot(
                Request::builder()
                    .uri("/api/fs/tree?vault=Games")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let bytes = axum::body::to_bytes(resp.into_body(), usize::MAX)
            .await
            .unwrap();
        serde_json::from_slice(&bytes).unwrap()
    }

    // ---- WebSocket live-sync integration tests (sprint 6) ----

    use futures_util::{SinkExt, StreamExt};
    use tokio_tungstenite::tungstenite::Message as WsMsg;

    /// Bind the app to an ephemeral port and serve it in the background; return the addr.
    async fn spawn_server(reg: Arc<VaultRegistry>) -> std::net::SocketAddr {
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        let application = app(reg);
        tokio::spawn(async move {
            axum::serve(listener, application).await.unwrap();
        });
        addr
    }

    /// Read text messages until one satisfies `pred` (or ~5s timeout). Tolerates pings.
    async fn read_event<S>(
        ws: &mut S,
        pred: impl Fn(&serde_json::Value) -> bool,
    ) -> Option<serde_json::Value>
    where
        S: StreamExt<Item = Result<WsMsg, tokio_tungstenite::tungstenite::Error>> + Unpin,
    {
        let fut = async {
            while let Some(Ok(msg)) = ws.next().await {
                if let WsMsg::Text(t) = msg {
                    if let Ok(v) = serde_json::from_str::<serde_json::Value>(t.as_str()) {
                        if pred(&v) {
                            return Some(v);
                        }
                    }
                }
            }
            None
        };
        tokio::time::timeout(std::time::Duration::from_secs(5), fut)
            .await
            .ok()
            .flatten()
    }

    #[tokio::test]
    async fn ws_streams_a_created_event() {
        let (dir, reg) = registry_with_one_vault();
        let addr = spawn_server(reg).await;
        let (mut ws, _) = tokio_tungstenite::connect_async(format!("ws://{addr}/ws?vault=Games"))
            .await
            .expect("ws handshake to a known vault should succeed");

        std::fs::write(dir.path().join("Games").join("z.md"), b"live!").unwrap();

        let ev = read_event(&mut ws, |v| v["type"] == "created" && v["path"] == "z.md")
            .await
            .expect("expected a {type:created, path:z.md} event");
        assert_eq!(ev["stat"]["size"], 5);
        assert!(ev["stat"]["mtime"].is_number());
        assert!(ev["stat"]["ctime"].is_number());
    }

    #[tokio::test]
    async fn ws_rejects_unknown_vault() {
        let (_dir, reg) = registry_with_one_vault();
        let addr = spawn_server(reg).await;
        let res = tokio_tungstenite::connect_async(format!("ws://{addr}/ws?vault=Nope")).await;
        assert!(
            res.is_err(),
            "handshake to an unknown vault must be rejected"
        );
    }

    #[tokio::test]
    async fn ws_streams_a_modified_event() {
        let (dir, reg) = registry_with_one_vault();
        let addr = spawn_server(reg).await;
        let (mut ws, _) = tokio_tungstenite::connect_async(format!("ws://{addr}/ws?vault=Games"))
            .await
            .unwrap();

        std::fs::write(
            dir.path().join("Games").join("a.md"),
            b"much longer content",
        )
        .unwrap();
        let ev = read_event(&mut ws, |v| v["type"] == "modified" && v["path"] == "a.md")
            .await
            .expect("expected a modified event for a.md");
        assert_eq!(ev["stat"]["size"], 19);
    }

    #[tokio::test]
    async fn ws_streams_a_deleted_event() {
        let (dir, reg) = registry_with_one_vault();
        let addr = spawn_server(reg).await;
        let (mut ws, _) = tokio_tungstenite::connect_async(format!("ws://{addr}/ws?vault=Games"))
            .await
            .unwrap();

        std::fs::remove_file(dir.path().join("Games").join("a.md")).unwrap();
        let ev = read_event(&mut ws, |v| v["type"] == "deleted" && v["path"] == "a.md")
            .await
            .expect("expected a deleted event for a.md");
        assert!(ev.get("stat").is_none(), "deleted carries no stat");
    }

    #[tokio::test]
    async fn ws_streams_a_folder_created_event() {
        let (dir, reg) = registry_with_one_vault();
        let addr = spawn_server(reg).await;
        let (mut ws, _) = tokio_tungstenite::connect_async(format!("ws://{addr}/ws?vault=Games"))
            .await
            .unwrap();

        std::fs::create_dir(dir.path().join("Games").join("newdir")).unwrap();
        let ev = read_event(&mut ws, |v| {
            v["type"] == "folder-created" && v["path"] == "newdir"
        })
        .await
        .expect("expected a folder-created event for newdir");
        assert!(ev.get("stat").is_none(), "folder-created carries no stat");
    }

    #[tokio::test]
    async fn ws_broadcasts_to_two_clients() {
        let (dir, reg) = registry_with_one_vault();
        let addr = spawn_server(reg).await;
        let (mut a, _) = tokio_tungstenite::connect_async(format!("ws://{addr}/ws?vault=Games"))
            .await
            .unwrap();
        let (mut b, _) = tokio_tungstenite::connect_async(format!("ws://{addr}/ws?vault=Games"))
            .await
            .unwrap();

        std::fs::write(dir.path().join("Games").join("z.md"), b"hi").unwrap();
        let ea = read_event(&mut a, |v| v["path"] == "z.md").await;
        let eb = read_event(&mut b, |v| v["path"] == "z.md").await;
        assert!(
            ea.is_some() && eb.is_some(),
            "both clients on the vault must receive the broadcast"
        );
    }

    #[tokio::test]
    async fn ws_accepts_subscribe_channel_and_keeps_streaming() {
        let (dir, reg) = registry_with_one_vault();
        let addr = spawn_server(reg).await;
        let (mut ws, _) = tokio_tungstenite::connect_async(format!("ws://{addr}/ws?vault=Games"))
            .await
            .unwrap();

        ws.send(WsMsg::Text(
            r#"{"type":"subscribe-channel","channel":"plugin:headless-sync"}"#.to_owned(),
        ))
        .await
        .unwrap();

        std::fs::write(dir.path().join("Games").join("z.md"), b"hi").unwrap();
        let ev = read_event(&mut ws, |v| v["path"] == "z.md").await;
        assert!(
            ev.is_some(),
            "a subscribe-channel control message must be accepted and not break the stream"
        );
    }

    #[tokio::test]
    async fn fs_tree_reflects_a_live_change() {
        // registry uses the LIVE build, so a file created in the vault after startup
        // should surface through the handler once the watcher applies it.
        let (dir, reg) = registry_with_one_vault();
        assert!(fetch_tree(&reg).await.get("z.md").is_none());

        fs::write(dir.path().join("Games").join("z.md"), b"live!").unwrap();

        let mut ok = false;
        for _ in 0..60 {
            if fetch_tree(&reg).await.get("z.md").is_some() {
                ok = true;
                break;
            }
            std::thread::sleep(std::time::Duration::from_millis(50));
        }
        assert!(ok, "GET /api/fs/tree did not reflect a live-created file");
    }

    // ---- vault + bootstrap routes (sprint 8) ----

    async fn get_json(reg: &Arc<VaultRegistry>, uri: &str) -> (StatusCode, serde_json::Value) {
        let resp = app(Arc::clone(reg))
            .oneshot(Request::builder().uri(uri).body(Body::empty()).unwrap())
            .await
            .unwrap();
        let status = resp.status();
        let bytes = axum::body::to_bytes(resp.into_body(), usize::MAX)
            .await
            .unwrap();
        let v = serde_json::from_slice(&bytes).unwrap_or(serde_json::Value::Null);
        (status, v)
    }

    #[tokio::test]
    async fn vault_list_returns_discovered_vaults() {
        let (_dir, reg) = registry_with_one_vault();
        let (status, v) = get_json(&reg, "/api/vault/list").await;
        assert_eq!(status, StatusCode::OK);
        let arr = v.as_array().expect("vault/list is an array");
        assert_eq!(arr.len(), 1);
        assert_eq!(arr[0]["id"], "Games");
        assert_eq!(arr[0]["name"], "Games");
        assert!(arr[0]["path"].as_str().unwrap().contains("Games"));
    }

    #[tokio::test]
    async fn vault_info_returns_five_fields() {
        let (_dir, reg) = registry_with_one_vault();
        let (status, v) = get_json(&reg, "/api/vault/info?vault=Games").await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(v["id"], "Games");
        assert_eq!(v["name"], "Games");
        assert!(v["path"].is_string());
        assert!(v["platform"].is_string());
        assert!(v["version"].is_string());
    }

    #[tokio::test]
    async fn vault_info_defaults_to_first_when_vault_omitted() {
        let (_dir, reg) = registry_with_one_vault();
        let (status, v) = get_json(&reg, "/api/vault/info").await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(v["id"], "Games");
    }

    #[tokio::test]
    async fn vault_info_unknown_vault_404() {
        let (_dir, reg) = registry_with_one_vault();
        let (status, _v) = get_json(&reg, "/api/vault/info?vault=Nope").await;
        assert_eq!(status, StatusCode::NOT_FOUND);
    }

    #[tokio::test]
    async fn bootstrap_returns_the_full_bundle() {
        let (_dir, reg) = registry_with_one_vault();
        let (status, v) = get_json(&reg, "/api/bootstrap?vault=Games").await;
        assert_eq!(status, StatusCode::OK);
        // all six top-level keys
        assert_eq!(v["vault"]["id"], "Games");
        assert!(v["vault"]["platform"].is_string());
        assert!(v["vault"]["version"].is_string());
        assert!(v["vaultList"].is_array());
        assert_eq!(v["vaultList"][0]["name"], "Games");
        // the live tree, Ignis shape
        assert_eq!(v["tree"]["a.md"]["type"], "file");
        assert_eq!(v["tree"]["a.md"]["size"], 5);
        assert!(v["plugins"].is_array() && v["plugins"].as_array().unwrap().is_empty());
        assert!(v["virtualPlugins"].is_array());
        // settings keys (Ignis defaults)
        assert_eq!(v["settings"]["contentCacheBytes"], 52_428_800);
        assert_eq!(v["settings"]["inputCacheBytes"], 209_715_200);
        assert_eq!(v["settings"]["inputCacheTtlMs"], 300_000);
        assert!(v["settings"]["directFetchHosts"].is_array());
    }

    #[tokio::test]
    async fn bootstrap_unknown_vault_404() {
        let (_dir, reg) = registry_with_one_vault();
        let (status, _v) = get_json(&reg, "/api/bootstrap?vault=Nope").await;
        assert_eq!(status, StatusCode::NOT_FOUND);
    }
}
