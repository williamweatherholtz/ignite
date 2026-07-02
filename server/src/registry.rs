//! Vault discovery + the per-vault warm index registry.
//!
//! Runtime-mutable (sprint 10): vaults live behind an `RwLock` so create/remove can
//! add/drop entries while the app holds `Arc<VaultRegistry>`. `get` returns an `Arc`
//! snapshot (cheap clone under a read lock). Dropping an entry releases its
//! `Arc<VaultIndex>`; the notify watcher stops when the last `Arc` is gone.

use crate::index::VaultIndex;
use rayon::prelude::*;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};

/// Holds a warm [`VaultIndex`] for every known vault, keyed by vault name.
#[derive(Debug, Default)]
pub struct VaultRegistry {
    vaults: RwLock<HashMap<String, Arc<VaultIndex>>>,
    vault_root: PathBuf,
}

impl VaultRegistry {
    /// Discover vaults as the immediate subdirectories of `vault_root` and build a warm
    /// live index for each, in PARALLEL across vaults (dCritiqueEfficiency).
    pub fn discover(vault_root: &Path) -> Self {
        let dirs: Vec<(String, PathBuf)> = match std::fs::read_dir(vault_root) {
            Ok(entries) => entries
                .flatten()
                .filter(|e| e.file_type().map(|t| t.is_dir()).unwrap_or(false))
                .map(|e| (e.file_name().to_string_lossy().into_owned(), e.path()))
                .collect(),
            Err(_) => Vec::new(),
        };
        let vaults: HashMap<String, Arc<VaultIndex>> = dirs
            .into_par_iter()
            .map(|(name, path)| (name, Arc::new(VaultIndex::build_live(&path))))
            .collect();
        Self {
            vaults: RwLock::new(vaults),
            vault_root: vault_root.to_path_buf(),
        }
    }

    /// The warm index for `name` (an `Arc` snapshot), or `None` if there is no such vault.
    pub fn get(&self, name: &str) -> Option<Arc<VaultIndex>> {
        self.vaults.read().unwrap().get(name).cloned()
    }

    /// Whether a vault named `name` currently exists.
    pub fn contains(&self, name: &str) -> bool {
        self.vaults.read().unwrap().contains_key(name)
    }

    /// All known vault names (sorted).
    pub fn names(&self) -> Vec<String> {
        let mut names: Vec<String> = self.vaults.read().unwrap().keys().cloned().collect();
        names.sort();
        names
    }

    /// The vault root directory (parent of all vault dirs) — used by create/rename.
    pub fn vault_root(&self) -> &Path {
        &self.vault_root
    }

    /// Build a live index for the vault at `path` and register it under `name`.
    pub fn insert_vault(&self, name: String, path: &Path) {
        let idx = Arc::new(VaultIndex::build_live(path));
        self.vaults.write().unwrap().insert(name, idx);
    }

    /// Drop the vault's index (its watcher stops once the last `Arc` is released).
    /// Returns whether an entry was present.
    pub fn remove_vault(&self, name: &str) -> bool {
        self.vaults.write().unwrap().remove(name).is_some()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::tempdir;

    #[test]
    fn discovers_vault_subdirs_and_indexes_them() {
        let dir = tempdir().unwrap();
        let vroot = dir.path();
        fs::create_dir(vroot.join("Games")).unwrap();
        fs::write(vroot.join("Games").join("a.md"), b"hi").unwrap();
        fs::create_dir(vroot.join("Journal")).unwrap();
        // a stray file at vault-root is NOT a vault
        fs::write(vroot.join("README.txt"), b"x").unwrap();

        let reg = VaultRegistry::discover(vroot);

        assert!(reg.get("Games").is_some());
        assert!(reg.get("Journal").is_some());
        assert!(reg.get("README.txt").is_none(), "a file is not a vault");
        assert!(reg.get("Missing").is_none());
        assert_eq!(
            reg.names(),
            vec!["Games".to_string(), "Journal".to_string()]
        );

        // the discovered index is warm and has the vault's file
        assert!(reg.get("Games").unwrap().tree().contains_key("a.md"));
    }

    #[test]
    fn insert_and_remove_mutate_the_registry() {
        let dir = tempdir().unwrap();
        let vroot = dir.path();
        let reg = VaultRegistry::discover(vroot);
        assert!(reg.names().is_empty());

        fs::create_dir(vroot.join("New")).unwrap();
        reg.insert_vault("New".to_string(), &vroot.join("New"));
        assert!(reg.get("New").is_some());
        assert_eq!(reg.names(), vec!["New".to_string()]);

        assert!(reg.remove_vault("New"));
        assert!(reg.get("New").is_none());
        assert!(!reg.remove_vault("New"), "second remove is a no-op");
    }
}
