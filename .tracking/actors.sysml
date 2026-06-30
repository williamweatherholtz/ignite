// ProjectActors — this project's actor registry (INSTANCE data). EDIT to your real actors.
// The declared part name is the id that createdBy/judgedBy reference (enforced by `keel guard actors`).
package ProjectActors {
    private import EngineElement::*;

    part will : Person { :>> name = "William Weatherholtz"; :>> email = "0612@asirobots.com"; }
    part ai : Actor { :>> name = "Claude (AI assistant)"; :>> kind = ActorKind::ai; }
}
