// IgniteProcessDecisions — operating/process Decisions for conducting the Ignite build
// (distinct from the architecture Decisions). Kept in .tracking/ (the authoritative model),
// NOT in private agent memory.
package IgniteProcessDecisions {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;

    part dAutonomyCadence : Decision {
        :>> id = "675aa3e2-066e-46a7-91a8-012d4996153a";
        :>> title = "Autonomy cadence: chain sprints without per-step check-ins; stop only at a human gate, a fork in the path, or when done";
        :>> createdAt = "2026-07-02";
        :>> createdBy = "will";
        :>> status = DecisionStatus::accepted;
        :>> context = "During the Ignite build the AI paused after each sprint to ask 'continue?'. will directed (2026-07-02) that this per-step confirmation is unwanted friction when the direction is clear. The AI first recorded this only in private agent memory - which is the exact 'process knowledge leaking outside the model' anti-pattern keel exists to prevent (the model, not conversation or private memory, is the authority; cf. the retired RESUME.md shadow-tracker and keel-repo issue054). will flagged that it should be a Decision.";
        :>> decision = "The AI proceeds autonomously through the ready backlog frontier - close a sprint, immediately plan + build the next - keeping FULL keel discipline (plan->build->verify->close, green validate+guard, honest tracking) on each. It STOPS only when: (1) a human gate is due (the per-sitting review D0049, accepting a Decision, or an outward/irreversible action needing confirmation); (2) the path bifurcates or is unclear; or (3) the backlog is dry. Process directives like this are recorded as keel Decisions in the model, never as private memory.";
        :>> rationale = "Cuts confirmation friction (a D0054 friction-is-#1-risk analog) while preserving the human gate where it matters (D0049 per-sitting review). ALTERNATIVES: (A) pause after every sprint - rejected by will as friction; (B) keep it in private AI memory - rejected: a shadow record outside the authoritative model (RESUME.md anti-pattern); (C) a keel Decision governing cadence - CHOSEN. CRITERIA: low friction x the human still gates via the per-sitting review x the directive lives in the model, reviewable + enforceable.";
        :>> consequences = "Between human gates, expect chained sprints with no 'continue?' prompts. The per-sitting review stays the human acceptance gate. The redundant private-memory note is deleted. Reinforces the general rule (keel-repo issue054): capture process directives/decisions in the model, not conversation or memory.";
    }
    verification dAutonomyCadenceAccept : Test { :>> id = "745a45bd-fe26-420b-9443-c304e9f98d48"; :>> method = VerificationMethod::confirmation; :>> procedureText = "will directed on 2026-07-02: 'no need to keep stopping. only stop when you need user confirmation, the path forward bifurcates or is otherwise unclear, or have nothing more to complete' - and confirmed it should be recorded as a Decision."; }
    part dAutonomyCadenceAcceptR1 : TestResult { :>> id = "03758b5f-212b-439b-ba6d-3d26587e4cbb"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "d02528e"; :>> judgedAt = "2026-07-02"; :>> judgedBy = "will"; }
}
