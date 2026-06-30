// IgniteDeliveryS03 — Sprint 3: honest end-to-end Ignite-vs-Ignis benchmark in Docker's
// bind-mount context (resolves issue004). Covers the dockerContextBench backlog action.
// IN PROGRESS: refine + standup passed; the Dockerfile + harness are authored, but the
// implement gate is PENDING until Docker Desktop is running and the measurement is taken
// (D0051 - no fabricated evidence; the implement gate's evidence is the real in-Docker run).
package IgniteDeliveryS03 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    // dockerContextBench (IgniteBacklog) referenced by name in the #CharteredBy edge (no import).
    #CharteredBy dependency from dockerContextBenchStory to dockerContextBench;

    part dockerContextBenchStory : Story {
        :>> id = "f9a8d054-bd97-436d-8cee-fda46d09eb33";
        :>> title = "Sprint 3: benchmark Ignite in Docker's bind-mount context for an honest end-to-end Ignis comparison (resolves issue004)";
        :>> createdAt = "2026-06-30"; :>> createdBy = "will"; :>> kind = WorkKind::research; :>> priority = WorkPriority::p1; :>> owner = "ai"; :>> estimatedPoints = 2;
    }

    action def DeliveryRunS03 {
        action storyDockerContextBench;
        verification storyDockerContextBenchDoD : Test { :>> id = "7376ce21-16fe-4110-8335-75d0e68a5e72"; :>> method = VerificationMethod::test; :>> procedureText = "Fill the Docker row of the 2x2 matrix {Ignite parallel-Rust, Ignis-algorithm sequential-Node} x {native, Docker}. Build the Ignite image (binary on container FS), run ignite-bench against the Games vault bind-mounted at /vault (same mechanism Ignis uses), and run the Node Ignis-algorithm baseline in a node container on the same mount. Record both Docker numbers; compare to the recorded native numbers (Ignite ~20ms; Node 657/216ms). VERIFY: state the TRUE end-to-end Ignis-vs-Ignite factor in the user's actual deployment context, and attribute the original 72-214s between Docker-FS overhead vs algorithm."; }
    }

    verification dockerContextBenchRefineGate : Test { :>> id = "6e236ba2-8c16-4087-8b3a-cbcea5d8bcf7"; :>> title = "Sprint 3 refine gate (DoR)"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: issue004 needs an apples-to-apples Docker-context measurement. Approach is clear (multi-stage Dockerfile: binary on fast FS, only vault bind-mounted; node container for the Ignis-algorithm baseline). Vault path known (Downloads/Games). Blocked only on Docker Desktop running (a runtime precondition, not a design gap). DoR met."; }
    part dockerContextBenchRefineGateR1 : TestResult { :>> id = "89783367-1f37-44d4-97ba-72b2e2230e53"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "be574c4"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
    verification dockerContextBenchStandupGate : Test { :>> id = "c484f302-ff9c-43b0-8994-d163c5a8023b"; :>> title = "Sprint 3 standup gate"; :>> createdAt = "2026-06-30"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "Approach implemented and committed: server/Dockerfile (multi-stage, binary on container FS, only /vault bind-mounted), server/bench/ignis-walk-baseline.js (in-Docker Node baseline), server/bench/run-docker-bench.ps1 (runs both, prints both). Precondition: user starts Docker Desktop, then `pwsh server/bench/run-docker-bench.ps1 <vault>`. No design blockers; implement gate pends the live run."; }
    part dockerContextBenchStandupGateR1 : TestResult { :>> id = "6c843e32-77b6-4102-89d1-b696c00e7db7"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "be574c4"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "ai"; }
}
