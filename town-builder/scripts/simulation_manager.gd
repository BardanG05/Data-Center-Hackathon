class_name SimulationManager
extends Node
## Aggregate town simulation. A frame only supplies elapsed time to a fixed step.

signal state_changed(state: Dictionary)

var state: Dictionary = {}
var placed_buildings: Array[Dictionary] = []
var _baseline: Dictionary = {}
var _accumulator: float = 0.0
var _tick_seconds: float = 1.0


func initialize(scenario: Dictionary) -> void:
	_baseline = scenario.duplicate(true)
	_tick_seconds = float(scenario["tick_seconds"])
	_accumulator = 0.0
	placed_buildings.clear()
	state = {
		"money": float(scenario["starting_money"]),
		"population": int(scenario["population"]),
		"electricity_capacity": float(scenario["electricity_capacity"]),
		"water_capacity": float(scenario["water_capacity"]),
		"compute_demand": float(scenario["compute_demand"]),
		"elapsed_seconds": 0.0,
		"tick_count": 0,
		"building_count": 0
	}
	_recalculate()


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if state.is_empty() or delta < 0.0 or not is_finite(delta):
		return
	_accumulator += delta
	while _accumulator >= _tick_seconds:
		_accumulator -= _tick_seconds
		state["tick_count"] += 1
		state["elapsed_seconds"] = state["tick_count"] * _tick_seconds
		_recalculate()


func can_afford(cost: float) -> bool:
	return not state.is_empty() and cost >= 0.0 and float(state["money"]) >= cost


func purchase_building(definition: Dictionary, cell: Vector2i) -> bool:
	# Called once by BuildingManager after placement validation, on the main thread.
	if not can_afford(float(definition["cost"])):
		return false
	state["money"] -= float(definition["cost"])
	var record := definition.duplicate(true)
	record["cell"] = cell
	placed_buildings.append(record)
	_recalculate()
	return true


func _recalculate() -> void:
	state["electricity_used"] = float(_baseline["electricity_usage"])
	state["water_used"] = float(_baseline["water_usage"])
	state["compute_capacity"] = float(_baseline["compute_capacity"])
	for building in placed_buildings:
		state["electricity_used"] += float(building["electricity_usage"])
		state["water_used"] += float(building["water_usage"])
		state["compute_capacity"] += float(building["compute_capacity"])
	state["building_count"] = placed_buildings.size()
	state_changed.emit(state.duplicate(true))
