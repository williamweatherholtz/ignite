// IgniteDeploymentDecisions — how Ignite ships + the browser-side stance.
package IgniteDeploymentDecisions {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part dDeploymentDirection : Decision {
        :>> id = "ad57a9b1-d249-4094-89c4-4ff104193051";
        :>> title = "Ship as a Docker image only (native descoped); reuse Ignis's browser JS by default, open to rolling our own";
        :>> createdAt = "2026-07-02";
        :>> createdBy = "will";
        :>> status = DecisionStatus::accepted;
        :>> context = "At the deployment fork (after the full server surface was built), the question was how Ignite ships end-to-end: it needs Ignis's built browser JS (packages/ui + shim) and Obsidian's bundle wired in, and a ship target (Docker vs native vs both). will decided the direction.";
        :>> decision = "Ignite ships as a DOCKER IMAGE as the primary and ONLY supported target - NATIVE deployment is descoped. The Docker image bundles the Rust binary + Ignis's built browser JS and downloads the Obsidian bundle at runtime (mirroring Ignis's model); vaults are bind-mounted. The browser-side JS (Ignis's ui + shim) is REUSED by default; rolling our own browser shim/UI is DEFERRED and remains open ONLY if a compelling performance or architectural reason emerges.";
        :>> rationale = "ALTERNATIVES: (A) native binary target - REJECTED: adds no value over just installing vanilla Obsidian, which runs on most OSs; Ignite's entire value is the self-hosted-in-browser (remote-vault) case, which is the Docker deployment. (B) roll our own browser JS now - REJECTED: reimplementing the Electron-API shim is a large effort and no compelling driver has emerged; reusing Ignis's proven JS is far cheaper and keeps the drop-in contract. (C) Docker-only + reuse-JS-by-default - CHOSEN. CRITERIA: ship the use case that has value (browser/self-host) x least effort to running x keep the door open to a custom browser layer if justified.";
        :>> consequences = "The deployment sprint builds a Dockerfile (Rust build stage + Ignis-JS build/vendor + runtime Obsidian download + vault bind-mount). No native ship target. The Docker bind-mount cold cost (issue005) applies but is mitigated by warm-at-startup. 'Roll our own browser layer' stays an open future option, not current scope. Refines/clarifies dScope (the browser shim is REUSED, not necessarily permanent).";
    }
    verification dDeploymentDirectionAccept : Test { :>> id = "03557410-e6b5-410f-81da-70ab482ac6d7"; :>> method = VerificationMethod::confirmation; :>> procedureText = "will on 2026-07-02: 'docker, but we don't need to reuse Ignis code if theres a compelling performance or architectural reason to just roll our own. but yet - docker image is the key use case here ... we wouldn't need native because Obsidian vanilla installs on most OSs.'"; }
    part dDeploymentDirectionAcceptR1 : TestResult { :>> id = "f751f790-44b5-4b74-a3ff-94f6aef3f88b"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "5b3ee18"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "will"; }

    #DependsOn dependency from dDeploymentDirection to needDropInCompatible;
}
