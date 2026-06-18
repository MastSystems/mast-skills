---
name: start
description: "First-time onboarding for mast. Detects project state, asks what the user wants, and guides their first session with concrete commands. Triggers on: \"I just installed mast\", \"how do I use mast\", \"what is mast\", \"getting started\", \"tutorial\", \"help me get started\", \"new to mast\", \"first time\", \"set up mast\", \"onboard me\", \"where do I begin\". Routes to /mast:orient, /mast:spec, /mast:mine, or /mast:check once the user is ready."
---

# start

This is the onboarding skill. It teaches through doing, not lecturing. Every explanation ends with a command the user can run. When the user knows enough to work independently, hand off to the right skill.

Reference: REF-BINARY, REF-FILEKINDS, REF-LIFECYCLE, REF-GOVERNANCE, REF-ROUTING, REF-HOOKRULE, REF-CONVENTIONS, REF-DEPENDENCIES
*(Reference sections live in `plugins/mast/skill-reference/` — e.g. `REF-FILEKINDS` resolves to `plugins/mast/skill-reference/REF-FILEKINDS.md`.)*

## Prerequisites

Which binary to invoke and when is shared doctrine — see **REF-BINARY**. Before anything else, check whether `mast` is installed:

```bash
command -v mast >/dev/null 2>&1 && mast --version
```

If not found, **stop and show this installation gate**. Do not proceed past it without a working `mast` binary:

