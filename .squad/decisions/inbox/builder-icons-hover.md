# Decision: Icon System & Hover Panel Redesign

**Author:** Builder
**Date:** 2026-05-25

## Context

UI used text labels "Pax", "Cargo", "Fuel" everywhere. Planet hover tooltip was an unstructured text blob.

## Decisions

1. **Tabler Icons via SVG** — Downloaded 3 Tabler Icons (users, package, gas-station) as SVGs with `stroke="#E6F5F0"` to match ThemeBuilder.TEXT. Stored in `src/assets/icons/`.

2. **BBCode `[img]` for inline icons** — Rather than HBoxContainer+TextureRect compositions, used RichTextLabel with BBCode `[img=14x14]` tags for most icon placements. This keeps layout simple and allows mixing icons with formatted text. ThemeBuilder provides `pax_bb()`, `cargo_bb()`, `fuel_bb()` helpers.

3. **`use_bbcode` flag pattern** — For the create_route_modal's generic selection list (which renders both plain-text and icon-rich items), added an opt-in `use_bbcode` flag on item dictionaries rather than converting all items to BBCode.

4. **Hover panel structured layout** — Used BBCode formatting (bold, color, separator lines) to create a visually structured tooltip. Planet name as bold header, system name in MUTED, stats with accent-colored "yours" values, demand line with pax/cargo icons.

## Impact

- All 8 UI files updated to use icons instead of text labels
- ThemeBuilder gains icon constants, BBCode helpers, and `make_icon_label()` factory
- No behavioral changes — UI-only
