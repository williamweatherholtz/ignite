// IgniteDeliveryS11 — Sprint 11: the CORS/SSRF proxy (srWireCompat), per dProxyWireCompat:
// keep Ignis's base64-JSON wire (shim compat) but bound memory internally (streamed encode).
// PLANNED to standup; implement gate pends the build.
package IgniteDeliveryS11 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    // chartered by srWireCompat (IgniteRequirements); name-ref, no import.
    #CharteredBy dependency from proxyStory to srWireCompat;

    part proxyStory : Story {
        :>> id = "e4a4c64b-d2f4-473d-b402-d778b203f3ba";
        :>> title = "Sprint 11: /api/proxy - base64-JSON wire (shim-compat) + SSRF guard + bounded memory (srWireCompat, dProxyWireCompat)";
        :>> createdAt = "2026-07-02"; :>> createdBy = "will"; :>> kind = WorkKind::code; :>> priority = WorkPriority::p1; :>> owner = "ai"; :>> estimatedPoints = 5;
    }

    action def DeliveryRunS11 {
        action storyProxy;
        verification storyProxyDoD : Test { :>> id = "c9b9cfaf-430c-4631-8cc9-5de58f5d4961"; :>> method = VerificationMethod::test; :>> procedureText = "POST /api/proxy wire-compatible with Ignis c9656b8 (check proxy.js): body {url,method?,headers?,body?,binary?} -> {status,headers,body:<base64>} (KEEP the base64-JSON envelope per dProxyWireCompat - the shim decodes it). SSRF GUARD (proxy.js:16-128): non-private addresses allowed; private/loopback/link-local (10./192.168./172.16-31./127./169.254./FC00::/7/FE80::/10) REJECTED unless in PROXY_ALLOW_PRIVATE_HOSTS; PROXY_MODE (any|allowlist|disabled). Follow redirects (301/302/303/307/308) with an SSRF RE-CHECK at each hop; STRIP Authorization on cross-origin redirect. 50MB response cap. Bound memory: stream the upstream body + encode incrementally (no simultaneous raw+base64 duplicate). Use reqwest. VERIFY (tests, use a local mock/httpbin-style server bound to 127.0.0.1 with PROXY_ALLOW_PRIVATE_HOSTS set so the loopback test target is reachable): a GET proxied -> {status,headers,body:base64} decodes to the upstream bytes; a private-IP target with the guard ON -> rejected; oversize -> capped; PROXY_MODE=disabled -> rejected. clippy -D warnings + cargo test green; keel validate + guard green."; }
    }

    verification proxyRefineGate : Test { :>> id = "e4f3138a-1740-4c61-9075-b5210b758fda"; :>> title = "Sprint 11 refine gate (DoR)"; :>> createdAt = "2026-07-02"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: the proxy, per dProxyWireCompat (base64-JSON wire kept for shim compat; memory bounded internally). SSRF logic + shapes from proxy.js. INVEST: Independent (self-contained route + reqwest); Valuable (plugin cross-origin fetch); Estimable (5pts - route + SSRF guard + redirect re-checks + streamed encode); Small; Testable (local mock server). DoR met."; }
    part proxyRefineGateR1 : TestResult { :>> id = "01737b7f-b04f-4155-8ef5-eec437a6252c"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "101aff9"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; }
    verification proxyStandupGate : Test { :>> id = "5ab7809c-c59f-4e26-a2a7-3ca96053dd9d"; :>> title = "Sprint 11 standup gate"; :>> createdAt = "2026-07-02"; :>> createdBy = "ai"; :>> method = VerificationMethod::inspect; :>> procedureText = "Approach: a proxy_routes module using reqwest (redirect policy = manual, re-check each hop's resolved IP against the SSRF guard, strip auth cross-origin); is_blocked_addr per proxy.js CIDR set + PROXY_ALLOW_PRIVATE_HOSTS + PROXY_MODE env; stream body with a 50MB cap + incremental base64. Build the {status,headers,body:base64} envelope. TDD against a 127.0.0.1 mock (allowlisted). No blockers; implement gate pends the build."; }
    part proxyStandupGateR1 : TestResult { :>> id = "5c8967b4-981a-4c1a-8c4c-83c9ddfcdc1d"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "101aff9"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "ai"; }
}
