// IgniteBacklog — outstanding work actions (the engine's backlog dialect: an action def
// whose tasks are actions, each with a method-tagged DoD Test). Done = the latest DoD result
// is a pass; these have no result yet (outstanding). Resolver actions for tracked Issues.
package IgniteBacklog {
    private import EngineElement::*;
    private import EngineVerification::*;

    action def IgniteBuild {
        action realVaultBench;
        verification realVaultBenchDoD : Test { :>> id = "91419081-70c3-48d2-ac10-f41b9f54902c"; :>> method = VerificationMethod::test; :>> procedureText = "Resolves issue001. Benchmark VaultIndex::build + GET /api/fs/tree against a REAL ~2,500-file vault on true storage (disk/NAS), not a fast tempdir. VERIFY: cold build < 1 s and warm serve < 50 ms on real storage; record the measured numbers as evidence for srTreeFast."; }
        part realVaultBenchDoDR1 : TestResult { :>> id = "6f4194d4-3e81-4bec-bd5b-3e1df96ae950"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "fb718be"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; :>> notes = "Real-vault benchmark on C:/Users/WilliamWeatherholtz/Downloads/Games (2,972 entries), release build: COLD VaultIndex::build 19.96ms (< 1s contract), WARM serve avg 3.99ms (< 50ms contract). srTreeFast CONFIRMED on real native storage. HONESTY CORRECTION (see issue004): the 72-214s Ignis figure was measured IN DOCKER (slow bind-mount FS). A CONTROLLED same-filesystem baseline - Node running Ignis's EXACT sequential per-file-stat walk over this native vault - is 657ms cold / 216ms warm. So Docker's bind-mount FS (~100-300x), NOT the Node algorithm, dominated the original 72-214s; the clean Rust-vs-Node same-FS speedup is ~11-33x (plus no event-loop head-of-line blocking). The 'thousands x' framing was confounded. End-to-end Ignite-in-Docker comparison is tracked as issue004."; }

        action ctimeUnixParity;
        verification ctimeUnixParityDoD : Test { :>> id = "028a3fcc-ebae-48d9-b12b-afd7693b8913"; :>> method = VerificationMethod::inspect; :>> procedureText = "Resolves issue002. Determine what Ignis c9656b8 serves for ctimeMs on Unix (inode change time) vs Ignite's created()-fallback-modified(); align TreeEntry.ctime for wire-parity, or document the accepted platform difference with rationale."; }

        action gitTreeInclusionParity;
        verification gitTreeInclusionParityDoD : Test { :>> id = "714f74f2-3d25-4198-96c2-011ffe45ee60"; :>> method = VerificationMethod::inspect; :>> procedureText = "Resolves issue003. Capture a real Ignis fs/tree response and confirm whether .git / .obsidian appear in the tree (Ignis's WATCHER ignores .git, but its tree walk may include it). Align build_tree's inclusion/ignore set to match the captured oracle."; }

        action dockerContextBench;
        verification dockerContextBenchDoD : Test { :>> id = "0ff2978b-0e0f-4b84-84a6-58fb9db76154"; :>> method = VerificationMethod::test; :>> procedureText = "Resolves issue004. For an HONEST end-to-end Ignis-vs-Ignite claim, benchmark Ignite reading the vault in the SAME environment Ignis used (Docker container, same bind-mount), OR run Ignis's server on the native path. Controlled finding so far: Ignis's 72-214s was Docker-bind-mount-FS-dominated; native same-algorithm Node walk is 657ms cold / 216ms warm; Rust is ~20ms (~11-33x clean speedup). VERIFY: record Ignite's cold/warm in Ignis's actual deployment context so the speedup claim is apples-to-apples; state the true end-to-end factor."; }
    }
}
