# REF-DEPENDENCIES

Shared doctrine: the three cross-spec dependency kinds. Cited by any skill that
explains or traverses spec-to-spec relationships (`start`, `orient`, `spec`, …).
Added post-pilot (the `start` pilot surfaced that this triad had no reference
home and would otherwise re-bleed across skills).

A spec relates to other specs three ways:

- **`Depends on <id> >= <v>`** — "this spec assumes that spec is satisfied." A
  version constraint (`>= N`) may be attached. A spec is *blocked-by* any
  `Depends on` target whose status is not `active` (see `mast spec read <id>
  --with-blocked-by`).
- **`extends <id> >= <v>`** — inheritance from a parent spec (a single-parent
  supertype chain). The child inherits the parent's vocabulary/obligations.
- **`Cites <spec>.R<n>` (or `.I<n>`)** — a rule-level, content-pinned reference
  placed under a rule header. The lockfile (`specs/mast.lock`) pins the cited
  entry with a blake3 content-hash, so silent drift in the upstream rule surfaces
  as a linker diagnostic and a non-`fresh` row in `mast cite list`. After editing
  a cited rule body, re-pin with `mast cite ack`.

Traversal: `mast graph <id> --edge deps|extends|cites [--direction in|out]`.
