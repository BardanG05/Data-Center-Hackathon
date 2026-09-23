class_name TownUI
extends CanvasLayer

signal build_requested
signal cancel_requested
signal restart_requested

const INK := Color("142d30")
const PANEL := Color("203c3f")
const CARD := Color("29474a")
const TEXT := Color("f1f5eb")
const MUTED := Color("acc2bb")
const GREEN := Color("a6e6b2")
const AMBER := Color("ffd48b")

var build_button: Button
var cancel_button: Button
var _root: Control
var _values: Dictionary = {}
var _details: Dictionary = {}
var _definition: Dictionary = {}
var _menu: Control
var _intro: Control
var _selection_badge: Label
var _message: Label
var _footer: Label
var _build_name: Label
var _build_description: Label
var _build_cost: Label
var _build_impact: Label


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_label("CAIRNBRIDGE", Vector2(30, 23), Vector2(720, 42), 30, TEXT)
	_label("IRELAND  /  SMALL TOWN, BIG DECISIONS", Vector2(32, 63), Vector2(700, 22), 12, MUTED)
	_label("LIVE TOWN MODEL", Vector2(1022, 38), Vector2(210, 25), 12, GREEN)
	var restart := _button("Restart town", Vector2(1252, 28), Vector2(160, 43), false)
	restart.pressed.connect(func() -> void: restart_requested.emit())
	var names := ["MONEY", "GRID", "WATER", "COMPUTE", "POPULATION"]
	var keys := ["money", "electricity", "water", "compute", "population"]
	for i in range(names.size()):
		var x := 28.0 + i * 280.0
		_panel(Vector2(x, 106), Vector2(264, 101), CARD)
		_label(names[i], Vector2(x + 18, 119), Vector2(228, 20), 12, MUTED)
		_values[keys[i]] = _label("—", Vector2(x + 18, 142), Vector2(228, 32), 26, TEXT)
		_details[keys[i]] = _label("", Vector2(x + 18, 178), Vector2(228, 18), 11, MUTED)
	_panel(Vector2(1060, 228), Vector2(352, 584), PANEL)
	_label("TOWN BRIEF", Vector2(1084, 251), Vector2(304, 24), 13, GREEN)
	_selection_badge = _label("NO LAND SELECTED", Vector2(1084, 285), Vector2(304, 23), 12, MUTED)
	_intro = _container(Vector2(1084, 337), Vector2(304, 275))
	_label("Make room for\na connected town.", Vector2.ZERO, Vector2(300, 92), 28, TEXT, _intro)
	_label("Select an empty grass tile to explore your first data centre.", Vector2(0, 113), Vector2(295, 66), 17, MUTED, _intro)
	_label("Every new centre uses money, electricity and water, while adding compute capacity.", Vector2(0, 196), Vector2(295, 89), 15, MUTED, _intro)
	_menu = _container(Vector2(1084, 330), Vector2(304, 378))
	_build_name = _label("Data Centre", Vector2.ZERO, Vector2(304, 65), 26, TEXT, _menu)
	_build_description = _label("", Vector2(0, 75), Vector2(304, 69), 14, MUTED, _menu)
	_build_cost = _label("", Vector2(0, 154), Vector2(304, 38), 28, TEXT, _menu)
	_build_impact = _label("", Vector2(0, 207), Vector2(304, 65), 16, MUTED, _menu)
	build_button = _button("Build Data Centre", Vector2(0, 284), Vector2(304, 47), true, _menu)
	build_button.pressed.connect(func() -> void: build_requested.emit())
	cancel_button = _button("Cancel selection", Vector2(0, 340), Vector2(304, 38), false, _menu)
	cancel_button.pressed.connect(func() -> void: cancel_requested.emit())
	_menu.hide()
	_message = _label("Tip: choose a clear grass tile on the map.", Vector2(1084, 734), Vector2(304, 57), 14, GREEN)
	_label("Fictional balancing values • supplied datasets not integrated yet", Vector2(30, 844), Vector2(820, 25), 13, MUTED)
	_footer = _label("00:00  /  TICK 0", Vector2(914, 844), Vector2(498, 25), 13, MUTED)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label("SELECT A GRASS TILE TO BUILD", Vector2(32, 217), Vector2(800, 21), 11, MUTED)


func configure(definition: Dictionary) -> void:
	_definition = definition.duplicate(true)
	_build_name.text = str(definition.get("name", "Data Centre"))
	_build_description.text = str(definition.get("description", "Local infrastructure for a more connected town."))
	_build_cost.text = "€%s" % _number(definition.get("cost", 0))
	_build_impact.text = "+%s electricity use\n+%s water use\n+%s compute capacity" % [
		_number(definition.get("electricity_usage", 0)),
		_number(definition.get("water_usage", 0)),
		_number(definition.get("compute_capacity", 0))]
	build_button.text = "Build Data Centre"


