extends SceneTree
## Run after import: godot --headless --path . --script res://tests/smoke_test.gd
## Add -- --capture in a rendered run to save screenshots to test-output/.

var failures: Array[String] = []
var checks: int = 0
var game: Node
var capture: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var sim: SimulationManager = game.simulation
	var map: TownMap = game.town_map
	var data: GameData = game.data
	sim.set_process(false)

	# Data import and derived facts
	_check(data.error_message.is_empty(), "All JSON loaded: " + data.error_message)
	_check(data.facts["share_2025"] == "23.2", "CSO 2025 data-centre share is 23.2%% (got %s)" % data.facts["share_2025"])
	_check(data.facts["share_2015"] == "5.0", "CSO 2015 share is 5.0%")
	_check(absf(data.rates["support"] - 110.0 / 198.0) < 0.001, "Starting support = 110/198 supportive respondents")
	_check(absf(data.rates["objection_near"] - 69.0 / 195.0) < 0.001, "Objection = 69/195 find a DC within 5 km unacceptable")
	_check(absf(data.rates["upgrade_waste_heat"] - 106.0 / 195.0) < 0.001, "Waste heat top-3 share = 106/195")
	_check(is_equal_approx(data.demand_index(2015), 1.0) and data.demand_index(2025) > 6.0, "Demand index follows CSO curve")
	for event: Dictionary in data.events:
		var text: String = game.ui._fill(String(event.get("reveal", "")) + String(event["body"]))
		_check(not "{" in text, "Event '%s' has every placeholder filled" % event["id"])

	# Start state
	_check(sim.state["year"] == 2015 and sim.state["month"] == 1, "Game starts January 2015")
	_check(game.ui.is_modal_open() and sim.paused and game.active_event.get("id") == "welcome", "Welcome screen shown first with time paused")
	_check(map.grid_size == Vector2i(48, 30), "Bournemouth grid is 48 × 30")
	_check(map.home_cells().size() > 500, "Map has residential homes")
	await _screenshot("00-welcome")
	game.ui.event_option_chosen.emit(1)
	_check(game.ui.is_modal_open() and game.active_event.get("id") == "share_quiz", "Skipping the tutorial opens the first quiz")
	await _screenshot("01-intro-quiz")
	game.ui.event_option_chosen.emit(2)
	await process_frame
	await _screenshot("02-quiz-reveal")
	game.ui.event_closed.emit()
	_check(not game.ui.is_modal_open() and not sim.paused, "Closing the quiz resumes time")
	sim.paused = true

	# Placement rules
	var sea := _find("sea")
	var home := _find("residential")
	var open := _find_isolated_open()
	_check(open != TownMap.NO_CELL, "An open plot exists")
	var money: float = sim.state["money"]
	_check(not game.building_manager.try_build(sea, "enterprise")["ok"], "Cannot build a data centre in the sea")
	_check(not game.building_manager.try_build(home, "enterprise")["ok"], "Cannot build on homes")
	sim.state["money"] = 10000.0
	_check(game.building_manager.try_build(sea, "offshore_wind")["ok"], "Offshore wind goes in the sea")
	_check(is_equal_approx(sim.state["electricity_supply"], 130.0), "Offshore wind adds 30 supply")
	money = sim.state["money"]
	var result: Dictionary = game.building_manager.try_build(open, "colocation")
	_check(result["ok"], "Colocation builds on open land")
	_check(is_equal_approx(sim.state["money"], money - 1400.0), "Cost deducted once")
	_check(is_equal_approx(sim.state["compute_capacity"], 35.0), "Compute capacity added")
	_check(not game.building_manager.try_build(open, "enterprise")["ok"], "Occupied plot rejected")
	var record: Dictionary = result["record"]
	var before: float = sim.exposure_of(record)["objectors"]
	if before > 0.0:
		money = sim.state["money"]
		_check(sim.buy_upgrade(record["uid"], "waste_heat")["ok"], "Waste-heat upgrade purchased")
		var after: float = sim.exposure_of(record)["objectors"]
		_check(absf(after / before - (1.0 - data.rates["upgrade_waste_heat"])) < 0.001, "Upgrade wins over the survey share of objectors")
		_check(not sim.buy_upgrade(record["uid"], "waste_heat")["ok"], "Duplicate upgrade rejected")

	# Placement preview and selection panels
	game._on_build_selected("hyperscale")
	var hover := _find_isolated_open()
	game._on_cell_hovered(hover)
	_check(game.ui._info.text.contains("residents within earshot"), "Preview shows affected residents")
	await _screenshot("05-preview")
	game._cancel()
	game._select(record["uid"])
	_check(game.ui._actions.get_child_count() == 5, "Data centre panel lists 4 upgrades + decommission")
	await _screenshot("06-selected")
	game._select(-1)

	# Time and resources
	for i in range(12):
		sim.step_month()
	_check(sim.state["year"] == 2016 and sim.state["month"] == 1, "Twelve months advance one year")
	_check(sim.state["compute_demand"] > 10.0, "Compute demand grows")
	sim.state["money"] = 100000.0
	for i in range(6):
		var cell := _find_isolated_open()
		if cell != TownMap.NO_CELL:
			game.building_manager.try_build(cell, "colocation")
	sim._recalculate()
	_check(sim.state["dc_output"] < 1.0, "Overbuilding throttles data centres (output %.2f)" % sim.state["dc_output"])
	_check(not sim.state["blackout"], "Throttling protects homes from blackouts")
	game.ui.update_state(sim.state)
	await _screenshot("03-town")

	# Run to the end
	sim.state["money"] = 100000.0
	var guard := 0
	while not sim.state["finished"] and guard < 400:
		sim.step_month()
		guard += 1
		if game.ui.is_modal_open() and not sim.state["finished"]:
			game.ui.event_option_chosen.emit(0)
			game.ui.event_closed.emit()
			sim.paused = true
	_check(sim.state["finished"], "Game reaches an outcome (%s)" % sim.state["outcome"])
	_check(game.fired_events.size() == data.events.size() or sim.state["outcome"] != "completed", "Every event fired in a full game")
	await _screenshot("04-end")
	game.queue_free()
	await process_frame
	await _tutorial_test()
	print("%d checks, %d failures" % [checks, failures.size()])
	for f in failures:
		print("FAIL: " + f)
	quit(1 if failures.size() > 0 else 0)


