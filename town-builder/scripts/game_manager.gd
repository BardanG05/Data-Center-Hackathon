extends Node
## Scene composition and signal wiring only.

@onready var data: GameData = $DataCatalog
@onready var simulation: SimulationManager = $SimulationManager
@onready var building_manager: BuildingManager = $BuildingManager
@onready var town_map: TownMap = $TownMap
@onready var ui: TownUI = $UI

var selected_cell := Vector2i(-1, -1)


func _ready() -> void:
	ui.restart_requested.connect(func() -> void: get_tree().reload_current_scene())
	if not data.load_all():
		ui.show_message("Cannot load game data: " + data.error_message, true)
		push_error(data.error_message)
		return
	ui.configure(data.buildings["data_centre"])
	simulation.state_changed.connect(ui.update_resources)
	simulation.initialize(data.scenario)
	building_manager.configure(town_map, simulation, data)
	town_map.tile_selected.connect(_on_tile_selected)
	ui.build_requested.connect(_on_build_requested)
	ui.cancel_requested.connect(_cancel_selection)


func _on_tile_selected(cell: Vector2i) -> void:
	if not town_map.is_buildable(cell):
		_cancel_selection()
		ui.show_message(town_map.describe_cell(cell) + " Choose an empty grass tile.")
		return
	selected_cell = cell
	town_map.set_selection(cell)
	var cost := float(data.buildings["data_centre"]["cost"])
	ui.show_build_menu(cell, simulation.can_afford(cost))


func _on_build_requested() -> void:
	var result := building_manager.try_build(selected_cell, "data_centre")
	if result["ok"]:
		_cancel_selection()
	ui.show_message(result["message"], not result["ok"])


func _cancel_selection() -> void:
	selected_cell = Vector2i(-1, -1)
	town_map.clear_selection()
	ui.close_build_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_cancel_selection()
		get_viewport().set_input_as_handled()
