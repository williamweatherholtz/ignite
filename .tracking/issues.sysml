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

    // ---- triage: each Issue is resolved by its IgniteBacklog action (computed when done) ----
    #Resolves dependency from realVaultBench to issue001;
    #Resolves dependency from ctimeUnixParity to issue002;
    #Resolves dependency from gitTreeInclusionParity to issue003;
}
