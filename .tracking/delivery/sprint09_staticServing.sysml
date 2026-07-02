// IgniteDeliveryS09 — Sprint 9: static + app-shell serving (srWireCompat). ServeDir for
// assets/ui/shim/obsidian, GET / index.html script-tag injection, /vault-files/<vault>/<path>
// serving, ?v= cache headers. The injection + serving LOGIC (fixture-tested); the real
// Obsidian bundle + built Ignis JS are deploy-time assets (a later deployment task).
// PLANNED to standup; implement gate pends the build.
package IgniteDeliveryS09 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    // chartered by srWireCompat (IgniteRequirements); name-ref, no import.
    #CharteredBy dependency from staticServingStory to srWireCompat;

    part staticServingStory : Story {
        :>> id = "09fcceb1-7f64-435f-9d59-5d566ebe98a2";
        :>> title = "Sprint 9: static + app-shell serving - index.html injection + /vault-files + ServeDir (srWireCompat)";
        :>> createdAt = "2026-07-02"; :>> createdBy = "will"; :>> kind = WorkKind::code; :>> priority = WorkPriority::p1; :>> owner = "ai"; :>> estimatedPoints = 8;
    }

    action def DeliveryRunS09 {
        action storyStaticServing;
        verification storyStaticServingDoD : Test { :>> id = "9b140ffa-a8ae-4c6b-9c3e-9f43947fb796"; :>> method = VerificationMethod::test; :>> procedureText = "Serve the app shell wire-compatible with Ignis c9656b8 (check index.js:124-174 in the cloned source for the exact injection): (1) GET / (and /index.html) returns HTML built by discovering Obsidian's <script src> tags from the Obsidian bundle's index.html, version-stamping them, and injecting them + the Ignis shim-loader/ui scripts into the ignis template; (2) static file serving (tower-http ServeDir) for the assets dir, the built ui/shim dist, and the Obsidian assets dir (paths from env: OBSIDIAN_ASSETS_PATH etc.); (3) GET /vault-files/<vaultId>/<relpath> serves vault files (images/attachments) with WITHIN-VAULT path security (reuse the traversal guard); (4) ?v=<version> cache-control headers. VERIFY (fixture tests): given a fake Obsidian index.html (with script tags) + a template, GET / produces HTML containing the injected + version-stamped scripts; a static asset is served from a fixture dir; /vault-files serves a file from a tempdir vault and REJECTS traversal; unknown paths 404. clippy -D warnings + cargo test green; keel validate + guard green. (Acquiring the REAL Obsidian bundle + building Ignis's JS = a deploy-time task, not this sprint.)"; }
    }

    verification staticServingRefineGate : Test { :>> id = "8f23e33d-a356-4390-aaf3-1666f91a43e9"; :>> title = "Sprint 9 refine gate (DoR)"; :>> createdAt = "2026-07-02"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: the app-shell serving surface of srWireCompat. Injection + serving behavior known from Ignis index.js/cache-headers.js. Scoped to the LOGIC (fixture-tested); real-bundle acquisition is deployment. INVEST: Independent (adds serving routes; reuses the fs path guard); Valuable (the shell that, with a real bundle at deploy, makes Obsidian load in a browser); Estimable (8pts - ServeDir + injection + vault-files + cache headers); Small-ish; Testable (fixtures). DoR met."; }
    part staticServingRefineGateR1 : TestResult { :>> id = "67cb84b5-ab2b-42ba-891b-09c9b7a35058"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "1ed1b11"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; }
    verification staticServingStandupGate : Test { :>> id = "7862dad8-4bfc-496c-a5f7-8c1fcf958a44"; :>> title = "Sprint 9 standup gate"; :>> createdAt = "2026-07-02"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "Approach: a static/shell module: read the injection logic from Ignis index.js (discover <script src> in Obsidian's index.html, version-stamp, inject into the ignis template - all path-configurable via env with test fixtures); tower-http ServeDir for assets/ui/obsidian; a /vault-files/:vault/*path handler reusing resolve_in_vault; cache-control by ?v=. TDD injection + vault-files + a served asset against fixtures. No blockers; implement gate pends the build."; }
    part staticServingStandupGateR1 : TestResult { :>> id = "8dcbc4d3-69e6-454c-8ef5-203ba44373b9"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "1ed1b11"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; }
}
