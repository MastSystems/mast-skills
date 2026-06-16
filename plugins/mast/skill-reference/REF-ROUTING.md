# REF-ROUTING

> Shared reference section. The cross-skill routing table and the bypass-gate,
> cited via `Reference:`. Single home for fragment A11. Every v2 skill's "When NOT
> to use" section cites this section instead of restating the routing rules.

## Cross-skill routing table (A11)

Each intent routes to exactly one skill. When a request does not match the skill
currently active, hand off to the one below.

| The user wants to… | Route to |
|--------------------|----------|
| Get started, onboard, learn what mast is for the first time | `/mast:start` |
| Tour the corpus, walk through architecture, understand the model, reverse-lookup a file → its spec, ask conceptual questions | `/mast:orient` |
| Read, create, rewrite, or patch a `.mspec` / `.march` / `.mtypes` file | `/mast:spec` |
| Verify before pushing, fix CI, audit corpus health, pre-flight a plan | `/mast:check` |
| Draft a corpus from existing code (one-time extraction) | `/mast:mine` |
| Plan or execute a complex multi-phase implementation against specs (dependency ordering, TDD phases, graduation) | `/mast:dag-plan` |

## The bypass-gate (A11)

If a request already contains **a concrete spec ID, a rule number (`R<n>`), or a
specific CLI command**, the user is past onboarding. **Skip onboarding and route
directly** to the skill that serves that operation — do not start a tutorial.
