# read-journal — design

A planned feature: expose the append-only journal for read-back. The store
method `EntryStore.forTransfer` already exists (the mining flagged it as latent
capability with no HTTP surface); this feature would put an endpoint in front of
it.

## Read path

A `GET /transfers/:id/journal` route on the `api` handler calls
`EntryStore.forTransfer(transferId)` and returns the two entries recorded for
that transfer. No write path is involved — the journal is append-only and this
feature never mutates it.

This anchor is a Design anchor: it deliberately blocks graduation. The spec
stays `[pending]` until the endpoint is built and the rule's Design anchor is
swapped for a Code anchor pointing at the route handler.
