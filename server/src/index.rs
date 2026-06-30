//! The vault tree model + the warm in-memory `VaultIndex`. Wire-compatible with
//! the Ignis c9656b8 fs/tree + bootstrap tree shape.

use ignore::{WalkBuilder, WalkState};
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::{SystemTime, UNIX_EPOCH};

/// A node in the vault tree. Directories carry only `type`; files carry
/// `type` + `size` + `mtime` + `ctime`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NodeType {
    File,
    Directory,
}

/// One entry in the tree map. `size`/`mtime`/`ctime` are populated for files only.
#[derive(Debug, Clone)]
pub struct TreeEntry {
    pub node_type: NodeType,
    pub size: Option<u64>,
    /// modification time, milliseconds since epoch (Ignis serves ms)
    pub mtime: Option<f64>,
    /// change/creation time, milliseconds since epoch
    pub ctime: Option<f64>,
}

/// The vault tree: relative POSIX path -> entry (Ignis `{ relPath: {..} }`).
pub type Tree = BTreeMap<String, TreeEntry>;

/// Build the full vault tree by walking `root`. Keys are vault-relative POSIX
/// paths (no leading slash, `/` separators), matching Ignis fs/tree / bootstrap.
pub fn build_tree(root: &Path) -> Tree {
    let tree = Mutex::new(Tree::new());

    // Parallel directory walk (the `ignore` crate's threaded walker). We do NOT
    // apply gitignore/hidden filtering: Ignis's tree walk includes everything
    // (e.g. .obsidian), so byte-shape parity requires the same.
    let walker = WalkBuilder::new(root)
        .hidden(false)
        .ignore(false)
        .git_ignore(false)
        .git_global(false)
        .git_exclude(false)
        .parents(false)
        .follow_links(false)
        .build_parallel();

    walker.run(|| {
        Box::new(|result| {
            let entry = match result {
                Ok(e) => e,
                Err(_) => return WalkState::Continue,
            };
            // skip the vault root itself (depth-0 entry)
            let rel = match entry.path().strip_prefix(root) {
                Ok(r) if !r.as_os_str().is_empty() => r.to_string_lossy().replace('\\', "/"),
                _ => return WalkState::Continue,
            };
            let meta = match entry.metadata() {
                Ok(m) => m,
                Err(_) => return WalkState::Continue,
            };
            let node = if meta.is_dir() {
                TreeEntry {
                    node_type: NodeType::Directory,
                    size: None,
                    mtime: None,
                    ctime: None,
                }
            } else {
                let mtime = meta.modified().ok().map(to_ms);
                let ctime = meta.created().ok().map(to_ms).or(mtime);
                TreeEntry {
                    node_type: NodeType::File,
                    size: Some(meta.len()),
                    mtime,
                    ctime,
                }
            };
            tree.lock().expect("tree mutex poisoned").insert(rel, node);
            WalkState::Continue
        })
    });

    tree.into_inner().expect("tree mutex poisoned")
}

fn to_ms(t: SystemTime) -> f64 {
    t.duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as f64)
        .unwrap_or(0.0)
}

/// Serialize a [`Tree`] to the EXACT Ignis c9656b8 JSON: a top-level object keyed by
/// relative POSIX path, where a directory is `{"type":"directory"}` (no other keys) and
/// a file is `{"type":"file","size":N,"mtime":N,"ctime":N}`.
pub fn tree_to_value(tree: &Tree) -> serde_json::Value {
    use serde_json::{Map, Value};
    let mut map = Map::with_capacity(tree.len());
    for (rel, entry) in tree {
        let mut obj = Map::new();
        match entry.node_type {
            NodeType::Directory => {
                obj.insert("type".into(), Value::from("directory"));
            }
            NodeType::File => {
                obj.insert("type".into(), Value::from("file"));
                if let Some(size) = entry.size {
                    obj.insert("size".into(), Value::from(size));
                }
                if let Some(mtime) = entry.mtime {
                    obj.insert("mtime".into(), serde_json::json!(mtime));
                }
                if let Some(ctime) = entry.ctime {
                    obj.insert("ctime".into(), serde_json::json!(ctime));
                }
            }
        }
        map.insert(rel.clone(), Value::Object(obj));
    }
    Value::Object(map)
}

/// A warm, in-memory index of one vault's tree. Built once via a (parallel) cold
/// walk; `tree()` returns the cached snapshot cheaply (an `Arc` clone) without
/// re-walking disk — this is what makes fs/tree serve in single-digit ms.
#[derive(Debug, Clone)]
pub struct VaultIndex {
    root: PathBuf,
    tree: Arc<Tree>,
}

impl VaultIndex {
    /// Build the index by walking `root` once (the cold build).
    pub fn build(root: &Path) -> Self {
        Self {
            root: root.to_path_buf(),
            tree: Arc::new(build_tree(root)),
        }
    }

    /// The cached tree snapshot. Cheap (`Arc` clone), no disk access.
    pub fn tree(&self) -> Arc<Tree> {
        Arc::clone(&self.tree)
    }

