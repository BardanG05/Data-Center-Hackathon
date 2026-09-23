extends Node
## Scene composition, signal wiring, events and end-of-game scoring.

@onready var data: GameData = $DataCatalog
@onready var simulation: SimulationManager = $SimulationManager
@onready var building_manager: BuildingManager = $BuildingManager
@onready var town_map: TownMap = $TownMap
@onready var ui: TownUI = $UI

const WELCOME := {
	"id": "welcome", "kind": "welcome", "kicker": "WELCOME TO BOURNEMOUTH · 2015",
	"title": "Can you power the digital town without losing it?",
	"body": "You run Bournemouth's digital future for the next 20 years. The town's demand for computing (streaming, cloud, AI) will grow the way Ireland's did: [b]almost tenfold[/b].\n\n[b]•[/b] Build [b]data centres[/b] to meet demand, or pay every month to import it.\n[b]•[/b] Each one uses [b]electricity and water[/b], and annoys the [b]homes nearby[/b].\n[b]•[/b] Keep [b]public acceptance above 25%[/b] and stay out of debt until [b]2034[/b].\n\nThe game uses real Irish energy data and a survey of 200 people in Ireland.",
	"options": ["Show me how (2-minute tutorial)", "Skip the tutorial"],
}

var armed := ""
var selected_uid := -1
var active_event: Dictionary = {}
var fired_events: Dictionary = {}
var _speed_before_pause := 1.0
var tutorial: Tutorial
var _quiz_elapsed := 0.0
var _event_answered := false
var _restart_speed := 1.0
var _restart_was_paused := false


func _ready() -> void:
	ui.restart_requested.connect(_on_restart_requested)
	ui.restart_confirmed.connect(_on_restart_confirmed)
	ui.restart_cancelled.connect(_on_restart_cancelled)
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
	tutorial = Tutorial.new()
	tutorial.name = "Tutorial"
	add_child(tutorial)
	tutorial.finished.connect(_begin_play)
	ui.coach_next.connect(tutorial.next)
	ui.coach_skip.connect(tutorial.finish)
	simulation.paused = true
	ui.set_speed(0.0)
	_on_state_changed(simulation.state)
	active_event = WELCOME
	ui.show_event(WELCOME)


## Starts the clock after the welcome screen or tutorial.
func _begin_play() -> void:
	_quiz_elapsed = 0.0
	set_speed(1.0)
	_check_events()


func _on_restart_requested() -> void:
	if ui.is_modal_open() or simulation.state.get("finished", false):
		return
	_restart_speed = simulation.speed
	_restart_was_paused = simulation.paused
	simulation.paused = true
	ui.set_speed(0.0)
	ui.show_restart_confirmation()


func _on_restart_confirmed() -> void:
	get_tree().reload_current_scene()


func _on_restart_cancelled() -> void:
	ui.hide_restart_confirmation()
	set_speed(0.0 if _restart_was_paused else _restart_speed)


func _process(delta: float) -> void:
	_advance_quiz_timer(delta)


## Count real seconds of active play, independently of the simulation speed.
func _advance_quiz_timer(delta: float) -> void:
	if delta <= 0.0 or not is_finite(delta) or simulation.state.is_empty():
		return
	if simulation.paused or simulation.state["finished"] or tutorial == null or tutorial.active:
		return
	if ui.is_modal_open() or not active_event.is_empty() or data.quiz_bank.remaining_count() == 0:
		return
	# A scheduled policy takes precedence; never stack two popups.
	_check_events()
	if not active_event.is_empty():
		return
	_quiz_elapsed += delta
	if _quiz_elapsed < data.quiz_bank.interval_seconds:
		return
	var question: Dictionary = data.quiz_bank.draw()
	if question.is_empty():
		return
	_quiz_elapsed = 0.0
	question["kind"] = "quiz"
	_open_event(question)


func _open_event(event: Dictionary) -> void:
	active_event = event
	_event_answered = false
	simulation.paused = true
	ui.show_event(event)


func set_speed(speed: float) -> void:
	simulation.paused = speed <= 0.0 or ui.is_modal_open() or (tutorial != null and tutorial.active)
	if speed > 0.0:
		simulation.speed = speed
		_speed_before_pause = speed
	ui.set_speed(speed if speed > 0.0 else 0.0)


func _on_state_changed(state: Dictionary) -> void:
	ui.update_state(state)
	_refresh_noise()
	var tip := advice(state)
	ui.set_advice(tip[0], tip[1])


func _on_month(_year: int, _month: int) -> void:
	_check_events()


func _check_events() -> void:
	if tutorial.active or not active_event.is_empty() or simulation.state.get("finished", false):
		return
	var state := simulation.state
	for event: Dictionary in data.events:
		if fired_events.has(event["id"]):
			continue
		if int(state["year"]) > int(event["year"]) or (int(state["year"]) == int(event["year"]) and int(state["month"]) >= int(event["month"])):
			fired_events[event["id"]] = true
			_open_event(event)
			return


func _on_event_option(index: int) -> void:
	if active_event.is_empty() or _event_answered:
		return
	if index < 0 or index >= active_event.get("options", []).size():
		return
	if active_event.get("kind") == "welcome":
		active_event = {}
		ui.hide_modal()
		if index == 0:
			tutorial.start(self)
		else:
			_begin_play()
		return
	_event_answered = true
	var effects: Array = active_event.get("effects", [])
	if index < effects.size():
		simulation.apply_effect(effects[index])
	ui.reveal_event(active_event, index)


