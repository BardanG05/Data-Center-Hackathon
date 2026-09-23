extends Node2D
class_name TownMap
## Top-down Bournemouth grid built from data/map.json over a faint satellite image.
## Owns terrain, occupancy, hover previews and the pan/zoom view.

signal cell_clicked(cell: Vector2i)
signal cell_hovered(cell: Vector2i)
signal cancel_clicked

const CELL := 40.0
const NO_CELL := Vector2i(-1, -1)
const SATELLITE_PATH := "res://assets/map/satellite.jpg"
const BUILDING_SCENE: PackedScene = preload("res://scenes/building.tscn")
const TERRAIN_CODES := {
	"r": "residential", "c": "town_centre", "o": "open", "i": "industrial",
	"g": "green", "w": "water", "h": "hospital", "s": "sea"}
const TERRAIN_NAMES := {
	"residential": "Homes", "town_centre": "Shops & offices", "open": "Open land",
	"industrial": "Industrial estate", "green": "Heath & parks (protected)",
	"water": "River & lakes", "hospital": "Hospital", "sea": "Poole Bay"}
const BUILDABLE_TINT := {
	"open": Color(0.72, 0.93, 0.45, 0.20), "industrial": Color(0.70, 0.78, 0.95, 0.26),
	"town_centre": Color(1.0, 0.78, 0.45, 0.20)}

var grid_size := Vector2i.ZERO
var terrain: Array[PackedStringArray] = []
var labels: Array = []
## cell -> uid of the building covering it.
var occupancy: Dictionary = {}
## Area of the screen the map may use (set by the game from the UI layout).
var view_rect := Rect2(0, 0, 1440, 900)

var _satellite: Texture2D
var _buildings: Node2D
var _nodes: Dictionary = {}
var _hover := NO_CELL
var _preview: Dictionary = {}
var _selected_uid := -1
var _noise: Dictionary = {}
var _dragging := false
var _drag_moved := false
var _min_zoom := 0.3


func setup(map_data: Dictionary) -> void:
	grid_size = Vector2i(int(map_data["width"]), int(map_data["height"]))
	terrain.clear()
	for row: String in map_data["rows"]:
		var cells := PackedStringArray()
		for code in row:
			cells.append(TERRAIN_CODES.get(code, "residential"))
		terrain.append(cells)
	labels = map_data.get("labels", [])
	if ResourceLoader.exists(SATELLITE_PATH):
		_satellite = load(SATELLITE_PATH)
	if not is_instance_valid(_buildings):
		_buildings = Node2D.new()
		_buildings.name = "Buildings"
		add_child(_buildings)
	fit_to_view()
	queue_redraw()


func terrain_at(cell: Vector2i) -> String:
	return terrain[cell.y][cell.x] if in_bounds(cell) else ""


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y


func home_cells() -> Array[Vector2i]:
	var homes: Array[Vector2i] = []
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			if terrain[y][x] == "residential":
				homes.append(Vector2i(x, y))
	return homes


## Why a footprint cannot be used, or "" if it can.
func placement_problem(cell: Vector2i, size: Vector2i, allowed: Array) -> String:
	for dy in range(size.y):
		for dx in range(size.x):
			var c := cell + Vector2i(dx, dy)
			if not in_bounds(c):
				return "That doesn't fit inside the map."
			if occupancy.has(c):
				return "Something is already built there."
			var kind := terrain_at(c)
			if not kind in allowed:
				return "%s can't be built on. Try %s." % [TERRAIN_NAMES[kind], _allowed_words(allowed)]
	return ""


func place(record: Dictionary, definition: Dictionary) -> void:
	var node: Node2D = BUILDING_SCENE.instantiate()
	node.position = Vector2(record["cell"]) * CELL
	node.configure(definition, record)
	_buildings.add_child(node)
	_nodes[record["uid"]] = node
	for dy in range(record["size"].y):
		for dx in range(record["size"].x):
			occupancy[record["cell"] + Vector2i(dx, dy)] = record["uid"]
	queue_redraw()


func remove(uid: int) -> void:
	for cell in occupancy.keys():
		if occupancy[cell] == uid:
			occupancy.erase(cell)
	if _nodes.has(uid):
		_nodes[uid].queue_free()
		_nodes.erase(uid)
	queue_redraw()


func refresh_building(record: Dictionary) -> void:
	if _nodes.has(record["uid"]):
		_nodes[record["uid"]].update_record(record)


## Preview a building footprint and its noise radius under the cursor.
func set_preview(preview: Dictionary) -> void:
	_preview = preview
	queue_redraw()


func set_selected(uid: int) -> void:
	_selected_uid = uid
	queue_redraw()


## cell -> objection fraction 0..1, shown as an orange wash over homes.
func set_noise(noise: Dictionary) -> void:
	_noise = noise
	queue_redraw()


func cell_at_screen(screen_pos: Vector2) -> Vector2i:
	var local := (get_global_transform_with_canvas().affine_inverse() * screen_pos) / CELL
	return Vector2i(floori(local.x), floori(local.y))


func fit_to_view() -> void:
	var world := Vector2(grid_size) * CELL
	if world.x <= 0.0:
		return
	var zoom := minf(view_rect.size.x / world.x, view_rect.size.y / world.y)
	_min_zoom = zoom
	scale = Vector2.ONE * zoom
	position = view_rect.position + (view_rect.size - world * zoom) * 0.5


func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var new_zoom := clampf(scale.x * factor, _min_zoom, 2.2)
	var local := (screen_pos - position) / scale.x
	scale = Vector2.ONE * new_zoom
	position = screen_pos - local * new_zoom
	_clamp_view()


