//! The vault tree model + the warm in-memory `VaultIndex`. Wire-compatible with
//! the Ignis c9656b8 fs/tree + bootstrap tree shape.

use arc_swap::ArcSwap;
use ignore::{WalkBuilder, WalkState};
use notify_debouncer_full::notify::{RecommendedWatcher, RecursiveMode, Watcher};
use notify_debouncer_full::{new_debouncer, DebounceEventResult, Debouncer, FileIdMap};
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

/// Kept-alive watcher handle (dropping it stops watching). Behind `Arc<Mutex<_>>`
/// so `VaultIndex` stays `Send + Sync + Clone`; we never need to lock it, only hold it.
type LiveDebouncer = Debouncer<RecommendedWatcher, FileIdMap>;

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

/// Apply a batch of changed paths to `tree` via copy-on-write: clone the current
/// tree once, re-stat each path (present -> upsert; missing -> remove it and any
/// subtree under it), then atomically swap in the result. Kind-agnostic — works for
/// create/modify/delete/rename/folder by reading disk truth per path. Incremental:
/// only the affected paths are touched, never a full re-walk.
fn apply_paths(tree: &ArcSwap<Tree>, root: &Path, paths: &[PathBuf]) {
    let mut next: Tree = (**tree.load()).clone();
    for p in paths {
        let rel = match p.strip_prefix(root) {
            Ok(r) if !r.as_os_str().is_empty() => r.to_string_lossy().replace('\\', "/"),
            _ => continue,
        };
        match std::fs::symlink_metadata(p) {
            Ok(meta) => {
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
                next.insert(rel, node);
            }
            Err(_) => {
                next.remove(&rel);
                let prefix = format!("{rel}/");
                next.retain(|k, _| !k.starts_with(&prefix));
            }
        }
    }
    tree.store(Arc::new(next));
}

/// A warm, in-memory index of one vault's tree. `tree()` returns the current snapshot
/// cheaply (lock-free `Arc` load). `build` is a static snapshot; `build_live` additionally
/// runs a continuous file watcher that keeps the snapshot correct as the vault changes.
#[derive(Clone)]
pub struct VaultIndex {
    root: PathBuf,
    tree: Arc<ArcSwap<Tree>>,
    // Kept alive for the index's lifetime; `None` for a static (unwatched) index.
    _watcher: Option<Arc<Mutex<LiveDebouncer>>>,
}

impl std::fmt::Debug for VaultIndex {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("VaultIndex")
            .field("root", &self.root)
            .field("entries", &self.tree.load().len())
            .field("live", &self._watcher.is_some())
            .finish()
    }
}

impl VaultIndex {
    /// Build a STATIC index by walking `root` once. The snapshot does not track later
    /// filesystem changes (used by benchmarks and where liveness isn't wanted).
    pub fn build(root: &Path) -> Self {
        Self {
            root: root.to_path_buf(),
            tree: Arc::new(ArcSwap::from_pointee(build_tree(root))),
            _watcher: None,
        }
    }

    /// Build a LIVE index: walk `root`, then run a continuous debounced watcher
    /// (`notify`) that keeps the snapshot correct as files change. The watcher starts
    /// here (NOT gated on any client) and lives for the index's lifetime.
    pub fn build_live(root: &Path) -> Self {
        let root_buf = root.to_path_buf();
        let tree = Arc::new(ArcSwap::from_pointee(Tree::new()));

        // Start the watcher FIRST (on an empty tree), then reconcile, so any change in
        // the build/watch gap is captured — either by a queued event or by the reconcile.
        let tree_cb = Arc::clone(&tree);
        let root_cb = root_buf.clone();
        let mut debouncer = new_debouncer(
            Duration::from_millis(300),
            None,
            move |res: DebounceEventResult| {
                if let Ok(events) = res {
                    let paths: Vec<PathBuf> = events.iter().flat_map(|e| e.paths.clone()).collect();
                    if !paths.is_empty() {
                        apply_paths(&tree_cb, &root_cb, &paths);
                    }
                }
            },
        )
        .expect("create file watcher");
        debouncer
            .watcher()
            .watch(root, RecursiveMode::Recursive)
            .expect("watch vault root");
        debouncer.cache().add_root(root, RecursiveMode::Recursive);

        let idx = Self {
            root: root_buf,
            tree,
            _watcher: Some(Arc::new(Mutex::new(debouncer))),
        };
        idx.reconcile(); // authoritative full walk after the watcher is live
        idx
    }

