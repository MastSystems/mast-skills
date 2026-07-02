# REF-CONVENTIONS

> Shared reference section. Project-wide authoring conventions, cited via
> `Reference:`. Single home for fragment A13 (no-emoji), C10 (plugin manifest
> invariants), C13 (`archetype:` header literals), and the shared
> `--no-verify`/no-push/no-amend MUST-NOT block. Generic and project-wide — kept
> implementation-agnostic so any skill or agent can cite it; the `start` skill
> cites only the no-emoji convention.

## No emoji (A13)

**Do not use emoji** in any mast skill output, spec content, or commit message. This
is a project convention and applies everywhere.

## Plugin manifest invariants (C10)

The mast skills, hooks, and subagents ship as a Claude Code plugin. The manifest
invariants:

- **Version lockstep.** `plugin.json` and `Cargo.toml` carry the same version —
  they move together; a release bumps both.
- **Single marketplace entry.** The marketplace exposes exactly one entry for the
  mast plugin (no duplicate or per-skill entries).
- **Install flow:**

  ```
  /plugin marketplace add mastsystems/mast-skills
  /plugin install mast@mastsystems
  ```

- **Namespaced invocation.** Installed skills are invoked namespaced as
  `/mast:<skill>` (e.g. `/mast:spec`, `/mast:check`).

## `archetype:` custom-header values (C13)

The `archetype:` custom header takes one of exactly two values:

- `component`
- `process`

## Shared MUST-NOT block (version control / hooks)

These prohibitions are project-wide and apply to every skill and agent that
touches git or the hook layer:

- **Never skip hooks (`--no-verify`).** Do not pass `--no-verify` to any git
  command — hooks are non-negotiable.
- **Never push; only the human pushes.** Skills and agents stage and commit; the
  human owns `git push` to remote.
- **Never amend a pushed commit or rewrite history.** No `git commit --amend` on
  pushed work, no rebases or force-pushes that rewrite published history.
