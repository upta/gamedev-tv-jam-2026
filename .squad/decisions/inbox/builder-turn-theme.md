# Decision: ThemeBuilder pattern for CanvasLayer overlays

**Date:** 2026-05-24
**By:** Builder

## Context
CanvasLayer nodes (layer 100+) don't inherit the parent scene's theme. Both WelcomeOverlay and TurnPresentationOverlay need explicit theme application.

## Decision
Standardized the pattern: in `_ready()`, set `ThemeBuilder.build_theme()` on the MarginContainer child of the Overlay ColorRect, then apply per-node overrides (title font/color, hint colors, accent button styling). Background color uses SURFACE RGB with custom alpha as a literal in the `.tscn` file.

## Implications
- Any future CanvasLayer-based overlay (game over screen, pause menu, etc.) should follow this same pattern.
- Consider extracting a helper method if more overlays are added (e.g., `ThemeBuilder.apply_to_overlay(overlay_rect)`).
