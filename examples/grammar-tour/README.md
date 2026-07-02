# grammar-tour — a synthetic grammar showcase

This corpus is intentionally **not** mined from a real codebase. It exists to
host the small set of live grammar productions that do not fit the faithful
worked example in [`examples/ledger/`](../ledger/):

- **component `extends`** in a `.march` file (`ui-kit.march`)
- **`status: retired`** at the spec level (`legacy-button-rendering.mspec`)
- **`status: amended`** at the spec level, with an `[amended $anchor]` rule
  chip (`button-theming.mspec`)
- **two constitutions governing one domain** — `style-governance.mspec` and
  `a11y-governance.mspec`, each with a `Tiers` block, and `ui-kit.march`
  carrying two `Compliance` blocks (one `certified: R1`, one `pending: R1`)
- **a `note:`-proved edge carrying a `!debt` annotation** with a `reason:`
  continuation (`ui-kit.march`), typed by the `Renders` edge-type declared in
  `tokens.mtypes`

Use `examples/ledger` when you want a mined, code-backed walkthrough. Use this
corpus when you want the remaining grammar constructs in a tiny, lint-clean
fixture (`mast lint ci examples/grammar-tour` passes clean; it is its own mast
project via the local `mast.toml`).
