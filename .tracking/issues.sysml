// IgniteIssues — tracked problems/gaps. Each is TRIAGED via a #Resolves edge from a resolving
// action (in IgniteBacklog). Resolution is COMPUTED (resolved iff the resolver is done), never a
// prose note. These three are the honest residuals from sprint 1's review/retro.
package IgniteIssues {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineRelationships::*;

    part issue001 : Issue {
        :>> id = "4b7b3aca-d941-4d28-a96d-b95b94e5c3af";
        :>> title = "srTreeFast perf verified on a synthetic fixture only, not a real vault";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "ai";
        :>> description = "Sprint 1 met srTreeFast's thresholds (cold 24.9ms < 1s, warm 6.8ms < 50ms) on a SYNTHETIC ~2,800-entry vault generated in a fast tempdir. Real vaults live on slower storage (disk/NAS) where the parallel walk's benefit is the real test. srTreeFast is not fully confirmed until benchmarked on a real ~2,500-file vault.";
        :>> discoveredInField = false;
        :>> relatedTask = "realVaultBench";
        :>> severity = Severity::Medium;
    }

    part issue002 : Issue {
        :>> id = "3b20024f-5ca3-4fe0-a541-53dce82ccbbf";
        :>> title = "ctime semantics may differ from Ignis on Unix (wire-parity)";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "ai";
        :>> description = "TreeEntry.ctime uses std created() (fallback modified()), which matches Ignis on Windows (creation time) but differs from Ignis on Unix, where stat ctime is the inode change time. For a faithful drop-in the served ctimeMs should match what Ignis emits on the host platform. Confirm against a captured Ignis response and align or document.";
        :>> discoveredInField = false;
        :>> relatedTask = "ctimeUnixParity";
        :>> severity = Severity::Low;
    }

    part issue003 : Issue {
        :>> id = "5e4bb76f-d2eb-46d7-8aee-2a9943151933";
        :>> title = "Unconfirmed whether Ignis fs/tree includes .git / .obsidian";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "ai";
        :>> description = "build_tree currently includes everything (incl. .git and .obsidian) to mirror Ignis's bootstrap walk, but Ignis's WATCHER explicitly ignores .git, and its tree walk's inclusion of .git was not confirmed against a real response. A mismatch could surface spurious or missing tree entries to the shim. Verify against a captured Ignis fs/tree oracle and align the ignore set.";
        :>> discoveredInField = false;
        :>> relatedTask = "gitTreeInclusionParity";
        :>> severity = Severity::Low;
    }

    part issue004 : Issue {
        :>> id = "1f84d1f5-997f-4d00-937b-7db79f40a408";
        :>> title = "Ignis 72-214s baseline was Docker-bind-mount-dominated, not a like-for-like algorithm comparison";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "ai";
        :>> description = "The headline 'Ignite is thousands of times faster than Ignis' is confounded. Ignis's 72-214s was measured in Docker (bind-mount filesystem). A controlled baseline running Ignis's EXACT sequential per-file-stat walk in Node over the SAME native vault is only 657ms cold / 216ms warm - so Docker's host<->VM filesystem bridge (~100-300x), not the Node algorithm, dominated the original number. The clean same-filesystem Rust-vs-Node speedup is ~11-33x (plus Ignite removes event-loop head-of-line blocking). For an honest end-to-end claim, Ignite must be benchmarked in Ignis's ACTUAL deployment context (Docker, same mount). Also implies a large share of the user's real-world pain is the Docker bind mount - a deployment concern partly orthogonal to the rewrite.";
        :>> discoveredInField = true;
        :>> relatedTask = "dockerContextBench";
        :>> severity = Severity::Medium;
    }

    part issue005 : Issue {
        :>> id = "55b6a8c7-6718-4525-a892-d4cdaca8c67b";
        :>> title = "srTreeFast cold contract (<1s) missed through a Docker bind mount (2.74s)";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "ai";
        :>> description = "issue004's Docker-context benchmark revealed Ignite's COLD index build takes 2.74s for the 2,972-entry Games vault when the vault is a Windows-host bind mount (vs 20ms native) - over srTreeFast's <1s cold threshold. Impact is LOW because Ignite builds indexes once at startup (registry.rs eager build) so every per-request serve is warm (~2.3ms in Docker); the 2.74s is a one-time boot cost per vault, not per request (unlike Ignis, which re-walked every request). Mitigations: prefer a Docker named volume or WSL2-native vault path over a Windows-host bind mount; or run Ignite natively. Open question: should srTreeFast's cold threshold be qualified to native storage, or carry a separate mounted-FS bound.";
        :>> discoveredInField = false;
        :>> relatedTask = "dockerColdMitigation";
        :>> severity = Severity::Medium;
    }

    part issue006 : Issue {
        :>> id = "74a21b1c-b101-4650-9f6d-c93fb5cf6997";
        :>> title = "Live watcher has no auto-restart on watcher error -> silent staleness can return";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "ai";
        :>> description = "Sprint 5 caveat: if the OS file watcher errors out, nothing re-arms it; reconcile() is the intended recovery but is not auto-triggered by a watcher-failure signal. A dead watcher silently re-introduces exactly the staleness dCritiqueCorrectness #1 fixes. Fix: detect watcher error events and re-arm + reconcile (or periodically reconcile as a backstop).";
        :>> discoveredInField = false;
        :>> relatedTask = "watcherAutoRestart";
        :>> severity = Severity::Medium;
    }

    part issue007 : Issue {
        :>> id = "44e2bdcc-cb36-4426-8299-a97f016731be";
        :>> title = "Bulk move of a populated directory may briefly under-populate the index";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "ai";
        :>> description = "Sprint 5 caveat: apply_paths upserts a moved-in directory entry but does not eagerly walk its new populated subtree; it relies on recursive notify emitting per-child events (and reconcile() as a backstop). A bulk move could briefly under-populate the tree until child events arrive or a reconcile runs. Fix: on a directory create/move event, walk the new subtree eagerly.";
        :>> discoveredInField = false;
        :>> relatedTask = "bulkMoveSubtreeWalk";
        :>> severity = Severity::Low;
    }

    part issue008 : Issue {
        :>> id = "576843c7-db84-4f88-b196-9ed27ebcd8bd";
        :>> title = "fs CRUD handlers use blocking std::fs on the async runtime";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "ai";
        :>> description = "Sprint 7 caveat: the fs CRUD handlers call blocking std::fs directly on tokio worker threads. Single-file ops are fast so this is not the head-of-line blocking Ignis had (the big walk is already off-thread), but under high concurrent write/read load blocking calls can stall executor threads. Refinement: move the blocking fs calls to tokio::task::spawn_blocking (or tokio::fs). Low priority.";
        :>> discoveredInField = false;
        :>> relatedTask = "fsSpawnBlocking";
        :>> severity = Severity::Low;
    }

    part issue009 : Issue {
        :>> id = "575fe5b0-862a-45d6-b54b-1ee260f92191";
        :>> title = "Proxy DNS-rebinding TOCTOU: SSRF guard resolves the host, but reqwest re-resolves at connect time";
        :>> createdAt = "2026-07-02";
        :>> createdBy = "ai";
        :>> description = "Sprint 11 caveat: /api/proxy's addr_ok resolves the target host and checks it against the SSRF private-range guard, but reqwest independently re-resolves at connect time - a DNS entry that flips between the check and the connect (rebinding) could reach a private address. This MATCHES Ignis's model (same gap), so it's parity not a regression, but it's a genuine SSRF hardening opportunity. Fix: pin the checked IP into the connection (custom resolver / connect to the vetted socket addr), or re-validate the peer address post-connect.";
        :>> discoveredInField = false;
        :>> relatedTask = "proxyDnsRebindHarden";
        :>> severity = Severity::Low;
    }

    part issue010 : Issue {
        :>> id = "6fbf5ac0-ccdf-4eb1-9576-ab9c6fa129f5";
        :>> title = "POST /api/settings does not drive the proxy at runtime (proxy reads env at startup)";
        :>> createdAt = "2026-07-02";
        :>> createdBy = "ai";
        :>> description = "Sprint 12 caveat: /api/settings persists proxyMode/proxyAllowlist/proxyAllowPrivate etc., but the proxy's ProxyConfig is loaded from env at startup and is not refreshed when settings change - so changing proxy mode via the API requires a server restart. Ignis applied such changes at runtime. Low impact for single-user self-host (restart acceptable). Fix: share the settings state with the proxy handler (read proxyMode/allowlist from the injected SettingsState instead of a startup-only ProxyConfig).";
        :>> discoveredInField = false;
        :>> relatedTask = "settingsProxyWire";
        :>> severity = Severity::Low;
    }

    part issue011 : Issue {
        :>> id = "d291ec3d-cd44-45b0-8201-bb66d1914a3a";
        :>> title = "download-zip buffers the whole archive in memory instead of streaming";
        :>> createdAt = "2026-07-02";
        :>> createdBy = "ai";
        :>> description = "Sprint 13 caveat: /api/fs/download-zip builds the zip fully in a Vec<u8> before responding, vs Ignis's archive.pipe(res) streaming. Fine for typical folders; a very large folder zips into RAM. Refinement: stream the zip to the response body (async zip writer / channel). Low (akin to issue008's blocking-fs concern).";
        :>> discoveredInField = false;
        :>> relatedTask = "zipStreaming";
        :>> severity = Severity::Low;
    }

    part issue012 : Issue {
        :>> id = "86ecc06b-ba88-4254-81d5-73c51afaf5e6";
        :>> title = "Content-Disposition is ASCII filename= only; no RFC-5987 filename* for non-ASCII names";
        :>> createdAt = "2026-07-02";
        :>> createdBy = "ai";
        :>> description = "Sprint 13 caveat: download/download-zip set a basic ASCII Content-Disposition filename=\"..\"; Ignis's encodeContentDispositionFilename adds an RFC-5987 filename* for non-ASCII names. A vault file/folder with non-ASCII characters downloads with a degraded (not broken) filename. Low wire-parity gap. Fix: add the filename* encoding.";
        :>> discoveredInField = false;
        :>> relatedTask = "contentDispositionRfc5987";
        :>> severity = Severity::Low;
    }

    part issue013 : Issue {
        :>> id = "2abd03ce-b9bd-456f-9f2f-35cf80489659";
        :>> title = "End-to-end unverified: a browser actually loading + operating Obsidian against the Ignite container";
        :>> createdAt = "2026-07-02";
        :>> createdBy = "ai";
        :>> description = "sprint15 verified the SERVER runs in the Docker container (endpoints return correct Ignis-shaped JSON) but NOT that a browser loads + operates Obsidian against it - that is a human demo (D0049, method=demo) the AI cannot self-attest. Risk: Ignite's static/app-shell serving (sprint09) was built against fixtures, so the real Ignis template placeholders, ignis-ui.js/shim-loader.js serving paths, app.css source, and route ordering may need a tweak once tested in a real browser. RESOLVER: run `docker compose up` (or the stack), open the browser, confirm Obsidian loads + a vault opens + edits live-sync; fix any asset-wiring mismatch surfaced.";
        :>> discoveredInField = false;
        :>> relatedTask = "browserLoadDemo";
        :>> severity = Severity::Medium;
    }

    // ---- triage: each Issue is resolved by its IgniteBacklog action (computed when done) ----
    #Resolves dependency from realVaultBench to issue001;
    #Resolves dependency from browserLoadDemo to issue013;
    #Resolves dependency from zipStreaming to issue011;
    #Resolves dependency from contentDispositionRfc5987 to issue012;
    #Resolves dependency from settingsProxyWire to issue010;
    #Resolves dependency from proxyDnsRebindHarden to issue009;
    #Resolves dependency from fsSpawnBlocking to issue008;
    #Resolves dependency from watcherAutoRestart to issue006;
    #Resolves dependency from bulkMoveSubtreeWalk to issue007;
    #Resolves dependency from dockerColdMitigation to issue005;
    #Resolves dependency from ctimeUnixParity to issue002;
    #Resolves dependency from gitTreeInclusionParity to issue003;
    #Resolves dependency from dockerContextBench to issue004;
}
