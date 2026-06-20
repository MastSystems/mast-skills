# mast

**Vagueness doesn't compile.**

Your specs become a linted, symbol-pinned, queryable corpus — one the agent can't make vague, or let rot unnoticed.

`MIT` · Claude Code plugin · `mast@mastsystems`

---

mast is spec-driven development where the spec is a machine-checked corpus — the set of `.mspec` files in your repo, treated as one linted, queryable database — not prose. Each file holds one feature contract: one rule per paragraph, every rule pinned to the code it satisfies (i.e. it records a checked reference to a real file path and the symbol inside it). A real Rust binary parses, lints, formats, and queries those files, and it ships with this plugin — so the discipline is enforced, not suggested.

Hedging words like *probably*, *roughly*, and *some* are hard errors, so vague rules never land. Per-file checks run first and short-circuit, so a hedge is caught before the corpus even loads. And **the only path to disk runs parse → lint → canonical format → atomic rename** — so within mast's workflow your agent has no way to save a malformed or vague spec.

## Install

In Claude Code:

```
/plugin marketplace add MastSystems/mast-skills
/plugin install mast@mastsystems
```

Dogfooding (GitHub Copilot):

In a Copilot chat or the Copilot UI on this repo, run:

```
/plugin marketplace add mastsystems/mast-skills
/plugin install mast@mastsystems
```

This registers the in-repo marketplace and installs the `mast` plugin for your Copilot session; no mirror portal needed.

The first time a skill or hook needs the `mast` binary, the right prebuilt for your host is fetched over the network (SHA-256 verified) and cached — or, offline, it falls back to a local `cargo` build. The plugin also puts a `mast` shim on your `PATH`: the skills run the `mast` commands shown below for you, and you can run them directly too.

- **Supported platforms:** Linux x86-64, macOS Intel, macOS Apple Silicon. Other hosts (ARM Linux, Alpine/musl, Windows) fall back to a local `cargo` build rather than failing silently.
- **Env knobs:** `MAST_CACHE_DIR` (override the cache root), `MAST_FORCE_REFRESH=1` (re-fetch the binary), `MAST_OFFLINE=1` (skip downloads; build locally).

> **Validation is `mast lint check` (per-file + linker) or `mast lint ci` — there is no bare `mast check`. The `/mast:check` skill is a Claude Code skill, not a shell command.**

## See it refuse a bad spec

The agent drafts a rule that hedges, and lint runs before any bytes reach disk:

```
$ mast spec write lang-parser <<'EOF'
Rule R4
  Given a malformed token stream
  Then the parser probably recovers and continues
EOF
spec write: error: weasel word "probably" ...
```

*The `spec` skill drives the write; `spec write: error:` and exit 2 are mast's real diagnostic shape, message text abbreviated.*

Exit 2 — nothing is written. The refusal isn't advice; it's the only path to disk, and a hedge word is the same severity as a syntax error. The agent de-hedges into a concrete claim, the write lands, and mast prints the canonical path:

```
$ mast spec write lang-parser <<'EOF'
Rule R4
  Given a malformed token stream
  Then the parser emits a partial AST and continues
EOF
specs/lang-parser.mspec
```

## vs. a markdown spec

- **Superpowers** gives Claude general TDD and debugging discipline.
- **BMAD** gives you analyst/PM/architect personas that emit design docs.
- **OpenSpec** gives you tool-agnostic markdown specs — but nothing parses, lints, or pins them.

mast is the only one where a real binary fails your CI, **by name**, when a spec hedges or pins to a file that moved. The spec is a machine-checked, queryable corpus — not a doc that lies the moment the code drifts.

## Why mast

