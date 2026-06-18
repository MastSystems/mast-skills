---
name: dag-plan
description: Decompose specs into an implementation DAG with phased execution, parallelism lanes, seams, join points, and tempo-aware staging. Three modes -- Plan, Phase, Review. Use when asked to "implement this spec", "plan the implementation", "what order should I implement these", "what can I build in parallel", "where are the seams", "what's the dependency order", "execute phase N", "build this phase", "TDD this rule", "implement rule R3", "do the next phase", "implement the next batch", "review implementation against spec", "is the code done for X", "what's left to implement", "compliance check", "what needs graduating", or "red-team this implementation".
---

# dag-plan

This skill turns a set of specs into an executable implementation plan and drives that plan to graduation. It has three modes: Plan (spec set -> phased DAG with parallelism, seams, join points, tempo, risk), Phase (execute one phase via rule-by-rule TDD), and Review (audit existing code against specs and report compliance). It routes internally from the user's intent and tracks session state across invocations.

Reference: REF-BINARY, REF-LIFECYCLE, REF-GOVERNANCE, REF-DEPENDENCIES, REF-CONVENTIONS, REF-ROUTING
*(Reference sections live in `plugins/mast/skill-reference/` — e.g. `REF-FILEKINDS` resolves to `plugins/mast/skill-reference/REF-FILEKINDS.md`.)*

## Prerequisites

