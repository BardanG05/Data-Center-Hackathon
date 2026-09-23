extends Node2D
class_name TownBuilding

## All buildings share this footprint and can use a replacement PNG later.
## The node's origin is the centre of the occupied ground tile.
var definition: Dictionary = {}
var _visual_kind: String = "house"
var _color: Color = Color("e3caa1")
var _sprite: Sprite2D


func configure(data: Dictionary) -> void:
	definition = data.duplicate(true)
	_visual_kind = String(data.get("visual_kind", data.get("id", "business")))
	var color_value: Variant = data.get("color", "#e3caa1")
	if color_value is Color:
		_color = color_value
	else:
		_color = Color.from_string(String(color_value), Color("e3caa1"))
	if is_instance_valid(_sprite):
		_sprite.queue_free()
		_sprite = null
	var sprite_path: String = String(data.get("sprite_path", ""))
	if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
		var texture_resource: Resource = load(sprite_path)
		if texture_resource is Texture2D:
			_sprite = Sprite2D.new()
			_sprite.texture = texture_resource
			# Replacement images should have a transparent background and ground
			# contact at their bottom centre. Their maximum width is one tile.
			var texture_size: Vector2 = _sprite.texture.get_size()
			var sprite_scale: float = 78.0 / maxf(texture_size.x, 1.0)
			_sprite.scale = Vector2.ONE * sprite_scale
			_sprite.offset = Vector2(0.0, -texture_size.y * 0.5)
			add_child(_sprite)
	queue_redraw()


func _draw() -> void:
	_shadow()
	if is_instance_valid(_sprite):
		return
	match _visual_kind:
		"tree":
			_draw_tree()
		"house":
			_draw_house()
		"grid":
			_draw_grid()
		"water":
			_draw_water()
		"hospital":
			_draw_hospital()
		"school":
			_draw_school()
		"data_centre":
			_draw_data_centre()
		_:
			_draw_business()


func _shadow() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-32, 5), Vector2(1, -11), Vector2(40, 6),
		Vector2(6, 24), Vector2(-27, 13)
	]), Color(0.09, 0.19, 0.17, 0.17))


func _prism(width: float, depth: float, height: float, tint: Color, offset: Vector2 = Vector2.ZERO) -> void:
	var left: Vector2 = offset + Vector2(-width, 0)
	var back: Vector2 = offset + Vector2(0, -depth)
	var right: Vector2 = offset + Vector2(width, 0)
	var front: Vector2 = offset + Vector2(0, depth)
	var lift: Vector2 = Vector2(0, -height)
	draw_colored_polygon(PackedVector2Array([left, front, front + lift, left + lift]), tint.darkened(0.10))
	draw_colored_polygon(PackedVector2Array([front, right, right + lift, front + lift]), tint.darkened(0.29))
	draw_colored_polygon(PackedVector2Array([left + lift, back + lift, right + lift, front + lift]), tint.lightened(0.19))
	draw_polyline(PackedVector2Array([left, left + lift, back + lift, right + lift, right, front, left]), Color(0.09, 0.18, 0.22, 0.35), 1.0, true)
	draw_line(front, front + lift, Color(0.08, 0.16, 0.20, 0.2), 1.0, true)


func _windows(width: float, depth: float, height: float, columns: int, rows: int, tint: Color = Color("ffe8ad")) -> void:
	for side: int in [-1, 1]:
		for column: int in range(columns):
			var t: float = (float(column) + 0.5) / float(columns)
			for row: int in range(rows):
				var center: Vector2 = Vector2(float(side) * width * (1.0 - t), depth * t - height + 11.0 + float(row) * 13.0)
				var along: Vector2 = Vector2(-float(side) * 4.0, depth * 4.0 / width)
				var down: Vector2 = Vector2(0, 3.5)
				draw_colored_polygon(PackedVector2Array([center - along - down, center + along - down, center + along + down, center - along + down]), tint.darkened(0.12 if side == 1 else 0.0))


func _draw_house() -> void:
	_prism(25, 13, 28, _color)
	_windows(25, 13, 28, 2, 1, Color("d6f0ee"))
	var roof: Color = Color("597784")
	var left: Vector2 = Vector2(-29, -28)
	var back: Vector2 = Vector2(0, -43)
	var right: Vector2 = Vector2(29, -28)
	var front: Vector2 = Vector2(0, -13)
	var ridge_left: Vector2 = Vector2(-14.5, -52)
	var ridge_right: Vector2 = Vector2(14.5, -37)
	draw_colored_polygon(PackedVector2Array([back, right, ridge_right, ridge_left]), roof.lightened(0.10))
	draw_colored_polygon(PackedVector2Array([left, front, ridge_right, ridge_left]), roof)
	draw_colored_polygon(PackedVector2Array([front, right, ridge_right]), _color.lightened(0.07))
	draw_polyline(PackedVector2Array([left, ridge_left, ridge_right, right]), roof.darkened(0.3), 1.5, true)
	_prism(3.5, 2.0, 11, Color("caa385"), Vector2(-11, -40))
	draw_colored_polygon(PackedVector2Array([Vector2(8, 8), Vector2(15, 4.5), Vector2(15, -7.5), Vector2(8, -4)]), Color("6e8788"))


func _draw_business() -> void:
	_prism(29, 15, 41, _color)
	_windows(29, 15, 41, 3, 2, Color("c7e9e3"))
	_prism(31, 16, 4, Color("617f88"), Vector2(0, -41))
	draw_line(Vector2(-27, -8), Vector2(-1, 5), Color("f5bd76"), 5.0, true)
	draw_line(Vector2(1, 5), Vector2(27, -8), Color("e49b61"), 5.0, true)


