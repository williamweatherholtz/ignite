// IgniteDecisions — this project's architecture/scope Decisions (the "how"), each
// traced by #DependsOn to the Need(s) it serves, each carrying its acceptance as a
// confirmation event (D0066). Kept in .tracking/ (instance data), NOT in .engine/.
// All accepted by the human (will) in the design session on 2026-06-30.
package IgniteDecisions {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;
    private import IgniteBusiness::*;

    // ---- D1: v1 scope = full wire-compatible drop-in ----
    part dScope : Decision {
        :>> id = "06d02f1a-8cee-46f1-8980-f61ceb88e967";
        :>> title = "Ignite v1 is a full wire-compatible drop-in replacement of the Ignis server";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "will";
        :>> status = DecisionStatus::accepted;
        :>> context = "Ignite must replace the Ignis Node server. The v1 boundary had to be set: target only the slow hot-path endpoints first, or reimplement the entire server surface for a clean single cutover.";
        :>> decision = "v1 is a full wire-compatible drop-in replacement of the entire Ignis Node server surface (~32 HTTP routes + the /ws protocol + file watcher + write-coalescer + CORS/SSRF proxy + static/Obsidian-bundle serving). The browser-side shim and UI (JS) and the closed-source Obsidian bundle are unchanged.";
        :>> rationale = "ALTERNATIVES: (A) hot-path-first (fs/tree + bootstrap + batch-read + static + ws only) - rejected: the human wanted a clean single cutover, not a partial server split; (B) full drop-in - CHOSEN. CRITERIA: clean cutover vs time-to-first-value; the human prioritized a complete replacement.";
        :>> consequences = "Larger surface; the full Ignis contract (pinned at c9656b8) is the spec. Sequencing within scope still lands the perf path first.";
    }
    verification dScopeAccept : Test { :>> id = "118b9b25-d90e-4af1-9c7d-12182231ecdc"; :>> method = VerificationMethod::confirmation; :>> procedureText = "will chose 'Full drop-in server replacement' on the v1-scope question, 2026-06-30."; }
    part dScopeAcceptR1 : TestResult { :>> id = "a05efc20-0863-49fe-bec7-75890a035b93"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "e1ba940"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "will"; }

    // ---- D2: axum + tokio + warm in-memory VaultIndex ----
    part dArch : Decision {
        :>> id = "9311d8b5-dfd3-43be-845f-17cbf0f56879";
        :>> title = "Build on axum + tokio with a warm, watcher-maintained in-memory VaultIndex";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "will";
        :>> status = DecisionStatus::accepted;
        :>> context = "The dominant bottleneck is an uncached synchronous per-file stat walk that blocks Node's single event loop (72-214 s for 2,552 files), which also starves unrelated requests. A runtime + server architecture had to be chosen.";
        :>> decision = "Build on axum + tokio with a warm in-memory VaultIndex: a parallel cold walk (ignore/jwalk) kept incrementally current from the file watcher (notify), served over async multithreaded I/O. fs/tree and bootstrap serialize the in-memory snapshot instead of re-walking disk.";
        :>> rationale = "FRAMEWORK alternatives: (A) actix-web - rejected (marginal synthetic edge, heavier API); (B) warp - rejected (declining); (C) axum - CHOSEN (tokio-native, ergonomic, first-class WS). INDEX alternatives: (A) parallel-walk-per-request - rejected (simpler but still re-walks); (B) lazy subtree - rejected; (C) warm + incremental - CHOSEN. CRITERIA: kills the walk cost, the no-cache re-walk, and event-loop head-of-line blocking at once; maintainability.";
        :>> consequences = "Turns the 72-214 s headline into single-digit ms (warm) / sub-second (cold). Adds an index + watcher subsystem that must stay correct under filesystem events.";
    }
    verification dArchAccept : Test { :>> id = "71225f8a-f73a-46c8-be32-d3f7563fdc31"; :>> method = VerificationMethod::confirmation; :>> procedureText = "will chose 'axum + tokio' on the framework question and approved the warm-index design, 2026-06-30."; }
    part dArchAcceptR1 : TestResult { :>> id = "e08ba40c-a753-4dae-b8dc-93c849759449"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "e1ba940"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "will"; }

    // ---- D3: native headless-sync + a Rust server-plugin trait ----
    part dPlugins : Decision {
        :>> id = "3c4393aa-c1e5-499e-b2c6-f9cf87737e19";
        :>> title = "Reimplement headless-sync natively in Rust + define a Rust server-plugin trait";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "will";
        :>> status = DecisionStatus::accepted;
        :>> context = "Ignis server plugins are Node modules (register(ctx)...); the only shipped one is headless-sync, which wraps the obsidian-headless CLI, stores an auth token, and broadcasts status. Rust cannot load Node plugin modules.";
        :>> decision = "Reimplement headless-sync natively in Rust (shell out to the obsidian-headless CLI, persist the token, broadcast over the plugin:headless-sync WS channel) keeping the /api/ext/headless-sync/* contract identical, and define a Rust-native server-plugin trait for future plugins. Browser-side community plugins are unaffected - they run in the tab via the JS shim.";
        :>> rationale = "ALTERNATIVES: (A) headless-sync only, no general trait (YAGNI) - rejected: the human wanted an extension seam; (B) defer all server plugins to v2 - rejected: loses Obsidian-Sync compat; (C) native + Rust trait - CHOSEN. CRITERIA: preserve the wire contract + sync compat, keep an extension point, no Node runtime.";
        :>> consequences = "The server-plugin ecosystem resets to a Rust trait (low cost - only headless-sync exists today). Sync compatibility is preserved.";
    }
    verification dPluginsAccept : Test { :>> id = "dfe2d4e5-40ee-4bcc-8670-6b1d366ab905"; :>> method = VerificationMethod::confirmation; :>> procedureText = "will chose 'Native headless-sync + Rust plugin trait' on the plugins question, 2026-06-30."; }
    part dPluginsAcceptR1 : TestResult { :>> id = "46ece804-d3d8-4c4d-85e0-68012301fb97"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "e1ba940"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "will"; }

    // ---- D4: cut demo mode from v1 (scope cut) ----
    part dDemoCut : Decision {
        :>> id = "b177a412-822f-4a05-8189-4c079584168a";
        :>> title = "Cut demo mode (multi-tenant sessions/quotas/translation) from Ignite v1";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "will";
        :>> status = DecisionStatus::accepted;
        :>> context = "Ignis ships a demo mode (multi-tenant sessions, per-session disk quotas, per-session vault-name translation) for its public demo. It adds notable server surface with no self-host benefit.";
        :>> decision = "Cut demo mode from Ignite v1. Ignite targets a fast self-hosted single-tenant server; demo mode is out of scope unless a public hosted demo is later wanted.";
        :>> rationale = "ALTERNATIVES: (A) include it - rejected: orthogonal multi-tenant feature, no self-host benefit, adds surface; (B) cut - CHOSEN. CRITERIA: self-host value vs surface area.";
        :>> consequences = "Demo session/quota/translation routes + middleware are not ported. Revisit only for a hosted public demo.";
    }
    verification dDemoCutAccept : Test { :>> id = "82de3d76-817c-4a96-81bc-e51a3b8857a5"; :>> method = VerificationMethod::confirmation; :>> procedureText = "will chose 'Cut from v1' on the demo-mode question, 2026-06-30."; }
    part dDemoCutAcceptR1 : TestResult { :>> id = "581ed2f8-7a79-4377-9231-a75334c928c4"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "e1ba940"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "will"; }

    // ---- D5: deliverable source lives in a subdirectory of this repo ----
    part dLayout : Decision {
        :>> id = "e2fa71c4-a506-49b2-8c88-e07ca9f20469";
        :>> title = "Ignite Rust deliverable source lives in a subdirectory of this keel repo";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "will";
        :>> status = DecisionStatus::accepted;
        :>> context = "Ignite is tracked by this keel project. The Rust deliverable source needs a home relative to the tracking root so the deliverable-manifest drift tracking (D0050) can map verify-tasks to source paths.";
        :>> decision = "The Rust deliverable source lives in a subdirectory of this keel repo (single repo). keel's deliverable-manifest.txt maps verification tasks to these relative paths.";
        :>> rationale = "ALTERNATIVES: (A) separate sibling repo - rejected: cross-repo drift tracking is fiddlier; (B) subdirectory - CHOSEN; (C) decide-later - superseded by this. CRITERIA: simplest manifest/drift tracking, single-repo cohesion.";
        :>> consequences = "Deliverable source + its keel tracking share one repo; manifest paths are repo-relative.";
    }
    verification dLayoutAccept : Test { :>> id = "a9e1dcaf-25a8-4d9a-8ad6-6d6d58bd993a"; :>> method = VerificationMethod::confirmation; :>> procedureText = "will chose 'Subdirectory of this repo' on the code-layout question, 2026-06-30."; }
    part dLayoutAcceptR1 : TestResult { :>> id = "3afac91d-bda8-43c6-a770-ff1a3bc575c2"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "e1ba940"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "will"; }

    // ---- D6: port against Ignis pinned at c9656b8 (v0.8.7) ----
    part dPinnedRef : Decision {
        :>> id = "96437190-5bf1-4417-acc7-027e1615a98f";
        :>> title = "Port against Ignis pinned at c9656b8 (v0.8.7); record the ref for upstream integration";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "will";
        :>> status = DecisionStatus::accepted;
        :>> context = "A full drop-in's contract is 'behave like Ignis'; the spec must be pinned to a specific Ignis version, and upstream Ignis continues to evolve.";
        :>> decision = "Port against Ignis pinned at commit c9656b8 (v0.8.7). Record the ref so future upstream Ignis changes can be diffed against this baseline and integrated.";
        :>> rationale = "ALTERNATIVES: (A) track a moving branch - rejected: a moving target makes the contract unstable; (B) pin a ref - CHOSEN. CRITERIA: stable, diffable spec baseline; integrability.";
        :>> consequences = "c9656b8 is the contract baseline; upstream integration becomes a future diff-against-this-ref task.";
    }
    verification dPinnedRefAccept : Test { :>> id = "cee5f609-74d7-48fa-a9e0-bb2877ac75e6"; :>> method = VerificationMethod::confirmation; :>> procedureText = "will chose to clone Ignis at a specific ref to track upstream changes, on the Ignis-source question, 2026-06-30."; }
    part dPinnedRefAcceptR1 : TestResult { :>> id = "541e6165-2f49-4453-a048-cdecc6e8df2b"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "e1ba940"; :>> judgedAt = "2026-06-30"; :>> judgedBy = "will"; }

    // ---- traceability: each Decision is grounded in the Need(s) it serves ----
    #DependsOn dependency from dScope to needDropInCompatible;
    #DependsOn dependency from dArch to needFastLargeVault;
    #DependsOn dependency from dArch to needResponsiveUnderLoad;
    #DependsOn dependency from dArch to needFastFileReads;
    #DependsOn dependency from dArch to needModestFootprint;
    #DependsOn dependency from dPlugins to needDropInCompatible;
    #DependsOn dependency from dPlugins to needReliableLiveSync;
    #DependsOn dependency from dPinnedRef to needUpstreamTrackable;
}
