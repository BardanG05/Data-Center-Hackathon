class_name Tutorial
extends Node
## Guided first minutes. Each step either waits for "Next" or for a player
## action reported through notify(). Time stays paused until it finishes.

signal finished

var active := false
var step := -1
var steps: Array[Dictionary] = []
var suggested_cell := Vector2i(-1, -1)
var built_uid := -1

var _game: Node


func start(game: Node) -> void:
	_game = game
	active = true
	step = -1
	built_uid = -1
	steps = _build_steps()
	_go(0)


func next() -> void:
	if active and steps[step]["wait"].is_empty():
		_go(step + 1)


## Player actions: "armed" (building id), "built" (record), "selected" (record or {}), "upgraded".
func notify(what: String, value: Variant = null) -> void:
	if not active:
		return
	var wait: String = steps[step]["wait"]
	match what:
		"armed":
			if wait == "armed" and value == "colocation":
				_go(step + 1)
			elif wait == "built" and value != "colocation":
				_go(step - 1)
		"built":
			if wait == "built" and value["id"] == "colocation":
				built_uid = value["uid"]
				_game.town_map.set_marker(Vector2i(-1, -1), Vector2i.ONE)
				_go(step + 1)
		"selected":
			if wait == "selected" and not value.is_empty() and value["uid"] == built_uid:
				_go(step + 1)
			elif wait == "upgraded" and (value.is_empty() or value["uid"] != built_uid):
				_go(step - 1)
		"upgraded":
			if wait == "upgraded":
				_go(step + 1)


func finish() -> void:
	if not active:
		return
	active = false
	_game.ui.hide_coach()
	_game.town_map.set_marker(Vector2i(-1, -1), Vector2i.ONE)
	finished.emit()


func _go(index: int) -> void:
	if index >= steps.size():
		finish()
		return
	step = index
	var s: Dictionary = steps[index]
	if s.has("enter"):
		s["enter"].call()
	var text: String = s["text"].call() if s["text"] is Callable else s["text"]
	_game.ui.show_coach("TUTORIAL · %d OF %d" % [index + 1, steps.size()], s["title"], text, s.get("button", ""), s["target"])


func _build_steps() -> Array[Dictionary]:
	var ui: TownUI = _game.ui
	var map: TownMap = _game.town_map
	var sim: SimulationManager = _game.simulation
	var data: GameData = _game.data
	return [
		{
			"title": "This is Bournemouth",
			"text": "Seen from above. The [b]bright squares[/b] are land you can build on: [color=#4a8a1c]green[/color] open land, [color=#3b5ea8]blue[/color] industrial estates and [color=#b07a12]orange[/color] shops and offices. Everything else is homes, protected heath or sea.",
			"button": "Next", "wait": "",
			"target": func() -> Rect2: return TownUI.MAP_RECT,
		},
		{
			"title": "Your town needs computing power",
			"text": func() -> String: return "Streaming, cloud storage, AI… Bournemouth needs [b]%d[/b] units of compute and makes [b]0[/b], so it pays %s every month to import it. Demand will grow about %sx by 2034, like it did in Ireland." % [
				roundi(sim.state["compute_demand"]), GameData.money(sim.state["import_cost"]), data.facts["growth_2034"]],
			"button": "Next", "wait": "",
			"target": func() -> Rect2: return ui.stat_rect("compute"),
		},
		{
			"title": "Build your first data centre",
			"text": "Click [b]Colocation data centre[/b]. It's the middle size: good compute for its price.",
			"wait": "armed",
			"target": func() -> Rect2: return ui.build_button_rect("colocation"),
		},
		{
			"title": "Pick a quiet spot",
			"text": "Move the mouse over the map. The [color=#c2561a]orange square[/color] shows how far the noise reaches, and homes inside it may object. The side panel shows how many.\n\nThe [b]gold ring[/b] marks a quiet site. Click it, or any bright tile.",
			"wait": "built",
			"enter": _enter_place,
			"target": func() -> Rect2: return map.cell_screen_rect(suggested_cell, Vector2i.ONE),
		},
		{
			"title": "Demand met, but at a cost",
			"text": func() -> String: return "Compute is covered and you've stopped paying for imports. But the centre uses electricity and water, and about [b]%s neighbours object[/b], so [b]public acceptance[/b] is heading to %d%%.\n\nIf acceptance falls below %d%%, the council stops you." % [
				GameData.thousands(sim.state["objectors"]), roundi(sim.state["acceptance_target"]), roundi(float(data.scenario["lose_acceptance"]))],
			"button": "Next", "wait": "",
			"target": func() -> Rect2: return ui.stat_rect("acceptance"),
		},
		{
			"title": "Win your neighbours over",
			"text": "Click your new data centre on the map.",
			"wait": "selected",
			"target": _built_rect,
		},
		{
			"title": "Buy an upgrade",
			"text": "Upgrades are the conditions survey respondents said would make them accept a data centre. Buy [b]Waste heat to homes[/b]: %s%% of respondents picked it, so it wins over that share of objectors." % data.facts["pct_waste_heat"],
			"wait": "upgraded",
			"target": func() -> Rect2: return ui.actions_rect(),
		},
		{
			"title": "Stuck? Look here",
			"text": "This bar always shows the most useful thing to do next. It turns [color=#b07a12]amber[/color] or [color=#c0392b]red[/color] when something needs attention. Hover any stat card for an explanation.",
			"button": "Next", "wait": "",
			"target": func() -> Rect2: return TownUI.ADVISOR_RECT,
		},
		{
			"title": "Time starts now",
			"text": "Each month takes 1.5 seconds. Pause with [b]Space[/b], or speed up with 2× and 4×. News headlines will pop up with quick quizzes.\n\nReach 2034 without going bankrupt or losing the public. Good luck!",
			"button": "Start playing", "wait": "",
			"target": func() -> Rect2: return ui.speed_rect(),
		},
	]


func _enter_place() -> void:
	suggested_cell = _game.building_manager.suggest_site("colocation")
	_game.town_map.set_marker(suggested_cell, Vector2i.ONE)


func _built_rect() -> Rect2:
	var record: Dictionary = _game.simulation.get_record(built_uid)
	if record.is_empty():
		return Rect2()
	return _game.town_map.cell_screen_rect(record["cell"], record["size"])