func _clamp_view() -> void:
	var world := Vector2(grid_size) * CELL * scale.x
	var lo := view_rect.end - world
	var hi := view_rect.position
	position.x = clampf(position.x, minf(lo.x, hi.x), maxf(lo.x, hi.x)) if world.x > view_rect.size.x else view_rect.position.x + (view_rect.size.x - world.x) * 0.5
	position.y = clampf(position.y, minf(lo.y, hi.y), maxf(lo.y, hi.y)) if world.y > view_rect.size.y else view_rect.position.y + (view_rect.size.y - world.y) * 0.5


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var inside := view_rect.has_point(event.position)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed and inside:
			_zoom_at(event.position, 1.15)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed and inside:
			_zoom_at(event.position, 1.0 / 1.15)
		elif event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if event.pressed and inside:
				_dragging = true
				_drag_moved = false
			elif not event.pressed and _dragging:
				_dragging = false
				if not _drag_moved and event.button_index == MOUSE_BUTTON_RIGHT:
					cancel_clicked.emit()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and inside:
			var cell := cell_at_screen(event.position)
			if in_bounds(cell):
				cell_clicked.emit(cell)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _dragging:
			position += event.relative
			_drag_moved = _drag_moved or event.relative.length() > 1.0
			_clamp_view()
		var cell := cell_at_screen(event.position) if view_rect.has_point(event.position) else NO_CELL
		if not in_bounds(cell):
			cell = NO_CELL
		if cell != _hover:
			_hover = cell
			cell_hovered.emit(cell)
			queue_redraw()


func _draw() -> void:
	var world := Rect2(Vector2.ZERO, Vector2(grid_size) * CELL)
	draw_rect(world.grow(6), Color("0b1a1f"))
	if _satellite:
		draw_texture_rect(_satellite, world, false, Color(1, 1, 1, 0.62))
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			_draw_cell(Vector2i(x, y))
	for cell: Vector2i in _noise.keys():
		var r := Rect2(Vector2(cell) * CELL, Vector2.ONE * CELL)
		draw_rect(r, Color(1.0, 0.45, 0.15, 0.12 + 0.55 * float(_noise[cell])))
	_draw_labels()
	if _selected_uid >= 0 and _nodes.has(_selected_uid):
		var node: Node2D = _nodes[_selected_uid]
		var size: Vector2i = node.record["size"]
		draw_rect(Rect2(node.position, Vector2(size) * CELL).grow(3), Color("ffd48b"), false, 3.0)
	_draw_preview()


func _draw_cell(cell: Vector2i) -> void:
	var kind := terrain_at(cell)
	var r := Rect2(Vector2(cell) * CELL, Vector2.ONE * CELL)
	match kind:
		"residential":
			draw_rect(r, Color(0.95, 0.80, 0.62, 0.10))
		"green":
			draw_rect(r, Color(0.20, 0.55, 0.28, 0.30))
		"hospital":
			draw_rect(r, Color(0.95, 0.97, 1.0, 0.55))
			draw_rect(Rect2(r.position + Vector2(16, 8), Vector2(8, 24)), Color("d9534f"))
			draw_rect(Rect2(r.position + Vector2(8, 16), Vector2(24, 8)), Color("d9534f"))
		"water":
			draw_rect(r, Color(0.25, 0.55, 0.85, 0.35))
		"sea":
			pass
		_:
			if BUILDABLE_TINT.has(kind):
				draw_rect(r, BUILDABLE_TINT[kind])
				draw_rect(r.grow(-2), Color(BUILDABLE_TINT[kind], 0.75), false, 1.5)
	if kind != "sea":
		draw_rect(r, Color(1, 1, 1, 0.05), false, 1.0)


func _draw_labels() -> void:
	var font := ThemeDB.fallback_font
	for label: Dictionary in labels:
		var pos := (Vector2(label["cell"][0], label["cell"][1]) + Vector2(0.5, 0.5)) * CELL
		var text: String = String(label["name"]).to_upper()
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var at := pos - Vector2(width * 0.5, -5)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0.04, 0.09, 0.10, 0.85))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.95, 0.97, 0.92, 0.9))


func _draw_preview() -> void:
	if _preview.is_empty() or not in_bounds(_preview.get("cell", NO_CELL)):
		if in_bounds(_hover):
			draw_rect(Rect2(Vector2(_hover) * CELL, Vector2.ONE * CELL), Color(1, 1, 1, 0.8), false, 2.0)
		return
	var cell: Vector2i = _preview["cell"]
	var size: Vector2i = _preview["size"]
	var radius: int = _preview.get("radius", 0)
	if radius > 0:
		var outer := Rect2(Vector2(cell - Vector2i.ONE * radius) * CELL, Vector2(size + Vector2i.ONE * radius * 2) * CELL).intersection(Rect2(Vector2.ZERO, Vector2(grid_size) * CELL))
		draw_rect(outer, Color(1.0, 0.55, 0.2, 0.10))
		draw_rect(outer, Color(1.0, 0.62, 0.3, 0.9), false, 2.0)
	var tint := Color("7be495") if _preview.get("ok", false) else Color("ff6b6b")
	var r := Rect2(Vector2(cell) * CELL, Vector2(size) * CELL)
	draw_rect(r, Color(tint, 0.35))
	draw_rect(r, tint, false, 3.0)


func _allowed_words(allowed: Array) -> String:
	var words: Array[String] = []
	for kind: String in allowed:
		words.append(String(TERRAIN_NAMES[kind]).to_lower())
	return " or ".join(words)
