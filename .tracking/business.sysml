// IgniteBusiness — the Business-layer facts for Ignite: the project Brief and the
// solution-free Needs (the "what / why"). Measurable thresholds live downstream as
// SystemRequirements + verify-linked Tests; Needs state the desired outcome only.
package IgniteBusiness {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRelationships::*;

    // ---- the Brief: problem + opportunity (Business-phase artifact) ----
    part ignisBrief : Brief {
        :>> id = "cb66954a-2c1d-428c-9332-a17a9777a511";
        :>> title = "Ignite: a performant Rust drop-in for the Ignis self-hosted Obsidian server";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "will";
        :>> problem = "Ignis lets the real (closed-source) Obsidian run in a self-hosted browser, but its Node server rebuilds the vault file tree on every request via a synchronous per-file stat walk with no caching. On a 2,552-file vault this takes 72-214 s; because the walk blocks Node's single event loop it also starves unrelated requests (static assets balloon to multi-second, batch reads to 3-24 s). The result is a self-hosted Obsidian too slow to use on real-sized vaults.";
        :>> opportunity = "The bottleneck is I/O-walk-bound and uncached - a near-ideal target for a Rust rewrite. A warm in-memory vault index, built by a parallel walk and kept current from the file watcher, served over async multithreaded I/O, can turn the headline 72-214 s into single-digit ms while leaving the browser client and Obsidian bundle unchanged.";
        :>> constraintsNote = "Wire-compatible drop-in: the browser-side shim/UI (JS) and the closed-source Obsidian bundle are unchanged; only the server is reimplemented in Rust. Spec pinned at Ignis c9656b8 (v0.8.7).";
    }

    // ---- Needs: solution-free desired outcomes (JTBD), MoSCoW-prioritized ----

    requirement needFastLargeVault : Need {
        :>> id = "13cc9626-27cf-4d11-889d-1584afd35222";
        :>> title = "Large vaults become usable almost immediately";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "will";
        :>> source = NeedSource::customer;
        :>> statement = "A user opening a vault - including a large one of several thousand files - can begin reading and editing almost immediately, rather than waiting minutes for the vault to become usable.";
        :>> priority = Priority::must;
    }

    requirement needResponsiveUnderLoad : Need {
        :>> id = "f0356b71-e04b-4372-b3d0-e83c5af06073";
        :>> title = "Heavy work never starves other interactions";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "will";
        :>> source = NeedSource::customer;
        :>> statement = "While the server is doing heavy work for one request, a user's other interactions (loading the page, opening notes) stay responsive and are not blocked behind it.";
        :>> priority = Priority::must;
    }

    requirement needFastFileReads : Need {
        :>> id = "31463b40-20cc-4462-b2d1-ffe195e54b89";
        :>> title = "Reading files is fast and scales with file size, not vault size";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "will";
        :>> source = NeedSource::customer;
        :>> statement = "Opening and reading files is fast and depends on the size of what is being read, not on how large the overall vault is.";
        :>> priority = Priority::must;
    }

    requirement needDropInCompatible : Need {
        :>> id = "b243d8c6-5f70-4e68-9589-20764fca4f63";
        :>> title = "Drop-in replacement for the existing client and Obsidian";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "will";
        :>> source = NeedSource::customer;
        :>> statement = "A self-hoster can run Ignite in place of the existing server and keep using Obsidian in the browser exactly as before, with no changes to the browser client or to Obsidian.";
        :>> priority = Priority::must;
    }

    requirement needReliableLiveSync : Need {
        :>> id = "22d70e3e-342b-42e9-9fc6-e8021a6c487a";
        :>> title = "Edits reflect reliably and promptly across sessions";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "will";
        :>> source = NeedSource::customer;
        :>> statement = "Edits a user makes are reflected reliably and promptly across their open sessions, with no lost or stale changes.";
        :>> priority = Priority::must;
    }

    requirement needModestFootprint : Need {
        :>> id = "5d2b64b4-9037-4ba4-b237-d12afd319860";
        :>> title = "Runs within a modest memory footprint";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "will";
        :>> source = NeedSource::customer;
        :>> statement = "A personal multi-vault setup runs within a modest memory footprint suitable for a small self-hosted box.";
        :>> priority = Priority::should;
    }

    requirement needUpstreamTrackable : Need {
        :>> id = "fd5455bd-4a9f-47fd-ac1c-8d15009231e5";
        :>> title = "Upstream Ignis changes can be integrated over time";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "will";
        :>> source = NeedSource::internal;
        :>> statement = "Improvements and fixes made upstream in Ignis can be identified and folded into Ignite over time.";
        :>> priority = Priority::should;
    }

    // ---- traceability: each Need arises from the Brief (semantic dependence) ----
    #DependsOn dependency from needFastLargeVault to ignisBrief;
    #DependsOn dependency from needResponsiveUnderLoad to ignisBrief;
    #DependsOn dependency from needFastFileReads to ignisBrief;
    #DependsOn dependency from needDropInCompatible to ignisBrief;
    #DependsOn dependency from needReliableLiveSync to ignisBrief;
    #DependsOn dependency from needModestFootprint to ignisBrief;
    #DependsOn dependency from needUpstreamTrackable to ignisBrief;
}
