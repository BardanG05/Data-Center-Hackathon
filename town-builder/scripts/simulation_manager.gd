class_name SimulationManager
extends Node
## Town model. One tick is one month; totals are recomputed from placed buildings
## each month rather than accumulated, so they cannot drift.

signal state_changed(state: Dictionary)
signal month_advanced(year: int, month: int)
signal game_finished(outcome: String)

var state: Dictionary = {}
## Placed buildings: {uid, id, cell, size, upgrades: Array[String]}.
var placed: Array[Dictionary] = []
var speed: float = 1.0
var paused: bool = false

var _data: GameData
var _homes: Array[Vector2i] = []
var _accumulator: float = 0.0
var _next_uid: int = 1


func initialize(data: GameData, homes: Array[Vector2i]) -> void:
	_data = data
	_homes = homes
	_accumulator = 0.0
	_next_uid = 1
	placed.clear()
	var s: Dictionary = data.scenario
	state = {
		"year": int(s["start_year"]),
		"month": 1,
		"months_elapsed": 0,
		"money": float(s["starting_money"]),
		"acceptance": data.rates["support"] * 100.0,
		"flags": {},
		"acceptance_modifier": 0.0,
		"coverage_total": 0.0,
		"blackout_months": 0,
		"curtailed_months": 0,
		"water_shortage_months": 0,
		"finished": false,
		"outcome": "",
	}
	_recalculate()
	_emit()


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if state.is_empty() or paused or state["finished"] or delta <= 0.0 or not is_finite(delta):
		return
	_accumulator += delta * speed
	var month_length := float(_data.scenario["seconds_per_month"])
	while _accumulator >= month_length and not paused and not state["finished"]:
		_accumulator -= month_length
		step_month()


## Advances exactly one month: money flows, acceptance moves, the calendar turns.
func step_month() -> void:
	_recalculate()
	var s: Dictionary = _data.scenario
	state["money"] += float(state["net_income"])
	state["acceptance"] += (float(state["acceptance_target"]) - float(state["acceptance"])) * float(s["acceptance_response"])
	state["acceptance"] = clampf(state["acceptance"], 0.0, 100.0)
	state["coverage_total"] += minf(1.0, float(state["compute_local"]) / maxf(float(state["compute_demand"]), 0.001))
	state["months_elapsed"] += 1
	if state["blackout"]:
		state["blackout_months"] += 1
	if state["dc_output"] < 0.999:
		state["curtailed_months"] += 1
	if state["water_shortage"]:
		state["water_shortage_months"] += 1
	if float(state["acceptance"]) <= float(s["lose_acceptance"]):
		_finish("lost_acceptance")
		return
	if float(state["money"]) <= float(s["lose_money"]):
		_finish("lost_money")
		return
	state["month"] += 1
	if state["month"] > 12:
		state["month"] = 1
		state["year"] += 1
	if state["year"] > int(s["end_year"]):
		state["year"] = int(s["end_year"])
		state["month"] = 12
		_finish("completed")
		return
	_recalculate()
	_emit()
	month_advanced.emit(state["year"], state["month"])


func can_afford(cost: float) -> bool:
	return not state.is_empty() and cost >= 0.0 and float(state["money"]) >= cost


## Build cost after policies and an optional site multiplier.
## With no site multiplier this returns the building's baseline cost.
func build_cost(id: String, site_multiplier: float = 1.0) -> float:
	var def: Dictionary = _data.buildings[id]
	var cost := float(def["cost"]) * maxf(site_multiplier, 0.0)
	if def["category"] == "data_centre" and has_flag("renewable_rule"):
		cost *= 1.25
	return cost


## greenfield_tiles: footprint tiles on open land, which cost acceptance for data centres.
func add_building(id: String, cell: Vector2i, greenfield_tiles: int = 0, site_multiplier: float = 1.0) -> Dictionary:
	var def: Dictionary = _data.buildings[id]
	var size := Vector2i(int(def["footprint"][0]), int(def["footprint"][1]))
	var final_cost := build_cost(id, site_multiplier)
	var record := {"uid": _next_uid, "id": id, "cell": cell, "size": size, "upgrades": [], "greenfield_tiles": greenfield_tiles, "site_multiplier": site_multiplier, "build_cost": final_cost}
	if def["category"] == "data_centre" and has_flag("renewable_rule"):
		record["upgrades"].append("renewable")
	_next_uid += 1
	state["money"] -= final_cost
	placed.append(record)
	_recalculate()
	_emit()
	return record


func remove_building(uid: int) -> bool:
	for i in range(placed.size()):
		if placed[i]["uid"] == uid:
			placed.remove_at(i)
			_recalculate()
			_emit()
			return true
	return false


func upgrade_cost(record: Dictionary, upgrade_id: String) -> float:
	return roundf(float(_data.buildings[record["id"]]["cost"]) * float(_data.upgrades[upgrade_id]["cost_fraction"]))


