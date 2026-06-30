// Ignis-algorithm baseline: replicates Ignis c9656b8's bootstrap/fs-tree walk EXACTLY
// (sequential recursive walk, one `await fsp.stat` per file). Run natively AND inside a
// node container against the same bind-mounted vault to isolate the Docker-FS penalty.
//   node ignis-walk-baseline.js <vault-path>
const fs = require('fs');
const fsp = fs.promises;
const path = require('path');

async function walk(dir, prefix, tree) {
  await fsp.stat(dir);
  const entries = await fsp.readdir(dir, { withFileTypes: true });
  for (const entry of entries) {
    const rel = prefix ? prefix + '/' + entry.name : entry.name;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      tree[rel] = { type: 'directory' };
      await walk(full, rel, tree);
    } else {
      const s = await fsp.stat(full);
      tree[rel] = { type: 'file', size: s.size, mtime: s.mtimeMs, ctime: s.ctimeMs };
    }
  }
}

(async () => {
  const root = process.argv[2];
  const tree = {};
  const t = process.hrtime.bigint();
  await walk(root, '', tree);
  const ms = Number(process.hrtime.bigint() - t) / 1e6;
  console.log(`node sequential Ignis-style walk: ${Object.keys(tree).length} entries in ${ms.toFixed(1)} ms`);
})();