## Walks the whole tutorial the way a player would.
func _tutorial_test() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var sim: SimulationManager = game.simulation
	sim.set_process(false)
	var t: Tutorial = game.tutorial
	game.ui.event_option_chosen.emit(0)
	_check(t.active and game.ui.is_coaching() and sim.paused, "Tutorial starts with time paused")
	await _screenshot("07-tutorial-map")
	game.ui.coach_next.emit()
	await _screenshot("08-tutorial-compute")
	game.ui.coach_next.emit()
	_check(t.step == 2, "Tutorial reaches the build step")
	game.ui.coach_next.emit()
	_check(t.step == 2, "Action steps ignore Next")
	game._on_build_selected("colocation")
	_check(t.step == 3 and game.town_map.in_bounds(t.suggested_cell), "Arming colocation shows a suggested site")
	game._on_cell_hovered(t.suggested_cell)
	await _screenshot("09-tutorial-place")
	game._cancel()
	_check(t.step == 2, "Cancelling placement steps back")
	game._on_build_selected("colocation")
	game._on_cell_clicked(t.suggested_cell)
	_check(t.step == 4 and sim.placed.size() == 1, "Building at the suggested site advances")
	_check(game.armed.is_empty(), "Placement mode ends after building")
	await _screenshot("10-tutorial-impact")
	game.ui.coach_next.emit()
	game._on_cell_clicked(t.suggested_cell)
	_check(t.step == 6, "Selecting the new centre advances")
	await _screenshot("11-tutorial-upgrade")
	game.ui.upgrade_requested.emit(t.built_uid, "waste_heat")
	_check(t.step == 7, "Buying an upgrade advances")
	await _screenshot("12-tutorial-advisor")
	game.ui.coach_next.emit()
	await _screenshot("13-tutorial-time")
	game.ui.coach_next.emit()
	_check(not t.active and not game.ui.is_coaching(), "Tutorial finishes")
	_check(game.ui.is_modal_open() and game.active_event.get("id") == "share_quiz", "First quiz follows the tutorial")
	game.ui.event_option_chosen.emit(2)
	game.ui.event_closed.emit()
	_check(not sim.paused, "Time runs after the tutorial and quiz")
	var tip: Array = game.advice(sim.state)
	_check(not String(tip[0]).is_empty(), "Advisor always has a suggestion")
	game.queue_free()
	await process_frame


func _find(kind: String) -> Vector2i:
	var map: TownMap = game.town_map
	for y in range(map.grid_size.y):
		for x in range(map.grid_size.x):
			var c := Vector2i(x, y)
			if map.terrain_at(c) == kind and not map.occupancy.has(c):
				return c
	return TownMap.NO_CELL


## An unoccupied open/industrial cell that touches homes, so noise matters.
func _find_isolated_open() -> Vector2i:
	var map: TownMap = game.town_map
	for y in range(map.grid_size.y):
		for x in range(map.grid_size.x):
			var c := Vector2i(x, y)
			if map.terrain_at(c) in ["open", "industrial"] and not map.occupancy.has(c):
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(0, 2)]:
					if map.terrain_at(c + d) == "residential":
						return c
	return TownMap.NO_CELL


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _screenshot(name: String) -> void:
	if not capture:
		return
	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-output"))
	root.get_texture().get_image().save_png("res://test-output/%s.png" % name)
