// IgniteDeliveryS05 — Sprint 5: the LIVE INDEX (the index half of srLiveSync). A notify
// watcher keeps the warm VaultIndex correct as files change, honoring dCritiqueCorrectness
// (#1 continuous-watch + reconcile; #2 event-based incremental invalidation). The WebSocket
// delivery layer is sprint06. PLANNED to standup; implement gate pends the build.
package IgniteDeliveryS05 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    // chartered by srLiveSync (IgniteRequirements); name-ref, no import.
    #CharteredBy dependency from liveIndexStory to srLiveSync;

    part liveIndexStory : Story {
        :>> id = "9d788f2d-a076-4cac-9e49-e7d199dc95ea";
        :>> title = "Sprint 5: live index - notify watcher keeps the warm index correct (index half of srLiveSync)";
        :>> createdAt = "2026-06-30"; :>> createdBy = "will"; :>> kind = WorkKind::code; :>> priority = WorkPriority::p0; :>> owner = "ai"; :>> estimatedPoints = 8;
    }

    action def DeliveryRunS05 {
        action storyLiveIndex;
        verification storyLiveIndexDoD : Test { :>> id = "339131c5-3587-474c-8552-5e08b9c29244"; :>> method = VerificationMethod::test; :>> procedureText = "The warm VaultIndex stays correct as the filesystem changes, per dCritiqueCorrectness. (1) a notify-based watcher starts when the index is built and runs CONTINUOUSLY (NOT gated on WS clients) for the index's lifetime; (2) on create/modify/delete/rename/folder events the index updates the affected entry INCREMENTALLY (no full re-walk), keyed on REAL file events (not dir-mtime); (3) on watcher start/restart the index RECONCILES against disk (re-diff) so it can never silently diverge; (4) burst events are debounced (~300ms, matching Ignis awaitWriteFinish). The index must stay thread-safe with lock-free or low-contention reads so warm GET /api/fs/tree stays < 50ms. VERIFY (tests): create -> entry appears; modify -> size/mtime update; delete -> entry gone; rename -> old gone + new present; a change made while the watcher is (re)started is reconciled (no silent divergence); GET /api/fs/tree reflects each within the debounce bound. clippy -D warnings + cargo test green; keel validate + guard green."; }
    }

    verification liveIndexRefineGate : Test { :>> id = "7a1381c5-ff74-4eb6-ad76-2dbe79851508"; :>> title = "Sprint 5 refine gate (DoR)"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: srLiveSync sliced into the index half (this) + the WS half (sprint06). Constraints from dCritiqueCorrectness (#1 continuous-watch+reconcile, #2 event-based invalidation) are explicit acceptance criteria. INVEST: Independent (builds on the existing VaultIndex; no unfinished dep); Valuable (the live-correct index, prerequisite to live sync); Estimable (8pts - notify + thread-safe incremental index + reconcile); Small (one sprint); Testable (FS-mutation + reconcile tests). DoR met."; }
    part liveIndexRefineGateR1 : TestResult { :>> id = "6860bb70-3166-4ea2-b314-be53155343f8"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "c68ed6a"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
    verification liveIndexStandupGate : Test { :>> id = "71251be1-744e-4845-837b-0ea212dcb80f"; :>> title = "Sprint 5 standup gate"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "Approach: make VaultIndex interior-mutable for lock-free reads (arc-swap ArcSwap<Tree>, or RwLock<Tree>); spawn a notify-debouncer-full watcher per vault at build time on a background thread; map debounced events to incremental tree mutations; reconcile (re-walk + diff) on watcher start. TDD each FS-mutation case with a tempdir + a bounded wait helper. No blockers; implement gate pends the build."; }
    part liveIndexStandupGateR1 : TestResult { :>> id = "a218488d-9681-4df2-b5b9-7c7a8cea196f"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "c68ed6a"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
}
