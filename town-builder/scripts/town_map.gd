extends Node2D
class_name TownMap

signal tile_selected(cell: Vector2i)

const BUILDING_SCENE: PackedScene = preload("res://scenes/building.tscn")
const TILE_SIZE: Vector2 = Vector2(88, 44)
const MAP_ORIGIN: Vector2 = Vector2(520, 302)
const NO_CELL: Vector2i = Vector2i(-1, -1)
const EXTRUSION: float = 12.0

var grid_size: Vector2i = Vector2i(10, 10)
var occupancy: Dictionary = {}
var _selection: Vector2i = NO_CELL
var _hover: Vector2i = NO_CELL
var _buildings: Node2D


func _ready() -> void:
	_buildings = Node2D.new()
	_buildings.name = "Buildings"
	_buildings.y_sort_enabled = true
	add_child(_buildings)
	_seed_town()
	queue_redraw()


func cell_to_world(cell: Vector2i) -> Vector2:
	return MAP_ORIGIN + Vector2(float(cell.x - cell.y) * TILE_SIZE.x * 0.5, float(cell.x + cell.y) * TILE_SIZE.y * 0.5)


func world_to_cell(pos: Vector2) -> Vector2i:
	var relative: Vector2 = pos - MAP_ORIGIN
	var grid_x: float = relative.x / TILE_SIZE.x + relative.y / TILE_SIZE.y
	var grid_y: float = relative.y / TILE_SIZE.y - relative.x / TILE_SIZE.x
	return Vector2i(int(floor(grid_x + 0.5)), int(floor(grid_y + 0.5)))


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y


func is_buildable(cell: Vector2i) -> bool:
	return _in_bounds(cell) and not occupancy.has(cell)


func set_selection(cell: Vector2i) -> void:
	_selection = cell if _in_bounds(cell) else NO_CELL
	queue_redraw()


func clear_selection() -> void:
	_selection = NO_CELL
	queue_redraw()


func place_building(cell: Vector2i, definition: Dictionary) -> Node2D:
	if not is_buildable(cell) or not is_instance_valid(_buildings):
		return null
	var building: Node2D = BUILDING_SCENE.instantiate()
	building.position = cell_to_world(cell)
	building.configure(definition)
	_buildings.add_child(building)
	occupancy[cell] = {
		"kind": String(definition.get("id", definition.get("visual_kind", "building"))),
		"name": String(definition.get("name", "Building")),
		"building": building
	}
	queue_redraw()
	return building


func describe_cell(cell: Vector2i) -> String:
	if not _in_bounds(cell):
		return "Outside the town"
	if occupancy.has(cell):
		return String(occupancy[cell].get("name", "Occupied land"))
	return "Available land"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var local_position: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var candidate: Vector2i = world_to_cell(local_position)
		var next_hover: Vector2i = candidate if is_buildable(candidate) else NO_CELL
		if next_hover != _hover:
			_hover = next_hover
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_position: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var cell: Vector2i = world_to_cell(local_position)
		if _in_bounds(cell):
			tile_selected.emit(cell)
			get_viewport().set_input_as_handled()


