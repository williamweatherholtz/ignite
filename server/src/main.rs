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
    println!(
        "ignite-server: indexed {} vault(s) from {vault_root}: {:?}",
        registry.names().len(),
        registry.names()
    );

    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .unwrap_or_else(|e| panic!("cannot bind {addr}: {e}"));
    println!("ignite-server listening on http://{addr}");
    axum::serve(listener, app(registry))
        .await
        .expect("server error");
}
