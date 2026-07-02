spec: style-governance
title: Style governance: visual consistency rules for the UI kit
status: active
version: 1
kind: constitution

Targets
  $readme @file=README.md

Tiers
  baseline: R1

Rule R1.tokens-only-styling [active $readme]
  Given any widget in the UI kit renders
  Then its colors and spacing come from the shared design tokens
    MUST tokens_only: a widget MUST NOT hard-code a color or spacing value outside the token set