func _seed_town() -> void:
	for x: int in range(grid_size.x):
		for y: int in range(grid_size.y):
			var cell: Vector2i = Vector2i(x, y)
			if _is_water(cell):
				occupancy[cell] = {"kind": "water", "name": "River · protected water"}
			elif _is_road(cell):
				occupancy[cell] = {"kind": "road", "name": "Town road"}
	var starting_buildings: Array[Dictionary] = [
		{"cell": Vector2i(0, 1), "visual_kind": "house", "name": "Willow House", "color": "#eed2ad"},
		{"cell": Vector2i(1, 1), "visual_kind": "house", "name": "Maple House", "color": "#e5c5b4"},
		{"cell": Vector2i(2, 1), "visual_kind": "house", "name": "Cedar House", "color": "#e4d7ad"},
		{"cell": Vector2i(1, 2), "visual_kind": "house", "name": "Birch House", "color": "#d8dcca"},
		{"cell": Vector2i(2, 3), "visual_kind": "school", "name": "Community school", "color": "#d5aa8b"},
		{"cell": Vector2i(6, 2), "visual_kind": "hospital", "name": "Town hospital", "color": "#e6e7d9"},
		{"cell": Vector2i(6, 3), "visual_kind": "business", "name": "Local businesses", "color": "#c9a98b"},
		{"cell": Vector2i(7, 3), "visual_kind": "business", "name": "Market offices", "color": "#9fb9b2"},
		{"cell": Vector2i(2, 7), "visual_kind": "grid", "name": "Electricity substation", "color": "#b1b7a3"},
		{"cell": Vector2i(7, 8), "visual_kind": "water", "name": "Water treatment works", "color": "#8ebbc1"},
		{"cell": Vector2i(0, 0), "visual_kind": "tree", "name": "Mature tree", "color": "#81a780"},
		{"cell": Vector2i(3, 0), "visual_kind": "tree", "name": "Mature tree", "color": "#759c78"},
		{"cell": Vector2i(0, 5), "visual_kind": "tree", "name": "Mature tree", "color": "#7fa67d"},
		{"cell": Vector2i(1, 8), "visual_kind": "tree", "name": "Mature tree", "color": "#83a974"},
		{"cell": Vector2i(5, 0), "visual_kind": "tree", "name": "Mature tree", "color": "#8db382"},
		{"cell": Vector2i(8, 1), "visual_kind": "tree", "name": "Mature tree", "color": "#759d7b"},
		{"cell": Vector2i(8, 6), "visual_kind": "tree", "name": "Mature tree", "color": "#82ac86"},
		{"cell": Vector2i(6, 9), "visual_kind": "tree", "name": "Mature tree", "color": "#82ac86"}
	]
	for definition: Dictionary in starting_buildings:
		var cell: Vector2i = definition["cell"]
		place_building(cell, definition)


func _is_road(cell: Vector2i) -> bool:
	return cell.x == 4 or cell.y == 4


func _is_water(cell: Vector2i) -> bool:
	return (cell.x == 9 and cell.y >= 6) or (cell.x == 8 and cell.y >= 8)


func _diamond(center: Vector2, inset: float = 0.0) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0, -22 + inset * 0.5),
		center + Vector2(44 - inset, 0),
		center + Vector2(0, 22 - inset * 0.5),
		center + Vector2(-44 + inset, 0)
	])


func _draw() -> void:
	# A restrained contact shadow lifts the whole map off the page.
	var edge_top: Vector2 = cell_to_world(Vector2i(0, 0)) + Vector2(0, -22)
	var edge_right: Vector2 = cell_to_world(Vector2i(grid_size.x - 1, 0)) + Vector2(44, 0)
	var edge_bottom: Vector2 = cell_to_world(grid_size - Vector2i.ONE) + Vector2(0, 22)
	var edge_left: Vector2 = cell_to_world(Vector2i(0, grid_size.y - 1)) + Vector2(-44, 0)
	draw_colored_polygon(PackedVector2Array([edge_top + Vector2(0, 13), edge_right + Vector2(10, 15), edge_bottom + Vector2(0, 23), edge_left + Vector2(-10, 15)]), Color(0.11, 0.24, 0.20, 0.08))
	for diagonal: int in range(grid_size.x + grid_size.y - 1):
		for x: int in range(grid_size.x):
			var y: int = diagonal - x
			if y >= 0 and y < grid_size.y:
				_draw_tile(Vector2i(x, y))
	if is_buildable(_hover) and _hover != _selection:
		_draw_highlight(_hover, Color("91c8b7"), 0.20, 2.0)
	if _in_bounds(_selection):
		_draw_highlight(_selection, Color("e0ab59"), 0.26, 3.0)


