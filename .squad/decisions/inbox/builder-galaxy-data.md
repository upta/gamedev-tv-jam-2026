# Decision: Inner Classes for Galaxy Data Structures

**Author:** Builder  
**Date:** 2026-05-17  
**Scope:** P1.1 Galaxy Data  
**File:** `src/game/state/galaxy_data.gd`

## Decision
Use inner classes (`Planet`, `Lane`) inside `GalaxyData` rather than separate Resource subclasses in their own files.

## Rationale
- Planet and Lane are pure data containers with no behavior beyond storage
- They are never used independently of GalaxyData — always accessed through it
- Single-file approach keeps the topology definition self-contained and easy to read
- If these grow complex enough to need their own files later, extraction is trivial

## Trade-offs
- **Pro:** One file to understand the entire galaxy topology
- **Pro:** No file proliferation for simple data classes
- **Con:** Inner classes can't be directly referenced as export types in the Godot editor (not needed — this is code-only data)
- **Con:** If Planet/Lane grow significant behavior, they should be extracted

## Status
Accepted — revisit if data structures gain complex behavior.