func _draw_school() -> void:
	_prism(32, 17, 32, _color)
	_windows(32, 17, 32, 3, 1, Color("daf1e8"))
	_prism(34, 18, 4, Color("ad7464"), Vector2(0, -32))
	_prism(10, 6, 12, Color("f4dfbc"), Vector2(0, -33))
	draw_circle(Vector2(-4, -39), 3.5, Color("fff7df"))
	draw_line(Vector2(-4, -39), Vector2(-4, -41), Color("667b82"), 1.0, true)
	draw_line(Vector2(-4, -39), Vector2(-2, -38), Color("667b82"), 1.0, true)
	draw_line(Vector2(20, -34), Vector2(20, -62), Color("6c8590"), 1.5, true)
	draw_colored_polygon(PackedVector2Array([Vector2(20, -62), Vector2(33, -58), Vector2(20, -53)]), Color("f2b766"))


func _draw_hospital() -> void:
	_prism(30, 16, 44, _color)
	_windows(30, 16, 44, 3, 2, Color("b4d8da"))
	_prism(32, 17, 4, Color("88a7a5"), Vector2(0, -44))
	# Medical cross on a small roof sign.
	draw_rect(Rect2(-8, -67, 16, 17), Color("fbf6e9"))
	draw_rect(Rect2(-2, -64, 4, 11), Color("da8274"))
	draw_rect(Rect2(-5.5, -60.5, 11, 4), Color("da8274"))
	_prism(10, 5, 4, Color("82a8a6"), Vector2(12, 8))


func _draw_grid() -> void:
	_prism(34, 18, 4, Color("a4b3a9"))
	_prism(13, 8, 23, _color, Vector2(-11, -2))
	_prism(10, 6, 18, Color("94a8a3"), Vector2(16, 2))
	for x: float in [-18.0, -10.0, -2.0]:
		draw_line(Vector2(x, -25), Vector2(x, -34), Color("7b9191"), 3.0, true)
		draw_line(Vector2(x - 3, -30), Vector2(x + 3, -30), Color("d5dcd0"), 2.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -17), Vector2(-8, -19), Vector2(-12, -11), Vector2(-6, -13), Vector2(-13, -3), Vector2(-11, -11), Vector2(-16, -9)]), Color("ffe096"))
	for x: float in [10.0, 15.0, 20.0]:
		draw_line(Vector2(x, -9), Vector2(x, -3), Color("617d81"), 1.5, true)


func _ellipse(center: Vector2, radius: Vector2, tint: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(32):
		var angle: float = TAU * float(index) / 32.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, tint)


func _tank(center: Vector2, radius: float, height: float) -> void:
	draw_rect(Rect2(center + Vector2(-radius, -height), Vector2(radius * 2.0, height)), _color.darkened(0.12))
	_ellipse(center, Vector2(radius, radius * 0.46), _color.darkened(0.12))
	_ellipse(center + Vector2(0, -height), Vector2(radius, radius * 0.46), _color.lightened(0.26))
	_ellipse(center + Vector2(0, -height), Vector2(radius - 3.0, radius * 0.34), Color("b7dadd"))
	draw_line(center + Vector2(-radius + 4, -height + 4), center + Vector2(-radius + 4, -3), Color(1, 1, 1, 0.25), 2.0, true)


func _draw_water() -> void:
	_prism(33, 17, 4, Color("a5c1b7"))
	_tank(Vector2(-13, -2), 13, 29)
	_tank(Vector2(14, 5), 12, 24)
	draw_polyline(PackedVector2Array([Vector2(-13, -31), Vector2(-13, -42), Vector2(13, -29), Vector2(13, -20)]), Color("6d949d"), 3.0, true)


func _draw_tree() -> void:
	draw_line(Vector2(0, 10), Vector2(0, -18), Color("896f58"), 5.0, true)
	_ellipse(Vector2(2, -20), Vector2(21, 22), _color.darkened(0.18))
	_ellipse(Vector2(-8, -29), Vector2(16, 19), _color)
	_ellipse(Vector2(6, -36), Vector2(16, 18), _color.lightened(0.12))
	_ellipse(Vector2(-4, -41), Vector2(12, 12), _color.lightened(0.2))


func _draw_data_centre() -> void:
	_prism(34, 18, 51, _color)
	_prism(36, 19, 4, _color.lightened(0.08), Vector2(0, -51))
	for side: int in [-1, 1]:
		for column: int in range(4):
			var t: float = (float(column) + 0.5) / 4.0
			var center: Vector2 = Vector2(float(side) * 34.0 * (1.0 - t), 18.0 * t - 25.0)
			var along: Vector2 = Vector2(-float(side) * 3.1, 1.65)
			var down: Vector2 = Vector2(0, 17)
			draw_colored_polygon(PackedVector2Array([center - along - down, center + along - down, center + along + down, center - along + down]), Color("34586a"))
			for row: int in range(5):
				var light_position: Vector2 = center + Vector2(0, -12 + row * 6)
				draw_line(light_position - along * 0.58, light_position + along * 0.58, Color("9ae4d2"), 1.3, true)
	_prism(10, 6, 6, Color("a6bec0"), Vector2(-12, -54))
	_prism(10, 6, 6, Color("a6bec0"), Vector2(12, -47))
	_ellipse(Vector2(-12, -60), Vector2(5.5, 2.7), Color("6b8791"))
	_ellipse(Vector2(12, -53), Vector2(5.5, 2.7), Color("6b8791"))
	draw_line(Vector2(-34, -47), Vector2(0, -29), Color("8adfcb"), 2.0, true)
	draw_line(Vector2(0, -29), Vector2(34, -47), Color("64baa9"), 2.0, true)
