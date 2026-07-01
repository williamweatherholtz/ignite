// IgniteDeliveryS07 — Sprint 7: the fs CRUD endpoints (read + write), wire-compatible with
// Ignis c9656b8, under srWireCompat. Applies dCritiqueCorrectness #3 (honest, durable writes -
// real mtime/size, no synthetic metadata, no coalescing). Writes propagate live via the
// existing notify watcher. PLANNED to standup; implement gate pends the build.
package IgniteDeliveryS07 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    // chartered by srWireCompat (IgniteRequirements); name-ref, no import.
    #CharteredBy dependency from fsCrudStory to srWireCompat;

    part fsCrudStory : Story {
        :>> id = "1aaabe14-302b-42cd-8d50-91aec8e58ab3";
        :>> title = "Sprint 7: fs CRUD endpoints (stat/readdir/readFile/writeFile/... ) - honest durable writes (srWireCompat)";
        :>> createdAt = "2026-06-30"; :>> createdBy = "will"; :>> kind = WorkKind::code; :>> priority = WorkPriority::p0; :>> owner = "ai"; :>> estimatedPoints = 8;
    }

    action def DeliveryRunS07 {
        action storyFsCrud;
        verification storyFsCrudDoD : Test { :>> id = "a41b2022-517d-4a04-8307-a5fbb72545a5"; :>> method = VerificationMethod::test; :>> procedureText = "Implement the fs CRUD routes wire-compatible with Ignis c9656b8: GET /api/fs/stat -> {type,size,mtime,ctime}; GET /api/fs/readdir -> [{name,type}]; GET /api/fs/readFile (encoding param; text or binary); POST /api/fs/writeFile {path,content,encoding?,base64?} -> {ok,mtime,size}; POST /api/fs/appendFile -> {ok}; POST /api/fs/mkdir {path,recursive?} -> {ok}; POST /api/fs/rename {oldPath,newPath} -> {ok}; POST /api/fs/copyFile {src,dest} -> {ok}; DELETE /api/fs/unlink|rmdir|rm(recursive) -> {ok}; GET /api/fs/access -> {ok}; POST /api/fs/utimes -> {ok}; POST /api/fs/batch-read {paths[]} -> {files:{relPath:content}}. CONSTRAINTS: (a) every path resolved WITHIN the vault (reject traversal / leading-slash escape); (b) dCritiqueCorrectness #3 - writeFile does a real write and returns the REAL mtime/size from the actual write (no synthetic metadata, no coalescing acked-before-disk); (c) writes are picked up by the existing live watcher (event-based, no manual index mutation) so the index + WS stay correct. VERIFY (axum oneshot tests + tempdir vault): each endpoint's status + shape matches Ignis; write then stat/readFile round-trips; traversal attempt rejected; a write is reflected in the live index/tree. clippy -D warnings + cargo test green; keel validate + guard green. (download + download-zip are a later sprint.)"; }
    }

    verification fsCrudRefineGate : Test { :>> id = "f629957e-1a02-4c50-97ea-50d65e5999a0"; :>> title = "Sprint 7 refine gate (DoR)"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: the fs CRUD half of srWireCompat. Route shapes known from the c9656b8 inventory; dCritiqueCorrectness #3 (honest durable writes) + within-vault path security are explicit criteria. INVEST: Independent (adds routes on the existing app + index); Valuable (Obsidian can read + SAVE through Ignite); Estimable (8pts - ~14 mechanical routes + path guard + write honesty); Small-ish (one sprint; download/zip deferred); Testable (per-route oneshot tests). DoR met."; }
    part fsCrudRefineGateR1 : TestResult { :>> id = "96cef2d2-bfab-4fae-ad44-d05d7cca753e"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "c692f79"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
    verification fsCrudStandupGate : Test { :>> id = "85914ffd-0d4a-4aee-8e89-c6e75958e1bf"; :>> title = "Sprint 7 standup gate"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "Approach: a routes/fs module + a resolve_in_vault(vault, rel) -> PathBuf guard (reject traversal); each handler maps to std::fs / tokio::fs with the exact Ignis JSON shape; writeFile returns real fs metadata post-write (fsync for durability). No write-coalescing. Rely on the live watcher for index/WS propagation. TDD each route with axum oneshot + a tempdir vault. No blockers; implement gate pends the build."; }
    part fsCrudStandupGateR1 : TestResult { :>> id = "99442cff-ac84-4710-b2ba-f0996f80e65b"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "c692f79"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
}
