# Godot Prototype Template

A GitHub template for rapid Godot game prototyping with automated validation and an AI development team.

The goal: **humans playtest for fun, not for bugs.** Automated validation catches regressions so you can iterate on game feel instead of QA.

## What's Included

- **Godot project scaffold** (`src/`) — ready-to-run with test-mode routing baked in
- **[Agentic Godot Validation Kit](https://github.com/upta/agentic-godot-validation)** — automated gameplay validation via scenario contracts (git submodule)
- **[Squad](https://github.com/bradygaster/squad) AI team** — three pre-configured agents (Lead, Builder, Validator)
- **Setup scripts** — cross-platform symlink management for the submodule

## Quick Start

### 1. Create from template

Click **"Use this template"** on GitHub, then clone your new repo:

```bash
git clone --recursive https://github.com/YOUR_USER/YOUR_REPO.git
cd YOUR_REPO
```

If you already cloned without `--recursive`:

```bash
git submodule update --init --recursive
```

### 2. Set up symlinks

**Windows (PowerShell):**
```powershell
.\setup.ps1
```

**Linux/macOS:**
```bash
chmod +x setup.sh && ./setup.sh
```

This creates symlinks from the submodule into the Godot project (`src/addons/`, `tools/`, `.github/skills/`).

### 3. Open in Godot

Open `src/project.godot` in Godot 4.x. The placeholder game scene should load.

### 4. Run validation

```powershell
.\tools\run_scenario.ps1 -Scenario src\validation\scenarios\your_scenario.json -GodotExe "path\to\godot"
```

## Project Structure

```
├── submodules/
│   └── agentic_godot_validation/   ← git submodule (validation kit)
├── src/                            ← Godot project root
│   ├── project.godot
│   ├── bootstrap/                  ← app entry (test-mode routing)
│   ├── game/                       ← your game scenes and scripts
│   ├── addons/
│   │   └── agentic_godot_validation/  ← symlink → submodule
│   └── validation/
│       ├── harnesses/              ← test harness scenes
│       ├── scenarios/              ← scenario JSON contracts
│       └── scripts/
│           └── harness_controllers/ ← state exposure scripts
├── tools/                          ← symlink → submodule runner scripts
├── .squad/                         ← AI team configuration
├── setup.ps1 / setup.sh           ← symlink setup
└── symlink-config.txt             ← declarative symlink mapping
```

## The Squad Team

| Agent | Role | Owns |
|-------|------|------|
| **Lead** | Architect | Vision, system design, delegation |
| **Builder** | Core Dev | Gameplay code, scenes, GDScript |
| **Validator** | Quality | Scenarios, harnesses, test runs |

The Validator agent knows how to use the validation kit's Copilot skills (`author-validation-scenario`, `debug-validation-failure`) to write and debug scenario contracts.

## How Validation Works

1. **Builder** creates game scenes with observable state
2. **Validator** writes scenario contracts (JSON) that simulate input and assert outcomes
3. Scenarios run headlessly via CLI — no human interaction needed
4. Artifacts (screenshots, event logs, scene trees) are produced for debugging

See the [validation kit docs](https://github.com/upta/agentic-godot-validation) for the full scenario contract reference.

## Updating the Validation Kit

```bash
cd submodules/agentic_godot_validation
git pull origin main
cd ../..
git add submodules/agentic_godot_validation
git commit -m "chore: update validation kit submodule"
```