func _draw_tile(cell: Vector2i) -> void:
	var center: Vector2 = cell_to_world(cell)
	var points: PackedVector2Array = _diamond(center)
	var is_water: bool = _is_water(cell)
	var is_road: bool = _is_road(cell)
	var variation: float = float((cell.x * 7 + cell.y * 11) % 5) * 0.013
	var fill: Color = Color("b8cdae").lightened(variation)
	if is_road:
		fill = Color("809293")
	if is_water:
		fill = Color("91bec4").lightened(variation)
	if cell.y == grid_size.y - 1:
		draw_colored_polygon(PackedVector2Array([points[3], points[2], points[2] + Vector2(0, EXTRUSION), points[3] + Vector2(0, EXTRUSION)]), Color("8da787") if not is_water else Color("6e9da7"))
	if cell.x == grid_size.x - 1:
		draw_colored_polygon(PackedVector2Array([points[2], points[1], points[1] + Vector2(0, EXTRUSION), points[2] + Vector2(0, EXTRUSION)]), Color("7d987b") if not is_water else Color("618f9b"))
	draw_colored_polygon(points, fill)
	var border: Color = Color(0.30, 0.43, 0.31, 0.15)
	if is_road:
		border = Color(0.31, 0.42, 0.43, 0.20)
	elif is_water:
		border = Color(0.75, 0.91, 0.90, 0.15)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), border, 1.0, true)
	if is_water:
		_draw_water_ripples(center, cell)
	elif is_road:
		_draw_road_markings(center, cell)
	elif not occupancy.has(cell):
		_draw_grass(center, cell)


func _draw_road_markings(center: Vector2, cell: Vector2i) -> void:
	var road_line: Color = Color("d6ddd0")
	if cell.x == 4 and cell.y != 4:
		draw_line(center + Vector2(-10, 5), center + Vector2(10, -5), road_line, 1.6, true)
	elif cell.y == 4 and cell.x != 4:
		draw_line(center + Vector2(-10, -5), center + Vector2(10, 5), road_line, 1.6, true)
	if cell == Vector2i(4, 3) or cell == Vector2i(3, 4):
		for stripe: int in range(4):
			var step: float = float(stripe) * 5.0 - 7.5
			var offset: Vector2 = Vector2(step, step * 0.5) if cell.x == 4 else Vector2(step, -step * 0.5)
			var across: Vector2 = Vector2(5, -2.5) if cell.x == 4 else Vector2(5, 2.5)
			draw_line(center + offset - across, center + offset + across, Color("e0e2d5"), 2.8, true)


func _draw_water_ripples(center: Vector2, cell: Vector2i) -> void:
	var shift: float = float((cell.x + cell.y) % 3) * 5.0
	draw_line(center + Vector2(-18 + shift, -3), center + Vector2(-3 + shift, -3), Color(0.84, 0.96, 0.95, 0.60), 1.4, true)
	draw_line(center + Vector2(0, 6), center + Vector2(17, 6), Color(0.84, 0.96, 0.95, 0.36), 1.2, true)


func _draw_grass(center: Vector2, cell: Vector2i) -> void:
	if (cell.x + cell.y * 3) % 4 != 0:
		return
	var grass: Color = Color(0.42, 0.58, 0.40, 0.25)
	var start: Vector2 = center + Vector2(15, 2)
	draw_line(start, start + Vector2(-2, -4), grass, 1.0, true)
	draw_line(start, start + Vector2(1, -5), grass, 1.0, true)
	draw_line(start, start + Vector2(4, -3), grass, 1.0, true)


func _draw_highlight(cell: Vector2i, tint: Color, opacity: float, width: float) -> void:
	var points: PackedVector2Array = _diamond(cell_to_world(cell), 2.0)
	draw_colored_polygon(points, Color(tint, opacity))
	points.append(points[0])
	draw_polyline(points, tint, width, true)
