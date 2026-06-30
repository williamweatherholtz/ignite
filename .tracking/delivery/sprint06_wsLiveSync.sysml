// IgniteDeliveryS06 — Sprint 6: WebSocket live sync (the WS half of srLiveSync). Puts the
// live index's change events on the wire to the browser, wire-compatible with Ignis c9656b8,
// applying dCritiqueEfficiency #5 (serialize once, backpressure, batch). PLANNED to standup;
// implement gate pends the build.
package IgniteDeliveryS06 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    // chartered by srLiveSync (IgniteRequirements); name-ref, no import.
    #CharteredBy dependency from wsLiveSyncStory to srLiveSync;

    part wsLiveSyncStory : Story {
        :>> id = "05bf316d-3f88-47fa-b2e4-9adc91268aff";
        :>> title = "Sprint 6: live sync over WebSocket - watcher events reach the browser (WS half of srLiveSync)";
        :>> createdAt = "2026-06-30"; :>> createdBy = "will"; :>> kind = WorkKind::code; :>> priority = WorkPriority::p0; :>> owner = "ai"; :>> estimatedPoints = 8;
    }

    action def DeliveryRunS06 {
        action storyWsLiveSync;
        verification storyWsLiveSyncDoD : Test { :>> id = "7653afef-37f1-40df-9c49-eaa6fda52922"; :>> method = VerificationMethod::test; :>> procedureText = "Live file changes reach connected browsers over WebSocket, wire-compatible with Ignis c9656b8, completing srLiveSync. (1) /ws?vault=<v> upgrade (vault query required; unknown/missing vault rejected). (2) the live index's watcher publishes each applied change as a TYPED event and the server broadcasts it to all clients on that vault: { type: 'created'|'modified'|'deleted'|'folder-created', path: <posix rel>, stat?: { size, mtime, ctime } } (stat for created/modified). (3) client->server control messages handled: subscribe-channel / unsubscribe-channel. (4) 30s ping/pong heartbeat. (5) dCritiqueEfficiency #5: each event serialized ONCE (broadcast the serialized message, not per-client), send honors backpressure (a lagging client recovers/drops rather than buffering unboundedly), burst events coalesced (300ms watcher debounce + batched send). VERIFY (tests): a WS client connects with ?vault, a file is created/modified/deleted on disk, and the client receives the correctly-typed, correctly-shaped event within the bound; a 2nd client on the same vault also receives it; heartbeat observed. clippy -D warnings + cargo test green; keel validate + guard green."; }
    }

    verification wsLiveSyncRefineGate : Test { :>> id = "b3c92791-a76a-4c77-97d4-952993eddf68"; :>> title = "Sprint 6 refine gate (DoR)"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: the WS half of srLiveSync, building on the sprint05 live index. Ignis /ws protocol known from the c9656b8 inventory; dCritiqueEfficiency #5 is an explicit acceptance criterion. INVEST: Independent (depends only on the now-built live index); Valuable (browsers finally see live updates - completes srLiveSync); Estimable (8pts - WS endpoint + per-vault broadcast wired to the watcher + heartbeat); Small (one sprint); Testable (WS integration tests). DoR met."; }
    part wsLiveSyncRefineGateR1 : TestResult { :>> id = "22b0b7d3-fdf7-49ec-9875-d00b9b2d69dd"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "2c0c489"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
    verification wsLiveSyncStandupGate : Test { :>> id = "65b4961f-77c7-4143-9095-40b1a76612b3"; :>> title = "Sprint 6 standup gate"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "Approach: give each VaultIndex a tokio broadcast::Sender<String>; apply_paths derives the typed event per path (exists+new=created/folder-created, exists+changed=modified, gone=deleted), serializes ONCE, and broadcasts the message text. An axum /ws handler resolves the vault, subscribes to its broadcast, selects over {recv -> ws.send, client msg -> subscribe-channel/pong, 30s ping}. Lagged receiver -> drop/recover. TDD with a real WS client (tokio-tungstenite) or axum test util. No blockers; implement gate pends the build."; }
    part wsLiveSyncStandupGateR1 : TestResult { :>> id = "9d0d7935-4b3a-4789-8f5e-d4b8fbee6237"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "2c0c489"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
}
