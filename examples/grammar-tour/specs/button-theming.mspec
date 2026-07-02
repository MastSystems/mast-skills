spec: button-theming
title: Theme-aware button rendering (amended)
status: amended
version: 1

Targets
  $readme @file=README.md

Rule R1.theme-driven-colors [amended $readme]
  Given a button renders under a named theme
  Then its colors resolve from that theme's design tokens
    MUST themed: a button MUST take its palette from the active theme, not a hard-coded default
