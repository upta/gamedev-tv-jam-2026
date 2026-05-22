# Decision: Unicode Icon Glyphs & Card-Based Ship Selection

**Date:** 2026-05-18
**Author:** Builder
**Status:** Implemented

## D-ICON: Unicode Glyphs Replace SVG BBCode

**Decision:** Replace `[img=WxH]res://path.svg[/img]` BBCode with colored Unicode glyphs for inline icons: `●` (pax/#6bedc4), `◼` (cargo/#e8c56d), `◆` (fuel/#73948c).

**Rationale:** SVG `[img]` tags render as broken rectangles in RichTextLabel. In-memory textures can't be referenced in BBCode strings. Unicode geometric shapes are universally supported by Inter/SpaceGrotesk fonts and render reliably.

**Impact:** `pax_bb()`, `cargo_bb()`, `fuel_bb()` return BBCode text strings. All existing call sites work unchanged. `load_icon_texture()` added for TextureRect usage (loads SVG, resizes, returns ImageTexture).

## D-SHIPCARD: Two-Step Card-Based Order Ship Modal

**Decision:** OrderShipModal uses a two-step flow: Step 0 shows all available ship types as browsable cards, Step 1 shows customization (capacity split, quantity, order).

**Rationale:** Dropdown + stats line was hard to compare ships. Card layout shows all stats at a glance for every ship type simultaneously.

**Impact:** Removed OptionButton. Programmatic API preserved — `select_type(index)` triggers step transition internally.
