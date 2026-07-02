# mast

**Code review tells you what changed. mast tells you what was supposed to change.**

mast is a spec language and toolchain: your team's intended behavior lives in the repo as spec files that a real binary parses, lints, formats, and cross-links — and the bundled Claude Code skills make AI agents first-class readers and writers of that corpus. An agent forgets everything between sessions; a spec pinned next to the code doesn't. When code and contract drift apart, CI fails by name instead of a reviewer noticing three weeks later.

- **Vagueness doesn't compile.** Hedge words — *probably*, *roughly*, *should*, *some* — are hard errors in rule text. A spec that can't commit never lands on disk.
- **Drift is caught, not discovered.** Rules pin to real file paths, and rule-to-rule citations are content-pinned in a lockfile. Move the file and `mast lint check` fails, naming the spec; change the cited text and the pin flags the drifted rule — `mast lint check --strict` makes that a failing build too.
- **Agents write specs through the same gate you do.** Every spec read and write is routed through the binary: parse → lint → canonical format, or nothing hits disk.

If your team ships with AI agents and has ever asked "wait, was it *supposed* to do that?" — that is the gap mast closes.

## Installation

In Claude Code:

```
/plugin marketplace add MastSystems/mast-skills
/plugin install mast@mastsystems
```

The first time a skill needs the `mast` binary, the right prebuilt for your host (Linux x86-64, macOS Intel, macOS Apple Silicon) is downloaded, SHA-256 verified, and cached. Other hosts fall back to a local `cargo` build.

## First five minutes

1. **Install** (above), then open your repo in Claude Code.
2. **`mast doctor`** reports where the repo stands and the single next command. Or just say "get me started with mast" (`/mast:start`).
3. **Get a corpus.** Existing code: "mine this codebase for specs" (`/mast:mine`) drafts specs, architecture, and vocabulary from the code as it actually is — as reviewable proposals, never silent writes. Greenfield: "create a spec for `<feature>`" (`/mast:spec`).
4. **Gate it.** `mast lint check` validates the whole corpus. Put it in CI and drift becomes a failing build.

A complete worked example — a small double-entry ledger with its full spec corpus — ships in [`examples/ledger`](https://github.com/MastSystems/mast-skills/tree/main/examples/ledger).

## The skills

Talk to Claude normally; skills trigger on intent, or explicitly as `/mast:<name>`.

| Skill | What it's for |
|-------|---------------|
| `start` | First-session onboarding: detects project state and routes you. |
| `mine` | Draft a spec corpus from an existing codebase. |
| `spec` | The only path to spec content: read, create, or patch — always lint-gated. |
| `orient` | Tour the corpus; answer "which spec governs this file?" |
| `dag-plan` | Turn a spec into a phased implementation plan with parallel lanes. |
| `check` | Pre-push verification, CI-failure diagnosis, corpus health audit. |
| `guide` | What's next, what's ready to ship, what's blocked. |

## What a spec is

One `.mspec` file per feature. One rule per paragraph. Every active rule pinned to the code that satisfies it, and every rule carrying a checkable lifecycle (`pending → active → amended → retired`). Optional `.march` and `.mtypes` files add your architecture — domains, components, typed connections — and its vocabulary to the same corpus, so "which specs does this diff affect?" is one command (`mast list scope --file <path>`), not a grep.

Everything the plugin does goes through the `mast` binary. Run `mast --help` for the full query surface.

MIT licensed.
