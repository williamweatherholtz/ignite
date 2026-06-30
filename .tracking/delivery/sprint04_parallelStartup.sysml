// IgniteDeliveryS04 — Sprint 4: build vault indexes in parallel at startup (the quick win
// from the critique, dCritiqueEfficiency). Behavior-preserving refactor of registry.rs;
// done at a7f5e78. Covers the work per D0064 (done work is sprint-covered).
package IgniteDeliveryS04 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    // chartered by the efficiency Decision (dCritiqueEfficiency, IgniteCritiqueDecisions); name-ref, no import.
    #CharteredBy dependency from parallelStartupStory to dCritiqueEfficiency;

    part parallelStartupStory : Story {
        :>> id = "fe797b7d-8570-4c25-8fa6-5ef64de7e19c";
        :>> title = "Sprint 4: parallel multi-vault index build at startup (dCritiqueEfficiency quick win)";
        :>> createdAt = "2026-06-30"; :>> createdBy = "will"; :>> kind = WorkKind::refactor; :>> priority = WorkPriority::p2; :>> owner = "ai"; :>> estimatedPoints = 1;
    }

    action def DeliveryRunS04 {
        action storyParallelStartup;
        verification storyParallelStartupDoD : Test { :>> id = "e5bdad8b-cf30-4182-ad4b-7f34dbd22288"; :>> method = VerificationMethod::test; :>> procedureText = "registry.rs discover() builds per-vault indexes concurrently (rayon into_par_iter) instead of sequentially, so multi-vault startup is bounded by the slowest single vault, not the sum. Behavior-preserving: discovers_vault_subdirs_and_indexes_them stays green. VERIFY: cargo test (10 pass) + clippy -D warnings clean."; }
        part storyParallelStartupDoDR1 : TestResult { :>> id = "9ce95438-ee0d-498d-8dbc-28c84caa8aee"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "a7f5e78"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; :>> notes = "rayon parallel build across vaults; 10 tests pass, clippy clean. Expected effect: ~16s -> ~3s startup for 6 vaults over a Docker bind mount (sum -> max)."; }
    }

    verification parallelStartupRefineGate : Test { :>> id = "e6cf79a6-c28a-4323-8747-1e6d292ef37d"; :>> title = "Sprint 4 refine gate (DoR)"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: small behavior-preserving refactor chartered by dCritiqueEfficiency; existing registry test covers correctness; 1pt. DoR met."; }
    part parallelStartupRefineGateR1 : TestResult { :>> id = "96181030-a649-4846-8812-4fea4735f296"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "a7f5e78"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
    verification parallelStartupStandupGate : Test { :>> id = "93dc5d02-88a6-4652-9603-6c75c8254991"; :>> title = "Sprint 4 standup gate"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "Approach: collect vault (name,path) dirs, into_par_iter().map(build).collect() into the HashMap. Keep the existing correctness test green. No blockers."; }
    part parallelStartupStandupGateR1 : TestResult { :>> id = "2da6df15-eca9-442e-921d-9b604e81c210"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "a7f5e78"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
    verification parallelStartupImplementGate : Test { :>> id = "87b36271-8437-488e-b08b-efbd76e49633"; :>> title = "Sprint 4 implement gate"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::test; :>> procedureText = "Implemented (rayon dep + into_par_iter in registry.rs). cargo test 10 pass (registry test green), clippy -D warnings clean. Verified live at a7f5e78."; }
    part parallelStartupImplementGateR1 : TestResult { :>> id = "5fa40572-d32d-4a5b-a166-949d918d8d24"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "a7f5e78"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
    verification parallelStartupReviewGate : Test { :>> id = "737f6a1d-7805-4c5c-86fc-a89ea3fad884"; :>> title = "Sprint 4 review gate"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "Reviewed: clean rayon refactor, behavior-preserving (same vaults indexed, names sorted), correctness test unchanged. Nested parallelism (rayon across vaults x ignore within a vault) is acceptable at this scale. Clean."; }
    part parallelStartupReviewGateR1 : TestResult { :>> id = "94760d4b-54cf-47d9-a7ec-def3f8b268c3"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "a7f5e78"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
    verification parallelStartupCloseOutGate : Test { :>> id = "6757d2c5-52fa-4c42-87d3-b2ee084effb9"; :>> title = "Sprint 4 closeOut gate (autonomous, D0049)"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "Autonomous closeOut (D0049): DoD pass; the dCritiqueEfficiency quick win is delivered. cargo test + clippy + keel validate/guard green."; }
    part parallelStartupCloseOutGateR1 : TestResult { :>> id = "c0d9bda8-c226-4ee4-a421-4267fd7298bd"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "a7f5e78"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
    verification parallelStartupRetroGate : Test { :>> id = "151b610e-898d-4480-80a4-452d6d775d6f"; :>> title = "Sprint 4 retro gate (autonomous, D0049)"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::analyze; :>> procedureText = "Autonomous retro (D0049). WELL: a critique-spike finding turned into a shipped quick win the same session. AVOIDABLE-ISSUE SCAN: none new - behavior-preserving refactor, existing registry correctness test held green, no defects introduced; the proxy-streaming + WS-batching constraints from dCritiqueEfficiency remain tracked design constraints on their future feature sprints. LESSON: parallelizing ACROSS vaults compounds with the per-vault parallel walk - matters most on slow storage (Docker), exactly where startup cost is highest. Estimate 1pt held."; }
    part parallelStartupRetroGateR1 : TestResult { :>> id = "92350973-e6b8-46f4-8370-f56a46559d26"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "a7f5e78"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
}
