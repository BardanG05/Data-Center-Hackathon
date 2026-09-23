# Cairnbridge — Town & Compute

A Godot 4 hackathon prototype about a fictional Irish town balancing digital infrastructure with electricity and water. **This is MVP 0.1: map, placement, one Data Centre and resource accounting.**

## Run

On this Windows workspace, double-click **`Play.cmd`** to play using the portable Godot runtime in the parent `.tools/` folder. It starts a fresh town each time. For development:

1. Open Godot **4.4 or newer**, standard/GDScript edition.
2. Choose **Import**, select this folder's `project.godot`, then **Import & Edit**.
3. Press **F5 / Run Project**.
4. Click an empty buildable plot, then choose the Enterprise Data Centre in the building menu.

The project uses the Compatibility renderer. No add-ons, external assets or online services are required.

## What the first build does

The town starts with homes, businesses, a school, hospital, electricity and water infrastructure, roads and trees. It starts with **no Data Centre**.

| Resource | At launch | After one Data Centre |
| --- | ---: | ---: |
| Money | 1,200 | 400 |
| Electricity usage / capacity | 42 / 90 | 70 / 90 |
| Water usage / capacity | 18 / 50 | 32 / 50 |
| Compute capacity / demand | 0 / 60 | 100 / 60 |
| Population | 1,200 | 1,200 |

All values are **fictional gameplay units**, not measured Irish statistics. Resource totals recalculate every simulation second. The initial compute deficit introduces the reason to build; it has no economic penalty yet. Electricity and water are ongoing loads, not stores that drain each second.

Construction is instant. The starting budget pays for one Data Centre, and there is no income yet. Restart the game to restore the town and budget. Saving, growth, construction timers, shortages' consequences, public acceptance, sustainability scoring, upgrades and events are later milestones.

## Test

With the Godot executable on your PATH, run these commands from this folder:

```powershell
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/smoke_test.gd
```

If the executable is named differently, substitute its name or use `& "C:\path\to\Godot.exe"` in PowerShell. From this folder, the downloaded console executable is `..\.tools\godot\Godot_v4.7.2-stable_win64_console.exe`.

Verified on Godot **4.7.2**: clean project import and **232 automated checks** passed, including viewport clicks, invalid/duplicate purchases, resource changes, scene reset and live ticks. A rendered run adds four screenshot checks. Screenshots are saved under `test-output/` by running the smoke test without `--headless` and appending `-- --capture`. Other Godot versions and web export have not been tested.

Manual checks:

1. Confirm the initial resource values and the existing town, with no Data Centre.
2. Select an empty plot; check that the menu describes its cost and resource effects.
3. Build once; confirm the exact values in the table and a visible Data Centre.
4. Click the occupied plot, roads, trees and outside the map; none should accept a new building.
5. Try another empty plot with only 400 remaining; money and resource totals must stay unchanged.
6. Wait several simulation ticks; totals must remain stable and the running simulation indicator should advance.
7. Resize the window; check tile selection and readable UI. Menu clicks must not accidentally select the map beneath.
8. Click **Restart town**; initial values and the original map must return. Stop and press F5 again to check a fresh launch too.

## Files to change

- `scenes/`: main composition, map, reusable building and UI scenes.
- `scripts/`: orchestration, JSON loading, simulation, placement, map, building visuals and UI.
- `data/buildings.json`: Data Centre cost, loads, capacity and optional sprite.
- `data/scenario.json`: initial town resources and tick interval.
- `data/events.json`, `data/survey.json`, `data/real_world_data.json`: explicitly deferred, empty datasets.
- `tests/smoke_test.gd`: repeatable checks of the first playable slice.
- [Architecture and milestone plan](docs/architecture.md).
- [Data contract and provenance guidance](docs/data-contract.md).

To replace a building's drawn placeholder, add a transparent texture under `assets/buildings/` and set its `sprite_path` to a `res://` path in the building definition. Use a one-tile footprint with ground contact at the image's bottom centre; the building scene handles placement and scaling.

The supplied Excel, Word and PowerPoint files remain untouched. Their contents have not been converted into game facts or survey effects in this milestone.

For a future export, include `*.json` in the export preset's non-resource file filter so the gameplay data ships with the game. Web export also needs matching export templates and a served build; it is not part of this milestone.

**Next: MVP 0.2** adds a short construction timer and simple money income. Completed buildings will contribute resources only when construction finishes. Resource shortages and their consequences follow in 0.3.
