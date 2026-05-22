# Decision: Centralized Carrier Colors

**By:** Builder
**Date:** 2026-05-22

## Context
Carrier colors were duplicated in `star_map.gd` and `planet_node.gd` with divergent values. `scoreboard_panel.gd` used ACCENT/TEXT/MUTED instead of carrier-specific colors.

## Decision
- Single source of truth: `ThemeBuilder.CARRIER_COLORS` dictionary constant.
- Colors chosen to fit the dark sci-fi palette: player=ACCENT teal-green, NPC1=muted coral `(0.85, 0.45, 0.42)`, NPC2=soft lavender-blue `(0.55, 0.65, 0.90)`, NPC3=warm amber `(0.90, 0.72, 0.35)`.
- All consumers (`star_map.gd`, `planet_node.gd`, `scoreboard_panel.gd`) reference `ThemeBuilder.CARRIER_COLORS`.
- Scoreboard rows now show each carrier in its identity color (indicator dot + name label).

## Rationale
- Eliminates color drift between map elements and UI panels.
- Desaturated palette feels cohesive with existing theme constants.
- Adding a new carrier only requires updating one dictionary.
