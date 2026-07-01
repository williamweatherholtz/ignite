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

    // ---- triage: each Issue is resolved by its IgniteBacklog action (computed when done) ----
    #Resolves dependency from realVaultBench to issue001;
    #Resolves dependency from fsSpawnBlocking to issue008;
    #Resolves dependency from watcherAutoRestart to issue006;
    #Resolves dependency from bulkMoveSubtreeWalk to issue007;
    #Resolves dependency from dockerColdMitigation to issue005;
    #Resolves dependency from ctimeUnixParity to issue002;
    #Resolves dependency from gitTreeInclusionParity to issue003;
    #Resolves dependency from dockerContextBench to issue004;
}
