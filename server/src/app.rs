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
}
