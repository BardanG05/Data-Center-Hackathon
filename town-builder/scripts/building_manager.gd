class_name BuildingManager
extends Node
## The single construction entry point; the UI never changes resources itself.

var _map: TownMap
var _simulation: SimulationManager
var _data: GameData


func configure(town_map: TownMap, simulation: SimulationManager, data: GameData) -> void:
	_map = town_map
	_simulation = simulation
	_data = data


func footprint(building_id: String) -> Vector2i:
	var size: Array = _data.buildings[building_id]["footprint"]
	return Vector2i(int(size[0]), int(size[1]))


## Everything the UI needs to preview a placement without changing anything.
func preview(cell: Vector2i, building_id: String) -> Dictionary:
	var def: Dictionary = _data.buildings[building_id]
	var size := footprint(building_id)
	var problem := _map.placement_problem(cell, size, def["terrain"])
	var cost := _simulation.build_cost(building_id)
	if problem.is_empty() and not _simulation.can_afford(cost):
		problem = "Not enough money (costs %s)." % GameData.money(cost)
	var result := {"cell": cell, "size": size, "radius": int(def.get("noise_radius", 0)), "ok": problem.is_empty(), "problem": problem, "cost": cost}
	result["greenfield_tiles"] = _greenfield_tiles(cell, size) if def["category"] == "data_centre" else 0
	if def["category"] == "data_centre" and _map.in_bounds(cell):
		var hypothetical := {"id": building_id, "cell": cell, "size": size, "upgrades": ["renewable"] if _simulation.has_flag("renewable_rule") else []}
		var before: float = _simulation.state.get("objectors", 0.0)
		var after: Dictionary = _simulation.exposure(hypothetical)
		result["new_objectors"] = float(after["objectors"]) - before
		result["exposed"] = _simulation.exposure_of(hypothetical)["exposed"]
	return result


func try_build(cell: Vector2i, building_id: String) -> Dictionary:
	if not _data.buildings.has(building_id):
		return {"ok": false, "message": "That building is not available."}
	var check := preview(cell, building_id)
	if not check["ok"]:
		return {"ok": false, "message": check["problem"]}
	var record := _simulation.add_building(building_id, cell, check["greenfield_tiles"])
	_map.place(record, _data.buildings[building_id])
	var def: Dictionary = _data.buildings[building_id]
	var message := "%s built." % def["name"]
	if def["category"] == "data_centre":
		message += " About %s nearby residents object." % GameData.thousands(check.get("new_objectors", 0.0))
	return {"ok": true, "message": message, "record": record}


func _greenfield_tiles(cell: Vector2i, size: Vector2i) -> int:
	var count := 0
	for dy in range(size.y):
		for dx in range(size.x):
			if _map.terrain_at(cell + Vector2i(dx, dy)) == "open":
				count += 1
	return count


func demolish(uid: int) -> Dictionary:
	var record := _simulation.get_record(uid)
	if record.is_empty():
		return {"ok": false, "message": "Nothing to remove."}
	_simulation.remove_building(uid)
	_map.remove(uid)
	return {"ok": true, "message": "%s decommissioned. No refund." % _data.buildings[record["id"]]["name"]}
