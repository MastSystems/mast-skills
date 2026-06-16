# mast for Claude Code

Spec-driven development, built right into Claude Code. This plugin teaches Claude
to read, write, and reason about your project's `.mspec` specifications — and it
brings the `mast` CLI along automatically, so there's nothing else to install.

## Install

In Claude Code:

```
/plugin marketplace add MastSystems/mast-skills
/plugin install mast@mastsystems
```

That's the whole setup. The first time a skill or hook needs `mast`, the right
prebuilt binary for your platform is fetched (SHA-256 verified) and cached — no
separate download, no build step.

## New here? Start with `start`

Run the **`start`** skill and it'll figure out where your project is and walk you
through a first session. Or just talk to Claude — say things like *"what is this
spec corpus?"*, *"mine this repo for specs,"* or *"is this spec ready to ship?"*
and the right skill steps in.

## What you get

- **Skills**
  - `start` — first-time onboarding
  - `orient` — tour and explain a spec corpus
  - `spec` — read, create, and edit specs safely
  - `mine` — extract candidate specs from existing code
  - `check` — verify specs, alignment, and readiness
  - `dag-plan` — plan the implementation order
  - `guide` — which command to reach for, and when
- **Subagents** — `spec-author`, `spec-explorer`, `spec-refactor`, and
  `spec-red-team` for deeper, multi-step work.
- **Hooks** — every `.mspec` read or edit is routed through the CLI, so it's
  parsed, linted, and formatted before it ever lands on disk.
- **The `mast` CLI** — provisioned for you; you never install it by hand.

## Good to know

- **Platforms:** prebuilt binaries cover Linux x86-64, macOS Intel, and macOS
  Apple Silicon. Other hosts (ARM Linux, Alpine/musl, Windows) aren't supported
  yet — the plugin tells you clearly rather than failing silently.
- **Caching:** the binary version is pinned per release. Tune it with
  `MAST_CACHE_DIR`, force a refresh with `MAST_FORCE_REFRESH=1`, or stay offline
  with `MAST_OFFLINE=1`.

## License

MIT.
