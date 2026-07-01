// IgniteDeliveryS08 — Sprint 8: /api/bootstrap cold-start bundle + vault/list + vault/info
// (read-only vault ops), wire-compatible with Ignis c9656b8, under srWireCompat. Served from
// the warm registry/index; no registry mutation (vault create/rename/remove is sprint09).
// PLANNED to standup; implement gate pends the build.
package IgniteDeliveryS08 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    // chartered by srWireCompat (IgniteRequirements); name-ref, no import.
    #CharteredBy dependency from bootstrapVaultStory to srWireCompat;

    part bootstrapVaultStory : Story {
        :>> id = "bf2a6d8b-f0c8-4b6f-a857-acbafdc2197a";
        :>> title = "Sprint 8: /api/bootstrap + vault/list + vault/info (read-only) - the cold-start bundle (srWireCompat)";
        :>> createdAt = "2026-06-30"; :>> createdBy = "will"; :>> kind = WorkKind::code; :>> priority = WorkPriority::p0; :>> owner = "ai"; :>> estimatedPoints = 5;
    }

    action def DeliveryRunS08 {
        action storyBootstrapVault;
        verification storyBootstrapVaultDoD : Test { :>> id = "0812b40c-1444-4a2d-8c53-54f0f3b3cb0c"; :>> method = VerificationMethod::test; :>> procedureText = "Implement the read-only vault + cold-start routes wire-compatible with Ignis c9656b8: GET /api/vault/list -> [{id,name,path}]; GET /api/vault/info?vault (default first) -> {id,name,path,platform,version}; GET /api/bootstrap?vault (default first) -> {vault:{id,name,path,platform,version}, vaultList:[{id,name,path}], tree:<Ignis fs/tree shape from the warm index>, plugins:[], virtualPlugins:[], settings:{contentCacheBytes,inputCacheBytes,inputCacheTtlMs,directFetchHosts}}. Derive vault id the same way Ignis does (check the cloned vault.js). platform = OS, version = OBSIDIAN_VERSION env (default matching Ignis). Add a tower-http CompressionLayer so responses (bootstrap/tree) are gzip/br-compressed per Accept-Encoding (Ignis compresses too). VERIFY (axum oneshot tests): vault/list + vault/info shapes; bootstrap returns all six keys with the correct nested shapes and the live tree; unknown vault handled. clippy -D warnings + cargo test green; keel validate + guard green."; }
    }

    verification bootstrapVaultRefineGate : Test { :>> id = "8a8fedb7-414a-47e7-b4b9-83e1b6d7cd9b"; :>> title = "Sprint 8 refine gate (DoR)"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: the read-only cold-start surface of srWireCompat. Shapes known from the c9656b8 inventory + source. Scoped to read-only (list/info/bootstrap) - no registry-mutability refactor (create/rename/remove is sprint09). INVEST: Independent (reads the existing registry + warm index); Valuable (the bundle Obsidian fetches on load - critical-path to loading the app); Estimable (5pts - 3 routes + compression); Small; Testable (oneshot). DoR met."; }
    part bootstrapVaultRefineGateR1 : TestResult { :>> id = "5d3b2287-f2f2-4211-bf06-109728b74b02"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0fdf423"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
    verification bootstrapVaultStandupGate : Test { :>> id = "8c5d7aac-c2fd-46df-a483-858588b61385"; :>> title = "Sprint 8 standup gate"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "Approach: a routes/vault module: vault/list + vault/info from the registry (id per Ignis vault.js, platform=OS, version=OBSIDIAN_VERSION env); /api/bootstrap assembles {vault,vaultList,tree(from warm index),plugins:[],virtualPlugins:[],settings:defaults}; add tower-http CompressionLayer to the router. TDD each with axum oneshot. No blockers; implement gate pends the build."; }
    part bootstrapVaultStandupGateR1 : TestResult { :>> id = "746c53ab-5a1e-438b-9ed8-c4adfa0f75dd"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0fdf423"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
}
