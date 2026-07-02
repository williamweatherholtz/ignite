// IgniteDeliveryS15 — Sprint 15: the Docker image (dDeploymentDirection). Multi-stage build
// (Rust binary + Ignis browser JS + runtime Obsidian download) + compose + entrypoint. The
// AI-verifiable DoD is: image builds + in-container server smoke test. The full browser-loads-
// Obsidian check is a SEPARATE human demo (D0049). PLANNED to standup; implement gate pends build.
package IgniteDeliveryS15 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    // chartered by the deployment Decision it realizes (name-ref, no import).
    #CharteredBy dependency from dockerImageStory to dDeploymentDirection;

    part dockerImageStory : Story {
        :>> id = "7ebae27d-bdb0-4912-bfbf-51b2dde8626a";
        :>> title = "Sprint 15: Docker image - Rust binary + Ignis JS + runtime Obsidian download + compose (dDeploymentDirection)";
        :>> createdAt = "2026-07-02"; :>> createdBy = "will"; :>> kind = WorkKind::code; :>> priority = WorkPriority::p1; :>> owner = "ai"; :>> estimatedPoints = 5;
    }

    action def DeliveryRunS15 {
        action storyDockerImage;
        verification storyDockerImageDoD : Test { :>> id = "24370e1c-78d7-4aad-9448-b275266feaf5"; :>> method = VerificationMethod::test; :>> procedureText = "Ship Ignite as a Docker image per dDeploymentDirection. (1) A multi-stage Dockerfile at repo root: (a) rust:1 builds the ignite-server release binary; (b) a node stage clones Ignis@c9656b8 + builds its browser JS (packages/ui + shim); (c) a debian-slim runtime with the binary + built Ignis JS + an entrypoint that downloads the Obsidian bundle at runtime (mirroring Ignis's entrypoint) and execs ignite-server; env VAULT_ROOT=/vaults, OBSIDIAN_ASSETS_PATH, IGNITE_UI_DIST, IGNITE_SHIM_DIST, PORT=8080; VOLUME /vaults. (2) docker-compose.yml (vault bind-mount + port). AI-VERIFIABLE (method=test/inspect): `docker build` succeeds; `docker run` with a bind-mounted test vault -> GET /api/version, /api/vault/list, and /api/bootstrap respond correctly in-container. NOTE: the FULL end-to-end (a browser loads + operates Obsidian against the container) is a SEPARATE human demo verification (method=demo, D0049) - NOT self-attested here."; }
    }

    verification dockerImageRefineGate : Test { :>> id = "9b9092de-8f02-435e-b92c-5a8f30e8e855"; :>> title = "Sprint 15 refine gate (DoR)"; :>> createdAt = "2026-07-02"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: the Docker ship target (dDeploymentDirection - Docker only, reuse Ignis JS). Model mirrors Ignis's Docker entrypoint (runtime Obsidian download). Scope split: AI verifies build + server smoke; the browser-loads-Obsidian demo is a human gate. INVEST: Independent (packaging over the finished server); Valuable (runnable Ignite); Estimable (5pts - Dockerfile + compose + entrypoint); Small; Testable (docker build + in-container curl). DoR met."; }
    part dockerImageRefineGateR1 : TestResult { :>> id = "cb02707f-b000-4820-bdec-a54dbd9348a5"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "6cf33e2"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; }
    verification dockerImageStandupGate : Test { :>> id = "761f881d-ac45-479d-a442-452cf76127d7"; :>> title = "Sprint 15 standup gate"; :>> createdAt = "2026-07-02"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "Approach: repo-root Dockerfile (rust:1 build stage -> ignite-server; node stage clones Ignis@c9656b8 + builds ui/shim; debian-slim runtime + entrypoint.sh that fetches the Obsidian bundle then execs the server); docker-compose.yml with a /vaults bind-mount + PORT. Verify with docker build + docker run + curl /api/version|vault/list|bootstrap against a test vault. Hand the browser-load demo to will. No blockers; implement gate pends the build + smoke."; }
    part dockerImageStandupGateR1 : TestResult { :>> id = "1967ece1-b0d7-46dc-b547-289f3cfed84e"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "6cf33e2"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; }
}
