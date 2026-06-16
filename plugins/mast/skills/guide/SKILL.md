---
name: guide
description: The continuity companion — use when the user asks "what's next", "where am I", "what should I work on", "what's ready to ship", "what's blocked", "give me a worklist", "continue", "what's the state of the corpus", or returns to a project and needs to re-orient on what to do next. This skill is subagent-driven (it does NOT run the corpus sweep in the main context) so the main thread stays uncluttered: it dispatches a sub-agent to query the read-only projections, compute each spec's standing, and rank candidates, then returns a terse ranked worklist. It SURFACES and RANKS; it never decides — selecting what to actually do is a value judgment the human owns. For a guided tour of an unfamiliar corpus use `/mast:orient`; to implement a chosen spec use `/mast:dag-plan`; to audit health use `/mast:check`.
---

# guide

This skill answers "where am I / what's next" by surfacing the corpus's actionable standing and ranking it — then helping you choose. The orchestrator (main thread) dispatches one sub-agent to run the read-only query sweep and rank the candidates; only a terse ranked digest crosses back. If you find yourself running the full `mast list` / `mast describe` sweep in the main context, stop and re-dispatch — the sweep belongs in the surveyor sub-agent so the main thread's tokens don't decay.

The load-bearing discipline: **surface and rank, never decide.** The rigid tier — which specs are ready, blocked, pending, in-scope, stale — is a deterministic function of the corpus plus the git working tree, and the surveyor computes it. The fuzzy tier — which of the ranked candidates *matters most* given your goals — is a value judgment that stays with you, in conversation. The skill must never collapse the worklist to a single mandated answer. (Design: `docs/mast-next-design.md`; contract: `next-projection` I2 `surface_not_decide`.)

Reference: REF-BINARY, REF-ROUTING, REF-DEPENDENCIES, REF-LIFECYCLE, REF-POSTURE
*(Reference sections live in `plugins/mast/skill-reference/` — e.g. `REF-LIFECYCLE` resolves to `plugins/mast/skill-reference/REF-LIFECYCLE.md`.)*

## Prerequisites

Which binary to invoke is shared doctrine — see **REF-BINARY**: call `mast` directly (the plugin puts it on Claude Code's PATH), or `./bin/mast` in a repo that vendors the shim. If `mast` cannot be provisioned, stop and tell the user to install it before proceeding. This skill is read-only — it never writes a spec; it surfaces what *could* be done next.

## Intent routing

The cross-skill routing table and the bypass-gate are shared doctrine — see **REF-ROUTING**. `guide` is the entry point for *"I don't know what to do next"*: open-ended continuity questions where the user has no specific spec in mind. The moment the user names a concrete spec ID, rule, or command, they are past the guide — route straight to the skill that owns that work (below).

## When NOT to use

- The user named a specific spec/rule to read or edit → **`/mast:spec`**.
- They picked a spec and want to *implement* it → **`/mast:dag-plan`** (it owns phasing, seams, TDD).
- They want a health/compliance *audit*, ask "what needs attention" / "what's stale", or "is X done" → **`/mast:check`** — it owns staleness and health phrasing; `guide` cedes those triggers to it.
- They are onboarding a brand-new project from zero → **`/mast:start`**; an empty corpus that needs seeding → **`/mast:mine`**.
- They want a narrative tour or a conceptual question answered → **`/mast:orient`**.

`guide` hands the user *to* those skills with a concrete next command; it does not do their work.

## The pipeline (subagent-driven)

One dispatch, then synthesis. The orchestrator (main thread) does **not** run the sweep.

### Step 1 — dispatch the standing surveyor (one sub-agent)

Spawn a single sub-agent with the brief below. It runs the read-only query sweep, computes standing, ranks, and returns a terse digest. Keep its budget tight (≤400 words back).

> **You are the standing surveyor for `mast guide`. Using ONLY read-only `mast` commands plus `git diff --name-only`, compute and rank the corpus's actionable candidates. Do not write anything. Return a ranked worklist, not a single answer.**
>
> **Query vocabulary (compose these — nothing more exotic is needed):**
> - `mast list specs --status pending` and `--status draft` — the candidate pool (specs that could advance).
> - `mast spec read <id> --with-blocked-by` — readiness: an **empty** blocked-by closure means *ready to ship*; a non-empty one lists the blockers.
> - `mast describe status <id>` — `graduation_eligible`, `fully_implemented`, and the `pending_rule_ids`.
> - `mast list pending` — every rule still carrying a `[pending]` chip, across the corpus.
> - `git diff --name-only | mast list scope --file -` — the specs the current working tree touches (*in-scope*). `scope` reads paths from stdin via `--file -`; it has no positional file argument.
> - `mast describe inbound <id>` — how many specs depend on this one (centrality → leverage).
> - `mast describe graduate <id>` — **confirmation only** (it dumps the full canonical spec text); run it on a candidate the user has already picked, never inside the ranking sweep.
>
> **Two passes — do not deep-probe the whole pool.** Pass 1 (cheap): rank the full candidate pool by `--status`, `mast list pending` counts, and the in-scope set. Pass 2 (deep, top ~5 only): run `--with-blocked-by` + `describe status` on the leaders to confirm readiness and name blockers. Per-candidate fan-out over the whole pool blows the budget for no ranking gain.
>
> **Standing** (one per candidate, computed — never guessed): `ready` (empty blocked-by + graduation_eligible) · `blocked` (name the blockers) · `pending` (carries `[pending]` rules) · `in-scope` (touched by the working diff) · `stale` (design anchor drift). The dependency triad behind blocked-by — `Depends on` / `extends` / `cites` — is shared doctrine (**REF-DEPENDENCIES**); the ready/stale lifecycle and the anchor ratchet are shared doctrine (**REF-LIFECYCLE**).
>
> **Ranking signals** (objective, corpus-derived — no opinion): graduation-eligible first; then in-scope candidates carrying pending rules (you are already touching them); then fewest transitive blockers; break ties by inbound centrality. Carry the signal that placed each row.
>
> **Return** a ranked list, each row exactly: `<id> — <standing> — <one-line why-this-rank> — next: <the concrete mast command to act on it>`. Cap at ~8 rows. Append one line of caveats (anything you could not compute, e.g. a near-cycle or a tool error). Stay descriptive, not prescriptive (**REF-POSTURE**): report standing, do not editorialize on importance.

### Step 2 — synthesize and hand the judgment back (main thread)

Present the surveyor's ranked worklist to the user verbatim-ish (tighten, don't pad). Then **apply the fuzzy tier with them, not for them**: note which rows align with what they said they were doing, surface any in-flight intent the corpus can't see (work-in-progress that hasn't landed as bytes), and ask which thread they want to pull — `AskUserQuestion` if a genuine fork. Never auto-pick the top row as "the" answer; the rank is a worklist, the choice is theirs. Once they choose, hand off with the row's `next:` command to the owning skill (`/mast:dag-plan`, `/mast:spec`, `/mast:check`).

