class_name BuildingManager
extends Node
## The single player construction entry point; UI never changes resources itself.

var _map: TownMap
var _simulation: SimulationManager
var _data: GameData


func configure(town_map: TownMap, simulation: SimulationManager, data: GameData) -> void:
	_map = town_map
	_simulation = simulation
	_data = data


func try_build(cell: Vector2i, building_id: String) -> Dictionary:
	if not _data.buildings.has(building_id):
		return {"ok": false, "message": "That building is not available."}
	if not _map.is_buildable(cell):
		return {"ok": false, "message": "Choose an empty grass tile. Roads, water and existing buildings are protected."}
	var definition: Dictionary = _data.buildings[building_id]
	if not _simulation.can_afford(float(definition["cost"])):
		return {"ok": false, "message": "Not enough town funds. Restart the demo to try another site."}
	# No await between validation, placement and purchase: a repeated click is rejected
	# by occupancy before funds can be deducted again.
	var building := _map.place_building(cell, definition)
	if building == null:
		return {"ok": false, "message": "Placement failed; no funds were spent."}
	_simulation.purchase_building(definition, cell)
	return {"ok": true, "message": "Data Centre online. Local compute is available; electricity and water usage have increased."}
