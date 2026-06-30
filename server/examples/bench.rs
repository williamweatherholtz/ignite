//! Real-vault benchmark for srTreeFast (resolves issue001).
//!   cargo run --release --example bench -- "C:\\path\\to\\vault"
//!
//! Measures, on REAL storage: cold VaultIndex::build (the parallel walk) and the
//! warm per-request serve cost (snapshot access + serialize to the Ignis JSON shape).

use ignite_server::{tree_to_value, VaultIndex};
use std::path::Path;
use std::time::Instant;

fn main() {
    let path = std::env::args()
        .nth(1)
        .expect("usage: cargo run --release --example bench -- <vault-path>");
    let root = Path::new(&path);

    // --- cold build: fresh index, parallel walk of real storage ---
    let t = Instant::now();
    let index = VaultIndex::build(root);
    let cold = t.elapsed();

    let tree = index.tree();
    let entries = tree.len();

    // --- warm serve: what a GET /api/fs/tree does once the index is warm ---
    // single representative request
    let t = Instant::now();
    let json = tree_to_value(&index.tree());
    let warm_once = t.elapsed();

    // average over 100 to smooth noise
    let iters = 100u32;
    let t = Instant::now();
    let mut bytes = 0usize;
    for _ in 0..iters {
        let v = tree_to_value(&index.tree());
        bytes = serde_json::to_vec(&v).map(|b| b.len()).unwrap_or(0);
    }
    let warm_avg = t.elapsed() / iters;

    println!("vault:           {path}");
    println!("entries:         {entries}");
    println!("payload bytes:   {bytes}");
    println!("COLD build:      {cold:?}   (srTreeFast contract: < 1 s)");
    println!("WARM serve once: {warm_once:?}");
    println!("WARM serve avg:  {warm_avg:?}  (srTreeFast contract: < 50 ms)");
    // keep `json` from being optimized away
    std::hint::black_box(json);
}
