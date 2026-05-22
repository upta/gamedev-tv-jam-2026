# Decision: Star Map Resize-Aware Rebuild + CanvasLayer Theme Pattern

**Date:** 2026-05-20
**Author:** Builder
**Status:** Implemented

## Context

Three UI issues: (1) star map bottom planets clipped after top bar grew, (2) star map lacked visual depth, (3) welcome overlay didn't use project theme.

## Decisions

### Star Map Deferred Build via `resized` Signal
The star map now connects to `resized` and rebuilds when the Control receives its actual post-layout size. Previously `_build_map()` ran at bind-time before VBoxContainer allocated space, causing the map to use stale dimensions.

### Background Starfield
200 seeded (seed=42) random stars drawn in `_draw()` behind all map content. Alpha range 0.05–0.25 using ThemeBuilder.TEXT. Regenerated on resize.

### CanvasLayer Theme Application
CanvasLayer nodes don't inherit parent themes. Pattern: assign `ThemeBuilder.build_theme()` to a child Control (MarginContainer) in `_ready()`. Font/color overrides applied per-label via script for heading font and accent color.

## Impact
- Star map correctly fills available space regardless of top bar height
- Starfield adds visual depth without distracting from gameplay elements
- Welcome overlay matches the rest of the UI visually
