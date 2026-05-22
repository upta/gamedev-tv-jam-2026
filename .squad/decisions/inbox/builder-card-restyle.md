# Decision: Icon Strategy — SVG [img] BBCode + Programmatic Fallback

**Date:** 2026-05-18
**Author:** Builder
**Status:** Implemented

## Context

The previous session replaced all SVG `[img]` BBCode with Unicode glyphs after observing rendering failures. Brian reported the SVG icons were actually working everywhere except the hover panel.

## Decision

- **Default:** Use `[img=NxN]res://path.svg[/img]` BBCode for inline icons (via `icon_bb()`). This works in all standard RichTextLabels.
- **Fallback:** For specific RichTextLabels where `[img]` fails (currently only the star map hover panel), use the programmatic API (`add_image()` with pre-loaded `ImageTexture`).
- **Ship cards:** Use plain `Label` nodes with `GridContainer` for tabular stats. "Capacity" is generic (no icon) since it covers both pax and cargo pre-split.

## Rationale

One broken panel doesn't justify changing the icon strategy for the entire app. Fix the broken panel specifically, keep the simpler BBCode approach everywhere else.
