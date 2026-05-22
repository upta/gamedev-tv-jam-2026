# Decision: OptionButton/PopupMenu/SpinBox Theme Styling

**Date:** 2026-05-20
**Author:** Builder
**Status:** Implemented

## Decision
Style OptionButton and PopupMenu dropdown via ThemeBuilder to match the sci-fi HUD theme. Style SpinBox by theming its underlying LineEdit and Button components.

## Rationale
- OptionButton reuses the same styleboxes as Button for visual consistency across all interactive controls.
- PopupMenu gets its own panel (MODAL_SURFACE + BORDER) and hover (ACCENT-tinted) styles since it's a floating overlay, not an inline control.
- SpinBox doesn't have its own theme type in Godot — it internally wraps LineEdit (text field) and Button (arrows). Styling those two theme types covers SpinBox completely with no extra code.

## Impact
All OptionButtons and SpinBoxes in the game now inherit the sci-fi theme automatically. No per-instance overrides needed.