func buy_upgrade(uid: int, upgrade_id: String) -> Dictionary:
	var record := get_record(uid)
	if record.is_empty() or _data.buildings[record["id"]]["category"] != "data_centre":
		return {"ok": false, "message": "Select one of your data centres first."}
	if upgrade_id in record["upgrades"]:
		return {"ok": false, "message": "This centre already has that upgrade."}
	var cost := upgrade_cost(record, upgrade_id)
	if not can_afford(cost):
		return {"ok": false, "message": "Not enough money for that upgrade."}
	state["money"] -= cost
	record["upgrades"].append(upgrade_id)
	_recalculate()
	_emit()
	return {"ok": true, "message": "%s added." % _data.upgrades[upgrade_id]["name"]}


func get_record(uid: int) -> Dictionary:
	for record in placed:
		if record["uid"] == uid:
			return record
	return {}


func has_flag(flag: String) -> bool:
	return state.get("flags", {}).has(flag)


func apply_effect(effect: Dictionary) -> void:
	if effect.has("flag"):
		state["flags"][effect["flag"]] = true
	if effect.has("acceptance"):
		state["acceptance_modifier"] += float(effect["acceptance"])
		state["acceptance"] = clampf(float(state["acceptance"]) + float(effect["acceptance"]), 0.0, 100.0)
	_recalculate()
	_emit()


## Apply the budget and public-acceptance consequence of a recurring quiz.
## The money percentage uses gross recurring income so a struggling town never
## receives a reward just because its net income is negative.
func apply_quiz_result(correct: bool) -> Dictionary:
	var s: Dictionary = _data.scenario
	var monthly_income := maxf(float(state.get("town_income", 0.0)) + float(state.get("revenue", 0.0)), 0.0)
	var fraction_key := "quiz_correct_income_fraction" if correct else "quiz_wrong_income_fraction"
	var income_fraction := maxf(float(s.get(fraction_key, 0.0)), 0.0)
	var money_delta := monthly_income * income_fraction * (1.0 if correct else -1.0)
	var acceptance_key := "quiz_correct_acceptance" if correct else "quiz_wrong_acceptance"
	var acceptance_delta := float(s.get(acceptance_key, 0.0))
	state["money"] += money_delta
	state["acceptance_modifier"] += acceptance_delta
	state["acceptance"] = clampf(float(state["acceptance"]) + acceptance_delta, 0.0, 100.0)
	_recalculate()
	_emit()
	return {
		"correct": correct,
		"monthly_income": monthly_income,
		"income_fraction": income_fraction,
		"money_delta": money_delta,
		"acceptance_delta": acceptance_delta,
	}


## Residents objecting to noise/visual impact, optionally with a hypothetical
## extra building (for placement previews). Returns {objectors, exposed}.
func exposure(extra: Dictionary = {}) -> Dictionary:
	var sources: Array[Dictionary] = []
	for record in placed:
		var source := _noise_source(record)
		if not source.is_empty():
			sources.append(source)
	if not extra.is_empty():
		var source := _noise_source(extra)
		if not source.is_empty():
			sources.append(source)
	var per_home := residents_per_home()
	var objection := float(_data.rates["objection_near"])
	var objectors := 0.0
	var exposed := 0.0
	for home in _homes:
		var remain := 1.0
		var hit := false
		for source in sources:
			if _distance_to_rect(home, source["cell"], source["size"]) <= int(source["radius"]):
				remain *= 1.0 - objection * float(source["multiplier"])
				hit = true
		if hit:
			exposed += per_home
			objectors += (1.0 - remain) * per_home
	return {"objectors": objectors, "exposed": exposed}


## Objectors near one specific centre, for its detail panel.
func exposure_of(record: Dictionary) -> Dictionary:
	var source := _noise_source(record)
	if source.is_empty():
		return {"objectors": 0.0, "exposed": 0.0}
	var per_home := residents_per_home()
	var count := 0
	for home in _homes:
		if _distance_to_rect(home, source["cell"], source["size"]) <= int(source["radius"]):
			count += 1
	var exposed := count * per_home
	return {"exposed": exposed, "objectors": exposed * float(_data.rates["objection_near"]) * float(source["multiplier"])}


## Survey share naming land use as a top negative impact, scaled per tile.
func greenfield_penalty_per_tile() -> float:
	return float(_data.rates["greenfield"]) * float(_data.scenario["greenfield_penalty_per_tile"])


func residents_per_home() -> float:
	return float(_data.scenario["residents"]) / maxf(float(_homes.size()), 1.0)


## Share of a centre's objectors that remain after its upgrades.
func objection_multiplier(record: Dictionary) -> float:
	var multiplier := 1.0
	for upgrade_id: String in record["upgrades"]:
		multiplier *= 1.0 - float(_data.rates.get("upgrade_" + upgrade_id, 0.0))
	return multiplier


