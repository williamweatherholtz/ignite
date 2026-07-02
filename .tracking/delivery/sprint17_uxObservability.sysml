// IgniteDeliveryS17 — Sprint 17: field-feedback UX + observability. One-knob .env config
// (resolves issue016 - VAULT_ROOT/VAULTS_DIR confusion) + per-request logging (resolves issue015
// - poor debug logs). Done at 0848e0a.
package IgniteDeliveryS17 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    #CharteredBy dependency from uxObservabilityStory to srWireCompat;
    #Resolves dependency from storyUxObservability to issue015;
    #Resolves dependency from storyUxObservability to issue016;

    part uxObservabilityStory : Story {
        :>> id = "a59f0f7f-88cc-45fc-9535-5b62453ff9e4";
        :>> title = "Sprint 17: one-knob .env config + per-request logging (field feedback)";
        :>> createdAt = "2026-07-02"; :>> createdBy = "will"; :>> kind = WorkKind::code; :>> priority = WorkPriority::p1; :>> owner = "ai"; :>> estimatedPoints = 3;
    }

    action def DeliveryRunS17 {
        action storyUxObservability;
        verification storyUxObservabilityDoD : Test { :>> id = "a8f561e2-a7b1-4249-a859-c0c8efbdd0d9"; :>> method = VerificationMethod::test; :>> procedureText = "Field feedback from the demo. (1) CONFIG (issue016): collapse vault config to ONE knob - VAULT_ROOT (the fixed in-container path /vaults) is removed from both compose files; the only setting is VAULTS_DIR (host vaults dir) via a new .env (compose auto-reads it). Add .env.example, gitignore .env. (2) LOGGING (issue015): add tracing + tracing-subscriber (level via RUST_LOG, default info) + a log_requests middleware that logs every request's method/path/status/latency; route startup logs through tracing too. VERIFY: 83 tests pass (middleware is transparent); clippy -D warnings + fmt clean; a container run emits per-request log lines (confirmed via the image rebuild)."; }
        part storyUxObservabilityDoDR1 : TestResult { :>> id = "bd3dd510-996d-4d35-8d6d-f3fdd3bcf8ba"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0848e0a"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; :>> notes = "compose: VAULT_ROOT removed (fixed /vaults in Dockerfile); VAULTS_DIR is the only knob, via .env (+ .env.example, .env gitignored). main.rs: tracing_subscriber (RUST_LOG default info) + startup logs via tracing::info!/warn!. app.rs: log_requests middleware (outermost layer) logs method/path/status/latency_ms per request. 83 tests pass (transparent middleware), clippy + fmt clean."; }
    }

    verification uxObservabilityRefineGate : Test { :>> id = "8b075c5e-2e8c-4ac9-8af5-32a6315044ee"; :>> title = "Sprint 17 refine gate (DoR)"; :>> createdAt = "2026-07-02"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: two field-reported UX gaps (config confusion issue016; poor logs issue015). Clear, small, testable. estimatedPoints=3. DoR met."; }
    part uxObservabilityRefineGateR1 : TestResult { :>> id = "56d9847f-b6ce-48bf-a190-6979606f72d9"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "e7d3f44"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; }
    verification uxObservabilityStandupGate : Test { :>> id = "bbbcbef8-3a38-4a95-9c69-74db58f30362"; :>> title = "Sprint 17 standup gate"; :>> createdAt = "2026-07-02"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "Approach: remove VAULT_ROOT from compose + add .env/.env.example (one knob = VAULTS_DIR); add tracing + tracing-subscriber + a log_requests from_fn middleware (outermost) + convert startup println! to tracing. No blockers."; }
    part uxObservabilityStandupGateR1 : TestResult { :>> id = "f4e13557-9d7e-4813-9e8d-0b43a784ec67"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "e7d3f44"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; }
    verification uxObservabilityImplementGate : Test { :>> id = "04f97121-8a1a-407f-938d-840998a7e71c"; :>> title = "Sprint 17 implement gate"; :>> createdAt = "2026-07-02"; :>> createdBy = "ai"; :>> method = VerificationMethod::test; :>> procedureText = "Implemented: .env one-knob config + tracing/log_requests. 83 tests pass; clippy -D warnings + fmt clean. Verified live at 0848e0a; image rebuilt."; }
    part uxObservabilityImplementGateR1 : TestResult { :>> id = "24730d62-26dd-4ccb-93ef-d3c85af4db7e"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0848e0a"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; }
    verification uxObservabilityReviewGate : Test { :>> id = "700f600c-ac26-465b-afbe-97423052fd2d"; :>> title = "Sprint 17 review gate"; :>> createdAt = "2026-07-02"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "Reviewed: config is now genuinely one knob (VAULT_ROOT off the compose surface; .env is the single place); the request log matches Ignis's style + is RUST_LOG-tunable; middleware is outermost so it reports the final (post-compression) status. Directly answers both field complaints. Sound."; }
    part uxObservabilityReviewGateR1 : TestResult { :>> id = "6b5cf082-2e2c-4063-a4f9-41ca0891d9c7"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0848e0a"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; }
    verification uxObservabilityCloseOutGate : Test { :>> id = "74f40b3b-8c5f-4d39-bc0f-32555716909b"; :>> title = "Sprint 17 closeOut gate (autonomous, D0049)"; :>> createdAt = "2026-07-02"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "Autonomous closeOut (D0049): DoD pass; issue015 (logging) + issue016 (config confusion) resolved. cargo test (83) + clippy + keel validate/guard green. Per-request logs now make the issue013 browser demo debuggable (the browser's fetches + 404s are visible)."; }
    part uxObservabilityCloseOutGateR1 : TestResult { :>> id = "efb3a124-787f-4176-b0d5-bb0a85f44e25"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0848e0a"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; }
    verification uxObservabilityRetroGate : Test { :>> id = "ed07e47a-e488-4668-aac9-0d3023cb442c"; :>> title = "Sprint 17 retro gate (autonomous, D0049)"; :>> createdAt = "2026-07-02"; :>> createdBy = "ai"; :>> method = VerificationMethod::analyze; :>> procedureText = "Autonomous retro (D0049). WELL: the demo keeps surfacing real UX gaps (dual-var confusion, no request logs) that no unit test would flag - fixed both same-session. AVOIDABLE-ISSUE SCAN: no new tracked issues; the two field reports are now issue015/016 resolved. LESSON: a two-layer Docker config (host var vs container env) is inherently confusing - expose ONE knob + hide the internal path; and a server without per-request logs is undebuggable in the field - request logging is table stakes, not polish. Estimate 3pt held."; }
    part uxObservabilityRetroGateR1 : TestResult { :>> id = "cb3681cd-bd0d-4947-b166-8fd9da923a51"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0848e0a"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; }
}