    /// Re-walk the vault and atomically replace the snapshot. Used after the watcher
    /// starts (and available to call on watcher restart) so the index can never
    /// silently diverge from disk — the no-silent-divergence safety net.
    pub fn reconcile(&self) {
        self.tree.store(Arc::new(build_tree(&self.root)));
    }

    /// The current tree snapshot. Cheap, lock-free (`ArcSwap` load), no disk access.
    pub fn tree(&self) -> Arc<Tree> {
        self.tree.load_full()
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

    /// Poll `cond` up to ~3s (notify is async + 300ms debounced — a single fixed
    /// sleep is too flaky). Returns the final result.
    fn wait_until<F: Fn() -> bool>(cond: F) -> bool {
        use std::time::Instant;
        let deadline = Instant::now() + Duration::from_secs(3);
        loop {
            if cond() {
                return true;
            }
            if Instant::now() >= deadline {
                return cond();
            }
            std::thread::sleep(Duration::from_millis(50));
        }
    }

    #[test]
    fn live_index_reflects_a_created_file() {
        let dir = tempdir().unwrap();
        let root = dir.path();
        fs::write(root.join("a.md"), b"hi").unwrap();
        let idx = VaultIndex::build_live(root);
        assert!(idx.tree().contains_key("a.md"));

        fs::write(root.join("b.md"), b"new").unwrap();
        assert!(
            wait_until(|| idx.tree().contains_key("b.md")),
            "watcher did not pick up a created file"
        );
    }

    #[test]
    fn live_index_reflects_a_modified_file() {
        let dir = tempdir().unwrap();
        let root = dir.path();
        fs::write(root.join("a.md"), b"hi").unwrap(); // 2 bytes
        let idx = VaultIndex::build_live(root);
        assert_eq!(idx.tree().get("a.md").unwrap().size, Some(2));

        fs::write(root.join("a.md"), b"much longer content").unwrap(); // 19 bytes
        assert!(
            wait_until(|| idx.tree().get("a.md").and_then(|e| e.size) == Some(19)),
            "watcher did not update size on modify"
        );
    }

    #[test]
    fn live_index_reflects_a_deleted_file() {
        let dir = tempdir().unwrap();
        let root = dir.path();
        fs::write(root.join("a.md"), b"hi").unwrap();
        let idx = VaultIndex::build_live(root);
        assert!(idx.tree().contains_key("a.md"));

        fs::remove_file(root.join("a.md")).unwrap();
        assert!(
            wait_until(|| !idx.tree().contains_key("a.md")),
            "watcher did not remove a deleted file"
        );
    }

    #[test]
    fn live_index_reflects_a_rename() {
        let dir = tempdir().unwrap();
        let root = dir.path();
        fs::write(root.join("old.md"), b"hi").unwrap();
        let idx = VaultIndex::build_live(root);
        assert!(idx.tree().contains_key("old.md"));

        fs::rename(root.join("old.md"), root.join("new.md")).unwrap();
        assert!(
            wait_until(|| !idx.tree().contains_key("old.md") && idx.tree().contains_key("new.md")),
            "watcher did not reflect a rename (old gone + new present)"
        );
    }

    #[test]
    fn live_index_reflects_a_created_directory() {
        let dir = tempdir().unwrap();
        let root = dir.path();
        let idx = VaultIndex::build_live(root);

        fs::create_dir(root.join("folder")).unwrap();
        assert!(
            wait_until(
                || idx.tree().get("folder").map(|e| e.node_type) == Some(NodeType::Directory)
            ),
            "watcher did not pick up a created directory"
        );
    }

    #[test]
    fn reconcile_resyncs_after_a_missed_change() {
        // A static index stands in for "watcher off": a change made while not watching
        // is missed, and reconcile() must re-sync the index to disk truth.
        let dir = tempdir().unwrap();
        let root = dir.path();
        fs::write(root.join("a.md"), b"hi").unwrap();
        let idx = VaultIndex::build(root);
        assert!(idx.tree().contains_key("a.md"));

        fs::write(root.join("c.md"), b"missed while watcher off").unwrap();
        assert!(
            !idx.tree().contains_key("c.md"),
            "static index must not silently auto-update"
        );

        idx.reconcile();
        assert!(
            idx.tree().contains_key("c.md"),
            "reconcile must re-sync the index to disk (no silent divergence)"
        );
    }
}
