// IgniteDeliveryS12 — Sprint 12: settings + version + plugins info endpoints (srWireCompat).
// Small config/info surface. Server-plugin listing is [] until native headless-sync (dPlugins).
// PLANNED to standup; implement gate pends the build.
package IgniteDeliveryS12 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    #CharteredBy dependency from settingsStory to srWireCompat;

    part settingsStory : Story {
        :>> id = "0837dfd6-f7b8-461c-842b-9e2abf88b307";
        :>> title = "Sprint 12: /api/settings (get/post) + /api/version + /api/plugins (srWireCompat)";
        :>> createdAt = "2026-07-02"; :>> createdBy = "will"; :>> kind = WorkKind::code; :>> priority = WorkPriority::p2; :>> owner = "ai"; :>> estimatedPoints = 5;
    }

    action def DeliveryRunS12 {
        action storySettings;
        verification storySettingsDoD : Test { :>> id = "86bb750a-f2db-4d5c-82d1-0cd2f22089ff"; :>> method = VerificationMethod::test; :>> procedureText = "Implement, wire-compatible with Ignis c9656b8 (check settings.js/version.js/plugins.js): GET /api/settings -> the effective settings object (defaults + env + persisted settings.json in DATA_ROOT) with Ignis's keys (proxyMode, proxyAllowlist, proxyAllowPrivate, contentCacheBytes, inputCacheBytes, inputCacheTtlMs, writeCoalesceMs, maxBodyBytes, directFetchHosts, wsOrigins); POST /api/settings (partial) -> validates (number ranges, proxy modes, list formats) + persists to settings.json + returns the updated effective settings. GET /api/version -> {version, build, obsidianVersion}. GET /api/plugins -> [] (no server plugins until native headless-sync, dPlugins); POST /api/plugins/:id/enable|disable -> 404 (no such plugin yet). NOTE: writeCoalesceMs is retained as a wire field but is a no-op (coalescing retired per dCritiqueCorrectness #3). VERIFY (axum oneshot): settings GET shape; POST persists + round-trips + rejects invalid; version shape; plugins -> []; enable unknown -> 404. clippy -D warnings + cargo test green; keel validate + guard green."; }
    }

    verification settingsRefineGate : Test { :>> id = "f0804570-4f6d-4d06-bea6-4b672af3c9eb"; :>> title = "Sprint 12 refine gate (DoR)"; :>> createdAt = "2026-07-02"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: the config/info endpoints of srWireCompat. Shapes/validation from settings.js/version.js/plugins.js. INVEST: Independent (self-contained); Valuable (the client reads settings + version on load; plugins list); Estimable (5pts - 3 small route groups + settings persistence + validation); Small; Testable (oneshot). writeCoalesceMs kept as a no-op wire field (dCritiqueCorrectness #3). DoR met."; }
    part settingsRefineGateR1 : TestResult { :>> id = "b69e8220-e8f3-4efe-9966-a61facfdeb0c"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "d31a9ec"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; }
    verification settingsStandupGate : Test { :>> id = "8d117b7c-1916-4b53-a2ab-2546449bad6c"; :>> title = "Sprint 12 standup gate"; :>> createdAt = "2026-07-02"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "Approach: a settings module (Settings struct with Ignis's keys + serde defaults; load = defaults<-env<-settings.json; POST validates + persists to DATA_ROOT/settings.json); version handler ({version=env CARGO_PKG_VERSION or IGNITE_VERSION, build, obsidianVersion=OBSIDIAN_VERSION}); plugins handler returns []; enable/disable -> 404. TDD each with oneshot + a tempdir DATA_ROOT. No blockers; implement gate pends the build."; }
    part settingsStandupGateR1 : TestResult { :>> id = "c8dd9be3-ac29-4151-a2c8-6b302b19149a"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "d31a9ec"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; }
}
