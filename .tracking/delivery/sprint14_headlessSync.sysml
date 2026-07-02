// IgniteDeliveryS14 — Sprint 14: native headless-sync (dPlugins) — Obsidian-Sync compat.
// A Rust server-plugin trait + the headless-sync plugin (obsidian-headless CLI wrapper +
// /api/ext/headless-sync/* routes + the plugin:headless-sync WS channel). Also consumes the
// subscribe-channel tracking from sprint06. PLANNED to standup; implement gate pends the build.
package IgniteDeliveryS14 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    #CharteredBy dependency from headlessSyncStory to srWireCompat;

    part headlessSyncStory : Story {
        :>> id = "29206cc3-ed6d-4de3-b80b-f039ece9d863";
        :>> title = "Sprint 14: native headless-sync (Rust plugin trait + obsidian-headless CLI + WS channel) (dPlugins, srWireCompat)";
        :>> createdAt = "2026-07-02"; :>> createdBy = "will"; :>> kind = WorkKind::code; :>> priority = WorkPriority::p2; :>> owner = "ai"; :>> estimatedPoints = 8;
    }

    action def DeliveryRunS14 {
        action storyHeadlessSync;
        verification storyHeadlessSyncDoD : Test { :>> id = "28c81dc8-9ef2-4375-af61-f00cb5f4c350"; :>> method = VerificationMethod::test; :>> procedureText = "Native headless-sync per dPlugins, wire-compatible with Ignis c9656b8 (check apps/ignis-server/server/plugins/headless-sync/ - routes.js, sync-manager.js, ob-cli.js, broadcaster.js). (1) A Rust SERVER-PLUGIN trait (register routes + a WS channel + shutdown) - the seam dPlugins called for. (2) The headless-sync plugin implementing it: /api/ext/headless-sync/{status,login,logout,setup,start,stop,unlink,logs,vaults,create-remote-vault,remote-vaults} with the Ignis shapes ({installed,version,authenticated,email,name}; {success,state}; {logs:[]}; {vaults:{}}; etc.); wraps the obsidian-headless CLI via an INJECTED runner trait (so tests use a fake, no real CLI needed); persists token + per-vault sync state as JSON in a plugin data dir (DATA_ROOT/plugins/headless-sync). (3) Broadcast sync-log / sync-status on the plugin:headless-sync WS channel - CONSUMING the subscribe-channel tracking added in sprint06 (wire channel-scoped broadcast into ws.rs). (4) GET /api/plugins now lists headless-sync. VERIFY (tests, fake CLI runner + tempdir data dir): status reflects auth state; login persists + round-trips; setup/start/stop update + return state; logs/vaults shapes; a WS client subscribed to plugin:headless-sync receives a sync-status broadcast; /api/plugins includes headless-sync. clippy -D warnings + cargo test green; keel validate + guard green. HONEST: real obsidian-headless CLI integration is NOT tested (CLI absent) - the runner is faked; note it."; }
    }

    verification headlessSyncRefineGate : Test { :>> id = "090a9e23-e913-4d5c-bc34-cee3c2e4a701"; :>> title = "Sprint 14 refine gate (DoR)"; :>> createdAt = "2026-07-02"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: native headless-sync (dPlugins) - the last srWireCompat feature. Shapes + behavior from the cloned headless-sync plugin source. Testable via an injected fake CLI runner (real CLI absent). INVEST: Independent (new module + a WS-channel hook); Valuable (Obsidian-Sync compat); Estimable (8pts - plugin trait + ~11 routes + CLI wrapper + WS channel + state); Small-ish (one sprint); Testable (fake runner + tempdir). DoR met."; }
    part headlessSyncRefineGateR1 : TestResult { :>> id = "7d940fd6-3341-45e1-bdfd-2af1a1fb4423"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "a04e7fd"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; }
    verification headlessSyncStandupGate : Test { :>> id = "b027a6aa-ce14-4615-8f6a-9feae3bde6fe"; :>> title = "Sprint 14 standup gate"; :>> createdAt = "2026-07-02"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "Approach: define a ServerPlugin trait (id/name + routes + optional WS channel + shutdown); implement HeadlessSyncPlugin with an injected CliRunner trait (real = std::process obsidian-headless; test = fake); persist token/state JSON under DATA_ROOT/plugins/headless-sync; extend ws.rs with channel-scoped broadcast (consume the subscribe-channel set) + a broadcaster the plugin uses for sync-log/sync-status; wire the ext routes + /api/plugins listing. TDD with the fake runner + tempdir. No blockers; implement gate pends the build."; }
    part headlessSyncStandupGateR1 : TestResult { :>> id = "6ceacd11-a2d5-4262-99ee-452dcb5e9a34"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "a04e7fd"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; }
}
