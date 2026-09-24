extends SceneTree
## Balance check: plays whole games with simple bot strategies and prints outcomes.
## godot --headless --path . --script res://tests/balance.gd

var game: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for strategy in ["idle", "careful", "greedy_hyperscale"]:
		game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		await process_frame
		var sim: SimulationManager = game.simulation
		sim.set_process(false)
		game.set_process(false)
		game.ui.event_option_chosen.emit(1)
		var log := []
		var guard := 0
		while not sim.state["finished"] and guard < 300:
			if game.ui.is_modal_open():
				game.ui.event_option_chosen.emit(0)
				game.ui.event_closed.emit()
			sim.paused = false
			_play(strategy, sim)
			sim.step_month()
			if int(sim.state["month"]) == 1 and int(sim.state["year"]) % 3 == 0:
				log.append("%d: £%d acc %d%% compute %d/%d elec %d/%d water %d/%d dcs %d" % [sim.state["year"], sim.state["money"], sim.state["acceptance"],
					sim.state["compute_local"], sim.state["compute_demand"], sim.state["electricity_used"], sim.state["electricity_supply"],
					sim.state["water_used"], sim.state["water_supply"], sim.state["dc_count"]])
			guard += 1
		var summary: Dictionary = game.summary()
		print("== %s → %s %d-%02d score %d (%s) coverage %d%%" % [strategy, sim.state["outcome"], sim.state["year"], sim.state["month"], summary["score"], summary["grade"], summary["coverage"] * 100])
		for line in log:
			print("   " + line)
		game.queue_free()
		await process_frame
	quit()


func _play(strategy: String, sim: SimulationManager) -> void:
	var s := sim.state
	if strategy == "idle":
		return
	var bm: BuildingManager = game.building_manager
	if strategy == "greedy_hyperscale":
		# Biggest affordable centre, first valid site, no infrastructure or upgrades.
		for id in ["hyperscale", "colocation"]:
			if s["compute_capacity"] < s["compute_demand"] * 1.5 and sim.can_afford(sim.build_cost(id)):
				var cell := _first_cell(id)
				if cell != TownMap.NO_CELL:
					bm.try_build(cell, id)
					return
		return
	# careful: power and water headroom first, then the quietest site, then upgrades.
	var want := "colocation" if s["year"] < 2024 else "hyperscale"
	var def: Dictionary = game.data.buildings[want]
	var e_head := float(s["electricity_supply"]) - float(s["electricity_town"]) - float(s["electricity_dc_demand"])
	if s["compute_capacity"] < s["compute_demand"]:
		var draw := float(def["electricity_usage"]) * (0.5 if sim.has_flag("renewable_rule") else 1.0)
		if e_head < draw:
			if sim.can_afford(900):
				var c := _best_cell("solar_farm", true)
				if c != TownMap.NO_CELL:
					bm.try_build(c, "solar_farm")
			return
		if float(s["water_used"]) + float(def["water_usage"]) > float(s["water_supply"]):
			if sim.can_afford(900):
				var c := _best_cell("water_works", true)
				if c != TownMap.NO_CELL:
					bm.try_build(c, "water_works")
			return
		if sim.can_afford(sim.build_cost(want)):
			var cell := _best_cell(want, false)
			if cell != TownMap.NO_CELL:
				bm.try_build(cell, want)
				return
	if float(s["acceptance_target"]) < 45.0:
		var worst := {}
		var worst_obj := 0.0
		for record in sim.placed:
			var obj: float = sim.exposure_of(record)["objectors"]
			if obj > worst_obj and record["upgrades"].size() < 4:
				worst = record
				worst_obj = obj
		if not worst.is_empty():
			for up in ["waste_heat", "local_jobs", "community_fund", "renewable"]:
				if not up in worst["upgrades"] and sim.can_afford(sim.upgrade_cost(worst, up) + 300):
					sim.buy_upgrade(worst["uid"], up)
					break


func _first_cell(id: String) -> Vector2i:
	var map: TownMap = game.town_map
	for y in range(map.grid_size.y):
		for x in range(map.grid_size.x):
			if game.building_manager.preview(Vector2i(x, y), id)["ok"]:
				return Vector2i(x, y)
	return TownMap.NO_CELL


## Buildable cell with the fewest new objectors (or the most isolated for infrastructure).
func _best_cell(id: String, infrastructure: bool) -> Vector2i:
	var map: TownMap = game.town_map
	var best := TownMap.NO_CELL
	var best_score := INF
	for y in range(map.grid_size.y):
		for x in range(map.grid_size.x):
			var c := Vector2i(x, y)
			var p: Dictionary = game.building_manager.preview(c, id)
			if not p["ok"]:
				continue
			var score: float = 0.0 if infrastructure else p.get("new_objectors", 0.0) / 400.0 * 10.0 / game.data.scenario["residents"] * 400.0 + p["greenfield_tiles"] * game.simulation.greenfield_penalty_per_tile()
			if score < best_score:
				best_score = score
				best = c
	return best