func _noise_source(record: Dictionary) -> Dictionary:
	var def: Dictionary = _data.buildings[record["id"]]
	if int(def.get("noise_radius", 0)) <= 0:
		return {}
	return {"cell": record["cell"], "size": record["size"], "radius": int(def["noise_radius"]), "multiplier": objection_multiplier(record)}


static func _distance_to_rect(point: Vector2i, origin: Vector2i, size: Vector2i) -> int:
	var dx := maxi(maxi(origin.x - point.x, 0), point.x - (origin.x + size.x - 1))
	var dy := maxi(maxi(origin.y - point.y, 0), point.y - (origin.y + size.y - 1))
	return maxi(dx, dy)


func _recalculate() -> void:
	var s: Dictionary = _data.scenario
	var year: int = state["year"]
	var month: int = state["month"]
	var other := _data.other_demand_index(year)
	var supply_e := float(s["electricity_capacity"])
	var supply_w := float(s["water_capacity"])
	var town_e := float(s["town_electricity_2015"]) * other
	var town_w := float(s["town_water_2015"]) * other
	var dc_e := 0.0
	var dc_w := 0.0
	var dc_compute := 0.0
	var dc_revenue := 0.0
	var dc_count := 0
	var greenfield := 0
	for record in placed:
		var def: Dictionary = _data.buildings[record["id"]]
		supply_e += float(def.get("electricity_supply", 0))
		supply_w += float(def.get("water_supply", 0))
		if def["category"] != "data_centre":
			continue
		dc_count += 1
		greenfield += int(record.get("greenfield_tiles", 0))
		var draw := float(def["electricity_usage"])
		for upgrade_id: String in record["upgrades"]:
			draw *= float(_data.upgrades[upgrade_id].get("grid_draw_multiplier", 1.0))
		dc_e += draw
		dc_w += float(def["water_usage"])
		dc_compute += float(def["compute_capacity"])
		dc_revenue += float(def["revenue_per_month"])
	# Data centres are throttled first when the grid is short.
	var available_e := supply_e - town_e
	var output := 1.0
	if dc_e > 0.0:
		output = clampf(available_e / dc_e, 0.0, 1.0)
	var blackout := available_e < 0.0
	var water_used := town_w + dc_w * output
	var water_ratio := water_used / maxf(supply_w, 0.001)
	var demand := float(s["base_compute_demand"]) * _data.demand_index(year, month)
	var local := dc_compute * output
	var unmet := maxf(0.0, demand - local)
	var import_cost := unmet * float(s["import_cost_per_compute"])
	var revenue := dc_revenue * output
	var ex := exposure()
	var local_penalty := float(s["acceptance_amplifier"]) * float(ex["objectors"]) / float(s["residents"]) * 100.0
	var greenfield_penalty := greenfield * greenfield_penalty_per_tile()
	var curtail_penalty := (1.0 - output) * float(s["curtailment_penalty"]) if dc_e > 0.0 else 0.0
	var blackout_penalty := float(s["blackout_penalty"]) if blackout else 0.0
	var water_penalty := 0.0
	if water_ratio > 1.0:
		water_penalty = minf((water_ratio - 1.0) * float(s["water_shortage_penalty_per_ratio"]), float(s["water_shortage_penalty_max"]))
	var base := float(_data.rates["support"]) * 100.0
	state["electricity_supply"] = supply_e
	state["electricity_town"] = town_e
	state["electricity_dc"] = dc_e * output
	state["electricity_dc_demand"] = dc_e
	state["electricity_used"] = town_e + dc_e * output
	state["dc_output"] = output
	state["blackout"] = blackout
	state["water_supply"] = supply_w
	state["water_used"] = water_used
	state["water_shortage"] = water_ratio > 1.0
	state["compute_demand"] = demand
	state["compute_capacity"] = dc_compute
	state["compute_local"] = local
	state["import_cost"] = import_cost
	state["revenue"] = revenue
	state["town_income"] = float(s["town_income_per_month"])
	state["net_income"] = float(s["town_income_per_month"]) + revenue - import_cost
	state["objectors"] = ex["objectors"]
	state["exposed"] = ex["exposed"]
	state["dc_count"] = dc_count
	state["dc_share"] = (dc_e * output) / maxf(town_e + dc_e * output, 0.001)
	state["ireland_share"] = _data.ireland_dc_share(year)
	state["penalties"] = {
		"local": local_penalty, "greenfield": greenfield_penalty, "curtailment": curtail_penalty, "blackout": blackout_penalty,
		"water": water_penalty, "policy": -float(state["acceptance_modifier"])}
	state["acceptance_base"] = base
	state["acceptance_target"] = clampf(base + float(state["acceptance_modifier"]) - local_penalty - greenfield_penalty - curtail_penalty - blackout_penalty - water_penalty, 0.0, 100.0)


func _finish(outcome: String) -> void:
	state["finished"] = true
	state["outcome"] = outcome
	_recalculate()
	_emit()
	game_finished.emit(outcome)


func _emit() -> void:
	state_changed.emit(state.duplicate(true))
