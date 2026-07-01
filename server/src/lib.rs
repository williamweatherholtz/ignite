//! Ignite server library — a performant Rust drop-in for the Ignis self-hosted
//! Obsidian server. Wire-compatible with Ignis c9656b8.

pub mod app;
pub mod fs_routes;
pub mod index;
pub mod registry;
pub mod vault_routes;
pub mod ws;

pub use index::{build_tree, tree_to_value, NodeType, Tree, TreeEntry, VaultIndex};
pub use registry::VaultRegistry;
