// IgniteCritiqueDecisions — design constraints adopted from the Ignis architectural-critique
// spike (c9656b8). Accepted by will on 2026-06-30. These BIND the relevant future feature
// sprints (srLiveSync watcher, write endpoints, proxy, WS) and one immediate code win.
// (Security findings #6 auth / #7 symlink-canonicalization were reviewed but NOT adopted now.)
package IgniteCritiqueDecisions {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;
    private import IgniteBusiness::*;

    part dCritiqueCorrectness : Decision {
        :>> id = "f82c226c-97fb-446c-b5d5-9597d3c14a17";
        :>> title = "Ignite correctness invariants from the Ignis critique: continuous-watch + reconcile, event-based invalidation, honest durable writes";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "will";
        :>> status = DecisionStatus::accepted;
        :>> context = "The Ignis critique spike surfaced three CORRECTNESS/data-integrity defects Ignite must not inherit: (1) Ignis's watcher is gated on WS clients (ignoreInitial, stops on last disconnect, no rescan), so changes while no client is connected are silently missed; (2) bootstrap cache validity is checked by DIRECTORY mtime only, so in-place content edits and out-of-band writes (incl. Obsidian Sync) serve a stale tree; (3) the write-coalescer acks {ok} with fabricated mtime/size before touching disk and can lose acknowledged writes on kill -9/OOM, and its dedup map is unbounded.";
        :>> decision = "Adopt three binding correctness invariants, as acceptance constraints on the srLiveSync (watcher) and write-endpoint work: (1) the warm index watches CONTINUOUSLY from build time (not gated on WS clients) and RECONCILES against disk on watcher start/restart so it can never silently diverge; (2) tree/cache invalidation is keyed on REAL file events (content-aware), never directory-mtime heuristics, so external/sync writes are reflected; (3) writes are honest and durable - never ack with synthetic metadata a crash can lose; Rust async writes largely retire coalescing, and any buffering bounds memory and makes durability explicit.";
        :>> rationale = "These are correctness/data-integrity, not speed - a notes app that silently shows a stale tree or loses a saved edit is broken regardless of latency; #1/#2 directly hit the user's Obsidian-Sync workflow (out-of-band writes). ALTERNATIVES: (A) inherit Ignis's approach - rejected (the defects are real + reproducible from the source); (B) fix later - rejected (free to design correctly now, the features aren't built yet); (C) adopt as binding constraints now - CHOSEN. CRITERIA: correctness over expedience; bind the design before the code exists.";
        :>> consequences = "srLiveSync's DoD gains continuous-watch + reconcile-on-restart + event-based invalidation + a no-silent-divergence test; the write endpoints' DoD gains durable, honest-metadata writes + bounded buffers. Derived from the Ignis critique spike.";
    }
    verification dCritiqueCorrectnessAccept : Test { :>> id = "38164383-c8f1-4d60-a351-179d22ecab9b"; :>> method = VerificationMethod::confirmation; :>> procedureText = "will selected 'Correctness trio (#1,#2,#3)' on the critique-adoption question, 2026-06-30, to bind Ignite's upcoming watcher + write work."; }
    part dCritiqueCorrectnessAcceptR1 : TestResult { :>> id = "1e5f6617-4b70-4d33-8ecb-ceb5394e5495"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "a5a0f41"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "will"; }

    part dCritiqueEfficiency : Decision {
        :>> id = "e1bf6114-39ca-47ec-a364-55b29a253be2";
        :>> title = "Ignite efficiency constraints from the critique: streaming proxy, batched/backpressured WS, parallel multi-vault startup";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "will";
        :>> status = DecisionStatus::accepted;
        :>> context = "The critique also surfaced efficiency/stability issues: (4) Ignis's /api/proxy buffers up to 50MB then base64-encodes into a JSON envelope (~33% inflation, no streaming); (5) WS fan-out serializes per-client, ignores backpressure, and emits one message per file change (message storms on bulk sync/rename); and separately, Ignite's OWN registry.rs builds vault indexes SEQUENTIALLY at startup (per-vault cold builds sum - ~16s for 6 vaults in Docker).";
        :>> decision = "Adopt three efficiency constraints: (4) the proxy streams the upstream response as binary pass-through with headers (no full buffer, no base64-in-JSON), re-checking the resolved address; (5) WS broadcast serializes each event ONCE, honors send backpressure, and coalesces/debounces burst file events into batched updates; and (immediate) registry index builds run in PARALLEL across vaults at startup. The proxy/WS constraints bind their future feature sprints (under srWireCompat); the parallel startup is implemented now (sprint04).";
        :>> rationale = "ALTERNATIVES: (A) base64-buffered proxy / per-client serialize / sequential startup - rejected (memory spikes, message storms, slow multi-vault boot); (B) adopt the constraints - CHOSEN. CRITERIA: bounded memory + stability under bulk ops + fast multi-vault startup. NOTE: not a correctness risk like the trio, so lower priority; the parallel startup is the one quick code win taken immediately.";
        :>> consequences = "The proxy + WS feature DoDs gain these constraints; sprint04 parallelizes the registry build. Derived from the Ignis critique spike.";
    }
    verification dCritiqueEfficiencyAccept : Test { :>> id = "ef053400-8206-4398-b9a9-3bd99742cb2e"; :>> method = VerificationMethod::confirmation; :>> procedureText = "will selected 'Efficiency (#4 proxy streaming, #5 WS batching, parallel startup)' on the critique-adoption question, 2026-06-30."; }
    part dCritiqueEfficiencyAcceptR1 : TestResult { :>> id = "16104096-0f74-46c6-bfd0-6634dab88b74"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "a5a0f41"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "will"; }

    part dProxyWireCompat : Decision {
        :>> id = "9bbec008-695f-4b20-bcc2-0ae77e9659f5";
        :>> title = "Amend dCritiqueEfficiency #4: the proxy keeps Ignis's base64-JSON wire (shim compat); bound memory internally instead";
        :>> createdAt = "2026-07-02";
        :>> createdBy = "will";
        :>> status = DecisionStatus::accepted;
        :>> context = "dCritiqueEfficiency #4 (adopted from the critique) said the proxy should 'stream the upstream response as binary pass-through instead of base64-in-JSON'. Planning sprint11 revealed this CONFLICTS with the drop-in contract: Ignis's /api/proxy returns {status,headers,body:base64} and the UNCHANGED browser shim (dScope) decodes that envelope. A binary wire would break the shim. The #4 proxy sub-point was proposed without accounting for the shim's dependence on the envelope.";
        :>> decision = "AMEND dCritiqueEfficiency #4 (proxy only): Ignite's /api/proxy KEEPS Ignis's base64-in-JSON wire ({status,headers,body:base64}) for shim compatibility, and instead bounds server memory internally - stream the upstream fetch + encode incrementally (avoid holding a raw+base64 duplicate), keep the 50MB cap + the SSRF/private-IP guard + redirect re-checks. dCritiqueEfficiency #5 (WS serialize-once/backpressure/batch) is UNAFFECTED and stands; only #4's 'no base64' clause is retired.";
        :>> rationale = "The drop-in's premise is an unchanged shim (dScope); wire-compat wins over the internal-representation change. ALTERNATIVES: (A) binary pass-through per literal #4 - rejected (breaks the shim; needs shim changes; violates dScope); (B) defer the proxy - rejected (plugins need cross-origin fetch); (C) keep the base64 wire + bound memory - CHOSEN. CRITERIA: preserve the drop-in contract x still address #4's memory concern as far as compat allows.";
        :>> consequences = "sprint11 builds /api/proxy to Ignis's base64-JSON wire with a bounded/streamed encode + SSRF guard + 50MB cap. #4's 'no base64' clause is retired; its memory-bounding intent is preserved. #5 (WS) unchanged. Corrects an over-reach in the original critique adoption.";
    }
    verification dProxyWireCompatAccept : Test { :>> id = "a7b970d0-2501-4aef-ac92-1e4b3e3a70af"; :>> method = VerificationMethod::confirmation; :>> procedureText = "will chose 'Amend #4: keep base64-JSON wire, bound memory internally' on the proxy-wire question, 2026-07-02, on being shown the dCritiqueEfficiency-#4-vs-drop-in-shim conflict."; }
    part dProxyWireCompatAcceptR1 : TestResult { :>> id = "d0467409-9717-4b93-92ed-02e83bdd5b05"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "101aff9"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "will"; }

    // traceability: correctness invariants serve reliable live sync; efficiency serves responsiveness;
    // the proxy-wire amendment serves the drop-in wire contract.
    #DependsOn dependency from dCritiqueCorrectness to needReliableLiveSync;
    #DependsOn dependency from dCritiqueEfficiency to needResponsiveUnderLoad;
    #DependsOn dependency from dProxyWireCompat to srWireCompat;
}
