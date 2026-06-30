// IgniteDeliveryS02 — Sprint 2: confirm srTreeFast on a REAL vault (resolves issue001) and
// honestly characterize the Ignis comparison. Small verification sprint covering the
// realVaultBench backlog action (D0064/issue020: done work is sprint-covered). Work is done;
// all gates passed. judged at fb718be (where the benchmark harness + run landed).
package IgniteDeliveryS02 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    // realVaultBench (IgniteBacklog) referenced by name in the #CharteredBy edge (no import - .tracking edges resolve by name).
    #CharteredBy dependency from realVaultBenchStory to realVaultBench;

    part realVaultBenchStory : Story {
        :>> id = "93c076b0-414d-4b50-9663-ede669d69dfd";
        :>> title = "Sprint 2: confirm srTreeFast on the real Games vault + honest Ignis comparison (resolves issue001)";
        :>> createdAt = "2026-06-30"; :>> createdBy = "will"; :>> kind = WorkKind::research; :>> priority = WorkPriority::p1; :>> owner = "ai"; :>> estimatedPoints = 1;
    }

    action def DeliveryRunS02 {
        action storyRealVaultBench;
        verification storyRealVaultBenchDoD : Test { :>> id = "8b930b04-59fb-4b9a-aca1-ae2a698af7a4"; :>> method = VerificationMethod::test; :>> procedureText = "Benchmark Ignite (release) on the real Games vault (C:/Users/.../Downloads/Games, 2,972 entries): assert cold VaultIndex::build < 1s and warm serve < 50ms on real native storage; record the numbers; and run a CONTROLLED same-filesystem baseline to characterize the Ignis comparison honestly (issue004)."; }
        part storyRealVaultBenchDoDR1 : TestResult { :>> id = "b9fb3356-7749-4940-8077-8262ef3ebdfe"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "fb718be"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; :>> notes = "Ignite on real Games vault: cold 19.96ms, warm 3.99ms - srTreeFast confirmed on real native storage. Honest comparison (issue004): native Node same-algorithm walk = 657ms cold / 216ms warm; the 72-214s Ignis figure was Docker-bind-mount-FS-dominated. Clean Rust-vs-Node same-FS speedup ~11-33x."; }
    }

    verification realVaultBenchStoryRefineGate : Test { :>> id = "a43adcbd-d579-4f30-8200-9e6a29bbda83"; :>> title = "Sprint 2 refine gate (DoR)"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: issue001 needs srTreeFast confirmed on a real vault (not synthetic). Path provided (Downloads/Games, 2,972 entries). Small (1pt) measurement task. #CharteredBy realVaultBench. DoR met."; }
    part realVaultBenchStoryRefineGateR1 : TestResult { :>> id = "49f34edd-b1ba-4571-8a20-a6d27aebba5c"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "fb718be"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
    verification realVaultBenchStoryStandupGate : Test { :>> id = "0b1ee322-1135-4990-931e-98e1394750a1"; :>> title = "Sprint 2 standup gate"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "Approach: a reproducible examples/bench.rs (release) times cold build + warm serve on the real path; plus a controlled Node baseline running Ignis's exact sequential walk over the same native path to isolate the Docker confound. No blockers."; }
    part realVaultBenchStoryStandupGateR1 : TestResult { :>> id = "03e3118f-7797-4da6-8316-5aff1b4e3f8f"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "fb718be"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
    verification realVaultBenchStoryImplementGate : Test { :>> id = "043d4fec-6ace-41f4-8e56-a6442f59da02"; :>> title = "Sprint 2 implement gate"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::test; :>> procedureText = "examples/bench.rs added + run (release): Ignite cold 19.96ms, warm 3.99ms on the real 2,972-entry vault (< 1s / < 50ms). Controlled Node baseline (Ignis's exact walk, same native path): 657ms cold / 216ms warm. Numbers recorded on realVaultBench + in issue004."; }
    part realVaultBenchStoryImplementGateR1 : TestResult { :>> id = "3f3e1b10-c5b8-4c4a-9f94-f7e975040178"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "fb718be"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
    verification realVaultBenchStoryReviewGate : Test { :>> id = "988416b4-0c8c-44ce-96fc-868a8e8b3970"; :>> title = "Sprint 2 review gate"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "Reviewed: srTreeFast genuinely confirmed on real native storage (20ms). The earlier 'thousands x vs Ignis' was an overclaim (Docker bind-mount confound) - corrected; the honest clean speedup is ~11-33x. The end-to-end Ignis-context comparison is correctly deferred to issue004 rather than overclaimed. Honest."; }
    part realVaultBenchStoryReviewGateR1 : TestResult { :>> id = "f33bfbb3-1fa9-4a53-8376-7cff2435fed6"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "fb718be"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
    verification realVaultBenchStoryCloseOutGate : Test { :>> id = "b028fff2-4d4a-450e-9893-22d4515ffca5"; :>> title = "Sprint 2 closeOut gate (autonomous, D0049)"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "Autonomous closeOut (D0049): DoD pass; issue001 resolved (srTreeFast confirmed on real storage). The honesty correction is recorded; issue004 tracks the end-to-end Docker-context comparison. keel validate + guard green."; }
    part realVaultBenchStoryCloseOutGateR1 : TestResult { :>> id = "992d0cc9-cabf-4dee-9109-0c64628bb5b7"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "fb718be"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
    verification realVaultBenchStoryRetroGate : Test { :>> id = "398668a2-f7da-4e58-aaff-4a94433271ee"; :>> title = "Sprint 2 retro gate (autonomous, D0049)"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::analyze; :>> procedureText = "Autonomous retro (D0049). WELL: a human challenge ('is this like-for-like?') caught a real overclaim before it stuck; the controlled same-filesystem baseline turned a confounded 'thousands x' into an honest ~11-33x + a separate Docker-FS finding. AVOIDABLE-ISSUE SCAN -> issue004 (end-to-end Docker-context comparison). LESSON: never compare across environments (Docker vs native) without isolating the variable; a cross-tool speedup claim needs same-FS, same-data control. Also: a masked `| tail -1` let a red guard slip past commit - run guard verdict unmasked before committing. Estimate 1pt held."; }
    part realVaultBenchStoryRetroGateR1 : TestResult { :>> id = "581c8e08-e734-44af-9a69-14efd95baeb8"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "fb718be"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
}
