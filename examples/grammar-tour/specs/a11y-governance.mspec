spec: a11y-governance
title: Accessibility governance: interaction rules for the UI kit
status: active
version: 1
kind: constitution

Targets
  $readme @file=README.md

Tiers
  baseline: R1

Rule R1.keyboard-operable [active $readme]
  Given any interactive widget in the UI kit
  Then it is fully operable from the keyboard alone
    MUST keyboard: an interactive widget MUST expose focus and activation without a pointer
