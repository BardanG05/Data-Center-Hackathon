extends Node2D
class_name TownBuilding
## Top-down placeholder art for a placed building. Origin is the footprint's
## top-left corner; simulation data never depends on this visual.

const CELL := 40.0
const UPGRADE_COLORS := {
	"renewable": Color("7be495"), "waste_heat": Color("ff9f5a"),
	"local_jobs": Color("ffd84d"), "community_fund": Color("f06fb0")}

var definition: Dictionary = {}
var record: Dictionary = {}
var _color := Color.WHITE
var _time := 0.0


func configure(def: Dictionary, placed: Dictionary) -> void:
	definition = def
	record = placed
	_color = Color.from_string(String(def.get("color", "#ffffff")), Color.WHITE)
	queue_redraw()


func update_record(placed: Dictionary) -> void:
	record = placed
	queue_redraw()


func _process(delta: float) -> void:
	if definition.get("id") == "offshore_wind":
		_time += delta
		queue_redraw()


func _draw() -> void:
	var size := Vector2(record.get("size", Vector2i.ONE)) * CELL
	match definition.get("id", ""):
		"solar_farm":
			_draw_solar(size)
		"water_works":
			_draw_water(size)
		"offshore_wind":
			_draw_wind(size)
		_:
			_draw_data_centre(size)


func _draw_data_centre(size: Vector2) -> void:
	var body := Rect2(Vector2(3, 3), size - Vector2(6, 6))
	# Soft glow so centres stay visible on a projector at full-map zoom.
	draw_rect(body.grow(7), Color(_color, 0.18))
	draw_rect(body.grow(4), Color(_color, 0.35))
	draw_rect(body.grow(1) , Color(0, 0, 0, 0.45))
	draw_rect(body, Color("1b2a33"))
	draw_rect(body, _color, false, 2.0)
	# Rooftop cooling units scale with the footprint.
	var units := int(size.x / CELL) * 2
	var step := (body.size.x - 8) / units
	for i in range(units):
		for j in range(int(size.y / CELL)):
			var p := body.position + Vector2(4 + i * step, 5 + j * CELL)
			draw_rect(Rect2(p, Vector2(step - 3, 10)), Color(_color, 0.85))
			draw_circle(p + Vector2((step - 3) * 0.5, 5), 3, Color("1b2a33"))
	draw_rect(Rect2(body.position + Vector2(4, body.size.y - 9), Vector2(body.size.x - 8, 4)), Color(_color, 0.5))
	var i := 0
	for upgrade_id: String in record.get("upgrades", []):
		draw_circle(body.position + Vector2(body.size.x - 5 - i * 8, 5), 3.5, UPGRADE_COLORS.get(upgrade_id, Color.WHITE))
		i += 1


func _draw_solar(size: Vector2) -> void:
	draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color("22314a"))
	for row in range(4):
		for col in range(3):
			draw_rect(Rect2(Vector2(5 + col * 11, 5 + row * 8), Vector2(9, 6)), _color)


func _draw_water(size: Vector2) -> void:
	draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color("22363d"))
	draw_circle(Vector2(13, 14), 9, _color)
	draw_circle(Vector2(28, 26), 9, _color.darkened(0.15))
	draw_arc(Vector2(13, 14), 9, 0, TAU, 20, Color.WHITE, 1.0)


func _draw_wind(size: Vector2) -> void:
	var hub := size * 0.5
	draw_circle(hub, 3, _color)
	for k in range(3):
		var a := _time * 2.0 + k * TAU / 3.0
		draw_line(hub, hub + Vector2(cos(a), sin(a)) * 15, _color, 2.5)
	draw_arc(hub, 18, 0, TAU, 24, Color(_color, 0.3), 1.0)