## Surface, never decide

This is the one rule the skill cannot break. The surveyor emits an *ordered* list with rationale; the main thread helps the human *select*. A `guide` run that ends in "you should do X" without the human choosing has silently encoded a priority function it does not own — the same failure `next-projection` I2 forbids for the tool. Rank is mechanical; selection is judgment; judgment is the user's.

## Forward compatibility with `mast next`

Today the surveyor *composes* the projections above. When the `next-projection` spec lands as a real `mast next` verb (its R3 verb amendment), the surveyor's whole sweep collapses to a single `mast next --format json` call — same standing, same ranking, computed once in one tested home instead of re-derived here. The brief changes from "compose these queries" to "call `mast next`"; nothing else about this skill moves. Drafting `guide` first, composing directly, resolves the `next-projection` R4 open question in favor of *skill-first, verb-as-single-home-refactor-later*.

## Style rules

- **Orchestrate; never sweep in the main context.** The `mast list`/`describe` sweep runs in the surveyor sub-agent so the main thread stays clean. If you catch yourself running it inline, stop and re-dispatch.
- **Compute standing; never guess it.** Every `ready`/`blocked`/`pending` claim traces to a command the surveyor ran. "Probably ready" is not a standing.
- **Rank, then defer.** Emit the ranked worklist; let the human choose. Surface, never decide.
- **Descriptive, not prescriptive (REF-POSTURE).** Report the corpus's standing; do not moralize about which work is "most important."
- **Read-only.** `guide` never writes a spec. It ends by handing the user a `next:` command and the skill that owns it.

## Worked example

> *(Illustrative — your corpus and its standings will differ; the surveyor computes them live, so never copy these rows.)*
>
> **User:** "I just got back to this — what's next?"
>
> Main thread dispatches the surveyor. Pass 1: `mast list specs --status pending` + `--status draft`, `mast list pending`, `git diff --name-only | mast list scope --file -`. Pass 2 (top few): `--with-blocked-by` + `describe status`. It returns:
>
> ```
> web-frontend    — in-scope — touched by the working diff, carries [pending] rules — next: /mast:check web-frontend
> next-projection — blocked  — draft; blocked by subagent-contract [pending]        — next: /mast:spec read subagent-contract --with-blocked-by
> skill-suite     — blocked  — ready-shape, but 3 deps still [pending]              — next: /mast:spec read skill-suite --with-blocked-by
> caveat: nothing is graduation-ready right now — the [pending] pool is dep-blocked, with subagent-contract a common root.
> ```
>
> Main thread: "Nothing's clear-to-ship yet — the pending specs are blocked on each other, with `subagent-contract` a common root. `web-frontend` is what your working tree is already touching. Want to unblock the root, stay on what you're editing — or were you mid-thought on something not in the corpus yet?" — it surfaces the standings and asks; it does **not** declare a winner.
