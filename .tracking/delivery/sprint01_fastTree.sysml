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
        verification storyTreeFastDoD : Test { :>> id = "25a11338-83d3-4016-a4ff-54bae8eee6f2"; :>> method = VerificationMethod::test; :>> procedureText = "As a self-hoster with a large vault, I want the file tree to load near-instantly. DoD (satisfies srTreeFast): (1) a Cargo workspace + axum/tokio server skeleton + vault discovery from VAULT_ROOT exist in the deliverable subdir; (2) an in-memory VaultIndex is built by a parallel directory walk (ignore/jwalk) and held warm; (3) GET /api/fs/tree?vault=<v> serves from the index with the EXACT Ignis c9656b8 JSON shape { relPath: { type, size?, mtime?, ctime? } }; (4) PERF on a 2,500-file vault (the cloned Games fixture): < 1 s cold (fresh start), < 50 ms warm (subsequent calls) - measured by a criterion benchmark test; (5) clippy -D warnings clean, cargo test green (incl. the perf + shape tests), keel validate + guard all green. Wire-compat verified by byte-shape comparison against an Ignis fs/tree capture."; }
    }

    // ---- Ceremony gates (D0047/D0049). Only the refine gate (DoR) has passed: the sprint is PLANNED. ----
    verification treeFastRefineGate : Test { :>> id = "4810b6b8-f455-48d1-b17d-3091d66cfa2f"; :>> title = "Sprint 1 refine gate (DoR)"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: srTreeFast is clear + measurable (< 1 s cold / < 50 ms warm for 2,500 files). INVEST: Independent (no unfinished dep - it is the foundational slice); Negotiable; Valuable (large vaults become usable); Estimable (8 pts - scaffolding + index + endpoint); Small (one sprint); Testable (perf + wire-shape criteria). The Ignis fs/tree contract is known from the pinned c9656b8 inventory. #CharteredBy srTreeFast. Scaffolding folded into the slice (not a horizontal story). DoR met."; }
    part treeFastRefineGateR1 : TestResult { :>> id = "135fa94f-ae90-43a2-b164-55c3af109cd0"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "e628296"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
}
