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
        part dockerContextBenchDoDR1 : TestResult { :>> id = "1ac3a31e-4fec-495f-a5bd-dc71f145fcb1"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "8fc3505"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; :>> notes = "Docker-context benchmark (Games vault, 2,972 entries, bind-mounted /vault). 2x2 cold/warm matrix: Ignite-native 20ms/4ms; Ignite-Docker 2.74s/2.3ms; Node-Ignis-algo-native 657ms/216ms; Node-Ignis-algo-Docker 27.15s. FINDINGS: (1) Docker bind-mount FS dominates - 137x penalty on Ignite cold, 41x on Node cold. (2) In Docker, Ignite parallel beats Node-sequential ~10x cold (2.74s vs 27.15s) + serves warm at 2.3ms. (3) STRUCTURAL WIN: Ignite builds all indexes ONCE at startup (registry.rs eager VaultIndex::build) then serves every request warm (~2ms); Ignis RE-WALKS every request. So per-request tree load: tens of seconds (Ignis, every time) -> ~2ms (Ignite, after one-time startup). (4) HONEST GAP (issue005): Ignite's COLD build misses the <1s srTreeFast contract through the bind mount (2.74s) - startup-only, mitigated by warm-at-startup; 20ms native."; }

        action dockerColdMitigation;
        verification dockerColdMitigationDoD : Test { :>> id = "2e2a4193-7dda-428b-b639-07126ee09776"; :>> method = VerificationMethod::inspect; :>> procedureText = "Resolves issue005. Ignite's cold index build misses srTreeFast's <1s threshold through a Docker bind mount (2.74s for 2,972 entries; 20ms native). It is startup-only (warm-at-startup means per-request serves stay ~2ms), so impact is low - but document the deployment guidance (prefer a Docker named VOLUME or a WSL2-native vault path over a Windows-host bind mount; or run Ignite natively) and decide whether srTreeFast's cold threshold should carry a 'native storage' qualifier or a separate mounted-FS bound. No fabrication; record the chosen disposition."; }

        action watcherAutoRestart;
        verification watcherAutoRestartDoD : Test { :>> id = "fa95288b-e06d-475b-811e-40cb87e73e69"; :>> method = VerificationMethod::test; :>> procedureText = "Resolves issue006. Detect file-watcher error/termination and auto-recover: re-arm the watcher and reconcile() (and/or a periodic reconcile backstop) so a dead watcher cannot silently re-introduce staleness. VERIFY: a test that simulates watcher failure and asserts the index re-syncs; clippy + cargo test + keel green."; }

        action bulkMoveSubtreeWalk;
        verification bulkMoveSubtreeWalkDoD : Test { :>> id = "5b3ade6b-0f43-47fd-a944-bf1d0dad1733"; :>> method = VerificationMethod::test; :>> procedureText = "Resolves issue007. On a directory create/move event, eagerly walk the new subtree in apply_paths instead of relying solely on per-child notify events + reconcile. VERIFY: a test that moves a populated directory into the vault and asserts all descendants appear in the index promptly; clippy + cargo test + keel green."; }

        action fsSpawnBlocking;
        verification fsSpawnBlockingDoD : Test { :>> id = "b18f52ce-9f5a-4756-a5d6-d76e6753eb57"; :>> method = VerificationMethod::test; :>> procedureText = "Resolves issue008. Move the fs CRUD handlers' blocking std::fs calls onto tokio::task::spawn_blocking (or tokio::fs) so heavy concurrent I/O cannot stall tokio worker threads. VERIFY: handlers behave identically (all fs tests stay green); clippy + cargo test + keel green."; }

        action proxyDnsRebindHarden;
        verification proxyDnsRebindHardenDoD : Test { :>> id = "e4520f2f-5adb-4bfa-ba45-2cb98e888f02"; :>> method = VerificationMethod::test; :>> procedureText = "Resolves issue009. Close the proxy DNS-rebinding TOCTOU: pin the SSRF-vetted IP into the actual connection (custom reqwest resolver / connect to the checked socket addr) or re-validate the peer address after connect, so a DNS flip between check and connect cannot reach a private address. VERIFY: a rebinding-style test (vetted host resolves public at check, private at connect) is blocked; clippy + cargo test + keel green."; }

        action settingsProxyWire;
        verification settingsProxyWireDoD : Test { :>> id = "3d957b2e-f2ff-4cd3-9849-8e12134910ed"; :>> method = VerificationMethod::test; :>> procedureText = "Resolves issue010. Make the proxy read proxyMode/proxyAllowlist/proxyAllowPrivate from the shared injected SettingsState (not a startup-only ProxyConfig), so POST /api/settings takes effect at runtime without a restart. VERIFY: POST /api/settings {proxyMode:disabled} then a proxy request is rejected without restart; clippy + cargo test + keel green."; }

        action zipStreaming;
        verification zipStreamingDoD : Test { :>> id = "a94a65cd-082b-44ed-88b3-9fbbf855fd5c"; :>> method = VerificationMethod::test; :>> procedureText = "Resolves issue011. Stream download-zip to the response body (async zip writer / channel-backed body) instead of buffering the whole archive in a Vec<u8>, so a large folder does not zip into RAM. VERIFY: a large-folder zip streams (bounded memory); entries still correct; clippy + cargo test + keel green."; }

        action contentDispositionRfc5987;
        verification contentDispositionRfc5987DoD : Test { :>> id = "a6d0d306-700c-4bcb-b1c9-f0aaa17da3ff"; :>> method = VerificationMethod::test; :>> procedureText = "Resolves issue012. Add RFC-5987 filename* encoding to Content-Disposition (download + download-zip) for non-ASCII names, matching Ignis's encodeContentDispositionFilename. VERIFY: a non-ASCII filename yields both filename= (ASCII fallback) and filename*=UTF-8''..; clippy + cargo test + keel green."; }

        action browserLoadDemo;
        verification browserLoadDemoDoD : Test { :>> id = "bec5bff5-882a-4a51-9f6a-e08368d16fa3"; :>> method = VerificationMethod::demo; :>> procedureText = "Resolves issue013 (HUMAN demo, D0049). Run the Ignite container (docker compose up, or the Caddy stack) with a real vault bind-mounted, open a browser, and confirm: Obsidian loads (the shell + shim), a vault opens, files render, and an edit live-syncs. Fix any Ignis-asset-wiring mismatch (template placeholders / ui-shim serving paths / app.css / route order) surfaced. Human-attested."; }
    }
}
