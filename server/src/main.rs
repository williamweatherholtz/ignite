//! Ignite server binary — discovers vaults under VAULT_ROOT, builds warm indexes,
//! and serves the (growing) Ignis-compatible HTTP surface on PORT.

use ignite_server::{app::app, registry::VaultRegistry};
use std::net::SocketAddr;
use std::path::Path;
use std::sync::Arc;

#[tokio::main]
async fn main() {
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
        eprintln!(
            "[ignite] WARNING: no vaults found under VAULT_ROOT='{vault_root}' (resolved: {resolved}). \
             Each immediate SUBDIRECTORY of VAULT_ROOT is a vault. In Docker, check your /vaults bind \
             mount: VAULTS_DIR must point at a directory that CONTAINS your vault folders (and be shared \
             with Docker Desktop). The browser will show a 'no vaults' page until one is mounted."
        );
    } else {
        println!(
            "[ignite] indexed {} vault(s) from {vault_root} (resolved: {resolved}): {names:?}",
            names.len()
        );
    }

    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .unwrap_or_else(|e| panic!("cannot bind {addr}: {e}"));
    println!("ignite-server listening on http://{addr}");
    axum::serve(listener, app(registry))
        .await
        .expect("server error");
}
