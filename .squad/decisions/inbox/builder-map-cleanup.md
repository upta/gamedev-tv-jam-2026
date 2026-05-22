# Decision: Use z_index for star map rendering order

**By:** Builder  
**Date:** 2025-07-26  
**Status:** Implemented

## Context

Route lines in the star map were using `move_child()` to render behind planet nodes. This was fragile and didn't always work correctly.

## Decision

Use Godot's `z_index` property for rendering order instead of child index manipulation:
- Route Line2D: `z_index = -1`
- LaneLine: `z_index = -2`
- PlanetNode (Area2D): default `z_index = 0`

This is the idiomatic Godot approach and is immune to child insertion order issues.

## Also decided

- System colors should be desaturated to avoid competing with carrier colors. The carrier color palette is the primary visual signal; system colors are secondary grouping only.
