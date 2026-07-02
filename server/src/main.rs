//! Ignite server binary — discovers vaults under VAULT_ROOT, builds warm indexes,
//! and serves the (growing) Ignis-compatible HTTP surface on PORT.

use ignite_server::{app::app, registry::VaultRegistry};
use std::net::SocketAddr;
use std::path::Path;
use std::sync::Arc;

#[tokio::main]
async fn main() {
    // Structured, leveled logging. Level via RUST_LOG (default "info"); per-request lines come
    // from the log_requests middleware. e.g. RUST_LOG=ignite_server=debug,tower_http=debug
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info")),
        )
        .with_target(false)
        .init();

    let vault_root = std::env::var("VAULT_ROOT").unwrap_or_else(|_| "./vaults".to_string());
    let port: u16 = std::env::var("PORT")
        .ok()
        .and_then(|p| p.parse().ok())
        .unwrap_or(8080);

    let registry = Arc::new(VaultRegistry::discover(Path::new(&vault_root)));
    let resolved = Path::new(&vault_root)
        .canonicalize()
        .map(|p| p.display().to_string())
        .unwrap_or_else(|_| vault_root.clone());
    let names = registry.names();
    if names.is_empty() {
        tracing::warn!(
            vault_root = %vault_root, resolved = %resolved,
            "no vaults found. Each immediate SUBDIRECTORY of VAULT_ROOT is a vault. In Docker, \
             check your /vaults bind mount: VAULTS_DIR must point at a directory that CONTAINS your \
             vault folders (and be shared with Docker Desktop). The browser will show a 'no vaults' page."
        );
    } else {
        tracing::info!(
            count = names.len(), vault_root = %vault_root, resolved = %resolved, vaults = ?names,
            "indexed vaults"
        );
    }

    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .unwrap_or_else(|e| panic!("cannot bind {addr}: {e}"));
    tracing::info!(%addr, "ignite-server listening");
    axum::serve(listener, app(registry))
        .await
        .expect("server error");
}
