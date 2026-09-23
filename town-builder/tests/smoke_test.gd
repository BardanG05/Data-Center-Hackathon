extends SceneTree
## Run after import: godot --headless --path . --script res://tests/smoke_test.gd
## Add -- --capture in a rendered run to save screenshots of the tested UI.

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
	game.simulation.set_process(false)
	var sim: SimulationManager = game.simulation
	var map: TownMap = game.town_map
	var initial: Dictionary = sim.state.duplicate(true)
	var definition: Dictionary = game.data.buildings["data_centre"]
	_check(not initial.is_empty(), "JSON loaded and game initialized")
	_check(sim.placed_buildings.is_empty() and initial["compute_capacity"] == 0, "Town starts without a data centre")
	_check(not map.occupancy.is_empty(), "Existing town buildings occupy land")
	await _screenshot("01-town")
	var free_cells: Array[Vector2i] = []
	for x in range(map.grid_size.x):
		for y in range(map.grid_size.y):
			var cell := Vector2i(x, y)
			var point := map.cell_to_world(cell)
			_check(map.world_to_cell(point) == cell, "Tile %s round trip" % cell)
			_check(map.world_to_cell(point + Vector2(20, 0)) == cell, "Diamond interior %s" % cell)
			if map.is_buildable(cell):
				free_cells.append(cell)
	_check(free_cells.size() >= 2, "At least two free plots are available")
	for cell in [Vector2i(-1, 0), Vector2i(10, 10), Vector2i(4, 5), Vector2i(9, 9)]:
		var rejected: Dictionary = game.building_manager.try_build(cell, "data_centre")
		_check(not rejected["ok"], "Invalid land rejected: %s" % cell)
	_check(sim.state == initial, "Invalid land leaves all simulation state unchanged")
	var unknown: Dictionary = game.building_manager.try_build(free_cells[0], "unknown")
	_check(not unknown["ok"], "Unknown building rejected")
	# Exercise actual viewport input and UI signals, rather than bypassing the menu.
	await _click(map.cell_to_world(free_cells[0]))
	_check(game.selected_cell == free_cells[0], "Clicking grass selects the correct tile")
	_check(game.ui.build_button.is_visible_in_tree(), "Grass click opens the build menu")
	await _screenshot("02-build-menu")
	await _click(game.ui.cancel_button.get_global_rect().get_center())
	_check(game.selected_cell == Vector2i(-1, -1), "Cancel button clears selection")
	_check(sim.state == initial, "Cancel costs nothing")
	await _click(map.cell_to_world(free_cells[0]))
	await _click(game.ui.build_button.get_global_rect().get_center())
	_check(sim.placed_buildings.size() == 1, "Build button places exactly one data centre")
	_check(not map.is_buildable(free_cells[0]), "New building occupies its tile")
	_check(sim.state["money"] == initial["money"] - definition["cost"], "Cost deducted exactly once")
	_check(sim.state["electricity_used"] == initial["electricity_used"] + definition["electricity_usage"], "Electricity increases by JSON usage")
	_check(sim.state["water_used"] == initial["water_used"] + definition["water_usage"], "Water increases by JSON usage")
	_check(sim.state["compute_capacity"] == initial["compute_capacity"] + definition["compute_capacity"], "Compute increases by JSON capacity")
	await _screenshot("03-data-centre-online")
	var after_build: Dictionary = sim.state.duplicate(true)
	var duplicate: Dictionary = game.building_manager.try_build(free_cells[0], "data_centre")
	_check(not duplicate["ok"] and sim.state == after_build, "Duplicate placement cannot charge twice")
	var occupied_count: int = map.occupancy.size()
	var poor: Dictionary = game.building_manager.try_build(free_cells[1], "data_centre")
	_check(not poor["ok"] and sim.state == after_build, "Insufficient funds leaves state unchanged")
	_check(map.occupancy.size() == occupied_count and map.is_buildable(free_cells[1]), "Failed purchase does not occupy a tile")
	await _click(map.cell_to_world(free_cells[1]))
	_check(game.ui.build_button.disabled, "Unaffordable build button is disabled")
	await _screenshot("04-insufficient-funds")
	game._cancel_selection()
	var ticks_before: int = sim.state["tick_count"]
	sim.advance(0.4)
	_check(sim.state["tick_count"] == ticks_before, "Partial second does not update simulation")
	sim.advance(0.7)
	_check(sim.state["tick_count"] == ticks_before + 1, "Accumulated time triggers a fixed tick")
	sim.advance(3.0)
	_check(sim.state["tick_count"] == ticks_before + 4, "Slow frames preserve every simulation tick")
	_check(sim.state["electricity_used"] == after_build["electricity_used"] and sim.state["water_used"] == after_build["water_used"], "Repeated ticks do not accumulate resource usage")
	_check(sim.state["money"] == after_build["money"], "Ticks do not repeatedly charge the build cost")
	# Verify the live process loop, not just manual advance.
	sim.set_process(true)
	await create_timer(1.15).timeout
	sim.set_process(false)
	_check(sim.state["tick_count"] >= ticks_before + 5, "Live simulation advances without player input")
	var reset_scene: PackedScene = load("res://scenes/main.tscn")
	root.remove_child(game)
	game.free()
	game = reset_scene.instantiate()
	root.add_child(game)
	await process_frame
	game.simulation.set_process(false)
	_check(game.simulation.state["money"] == initial["money"] and game.simulation.placed_buildings.is_empty(), "Fresh scene resets funds and buildings")
	_check(game.town_map.is_buildable(free_cells[0]), "Fresh scene resets occupancy")
	if failures.is_empty():
		print("PASS: %d MVP checks, including viewport clicks and live ticks." % checks)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		printerr("%d failures from %d checks." % [failures.size(), checks])
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var button := InputEventMouseButton.new()
	button.position = point
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = true
	root.push_input(button, true)
	await process_frame
	button = button.duplicate()
	button.pressed = false
	root.push_input(button, true)
	await process_frame


func _screenshot(filename: String) -> void:
	if not capture:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://test-output")
	var result := root.get_texture().get_image().save_png("res://test-output/%s.png" % filename)
	_check(result == OK, "Screenshot saved: " + filename)
