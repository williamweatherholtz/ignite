// IgniteBacklog — outstanding work actions (the engine's backlog dialect: an action def
// whose tasks are actions, each with a method-tagged DoD Test). Done = the latest DoD result
// is a pass; these have no result yet (outstanding). Resolver actions for tracked Issues.
package IgniteBacklog {
    private import EngineElement::*;
    private import EngineVerification::*;

    action def IgniteBuild {
        action realVaultBench;
        verification realVaultBenchDoD : Test { :>> id = "91419081-70c3-48d2-ac10-f41b9f54902c"; :>> method = VerificationMethod::test; :>> procedureText = "Resolves issue001. Benchmark VaultIndex::build + GET /api/fs/tree against a REAL ~2,500-file vault on true storage (disk/NAS), not a fast tempdir. VERIFY: cold build < 1 s and warm serve < 50 ms on real storage; record the measured numbers as evidence for srTreeFast."; }
        part realVaultBenchDoDR1 : TestResult { :>> id = "6f4194d4-3e81-4bec-bd5b-3e1df96ae950"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "fb718be"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; :>> notes = "Real-vault benchmark on C:/Users/WilliamWeatherholtz/Downloads/Games (2,972 entries = 2,557 files + 416 dirs - the vault Ignis took 72-214s on). Release build: COLD VaultIndex::build 19.96ms (< 1s contract), WARM serve avg 3.99ms (< 50ms contract). ~3,600-10,700x faster than Ignis. srTreeFast confirmed on real storage."; }

        action ctimeUnixParity;
        verification ctimeUnixParityDoD : Test { :>> id = "028a3fcc-ebae-48d9-b12b-afd7693b8913"; :>> method = VerificationMethod::inspect; :>> procedureText = "Resolves issue002. Determine what Ignis c9656b8 serves for ctimeMs on Unix (inode change time) vs Ignite's created()-fallback-modified(); align TreeEntry.ctime for wire-parity, or document the accepted platform difference with rationale."; }

        action gitTreeInclusionParity;
        verification gitTreeInclusionParityDoD : Test { :>> id = "714f74f2-3d25-4198-96c2-011ffe45ee60"; :>> method = VerificationMethod::inspect; :>> procedureText = "Resolves issue003. Capture a real Ignis fs/tree response and confirm whether .git / .obsidian appear in the tree (Ignis's WATCHER ignores .git, but its tree walk may include it). Align build_tree's inclusion/ignore set to match the captured oracle."; }
    }
}
