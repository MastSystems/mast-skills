# REF-LIFECYCLE

> Shared reference section. The spec/rule lifecycle, the anchor ratchet, and the
> AnchorKind taxonomy, cited via `Reference:`. Single home for fragments A5
> (lifecycle + ratchet) and A2 (AnchorKind taxonomy). The exact-filename literals
> are a separately-pinned verbatim block (C11) at the bottom so drift hash-checks.

## Lifecycle (A5)

Spec status progresses through a fixed order:

```
draft  →  pending  →  active  →  retired
```

- **draft** — design stage.
- **pending** — implementing.
- **active** — shipped. CI gates only fully enforce **active** specs.
- **retired** — superseded.

Rules within a spec carry their own status chips (e.g. `[pending]`, `[active]`),
independent of the spec's overall status. The lifecycle tells the toolchain what to
enforce.

## The anchor ratchet (A5)

An **anchor** ties a rule to evidence — either a design document or real source
code — and the path's suffix decides the anchor kind. The ratchet is the required
order of work:

1. **Design-doc-first.** When a feature's code does not exist yet, the first
   artifact is a design document, not code. Write `docs/<feature>-design.md` and
   link it from the spec's top-level `design:` header
   (`design: docs/<feature>-design.md`). The linter checks the design doc exists.
2. **Implement the code.**
3. **Declare a `$symbol`** in the spec's `Targets` block pointing at real source
   (e.g. `login/src/token.rs#mint`), and carry it in the rule chip
   (`Rule R1.session-token [active $token]`).
4. **Graduate** the rule to `[active]`.

**The block:** a **design anchor** (or a `*-plan.md` plan anchor) *blocks
graduation*. A rule cannot reach `[active]` while any design or plan anchor remains
— the toolchain forces you to point at real code first. An `[active]` rule requires
at least one **code anchor**.

**On `[pending]` rules:** Design and Plan anchors are **valid on `[pending]` rules** (an
**info** finding, not a warning or error) and are **validated for existence** — the
linter checks the anchored `*-design.md` / `*-plan.md` file actually exists, not
merely that the `design:` / `plan:` header is present. So a `[pending]` rule carrying a
design anchor is healthy, but a dangling design anchor (pointing at a missing file)
is still flagged. **The anchor lives in the `Targets`/`References` block; the
`[pending]` rule's chip stays bare** — referencing any `$`-anchor from a `[pending]`
chip is rejected (`rule status [pending] must not have code anchors`). Graduation
adds the code-anchor `$name` to the chip (`[active $code]`) and drops the `design:`
header.

## Design→Active supersession (A5)

The lifecycle is a **progression**, and it is teachable as one: design/plan docs
inform early drafting, so a **Pending/Draft** spec is *expected* to carry Design/Plan
anchors and `design:`/`plan:` headers — that is healthy. The spec graduates to
**Active** once those design-phase artifacts are **superseded** by non-blocking
anchors (Code/Context/Skill/Doc). `graduate()` rejects any spec still carrying a
blocking anchor. After graduation the inverse holds: an Active spec that still
carries a Design/Plan anchor emits `DesignAnchorOnActiveRule` (**error**), and one
still carrying a stale `design:`/`plan:` header emits a stale-design **warning** —
the design-phase artifacts should have been archived or removed.

## AnchorKind taxonomy (A2)

An anchor's kind is decided by what its `@file=` path points at. There are **six
variants**:

| AnchorKind | Points at | Blocks graduation? |
|------------|-----------|--------------------|
| **Code**    | real source — any **non-doc extension** (optional `#symbol`/`:method` fragment) | no |
| **Design**  | a `*-design.md` document       | **yes** |
| **Plan**    | a `*-plan.md` document         | **yes** |
| **Context** | an agent-context file (see literals below) | no |
| **Skill**   | a `SKILL.md`                   | no |
| **Doc**     | other **`.md` / `.txt`** files | no |

Only **Design** and **Plan** anchors block graduation
(`blocks_graduation()` is true for exactly those two). Attempting to graduate a rule
that still carries a Design anchor raises `GraduateError::DesignDocAnchors`.

**No `.md` is ever a parse error** — every path classifies into exactly one of the
six variants. Downstream consumers **pattern-match on the variant — they never
inspect path strings**; the classification happens once, at parse time, and the
variant is the only thing the rest of the toolchain reads.

## Exact-filename literals (C11) — PRESERVE VERBATIM

> The following filename literals are machine-coupled (the AnchorKind classifier
> matches on them). They are pinned here separately from the A2 prose so any drift
> is a hash mismatch. **Do not paraphrase, re-case, or abbreviate these.** Source of
> truth: the AnchorKind classifier. `preserve-verbatim`.

- **Context** anchors match these exact filenames:
  - `AGENTS.md`
  - `CLAUDE.md`
  - `copilot-instructions.md`
  - `.cursorrules`
- **Skill** anchors match this exact filename:
  - `SKILL.md`
- **Design** / **Plan** anchors match these suffixes (case-sensitive, lowercase):
  - `*-design.md`
  - `*-plan.md`
