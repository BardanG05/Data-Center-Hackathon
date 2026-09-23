# Gameplay data and provenance

## Current status

All active values are **fictional gameplay balance**. They are not imported measurements, survey results or estimates of Ireland's infrastructure. Electricity, water and compute use abstract game units, and a simulation second has no real-world time equivalent. The UI's euro symbol denotes fictional game money, not a sourced construction-cost estimate.

The supplied source files in the parent workspace are unchanged. MVP 0.1 does not yet fulfil the final hackathon requirement to use those datasets meaningfully; that requires a reviewed conversion and a visible gameplay/educational use later.

## Active JSON files

`data/buildings.json` contains `schema_version`, `data_status`, a human-readable `note`, and a `buildings` array. Each definition describes gameplay effects independently of map code.

| Building field | Meaning |
| --- | --- |
| `id` | Stable unique identifier, currently `data_centre`. |
| `name`, `description` | Player-facing text. |
| `level` | Current upgrade level; only level 1 is implemented. |
| `cost` | One-time purchase cost in game money. |
| `electricity_usage` | Ongoing electricity load added by an operational building. |
| `water_usage` | Ongoing water load added by an operational building. |
| `compute_capacity` | Added compute capacity. |
| `visual_kind` | Selects the placeholder artwork. |
| `color` | HTML-style hex colour for that artwork. |
| `sprite_path` | Optional `res://` texture path; empty uses the placeholder. |

Current Data Centre: cost **800**, electricity **28**, water **14**, compute **100**. It occupies one tile. Adding an arbitrary new building definition does not automatically implement new resource effects or a new interaction; extend the relevant manager and UI when its milestone arrives.

`data/scenario.json` contains the initial town state:

| Field | Current value / interpretation |
| --- | --- |
| `schema_version` | `1` |
| `data_status` | `fictional_gameplay_balance` |
| `name`, `note` | Fictional town name and scope explanation. |
| `tick_seconds` | `1.0`, simulation update interval. |
| `starting_money` | `1200` |
| `population` | `1200`, static in MVP 0.1. |
| `electricity_capacity`, `electricity_usage` | `90`, `42` baseline. |
| `water_capacity`, `water_usage` | `50`, `18` baseline. |
| `compute_capacity`, `compute_demand` | `0`, `60` baseline. |

At each tick, usage/capacity equals the scenario baseline plus each relevant placed building's contribution. These are rates/capacities in game units, not amounts accumulated or consumed from a reservoir each second. Population and demand do not increase yet. The start contains no Data Centre.

Use finite non-negative numbers for costs, loads and capacities, a positive tick interval and unique non-empty building identifiers. Keep JSON valid: no comments or trailing commas. After editing balance values, import/run the project again and update expected test values deliberately if the intended scenario changed.

## Deferred data

`events.json`, `survey.json` and `real_world_data.json` are empty, explicitly deferred collections. They reserve clear integration locations; there is no event scheduler, survey-derived modifier or fact-question engine in MVP 0.1. Empty collections must never be presented as measured zero values.

Do not bury future supplied data inside scripts. Maintain a separate import/cleaning step that produces reviewed JSON/CSV. Preserve source identifiers and units through that conversion, then map selected records into gameplay deliberately.

## Proposed later provenance contract

These fields are a design for the future importer, **not a schema currently consumed by the game**:

- **Source:** stable `source_id`, original filename, worksheet/table, question or row locator, publisher/author if supplied, observation year and retrieval/conversion date.
- **Measurement:** `record_id`, value, unit, geography, period, metric definition, source reference and known limitations. Record whether a value is reported, calculated or estimated.
- **Survey result:** exact question wording, response option, count, valid-response denominator, overall sample size, missing/excluded count and whether multiple selections were permitted.
- **Cleaning decision:** issue found, transformation applied, rationale and rows/records affected. Retain the originals and a reproducible conversion script.
- **Gameplay mapping:** source record references, normalisation or scaling rule, chosen game effect and an explicit statement that the effect is a design assumption where causality is unestablished.

Missing or inconsistent data should remain flagged as unknown. Do not silently substitute zero, merge incompatible units or average across different time periods. Remove direct personal identifiers and free-text identifying details from any distributable survey export.

## Perception vs Reality presentation

Keep three distinct records and labels for each educational question:

1. **Your guess:** the player's answer and its unit.
2. **Survey respondents' beliefs:** the surveyed distribution with its valid sample size and question wording.
3. **Supplied real-world data:** a measurement with source, year, definition and limitations.

Compare them only when units, geography, time period and the underlying question align. If they do not, explain the mismatch rather than calling an answer incorrect. Use wording such as **“Among the surveyed respondents…”**, never a claim that this sample represents all of Ireland.

Survey support for heat recovery, renewables or local benefits may inspire policy options. It does not establish how many acceptance points a policy causes; that conversion must remain labelled as gameplay balance. The educational objective is to keep **data, opinion and assumption** distinguishable while the player makes town decisions.
