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

## Key Conventions

- The app root routes between the game and the validation test bootstrap via `--test-mode` CLI flag
- Validation scenarios are JSON contracts in `src/validation/scenarios/`
- Harness scenes live in `src/validation/harnesses/` with controllers in `src/validation/scripts/harness_controllers/`
- Run scenarios with `./tools/run_scenario.ps1 -Scenario src/validation/scenarios/<name>.json -GodotExe <path>`
- Do not modify files under `src/addons/agentic_godot_validation/` — changes belong in the submodule repo

## Validation-First Policy

- **Every gameplay code change MUST include validation scenarios.** No exceptions. If a change affects player-visible behavior, it needs a scenario proving it works.
- Humans play-test for fun, feel, and game design feedback — never for QA or bug detection. Automated validation catches bugs.
- If a bug is found during play-testing that should have been caught by validation, add the missing scenario as part of the fix.
- If the validation framework doesn't support a needed assertion, improve the framework first.

## Definition of Done

A feature is not done until a human can play-test it for game feel — not for whether it works. "It works" is the agent's job to prove before any human touches the game. Specifically:

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
