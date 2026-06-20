# read-journal — plan

## Milestones

1. Add a `GET /transfers/:id/journal` route to `src/http/api.ts`.
2. Wire it to `EntryStore.forTransfer` (already implemented).
3. Return an empty list (not a 404) for an unknown transferId.
4. Swap the Design/Plan anchors on `read-journal` for Code anchors and graduate
   the spec to `active`.
