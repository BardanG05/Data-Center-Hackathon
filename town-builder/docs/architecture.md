# Architecture and MVP plan

## Technology choice

Godot 4, GDScript and 2D isometric presentation fit this project: the game needs a readable town, direct interaction and a small continuous simulation, without the production cost of a full 3D world. Use the standard Godot build and target Godot 4.4 or newer. Verify the team's chosen engine version before the demo; a newer-engine test does not establish compatibility with every older release.

The project selects **Compatibility** rendering from the outset. Godot's documented web export uses WebGL 2.0 through this renderer, making a later web export a practical option to test rather than an additional feature promised by MVP 0.1. See [Godot web export documentation](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_web.html).

The first map is a fixed 10 × 10 array drawn as isometric diamonds. A custom small map avoids a tileset authoring step while preserving integer grid coordinates as the model. If terrain editing grows later, migrate presentation to `TileMapLayer`; Godot documents the older `TileMap` node as deprecated. See [TileMapLayer documentation](https://docs.godotengine.org/en/4.4/classes/class_tilemaplayer.html).

## Components

| File | Responsibility |
| --- | --- |
| `scenes/main.tscn` | Compose the map, UI and managers. |
| `scenes/map.tscn` | Host the isometric town presentation. |
| `scenes/building.tscn` | Reusable building instance and visual. |
| `scenes/ui.tscn` | Resource display and placement interaction. |
| `scripts/game_manager.gd` | Start the scenario and connect components. |
| `scripts/data_catalog.gd` | Load and validate gameplay JSON. |
| `scripts/simulation_manager.gd` | Own money and resource totals; advance fixed simulation ticks. |
| `scripts/building_manager.gd` | Check purchase eligibility and coordinate placement. |
| `scripts/town_map.gd` | Grid projection, buildability, occupancy, selection and town layout. |
| `scripts/building.gd` | Draw reusable placeholder buildings or load their replacement texture. |
| `scripts/ui.gd` | Present state, cost and feedback; emit player requests. |

Resource rules belong in simulation/placement code. The UI displays results; it must not independently deduct money or calculate resource usage. Building artwork does not determine a tile's occupancy or resource contribution.

The existing town's resource demand is a scenario baseline. Its houses and other initial visuals are not individually simulated citizens or consumers. Purchased buildings add their definitions to that baseline.

## Placement and time

The placement flow is: select a valid empty tile → display the building menu → request purchase → validate tile, definition and funds → deduct one cost and place one building → refresh state and presentation. A rejected request leaves the town and balance unchanged.

Simulation runs on a fixed **one-second** tick. Recompute resource totals from the baseline and placed buildings, rather than adding each building's load again on every tick. The totals therefore remain constant until something in the town changes. Money is deducted on purchase, not every tick.

This is real-time accounting, but not yet population growth or a dynamic economy. The starting compute deficit is instructional only. There is no throttling, service degradation or game-over rule in this milestone.

Keep each building on one tile, with its visual anchored to the ground. Integer tile coordinates remain stable when the map moves or the window changes size. Buildings can receive `sprite_path` textures later without changing simulation data or placement rules.

## Deliberate limits

- One Data Centre type and level; instant construction; no income or selling.
- A fixed map without a camera, terrain editing, roads simulation or pathfinding.
- Static population and demand; acceptance and sustainability scoring are deferred.
- No saving, events, upgrades, speed controls or imported survey effects.
- All current balancing values are illustrative; no supplied statistics are represented as implemented facts.

Money deduction and electricity/water/compute accounting are included now because the explicit first-playable checklist requires them. Later milestones deepen these systems rather than postponing their basic display.

## Realistic staged plan

For someone comfortable with Godot, reserve roughly **4–6 focused hours** for the first slice including import, debugging and manual validation. A first-time Godot team should allow at least an additional learning/debugging block. These are planning estimates, not a deadline commitment; data cleaning and asset integration may dominate later work.

| Milestone | Smallest useful deliverable | Planning allowance |
| --- | --- | --- |
| 0.1 | Town, click-to-build, one Data Centre, money deduction and fixed-tick totals | 4–6 focused hours |
| 0.2 | Short construction timer and simple income; effects begin on completion | 2–4 hours |
| 0.3 | Electricity/water shortfall ratios, compute throttling and clear feedback | 3–5 hours |
| 0.4 | Slowly rising compute demand and one meaningful service penalty | 1–3 hours |
| 0.5 | Grid, water and wind first; add the other infrastructure only if time permits | 3–6 hours |
| 0.6 | One tested upgrade path before adding all four Data Centre levels | 2–4 hours |
| 0.7 | Population and economy feedback with bounded growth | 3–6 hours |
| 0.8 | Public acceptance with two understandable player interventions | 3–6 hours |
| 0.9 | Verified source conversion, one event and one Perception vs Reality interaction | 4–8+ hours; depends on data quality |
| 1.0 | Tutorial, visual consistency, demo balancing and export verification | Reserve 4–8 hours |

Complete and test one slice before expanding. Stop at the strongest stable milestone the available time supports. The hackathon submission must eventually demonstrate meaningful use of the supplied datasets; MVP 0.1 alone establishes the interaction foundation, not that final requirement. Review data quality and provenance early, even though gameplay integration comes later.

## Main risks and simplifications

**Isometric interaction:** selection and visual depth are more error-prone than the projection formula. Keep flat terrain and one-tile buildings; test adjacent edges, occupied plots and UI click handling before adding larger assets.

**Interconnected simulation:** feedback can create a runaway economy or an unrecoverable shortage. Introduce one effect at a time, use bounded ratios and provide an affordable recovery action before adding cascading consequences.

**Survey interpretation:** preferences are not causal effect sizes, and a supplied sample is not automatically representative of Ireland. Keep respondent belief, sourced measurement and gameplay assumptions visibly separate.

**Demo delivery:** native launch and browser export are different validation tasks. Preserve a working desktop demo, test the intended presentation computer, and attempt web export while time remains to resolve hosting and browser constraints.

## Validation boundary

Run the import and smoke-test commands in the README, then perform its manual UI checks. Headless checks can validate resource invariants and rejected purchases; they do not establish that visuals are readable, hit targets align or the build menu behaves correctly in a displayed window.

The next implementation step is **0.2: construction state and income**. Keep `under_construction` buildings visible but exclude them from operational resource contributions until their timer completes; test that completion occurs once and purchase cost is still deducted only once.
