# Copilot Instructions

This is a Godot game prototype using the [agentic-godot-validation](https://github.com/upta/agentic-godot-validation) kit for automated gameplay validation.

## Project Structure

- `src/` — the Godot project root (`project.godot` lives here)
- `src/game/` — gameplay scenes and scripts
- `src/bootstrap/` — app entry point with test-mode routing
- `src/validation/` — harnesses, scenarios, and harness controllers
- `src/addons/agentic_godot_validation/` — symlinked validation runtime (do not edit directly)
- `submodules/agentic_godot_validation/` — git submodule source
- `tools/` — symlinked validation runner scripts

## Protected Files

- **`DESIGN.md`** — The game design document. **Never delete, overwrite, or move this file.** It is the single source of truth for what the game is. Edits are allowed only when the user explicitly requests design changes. If `DESIGN.md` is missing, stop and alert the user immediately — do not proceed with implementation work without it.
- **`CONTEXT.md`** — Domain language glossary. Same protections apply.

## Key Conventions

- The app root routes between the game and the validation test bootstrap via `--test-mode` CLI flag
- Validation scenarios are JSON contracts in `src/validation/scenarios/`
- Harness scenes live in `src/validation/harnesses/` with controllers in `src/validation/scripts/harness_controllers/`
- Run scenarios with `./tools/run_scenario.ps1 -Scenario src/validation/scenarios/<name>.json -ProjectPath src -GodotExe <path>`
- Run the full suite with `./tools/run_all_scenarios.ps1 -ScenarioDir src/validation/scenarios -ProjectPath src -GodotExe <path>`
- **CRITICAL**: Always pass `-ProjectPath src` to the validation runner scripts. The `tools/` directory is a junction to the submodule, so the script's default project path resolves to the repo root (which has no `project.godot`). Without `-ProjectPath src`, Godot opens the project selector and produces no artifacts.
- Run GUT unit tests with `godot --headless --path src -s addons/gut/gut_cmdln.gd -gexit`
- Do not modify files under `src/addons/agentic_godot_validation/` — changes belong in the submodule repo
- Do not modify files under `src/addons/gut/` — managed by GUT upstream

## Validation-First Policy

- **Every gameplay code change MUST include validation scenarios.** No exceptions. If a change affects player-visible behavior, it needs a scenario proving it works.
- Humans play-test for fun, feel, and game design feedback — never for QA or bug detection. Automated validation catches bugs.
- If a bug is found during play-testing that should have been caught by validation, add the missing scenario as part of the fix.
- If the validation framework doesn't support a needed assertion, improve the framework first.

## Definition of Done

A feature is not done until a human can play-test it for game feel — not for whether it works. "It works" is the agent's job to prove before any human touches the game. Specifically:

0. **Godot launches without script errors.** GDScript is not compiled, so the smoke test is: `godot --headless --path src --quit` exits cleanly with no errors in the console. Run this after every code change that touches `.gd` files. Common failure mode: circular `class_name` dependencies between scripts (use `load()` to defer cross-references when needed).
1. **Validation scenarios exist** for the change — covering the intended behavior, not just the happy path.
2. **New scenarios pass.** Writing a scenario is not enough. Run it and confirm green.
3. **All existing scenarios still pass.** Run the full suite (`run_all_scenarios.ps1`) and confirm no regressions. If something broke, fix it before calling the work done.
4. **`git push origin`** at the end of every work batch.

If any of these are missing, the feature is not done. A human should never encounter a bug that automated validation could have caught.

## Validation Asset Rules

- Expose semantic game state through harness controllers using `get_observed_state()`
- Prefer `nodes`, `metrics`, and `signals` under `harness_state`
- Prefer `assert_value` and `assert_pipeline` over custom scenario operations
- Keep harnesses deterministic and minimal

## GDScript Conventions

- **Avoid circular `class_name` dependencies.** If script A uses class B as a type annotation and script B uses class A, Godot will fail to parse at startup. Break cycles by removing the type annotation on one side and using `load("res://path/to/script.gd")` for runtime access instead of the global class name.
- **Prefer inner classes for tightly-coupled data types** (e.g., `CarrierData.Route`, `TurnPipeline.CarrierIntent`). Access from other scripts via the parent class name.
- **Static utility classes** extend `RefCounted` with all `static func` methods and no instance state.
- **Use typed arrays** (`Array[String]`, `Array[CarrierData]`) for collections where the element type is known.
- **Use `carrier_name` instead of `name`** on CarrierData to avoid shadowing `Object.name`.