Which binary to invoke is shared doctrine -- see **REF-BINARY**: call `mast` directly (the plugin puts it on Claude Code's PATH), or `./bin/mast` in a repo that vendors the shim. If `mast` cannot be provisioned, stop and tell the user to install it before proceeding.

This skill also assumes a working build toolchain. Detect the build system early (see Check skill's detection probes). The skill drives TDD cycles that require `cargo test`, `go test`, `pnpm test`, or equivalent.

## Intent routing

| User says | Mode |
|-----------|------|
| "implement this spec", "plan the implementation", "what order should I implement these", "what can I build in parallel", "where are the seams", "what's the dependency order" | **Plan** |
| "execute phase N", "build this phase", "TDD this rule", "implement rule R3", "do the next phase", "implement the next batch" | **Phase** |
| "review implementation against spec", "is the code done for X", "what's left to implement", "compliance check", "what needs graduating", "red-team this implementation" | **Review** |

When ambiguous (e.g. "implement X"), prefer **Plan** if no plan exists yet, **Phase** if a plan was already produced in this session, **Review** if the user says "check" or "done" or "ready".

### Session state machine

Track session state with a marker at the top of each response:

```
[DAG-PLAN STATE: NO_PLAN]        -- no plan produced yet
[DAG-PLAN STATE: PLAN_PRODUCED]  -- plan produced, awaiting approval
[DAG-PLAN STATE: PHASE_N_ACTIVE] -- executing phase N
[DAG-PLAN STATE: PHASE_N_DONE]   -- phase N complete, next phase or review
[DAG-PLAN STATE: ALL_PHASES_DONE] -- all phases complete, review pending
[DAG-PLAN STATE: REVIEW_COMPLETE] -- compliance report delivered
```

```
NO_PLAN ──Plan──> PLAN_PRODUCED ──approval──> PHASE_1_ACTIVE
                       ^                           │
                       │                 checkpoint pass
                  PLAN_INVALIDATED                 │
                       ^                    PHASE_N_DONE ──┐
                       │                           ^       │
              structural amendment                 │       v
              or midgame re-plan            failure protocol
                       │                           │
                PHASE_N_ACTIVE ──────────> PHASE_N_DONE
                                                   │
                                                   v
                              PHASE_(N+1)_ACTIVE <─┘ (if more phases)
                                    ...
                              ALL_PHASES_DONE ──Review──> REVIEW_COMPLETE
```

**Plan invalidation:** If a phase failure classifies as "spec is wrong"
with structural implications (new crate boundary, changed dependency
edge, altered type signature), or if the midgame review identifies spec
amendments that change the dependency graph, the plan is invalidated.
The next invocation MUST re-run Plan mode with fresh corpus data before
resuming Phase mode. Write `[DAG-PLAN STATE: PLAN_INVALIDATED]` to
`.mast/dag-plan-state.md` with the reason.

Persist state across context resets by writing to `.mast/dag-plan-state.md` at each transition (see Carry-forward persistence below).

## Scale thresholds

All conditional branches in one place:

| Condition | Action |
|-----------|--------|
| Target set = 0 specs | Early exit: "No specs in target set. Check filters." |
| Target set contains draft/retired specs | Filter them out, warn: "Filtered N draft/retired specs: <list>. Proceeding with pending/active only." |
| Target set < 5 specs | Single-thread Plan (main thread runs Steps 1-9, no subagent dispatch) |
| Target set >= 5 specs | Dispatch 4 competing subagent proposals |
| Plan has < 3 phases AND < 10 total rules | Skip midgame review; go directly opening to endgame |
| Plan has >= 3 phases OR >= 10 total rules | Midgame review required at ~50% graduation or first join point |
| Review scope > 5 specs | Dispatch per-spec compliance checks to subagents |
| TDD cycle fails 3 consecutive attempts on same rule | Invoke failure protocol, do not retry |

## When NOT to use

Each intent routes to exactly one skill; the cross-skill routing table and the bypass-gate are shared -- see **REF-ROUTING**.

- **Writing or editing specs.** Use `/mast:spec`. This skill reads specs; it does not author them.
- **Corpus health check or scored audit.** Use `/mast:check`.
- **Mining a corpus from code.** Use `/mast:mine`.
- **Orientation or walkthrough.** Use `/mast:orient`.

---

## Modes / playbooks

This skill has three modes. Each below is a playbook with its own **Gather** (what to read / query), **Render** (the output shape), and **Budget** (the discipline that bounds it).

## Mode: Plan

**Goal:** Given a set of specs (typically `pending` status) and optionally design documents, produce an implementation DAG: a phased execution plan with dependency ordering, parallelism lanes, seams, join points, tempo staging, and risk assessment.

**Gather.** Run the corpus-wide batch (Step 1), then either run Steps 2-9 in the main thread (< 5 specs) or dispatch 4 competing subagent proposals and synthesize them (>= 5 specs). The dependency triad the graph is built from -- `Depends on` / `extends` / `Cites` -- is shared doctrine; see **REF-DEPENDENCIES**.

### Step 1 -- Gather corpus-wide data (batch)

Run five corpus-wide queries to gather the data needed downstream. Do NOT fan out per-spec at this stage.

```bash
mast list specs --status pending       # identify targets
mast list deps                     # all dependency edges
mast list rules                    # all rules with status chips
mast list targets                  # all target file references
mast list extends                  # all extends edges
mast list constitutions 2>/dev/null # governance layer (if present)
```

If the user named specific specs, filter the output to those. Otherwise, the target set is all `pending`-status specs from the first command.

**Amendment-driven change sets.** When the work is a design decision amending
EXISTING (often active) specs — a language change, a policy cutover, a review's
findings ledger — the target set is not pending-status specs but the specs the
design amends plus the specs governing every touched code surface. In this mode:
(1) the spec amendments themselves are first-class plan nodes that precede their
implementing code phases (via `/mast:spec`); (2) the design decisions must be
stated verbatim in every subagent brief — the corpus does not yet contain them;
(3) the plan output MUST include amendment briefs: the drafted normative text
(MUST constraints, `success.<name>` oracles) per amended spec, so executors
patch text in rather than authoring normative language; (4) check certification
state — amending a certified spec flips its compliance to pending and adds an
inspector re-certification node to the endgame.

**Early exits:**
- If the target set is empty after filtering, stop: "No specs in target set. Check filters."
- If any specs are draft or retired, filter them out and warn: "Filtered N draft/retired specs: <list>. Proceeding with pending/active only."

**Corpus validation:** For each target spec, spot-check that declared
`Depends on` edges are consistent with actual `use`/`import` statements
in the Targets files. If a target file imports a crate not listed in
the spec's `Depends on`, warn: "Possible undeclared dependency: <spec>
imports <crate> but does not declare a dep on the spec governing it."
This prevents correlated subagent failures where all 4 proposals build
on the same defective dependency graph.

From the `mast list deps` output, identify which target specs are blocked by non-active dependencies. Partition into "ready" (no blockers among target set or all deps are active) and "blocked" (depends on non-active specs outside the target set). Report blockers immediately. Proceed with the ready set.

### Step 1b -- Dispatch decision

```
              Step 1 complete
                    │
                    v
         ┌── target set size? ──┐
         │                      │
     < 5 specs             >= 5 specs
         │                      │
         v                      v
  SINGLE-THREAD            SUBAGENT
  Main thread runs         Main thread sends
  Steps 2-9 directly       Step 1 data to 4
                            subagents; each
                            runs Steps 2-8
                            with its strategy;
                            main thread runs
                            Synthesis + Step 9
```

**Single-thread path (< 5 specs):** Continue with Steps 2-9 below in the main thread.

**Subagent path (>= 5 specs):** Dispatch 4 subagents with the briefs in "Subagent strategy briefs" below. Each subagent receives the Step 1 data and runs Steps 2-8 per its strategy. Each returns a plan proposal in the "Plan output template" format. The main thread then runs the Synthesis procedure and presents the merged plan (Step 9).

### Step 2 -- Build the dependency graph

From the batched `mast list deps` and `mast list extends` output (already gathered), extract the edges among the target specs. Compute the topological order. If the graph has cycles, report them as a blocking finding and stop.

Only call `mast spec read <id> --with-blocked-by` for specs whose blocker status is ambiguous from the deps list (e.g., transitive blockers through non-target specs). Do not fan out this call for every target.

### Step 3 -- Map specs to code targets

From the batched `mast list targets` output, group specs by the crate or module they target. Specs targeting the same crate should be implemented together when possible -- shared context reduces ramp-up.

If architecture files exist (check `mast list domains --count`), run `mast describe attached <id>` only for specs whose attachment set you need to inspect, not for every target. Attachment is derived from a spec's `uses { component:Name } from <domain>` imports and rule-chip component refs -- there is no `attached_to:` header to filter on.

### Step 4 -- Extract rule inventory

From the batched `mast list rules` output, catalog the rules per target spec. For each rule, record:
- Rule ID (bare numeric: `3`, not `R3`) and status chip (`[pending]`, `[active]`, etc.)
- Constraint count (from the `constraints=N` column)

Only call `mast spec read <id> --with-rules` for specs that need deep inspection (high constraint count, or the spec is a join-point dependency). For specs with fewer than 5 rules, the `mast list rules` output is sufficient for planning.

Count the total MUST constraints across all target specs. This is the minimum test count for full coverage.

### Step 5 -- Identify phases, parallelism, and seams

Partition the topological order into phases. A phase is a set of specs (or rule groups within specs) that can be implemented together because:
- Their dependencies are already implemented (in a prior phase or already active)
- They target the same crate or module (shared context)

For each phase, identify:

**Parallelism opportunities.** Independent specs within the same phase that touch different crates can be built concurrently. Two specs are independent when ALL of the following hold:
1. Neither appears in the other's transitive `Depends on` or `extends` closure.
2. They share no files in their `Targets` lists.
3. They do not share a transitive dependency whose implementation has not yet landed (diamond deps). If A and B both depend on D, and D is in the same phase, stub D's interface FIRST as a pre-phase step before A and B begin parallel work.

**Join points.** Where parallel work must synchronize -- typically when a later-phase spec depends on results from two or more earlier parallel specs.

**Seams.** API boundaries where independently-developed work meets. Identify them by finding Targets overlaps and cross-spec `Depends on` edges that cross crate boundaries. For each seam, note whether the interface shape is stubbable -- see T1 in "Implementation techniques."

**Collapse trivial phases.** After initial phasing, merge consecutive single-spec phases that target the same crate into a single phase. A 7-phase plan where each phase has 1 spec in the same crate is better implemented as 2-3 phases. The overhead-to-work ratio of phase transitions (pre-flight, checkpoint, carry-forward) is too high for single-spec phases.

**Order work so the build is never broken between items:** add the new path, switch callers, then remove the old path. The same rule applies inside a phase as between phases.

### Step 6 -- Risk assessment

For each phase, identify red-team surfaces:

- **Cross-crate boundaries.** Rules that span multiple crates are harder to test in isolation.
- **Exhaustive dispatch points.** Rules requiring handling every variant of an enum or match.
- **Shared mutable state.** Rules describing concurrent access or atomicity requirements.
- **Pure-function candidates.** Rules describing multi-dimensional decisions.
- **Layer-separation constraints.** Rules describing relationships where direct import is forbidden by `build-topology` or `internal/archtest`.

Source risk signals from the specs: `Cites` chains, `Invariant I<n>` entries (now first-class rules-section entries, citable via `Cites <spec>.I<n>`), and `Depends on` density.

- **Design/Plan-anchor risk.** Specs whose targets consist entirely of anchors where `blocks_graduation()` holds (`AnchorKind::Design` for `-design.md`, `AnchorKind::Plan` for `-plan.md` -- the AnchorKind taxonomy and which kinds block graduation are shared doctrine; see **REF-LIFECYCLE**) are not graduation-ready. Flag them in the risk assessment -- Design and Plan anchors must be replaced with anchors that do not block graduation (`Code`, `Context`, `Skill`, or `Doc`) before `set-status active`.
- **Governance constraints.** If constitutions exist, check whether target specs' Targets fall under governed domains (`mast describe governance-for <path>`). The generic governance model (certified=error / pending=warning / waived=info severity modulation, the ratchet) is shared doctrine; see **REF-GOVERNANCE**. Governed specs have severity modulated by compliance state -- certified rules produce errors on violation, pending rules produce warnings. Rules in a domain certified at a higher tier carry more risk if the implementation introduces a violation.

### Step 7 -- Estimate effort

For each phase:
- **S (small):** 1-3 MUST constraints, single crate, no cross-crate seams
- **M (medium):** 4-8 MUST constraints, or 2 crates, or 1 seam
- **L (large):** 9+ MUST constraints, or 3+ crates, or 2+ seams

Effort estimation is a rough guide, not a commitment. Constraint count is a poor proxy for implementation difficulty -- a single constraint requiring error-recovery restructuring can outweigh ten field-presence constraints. The Phase failure protocol is the real calibration mechanism; effort labels set expectations, not hard budgets.

### Step 8 -- Recommend techniques

Based on the plan structure, recommend applicable techniques from the "Implementation techniques" section. Use the technique selection guide (decision tree in that section) to determine which apply. Include the recommended techniques per phase in the plan output.

### Step 9 -- Present the plan

Render the plan using the "Plan output template" below. Wait for user approval before proceeding to Phase mode.

**Persist the plan as a design doc.** Write the rendered plan to `docs/<spec-id>-plan.md` (lowercase, case-sensitive `-plan.md` suffix; `docs` is the default `docs_dir`, overridable in `mast.toml`). When the target set is a single spec, name the file after that spec; for a multi-spec plan, name it after the root spec of the dependency graph. This file is a `Plan` anchor (`AnchorKind::Plan`) and satisfies `blocks_graduation()` -- so suggest the user add a `plan: docs/<spec-id>-plan.md` header to the spec to link the plan to the spec it implements. The `plan:` header is validated for existence and warns (stale) on active specs, but a `.md` plan anchor is never a parse error. Do not confuse this with `.mast/dag-plan-state.md`, which holds session/transition state, not the plan itself. The plan doc is a derived, disposable projection of the spec graph -- generated from the corpus, never stored beside the rules as normative content. When the corpus changes, regenerate the plan from fresh `mast list` data rather than hand-amending a stale plan doc; the `Plan` anchor blocking graduation is the mechanism that forces the projection to be shed once the work lands.

**Executor hardening (required when execution is delegated).** When the phases
will be executed by weaker models or an autonomous loop rather than this
session, the plan doc MUST additionally carry: (1) a **per-item validation
matrix** -- for every work item, the exact verification command and its
expected output; checkpoints are pasted output, never self-assessment. A row
MAY carry an item-specific STOP predicate ("if X proves false, stop and
report"); a tripped predicate routes directly to the Phase failure protocol
classification without burning the 3 TDD attempts. Strategy D's hypotheses
are the natural source of predicates. Plan-time probe results MUST embed the
pasted command output, and the executor re-runs every tripped predicate
before honoring it -- predicate output is authoritative over plan prose;
(2) **amendment briefs** -- drafted normative text per amended spec (see Step 1)
so executors patch text in rather than author it; (3) an **executor guardrails**
section -- the non-negotiables (CLI-mediated spec access, never weaken a failing
test, file-count caps per item, the architecture invariants from AGENTS.md),
plus evidence-audited reports: the executor audits every claim in its
completion report against an actual tool result from its session; failed or
skipped verifications are reported plainly, never papered over;
(4) a **drift check** -- the plan stamps `Planned at: <git rev-parse --short
HEAD>`, and the executor's FIRST action is `git diff --stat <SHA>..HEAD --
<in-scope paths>`. Empty output means no drift: proceed. Non-empty output
routes to the Phase-mode corpus-drift check for classification -- only
structural graph changes write `[DAG-PLAN STATE: PLAN_INVALIDATED]`; benign
drift (rules graduated elsewhere, doc-only hunks) is folded in with a warning;
(5) a **per-phase out-of-scope list** -- files that look related but must NOT
be touched, derived from neighboring specs' Targets where Targets exist
(retired-spec surfaces and zero-Targets specs need manual enumeration), plus
files under domains with certified compliance (violations there are linker
errors). A delegated executor improvises wherever the plan leaves a blank;
these five sections are where the blanks were. The plan doc must be executable
by a model that has only the file, the repo, and the mast CLI -- any "as
discussed", any skill-internal vocabulary (T1-T6, tempo labels, "failure
protocol") used without an inline definition, and any appeal to session
context is a defect.

**Loop handoff (optional).** If the user will drive execution with a recurring
loop (the `/loop` skill -- there is no `mast loop` CLI command), also emit an iteration protocol file
(`.mast/loop-<plan-name>.md`): resume from `.mast/dag-plan-state.md`, pick ONE
eligible item per iteration (parallel lanes only where the plan declares them),
route spec edits to `/mast:spec` and code to the TDD cycle, checkpoint with the
item's validation row, commit, persist state, and end the turn. Include the
failure protocol (3 attempts, two no-progress iterations -> BLOCKED-and-skip)
and a done-when gate made of concrete commands -- completion sentinels without
verifying commands are how loops exit early with work remaining.

**Quality bar (check before presenting; all must hold when execution is delegated).**
- Every validation row is a command plus the expected output that command actually produces -- not a judgment ("works correctly"), not a property the command cannot test.
- Every item names exact specs, rules, and files -- never "the relevant module"; every placeholder is bound to a concrete path or value.
- Every file path named in the plan is verified to exist at plan time, or explicitly marked "to be created".
- No unresolved `[USER DECISION]` tags in a plan handed to an executor -- resolve them, or split the undecided item out of the delegated scope. Rules with no validation row get an explicit disposition (skip / manual check / ask).
- STOP predicates are item-specific, not boilerplate; `Planned at:` SHA, git workflow, and the normative binary invocation are filled in; rows asserting "no new findings" name the baseline-capture command run first.
- Counts reconcile: phase rule and constraint totals match the header arithmetic, including conditional splits ("12 ready" and "rule 2 only after amendment" cannot both be true -- state "11 + 1 blocked").
- Expected outputs come from running the command at plan time and pasting the result -- never transcribed from spec text. Where spec and binary disagree, surface the disagreement as a finding in the plan; do not encode either side as the expectation.
- The plan names the repository, branch, and remote the work lands in. A checkout with no pushable remote cannot satisfy a push/PR workflow -- if planning from a scratch checkout, say how the work migrates.
- Commands and expected outputs are verbatim-executable as written: if markdown table escaping (e.g. `\|`) would corrupt them, move them into fenced blocks instead of table cells.
- After any item that changes code, later validation rows say to rebuild before reusing a prebuilt binary -- stale-binary greens are false greens.

**Cold read (required when execution is delegated).** After the quality bar,
dispatch one fresh-context subagent whose prompt contains only the plan file
path and "you are an executor with zero context: list every ambiguity, missing
fact, or unverifiable step that would block you." Fold its findings back into
the plan before presenting. Self-critique misses gaps you mentally fill from
context the executor won't have. In harnesses that run subagents
asynchronously, do not block your final output on the cold reader: deliver
the plan and your own findings first and fold the cold read in as a
follow-up when it returns -- a parent that waits on a nested agent can be
orphaned with its report lost.

**Render.** The "Plan output template" below: a phased plan with per-phase effort/tempo labels, parallelism, seams, join points, out-of-scope lists, risk, techniques, and a graduation path -- persisted to `docs/<spec-id>-plan.md` and (when delegated) hardened with the five executor sections and a cold read. Wait for user approval before Phase mode.

**Budget.** Subagent proposals are 1500 words each (the common-brief cap). Plan presentation favors exact specs/rules/files and pasted command output over prose; every notation used (T1-T6, tempo labels, effort letters, lane/seam vocabulary) is glossed inline or marked "none used."

---

### Plan output template

```
## Implementation Plan

Target specs: <N> specs, <M> total rules, <K> MUST constraints
Dependency order: <topological list>
Planned at: <git rev-parse --short HEAD>
Git workflow: <branch name> / <commit subject format, with one example from git log>
Binary: <the one normative mast invocation for every command and evidence quote in this plan>
Definitions: <inline gloss for every notation the plan uses -- techniques (T1-T6), tempo labels, effort letters, lane/seam vocabulary -- or "none used">

### Phase 1: <title> [effort: S/M/L] [opening|midgame|endgame]

Specs: <list>
Crates: <list>
Rules: <list with MUST counts, bare numeric IDs>
Parallelism: <which specs can be built concurrently>
Seams: <API boundaries -- note stubbable (T1) seams>
Out of scope: <related-looking files that must NOT be touched>
Risk: <red-team surfaces>
Techniques: <applicable T1-T6>
Prerequisite: none (foundation phase)

### Phase 2: <title> [effort: S/M/L] [opening|midgame|endgame]

Specs: <list>
Crates: <list>
Rules: <list with MUST counts, bare numeric IDs>
Parallelism: <opportunities>
Join points: <where prior parallel work synchronizes>
Seams: <API boundaries>
Out of scope: <related-looking files that must NOT be touched>
Risk: <red-team surfaces>
Techniques: <applicable T1-T6>
Prerequisite: Phase 1 complete

### ...

## Graduation path

After all phases: <N> rules ready for graduation
Command: mast spec patch <id> rule set-status <rule-id> --status active --anchor <symbol>
```

Tempo labels (`[opening]`, `[midgame]`, `[endgame]`) are required on every phase. Rule IDs are bare numeric throughout (R3 in the spec maps to `3` in the CLI and in this plan).

---

### Subagent strategy briefs

Always dispatch exactly 4 subagents (A breadth, B depth, C risk, D funnel). Each receives the same common brief plus its strategy-specific brief.

#### Common brief (sent to all 4)

- The corpus-wide data from Step 1 (spec list, deps, rules, targets, extends edges)
- Instructions to: read specs via `mast spec read <id> --with-rules`, run Steps 2-8 per its strategy, and return a complete plan proposal in the Plan output template format
- Access to `/mast:spec` for deep reads and `/mast:orient` for corpus context
- Word budget: 1500 per proposal
- Tempo labeling requirement: annotate every phase as `[opening]`, `[midgame]`, or `[endgame]` using the definitions in "Implementation tempo" below. The tempo label is a required output field.
- Close every brief with: before reporting, audit each claim against an actual tool result from your session -- report only what you can point to evidence for; if a verification failed or was skipped, say so plainly.

#### Strategy A: Breadth-first plan

Maximize parallelism. Group specs into the widest possible phases.

Independence test -- two specs may occupy the same phase in parallel lanes when ALL of the following hold:
1. Neither appears in the other's transitive `Depends on` or `extends` closure.
2. They share no files in their `Targets` lists.
3. They do not both introduce new public types in the same crate (to avoid merge conflicts on `lib.rs` exports).

When specs share Targets files but have no dependency edge, place them in the same phase but the SAME lane (sequential within the phase, not parallel) to avoid file-level conflicts.

Minimize total phase count. Favor throughput at the cost of more seams and join points.

Tempo assignment: front-load phases that introduce crates, traits, or type signatures as `[opening]`. Assign the widest parallel phase (the one with the most concurrent lanes) as `[midgame]`. Place CLI wiring, integration, and polish phases as `[endgame]`.

#### Strategy B: Depth-first plan

Minimize seams. Implement one complete vertical slice before starting the next.

Slice selection procedure:
1. Enumerate all maximal dependency chains in the target set (root spec through its longest transitive `Depends on` path to a leaf).
2. Score each chain: `total_MUST_constraints * distinct_crate_count` (call this the "slice weight").
   Higher slice weights exercise more spec surface across more structural boundaries per slice.
3. If top two chains tie (within 10%), prefer the one whose root spec has the most inbound `Depends on` edges (it unblocks more work).
4. The winning chain is the first slice. Remaining specs are partitioned into subsequent slices by repeating steps 1-3 on the residual graph.

Implement each slice foundation-through-surface before starting the next. Mark the first slice as `[opening]`, subsequent slices as `[midgame]`, and the final integration pass as `[endgame]`.

#### Strategy C: Risk-ordered plan

Front-load uncertainty. Score each spec on four dimensions, then schedule highest-risk specs earliest.

Risk scoring procedure (produces a "risk composite" per spec):
1. For each target spec, compute four raw scores:
   - `must_count`: number of MUST constraints
   - `seam_count`: number of distinct crates in Targets
   - `cite_depth`: longest inbound `Cites` chain (0 if none)
   - `dep_fanout`: number of direct `Depends on` edges
2. For each dimension, rank the specs 1st through Nth (ties share the same rank). If the max raw value minus the min raw value is less than 2 for a dimension, exclude that dimension from scoring (insufficient variance to discriminate).
3. Risk composite = sum of ranks across included dimensions (lower rank number = higher risk = scheduled earlier).
4. Sort specs by risk composite ascending (lowest sum = highest risk first).
5. Schedule each spec into the earliest phase that its dependency order permits. When a high-risk spec is blocked by a low-risk dependency, bundle them in the same phase (dependency first).

Tempo assignment: phases dominated by specs in the top third of risk composites are `[opening]`. Phases with mixed-rank specs are `[midgame]`. Phases containing only bottom-third specs are `[endgame]`.

#### Strategy D: Uncertainty-funnel plan

Structure phases by INFORMATION GAIN, not work size or risk rank. Where Strategy
C front-loads the riskiest work items, Strategy D front-loads the cheapest
probes that collapse the most uncertainty, and widens parallelism only as the
funnel narrows.

Procedure:
1. Enumerate the load-bearing HYPOTHESES the change set rests on — claims that,
   if wrong, invalidate downstream structure (a data model fits all contexts;
   the corpus survives a migration; a budget/cap holds; a hash or wire format
   is unaffected).
2. Score each hypothesis: impact-if-wrong × current uncertainty.
3. **Run pure-measurement probes NOW, at plan time** — greps, `wc`, dry-run
   counts over the real corpus, reading the implicated source file. Fold the
   RESULTS into the proposal (a "Hypotheses & probe results" section above the
   phase list). Do not plan a phase for what a 5-minute command can answer;
   measured numbers settle divergences that argument cannot.
4. Probes that need code (a tracer construct end-to-end, a converter dry-run)
   become Phase 1, with an explicit **Decision gate** listing what must be true
   to enter Phase 2.
5. Later phases commit structure only on validated hypotheses; each phase ends
   with a Decision gate.

Tempo assignment: probe/spike phases are `[opening]`; committed build-out is
`[midgame]`; wide mechanical execution and landing are `[endgame]`. Each phase
in the proposal carries a `Decision gate:` field in addition to the standard
template fields.

---

### Synthesis procedure

The main thread receives all 4 proposals and produces a merged plan.

**Step S1 -- Rank each proposal.** Fill in the comparison table using ordinal ranks (1st through 4th) per dimension. Do NOT compute continuous normalized scores.

```
## Proposal comparison

| Dimension              | Weight | A (breadth) | B (depth) | C (risk) | D (funnel) |
|------------------------|--------|-------------|-----------|----------|------------|
| Phase count            | 1      | <rank>      | <rank>    | <rank>   | <rank>     |
| Max parallelism        | 2      | <rank>      | <rank>    | <rank>   | <rank>     |
| Seam count             | 2      | <rank>      | <rank>    | <rank>   | <rank>     |
| Risk front-loading (%) | 3      | <rank>      | <rank>    | <rank>   | <rank>     |
| Tempo alignment        | 3      | <rank>      | <rank>    | <rank>   | <rank>     |
| Technique coverage     | 1      | <rank>      | <rank>    | <rank>   | <rank>     |
| **Weighted rank sum**  |        | **<sum>**   | **<sum>** | **<sum>**| **<sum>**  |
```

For risk front-loading, probes already RUN at plan time count as risk retired in
phase zero — a proposal that arrives with measured numbers outranks one that
schedules the same measurement as future work.

Ranking rules per dimension:
- **Phase count:** fewer phases = rank 1. Lower is better.
- **Max parallelism:** most concurrent specs in any single phase = rank 1. Higher is better.
- **Seam count:** fewest cross-crate API boundaries = rank 1. Lower is better.
- **Risk front-loading:** highest percentage of total risk composite concentrated in the first half of phases = rank 1. Higher is better.
- **Tempo alignment:** score 0-2 per proposal: +1 if ALL structural decisions appear exclusively in `[opening]` phases; +1 if ALL surface work appears exclusively in `[endgame]` phases. Best score = rank 1.
- **Technique coverage:** most distinct T1-T6 techniques recommended = rank 1.

For ties on a dimension, all tied proposals share the best rank (e.g., two proposals tied for first both get rank 1).

Weighted rank sum = sum of (rank * weight) across all dimensions. Lowest sum wins (rank 1 is best).

**Spec coverage validation:** Before scoring, verify that every target spec appears in at least one phase of every proposal. If a subagent dropped specs (due to budget pressure or oversight), flag the missing specs and assign them to the phase their dependency order dictates in the merged plan.

**Step S2 -- Extract fixed points.** List decisions where all proposals agree. Typical fixed points: foundation phase contents, dependency-graph roots, graph leaves, identified risk surfaces. Fixed points carry into the merged plan unchanged.

If the fixed-point set is empty (proposals are too divergent), adopt the highest-ranked proposal wholesale and note the divergences from the others as "alternative placements."

**Step S3 -- Resolve divergences.** For each spec that appears in different phases or tempo stages across proposals:

```
Divergence: <spec-id>
  A says: <placement and rationale>
  B says: <placement and rationale>
  C says: <placement and rationale>
  Resolution: <adopt the option from the highest-ranked proposal on
    this dimension, OR flag "user decision needed" if the top two
    proposals are within 1 weighted rank point>
```

**Step S4 -- Merge into final plan:**

1. Start with the fixed points from S2 as the skeleton.
2. For each resolved divergence from S3, adopt the winning option.
3. For unresolved divergences, present both alternatives inline with a `[USER DECISION]` tag and a one-sentence tradeoff summary.
4. Verify topological order: no spec appears before its dependencies. If the merge broke ordering, demote the offending spec to the next phase.
5. Re-assign tempo labels using the canonical definitions (see "Implementation tempo").
6. Validate tempo: if any structural decision (new crate, new trait, new public type) appears in an `[endgame]` phase, promote to `[midgame]`. If surface-only work appears in `[opening]`, defer to `[endgame]` unless it is a dependency.

**Step S5 -- Recommend or ask.** If the weighted rank sum has a clear winner (margin >= 2 points), recommend that proposal's plan (with fixed-point corrections and merge adjustments). If the margin is < 2, present the comparison table and unresolved divergences to the user and ask which they prefer.

---

### Phase mode subagents -- parallel execution

For phases with parallel lanes (independent specs targeting different crates), dispatch each lane to a subagent. Brief each with:
- The spec(s) and rule(s) for its lane
- The technique recommendations from the plan (T1-T6)
- The tempo stage annotation
- Access to `/mast:spec` for reading cited specs and upstream contracts
- Access to `/mast:check` for pre-flight and checkpoint verification
- Instructions to follow the TDD cycle (Steps 3a-3e) and commit at each checkpoint per version control conventions
- When the lane runs in an isolated worktree: inline the full plan/brief text (worktrees contain only committed files -- an uncommitted plan doc is invisible there), and expect an install-then-build first step (fresh worktrees lack node_modules/target); that is setup, not a deviation

The main thread merges results at the join point and runs the midgame review if applicable.

### Review mode subagents -- parallel audit

When reviewing more than 5 specs, dispatch per-spec compliance checks to subagents. Each subagent reads the spec via `/mast:spec`, searches for tests and implementations in the target files, and returns the three-dimension verdict (coverage, implementation, anchor). The main thread synthesizes the gap analysis and compile-time enforcement audit.

---

## Mode: Phase

**Goal:** Execute one phase of an implementation plan. For each rule group, drive a TDD cycle: write test, implement, verify, checkpoint. The output is tested code ready for graduation.

**Gather.** Confirm the phase, re-read its spec rules fresh (`mast spec read <id> --with-rules`), pre-flight that target files exist, run the corpus-drift check, and verify the build compiles on HEAD before writing any code.

### Step 1 -- Confirm the phase

State which phase you are executing and which specs/rules it covers. If no plan exists from a prior Plan mode invocation, run a lightweight version of Plan (Steps 1-4) first to establish context.

Re-read the target spec rules fresh (do not rely on cached rule IDs from plan time -- specs may have been amended):

```bash
mast spec read <id> --with-rules
```

### Step 2 -- Pre-flight

Verify all referenced files exist before writing any code. For each spec in this phase:

```bash
mast list targets
# For each target file:
test -f <path> && echo "OK: <path>" || echo "MISSING: <path>"
```

If target files are missing, report them. If the files need to be created (new module), note that in the implementation sequence. If the files should exist but do not, stop and ask -- the spec may reference code that was renamed or deleted.

**Corpus-drift check:** Re-query `mast list deps` and `mast list rules`
for the target specs. Compare against the plan's assumptions:
- If a new dependency edge appeared (spec amended between phases), warn
  and check whether phase ordering is still valid.
- If rules that were `[pending]` at plan time are now `[active]` (graduated
  by another agent or human), skip them in this phase.
- If the dependency graph changed structurally, write
  `[DAG-PLAN STATE: PLAN_INVALIDATED]` and re-run Plan mode.

Also verify the build compiles before starting:

```bash
cargo check --workspace   # or project-equivalent type-check
mast lint check .
```

Note: `mast lint check .` validates spec-to-spec consistency (deps, refs, targets). It does NOT validate spec-to-code compliance -- that is what the TDD tests in Step 3 do.

Reserve full test suite runs for checkpoints (Step 3e). If the type-check fails on HEAD, stop and report. If it passes but pre-existing test failures exist in crates outside your phase's targets, note them and proceed.

### Step 3 -- Rule-by-rule TDD

#### Tempo determination

If the plan annotated each phase with a tempo label (`[opening]`, `[midgame]`, `[endgame]`), use that label directly. This is the default path.

Fallback (only when entering Phase without a prior Plan -- e.g., the user jumped straight to "execute phase N"):

```bash
# Count graduated (active) rules among the target specs
mast list rules | grep -E '<target-spec-ids>' | grep -c 'status=active'
# Count total rules among the target specs
mast list rules | grep -E '<target-spec-ids>' | wc -l
# Ratio = active / total
```

Apply the thresholds: 0-30% active = opening, 30-70% active = midgame, >70% active = endgame.

For plans with fewer than 3 phases AND fewer than 10 total rules, skip the midgame review and go directly from opening to endgame. Otherwise the midgame review is required (see midgame review checkpoint below).

#### TDD cycle state machine

For each rule in this phase, execute the following cycle. Process rules within a spec in numeric order (1 before 2). Process specs in dependency order.

```
         ┌──────────────────────────────────────┐
         v                                      │
   READ RULE ──> WRITE TEST ──> IMPLEMENT ──> VERIFY
                      │              │           │
                      │              │      pass │ fail (attempt < 3)
                      │              │           │     │
                      │              │     CHECKPOINT   └──> fix ──┐
                      │              │           │                  │
                      │              │      next rule              │
                      │              │                             │
                      │              └── fail (attempt 3) ──> FAILURE PROTOCOL
                      │
                      └── cannot write test ──> flag under-specified ──> SKIP
```

Maximum 3 attempts per rule (write/implement/verify counts as one attempt). After 3 failures, invoke the failure protocol.

#### 3a. Read the rule

Parse the rule's constraints:
- Each MUST constraint becomes at least one test case
- Each SHOULD constraint becomes a test case marked with a comment noting it is recommended
- Each `success.<name>` constraint provides the oracle

If the rule has `Cites <spec>.R<n>` (or `Cites <spec>.I<n>` -- invariants are citable in mast/3), read the cited rule or invariant (the `Cites` content-pinning mechanism is shared doctrine; see **REF-DEPENDENCIES**):

```bash
mast spec read <cited-spec> --with-rules
# Find the cited rule (R<n>) or invariant (I<n>) in the output to understand the upstream contract
```

#### 3b. Write the test first

For each MUST constraint, write a test that will fail until the implementation is correct. The test name should reference the rule and constraint:

```rust
// Example: testing ci-gates R4's title_format constraint
#[test]
fn r4_title_format_rejects_malformed_prefix() {
    // Arrange: a PR title that violates the constraint
    // Act: run the validation
    // Assert: validation fails with the expected diagnostic
}
```

Design principles for tests:
- **Exhaustive case coverage for dispatch logic.** If the rule describes N cases, write N+1 tests (one per case plus a "no other cases" assertion if the language supports it).
- **Table-driven tests for multi-dimensional decisions.** If the rule describes a matrix, express the full table as test data and iterate.
- **Pure function extraction.** If the rule describes a decision with no side effects, extract it as a pure function and test with property-based or table-driven tests.

Run the tests to confirm they fail:

```bash
cargo test --lib <test_name>   # or project-equivalent
```

#### 3c. Implement

Write the minimum code to make the tests pass. See "Cross-cutting implementation patterns" and "Implementation techniques" for applicable patterns -- do not repeat their content here; follow the technique selection guide.

#### 3d. Verify

Run the rule's own tests at the finest granularity available:

```bash
cargo test -p <crate> <test-filter>   # or project-equivalent; reserve --workspace for checkpoints (3e)
```

If tests fail, fix the implementation. Do not weaken the test to match broken code.

#### 3e. Checkpoint

After completing each rule (or every 2-3 rules if they are small), run full verification:

```bash
cargo test --workspace              # or project-equivalent
cargo clippy --workspace --all-targets -- -D warnings   # Rust only; skip for non-Rust projects
mast lint check .
```

All applicable checks must pass before proceeding to the next rule. If `mast lint check .` surfaces new warnings related to your changes, address them now.

### Phase failure protocol

When a rule's TDD cycle cannot complete (test cannot be made to pass, design assumption collapses, build breaks in an unrelated crate):

1. **Revert the failing rule's uncommitted changes.** Do not revert changes from rules that already passed their checkpoint.

```bash
git restore -- <files-touched-by-failing-rule>
```

2. **Commit passing work.** If earlier rules in this phase passed their checkpoints, commit them now. Partial progress is better than no progress.

3. **Classify the failure:**

   - **Spec is wrong** -- the MUST constraint describes something impossible or incorrect. Document the evidence (the test that proves it). Produce a concrete `/mast:spec` patch command with the proposed amendment. Mark the rule and its downstream dependents as "blocked on amendment."
   - **Implementation is stuck** -- the constraint is correct but you cannot find the right approach. Note what you tried and why it failed. The rule carries forward to the next session.
   - **Pre-existing breakage** -- the build is broken by something outside this phase. Stop and report. Do not layer implementation on a broken base.

4. **Produce a carry-forward summary:**

```
Phase N partial progress:

  DONE:
    <spec-id> R1: implemented + tested, anchor = $symbol
    <spec-id> R2: implemented + tested, anchor = $symbol

  BLOCKED:
    <spec-id> R3: spec amendment needed -- <evidence>
    <spec-id> R4: depends on R3

  CARRY FORWARD:
    <spec-id> R5: stuck -- tried X and Y, both failed because Z

  DESIGN ANCHORS (block graduation):
    <spec-id> R6: still anchored to docs/<spec-id>-design.md (AnchorKind::Design)
    <spec-id> R7: still anchored to docs/<spec-id>-plan.md (AnchorKind::Plan)
```

The DESIGN ANCHORS list tracks anchor migration explicitly: any rule whose
target is still a `Design` or `Plan` anchor (`-design.md` / `-plan.md`, where
`blocks_graduation()` holds) carries forward as not-yet-graduatable until its
anchor is swapped to a `Code`, `Context`, `Skill`, or `Doc` anchor. Empty list
means every rule in this phase reached a non-blocking anchor.

#### Carry-forward persistence

Write the carry-forward summary to `.mast/dag-plan-state.md` so it survives context resets. Include the session state marker, the phase number, and the full DONE/BLOCKED/CARRY FORWARD/DESIGN ANCHORS lists. On session start, if `.mast/dag-plan-state.md` exists, read it and resume from the recorded state.

```bash
mkdir -p .mast
cat > .mast/dag-plan-state.md << 'STATE'
[DAG-PLAN STATE: PHASE_N_DONE]

Phase N partial progress:
  DONE: ...
  BLOCKED: ...
  CARRY FORWARD: ...
  DESIGN ANCHORS: ...
STATE
```

### Step 4 -- Phase completion

After all rules in the phase are implemented and tested (or after the failure protocol has partitioned them):

1. Re-read spec rules to get current rule IDs (in case specs were amended during the phase):

```bash
mast spec read <id> --with-rules
```

2. Run the full check suite one final time:

```bash
cargo test --workspace        # or project-equivalent
mast lint check .
```

3. Partition rules into three buckets:

   - **Ready to graduate** -- implemented, tested, checkpoint passed. Identify the declared Targets/References `$name` for the rule (`--anchor` binds that name, not a raw code symbol).
   - **Needs more work** -- partially implemented or test is incomplete. Note the specific gap.
   - **Blocked** -- waiting on spec amendment or unresolved dependency. Note the blocker.

4. Present the graduation list. Use bare numeric rule IDs.

   **Design/Plan-anchor gate:** Rules whose targets include anchors where `blocks_graduation()` holds (`AnchorKind::Design` for `-design.md`, `AnchorKind::Plan` for `-plan.md` -- see **REF-LIFECYCLE** for the taxonomy) are not graduation-ready. Replace each such anchor with one that passes graduation (`Code`, `Context`, `Skill`, or `Doc`) before running `set-status active` -- otherwise the linker rejects the rule: `active rule R<n> has design/plan anchor <path>; graduate to code anchor`.

   **Graduation gate:** If running interactively (no `<ralph-context>`
   block in the conversation), do not graduate automatically -- present
   the commands and wait for user approval, then hand off to `/mast:spec`.
   If running inside mast-loop (detectable via the `<ralph-context>`
   block), graduation follows the user's loop protocol instead (there is no
   `mast loop` CLI command -- mast-loop is retired; this path applies only
   if a user wires their own loop).

```
Ready for graduation:

  # --anchor names a $ref declared in the spec's Targets/References, not a code symbol
  mast spec patch <spec-id> rule set-status 3 --status active --anchor handler --anchor validator
  mast spec patch <spec-id> rule set-status 4 --status active --anchor title_parser

Needs more work:
  <spec-id> R5: missing test for the error-path constraint

Blocked:
  <spec-id> R6: blocked on spec amendment (see carry-forward summary)
```

5. If this is the last phase and all rules are ready, note that the specs are ready for full graduation. When the last `[pending]` rule in a `[pending]` spec is set to `[active]`, the spec-level status auto-flips to `[active]`.

6. Run `mast context render` if any spec status changed, to keep AGENTS.md zones current.

7. Update `.mast/dag-plan-state.md` with the new state marker.

**Render.** A graduation list partitioned into Ready to graduate / Needs more work / Blocked (bare numeric rule IDs), with concrete `mast spec patch ... rule set-status` commands for the ready set, plus a carry-forward summary persisted to `.mast/dag-plan-state.md`.

**Budget.** 3 attempts max per rule before the failure protocol; checkpoints run the full suite and are non-negotiable; never weaken a failing test to make it pass.

---

## Mode: Review

**Goal:** Audit existing implementation against specs. For each rule, determine whether the code satisfies it. Produce a compliance report with gaps, coverage metrics, and graduation readiness.

**Gather.** Identify the review scope, read each in-scope spec full (`mast spec read <id> --with-rules --with-blocked-by`), then search the target files for tests, implementations, and anchor symbols. For > 5 specs, fan the per-spec compliance checks out to subagents.

### Step 1 -- Identify review scope

If the user named specific specs, review those. Otherwise, find specs with mixed rule statuses (some `[pending]`, some `[active]`) -- these are partially implemented:

```bash
mast list specs --status pending
mast list specs --status active
mast list rules
```

For each spec in scope, read the full content:

```bash
mast spec read <id> --with-rules --with-blocked-by
```

### Step 2 -- Rule-by-rule compliance check

For each rule in the target specs, evaluate three dimensions:

#### 2a. Test coverage

Does a test exist that exercises this rule's MUST constraints?

```bash
# Search for test functions referencing the rule
rg "r<N>|<constraint_name>" --type rust -l   # adapt to project language
# Check if the test actually asserts the constraint
rg "<constraint_name>" --type rust -A 5
```

Verdicts per constraint:
- **COVERED** -- a test exists that directly exercises the constraint
- **PARTIAL** -- a test exists but does not cover all cases
- **MISSING** -- no test found

#### 2b. Implementation presence

Does code exist that enforces the constraint?

```bash
rg "fn <anchor>|struct <anchor>|mod <anchor>" --type rust
```

Verdicts:
- **ENFORCED** -- code exists and the constraint is structurally enforced (compile-time or test-time)
- **IMPLEMENTED** -- code exists but enforcement is runtime-only
- **MISSING** -- no implementation found

#### 2c. Anchor validity

If the rule has code anchors (`$symbol` in the status chip), verify they resolve:

```bash
rg "fn <symbol>|struct <symbol>|mod <symbol>|type <symbol>" --type rust
```

Verdicts:
- **VALID** -- anchor resolves to a real symbol
- **STALE** -- anchor does not resolve (symbol was renamed or deleted)
- **DESIGN/PLAN** -- anchor is `AnchorKind::Design` (`-design.md`) or `AnchorKind::Plan` (`-plan.md`); both satisfy `blocks_graduation()` and active rules carrying either emit `DesignAnchorOnActiveRule` (error). See **REF-LIFECYCLE** for the AnchorKind taxonomy.
- **NONE** -- rule has no anchor (still `[pending]`)

### Step 3 -- Gap analysis

Identify four categories of gaps:

1. **Rules without implementation.** `[pending]` rules with no corresponding code or tests.
2. **Implementation without rules.** Code that enforces behavior not captured in any spec rule. Focus on code in Targets-referenced files.
3. **Stale anchors.** `[active]` rules whose `$symbol` anchors no longer resolve. These need `mast spec patch <id> rule set-status <rule-id> --status amended` or anchor updates.
4. **Constraint-test mismatches.** Rules where the MUST constraint count exceeds the test count, or where tests exist but do not assert the specific constraint.

### Step 4 -- Compile-time enforcement audit

For rules that describe invariants, check whether the implementation uses compile-time enforcement where possible:

- **Exhaustive match.** Does the code use `match` without a wildcard arm? If it uses `_ =>`, the compiler will not catch new variants.
- **Type safety.** Does the code use newtypes or branded types to prevent argument confusion?
- **Sealed access.** Does the code use visibility modifiers to prevent external construction of values that should only come from validated paths?
- **Layer separation.** Does the code respect the crate dependency topology? Check with `cargo tree -p <crate>` or the project's archtest suite.

Report each finding with the specific file and line.

### Step 4b -- Governance compliance (if constitutions exist)

If `mast list constitutions --count` returns > 0, extend the review with governance. The generic governance model (certified/pending/waived severity, the ratchet) is shared doctrine; see **REF-GOVERNANCE**.

```bash
mast list constitutions
# For each target spec's Targets paths:
mast describe governance-for <target-path>
```

For each governed spec, report:
- Which domain governs it and at what tier
- The compliance state for the constitution's rules (certified/pending/waived)
- Whether the implementation satisfies certified rules (violations would be linker errors)
- Whether pending rules have test coverage (they should, even though violations are only warnings -- certification is the goal)

Add a governance section to the compliance report:

```
### Governance compliance

| Spec | Domain | Constitution | Tier | Certified | Pending | Waived |
|------|--------|-------------|------|-----------|---------|--------|
| <id> | <domain> | <constitution> | <tier> | <n> | <n> | <n> |
```

### Step 5 -- Produce the compliance report

```
## Compliance Report: <spec-id> [and N others]

Date: <YYYY-MM-DD>

### Summary

| Spec | Rules | COVERED | PARTIAL | MISSING | Ready to graduate |
|------|-------|---------|---------|---------|-------------------|
| <id> | <N>   | <n>     | <n>     | <n>     | <n> of <N>        |

### Per-rule detail

<spec-id> R<n> [<status>]
  MUST <constraint>: <COVERED|PARTIAL|MISSING> -- <evidence>
  Anchor: <VALID|STALE|NONE>
  Verdict: <READY|NEEDS WORK|BLOCKED>

### Gaps

1. **<title>** -- <description>. File: <path>:<line>.

### Compile-time enforcement

| Pattern | Used | Opportunity |
|---------|------|-------------|
| Exhaustive match | Y/N | <where> |
| Newtype wrappers | Y/N | <where> |
| Sealed construction | Y/N | <where> |
| Layer-clean imports | Y/N | <where> |

### Graduation commands

Ready now:
  mast spec patch <id> rule set-status <n> --status active --anchor <symbol>

Needs work first:
  <id> R<n>: <what's missing>
```

**Render.** A compliance report: a per-spec coverage summary table, per-rule detail with COVERED/PARTIAL/MISSING + anchor validity + verdict, a four-category gap list, a compile-time-enforcement audit table, an optional governance section, and ready-now vs needs-work graduation commands.

**Budget.** Every compliance verdict cites a file path or command; a verdict with no evidence is "inconclusive," not a pass. For > 5 specs, fan out to per-spec subagents and synthesize.

---

## Cross-cutting implementation patterns

These patterns apply across all modes. When spec rules describe one of these shapes, guide the implementation toward the corresponding code pattern.

### Pattern: Exhaustive kind dispatch

When a spec rule enumerates cases, implement with exhaustive `match` (Rust) or exhaustive `switch` (TypeScript). No wildcard arm. Adding a new variant becomes a compile error.

```rust
// Good: compiler enforces exhaustiveness
match severity {
    Severity::Error => /* ... */,
    Severity::Warning => /* ... */,
    Severity::Info => /* ... */,
}

// Bad: new variants silently swallowed
match severity {
    Severity::Error => /* ... */,
    _ => /* ... */,
}
```

### Pattern: Pure function for decision logic

When a spec rule describes a multi-dimensional decision, extract a pure function. All inputs are parameters. Return value is data, not execution. Test with a table of every input combination.

```rust
fn compute_severity(finding: &Finding, context: &Context) -> Severity {
    match (finding.kind, context.is_suppressed) {
        (Kind::Error, false) => Severity::Error,
        (Kind::Error, true) => Severity::Warning,
        (Kind::Warning, _) => Severity::Warning,
    }
}
```

### Pattern: Callback indirection for layer separation

When two crates must not import each other but a spec describes cross-boundary behavior, use callback-based composition. The lower crate defines a trait or accepts a closure; the higher crate provides the implementation.

```rust
// In the lower crate (e.g., store/)
pub fn process<F>(items: &[Item], on_each: F) where F: Fn(&Item) -> Action {
    for item in items {
        let action = on_each(item);
        // ...
    }
}

// In the higher crate (e.g., cli/)
store::process(&items, |item| Action::Accept);
```

### Pattern: Parse at the boundary

When a spec rule describes validation ("X MUST be a valid Y"), validate at the boundary and produce a refined type. Downstream code receives the refined type and never re-validates.

```rust
pub struct SpecId(String);  // private field

impl SpecId {
    pub fn parse(s: &str) -> Result<Self, ParseError> {
        if SPEC_ID_REGEX.is_match(s) {
            Ok(SpecId(s.to_string()))
        } else {
            Err(ParseError::InvalidSpecId(s.to_string()))
        }
    }
}
```

### Pattern: Validate inside the lock

When a spec describes an operation that must be atomic, structure the code so that validation and mutation happen inside the same critical section. Do not validate, release, then mutate.

---

## Implementation techniques

Six techniques that Plan and Phase modes invoke when conditions are right. Each states the detection condition, the action, and an example.

### Technique selection guide

```
New crate introduced?
  yes --> T2 (skeleton crate), then T1 (stub interfaces)

Seam identified with high-confidence shape?
  yes --> T1 (interface stub)
  shape unclear --> defer, implement inline first

3+ phases in pipeline?
  yes --> T3 (tracer bullet) before breadth-first

Spec describes compile-time invariant?
  yes --> T4 (compile-fail test) alongside positive tests

success.<name> constraints on stubbed interface?
  yes --> T5 (contract-first testing)

Multi-dimensional decision in spec?
  yes --> T6 (pure-function extraction)
```

### T1: Interface stubbing at seams

**Detection:** Plan mode identifies a seam where two specs in different dependency subtrees both reference a shared type or method defined by a third spec, and the defining spec's constraints fully specify the signature.

**Action:** Create the type/trait/function with the full public signature and `todo!()` bodies immediately -- before any implementation in either consumer.

**Confidence rating for seams:**
- **Stubbable** -- spec constraints fully define the type signature. Stub it.
- **Shape known, details open** -- parameter types are clear, return/error type has open markers. Do not stub.
- **Exploratory** -- interface will emerge during implementation. Do not stub.

**Example:**

```rust
// manager/src/lib.rs -- stubbed in Phase 0, implemented in Phase 3a
pub trait Manager {
    type Entity;
    fn business_rules(
        &self,
        mutation: &Mutation,
        corpus: &Corpus,
    ) -> Result<Vec<Finding>>;
}

pub fn apply<M: Manager>(
    repo: &Repository<ReadWrite>,
    mutation: Mutation,
    manager: &M,
) -> Result<MutationOutcome, ManagerError> {
    todo!("Phase 3a: manager-layer R6-R8")
}
```

### T2: Skeleton crates

**Detection:** The implementation plan includes a new crate with downstream consumers in later phases.

**Action:** Create the crate skeleton as the very first task in the phase:

1. `mkdir -p <crate>/src`
2. Write `Cargo.toml` with correct dependencies
3. Write `src/lib.rs` with `#![forbid(unsafe_code)]` and public type stubs
4. Add the crate to workspace `Cargo.toml` `members`
5. Add topology edges in `internal/archtest` if applicable
6. Run `cargo build --workspace` to verify compilation
7. Run archtest to verify topology

### T3: Tracer bullets

**Detection:** The plan has 3+ phases with cross-phase dependencies, and the spec set describes a pipeline.

**Action:** Before implementing breadth-first, implement one thin vertical slice through all layers first. Pick the simplest instance of the full pipeline and implement it end-to-end.

How to select the tracer:
1. Pick one rule from the bottom-most phase (foundation)
2. Pick one rule from each intermediate phase that consumes the foundation rule's output
3. Pick one rule from the top-most phase (surface)
4. Together these rules should touch every crate in the pipeline with minimal surface area

**Phase mode integration:** When the user asks to execute Phase 1 and the plan has 3+ phases, suggest the tracer bullet first:

> Before implementing Phase 1 breadth-first, I recommend a tracer bullet: implement one minimal instance through all layers to validate the full pipeline. This would touch rules <list> across phases <list>. Proceed with the tracer, or go breadth-first?

### T4: Compile-fail tests

**Detection:** Spec rules describe a compile-time invariant. Keywords: "compile error", "compile-time", "MUST NOT be callable", "E0004", "E0271", "sealed", "phantom", "cannot construct".

**Action:** Write a test that asserts the WRONG usage does not compile. In Rust, use `trybuild`. In TypeScript, use `tsd` or `@ts-expect-error`.

**Example (Rust with trybuild):**

```rust
// tests/compile_fail/read_only_apply.rs
// Expected error: E0271 -- ReadOnly does not satisfy ReadWrite bound
use mast_manager::{Repository, ReadOnly, apply};

fn main() {
    let repo: Repository<ReadOnly> = todo!();
    let mutation = todo!();
    let manager = todo!();
    apply(&repo, mutation, &manager);
}
```

```rust
// tests/compile_fail.rs
#[test]
fn compile_fail_tests() {
    let t = trybuild::TestCases::new();
    t.compile_fail("tests/compile_fail/*.rs");
}
```

**Example (exhaustive match):**

```rust
// tests/compile_fail/missing_kind_arm.rs
// Expected error: E0004 -- non-exhaustive patterns
use mast_lang_ast::SpecKind;

fn dispatch(kind: SpecKind) -> &'static str {
    match kind {
        SpecKind::Feature => "feature",
        // Missing: Constitution, Workflow, Component, Unset, Unknown
    }
}

fn main() {}
```

**Review mode integration:** When auditing compile-time enforcement (Step 4), check for compile-fail tests. Active rules describing compile-time invariants without compile-fail tests get a PARTIAL coverage verdict.

### T5: Contract-first testing

**Detection:** Spec rules have `success.<name>` constraints describing observable behavior, AND the implementation target can be stubbed (T1 conditions met).

**Action:** Write integration tests against the stubbed interface BEFORE implementing the body. The tests define the expected behavior; the implementation makes them pass.

Process:
1. Read the `success.<name>` and MUST constraints from the spec rule
2. For each, write a test that constructs the inputs described in the Given clause and asserts the outcome described in the Then clause
3. Run the tests -- they fail (because `todo!()` panics)
4. Implement the body until the tests pass

**Example:**

```rust
// From gov-linker-verify R6 success.roots_overlap_detected:
#[test]
fn roots_overlap_emits_warning() {
    let corpus = TempProject::new()
        .with_march("domain-a", "roots: src/\n")
        .with_march("domain-b", "roots: src/lib/\n")
        .build_corpus();

    let findings = verify_governance(&corpus);

    assert!(findings.iter().any(|f|
        f.code == "roots/overlap"
        && f.severity == Severity::Warning
    ));
}
```

### T6: Pure-function extraction

**Detection:** Spec rules where the Then clause depends on 2+ independent Given/When conditions, or where MUST constraints enumerate cases across a matrix of inputs.

**Action:** Extract a standalone pure function. Write an exhaustive table-driven test covering every combination of inputs. Then fill in the function body.

Process:
1. Identify the input dimensions from the spec rule
2. Enumerate the domain of each dimension
3. Compute the Cartesian product -- this is the test table
4. For each cell, determine the expected output from the spec's MUST constraints
5. Write the test table first
6. Write the function signature (inputs to output, no side effects)
7. Fill in the body until all cells pass

**Example:**

```rust
fn modulate_severity(
    constitution_status: Lifecycle,
    rule_chip: Lifecycle,
    compliance_state: ComplianceState,
) -> Severity {
    todo!()
}

#[test]
fn severity_modulation_matrix() {
    use Lifecycle::*;
    use ComplianceState::*;
    use Severity::*;

    let cases = [
        (Draft, New, Pending,   Info),
        (Draft, New, Certified, Info),
        (Draft, Active, Pending, Info),
        (Draft, Active, Certified, Info),
        (New, New, Pending,     Warning),
        (New, New, Certified,   Warning),
        (New, Active, Pending,  Warning),
        (New, Active, Certified, Error),
        (Active, New, Pending,  Warning),
        (Active, New, Certified, Warning),
        (Active, Active, Pending, Warning),
        (Active, Active, Certified, Error),
    ];

    for (status, chip, state, expected) in cases {
        assert_eq!(
            modulate_severity(status, chip, state),
            expected,
            "({status:?}, {chip:?}, {state:?})"
        );
    }
}
```

---

## Implementation tempo

Three stages. The stage determines what feedback is available and what decisions are well-founded. Design rigor is constant; what changes is the nature of the information.

The tradeoff across stages: **degrees of freedom** vs. **information quality**. Early, you have maximum freedom to choose structures but the weakest signal on whether they hold. Late, freedom is gone (everything is load-bearing) but you know exactly what works. Good engineering spends freedom when you have it (opening) and spends information when you have it (endgame). The midgame is the inflection — enough information has arrived to evaluate opening decisions, while enough freedom remains to correct them cheaply.

```
                         ┌─────────────────────────────────────────┐
  Degrees of freedom     │ ████████████████░░░░░░░░░░░░░           │ high → low
  Information quality    │ ░░░░░░░░░░░░░░░████████████████████████ │ low → high
  Cost of change         │ ░░░░░░░░░░░░░████████████████████████── │ low → high
                         └─────────────────────────────────────────┘
                           OPENING         MIDGAME        ENDGAME
                          (0-30%)         (30-70%)        (70-100%)
```

### Opening -- structural decisions under bounded visibility

**When:** The first ~30% of rules are being implemented. Foundation phases. Skeleton crates, stubbed interfaces, and tracer bullets are active.

**What you are learning:** Whether the spec's structural assumptions hold in code. Do the crate boundaries make sense? Do the type signatures compose? Does the dependency graph compile?

**Posture:** Maximum freedom, minimum information. This is when established patterns earn their keep — they are standardized solutions with known tradeoffs, letting you spend degrees of freedom on choices that have been vetted by the industry rather than inventing bespoke structures under uncertainty. When a spec describes a shape that matches a pattern, use it. When it does not match, do not force one. The spec is the authority on shape; patterns are the toolkit:
- "sealed access control with compile-time enforcement" --> typestate pattern
- "multi-dimensional severity decision" --> pure function with lookup table
- "cross-crate behavior without import" --> callback indirection

**Plan mode:** Annotate opening-stage phases with the structural questions they will answer:

```
Phase 1 [opening]
  Structural questions:
  - Does the Tiers block parser compose with the existing block-phase map?
  - Does SpecKind::Constitution require a new validator slice shape?
```

**Phase mode:** After completing an opening-stage phase, run a brief structural check:
1. Do the types you introduced compose with the types from earlier phases?
2. Did any spec assumption turn out to be wrong?
3. If so, is the correction local or structural (spec needs amending)?

Report structural findings to the user. If a spec assumption was wrong, hand off to `/mast:spec` for amendment before building on top of it.

### Midgame -- informed refinement

**When:** ~30-70% of rules are graduated. Both sides of every seam are visible. Stubs replaced with real implementations.

**What you are learning:** Whether the interfaces serve what you have built. The interface signatures were hypotheses; implementation has confirmed or challenged them.

**Posture:** Degrees of freedom have narrowed (real consumers depend on your interfaces) but information quality has risen sharply. A refactor here is not premature — it is a high-confidence correction grounded in evidence that did not exist during the opening. The cost of change is moderate (some consumers exist but not all). If the ROI is clear, take the refactor before the endgame locks it in.

**Midgame review checkpoint:** When approximately 50% of target rules are graduated (or when the first join point is reached -- whichever comes first), pause and run this review:

```
Midgame review:

1. Seam audit: for each seam identified in the plan, compare the
   stubbed interface (T1) with the actual implementation.
   - Signature match? (parameters, return types, error types)
   - If not, what changed and why?
   - Do consumers need updating?

2. Technique assessment: which opening-stage techniques paid off?
   - T3 tracer bullet: did the vertical slice reveal anything?
   - T1 stubs: how many survived unchanged vs. needed correction?
   - T5 contract-first tests: are they passing against real impls?

3. Refactor candidates: identify at most 3 refactoring opportunities
   where the implementation revealed a better structure. For each:
   - What is the current shape?
   - What would the better shape be?
   - What is the blast radius (which crates, which rules)?
   - Is it worth doing now or is the current shape adequate?

4. Spec amendments: are any spec rules wrong? List for `/mast:spec`.
```

Present the midgame review to the user. Refactoring is a decision, not an automatic action. The user decides. Then proceed.

### Endgame -- hardening with evidence

**When:** >70% of rules are graduated. Remaining work is wiring and graduation.

**Posture:** Information quality at its peak — you know exactly how everything fits. But degrees of freedom at their lowest — the structure is load-bearing. Refactor only when you have a concrete finding (wrong red-team result, compliance gap, performance cliff) AND the ROI clearly justifies the blast radius. The high information quality means you can evaluate that ROI with confidence.

**Phase mode:** In endgame phases:

1. **Run every red-team scenario** from the plan. Build the attack fixture, confirm the expected finding is emitted. If not, fix the implementation.

2. **Close open markers.** Search for `open:` in target specs:
   ```bash
   mast list rules | grep -i "open"
   ```
   Resolve each open marker or flag as deliberately deferred.

3. **Run Review mode** (full compliance audit) before the final graduation batch.

4. **Refactor only on evidence.** Evaluate ROI: concrete benefit vs. blast radius. If marginal, record as follow-up.

---

## Version control

### Commit granularity

Commit after each passing checkpoint (Phase Step 3e). Each commit contains:
- The test(s) for the rule's MUST constraints
- The implementation code
- Any lint fixes triggered by the change

Use conventional commit subjects referencing the spec and rule:

```
feat(<spec-id>): implement R<n> -- <one-line constraint summary>
feat(<spec-id>): implement R<a>,R<b> -- <summary>   # multi-rule atomic commits
```

Verification-only items (no file changes) produce no commit -- note them in the carry-forward summary instead.

### Branch strategy

One feature branch per implementation plan. If the plan has parallel lanes, each lane may use its own branch and merge at the join point. Seam interfaces (T1 stubs) should be merged to the shared base before parallel work begins.

### Phase completion commits

After Phase Step 4, commit the carry-forward summary or a clean "phase complete" commit:

```
feat(<spec-id>): complete phase N -- R1-R5 ready for graduation
```

### Do not commit graduation patches

Graduation (`mast spec patch ... rule set-status`) modifies `.mspec` files. Commit separately after the user approves the graduation list.

---

## Execution checklist

Critical behavioral constraints. This is the recency-zone summary of what matters most during execution.

1. **Specs are the source of truth.** Every implementation decision traces back to a rule and constraint. When in doubt, re-read the spec.
2. **Tests before code.** Write the failing test first. If you cannot write a test for a MUST constraint, flag it as under-specified.
3. **Checkpoints are non-negotiable.** Run the full check suite after every meaningful change. Do not batch-skip checkpoints.
4. **3 attempts max per rule.** After 3 TDD cycle failures, invoke the failure protocol. Do not loop indefinitely.
5. **Re-read specs before graduation.** Rule IDs may have changed if the spec was amended mid-phase.
6. **Graduation is the deliverable.** The skill succeeds when rules graduate from `[pending]` to `[active]` with code anchors.
7. **Propose, do not auto-execute.** Present the plan or graduation commands and wait for approval.
8. **Bare numeric rule IDs everywhere.** R3 in the spec maps to `3` in the CLI and in plan output.
9. **Persist state.** Write carry-forward summaries to `.mast/dag-plan-state.md` at every phase transition.
10. **Cite evidence.** Every compliance verdict includes a file path or command. Verdicts without evidence are "inconclusive."
11. **Hand off cleanly.** Graduation patches go through `/mast:spec`. Build verification goes through `/mast:check`. Spec authoring goes through `/mast:spec`.
12. **Filter targets.** Only include pending/active specs in the target set. Warn on draft/retired.
13. **lint check validates spec-to-spec, not spec-to-code.** The TDD tests are the spec-to-code validation.
14. **Corpus-drift check on every phase start.** Re-query deps and rules; if the graph changed structurally, invalidate the plan.
15. **Diamond deps get pre-phase stubs.** If two parallel specs share a transitive dependency, stub that dependency's interface before parallel work begins.
16. **Plan invalidation is a state.** If a phase failure or midgame review reveals structural amendments, write PLAN_INVALIDATED and re-plan before continuing.
17. **Collapse trivial phases.** Consecutive single-spec phases targeting the same crate should be merged.
18. **mast-loop graduation follows loop protocol.** Check for `<ralph-context>` block; if present, follow the user's loop graduation protocol instead of waiting for human approval (there is no `mast loop` CLI command; mast-loop is retired -- this applies only if a user wires their own loop).

## Style rules

The no-emoji rule is a project convention -- see **REF-CONVENTIONS**. The rest are dag-plan-specific:

- **Bare numeric rule IDs everywhere.** R3 in the spec is `3` in the CLI and in every plan, graduation command, and report.
- **Propose, do not auto-execute.** Plans and graduation commands are presented for approval, not run; the only exception is a user-wired loop (the deprecated mast-loop path).
- **Cite evidence or say "inconclusive."** Every compliance verdict carries a file path or command; a verdict you cannot back with evidence is not a pass.
- **Pasted output, never self-assessment.** Checkpoints and validation rows are the command's actual output, not a judgment that it "works."
- **Never weaken a failing test** to make it pass. A failing test is a finding (spec wrong, impl stuck, or pre-existing breakage), classified by the failure protocol.

## Worked example

[`examples/ledger/`](../../../../examples/ledger) has a concrete planning target: `read-journal` is a `[pending]` feature that `extends transfer-funds`, anchored only to Design/Plan docs (`mast spec read read-journal --with-blocked-by --root examples/ledger`). It is exactly the shape this skill decomposes — a not-yet-built spec whose parent is active, with `EntryStore.forTransfer` already implemented (the seam) and only the HTTP route and ordering/pagination decisions (its `open:` markers) left to phase. The four active features (`open-account`, `get-balance`, `transfer-funds`, `idempotent-transfer`) plus their two `.march` domains form a small dependency graph (`idempotent-transfer` `Depends on` `transfer-funds`) to practise lane assignment, seams, and join points on.
