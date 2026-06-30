// IgniteRequirements — the Architecture-layer SystemRequirements (the "how", EARS-formatted,
// with measurable thresholds), each `satisfy`-linked to the Need it discharges. The full
// route-level functional SR set is refined into the backlog; this is the first decomposition
// covering every Need (raises tier-satisfaction off 0) plus the load-bearing performance contract.
package IgniteRequirements {
    private import EngineElement::*;
    private import EngineRequirements::*;
    private import IgniteBusiness::*;

    requirement srTreeFast : SystemRequirement {
        :>> id = "ece25d7a-05fc-4bf4-a4fb-a0a6571fc698";
        :>> title = "Vault tree / bootstrap fast and scalable";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "will";
        :>> statement = "The system shall serve GET /api/fs/tree and GET /api/bootstrap for a vault of 2,500 files in under 1 s on a cold start (no warm index) and under 50 ms once the in-memory index is warm.";
        :>> rationale = "Directly retires the dominant Ignis bottleneck (72-214 s uncached per-file stat walk for 2,552 files). Threshold set from the measured baseline: a parallel walk is sub-second cold, a warm snapshot serialize is single-digit ms.";
        :>> kind = RequirementKind::nonFunctional;
        :>> priority = Priority::must;
        :>> verificationMethod = VerificationMethod::test;
    }

    requirement srNoHolBlocking : SystemRequirement {
        :>> id = "c0b27a00-3b92-4032-b020-bd48e8ab539f";
        :>> title = "No head-of-line blocking under concurrent index build";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "will";
        :>> statement = "While a full vault index build is in progress, the system shall serve static-asset and file-read requests with a 95th-percentile latency under 100 ms.";
        :>> rationale = "In Ignis the synchronous walk starves Node's single event loop, ballooning unrelated requests (static assets 2-4 s, reads 3-24 s). Async multithreaded I/O must keep concurrent requests fast.";
        :>> kind = RequirementKind::nonFunctional;
        :>> priority = Priority::must;
        :>> verificationMethod = VerificationMethod::test;
    }

    requirement srBatchRead : SystemRequirement {
        :>> id = "b1a2a150-746e-4713-b732-5b60ff5e0bee";
        :>> title = "File reads scale with bytes, not vault size";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "will";
        :>> statement = "The system shall serve POST /api/fs/batch-read with response time proportional to total bytes read and independent of overall vault size; a typical editor-open batch shall complete within 200 ms.";
        :>> rationale = "Ignis batch-read ran 3-24 s, partly from event-loop contention. Reads must depend only on what is read.";
        :>> kind = RequirementKind::nonFunctional;
        :>> priority = Priority::must;
        :>> verificationMethod = VerificationMethod::test;
    }

    requirement srWireCompat : SystemRequirement {
        :>> id = "0958d3c6-32a6-4522-9598-5f51413fd78e";
        :>> title = "Wire-compatible Ignis c9656b8 HTTP + WebSocket contract";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "will";
        :>> statement = "The system shall expose the Ignis c9656b8 HTTP route set and WebSocket message protocol such that the unmodified Ignis browser shim and the Obsidian bundle load and operate without any client-side change.";
        :>> rationale = "A drop-in replacement is defined by behavioral parity with the pinned Ignis contract; the existing JS shim must interpose unchanged. Per-route functional SRs are refined into the backlog under this umbrella.";
        :>> kind = RequirementKind::interfaceReq;
        :>> priority = Priority::must;
        :>> verificationMethod = VerificationMethod::demo;
    }

    requirement srLiveSync : SystemRequirement {
        :>> id = "a4510785-c741-44ff-be6d-a1ad8992be6c";
        :>> title = "Filesystem changes broadcast and reflected promptly";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "will";
        :>> statement = "When a vault file is created, modified, deleted, or renamed, the system shall broadcast the corresponding WebSocket event to all clients subscribed to that vault and reflect the change in the served tree within 500 ms.";
        :>> rationale = "Live cross-session sync depends on watcher events reaching clients promptly and the warm index staying correct without a full re-walk.";
        :>> kind = RequirementKind::functional;
        :>> priority = Priority::must;
        :>> verificationMethod = VerificationMethod::test;
    }

    requirement srMemory : SystemRequirement {
        :>> id = "9e0825ab-fd3a-4b5d-8998-d09ef4ea833f";
        :>> title = "Modest resident memory across the multi-vault set";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "will";
        :>> statement = "The system shall keep resident memory (RSS) under 150 MB while serving the full multi-vault set (approx. 6 vaults, approx. 5,600 files total).";
        :>> rationale = "Provisional order-of-magnitude ceiling: an in-memory index of ~5,600 entries is ~1 MB; the budget is generous and far below Node's footprint. Refine to a tighter threshold (or demote to a monitored Indicator per D0088) once measured.";
        :>> kind = RequirementKind::nonFunctional;
        :>> priority = Priority::should;
        :>> verificationMethod = VerificationMethod::test;
    }

    requirement srUpstreamContract : SystemRequirement {
        :>> id = "6cca7898-ee1a-4c69-9461-d5b8cbba0c93";
        :>> title = "Documented endpoint mapping to the pinned Ignis contract";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "will";
        :>> statement = "The system shall maintain a documented mapping of each implemented endpoint and WebSocket message to the pinned Ignis c9656b8 contract, such that an upstream Ignis diff can be assessed against it.";
        :>> rationale = "Integrating future upstream Ignis changes requires a stable, diffable record of what was ported from which baseline.";
        :>> kind = RequirementKind::functional;
        :>> priority = Priority::should;
        :>> verificationMethod = VerificationMethod::inspect;
    }

    // ---- satisfy edges: SR discharges Need (native `satisfy <need> by <sr>`) ----
    satisfy needFastLargeVault by srTreeFast;
    satisfy needResponsiveUnderLoad by srNoHolBlocking;
    satisfy needFastFileReads by srBatchRead;
    satisfy needDropInCompatible by srWireCompat;
    satisfy needReliableLiveSync by srLiveSync;
    satisfy needModestFootprint by srMemory;
    satisfy needUpstreamTrackable by srUpstreamContract;
}