func update_resources(state: Dictionary) -> void:
	_values.money.text = "€%s" % _number(state.get("money", 0))
	_values.electricity.text = "%s / %s" % [_number(state.get("electricity_used", 0)), _number(state.get("electricity_capacity", 0))]
	_values.water.text = "%s / %s" % [_number(state.get("water_used", 0)), _number(state.get("water_capacity", 0))]
	_values.compute.text = "%s / %s" % [_number(state.get("compute_capacity", 0)), _number(state.get("compute_demand", 0))]
	_values.population.text = _number(state.get("population", 0))
	_details.money.text = "AVAILABLE BUDGET"
	_details.electricity.text = "USE / GRID CAPACITY · UNITS"
	_details.water.text = "USE / SUPPLY · UNITS"
	_details.population.text = "RESIDENTS"
	var demand_met := float(state.get("compute_capacity", 0)) >= float(state.get("compute_demand", 0))
	_details.compute.text = "CAPACITY / DEMAND · %s" % ("MET" if demand_met else "LOW")
	_values.compute.add_theme_color_override("font_color", GREEN if demand_met else AMBER)
	_values.electricity.add_theme_color_override("font_color", AMBER if float(state.get("electricity_used", 0)) > float(state.get("electricity_capacity", 0)) else TEXT)
	_values.water.add_theme_color_override("font_color", AMBER if float(state.get("water_used", 0)) > float(state.get("water_capacity", 0)) else TEXT)
	var seconds := int(state.get("elapsed_seconds", 0))
	_footer.text = "%d CENTRES   /   %02d:%02d   /   TICK %d" % [int(state.get("building_count", 0)), seconds / 60, seconds % 60, int(state.get("tick_count", 0))]


func show_build_menu(cell: Vector2i, can_afford: bool) -> void:
	_selection_badge.text = "SELECTED LAND  /  %02d, %02d" % [cell.x + 1, cell.y + 1]
	_selection_badge.add_theme_color_override("font_color", GREEN)
	_intro.hide()
	_menu.show()
	build_button.disabled = not can_afford
	show_message("Ready to connect this plot to the town." if can_afford else "Insufficient money for this centre.", not can_afford)


func close_build_menu() -> void:
	_menu.hide()
	_intro.show()
	_selection_badge.text = "NO LAND SELECTED"
	_selection_badge.add_theme_color_override("font_color", MUTED)


func show_message(message: String, is_error: bool = false) -> void:
	_message.text = message
	_message.add_theme_color_override("font_color", AMBER if is_error else GREEN)


func _number(value: Variant) -> String:
	var digits := str(int(value))
	var formatted := ""
	for i in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0 and digits[i - 1] != "-":
			formatted += ","
		formatted += digits[i]
	return formatted


func _container(pos: Vector2, dimensions: Vector2) -> Control:
	var control := Control.new()
	control.position = pos
	control.size = dimensions
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(control)
	return control


func _panel(pos: Vector2, dimensions: Vector2, color: Color) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = dimensions
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _style(color, 13))
	_root.add_child(panel)
	return panel


func _label(value: String, pos: Vector2, dimensions: Vector2, font_size: int, color: Color, parent: Control = null) -> Label:
	var label := Label.new()
	# Set wrapping before assigning text/size; otherwise the initial unwrapped
	# minimum width can expand long labels beyond their allocated panel.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = value
	label.position = pos
	label.size = dimensions
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", ThemeDB.fallback_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	(parent if parent != null else _root).add_child(label)
	return label


func _button(value: String, pos: Vector2, dimensions: Vector2, primary: bool, parent: Control = null) -> Button:
	var button := Button.new()
	button.text = value
	button.position = pos
	button.size = dimensions
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", INK if primary else TEXT)
	button.add_theme_color_override("font_hover_color", INK if primary else TEXT)
	button.add_theme_color_override("font_pressed_color", INK if primary else TEXT)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("normal", _style(GREEN if primary else CARD, 9))
	button.add_theme_stylebox_override("hover", _style(Color("c4f4ce") if primary else Color("38575a"), 9))
	button.add_theme_stylebox_override("pressed", _style(Color("86c996") if primary else PANEL, 9))
	button.add_theme_stylebox_override("disabled", _style(Color("3f5351"), 9))
	(parent if parent != null else _root).add_child(button)
	return button


func _style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style