    /// The vault root this index was built from.
    pub fn root(&self) -> &Path {
        &self.root
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::tempdir;

    #[test]
    fn builds_tree_in_ignis_shape() {
        let dir = tempdir().unwrap();
        let root = dir.path();
        fs::write(root.join("a.md"), b"hello").unwrap(); // 5 bytes
        fs::create_dir(root.join("sub")).unwrap();
        fs::write(root.join("sub").join("b.md"), b"world!!").unwrap(); // 7 bytes

        let tree = build_tree(root);

        let sub = tree.get("sub").expect("sub dir present");
        assert_eq!(sub.node_type, NodeType::Directory);
        assert_eq!(sub.size, None);

        let a = tree.get("a.md").expect("a.md present");
        assert_eq!(a.node_type, NodeType::File);
        assert_eq!(a.size, Some(5));
        assert!(a.mtime.is_some() && a.ctime.is_some());

        let b = tree
            .get("sub/b.md")
            .expect("nested file present with posix key");
        assert_eq!(b.node_type, NodeType::File);
        assert_eq!(b.size, Some(7));

        assert!(tree
            .keys()
            .all(|k| !k.starts_with('/') && !k.contains('\\')));
        assert_eq!(tree.len(), 3);
    }

    #[test]
    fn serializes_tree_in_ignis_json_shape() {
        let mut tree = Tree::new();
        tree.insert(
            "sub".into(),
            TreeEntry {
                node_type: NodeType::Directory,
                size: None,
                mtime: None,
                ctime: None,
            },
        );
        tree.insert(
            "a.md".into(),
            TreeEntry {
                node_type: NodeType::File,
                size: Some(5),
                mtime: Some(1000.0),
                ctime: Some(2000.0),
            },
        );

        let v = tree_to_value(&tree);

        assert_eq!(v["sub"], serde_json::json!({ "type": "directory" }));
        assert_eq!(v["sub"].as_object().unwrap().len(), 1);
        assert_eq!(
            v["a.md"],
            serde_json::json!({ "type": "file", "size": 5, "mtime": 1000.0, "ctime": 2000.0 })
        );
    }

    #[test]
    fn vault_index_snapshot_matches_a_direct_build() {
        let dir = tempdir().unwrap();
        let root = dir.path();
        fs::write(root.join("a.md"), b"hi").unwrap();
        fs::create_dir(root.join("sub")).unwrap();

        let idx = VaultIndex::build(root);
        assert_eq!(idx.tree().len(), build_tree(root).len());
        assert!(idx.tree().contains_key("a.md"));
        assert_eq!(idx.root(), root);
    }

    /// Generate a synthetic vault: `dirs` directories each holding `files_per_dir`
    /// small markdown files. ~`dirs * files_per_dir` files + `dirs` directories.
    fn make_synthetic_vault(root: &Path, dirs: usize, files_per_dir: usize) {
        for d in 0..dirs {
            let dir = root.join(format!("dir{d:04}"));
            fs::create_dir_all(&dir).unwrap();
            for f in 0..files_per_dir {
                fs::write(dir.join(format!("note{f}.md")), b"# note\nsome content\n").unwrap();
            }
        }
    }

    #[test]
    fn cold_build_under_1s_for_2500_file_vault() {
        use std::time::{Duration, Instant};
        let dir = tempdir().unwrap();
        let root = dir.path();
        make_synthetic_vault(root, 400, 6); // ~2,400 files + 400 dirs

        let start = Instant::now();
        let idx = VaultIndex::build(root);
        let elapsed = start.elapsed();
        let entries = idx.tree().len();
        println!("cold build: {entries} entries in {elapsed:?}");

        assert!(entries >= 2400, "expected ~2,400+ entries, got {entries}");
        assert!(
            elapsed < Duration::from_secs(1),
            "cold build took {elapsed:?}, srTreeFast requires < 1s"
        );
    }

    #[test]
    fn warm_serve_under_50ms_for_2500_file_vault() {
        use std::time::{Duration, Instant};
        let dir = tempdir().unwrap();
        let root = dir.path();
        make_synthetic_vault(root, 400, 6);
        let idx = VaultIndex::build(root);

        // warm serve = serialize the cached snapshot to the Ignis JSON (what fs/tree does)
        let tree = idx.tree();
        let start = Instant::now();
        let json = tree_to_value(&tree);
        let elapsed = start.elapsed();
        println!(
            "warm serve: serialized {} entries in {elapsed:?}",
            tree.len()
        );

        assert!(json.as_object().unwrap().len() >= 2400);
        assert!(
            elapsed < Duration::from_millis(50),
            "warm serve took {elapsed:?}, srTreeFast requires < 50ms"
        );
    }

    #[test]
    fn vault_index_serves_cached_snapshot_not_live_disk() {
        let dir = tempdir().unwrap();
        let root = dir.path();
        fs::write(root.join("a.md"), b"hi").unwrap();

        let idx = VaultIndex::build(root);
        // mutate the filesystem AFTER the build
        fs::write(root.join("b.md"), b"new").unwrap();

        // the warm snapshot reflects build-time state — it did NOT re-walk disk
        assert!(idx.tree().contains_key("a.md"));
        assert!(!idx.tree().contains_key("b.md"));
    }
}
