extends SceneTree
## Scripted playthrough for visual review. Rendered run only:
## godot --path . --script res://tests/playthrough.gd

var game: Node
var shots := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var sim: SimulationManager = game.simulation
	sim.set_process(false)
	game.set_process(false)
	game.ui.event_option_chosen.emit(1)   # skip tutorial
	await _shot("after-welcome")
	# First mandatory press conference after 60 s of play.
	game._advance_quiz_timer(61.0)
	await _shot("quiz")
	game.ui.event_option_chosen.emit(0)
	await _shot("quiz-reveal")
	game.ui.event_closed.emit()
	var quizzes := 1
	var log: Array[String] = []
	var seconds := 0.0
	while not sim.state["finished"]:
		if game.ui.is_modal_open():
			if game.active_event.get("id") == "renewable_rule" and not game._event_answered:
				await _shot("policy")
			if not game._event_answered:
				game.ui.event_option_chosen.emit(0)
			game.ui.event_closed.emit()
			continue
		_play(sim)
		sim.step_month()
		seconds += 1.5
		if not game.ui.is_modal_open():
			game._advance_quiz_timer(1.5)
			if game.ui.is_modal_open() and game.active_event.get("kind") == "quiz":
				quizzes += 1
		if sim.state["month"] == 1:
			log.append("%d £%s acc %d compute %d/%d e %d/%d w %d/%d" % [sim.state["year"], GameData.money(sim.state["money"]), sim.state["acceptance"],
				sim.state["compute_local"], sim.state["compute_demand"], sim.state["electricity_used"], sim.state["electricity_supply"], sim.state["water_used"], sim.state["water_supply"]])
			if sim.state["year"] in [2020, 2027]:
				game.ui.update_state(sim.state)
				await _shot("year-%d" % sim.state["year"])
				if not sim.placed.is_empty():
					game._select(sim.placed[-1]["uid"])
					await _shot("selected-%d" % sim.state["year"])
					game._select(-1)
	await _shot("end")
	game.ui.attitude_chosen.emit("Somewhat positive")
	await _shot("end-attitude")
	for line in log:
		print(line)
	print("outcome %s, %d quizzes at 1x (%.0f s of play)" % [sim.state["outcome"], quizzes, seconds])
	quit()


## A reasonable human: keep demand met at quiet sites, add power and water first, upgrade when acceptance slips.
func _play(sim: SimulationManager) -> void:
	var s := sim.state
	var bm: BuildingManager = game.building_manager
	var want := "colocation" if s["year"] < 2025 else "hyperscale"
	var def: Dictionary = game.data.buildings[want]
	var e_head := float(s["electricity_supply"]) - float(s["electricity_town"]) - float(s["electricity_dc_demand"])
	if s["compute_capacity"] < s["compute_demand"]:
		var draw := float(def["electricity_usage"]) * (0.5 if sim.has_flag("renewable_rule") else 1.0)
		if e_head < draw:
			var c := bm.suggest_site("solar_farm")
			if c != TownMap.NO_CELL and sim.can_afford(bm.preview(c, "solar_farm")["cost"]):
				bm.try_build(c, "solar_farm")
			return
		if float(s["water_used"]) + float(def["water_usage"]) > float(s["water_supply"]):
			var c := bm.suggest_site("water_works")
			if c != TownMap.NO_CELL and sim.can_afford(bm.preview(c, "water_works")["cost"]):
				bm.try_build(c, "water_works")
			return
		var cell := bm.suggest_site(want)
		if cell != TownMap.NO_CELL:
			bm.try_build(cell, want)
			return
	if float(s["acceptance_target"]) < 45.0:
		for record in sim.placed:
			if game.data.buildings[record["id"]]["category"] != "data_centre":
				continue
			for up in ["waste_heat", "local_jobs", "community_fund"]:
				if not up in record["upgrades"] and sim.can_afford(sim.upgrade_cost(record, up) + 300):
					sim.buy_upgrade(record["uid"], up)
					return


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	shots += 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-output/play"))
	root.get_texture().get_image().save_png("res://test-output/play/%02d-%s.png" % [shots, name])
