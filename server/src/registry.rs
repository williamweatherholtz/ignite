//! Vault discovery + the per-vault warm index registry.

use crate::index::VaultIndex;
use rayon::prelude::*;
use std::collections::HashMap;
use std::path::Path;

/// Holds a warm [`VaultIndex`] for every discovered vault, keyed by vault name.
#[derive(Debug, Default)]
pub struct VaultRegistry {
    vaults: HashMap<String, VaultIndex>,
}

impl VaultRegistry {
    /// Discover vaults as the immediate subdirectories of `vault_root` and build
    /// a warm index for each. Non-directory entries are ignored. Indexes are built
    /// in PARALLEL across vaults (dCritiqueEfficiency): startup is bounded by the
    /// slowest single vault, not the sum — material for multi-vault setups on slow
    /// storage (e.g. ~6 vaults over a Docker bind mount).
    pub fn discover(vault_root: &Path) -> Self {
        let dirs: Vec<(String, std::path::PathBuf)> = match std::fs::read_dir(vault_root) {
            Ok(entries) => entries
                .flatten()
                .filter(|e| e.file_type().map(|t| t.is_dir()).unwrap_or(false))
                .map(|e| (e.file_name().to_string_lossy().into_owned(), e.path()))
                .collect(),
            Err(_) => Vec::new(),
        };
        let vaults: HashMap<String, VaultIndex> = dirs
            .into_par_iter()
            .map(|(name, path)| (name, VaultIndex::build_live(&path)))
            .collect();
        Self { vaults }
    }

    /// The warm index for `name`, or `None` if there is no such vault.
    pub fn get(&self, name: &str) -> Option<&VaultIndex> {
        self.vaults.get(name)
    }

    /// All known vault names (sorted).
    pub fn names(&self) -> Vec<String> {
        let mut names: Vec<String> = self.vaults.keys().cloned().collect();
        names.sort();
        names
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
}