> mast is not installed. Pick one:
>
> - **macOS / Linux:** download the latest prebuilt binary from [GitHub Releases](https://github.com/MastSystems/mast-skills/releases/latest) (Linux x86_64, macOS Intel, and Apple Silicon, each with a `.sha256` sidecar)
> - **Repos that pin a mast release in `.mast-version`:** run `./bin/mast <args>` (the shim fetches and SHA-verifies the pinned release binary)
> - **Other platforms:** see [Installation](https://github.com/MastSystems/mast-skills#installation)
>
> Run `/mast:start` again after installing.

Do not proceed past this point without a working `mast` binary.

## Intent routing

This skill detects state silently, then asks ONE routing question and follows the chosen guided path. Default mode: **Phase 1 Detection**, which always runs first; the detected spec count selects the routing variant (A when a corpus exists, B when it is empty), and the user's answer selects one of the six guided paths in `## Modes / playbooks`.

| The user's situation / intent | Mode |
|-------------------------------|------|
| Just arrived, any onboarding phrasing | Phase 1 Detection (always first) |
| Corpus exists, wants to see what's there | Path: Explore what exists |
| Wants the concepts behind mast | Path: Learn the mental model |
| Wants to start contributing specs (corpus exists) | Path: Jump into editing |
| No corpus yet, wants a first spec fast | Path: Quick start |
| No corpus yet, wants specs drafted from code | Path: Mine the codebase |
| Corpus exists, wants a health read | Path: Run a health check |

## When NOT to use

The cross-skill routing table and the bypass-gate are shared doctrine — see **REF-ROUTING**. In particular:

- The user already knows mast and wants to read/write a spec. Route to `/mast:spec`.
- The user wants a corpus walkthrough or architecture explanation. Route to `/mast:orient`.
- The user wants to verify work or fix CI. Route to `/mast:check`.
- The user wants to mine a corpus from existing code. Route to `/mast:mine`.
- The user has a complex multi-phase implementation to plan or execute against specs (dependency ordering, TDD phases, graduation). Route to `/mast:dag-plan`.

If the user's message contains a specific spec ID, rule number, or CLI command, they are past onboarding (the bypass-gate, REF-ROUTING). Skip this skill and route directly.

## Modes / playbooks

### Mode: Phase 1 -- Detection (always first)

**Gather.** Before asking the user anything, probe the project state silently. Run all five probes:

```bash
# 1. Is there a mast.toml?
test -f mast.toml && echo "HAS_CONFIG" || echo "NO_CONFIG"

# 2. How many specs exist?
mast list specs --count 2>/dev/null || echo "0"

# 3. Are there .march files (architecture layer)?
mast list domains --count 2>/dev/null || echo "0"

# 4. Are there constitutions (governance layer)?
mast list constitutions --count 2>/dev/null || echo "0"

# 5. What kind of project is this?
test -f Cargo.toml && echo "PROJECT_TYPE=rust"
test -f package.json && echo "PROJECT_TYPE=node"
test -f go.mod && echo "PROJECT_TYPE=go"
test -f pyproject.toml && echo "PROJECT_TYPE=python"
test -f pom.xml && echo "PROJECT_TYPE=java"

# 6. Onboarding phase + next command -- also flags whether AGENTS.md is mast-aware
mast doctor 2>/dev/null || echo "DOCTOR_UNAVAILABLE"
```

**Render.** Record the results. You need five facts: config exists (yes/no), spec count, domain count, and constitution count (numbers), and project type (for later context). Note that the domain probe (`mast list domains --count`) is a proxy for `.march` presence -- domains approximate `.march` files but are not strictly 1:1, so treat a non-zero count as "architecture layer present," not an exact file count. `mast doctor` is the authoritative onboarding-state probe: it names the phase (e.g. `P1 (Initialized)`), lists findings -- notably `AGENTS.md lacks the mast sentinel zone -- mast context onboard` whenever the project's AGENTS.md is not yet mast-aware -- and prints the single `Next:` command. Whenever that finding is present, make sure the chosen path ends by running the AGENTS.md onboarding step (`mast context onboard` then `mast context render`); a project is not fully onboarded until its AGENTS.md carries the rendered zone.

**Budget.** Silent. Emit no narration during detection; the first user-facing output is the Phase 2 routing question.

### Mode: Phase 2 -- Routing question

**Gather.** Use the spec count from detection to pick the variant.

**Render.** Ask the user ONE question via direct output (not a tool call -- keep it conversational). Use the appropriate variant.

**Variant A: Corpus exists (spec count > 0).** The project already has specs. The user is joining an existing team or revisiting after a break. If constitutions were detected, mention it: "with N specs (including K constitutions governing M domains)".

> This project has a mast corpus with N specs. What would you like to do?
>
> 1. **Explore what exists** -- I will walk you through the corpus, show you the most important specs, and explain how they connect.
> 2. **Learn the mental model** -- understand the three file kinds (.mspec, .march, .mtypes), how specs connect to each other and to code, and why this approach works.
> 3. **Jump into editing** -- learn the read/write/patch workflow so you can start contributing specs.
> 4. **Run a health check** -- see how healthy the corpus is and what needs attention.

**Variant B: No corpus (spec count = 0).** The project has no specs. The user is adopting mast for the first time.

> This project does not have any mast specs yet. How would you like to start?
>
> 1. **Quick start** -- create your first spec in about two minutes. I will walk you through every line.
> 2. **Mine the codebase** -- let mast analyze your code structure and draft specs automatically.
> 3. **Learn first** -- understand what mast is and how it works before creating anything.

**Budget.** Exactly one question, then wait for the user's answer before proceeding to a guided path.

### Mode: Path -- Explore what exists (Variant A, option 1)

**Goal:** The user understands the corpus shape and can navigate it.

**Gather + Render (one step at a time):**

**Step 1.** Run `mast describe stats` and narrate the numbers in two sentences.

**Step 2.** Run `mast list deps`, compute the top 3 specs by inbound dependency count.

**Step 3.** For the most-depended-on spec, run `mast spec read <id>` and walk the user through each section (header, Boundary, Depends on, Rules, Inbound) in one sentence each. Summarize -- do not quote verbatim.

**Step 4.** If domain count > 0, run `mast list domains` and `mast list components`. One sentence: "The project also declares N domains with M components. Explore with `mast describe domain <id>`."

**Step 5.** Run `mast list patterns --count`. If > 0, one sentence: "The corpus has N detected structural patterns. Run `mast list patterns` to see them, or `/mast:check` for a scored audit."

**Step 6.** If constitution count > 0, run `mast list constitutions`. One sentence: "The project uses N constitutions for governance. Run `mast describe governance <domain>` to see a domain's compliance state, or `mast describe constitution <id>` for the full tier and certification breakdown."

**Step 7.** Hand off: "Use `/mast:orient` for deeper spec tours, `/mast:spec` to read or edit, `/mast:check` for health audits."

**Budget.** One command per step; one or two sentences of narration each.

### Mode: Path -- Learn the mental model (Variant A option 2, or Variant B option 3)

**Goal:** The user understands the three file kinds, lifecycle, and dependency model.

**Gather + Render (one concept per step):**

**Step 1 -- The three file kinds.** The three file kinds (`.mspec` feature / `.march` domain / `.mtypes` alphabet), and that there is no `lang:` header, are shared doctrine -- see **REF-FILEKINDS**. Teach them one at a time in plain language, then add the governance concept that builds on them: **constitutions** are special `.mspec` files (with `kind: constitution`) that declare governance rules organized into tiers; domains (`.march` files) opt into governance via `roots:` plus a `Compliance <constitution>` block. The constitution / tiers / Compliance / ratchet model is shared doctrine -- see **REF-GOVERNANCE**.

**Step 2 -- Lifecycle.** The status order (draft to pending to active to retired), per-rule status chips, and that CI gates only fully enforce active specs are shared doctrine -- see **REF-LIFECYCLE**. Narrate it in one or two sentences.

**Step 3 -- Anchors (how a rule points at proof).** What an anchor is, the design-anchor vs code-anchor distinction, the suffix-decides-kind rule, the `design:` header, and that a design (or `*-plan.md` plan) anchor blocks graduation until you point at real code are shared doctrine -- see **REF-LIFECYCLE** (anchor ratchet + AnchorKind taxonomy). Walk the user through it conversationally; do not re-derive the rules here.

**Step 4 -- Dependencies.** The dependency triad -- `Depends on` (this spec assumes that spec is satisfied), `extends` (inheritance from a parent spec), and `Cites` (rule-level content-pinned reference; the linker flags drift if the upstream rule changes) -- is shared doctrine -- see **REF-DEPENDENCIES**. Name the three kinds for the user, one line each; do not re-derive the semantics here.

**Step 5 -- Concrete example.** If specs exist, pick a small one and run `mast spec read <id>`. If empty, show this template:

```
spec: user-login
title: User login with email and password
status: pending
version: 1
design: docs/user-login-design.md

Boundary
  in: email/password authentication , session creation
  out: OAuth , SSO , password reset

Invariant I1.no-plaintext [pending]
  passwords are never stored or logged in plaintext

Rule R1.session-token [pending]
  Given a user submits valid credentials
  Then a session token is created
    MUST expiry: the token MUST expire after 24 hours
    MUST format: the token MUST be a signed JWT
```

Point out how the header block (spec/title/status/version) names the spec, how the `design:` header links the design doc you write *before* the code (the starting point for a brand-new `[pending]` spec), how Boundary declares scope, how an `Invariant I<n>` states a spec-wide assertion with no Given/When/Then, and how the MUST constraints inside a rule are specific and testable. (That the file kind is inferred from the extension rather than a `lang:` line is shared doctrine -- see REF-FILEKINDS.)

**Step 6.** Hand off. If corpus exists: "Try `/mast:orient` to see this in your codebase, or `/mast:spec` to read a spec." If empty: "Ready to create? Let's do the Quick start now — or use `/mast:mine` to draft specs from code." Then proceed directly to the Quick start path below.

**Budget.** One concept per step; no bundling.

### Mode: Path -- Jump into editing (Variant A, option 3)

**Goal:** The user knows read/write/patch and can work independently.

**Gather + Render (one step at a time):**

**Step 1 -- Reading.** Pick a real spec and run `mast spec read <spec-id>`. Point out the Inbound section at the bottom -- it shows relationships from *other* specs, invisible if you just open the file. Mention `--with-rules` and `--with-blocked-by` briefly. (Direct `.mspec` Read/Edit is blocked by a PreToolUse hook; always route through the CLI -- shared doctrine, see **REF-HOOKRULE**.)

**Step 2 -- Creating.** `mast spec create my-feature --title "My first feature"` scaffolds a minimal valid .mspec.

**Step 3 -- Adding a rule.** Show the patch command:

```bash
mast spec patch my-feature rule add <<'EOF'
Rule R1.responds [pending]
  Given a user performs an action
  Then the system responds correctly
    MUST response_time: the response MUST complete within 200ms
EOF
```

The `.name` suffix on the rule header is optional but encouraged. The CLI parses, lints, and formats before writing. Malformed input leaves the file untouched.

**Step 4 -- Verifying.** Run `mast lint check .`. This runs per-file validation plus cross-spec linking -- the same pipeline CI runs on every PR.

**Step 5.** Hand off: "Use `/mast:spec` for all operations, `mast lint check .` before every push, `/mast:check` for deep audits."

**Budget.** One command per step.

### Mode: Path -- Quick start (Variant B, option 1)

**Goal:** A working spec in under two minutes.

**Gather + Render (one step at a time):**

**Step 1 -- Initialize.** If no `mast.toml` exists, run `mast spec init`. This creates the config and a `specs/` directory.

**Step 2 -- Create a spec.** Ask the user what feature to spec. If they have no preference, suggest one based on project type (e.g., "API validation" for a web project, "CLI argument parsing" for a CLI). Then run `mast spec create <id> --title "<title>"`.

**Step 3 -- Design first.** For a brand-new feature the first artifact is a design doc, not code (the anchor ratchet -- REF-LIFECYCLE). Suggest the user jot a few lines into `docs/<chosen-id>-design.md` describing the intended behavior. That doc is then linked from the spec's top-level `design:` header (`design: docs/<chosen-id>-design.md`); the header is written through the full-spec pipeline (`mast spec write`, surfaced by `/mast:spec`), and mast validates the file exists. A design anchor keeps the rule from graduating until real code is wired up. (Skip this only if the code already exists.)

**Step 4 -- Add a rule.** Build one together -- ask for the Given condition, Then outcome, and a MUST constraint. The `[pending]` chip stays anchor-free until the code lands; the spec's `design:` header carries the design link in the meantime. Then run:

```bash
mast spec patch <chosen-id> rule add <<'EOF'
Rule R1.first [pending]
  Given <their condition>
  Then <their outcome>
    MUST <key>: <their constraint>
EOF
```

**Step 5 -- Verify.** Run `mast lint check .`. If it passes: "Your first spec passes all checks. The CLI parsed it, ran lint validators, and verified cross-spec references -- the same pipeline CI runs on every PR."

**Step 6 -- Wire mast into AGENTS.md (do not skip).** So every agent on this project discovers the corpus, insert and fill the mast-managed zone in the project's `AGENTS.md`:

```bash
mast context onboard    # inserts the <!-- MAST:BEGIN --> ... <!-- MAST:END --> sentinel zone (idempotent)
mast context render     # fills the zone with the corpus TOC + a "how to use the mast CLI" section
```

Then commit the regenerated `AGENTS.md`. Content outside the sentinel markers is never touched. The rendered zone tells future agents to drive everything through `mast spec read|write|patch` and to discover commands via `mast <command> --help` -- which is how a teammate or agent who has only the binary learns the corpus. From now on, re-run `mast context render` after any corpus-changing write (`mast lint ci .` rejects a drifted zone); `--check` on either command classifies drift without writing.

**Step 7.** Hand off: "Use `/mast:spec` to add more rules, `/mast:mine` to draft specs from code, `/mast:check` before pushing."

**Budget.** One command per step; under two minutes end-to-end.

### Mode: Path -- Mine the codebase (Variant B, option 2)

**Goal:** Hand the user off to mining with the right expectation.

**Gather + Render.** If no `mast.toml` exists, run `mast spec init` first. Then explain: "Mining reads your code structure and proposes specs. It does not write directly -- you review a proposal and decide what to keep." Hand off to `/mast:mine`. Once mining has landed an approved corpus, finish onboarding by wiring AGENTS.md -- `mast context onboard` then `mast context render` (Quick start step 6) -- so the new corpus is visible to every agent on the project.

**Budget.** Two sentences plus the hand-off.

### Mode: Path -- Run a health check (Variant A, option 4)

**Goal:** Hand the user off to verification with the right expectation.

**Gather + Render.** Explain: "The check skill runs CI-equivalent validation plus staleness detection, architecture scoring, and structural pattern analysis -- it detects 17 kinds of recurring motifs and anti-patterns in the corpus." Hand off to `/mast:check`.

**Budget.** Two sentences plus the hand-off.

### Mode: Phase 4 -- Skill map (after any path completes)

**Gather.** None.

**Render.** After any path completes, always show this card:

```
Where am I / what next:
  mast doctor                                  -- onboarding phase + the single next command
  mast context onboard && mast context render  -- make this project's AGENTS.md mast-aware (do this once)

Your mast skills:

  /mast:spec    -- read, write, or patch any spec (daily driver)
  /mast:orient  -- understand what is in the corpus or how the model works
  /mast:check   -- verify before pushing, fix CI, or audit corpus health
  /mast:mine    -- draft a corpus from existing code (one-time setup)
  /mast:dag-plan -- plan, phase-execute (TDD), and review spec implementation
  /mast:start   -- re-run this tutorial anytime

Governance commands (if constitutions exist):
  mast list constitutions              -- list constitutions with tier and certification status
  mast describe governance <domain>    -- domain's compliance breakdown
  mast describe governance-for <path>  -- which domain governs a file path
  mast describe constitution <id>      -- constitution tier and per-domain compliance table
```

**Budget.** The card verbatim; no extra prose.

## Style rules

The no-emoji rule is a project convention — see **REF-CONVENTIONS**. The rest are start-specific:

- **No jargon without definition.** The first time you say "linker", explain it links specs together and catches broken references. The first time you say "L6", say "architecture layer." After the first definition, use the short form.
- **Concrete over abstract.** Show the command, then explain what it does. Not the other way around.
- **One thing at a time.** Each step teaches one concept or shows one command. Do not bundle.
- **No emoji.** Per project convention (REF-CONVENTIONS).
- **Adapt to the project.** Use spec IDs, file names, and domain names from the actual corpus when available. Fall back to generic examples only when the corpus is empty.
- **Celebrate milestones briefly.** When the user successfully reads a spec, creates one, or passes a lint check, acknowledge it in one sentence. Do not over-praise.
- **Do not re-explain mast to someone who already knows it.** If the user's follow-up question shows familiarity, drop the tutorial tone and route to the appropriate skill immediately.
