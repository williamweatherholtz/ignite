// IgniteDeliveryS13 — Sprint 13: /api/fs/download + /api/fs/download-zip (srWireCompat).
// The last fs endpoints; completes the fs surface. PLANNED to standup; implement gate pends build.
package IgniteDeliveryS13 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    #CharteredBy dependency from downloadStory to srWireCompat;

    part downloadStory : Story {
        :>> id = "11bda5d1-7470-40b1-8a2a-5d101701a697";
        :>> title = "Sprint 13: /api/fs/download (file) + /api/fs/download-zip (folder as ZIP) (srWireCompat)";
        :>> createdAt = "2026-07-02"; :>> createdBy = "will"; :>> kind = WorkKind::code; :>> priority = WorkPriority::p2; :>> owner = "ai"; :>> estimatedPoints = 3;
    }

    action def DeliveryRunS13 {
        action storyDownload;
        verification storyDownloadDoD : Test { :>> id = "8372f5da-9ee8-40a7-846b-9179581d3196"; :>> method = VerificationMethod::test; :>> procedureText = "Implement, wire-compatible with Ignis c9656b8 (check fs.js:529-597): GET /api/fs/download?vault&path -> the file bytes with Content-Disposition attachment (error 400/404 on a directory/missing); GET /api/fs/download-zip?vault&path -> the directory zipped (application/zip + Content-Disposition), SKIPPING symlinks (as Ignis does). Reuse resolve_in_vault (within-vault, traversal rejected). Add the `zip` crate. VERIFY (axum oneshot + tempdir vault): download returns a file's bytes + a Content-Disposition header; download on a dir errors; download-zip of a folder returns a valid zip whose entries match the folder's files (unzip in-test + assert); traversal rejected. clippy -D warnings + cargo test green; keel validate + guard green."; }
    }

    verification downloadRefineGate : Test { :>> id = "501564d3-a7c0-4420-9ce9-8ab61a043d53"; :>> title = "Sprint 13 refine gate (DoR)"; :>> createdAt = "2026-07-02"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: the last fs endpoints of srWireCompat. Shapes from fs.js:529-597. INVEST: Independent (adds 2 routes; reuses the path guard); Valuable (file/folder export); Estimable (3pts - 2 routes + zip); Small; Testable (oneshot + in-test unzip). DoR met."; }
    part downloadRefineGateR1 : TestResult { :>> id = "810ca3a0-4c01-4db3-a750-17434602ee02"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "60b3cff"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; }
    verification downloadStandupGate : Test { :>> id = "cd0fee3d-3f92-4ad4-8c4e-fb291508b1cc"; :>> title = "Sprint 13 standup gate"; :>> createdAt = "2026-07-02"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "Approach: add to fs_routes (or a small module): download reads the file + sets Content-Disposition; download-zip walks the dir (skip symlinks), streams entries into a zip (zip crate) with Content-Disposition. Reuse resolve_in_vault. TDD with oneshot + an in-test unzip assertion. No blockers; implement gate pends the build."; }
    part downloadStandupGateR1 : TestResult { :>> id = "027a54be-c741-44bf-9fd5-74b97bef3a28"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "60b3cff"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; }
}
