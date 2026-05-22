# Decision: Programmatic radio icons over asset files

**Context:** Default Godot radio button icons are dark circles, invisible against our dark PopupMenu background (MODAL_SURFACE #121A1A).

**Decision:** Generate radio icons programmatically in `ThemeBuilder._make_radio_icon()` using `Image` + `ImageTexture` rather than shipping SVG/PNG asset files.

**Rationale:**
- Zero external dependencies — no icon files to manage or lose
- Colors stay in sync with the palette constants (MUTED for unchecked ring, ACCENT for filled checked dot)
- Antialiased pixel rendering at 16px produces crisp results
- If the palette changes, icons update automatically

**Alternatives rejected:**
- SVG/PNG assets in `src/assets/icons/`: adds file management overhead, palette drift risk
- Godot icon color modulation: PopupMenu doesn't expose per-icon color modulation for radio items
