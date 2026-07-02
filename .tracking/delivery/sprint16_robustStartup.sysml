// IgniteDeliveryS16 — Sprint 16: robust startup + graceful shell diagnostics (resolves issue014,
// field feedback from the sprint15 demo: 0 vaults -> blank page, no error). Done at 4250086.
package IgniteDeliveryS16 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    #CharteredBy dependency from robustStartupStory to srWireCompat;
    // resolves the field-reported blank-page bug
    #Resolves dependency from storyRobustStartup to issue014;

    part robustStartupStory : Story {
        :>> id = "1687b1cb-17a1-4ec9-95ab-681eaaed7ee4";
        :>> title = "Sprint 16: clear diagnostics instead of a blank 500 (no-vaults page + shell-error page + loud startup logging)";
        :>> createdAt = "2026-07-02"; :>> createdBy = "will"; :>> kind = WorkKind::code; :>> priority = WorkPriority::p1; :>> owner = "ai"; :>> estimatedPoints = 2;
    }

    action def DeliveryRunS16 {
        action storyRobustStartup;
        verification storyRobustStartupDoD : Test { :>> id = "c62337f4-2c3b-4d32-b52d-7eaa033b7c3f"; :>> method = VerificationMethod::test; :>> procedureText = "Resolves issue014 (blank page / no error on 0 vaults, found in the sprint15 demo). (1) GET / with an EMPTY registry returns a friendly 'No vaults found' HTML page (200) explaining the /vaults mount, not the blank Obsidian shell. (2) build_shell now returns descriptive errors (which path is missing/unreadable) and index_handler renders them into a diagnostic page (500 WITH a body) instead of a bare empty 500. (3) startup logs a loud WARNING with the resolved VAULT_ROOT + mount guidance when 0 vaults. VERIFY: a new test (empty registry -> GET / 200 contains 'No vaults found'); cargo test + clippy green."; }
        part storyRobustStartupDoDR1 : TestResult { :>> id = "cfabbf35-8571-4fe8-9c3c-7917836bae81"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "4250086"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; :>> notes = "main.rs: loud 0-vaults WARNING + resolved path. static_routes: build_shell -> Result<String,String> naming the bad path; index_handler serves a no-vaults page (empty registry) or a diagnostic page (build_shell Err) via diagnostic_page(). 83 tests pass (new index_shows_no_vaults_page_when_registry_empty), clippy + fmt clean."; }
    }

    verification robustStartupRefineGate : Test { :>> id = "42d85446-6988-418d-8cfc-72f64ecc22f1"; :>> title = "Sprint 16 refine gate (DoR)"; :>> createdAt = "2026-07-02"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: hotfix for issue014 (field feedback: blank page on 0 vaults). Small, clear, testable (no-vaults page + descriptive shell errors + logging). estimatedPoints=2. DoR met."; }
    part robustStartupRefineGateR1 : TestResult { :>> id = "e89433a3-b305-465f-845e-807aad938fcc"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "cf7899d"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; }
    verification robustStartupStandupGate : Test { :>> id = "367519d5-f9cc-481f-88d1-be78da10f9cf"; :>> title = "Sprint 16 standup gate"; :>> createdAt = "2026-07-02"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "Approach: main.rs logs a 0-vaults warning; build_shell returns a descriptive Err; index_handler gains State<VaultRegistry>, serves a no-vaults page when empty + a diagnostic page on shell error via a diagnostic_page helper. TDD the no-vaults page. No blockers."; }
    part robustStartupStandupGateR1 : TestResult { :>> id = "ad085ea8-beaf-48dc-a1be-8795c9b291a9"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "cf7899d"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; }
    verification robustStartupImplementGate : Test { :>> id = "a8c328aa-a0da-42ab-9ba2-8ae5bda02a76"; :>> title = "Sprint 16 implement gate"; :>> createdAt = "2026-07-02"; :>> createdBy = "ai"; :>> method = VerificationMethod::test; :>> procedureText = "Built test-first (no-vaults test would 500 pre-change -> now 200 'No vaults found'). 83 tests pass; clippy -D warnings + fmt clean. Verified live at 4250086. (Also cleared a stray leftover test process holding target/ that caused a transient LNK1104.)"; }
    part robustStartupImplementGateR1 : TestResult { :>> id = "e16e6eea-422b-4b9b-b2e2-7a9cb5886e7d"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "4250086"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; }
    verification robustStartupReviewGate : Test { :>> id = "8a9c870d-3518-4281-951a-1eb10f5e4139"; :>> title = "Sprint 16 review gate"; :>> createdAt = "2026-07-02"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "Reviewed: the no-vaults + shell-error pages turn opaque failures into actionable messages (the exact field complaint); errors name the offending path; startup warning guides the mount. HTML is escaped. Good UX/robustness fix; resolves issue014."; }
    part robustStartupReviewGateR1 : TestResult { :>> id = "fab16d62-f9b7-4717-96e0-487969016d62"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "4250086"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; }
    verification robustStartupCloseOutGate : Test { :>> id = "1587614c-674a-405b-8d52-f7aaea602915"; :>> title = "Sprint 16 closeOut gate (autonomous, D0049)"; :>> createdAt = "2026-07-02"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "Autonomous closeOut (D0049): DoD pass; issue014 resolved (blank-page -> clear diagnostics). cargo test (83) + clippy + keel validate/guard green. The browser demo (issue013) can now report a clear state on any misconfig."; }
    part robustStartupCloseOutGateR1 : TestResult { :>> id = "4f690e90-e8a7-4dff-8301-3b203604f492"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "4250086"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; }
    verification robustStartupRetroGate : Test { :>> id = "2e9a8906-dd7d-4b91-b2e5-1d337fa01f01"; :>> title = "Sprint 16 retro gate (autonomous, D0049)"; :>> createdAt = "2026-07-02"; :>> createdBy = "ai"; :>> method = VerificationMethod::analyze; :>> procedureText = "Autonomous retro (D0049). WELL: the human demo (issue013) immediately earned its keep - first real run surfaced a genuine UX bug (blank on 0 vaults) that no unit test would have flagged; fixed same-turn with a clear no-vaults page + path-naming shell errors. AVOIDABLE-ISSUE SCAN: no new tracked issues; noted a stray leftover test process (LNK1104) - a reminder to reap test-spawned server processes. LESSON: the first end-to-end run of a server is where the empty/misconfig UX gets exercised - fail LOUD + actionable, never blank. Estimate 2pt held."; }
    part robustStartupRetroGateR1 : TestResult { :>> id = "e3b99177-b280-4b3a-af85-0f085c5e7b65"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "4250086"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; }
}
