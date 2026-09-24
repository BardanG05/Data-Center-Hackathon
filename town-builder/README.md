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

New players get a welcome screen and an optional 2-minute tutorial. Time stays paused throughout the tutorial, which walks them through the following:
1. Reading the map.
2. Building a first data centre at a suggested quiet site.
3. Seeing its impact.
4. Buying an upgrade.

After that, the **Next step** bar above the map always shows the most useful action, turning amber or red when something needs attention. Hover a stat card for an explanation, or a map tile to see what it is and whether you can build there.

- Pick a building on the right, then click the map. Only tinted tiles can be built on: open land (green), industrial estates (blue), and shops and offices (orange).
- Construction cost depends on the site: open land is cheaper but costs acceptance as greenfield, industrial land is the baseline, and shops and offices cost more. Hover a tile to see the final price.
- Hovering shows the footprint, the noise radius, how many residents are within earshot and how many would object.
- Click a data centre to buy upgrades (renewable deal, waste heat, local jobs, community fund) or to decommission it.
- Scroll to zoom and right-drag to pan. Press Space or use the header buttons to pause or change speed.
- Press conferences pause the game for a question. You can attend one whenever you want, and one mandatory conference arrives every 60 seconds of active play. Each question appears at most once per game.
- The renewable-energy policy remains a scheduled decision in 2023.
- **Restart** asks for confirmation before discarding the current town.
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
| Site cost multipliers | Open land 0.75×, industrial 1.0×, shops/offices 1.35× | ASSUMPTION |
| Data centres throttled first in a shortage | Beyond Fossil Fuels: only 4% prioritise data centres | OPINION |
| Enterprise / colocation / hyperscale real-world figures | KPMG (2025) typical data-centre types | DATA |
| Quiz reveals | Supplied question bank: survey results, resource use, AI, company reports and terminology | DATA + OPINION |
| Costs, capacities, noise radii, penalty scales | Game balance | ASSUMPTION |

The simulation's energy data describes **Ireland**, not Bournemouth. The hackathon survey is a 200-person sample of people in Ireland and is not representative of Ireland or Bournemouth. Quiz questions also include other surveys, global figures and company-reported estimates; their wording and explanations specify the relevant scope.

## Question bank

`data/question_bank.json` contains the 36 supplied questions, their answer choices, correct answers, explanations and source metadata. The supported formats are `MULTIPLE_CHOICE` (four choices), `MYTH_OR_FACT` (two choices) and `HIGHER_OR_LOWER` (two choices). The popup uses the same controls for all formats, highlights the correct answer after selection and applies a consequence. A correct answer rewards 10% of current gross monthly income and 1 public-acceptance point; a wrong answer loses 5% and 1.5 acceptance points. These are game-balance assumptions, and the result is shown in the explanation popup.

- Change the file's `interval_seconds` to set the delay between mandatory conferences (default: 60). This counts real seconds of active play, regardless of 1×/2×/4× game speed. Optional conferences use the same question pool and reset the timer.
- Welcome, tutorial, manual pause, other popups and the end screen stop the quiz timer. The first quiz waits for a full interval after onboarding. Reading an answer does not create a backlog of quizzes.
- Questions are shuffled for each new game. Drawing a question removes it from that game's pool. After every enabled question has appeared, quizzes stop until **Restart town** or **Play again** creates a fresh game; there is no mid-game recycling.
- To add a question, add an entry with a unique `id` and a `correct_answer` that exactly matches one of its options. Set `enabled` to `false` to exclude an entry from play. An empty bank is valid and disables quizzes.
- Invalid entries fail loading with an error identifying the problem. Source metadata stays in the JSON and is not displayed in the popup. The supplied wording is preserved; implementing this bank does not independently verify the external claims.

`data/events.json` now contains scheduled gameplay policy decisions only. Welcome, tutorial and final opinion prompts remain separate from the random question pool.

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
..\.tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/question_bank_test.gd
..\.tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/quiz_flow_test.gd
..\.tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/balance.gd
```

- `smoke_test.gd` checks the imported figures, the placement rules, the upgrade maths, throttling, the event flow and a full game. Run it without `--headless` and add `-- --capture` to save screenshots to `test-output/`.
- `question_bank_test.gd` validates the supplied bank, no-repeat draws, exhaustion, reset, disabled questions and malformed input. `quiz_flow_test.gd` checks timer/popup behaviour and scene restart; it also supports `-- --capture` in a rendered run.
- `balance.gd` plays three bot strategies. Currently doing nothing goes bankrupt in 2024, greedy hyperscale building gets voted out in 2024, and careful play finishes 2034 with 99% of demand met.

## Files

| File | Responsibility |
| --- | --- |
| `scripts/data_catalog.gd` | Loads the JSON files and derives survey rates and display facts |
| `scripts/quiz_bank.gd` | Validates questions and manages the shuffled pool for one game |
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
