# Decision: Centralized UI Theme System

**Date:** 2026-05-20  
**Author:** Builder  
**Status:** Implemented

## Context

Game jam polish pass. UI needed visual cohesion — consistent colors, typography, and spacing across all controls. Godot 4's Theme system can be applied globally, but managing colors and styles across scenes is error-prone without centralization.

## Decision

Created `ThemeBuilder` static utility class to own the design system:

1. **Color Palette as Constants:** All colors defined once (SURFACE, BORDER, TEXT, ACCENT, POSITIVE, NEGATIVE, WARNING, etc.) and exposed as public constants. Any script can reference `ThemeBuilder.ACCENT` for consistency.

2. **Programmatic Theme Generation:** `build_theme()` creates a Theme resource at runtime with styles for all core controls (Button, PanelContainer, ScrollBar, etc.). Applied in `main.gd` before any scene setup.

3. **Font Management:** Inter (body/data) and Space Grotesk (headings) downloaded from official GitHub repos. Inter set as `project.godot` default font. Fonts loaded via `res://` paths in ThemeBuilder.

4. **Icons via Tabler Icons:** Downloaded 5 MIT-licensed SVGs for toolbar buttons. Loaded as Texture2D in `top_bar.gd` and assigned to Button.icon property.

5. **Background Clear Color:** Set in `project.godot` rendering settings (#14161C) for dark space aesthetic.

## Rationale

- **Game jam speed:** Programmatic theme is faster than hand-editing .tres files in the Godot editor. One source of truth for all colors.
- **Maintainability:** Changing ACCENT color updates all buttons/links instantly. No hunting through scene overrides.
- **Harness compatibility:** Theme application happens in `_ready()` before validation harnesses bind — no impact on existing scenarios.

## Alternatives Considered

- **Manual .tres Theme resource:** Slower to iterate, harder to version control (binary conflicts).
- **Inline StyleBox creation per widget:** DRY violation, no single source of truth.

## Implementation Notes

- `main.gd` applies theme: `theme = ThemeBuilder.build_theme()`
- `star_map.gd` hover panel now uses `ThemeBuilder.SURFACE` and `ThemeBuilder.BORDER`
- `top_bar.gd` toolbar buttons load icons from `res://assets/icons/`
- Godot SVG import works out-of-box — icons render correctly as Texture2D

## Verification

- Headless launch test passed (no script errors)
- All existing validation scenarios pass (theme application is pre-bind, no conflicts)
- Visual inspection via play-test confirms consistent styling

---

**Tags:** #ui #theme #polish #game-jam
