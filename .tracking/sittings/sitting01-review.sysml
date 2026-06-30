// IgniteSittings — per-sitting sprint-review records (D0049 single human gate).
// A sitting = one work session (>=1 sprint). The review is a confirmation TestResult naming
// what it accepts, written ONLY on the human's explicit attestation (D0016/D0051 — never inferred).
package IgniteSittings {
    private import EngineElement::*;
    private import EngineVerification::*;

    verification sitting01Review : Test {
        :>> id = "3d1cb507-14bc-44dd-a40f-578867c621cd";
        :>> title = "Sitting 01 review — Ignite bootstrap + sprint 1 (2026-06-30)";
        :>> createdAt = "2026-06-30";
        :>> createdBy = "will";
        :>> method = VerificationMethod::confirmation;
        :>> procedureText = "Per-sitting sprint review (D0049 single human gate). will reviewed and accepts the content of this sitting: the Business+Architecture spine (Brief ignisBrief; 7 Needs; 7 SystemRequirements srTreeFast/srNoHolBlocking/srBatchRead/srWireCompat/srLiveSync/srMemory/srUpstreamContract; 6 Decisions dScope/dArch/dPlugins/dDemoCut/dLayout/dPinnedRef) and sprint01_fastTree (warm VaultIndex + GET /api/fs/tree, Ignis-exact shape; perf demonstrated on a SYNTHETIC ~2,800-entry vault at ~25ms cold / ~7ms warm; residuals tracked as issue001 real-vault bench, issue002 ctime Unix parity, issue003 .git tree inclusion). Explicit attestation: 'Accept the sitting' (2026-06-30).";
    }
    part sitting01ReviewR1 : TestResult {
        :>> id = "78643cc7-53ae-48e3-bb07-21c2540b7da8";
        :>> outcome = VerdictKind::pass;
        :>> judgedAgainst = "a7dfe54";
        :>> judgedAt = "2026-06-30";
        :>> judgedBy = "will";
    }
}
