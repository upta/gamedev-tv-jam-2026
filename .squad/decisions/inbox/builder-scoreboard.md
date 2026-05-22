# Decision: Scoreboard Panel as Star Map Overlay

**By:** Builder
**Date:** 2026-05-22

## Context

The top bar had Rank and Events labels that cluttered the header. Brian requested a standalone scoreboard panel overlaid on the star map instead.

## Decision

- ScoreboardPanel is a child of the StarMap node in main.tscn (not a direct child of GameScene or the top bar)
- Built programmatically in GDScript (no complex scene tree)
- Uses `mouse_filter = IGNORE` so star map interactions pass through
- Positioned with absolute offsets (16px from top-left of star map area)

## Rationale

Placing it as a StarMap child means it naturally clips to the star map area and moves with it. Mouse filter ignore ensures planet clicks still work. Programmatic build avoids coupling to scene tree node names.
