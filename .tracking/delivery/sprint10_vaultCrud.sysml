// IgniteDeliveryS10 — Sprint 10: vault create/rename/remove (srWireCompat). Requires making
// VaultRegistry mutable at runtime (RwLock) so vaults can be added/dropped + their live
// watchers started/stopped. PLANNED to standup; implement gate pends the build.
package IgniteDeliveryS10 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    // chartered by srWireCompat (IgniteRequirements); name-ref, no import.
    #CharteredBy dependency from vaultCrudStory to srWireCompat;

    part vaultCrudStory : Story {
        :>> id = "588077f5-864a-4041-8885-db6a4c182b9d";
        :>> title = "Sprint 10: vault create/rename/remove - runtime-mutable VaultRegistry (srWireCompat)";
        :>> createdAt = "2026-07-02"; :>> createdBy = "will"; :>> kind = WorkKind::code; :>> priority = WorkPriority::p1; :>> owner = "ai"; :>> estimatedPoints = 8;
    }

    action def DeliveryRunS10 {
        action storyVaultCrud;
        verification storyVaultCrudDoD : Test { :>> id = "a3455fad-bdaf-459c-8168-e15a4845aa24"; :>> method = VerificationMethod::test; :>> procedureText = "Implement the vault-mutation routes wire-compatible with Ignis c9656b8 (check vault.js): POST /api/vault/create {name} -> {ok:true,id,path} (create dir + .obsidian subdir; add to registry as a LIVE index); POST /api/vault/rename {vault,name} -> {ok:true,id,path} (rename dir on disk; re-key the registry, watcher tracks the new path); DELETE /api/vault/remove?vault -> {ok:true} (recursively delete the dir; drop the index so its watcher stops). NAME VALIDATION must match Ignis vault.js:11-27: reject / \\ : * ? \" < > |, a leading '.', Windows reserved names (CON/PRN/AUX/NUL/COM1-9/LPT1-9), and > 255 chars (400). REGISTRY: make VaultRegistry interior-mutable (RwLock<HashMap<String, Arc<VaultIndex>>> or similar) so create/remove add/drop entries at runtime; get() returns an Arc snapshot; update every caller (fs_routes/vault_routes/static_routes/ws/app) accordingly, keeping all existing tests green. VERIFY (axum oneshot + tempdir vault-root): create makes a vault that then appears in vault/list + is readable via fs/tree; rename moves it + updates list; remove deletes it + drops it from list; invalid names rejected (400); the ~49 prior tests still pass. clippy -D warnings + cargo test green; keel validate + guard green."; }
    }

    verification vaultCrudRefineGate : Test { :>> id = "1969a91c-b848-4a6e-8c50-0c95334366c6"; :>> title = "Sprint 10 refine gate (DoR)"; :>> createdAt = "2026-07-02"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: vault mutation half of srWireCompat. Shapes + name rules from vault.js. Central change: runtime-mutable registry (RwLock). INVEST: Independent (extends the registry + routes); Valuable (vault management from the UI); Estimable (8pts - registry refactor touching all callers + 3 routes + validation); Small-ish (one sprint); Testable (oneshot). DoR met."; }
    part vaultCrudRefineGateR1 : TestResult { :>> id = "b0a4be3e-1947-415f-a083-4af1aa37e175"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "4f556a9"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; }
    verification vaultCrudStandupGate : Test { :>> id = "fae01c75-b783-41f1-b026-bed08c845b53"; :>> title = "Sprint 10 standup gate"; :>> createdAt = "2026-07-02"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "Approach: refactor VaultRegistry to hold RwLock<HashMap<String, Arc<VaultIndex>>>; get()->Option<Arc<VaultIndex>>; add insert/remove; update all callers to the Arc snapshot. Add a vault-mutation handler set (create/rename/remove) with a validate_vault_name matching vault.js. create -> build_live + insert; remove -> remove (drops Arc -> watcher stops); rename -> fs rename + re-key. TDD each + a full-regression pass. No blockers; implement gate pends the build."; }
    part vaultCrudStandupGateR1 : TestResult { :>> id = "235e6e81-5a34-4ff6-9965-72dcfa74eedc"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "4f556a9"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; }
}