func _on_event_closed() -> void:
	if simulation.state.get("finished", false):
		get_tree().reload_current_scene()
		return
	if active_event.is_empty() or not _event_answered:
		return
	active_event = {}
	_event_answered = false
	ui.hide_modal()
	simulation.paused = false
	set_speed(_speed_before_pause)
	_check_events()


func _on_build_selected(building_id: String) -> void:
	if armed == building_id:
		_cancel()
		return
	_select(-1)
	armed = building_id
	ui.set_armed(building_id)
	town_map.set_build_filter(data.buildings[building_id]["terrain"])
	tutorial.notify("armed", building_id)


func _on_cell_hovered(cell: Vector2i) -> void:
	if not town_map.in_bounds(cell) or ui.is_modal_open():
		town_map.set_preview({})
		ui.show_hover("")
		return
	if armed.is_empty():
		town_map.set_preview({})
		ui.show_hover(_describe_cell(cell))
		return
	var preview := building_manager.preview(cell, armed)
	town_map.set_preview(preview)
	ui.set_preview(preview)
	var text: String = preview["problem"]
	if preview["ok"]:
		var site_type := String(preview.get("site_type", "mixed site"))
		var site_name := String(TownMap.TERRAIN_NAMES.get(site_type, site_type.capitalize()))
		text = "Click to build · %s · %s" % [GameData.money(preview["cost"]), site_name]
		if preview.has("new_objectors"):
			text += " · about %s would object" % GameData.thousands(preview["new_objectors"])
		if int(preview.get("greenfield_tiles", 0)) > 0:
			text += " · greenfield"
	ui.show_hover(text)


func _describe_cell(cell: Vector2i) -> String:
	if town_map.occupancy.has(cell):
		var record := simulation.get_record(town_map.occupancy[cell])
		return "%s · click for details" % data.buildings[record["id"]]["name"]
	match town_map.terrain_at(cell):
		"residential":
			return "Homes · about %s residents" % GameData.thousands(simulation.residents_per_home())
		"open":
			return "Open land · you can build here (greenfield)"
		"industrial":
			return "Industrial estate · you can build here"
		"town_centre":
			return "Shops & offices · you can build here"
		"sea":
			return "Poole Bay · offshore wind only"
		var kind:
			return "%s · can't build here" % TownMap.TERRAIN_NAMES[kind]


func _on_cell_clicked(cell: Vector2i) -> void:
	if ui.is_modal_open():
		return
	if not armed.is_empty():
		var result := building_manager.try_build(cell, armed)
		ui.show_message(result["message"], not result["ok"])
		if result["ok"]:
			tutorial.notify("built", result["record"])
			_cancel()
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
	var record := simulation.get_record(uid) if uid >= 0 else {}
	ui.set_selected(record)
	tutorial.notify("selected", record)


func _cancel() -> void:
	var was_armed := not armed.is_empty()
	armed = ""
	town_map.set_preview({})
	town_map.set_build_filter([])
	_select(-1)
	ui.set_armed("")
	if was_armed:
		tutorial.notify("armed", "")


func _on_upgrade(uid: int, upgrade_id: String) -> void:
	var result := simulation.buy_upgrade(uid, upgrade_id)
	ui.show_message(result["message"], not result["ok"])
	if result["ok"]:
		tutorial.notify("upgraded")
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


## The single most useful next step, as [text, level] with level info/warn/bad.
func advice(state: Dictionary) -> Array:
	var s: Dictionary = data.scenario
	var lose := float(s["lose_acceptance"])
	var net := float(state["net_income"])
	var e_head := float(state["electricity_supply"]) - float(state["electricity_town"]) - float(state["electricity_dc_demand"])
	var w_head := float(state["water_supply"]) - float(state["water_used"])
	if state["blackout"]:
		return ["Homes are losing power! Build a solar farm or offshore wind, or decommission a data centre.", "bad"]
	if state["water_shortage"]:
		return ["Hosepipe ban! Build a water treatment works on open or industrial land.", "bad"]
	if float(state["acceptance"]) < lose + 10.0:
		return ["Acceptance is close to %d%%. Click your noisiest data centre and buy upgrades, or decommission it." % roundi(lose), "bad"]
	if net < 0.0 and float(state["money"]) + net * 12.0 < float(s["lose_money"]):
		return ["You're losing %s a month and will be bankrupt within a year. Meet more demand locally to cut the import bill." % GameData.money(-net), "bad"]
	if float(state["dc_output"]) < 0.999:
		return ["The grid is full, so your data centres are throttled. Build a solar farm or offshore wind.", "warn"]
	if int(state["dc_count"]) == 0:
		return ["Build your first data centre: pick one on the right, then click a bright tile on the map.", "info"]
	if float(state["compute_local"]) < float(state["compute_demand"]) * 0.95:
		return ["Demand (%d) is outgrowing your data centres (%d). You're paying %s a month for imports, so build another." % [
			roundi(state["compute_demand"]), roundi(state["compute_local"]), GameData.money(state["import_cost"])], "warn"]
	if float(state["acceptance_target"]) < float(state["acceptance"]) - 3.0:
		return ["Acceptance is falling towards %d%%. Upgrades on your data centres win neighbours back." % roundi(state["acceptance_target"]), "warn"]
	if e_head < 10.0:
		return ["Only %d electricity to spare. Add a solar farm before your next data centre." % maxi(roundi(e_head), 0), "warn"]
	if w_head < 4.0:
		return ["Water is nearly used up. Build a water treatment works before your next data centre.", "warn"]
	return ["All good. Demand keeps growing, so plan your next site. Speed up with 2× or 4×.", "info"]


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
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE and not ui.is_modal_open() and not tutorial.active:
		set_speed(0.0 if not simulation.paused else _speed_before_pause)
		get_viewport().set_input_as_handled()
