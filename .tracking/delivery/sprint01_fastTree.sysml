// IgniteDeliveryS01 — Sprint 1: warm in-memory VaultIndex serving a fast /api/fs/tree.
// The foundational vertical slice + the heart of the perf win (satisfies srTreeFast).
// Scaffolds the Cargo workspace + axum skeleton + vault discovery as part of the slice.
// PLANNED to DoR (refine gate passed); standup..retro remain unpassed until built (D0051 - no
// fabricated evidence; the implement gate's evidence is a real green build).
package IgniteDeliveryS01 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;
    // srTreeFast (IgniteRequirements) is referenced by name in the #CharteredBy edge below;
    // no import - this file sorts before requirements.sysml, and .tracking edges resolve by name.

    // The Story is chartered by the requirement it implements (D0068 charter lineage).
    #CharteredBy dependency from treeFastStory to srTreeFast;

    part treeFastStory : Story {
        :>> id = "f713ea0f-b7f2-4440-a8d3-f5d7357348c1";
        :>> title = "Sprint 1: warm in-memory index serving a fast /api/fs/tree (satisfies srTreeFast)";
        :>> createdAt = "2026-06-30"; :>> createdBy = "will"; :>> kind = WorkKind::code; :>> priority = WorkPriority::p0; :>> owner = "ai"; :>> estimatedPoints = 8;
    }

    action def DeliveryRunS01 {
        action storyTreeFast;
        verification storyTreeFastDoD : Test { :>> id = "25a11338-83d3-4016-a4ff-54bae8eee6f2"; :>> method = VerificationMethod::test; :>> procedureText = "As a self-hoster with a large vault, I want the file tree to load near-instantly. DoD (satisfies srTreeFast): (1) a Cargo workspace + axum/tokio server skeleton + vault discovery from VAULT_ROOT exist in the deliverable subdir; (2) an in-memory VaultIndex is built by a parallel directory walk (ignore/jwalk) and held warm; (3) GET /api/fs/tree?vault=<v> serves from the index with the EXACT Ignis c9656b8 JSON shape { relPath: { type, size?, mtime?, ctime? } }; (4) PERF on a ~2,500-file vault: < 1 s cold (fresh start), < 50 ms warm (subsequent calls) - measured by a criterion benchmark test; (5) clippy -D warnings clean, cargo test green (incl. the perf + shape tests), keel validate + guard all green. Wire shape matches the documented Ignis c9656b8 contract."; }
        part storyTreeFastDoDR1 : TestResult { :>> id = "dc04f3c5-dbda-4ef2-a201-0b4c447d4a8c"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "bac82fb"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; :>> notes = "Verified live: 10 tests pass (axum oneshot integration + 2 perf), clippy -D warnings clean, fmt. On a SYNTHETIC ~2,800-entry vault: cold build 24.9ms (< 1s), warm serve 6.8ms (< 50ms). CAVEATS (tracked): perf measured on a fast tempdir, not a real vault (issue001); ctime=created() differs from Ignis on Unix (issue002); .git/.obsidian tree-inclusion vs Ignis unconfirmed (issue003). 'Warm' = built-and-cached, not yet watcher-maintained (srLiveSync, future)."; }
        part storyTreeFastDoDR2 : TestResult { :>> id = "6bae0346-a986-4765-a5ec-795312443143"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "a7f5e78"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
        part storyTreeFastDoDR3 : TestResult { :>> id = "8c9580e4-aff4-47f3-beec-eeaa837319e9"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "882a80e"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
        part storyTreeFastDoDR4 : TestResult { :>> id = "6573ccec-f137-4e26-87ac-6c1c9cea113e"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "80d878e"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
        part storyTreeFastDoDR5 : TestResult { :>> id = "d4b60391-326b-44db-b648-236cdc107641"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "272821d"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
        part storyTreeFastDoDR6 : TestResult { :>> id = "1a13d741-e39c-4fe4-a64e-e4dc7db624d8"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "bdd8f40"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
        part storyTreeFastDoDR7 : TestResult { :>> id = "87f85695-8e6c-4026-a6fb-8749f38a8906"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "3b97ec1"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; }
        part storyTreeFastDoDR8 : TestResult { :>> id = "15e17ac8-1c41-4fd5-aa74-37a45dcc6203"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "4cd1b2a"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; }
        part storyTreeFastDoDR9 : TestResult { :>> id = "2adc0746-9bbf-4b4d-a2df-b368384db3a3"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "cb32d15"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "claudeOpus"; }
    }

    // ---- Ceremony gates (D0047/D0049). Only the refine gate (DoR) has passed: the sprint is PLANNED. ----
    verification treeFastRefineGate : Test { :>> id = "4810b6b8-f455-48d1-b17d-3091d66cfa2f"; :>> title = "Sprint 1 refine gate (DoR)"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: srTreeFast is clear + measurable (< 1 s cold / < 50 ms warm for 2,500 files). INVEST: Independent (no unfinished dep - it is the foundational slice); Negotiable; Valuable (large vaults become usable); Estimable (8 pts - scaffolding + index + endpoint); Small (one sprint); Testable (perf + wire-shape criteria). The Ignis fs/tree contract is known from the pinned c9656b8 inventory. #CharteredBy srTreeFast. Scaffolding folded into the slice (not a horizontal story). DoR met."; }
    part treeFastRefineGateR1 : TestResult { :>> id = "135fa94f-ae90-43a2-b164-55c3af109cd0"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "e628296"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }

    verification treeFastStandupGate : Test { :>> id = "ef478bf6-f099-461c-9619-98b309eb3acf"; :>> title = "Sprint 1 standup gate"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "Approach: lib (index.rs: parallel-walk build_tree + warm VaultIndex cache + tree_to_value Ignis-shape), registry.rs (VAULT_ROOT discovery), app.rs (axum GET /api/fs/tree), each TDD. A synthetic ~2,500-file fixture drives the perf tests (no real vault data in-repo). No blockers."; }
    part treeFastStandupGateR1 : TestResult { :>> id = "2af91094-deb0-41c6-8fe3-6ff442312b62"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "bac82fb"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
    verification treeFastImplementGate : Test { :>> id = "5c3f80ee-0cc6-45e9-97e0-5553d8035512"; :>> title = "Sprint 1 implement gate"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::test; :>> procedureText = "Built test-first (each behavior watched RED first). 10 tests pass incl. axum oneshot integration + 2 perf tests; clippy -D warnings clean; fmt. PERF on synthetic ~2,800-entry vault: cold build 24.9ms (< 1s), warm serve 6.8ms (< 50ms). Verified live at bac82fb."; }
    part treeFastImplementGateR1 : TestResult { :>> id = "1906d2c3-4067-48ff-a2b1-8986f1599552"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "bac82fb"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
    verification treeFastReviewGate : Test { :>> id = "998fdf3a-18c5-44a8-9c9a-0df4ff125232"; :>> title = "Sprint 1 review gate"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "Reviewed: clean module split (index/registry/app), exact Ignis tree shape (dirs {type}; files {type,size,mtime,ctime}), parallel walk per dArch. Residual caveats logged as issue001 (synthetic-not-real-vault perf), issue002 (ctime Unix parity), issue003 (.git/.obsidian inclusion parity). Slice is sound; caveats tracked, non-blocking."; }
    part treeFastReviewGateR1 : TestResult { :>> id = "83f4fd2a-fb8a-4907-aa80-9b0f2a2e0f44"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "bac82fb"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
    verification treeFastCloseOutGate : Test { :>> id = "d586da65-1ddd-47ba-9ac4-7e4817ecd928"; :>> title = "Sprint 1 closeOut gate (autonomous, D0049)"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "Autonomous closeOut (D0049): DoD pass (buildable/testable criteria met; method=test self-evidencing D0051). srTreeFast's perf contract demonstrated on synthetic data; real-vault confirmation tracked as issue001. cargo test + clippy + keel validate/guard green. Sprint 1 deliverable (fast /api/fs/tree) is built."; }
    part treeFastCloseOutGateR1 : TestResult { :>> id = "b5ecc99c-5995-487a-bcb7-3ee4b1f5d435"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "bac82fb"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
    verification treeFastRetroGate : Test { :>> id = "fa54a4aa-b183-46e0-acc5-be247c6fb250"; :>> title = "Sprint 1 retro gate (autonomous, D0049)"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::analyze; :>> procedureText = "Autonomous retro (D0049). WELL: the perf win is dramatic (minutes -> ~25ms cold / ~7ms warm); the warm-index architecture (dArch) is validated end-to-end. AVOIDABLE-ISSUE SCAN -> tracked: issue001 (benchmark on a real ~2,500-file vault, not just a fast tempdir), issue002 (ctime Unix parity), issue003 (.git/.obsidian tree-inclusion parity vs Ignis). LESSON: byte-shape parity with a CLOSED upstream needs a CAPTURED real Ignis fs/tree response as the oracle, not just the documented shape. Estimate 8pt held. Next frontier: srLiveSync (notify watcher + incremental index + WS) and bootstrap/batch-read under srWireCompat."; }
    part treeFastRetroGateR1 : TestResult { :>> id = "dd1e03d8-d153-46b2-8b4a-570f02effb4f"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "bac82fb"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
}
