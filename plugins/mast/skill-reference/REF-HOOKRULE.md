# REF-HOOKRULE

> Shared reference section. The `/mast:spec` hook-block hard rule, cited via
> `Reference:`. Single home for fragment A12. The verbatim hook redirect messages
> themselves (C1) live in their generated-asset source of truth (`cli/src/hook.rs`)
> and are byte-parity-checked there; this section states the rule the messages
> enforce.

## The hook-block hard rule (A12)

Direct `.mspec` access is **blocked by a PreToolUse hook** when the mast workflow
is active. Specifically:

- Direct `Read` of a `.mspec` file is blocked.
- Direct `Write` / `Edit` of a `.mspec` file is blocked.
- This includes **staged copies** under `/tmp/*.mspec` — moving the file does not
  evade the block.

**Always route through the CLI** (surfaced by the `/mast:spec` skill):

- `mast spec read <id>` instead of `Read` — so inbound relationships are surfaced.
- `mast spec write` / `mast spec patch` instead of `Write` / `Edit` — so content is
  parsed, linted, and canonically formatted before touching disk.

The hook **fails open at the plugin layer** (a malformed payload or an absent binary
does not block the user) but **fails closed in the worker** (a `.mspec` path that
reaches the worker is blocked). A `SessionStart` hint surfaces when mast is absent or
the corpus has skewed (C2).