- **Vagueness is a compile error, not a code-review nit.** A fixed, case-insensitive list of 17 hedging words — `approximately, should, reasonably, a few, some, probably, maybe, might, roughly, around, about, fairly, quite, generally, often, usually, sometimes` — is a hard error in rule text, matched at word boundaries. That includes the weak normative *should*: rule text must commit. There is no warning mode.
- **Specs that can't rot unnoticed.** Drift in what a rule points at is named at lint / CI time:
  - **File pins are verified exactly.** Delete or move the file a rule pins to and `mast lint check` / CI fails by name (`@file= path does not exist`) — a hard error, no grep required.
  - **Symbol pins are a best-effort hint.** Rename the symbol inside an existing file and you get a *warning*, not a gate: it's a substring heuristic that can miss or false-positive, which is exactly why file drift errors and symbol drift only warns.
  - **Citations are content-pinned.** Rule-to-rule citations live in a lockfile and are flagged the instant the cited text changes; `mast cite ack` clears the flag once you confirm the citation still holds (`mast cite list` shows what's pending).
  - **Your agents' brief can't drift either.** `mast context render` regenerates the managed `AGENTS.md` zone deterministically; `mast context render --check` fails CI on a stale zone.
- **A query grep can't answer.** Point mast at a file you just changed and it tells you which specs and architecture components now need review — `mast list scope --file` runs the corpus backwards, from code to the contracts that govern it. From there: what depends on a spec, who cites a rule, corpus-wide counts. Every write is CLI-mediated, so the index never drifts from the bytes.
- **A lifecycle you can check.** Every rule carries a status — `pending → active → amended → retired`. Pending rules carry no anchor; promoting a rule to `active` or `amended` without pinning it to a chip anchor is a lint error. The `dag-plan` skill decomposes a spec into an implementation DAG (phases, parallel lanes, seams); `guide` ranks what's ready versus blocked. You advance the corpus rule by rule as the code lands.

## First thing to say to Claude

Just talk to it. Skills are invoked by intent (or with `/mast:<name>`).

- **Existing repo?** → `mine` drafts the corpus from your code → `orient` tours it → `guide` says what's next. Run `mine` first — it produces the specs the other skills act on.
- **New or empty repo?** → `start` onboards you.
- **Working a spec?** "Read the `<spec>` spec" / "Add a rule to `<spec>`" → `spec`, the only legal path to spec content.
- **Ready to build?** "What should I work on?" → `guide`; "Plan the implementation of `<spec>`" → `dag-plan`.

## What's in the plugin

**7 skills** — invoked by talking to Claude, or `/mast:<name>`:

| Skill | The one job it does |
|-------|---------------------|
| `start` | First-time onboarding — detects project state, asks what you want, routes you to the right skill with concrete commands. |
| `orient` | Orientation — corpus walkthrough, single-spec deep-dive, task routing, code-to-spec reverse lookup ("which spec governs this file?"), and conceptual Q&A. |
| `spec` | The only legal path to spec content — read, create, rewrite, or patch any `.mspec`/`.march`/`.mtypes`; parse + lint + format runs before bytes land on disk. |
| `mine` | Extract a candidate `.march`/`.mtypes`/`.mspec` set from an existing codebase — subagent-orchestrated, outputs a proposal manifest with confidence levels, never direct writes. |
| `check` | Verification in four modes — pre-push local CI, CI-fix (diagnose a red GitHub Actions run and fix in one commit), audit (scored health report), pre-flight (verify referenced files exist). |
| `dag-plan` | Decompose specs into an implementation DAG — phases, parallelism lanes, seams, join points. |
| `guide` | Continuity companion — "what's next / where am I / what's ready to ship / what's blocked?" It surfaces and ranks; the human picks. |

**4 subagents** — `spec-author`, `spec-explorer`, `spec-red-team`, `spec-refactor` — ship with a tools allowlist of exactly `Skill`, `Bash`, `Read`. No mutating tools, so every spec change is structurally forced through the skills and hooks, not left to convention.

**Hooks** — a `PreToolUse` hook intercepts `Read`/`Write`/`Edit`/`MultiEdit` on `.mspec`/`.march`/`.mtypes` files and routes them through the mast CLI, so a spec is always parsed, linted, and formatted before it hits disk. A raw `Edit` on a spec is blocked and redirected to the skill. A `SessionStart` probe prints a one-line hint if the binary is missing.

**Skill-reference library** — cited `REF-*.md` files (routing, lifecycle, conventions, governance, theory, idioms) the skills draw on instead of duplicating prose.

**`bin/mast` shim** — the binary isn't vendored. The shim detects your host on first run and downloads the matching prebuilt release, SHA-256 verified and cached.

## Query behavior and architecture as one corpus

mast indexes three layers of your repo — something a markdown-spec tool structurally can't offer. The `.mspec` layer is enough to get first value; `.march` / `.mtypes` are optional and only needed once you want to model architecture.

- **`.mspec`** — feature contracts, one per file, each rule pinned to the file or symbol that satisfies it.
- **`.march`** — architecture: your *domains* (top-level areas, e.g. `billing`), their *components* (named parts, e.g. `RateLimiter`), and the typed connections between them.
- **`.mtypes`** — the edge-type vocabulary those connections may use.

A feature attaches to a component via `attached_to: billing.RateLimiter` (the dotted form is `<domain>.<component>`), so behavior and structure stay linked — and you can query either side:

| Command | What it answers |
|---------|-----------------|
| `mast list scope --file <path>` | The code-to-spec query grep can't do: which specs govern a changed file. |
| `mast list` — `specs`, `rules`, `pending` | Enumerate records in the corpus. |
| `mast list` — `domains`, `components`, `connections`, `edge-types` | The architecture layer: what exists, and how it's wired. |
| `mast graph <id> --edge deps` / `connects` | Walk the dependency graph, or the architecture connection graph. |
| `mast describe` — `inbound`, `status`, `stats`, `attached` | Inbound relationships, graduation eligibility, corpus-wide counts, and which features attach to a component. |
| `mast context render --check` | Regenerate the managed `AGENTS.md` zone; `--check` fails CI on a stale zone. |

Corpus-wide drift and staleness surface at `mast lint check` / CI time — not via a live editor watcher.

## Learn more

This repo contains only the plugin — skills, subagents, hooks, the `REF-*.md` library, and the `bin/mast` shim. The `mast` binary it fetches is the full toolchain: the same linter and query engine the skills lean on, and it can even run an editor LSP (`mast lsp`, for live per-file diagnostics) and the GraphQL/web UI (`mast serve`). That toolchain's Rust source lives upstream, not in this plugin mirror. Run `mast --help` for the full surface.

MIT licensed.
