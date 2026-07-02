---
name: check
description: Unified verification across four modes. Pre-push (default) runs local CI checks. CI-fix diagnoses GitHub Actions failures and fixes in one commit. Audit scores architecture, spec corpus, and code alignment. Pre-flight verifies referenced files exist before implementation. Use when asked to "check", "am I ready to push", "pre-push", "CI failed", "fix CI", "why is CI red", "audit", "health check", "what's stale", "what needs attention", "check layer separation", "grade this repo", "pre-flight", or "verify files exist".
---

# check

This is the verification skill: one entry point, four modes. Pre-push runs the same gates CI runs, locally, before you push. CI-fix diagnoses a red build and greens it in a single commit. Audit produces a scored health report over the architecture, the spec corpus, and the code no spec governs. Pre-flight fails fast on missing inputs before an implementation loop starts. It routes internally to one of the four from the user's intent.

Reference: REF-BINARY, REF-FILEKINDS, REF-LIFECYCLE, REF-GOVERNANCE, REF-DEPENDENCIES, REF-CONVENTIONS
*(Reference sections live in `plugins/mast/skill-reference/` — e.g. `REF-FILEKINDS` resolves to `plugins/mast/skill-reference/REF-FILEKINDS.md`.)*

## Prerequisites

Which binary to invoke is shared doctrine — see **REF-BINARY**: call `mast` directly (the plugin puts it on Claude Code's PATH), or `./bin/mast` in a repo that vendors the shim. If `mast` cannot be provisioned, stop and tell the user to install it before proceeding.

`check`-specific fail-mode (cited to **REF-BINARY**'s `./bin/mast` SHA-256 callout): the shim verifies the SHA-256 of the release binary it fetches and hard-fails on any fetch or verification error — it never falls back to executing an unverified or stale cached binary. A failing `./bin/mast` therefore means install or network trouble (fix the fetch, or set `MAST_OFFLINE=1` with a warm cache), never a lint finding. Do not report a failing shim as a corpus problem.

## Intent routing

Map the user's request to one of four modes:

| User says | Mode |
|-----------|------|
| "check", "check my work", "am I ready to push", "pre-push", "run checks", "verify before push", "local CI" | **Pre-push** (default) |
| "CI failed", "fix CI", "why is CI red", "CI is broken", "green the build" | **CI-fix** |
| "audit", "health check", "is this codebase healthy", "what's stale", "what needs attention", "where should I focus", "check spec health", "audit the architecture", "grade this repo", "check layer separation" | **Audit** |
| "pre-flight", "verify files exist", "check references", "do the files exist" | **Pre-flight** |

When the user says just "check" with no qualifier, use **Pre-push** mode.

## When NOT to use

- **Reading or editing specs.** Use `/mast:spec`.
- **Orientation or walkthrough.** Use `/mast:orient`.
- **Mining a corpus from code.** Use `/mast:mine`.
- **Conceptual questions about the model.** Use `/mast:orient`.

---

## Modes / playbooks

### Mode: Pre-push (default)

**Goal:** Run the same checks CI will run, locally, before pushing. Report pass/fail per check with a clear overall verdict.

**Gather.** Establish corpus state first: `mast doctor` is daemon-free, always exits 0 on a successful diagnosis, and names the onboarding phase. `P0 (Bare)` means there are no mast gates to run — say so instead of inventing them; any `error`-severity finding doctor lists is itself a pre-push blocker to surface. Then detect the build system, run its check sequence, then run mast's own checks if a corpus exists.

#### Build-system detection

Run these probes in order, stopping at the first hit:

```bash
# Cargo workspace (Rust)
test -f Cargo.toml && cargo metadata --no-deps --format-version 1 2>/dev/null

# Go modules
test -f go.mod

# Node.js / pnpm workspace
test -f pnpm-workspace.yaml

# Node.js / npm workspace
test -f package.json && node -e "const p=require('./package.json'); if(p.workspaces) console.log(JSON.stringify(p.workspaces))" 2>/dev/null

# Python (pyproject with deps)
test -f pyproject.toml

# Gradle
test -f settings.gradle -o -f settings.gradle.kts

# Maven
test -f pom.xml
```

#### Per-project check sequences

Run the checks for the detected build system. Run each check independently so a failure in one does not skip the rest.

**Rust (Cargo workspace):**

```bash
cargo build --workspace
cargo test --workspace
cargo clippy --workspace --all-targets -- -D warnings
cargo fmt --check
cargo machete --skip-target-dir
```

**Go:**

```bash
go build ./...
go test ./...
go vet ./...
gofmt -l . | head -20
```

**Node.js (pnpm/npm):**

```bash
pnpm install --frozen-lockfile   # or: npm ci
pnpm run typecheck               # if script exists (or: npm run typecheck)
pnpm run lint                    # if script exists
pnpm run build
pnpm test
```

**Python:** `python -m pytest` + `mypy .` (if installed) + `ruff check .` (if installed).

**Gradle:** `./gradlew check`. **Maven:** `mvn verify -q`.

#### Mast-specific checks

After the build-system checks, always run mast checks if the corpus exists:

```bash
# Check if mast corpus exists
mast list specs --count 2>/dev/null
```

If the corpus exists (command succeeds with count > 0):

```bash
mast lint fmt --check .
mast lint ci .
```

Some hosts unify their gates through a top-level `mast ci` command -- probe with `mast ci --help` first; whatever gate list that help enumerates for this repo is authoritative. When the command exists, prefer running `mast ci` as the single source of truth instead of reproducing the per-tool sequence above; it is what CI itself runs.

If the project keeps architecture-enforcement tests inside its normal test suite (e.g. a Rust workspace with an `internal/archtest` crate), those run as part of the workspace test command and do not need a separate invocation.

**Design-anchor info on `[pending]` specs.** Design anchors (`*-design.md`) and plan anchors (`*-plan.md`) are the expected target shape for `[pending]` specs describing not-yet-built code, so they are NOT lint errors there (the AnchorKind taxonomy and the design-anchor lifecycle are shared doctrine — see **REF-LIFECYCLE**). Surface them as an info line, not a failure:

```bash
mast list targets 2>/dev/null
```

For any `[pending]` spec whose Targets resolve to a `*-design.md` / `*-plan.md` path, report `[INFO]` ("spec <id> uses a design anchor -- expected while not yet implemented"). These anchors only become errors once the rule is `[active]`: `mast lint check .` emits `design-anchor-on-active-rule` (Error) on an active rule still pointing at `*-design.md` / `*-plan.md`, and `stale-design-header` (Warning) on an active spec still carrying a `design:` / `plan:` header. `mast lint ci .` already covers both; the info line is just so the user is not surprised by design anchors on their `[pending]` work.

**Render.** Present results as a checklist with pass/fail per item:

```
Pre-push check: <repo-name>

  [PASS] cargo build --workspace
  [PASS] cargo test --workspace
  [FAIL] cargo clippy --workspace --all-targets -- -D warnings
         src/foo.rs:42:5: unused variable `x`
  [PASS] cargo fmt --check
  [PASS] cargo machete --skip-target-dir
  [PASS] mast lint fmt --check .
  [PASS] mast lint ci .

Result: FAIL (1 of 7 checks failed)
```

If all checks pass:

```
Result: PASS (7 of 7 checks passed) -- ready to push
```

When checks fail, show the first 20 lines of each failure's stderr/stdout. Do not attempt to fix automatically -- that is what CI-fix mode is for. The user asked "am I ready?" not "fix it for me."

**Budget.** Run each gate once; one checklist line per gate; the first 20 lines of stderr/stdout per failure. No automatic fixes in this mode.

### Mode: CI-fix

**Goal:** Fix a failing CI workflow in a single push cycle. Read ALL failures before fixing ANY. Do not push partial fixes.

**Gather.** Read the failure logs, categorize every failure, verify the CI-specific concerns, and reproduce locally.

#### Steps

1. **Read the failure.** Use `gh run list --limit 1 --json status,conclusion,url` to find the latest run, then `gh run view <id> --log-failed` to get failure logs. Read ALL failures, not just the first one.

2. **Categorize each failure:**
   - Clippy violation (`cargo clippy -- -D warnings`)
   - Format violation (`cargo fmt --check`)
   - Test failure (`cargo test`)
   - Build failure (`cargo build` or `cargo check`)
   - Unused dependency (`cargo machete`)
   - Spec lint failure (`mast lint fmt` or `mast lint ci`)
   - Per-file spec warning (`conditional-given-suggest-when`, `success-criterion-not-falsifiable`, `must-with-style-language`, `rationale-keys`) -- these are warnings, not errors, so they do not gate `mast lint ci`; surface them but do not block the green on them unless the repo's CI is configured to deny warnings. The trigger words that fire each (machine-coupled; `preserve-verbatim` -- the validators match these exact strings):
     - `must-with-style-language` (validator `normative-style-mismatch`) fires when a `MUST`-prefixed constraint contains: `prefer`, `preferable`, `preferably`, `ideally`, `favor`, `encourage`, `recommend`, `where possible`, `where feasible`, `where appropriate`.
     - `conditional-given-suggest-when` (validator `when-suggestion`) fires when a rule's `Given` contains: `if`, `once`, `unless`, `when`, `whenever`, `while`, and the rule has no `When` clause.
     - `rationale-keys` fires on a constraint key of `rationale:` or `reason:`.
   - Governance violation (`roots/overlap`, `roots/trailing-slash`, `enforces/target-valid`, `enforces/compliance-valid`, `enforces/compliance-severity`, `enforces/unknown-constitution`, `enforces/coverage-gap`, `enforces/waive-reason-required`, `compliance/constitution-missing`, `compliance/tier-missing`, `constitution/tiers-required`, `constitution/tiers-monotonic`, `constitution/tier-syntax-invalid`)
   - Legacy mast/2 syntax (`imports/attached-to-deprecated`) -- a spec still carries a retired `attached_to:` header; replace it with a `uses { component: ... } from <id>` import or a rule chip component ref
   - Broken code anchor (`file-ref-path-missing`) -- a Targets `@file=` path does not exist on disk. If the file is genuinely not built yet, this is the design-anchor signal: redirect the target to a `*-design.md` / `*-plan.md` doc under `docs_dir` (default `docs/`) rather than inventing a fake source path. If the file was moved/renamed, fix the path to the real location. Code anchors no longer get a `[pending]`-status skip in mast/3 -- a missing code path is an error even on a `[pending]` spec, which is exactly what forces the design-anchor switch.
   - Permission issue (`GITHUB_TOKEN` missing write access)
   - Detached HEAD (`git` operations that assume a branch)
   - Workflow logic (`if` conditions, missing steps, wrong triggers)

3. **Verify CI-specific concerns:**
   - Does `GITHUB_TOKEN` have all required permissions for the failing workflow?
   - Do git operations work in CI's detached HEAD state?
   - Are `if`-condition expressions correct? (Watch for `github.event_name` typos, missing `||` branches)
   - Are all generated files committed?

4. **Fix locally first.** Run the same check sequence as Pre-push mode (build, test, clippy/lint, fmt, machete, mast lint). Adapt to the project's build system.

5. **Commit all fixes in a single commit** with message `fix(ci): <description of all fixes>`.

6. **Push once.** Do not push until all local checks pass.

**Render.** A single commit `fix(ci): <description of all fixes>` covering every failure read in step 1, pushed once. Report which categories were hit and how each was resolved; never push a partial fix.

**Budget.** One read pass over ALL failures before any edit; one commit; one push. No push until every local check passes.

### Mode: Audit

**Goal:** Produce a scored health report with specific findings. Every finding cites a file path, command output, or line number. `/mast:orient` tells you *what a corpus is*. Audit mode tells you *how healthy it is*.

**Gather.** Run Phase 0 intake (cannot be skipped), map the answers to phases via the routing table, then collect each selected phase's data with the exact commands in its phase description below. For full repo audits, fan the phases out across the two subagent groups, then vet every cited finding in the main thread before scoring.

#### Phase 0 -- Intake (always do this; cannot be skipped)

Before asking anything, run `mast doctor --format json` as the intake's first datum: the reported phase names which surfaces exist to audit at all (a corpus below the architecture phase has no L6 topology to conform; a bare repo has nothing to audit but the onboarding gap itself), its findings seed the finding inventory, and its `nextCommand` is the fallback recommendation when an audit surface turns out to be empty.

Then route the audit with a two-question intake. Ask both questions in a single exchange. The goal is to reach a concrete audit plan in at most two exchanges with the user -- never three.

##### Question 1 -- Surface

Ask the user:

> **What do you want to audit?**
>
> 1. **Full repo health check** -- architecture, spec corpus, code alignment, and velocity signals. Takes 2-3 minutes.
> 2. **Architecture conformance** -- L6 topology, layer separation, drift between declared and actual dependencies.
> 3. **Spec corpus health** -- staleness, graduation readiness, orphan detection, dependency density.
> 4. **A specific domain or spec** -- focused audit of one area.
> 5. **Staleness scan** -- which specs have drifted from the code they govern?
> 6. **Governance posture** -- constitution coverage, certification progress, compliance gaps across domains.

If the user's original message already implies one of these (e.g. "is the architecture clean?" maps to option 2, "what's stale?" maps to option 5), skip Question 1 and infer the surface. State the inference in one sentence ("I'm reading this as an architecture conformance audit -- correct me if not") and proceed to Question 2.

##### Question 2 -- Depth (conditional)

This question varies by surface:

**For "Full repo health check" (option 1):**

> **How deep?**
>
> a. **Quick** -- no subagents; hotspot phases only (Staleness + Alignment + Velocity), run in the main thread.
> b. **Standard** (default) -- both subagent groups, every phase except Code.
> c. **Deep** -- both subagent groups plus the Code phase on the unspecced surface.

If the user already typed "quick" or "deep" anywhere in the request, skip the question and use that depth.

**Branch-scoped audits.** When the user asks to audit only the current branch's changes, the scope is files changed since the merge-base with the default branch plus their direct importers. Tag every finding `introduced` (by this branch) or `pre-existing` (in touched files) -- don't blame the branch for legacy debt, but do surface what it builds on. Resolve the default branch via `git remote show origin | sed -n '/HEAD branch/s/.*: //p'` when `origin/HEAD` is unset; fall back to `main`.

**For "Architecture conformance" (option 2):**

> **What's your concern?**
>
> a. **Layer violations** -- are components importing things they shouldn't?
> b. **Drift from code** -- does the `.march` topology match the actual dependency graph?
> c. **Completeness** -- are architectural constraints enforced at compile time, or just documented?
> d. **All of the above** -- full architecture audit.

**For "Spec corpus health" (option 3):**

> **What's your concern?**
>
> a. **Staleness** -- which specs have drifted from the code they govern?
> b. **Graduation blockers** -- which specs are blocked from advancing, and by what?
> c. **Orphan specs** -- which specs are disconnected from the dependency graph?
> d. **All of the above** -- full corpus audit.

**For "A specific domain or spec" (option 4):**

> **Which domain or spec?**

Run `mast list domains` and `mast list specs` to populate the question with the actual corpus contents. Present both lists and let the user pick.

**For "Staleness scan" (option 5):** Skip Question 2 -- proceed directly to the staleness algorithm.

#### Routing table

After intake, map answers to phases:

| Surface + Concern | Phases to run |
|-------------------|---------------|
| Full repo (1), quick | Staleness + Alignment + Velocity (main thread, no subagents) |
| Full repo (1), standard | Topology + Drift + Archtest + Patterns + Graph + Alignment + Governance + Velocity + Staleness |
| Full repo (1), deep | The standard set + Code |
| Arch + layer violations (2a) | Topology + Archtest + Patterns (anti-patterns only) |
| Arch + drift from code (2b) | Topology + Drift |
| Arch + completeness (2c) | Archtest |
| Arch + all (2d) | Topology + Drift + Archtest + Patterns |
| Specs + staleness (3a) | Staleness |
| Specs + graduation (3b) | Graph (graduation focus) |
| Specs + orphans (3c) | Graph (orphan focus) |
| Specs + all (3d) | Graph + Patterns + Staleness + Alignment |
| Specific domain (4 + domain) | Domain-focused: Topology (filtered) + Drift (filtered) + Patterns (filtered to domain participants) + attached specs |
| Specific spec (4 + spec) | Spec-focused: Staleness (single) + blocked-by + inbound + Patterns (filtered to spec participants) |
| Staleness scan (5) | Staleness |
| Governance posture (6) | Governance |

**Render.** The selected phases run, each producing a GREEN/YELLOW/RED/NOT COMPUTABLE score and findings; the main thread assembles the scorecard, the findings, and the top-3 actions per the Audit output format at the end of this mode. The full phase catalog with its data-collection commands and rubric thresholds follows.

#### Phase: Topology -- L6 shape analysis

**Goal:** Map the architecture layer and measure its shape.

**Commands:**

```bash
mast list domains
mast list components
mast list connections
mast list edge-types
```

**Compute and report:**

1. **Domain count, component count, edge count.** State the numbers.
2. **Edge-type distribution.** Count edges per type. Flag if the `default-edge-type` (the generic fallback used by empty `-[]->` brackets) exceeds 10% of total edges -- that signals under-classified wiring. Use the actual names from `mast list edge-types` rather than assuming a casing -- the `.mtypes` author chooses them.
3. **Orphan components.** Components with zero inbound and zero outbound edges. These are either leaf utilities (fine) or dead declarations (not fine). Classify each before scoring -- dead means no corresponding crate/directory exists on disk; leaf utility means the code exists but nothing wires to it. Only dead declarations count toward the rubric; leaf utilities are listed but not scored.
4. **Hub components.** Components with inbound + outbound edge count > 2x the domain average. These are coupling hotspots. List the top 3.

**Scoring:**
- GREEN: <10% default-edge-type, no orphans, no hubs >3x average
- YELLOW: 10-25% default-edge-type, or <=2 orphans, or 1 hub >3x average
- RED: >25% default-edge-type, or >2 orphans, or >1 hub >3x average

Skip this phase if the corpus has no `.march` files.

**Domain-filtered variant (for option 4):** When auditing a single domain, filter all outputs to that domain. Report the same metrics scoped to that domain only.

#### Phase: Drift -- declared vs actual dependency detection

**Goal:** Verify that the architecture model matches the actual dependency graph.

This phase adapts to the project's build system (use the detection probes from the Pre-push section).

##### Process

1. Extract workspace-internal dependency edges from the build manifest (Cargo: `cargo metadata --no-deps --format-version 1`; Go: `go mod graph`; Node: `pnpm list --recursive --depth 0 --json` or `package.json` workspaces).
2. Parse `mast list connections` for edges that imply code-level dependency (typically an `Imports`-style edge-type, or any edge-type whose `transport:` is `in-process`).
3. For each `.march` domain that maps to a build unit (by naming convention, `Targets` block, or directory co-location), compare:
   - **Missing in .march:** build-system edge exists but no corresponding edge in the .march file.
   - **Missing in build:** `.march` declares an edge but no build-system dependency exists.
4. Report each drift finding with the specific module/crate/package names and `.march` file path.

If the two edge sets share no key -- e.g. every `.march` edge is an intra-domain component edge while every build-system edge is inter-crate -- report Drift as NOT COMPUTABLE rather than scoring it. Compare only at matching granularity.

**Scoring:**
- GREEN: 0 drift findings
- YELLOW: 1-3 drift findings
- RED: >3 drift findings

Skip this phase if no build system is detected or no `.march` files exist.

#### Phase: Archtest -- compile-time constraint coverage

**Goal:** Determine which architectural constraints are enforced at compile time vs merely documented.

This phase is conditional on the project having architecture-enforcement tests. Detect them:

- **Rust:** `find . -path '*/archtest*' -name '*.rs' -not -path '*/target/*'`
- **Java/Kotlin:** grep for `ArchUnit` / `ArchRuleDefinition` in `.java`/`.kt` files
- **TS/JS:** `.dependency-cruiser*` or `eslint-plugin-import` config
- **Go:** `find . -name '*.go' -path '*/arch*' -not -path '*/vendor/*'`
- **Bazel:** `grep -c package_group BUILD.bazel` plus `visibility =` in per-crate BUILD files -- visibility package_groups fail forbidden dep edges at analysis time and count as enforcement

##### Process (when architecture tests exist)

1. Count architecture assertions/rules in the test files found.
2. Cross-reference against the `.march` connection list. For each declared edge, check if a corresponding architecture test assertion exists.
3. Report:
   - **Enforced edges:** count and percentage of total `.march` edges
   - **Unenforced edges:** specific `.march` edges with no test coverage
   - **Extra assertions:** test constraints that go beyond what `.march` declares (defense in depth -- fine)

**Scoring:**
- GREEN: >80% of `.march` edges have test coverage
- YELLOW: 50-80% coverage
- RED: <50% coverage

If the enforcement operates at a different granularity than the `.march` edges (e.g. crate-level Bazel visibility vs intra-domain component edges), report coverage as NOT COMPUTABLE and state the enforcement that does exist -- a granularity mismatch is not absent enforcement.

Skip this phase if no architecture test infrastructure exists. Note in the report: "No architecture test framework detected -- `.march` constraints are documentation-only."

#### Phase: Graph -- spec dependency graph health

**Goal:** Assess the spec dependency graph for density, bottlenecks, and graduation readiness. (The three dependency kinds this phase traverses — `Depends on`, `extends`, `Cites` — are shared doctrine, see **REF-DEPENDENCIES**.)

**Commands:**

```bash
mast list specs
mast list deps
mast list extends
mast list pending
```

**Compute and report:**

1. **Status distribution.** Count specs by lifecycle status (active, pending, draft, retired). Report the ratio of active to total.
2. **Dependency density.** Total dep edges / total specs. Context: <2 is sparse, 2-5 is moderate, >5 is dense. Dense is not bad -- it means specs are well-connected -- but it increases coordination cost.
3. **Most-depended-on specs (fan-in top 5).** These are load-bearing: a breaking change cascades widest. List with dep count.
4. **Highest-fanout specs (top 5).** These are hardest to graduate because their entire transitive dep closure must be satisfied. List with dep count.
5. **Extends chains.** Report any chain longer than 2 (A extends B extends C). Long chains increase fragility.
6. **Orphan specs.** Specs with zero inbound deps and zero outbound deps. These are either foundational (fine) or disconnected (not fine).
7. **Design lifecycle status.** Report the corpus-wide anchor migration picture. From `mast list targets`, count Design/Plan anchors (`*-design.md` / `*-plan.md` paths, the `blocks_graduation()` kinds) vs Code anchors, and report the ratio. Count specs carrying a `design:` or `plan:` header via `mast spec read <id> | grep -cE '^(design|plan):'` -- no list command surfaces headers, so limit the per-spec reads to pending/draft specs (where the headers live) to bound the cost. Then split by spec status: design/plan anchors and headers on `[pending]`/draft specs are healthy (work in flight); the same on `[active]` specs is stale and should have been replaced with `Code` / `Context` / `Skill` / `Doc` anchors before graduation. Report the count of active specs still on a Design/Plan anchor or header -- these are the `design-anchor-on-active-rule` (Error) and `stale-design-header` (Warning) findings `mast lint check .` surfaces.

##### Graduation focus (for option 3b)

When the intake routed here for graduation blockers, expand this section:

For each "pending" or "draft" status spec, run:

```bash
mast spec read <id> --with-blocked-by
```

Report specs that are blocked by other non-active specs (transitive blockers). Identify the critical path: which specs, if graduated first, would unblock the most others. Present as a ranked list:

```
Graduation critical path:
  1. <spec-id> -- graduating this unblocks N other specs: <list>
  2. <spec-id> -- graduating this unblocks N other specs: <list>
  ...
```

##### Orphan focus (for option 3c)

When the intake routed here for orphan detection, expand:

For each orphan spec (zero inbound + zero outbound deps), report:
- Whether it has any `Targets` references (anchored to code = likely foundational, not orphaned)
- Whether `mast describe attached <id>` returns a non-empty set (anchored to architecture = likely foundational)
- Last git-modified date (stale orphan = candidate for retirement)

**Scoring:**
- GREEN: >60% active, no circular deps, all extends chains <=2
- YELLOW: 40-60% active, or any extends chain >2, or >5 orphan specs
- RED: <40% active, or circular deps detected

Cycle detection: none of this phase's four commands detects cycles -- run `mast list patterns --kind circular-dependency` here even when the Patterns phase is not selected by the routing.

#### Phase: Patterns -- structural motif detection

**Goal:** Surface recurring structural motifs (both healthy patterns and anti-patterns) in the corpus using the pattern analytics engine.

**Commands:**

```bash
mast list patterns                          # all detected patterns
mast list patterns --format json            # structured output for programmatic analysis
mast list patterns --kind <slug>            # filter by specific pattern kind
```

The engine detects 17 pattern kinds. The `--format json` output is a flat array of records, each `{kind, participants, summary, confidence}`: `kind` is the kebab-case pattern slug, `participants` is a flat list of the spec/component IDs involved, `summary` is a human-readable description, and `confidence` is a score (0.0--1.0). Severity classification comes from the two tables below, keyed on `kind` -- derive each pattern's anti-pattern status from the tables, not from the JSON (the flat shape does not carry an `is_anti_pattern` flag; the tables are authoritative).

**Healthy patterns (report as strengths when found):**

| Pattern kind | What it reveals |
|---|---|
| `three-phase-pipeline` | A spec chain with clear intake/process/output phases -- well-factored |
| `parent-catalog` | A parent spec with multiple children via `extends` -- good reuse |
| `extension-chain` | Ordered spec inheritance -- clean layering |
| `spec-trio` | A domain covered by all three file kinds (.mspec + .march + .mtypes) -- full-stack specification |
| `co-citation-cluster` | Multiple specs citing the same upstream rules -- shared contract |
| `l6-reciprocal-pair` | Two components with bidirectional edges -- intentional coupling |
| `skill-and-hook-footprint` | Plugin/skill coverage of the corpus -- tooling integration |

**Anti-patterns (report as findings when found):**

| Pattern kind | What it reveals | Severity |
|---|---|---|
| `circular-dependency` | Dependency cycle in the spec graph | RED |
| `boundary-breach` | A spec's rules reference components outside its declared boundary | RED |
| `articulation-point` | Removing one spec disconnects the graph -- single point of failure | YELLOW |
| `shared-target-conflict` | Multiple specs claim the same Targets file with conflicting rules | YELLOW |
| `target-coverage-gap` | Source files referenced as Targets but not fully covered by rules | YELLOW |
| `component-type-gravity` | One component type dominates the corpus -- under-classified | YELLOW |
| `cross-domain-fan-in` | A component imported by many domains -- coupling hotspot | YELLOW |
| `edge-type-monotony` | >80% of edges use a single edge type -- under-classified wiring | YELLOW |
| `l6-sink-cluster` | Components with only inbound edges and no outbound -- dead ends or sinks | YELLOW |
| `fan-out-hub` | One spec depends on many others -- coordination bottleneck | YELLOW |

**Compute and report:**

1. **Pattern count by category.** Count healthy patterns vs anti-patterns. State totals.
2. **Anti-pattern inventory.** For each anti-pattern found, list the participants and the summary. Group by severity (RED first, then YELLOW).
3. **Healthy pattern highlights.** Name the top 3 healthy patterns with highest confidence. One sentence each on what they show about corpus quality.
4. **Cross-phase correlation.** (Main thread only, during the vet step -- the subagent groups do not see each other's outputs.) Flag anti-patterns that reinforce other audit phases. Examples: `circular-dependency` correlates with Graph phase orphan/cycle findings; `edge-type-monotony` correlates with Topology phase edge-type distribution; `shared-target-conflict` correlates with Alignment phase attachment audit.

**Scoring:**
- GREEN: 0 anti-patterns, or only YELLOW anti-patterns with confidence < 0.5
- YELLOW: 1-3 distinct YELLOW anti-pattern kinds with confidence >= 0.5, or 1 RED anti-pattern with confidence < 0.5
- RED: any RED anti-pattern with confidence >= 0.5, or >3 distinct YELLOW anti-pattern kinds with confidence >= 0.5

Score on distinct kinds, not instances -- a mature corpus can carry dozens of instances of one tolerated kind (e.g. `shared-target-conflict`), and instance-counting guarantees RED regardless of health. Report instance counts in the findings; score by kind.

Skip this phase if `mast list patterns` returns no rows (no patterns detected, which can happen on very small corpora).

#### Phase: Staleness -- spec-to-code drift detection

**Goal:** Identify specs whose governing claims may no longer reflect reality.

This is the most complex phase. It computes a per-spec staleness score from multiple signals, then ranks specs by staleness.

##### Corpus-wide drift inventory (run first)

Anchor rot is the dominant observed failure mode in spec corpora, and the stale-anchor findings are buried in the warning pile, so surface them as first-class numbers before the per-spec scoring:

```bash
mast lint check . 2>/dev/null | grep -ciE "not found|does not exist"   # count of stale symbol/path anchors
mast lint check . 2>/dev/null | grep -iE "not found|does not exist"    # the inventory itself -- list these in the report
mast lint check . 2>/dev/null | grep -c "warning:"     # total warning count
```

Linter phrasings differ across versions -- before trusting a zero, verify the grep pattern against one known finding phrasing (introduce a temporary broken anchor in a scratch copy, or read one missing-path diagnostic from the linter source).

Findings go to stdout; the `2>/dev/null` keeps shim and progress noise out of the grep. Report both counts as health metrics in their own right. The anchor-rot count is the drift inventory. The total warning count matters because warnings do not gate -- `mast lint check` exits 0 with hundreds of them -- so unchecked growth is the broken-windows inversion in progress. Record both counts in the report header so the next audit can diff against the last committed report. If a previous audit or committed report recorded either number, report the delta: growth in either is a finding even when every individual warning looks tolerable.

##### Staleness signals

Each signal contributes points to a spec's staleness score. The score for each signal is the column value (0, 1, 2, or 3) -- they are not weighted further. A dash means the signal does not fire at that level.

| Signal | Max | 0 (fresh) | 1 (aging) | 2 (stale) | 3 (critical) |
|--------|-----|-----------|-----------|-----------|---------------|
| **Cite drift** | 3 | All citations fresh | -- | -- | Any citation stale |
| **Target file existence** | 3 | All Targets files exist | -- | -- | Any Targets file missing |
| **Git age gap** | 3 | Spec modified more recently than its targets | Targets modified 1-30 days after spec | Targets modified 31-90 days after spec | Targets modified >90 days after spec |
| **Rule/invariant status mismatch** | 2 | Status and lifecycle chips consistent | -- | Active spec with >50% `[pending]` `Rule R<n>` / `Invariant I<n>` entries, or pending spec with >50% `[active]` entries (both `R<n>` and `I<n>` carry the same `[pending]`/`[active]`/`[deprecated]`/`[removed]` lifecycle chips) | -- |
| **Attachment drift** | 2 | All derived attachment components exist in `.march` | -- | Any attachment (from `uses` imports or rule chip component refs) names a missing component | -- |
| **Design/Plan anchor on active** | 2 | No anchors where `blocks_graduation()` holds on active specs | -- | Active spec has `AnchorKind::Design` (`-design.md`) or `AnchorKind::Plan` (`-plan.md`) targets (should have been replaced with `Code`, `Context`, `Skill`, or `Doc` anchors before graduation) | -- |
| **Stale design/plan header** | 1 | No `design:` or `plan:` header on active specs | Active spec carries `design:` or `plan:` header (stale -- suggest archive/remove) | -- | -- |

**Maximum possible score:** 16 (all signals at worst).

##### Staleness thresholds

| Score | Label | Meaning |
|-------|-------|---------|
| 0 | FRESH | Spec aligns with its targets and the corpus graph |
| 1-3 | AGING | Minor drift detected -- review on next touch |
| 4-7 | STALE | Meaningful drift -- spec may not reflect current behavior |
| 8+ | CRITICAL | Multiple strong signals -- spec likely describes code that no longer exists or has fundamentally changed |

##### Data collection

Run these commands to gather staleness inputs:

```bash
# Citation state (content-pinned rule-to-rule and rule-to-invariant edges)
mast cite list 2>/dev/null

# Spec metadata (includes file paths for git age checks)
mast list specs

# Rules with lifecycle chips
mast list rules

# Invariants (NOTE: `mast list invariants` prints spec and text only -- the I<n>
# lifecycle chips are visible only via `mast spec read <id> --with-rules`;
# fetch chips per spec for the specs being scored, not corpus-wide)
mast list invariants

# Targets per spec (for file existence and git age)
mast list targets 2>/dev/null
```

For **git age gap**, compute per spec:

```bash
# Last modification date of the spec file
git log -1 --format="%ai" -- <spec-file-path>

# Last modification date of each target file
git log -1 --format="%ai" -- <target-file-path>
```

For **attachment drift**, compute the derived attachment set per spec (mast/3
attachment is derived from `uses { component: ... } from <id>` imports plus rule
chip component refs -- there is no authored `attached_to:` header):

```bash
mast describe attached <spec-id>
```

Check each returned component against `mast list components`.

For **target file existence**, check each path in the spec's `Targets` block:

```bash
test -f <target-path> && echo "exists" || echo "MISSING"
```

##### Report format

Present staleness results as a ranked table, worst first:

```
Staleness scan: <N> specs evaluated

CRITICAL (score >= 8):
  <spec-id>  score=<N>  signals: <list of triggered signals with details>

STALE (score 4-7):
  <spec-id>  score=<N>  signals: <list>

AGING (score 1-3):
  <spec-id>  score=<N>  signals: <list>

FRESH (score 0): <N> specs
```

For each non-fresh spec, list the specific signals that fired and their evidence. Example:

```
  idempotent-transfer  score=5  signals:
    - git-age-gap [2]: spec last modified 2025-11-01, target src/ledger/idempotency.ts last modified 2026-03-15 (134 days gap)
    - cite-drift [3]: R1 cites transfer-funds.R2 -- citation is STALE (upstream content changed)
```

##### Single-spec variant (for option 4 + spec)

When auditing a single spec, compute the same staleness score but also report:
- Full `mast spec read <id> --with-blocked-by` output
- Full `mast describe inbound <id>` output
- Each rule's status chip and a one-sentence summary of what it governs

#### Phase: Alignment -- code-to-spec attachment audit

**Goal:** Check whether specs reference code through the architecture layer and whether the references are valid. That attachment is *derived* (from `uses {component:} from` imports plus rule-chip component refs), not authored — and that the `Imports` block / `attached_to:` header are retired — is shared doctrine, see **REF-FILEKINDS**; this phase audits whether the derived set resolves.

**Process:**

1. **Attachment audit.** For each spec, compute its derived attachment set and verify the referenced components exist in the `.march` corpus:
   ```bash
   mast describe attached <spec-id>
   ```
   Attachment is derived from the spec's `uses { component: ... } from <id>` imports plus its rule chip component refs (`domain.Component[.port]`). Flag specs whose derived attachment names a component not declared in any `.march` file.

2. **Direct-reference bleed.** Scan spec `Targets` blocks for file paths. For each path, check if a `.march` component exists that governs the same file/directory. No command maps a component to its files directly -- treat a component as governing the directory matching its domain's `roots:` (falling back to crate/directory co-location by name), and say which heuristic attributed it in the finding. If a governing component exists, the spec should reference the component (via a `uses { component: ... } from <id>` import or a rule chip component ref) rather than the raw path. Report bleed findings.

3. **Unanchored specs.** Find specs with no `Targets`, no `uses` imports, and an empty `mast describe attached` set. These describe behavior with no code anchor -- they may be aspirational (fine for draft/pending) or disconnected (not fine for active).

4. **Graduation-blocking anchors on active specs.** For each active spec, check whether any `@file=` targets resolve to an anchor where `blocks_graduation()` holds: `AnchorKind::Design` (`-design.md`) or `AnchorKind::Plan` (`-plan.md`). Either kind on an active spec indicates an incomplete graduation -- these anchors should have been replaced with non-blocking anchors (`Code`, `Context`, `Skill`, or `Doc`) before `set-status active`. Flag as a RED finding.

**Scoring:**
- GREEN: no attachment misses, no bleed findings, no unanchored active specs
- YELLOW: <=2 attachment misses or bleed findings, or 1 unanchored active spec
- RED: >2 attachment misses, or >2 bleed findings, or >1 unanchored active spec

Skip attachment and bleed checks if the corpus has no `.march` files.

#### Phase: Governance -- constitution compliance posture

**Goal:** Assess the governance layer's health: constitution coverage, per-rule compliance progress, ratchet integrity, and compliance gaps. What a constitution / tier / `Compliance` block / ratchet *is* — the generic governance model — is shared doctrine, see **REF-GOVERNANCE**. What follows is `check`'s audit-specific use of it. Recall the model: compliance is tracked per rule against a constitution. A domain opts in by adding a `Compliance <constitution>` block to its `.march`; the block's first indented line is `enforces: <tier>`, followed by indented `certified:` / `pending:` / `waive:` keywords, each taking a rule-ID list (`certified: R1, R2`). A `waive:` line requires a justification string per rule (`waive: R6 "bootstrap exception"`). Multiple `Compliance` blocks are allowed on one `.march` (one per constitution). Any rule in the enforced tier not listed under `certified:` / `pending:` / `waive:` defaults to pending. Every governed rule is in exactly one state -- certified (a violation is an error), pending (a violation is a warning), or waived (info, with a required justification) -- and the certified set ratchets forward (rules can be added to `certified:` but never removed from it or regressed to `pending:` / `waive:`). On a behavioral `.mspec`, the same block carries no `enforces:` line and uses `certified: yes` (all rules) or an explicit `certified: R1, R2, I1` list. Constitutions are `.mspec` files with `kind: constitution` and a `Tiers` block listing rules only (never invariants) in monotonic-superset order.

**Commands:**

```bash
mast list constitutions                               # overview of all constitutions
mast list constitutions --format json                 # structured output
```

For each constitution:

```bash
mast describe constitution <id>                       # per-domain compliance table
```

For each governed domain:

```bash
mast describe governance <domain>                     # domain compliance breakdown
```

**Compute and report:**

1. **Constitution coverage.** How many domains enforce each constitution (via a `Compliance` block on their `.march`)? How many are unclaimed? List constitutions with their `Tiers` (ordered least-to-most restrictive) and domain counts.
2. **Compliance progress.** Per constitution: across all governed rules, how many are certified vs. pending vs. waived. Report the percentage of rules certified across all domains. Recall tiers list rules only, never invariants.
3. **Compliance gaps.** Per domain: which rules are still pending? Which are waived (with justifications)? Flag waived rules without a justification string (a linker error -- `mast lint check .` will surface it, but report if found).
4. **Tier distribution.** Which tiers are most adopted? Are all domains at the same tier, or is there variance? Because consecutive tiers form a monotonic superset chain, a domain enforcing a higher tier is bound to a superset of the lower tier's rules. High variance may indicate an uneven adoption curve.
5. **Certification information content.** Pull the `compliance:` block from `mast describe stats` (certified / pending / waived totals corpus-wide). Blanket certification -- every governed rule certified, zero pending, zero waived across all domains -- is a smell, not a strength: a ratchet that has never had anything to ratchet carries no information, and `certified: yes` one-liners are the cheapest conforming move. Report the distribution, and when it is N/0/0, state explicitly that the certified count is currently indistinguishable from ceremony. This finding does not lower the percentage-based score below, but it must appear in the report. Cross-check the stats block against each `mast describe constitution <id>` table first -- the two sources can disagree (stats may aggregate differently); when they do, score from the constitution tables and report the discrepancy as a tooling finding rather than asserting ceremony.
6. **Ratchet health.** The certified set is forward-only: once a rule ID appears under `certified:` in a `Compliance <C>` block on the base branch, it cannot be removed from `certified:` or regressed to `pending:` / `waive:` in a later commit. This ratchet is enforced at write time inside the binary's apply/transact layer (its "evolution ratchet" check) -- a regressing `mast spec patch` / `write` is rejected before the bytes land, so a clean working tree means the ratchet held. To audit it, compare the current `certified:` rule sets against the base branch: `git show <base>:<march-path>` versus the working copy, and flag any rule that left `certified:`. Any such regression is RED. Separately, run `mast lint check .` and grep for `imports/attached-to-deprecated` -- it means a spec still carries a retired `attached_to:` header that must be replaced with a `uses { component: ... } from <id>` import or a rule chip component ref.

The severity a governed rule's violation carries is a pure function of *compliance state × constitution status × rule chip* — the **severity-modulation truth table**:

| Compliance state | Violation severity |
|---|---|
| certified | **error** (always) |
| pending | **warning** (lifecycle-capped — never exceeds error even if the rule chip is active) |
| waived | **info** (always; requires a justification string) |

Certified is always error and waived is always info regardless of chip; only pending is modulated by lifecycle. Score against this table — never reclassify a finding's severity by feel.

**Scoring:**
- GREEN: >80% of governed rules certified, no certified-set regression vs base branch, 0 `imports/attached-to-deprecated` findings, all waivers have justifications
- YELLOW: 50-80% of governed rules certified, or <=2 pending rules across governed domains, or 1-2 unjustified waivers
- RED: <50% of governed rules certified, or any certified-set regression vs base branch, or any `imports/attached-to-deprecated` finding, or >2 unjustified waivers

Skip this phase if `mast list constitutions --count` returns 0 (no governance layer).

#### Phase: Velocity -- trend and risk signals

**Goal:** Surface trends that predict future development friction.

**Process:**

1. **Commit frequency by type.** Parse `git log --format="%s" -100` for conventional commit prefixes. Report counts per type. Compute feat:fix ratio -- healthy repos trend >2:1 (building more than patching).

2. **Churn hotspots.** Files changed most frequently in the last 30 commits:
   ```bash
   git log --oneline -30 --name-only --format="" | sort | uniq -c | sort -rn | head -10
   ```
   Exclude `.mspec`/`.march`/`.mtypes` files, `docs/`, lockfiles, and generated files from the churn list first -- a spec file cannot be "unspecced". Then flag files that appear in >30% of recent commits. Cross-reference with spec coverage: high-churn files without governing specs are risk.

3. **Spec churn.** Which specs have been modified most frequently in the last 30 commits? High-churn specs may indicate unstable contracts.

**Scoring:**
- GREEN: feat:fix >2:1, no high-churn unspecced files
- YELLOW: feat:fix 1-2:1, or 1-2 unspecced churn hotspots
- RED: feat:fix <1:1, or >2 unspecced churn hotspots

#### Phase: Code -- quality audit of the unspecced surface

**Goal:** Read the code no spec governs and report concrete quality findings. Deep audits only.

**Input -- compute it yourself (it does not depend on other phases' outputs):** invert the anchored-path set against the source tree:

```bash
mast list targets | awk -F'\t' '{print $3}' | sed 's|#.*||' | sort -u > /tmp/anchored.txt
git ls-files '*.rs' '*.ts' '*.tsx' '*.js' '*.jsx' '*.go' '*.py' | grep -v -E '(^|/)tests?/' | sort > /tmp/source.txt
comm -23 /tmp/source.txt /tmp/anchored.txt   # unanchored source files
```

Add the high-churn unspecced files from the Velocity phase when it ran. Sample the result (~10 files, by churn then size) rather than reading everything.

**Checklist -- correctness:**
- Swallowed errors: empty catch blocks, logged-and-ignored errors on critical paths, missing error states.
- Async hazards: unawaited futures/promises, check-then-act races on shared state, missing cancellation/cleanup.
- Escape hatches: non-null assertions, `unwrap()`/`expect()` clusters, `any`/`as` casts -- each is a place the compiler was overruled. Check whether the cluster sits in test code before reporting.
- Boundaries: off-by-one, empty-collection handling, non-idempotent retried operations (webhooks, queues).
- Resource leaks: unclosed handles/connections/subscriptions, missing `finally`/Drop.

**Checklist -- security:**
- Secrets: hardcoded keys/tokens, secrets in committed `.env`, secrets in logs.
- Injection: string-built SQL/shell, eval on dynamic input, path traversal on user-supplied filenames.
- AuthN/Z: endpoints missing auth checks, authorization checked client-side only, PII or stack traces in responses/logs.
- By-design is not a finding: standard platform conventions (honoring `https_proxy`, reading `~/.netrc`, a local dev tool shelling out to configured package managers) are intentional -- flag only when the implementation adds risk beyond the convention itself.

**Checklist -- performance (algorithmic wins only, no micro-optimizations):**
- N+1: query/fetch per item inside loops; missing batching.
- Nested scans where a keyed lookup belongs; identical expensive computation repeated with no memoization.
- Unbounded lists without pagination; synchronous work that belongs in a queue.

Each finding carries Impact / Effort / Confidence per the Audit output format.

**Scoring:**
- GREEN: no findings above LOW confidence
- YELLOW: any MED/HIGH-confidence correctness or performance finding
- RED: any HIGH-confidence security finding

Run this phase in the main thread after both subagent groups return (or recompute its inputs inside whichever group hosts it -- the input derivation above is self-contained by design). Skip below deep depth, or when the unspecced surface is empty.

#### Audit output format

Render the report in this structure, regardless of which phases ran:

```
## Repo Audit: <repo-name>

Date: <YYYY-MM-DD>
Surface: <full | architecture | specs | domain:<name> | spec:<name> | staleness>
Corpus: <N> specs (<active>/<pending>/<draft>/<retired>), <N> domains, <N> components

### Scorecard

| Phase | Score | Key finding |
|-------|-------|-------------|
| <phase name> | GREEN/YELLOW/RED/NOT COMPUTABLE | one-sentence summary |
| ... | ... | ... |

### Findings

#### [Phase name]
- **[Finding title]** -- [one-sentence description]. [file:line or the exact verbatim command (full pipeline) that shows it]. Impact: [what is being paid]. Effort: S/M/L. Confidence: HIGH/MED/LOW.

### Top 3 highest-ROI actions

1. **[Title]** -- [2 sentences: what to do and why]. Effort: S/M/L.
2. ...
3. ...
```

Rank the top-3 actions by leverage -- an ordinal judgment, not arithmetic: bucket Impact as BLOCKS-WORK / COSTS-TIME / COSMETIC, rank within buckets by effort ascending then confidence descending, and discount by fix-risk. Tiebreakers: actions that unblock other findings float up; HIGH-confidence security findings float above equivalent-leverage findings; prefer fixes with a clean verification story (a command that proves the fix landed). If there is no one-command way to know the codebase works, that is finding #1 and floats to the top regardless of leverage. "Not worth doing" is a valid verdict -- record it with one line of reasoning rather than padding the list.

Only include phases that were selected by the routing table. Omit phases that were skipped due to missing prerequisites (no `.march` files, no build system, no architecture tests) or deselected by depth -- but note the skip in a one-line "Skipped phases" row after the scorecard, naming the prerequisite or depth that excluded each. A phase that ran but could not be scored (granularity mismatch) appears in the scorecard as NOT COMPUTABLE with the mismatch named -- that is a third outcome, not a skip and not a RED. The report also states what was NOT audited -- coverage honesty is part of the deliverable.

#### Subagent strategy

For full repo audits, the phases divide into two independent groups:

- **Architecture group:** Topology + Drift + Archtest
- **Corpus group:** Patterns + Graph + Staleness + Alignment + Governance + Velocity

Spawn two parallel subagents -- one for each group -- to halve wall-clock time. The main thread owns the intake, the final scorecard, the top-3 actions, and the cross-phase correlations (e.g., "the attachment-drift finding in the Alignment phase is the same component flagged as an orphan in the Topology phase").

Brief each subagent with:
- The exact commands to run (from the phase descriptions above)
- The scoring rubric (so findings are pre-scored)
- Instruction to report raw data + scores, not narrative
- Instruction that every finding include the exact verbatim command (the full pipeline) that produced it -- the vet step re-runs that command, not an approximation

**Vet before scoring -- subagents over-report.** Before assembling the scorecard, the main thread re-opens the cited evidence (file and line, or by re-running the recorded command) for every finding that will make the report. Expect three failure classes: by-design behavior reported as a bug, mis-attributed file/line (real finding, wrong location), and duplicates across the two groups. Downgrade, correct, or merge accordingly; a finding whose evidence does not reproduce becomes a note, not a finding.

For focused audits (2-3 phases), run sequentially in the main thread -- the overhead of subagent dispatch exceeds the benefit.

**Budget.** At most two exchanges with the user in Phase 0 intake (never three). Run only the phases the routing table selects; spawn the two subagent groups only at standard/deep depth on a full repo, sequential otherwise. Every finding cites a reproducible command or file:line; vet before scoring; the report ends with the top-3 actions.

### Mode: Pre-flight

**Goal:** Verify all referenced files and specs exist before starting implementation. Fail fast on missing inputs.

Run this before starting any implementation loop or multi-step task.

**Gather.** Enumerate every referenced path and dependency, then probe each for existence.

#### Steps

1. **Identify all referenced files.** Scan the task description, spec file, or progress document for:
   - `.mspec` spec files
   - Source files (`.rs`, `.yml`, `.ts`, etc.)
   - Config files (`.json`, `.yml`, `Cargo.toml`)
   - Documentation files (`AGENTS.md`, `CLAUDE.md`, `README.md`)

2. **Verify each file exists.** For every referenced path:
   ```bash
   test -f <path> && echo "OK: <path>" || echo "MISSING: <path>"
   ```

3. **Verify `docs_dir` existence.** If specs reference graduation-blocking anchors (`AnchorKind::Design` for `-design.md`, `AnchorKind::Plan` for `-plan.md`) or carry `design:` / `plan:` headers, verify the `docs_dir` directory (default `docs/`) exists and the referenced paths resolve:
   ```bash
   test -d docs/ && echo "OK: docs_dir" || echo "MISSING: docs_dir (default docs/)"
   ```

4. **Verify spec dependencies.** If the task references a `.mspec` file, check its `Depends on` block and verify those specs exist too:
   ```bash
   mast spec read <spec-id> --with-blocked-by
   ```

5. **Verify build dependencies.** If the task requires new crate/package imports:
   ```bash
   # Rust
   grep -q '<crate>' Cargo.toml && echo "OK: <crate>" || echo "MISSING: <crate> -- add to [workspace.dependencies] or the crate's Cargo.toml"

   # Node
   node -e "try { require.resolve('<pkg>'); console.log('OK') } catch { console.log('MISSING') }"
   ```

6. **Report and abort if anything is missing.** List all missing files clearly:
   ```
   PRE-FLIGHT FAILED:
   - MISSING: specs/foo.mspec (referenced in task description)
   - MISSING: src/ledger/transfer-service.ts (referenced in spec target)
   ```
   Stop here. Do not proceed with implementation.

7. **If everything passes**, confirm:
   ```
   PRE-FLIGHT OK: all N referenced files verified
   ```
   Then proceed with the task.

**Render.** Either a `PRE-FLIGHT FAILED:` block listing every missing file (and a hard stop — do not proceed with implementation), or a `PRE-FLIGHT OK: all N referenced files verified` line before continuing.

**Budget.** One existence probe per referenced path; abort on the first missing-input set rather than partially proceeding.

---

## Style rules (all modes)

The no-emoji rule is a project convention — see **REF-CONVENTIONS**. The rest are `check`-specific:

- **Numbers, not adjectives.** "42 Imports edges, 1 Connects" -- not "mostly well-classified."
- **Cite evidence.** Every finding includes a file path, line number, or command. If you cannot cite evidence, downgrade the finding to a note.
- **Never reproduce a secret value** in any finding, report, or output -- cite the file:line and credential type only ("live API key at `config.ts:12`"). A committed secret is burned: the fix is rotation, not removal.
- **Advise, don't sell.** Prefer "not worth doing" verdicts over padding; a short list of high-confidence findings beats a long one.
- **Score conservatively.** When in doubt between YELLOW and GREEN, pick YELLOW. False negatives (missing a real problem) are worse than false positives (flagging a non-problem).
- **No emoji.** Per project convention (REF-CONVENTIONS). No headers below H3 in output.
- **End with actions, not observations.** The report's value is what to do next. Everything above it is justification.
- **Staleness scores are additive, not averaged.** A spec with one critical signal (score 3) and two minor signals (score 1 each) has total score 5 (STALE), not average score 1.7 (AGING).

## Worked example

[`examples/ledger/`](../../../../examples/ledger) is a small, self-contained mast project (its own `mast.toml` + `specs/`) you can run every mode against without touching the host repo (if `examples/` is not on disk — plugin installs ship only `plugins/mast/` — clone it from https://github.com/MastSystems/mast-skills/tree/main/examples/ledger to run the `examples/ledger` commands below):

- **Pre-push:** `mast lint ci examples/ledger` exits 0 — a clean baseline. The corpus carries multiple domains and components, feature specs across several lifecycle stages, and a governance constitution, so an Audit has real material: `mast describe governance ledger --root examples/ledger` shows a CERTIFYING domain (certified / pending / waived rules), and `mast describe attached transfer-funds --root examples/ledger` shows derived L7→L6 attachment.
- **What a healthy small corpus looks like:** every declared edge-type and component-kind is bound, every implemented feature attaches to a component (the queued `audit-trail` sketch deliberately has no attachment yet), and the one intentional debt is recorded as an `!overreach` edge annotation rather than left implicit — a model for the "evidence cited, no implicit problems" output an Audit should produce.
