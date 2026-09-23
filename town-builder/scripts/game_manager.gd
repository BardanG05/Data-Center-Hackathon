extends Node
## Scene composition, signal wiring, events and end-of-game scoring.

@onready var data: GameData = $DataCatalog
@onready var simulation: SimulationManager = $SimulationManager
@onready var building_manager: BuildingManager = $BuildingManager
@onready var town_map: TownMap = $TownMap
@onready var ui: TownUI = $UI

var armed := ""
var selected_uid := -1
var active_event: Dictionary = {}
var fired_events: Dictionary = {}
var _speed_before_pause := 1.0


func _ready() -> void:
	ui.restart_requested.connect(func() -> void: get_tree().reload_current_scene())
	if not data.load_all():
		ui.show_message("Cannot load game data: " + data.error_message, true)
		push_error(data.error_message)
		return
	town_map.view_rect = TownUI.MAP_RECT
	town_map.setup(data.map)
	simulation.state_changed.connect(_on_state_changed)
	simulation.month_advanced.connect(_on_month)
	simulation.game_finished.connect(_on_finished)
	ui.configure(data, simulation)
	simulation.initialize(data, town_map.home_cells())
	building_manager.configure(town_map, simulation, data)
	town_map.cell_clicked.connect(_on_cell_clicked)
	town_map.cell_hovered.connect(_on_cell_hovered)
	town_map.cancel_clicked.connect(_cancel)
	ui.build_selected.connect(_on_build_selected)
	ui.upgrade_requested.connect(_on_upgrade)
	ui.demolish_requested.connect(_on_demolish)
	ui.speed_requested.connect(set_speed)
	ui.event_option_chosen.connect(_on_event_option)
	ui.event_closed.connect(_on_event_closed)
	ui.attitude_chosen.connect(func(option: String) -> void: ui.reveal_attitude(option))
	set_speed(1.0)
	ui.update_state(simulation.state)
	_check_events()


func set_speed(speed: float) -> void:
	simulation.paused = speed <= 0.0 or ui.is_modal_open()
	if speed > 0.0:
		simulation.speed = speed
		_speed_before_pause = speed
	ui.set_speed(speed if speed > 0.0 else 0.0)


func _on_state_changed(state: Dictionary) -> void:
	ui.update_state(state)
	_refresh_noise()


func _on_month(_year: int, _month: int) -> void:
	_check_events()


func _check_events() -> void:
	var state := simulation.state
	for event: Dictionary in data.events:
		if fired_events.has(event["id"]):
			continue
		if int(state["year"]) > int(event["year"]) or (int(state["year"]) == int(event["year"]) and int(state["month"]) >= int(event["month"])):
			fired_events[event["id"]] = true
			active_event = event
			simulation.paused = true
			ui.show_event(event)
			return


func _on_event_option(index: int) -> void:
	if active_event.is_empty():
		return
	var effects: Array = active_event.get("effects", [])
	if index < effects.size():
		simulation.apply_effect(effects[index])
	ui.reveal_event(active_event, index)


func _on_event_closed() -> void:
	if simulation.state.get("finished", false):
		get_tree().reload_current_scene()
		return
	active_event = {}
	ui.hide_modal()
	simulation.paused = false
	set_speed(_speed_before_pause)
	_check_events()


func _on_build_selected(building_id: String) -> void:
	if armed == building_id:
		_cancel()
		return
	armed = building_id
	_select(-1)
	ui.set_armed(building_id)


func _on_cell_hovered(cell: Vector2i) -> void:
	if armed.is_empty() or not town_map.in_bounds(cell):
		town_map.set_preview({})
		return
	var preview := building_manager.preview(cell, armed)
	town_map.set_preview(preview)
	ui.set_preview(preview)


func _on_cell_clicked(cell: Vector2i) -> void:
	if ui.is_modal_open():
		return
	if not armed.is_empty():
		var result := building_manager.try_build(cell, armed)
		ui.show_message(result["message"], not result["ok"])
		_on_cell_hovered(cell)
		return
	if town_map.occupancy.has(cell):
		_select(town_map.occupancy[cell])
	else:
		_select(-1)
		ui.show_message("%s. Pick a building on the right to build here." % TownMap.TERRAIN_NAMES[town_map.terrain_at(cell)])


func _select(uid: int) -> void:
	selected_uid = uid
	town_map.set_selected(uid)
	ui.set_selected(simulation.get_record(uid) if uid >= 0 else {})


func _cancel() -> void:
	armed = ""
	town_map.set_preview({})
	_select(-1)
	ui.set_armed("")


func _on_upgrade(uid: int, upgrade_id: String) -> void:
	var result := simulation.buy_upgrade(uid, upgrade_id)
	ui.show_message(result["message"], not result["ok"])
	var record := simulation.get_record(uid)
	town_map.refresh_building(record)
	ui.set_selected(record)


func _on_demolish(uid: int) -> void:
	var result := building_manager.demolish(uid)
	ui.show_message(result["message"], not result["ok"])
	_select(-1)


## Orange wash over homes, stronger where more residents object.
func _refresh_noise() -> void:
	var noise := {}
	var objection := float(data.rates["objection_near"])
	for record in simulation.placed:
		var def: Dictionary = data.buildings[record["id"]]
		var radius := int(def.get("noise_radius", 0))
		if radius <= 0:
			continue
		var strength := objection * simulation.objection_multiplier(record)
		for y in range(record["cell"].y - radius, record["cell"].y + record["size"].y + radius):
			for x in range(record["cell"].x - radius, record["cell"].x + record["size"].x + radius):
				var cell := Vector2i(x, y)
				if town_map.terrain_at(cell) == "residential":
					noise[cell] = 1.0 - (1.0 - float(noise.get(cell, 0.0))) * (1.0 - strength)
	town_map.set_noise(noise)


func _on_finished(_outcome: String) -> void:
	ui.show_end(simulation.state, summary())


func summary() -> Dictionary:
	var state := simulation.state
	var months := maxf(float(state["months_elapsed"]), 1.0)
	var coverage := float(state["coverage_total"]) / months
	var completed: bool = state["outcome"] == "completed"
	var score := roundi(coverage * 500.0 + float(state["acceptance"]) * 8.0 + clampf(float(state["money"]), -3000.0, 5000.0) / 25.0)
	if not completed:
		score = roundi(score * months / 240.0)
	var grade := "Council removed you" if state["outcome"] == "lost_acceptance" else "Bankrupt"
	if completed:
		var accepted := float(state["acceptance"])
		grade = "Digital hub, happy town" if coverage >= 0.85 and accepted >= 45.0 else ("Steady steward" if coverage >= 0.6 and accepted >= 35.0 else "Survived, just")
	return {"score": score, "grade": grade, "coverage": coverage}


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_cancel()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE and not ui.is_modal_open():
		set_speed(0.0 if not simulation.paused else _speed_before_pause)
		get_viewport().set_input_as_handled()
