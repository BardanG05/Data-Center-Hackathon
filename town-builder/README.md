# Bournemouth: Compute & Community

A Godot 4 hackathon game: **Ireland's data-centre decade, replayed on Bournemouth.** From 2015 to 2034 the town's demand for compute grows along Ireland's real data-centre electricity curve (about 9.5× in total). You build data centres to meet it, but every centre needs electricity and water, annoys the homes in its noise radius, and costs public acceptance if it goes on greenfield land. Run out of money or lose the public and the game ends.

## Run

The portable Godot runtime in `../.tools/` is stored with Git LFS. After cloning:

```powershell
git lfs install
git lfs pull
```

Double-click **`Play.cmd`**. Alternatively, open `project.godot` in Godot 4.4+ and press F5.

## How to play

- Pick a building on the right, then click the map. Only tinted tiles can be built on: open land (green), industrial estates (blue), and shops and offices (orange).
- Hovering shows the footprint, the noise radius, how many residents are within earshot and how many would object.
- Click a data centre to buy upgrades (renewable deal, waste heat, local jobs, community fund) or to decommission it.
- Scroll to zoom and right-drag to pan. Press Space or use the header buttons to pause or change speed.
- News events pause the game: guess the answer, then see the data and the survey side by side.
- At the end, answer "how do you feel about data centres now?" and compare yourself with the survey respondents.

## Where the numbers come from

Every number in the UI is tagged **DATA** (a sourced measurement), **OPINION** (a survey response) or **ASSUMPTION** (game balance).

| Game mechanic | Source | Type |
| --- | --- | --- |
| Compute demand growth 2015–2034 | CSO data-centre GWh 2015–2025, then SEAI forecast growth | DATA |
| Town (non-DC) electricity growth | CSO other-customer GWh | DATA |
| Starting acceptance 56% | 110 of 198 respondents strongly or somewhat supportive | OPINION |
| 35% of residents within earshot object | 69 of 195 found a DC within 5 km unacceptable | OPINION |
| Upgrade effects (54%, 49%, 41%, 39%) | Share naming each condition in their top 3 (n=195) | OPINION → ASSUMPTION |
| Greenfield penalty | 85 of 193 named land use as a top-2 negative impact | OPINION → ASSUMPTION |
| Data centres throttled first in a shortage | Beyond Fossil Fuels: only 4% prioritise data centres | OPINION |
| Enterprise / colocation / hyperscale real-world figures | KPMG (2025) typical data-centre types | DATA |
| Quiz reveals | CSO share, EirGrid renewables, survey beliefs | DATA + OPINION |
| Costs, capacities, noise radii, penalty scales | Game balance | ASSUMPTION |

All data describes **Ireland**, not Bournemouth. The survey is a 200-person sample of people in Ireland and is not representative of Ireland or Bournemouth. The game says "among surveyed respondents in Ireland" wherever it uses it.

## Regenerating data

- `../tools/data_import/import_data.py` converts `Survey.csv.xlsx` and `BCP Data.xlsx` into `data/survey.json` and `data/real_world_data.json`. It needs `pip install openpyxl`.
- `../tools/map_build/` builds `data/map.json` and `assets/map/satellite.jpg`:
  1. `curl` the Overpass query in `query.overpass` to `osm.json`.
  2. Run `fetch_tiles.py`, then `stitch.py`, then `build_map.py`. These need `pip install pillow`.

  The bounding box is set in `bbox.py`.

## Test

```powershell
..\.tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --editor --import
..\.tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd
..\.tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/balance.gd
```

- `smoke_test.gd` checks the imported figures, the placement rules, the upgrade maths, throttling, the event flow and a full game. Run it without `--headless` and add `-- --capture` to save screenshots to `test-output/`.
- `balance.gd` plays three bot strategies. Currently doing nothing goes bankrupt in 2024, greedy hyperscale building gets voted out in 2024, and careful play finishes 2034 with 99% of demand met.

## Files

| File | Responsibility |
| --- | --- |
| `scripts/data_catalog.gd` | Loads the JSON files and derives survey rates and display facts |
| `scripts/simulation_manager.gd` | Monthly model: demand, grid, water, throttling, acceptance, money, win/lose |
| `scripts/building_manager.gd` | Placement validation, previews, building and decommissioning |
| `scripts/town_map.gd` | Bournemouth grid, satellite underlay, noise overlay, pan and zoom |
| `scripts/building.gd` | Top-down placeholder art |
| `scripts/ui.gd` | HUD, build panel, upgrade panel, acceptance breakdown, event and end modals |
| `scripts/game_manager.gd` | Wiring, event scheduling, scoring |
| `data/*.json` | Buildings and upgrades, scenario balance, events, map, survey, real-world data |

## Attribution

- Map data © OpenStreetMap contributors (ODbL).
- Imagery: Sentinel-2 cloudless 2023 by EOX IT Services GmbH (contains modified Copernicus Sentinel data), CC BY-NC-SA 4.0.
- Survey: Social Acceptance of Sustainable Data Centres in Ireland (Maynooth University).
- Energy and economic data: CSO, SEAI, EirGrid, KPMG, Beyond Fossil Fuels, via the supplied `BCP Data.xlsx`.
