class_name TownUI
extends CanvasLayer
## Presents state and emits player requests. It never changes resources itself.

signal build_selected(building_id: String)
signal upgrade_requested(uid: int, upgrade_id: String)
signal demolish_requested(uid: int)
signal speed_requested(speed: float)
signal press_conference_requested
signal restart_requested
signal restart_confirmed
signal restart_cancelled
signal event_option_chosen(index: int)
signal event_closed
signal attitude_chosen(option: String)
signal coach_next
signal coach_skip

const INK := Color("0e1c20")
const PANEL := Color("16292e")
const CARD := Color("1f3a40")
const CARD_HI := Color("2b4d54")
const TEXT := Color("eef4ea")
const MUTED := Color("9fb8b1")
const GREEN := Color("8fe3a4")
const AMBER := Color("ffc970")
const RED := Color("ff7b72")
const GOLD := Color("ffd84d")
const TAG_COLORS := {"data": "#2f6fd6", "opinion": "#8a4fd0", "assumption": "#5d6b70"}
const QUIZ_TITLES := {"MULTIPLE_CHOICE": "Quick question", "MYTH_OR_FACT": "Myth or fact?", "HIGHER_OR_LOWER": "Which is higher or lower?"}
const SCREEN := Vector2(1440, 900)
const ADVISOR_RECT := Rect2(16, 164, 1062, 38)
const MAP_RECT := Rect2(16, 208, 1062, 672)
const SIDE_X := 1094.0
const SIDE_W := 330.0
const STAT_KEYS := ["money", "electricity", "water", "compute", "acceptance", "share"]
const STAT_NAMES := ["MONEY", "ELECTRICITY", "WATER", "COMPUTE", "PUBLIC ACCEPTANCE", "DATA CENTRES' SHARE"]
const STAT_HELP := [
	"Your budget. Every month you get town income plus data-centre revenue, minus the cost of importing any compute you don't produce yourself. Below −£3.0m the town is bankrupt.",
	"Electricity used / grid supply. Homes always come first: if the grid is full, your data centres are throttled and earn less. Solar farms and offshore wind add supply.",
	"Water used / supply. Data centres use water for cooling. Going over supply means a hosepipe ban, which angers residents. Water treatment works add supply.",
	"Computing power produced in Bournemouth / what the town needs. Demand grows every year along Ireland's real curve. Any shortfall is imported, which costs money every month.",
	"How much the public backs your plans. It starts at the share of surveyed people in Ireland who were supportive. It drifts towards the 'heading to' value. Below 25% the council stops you.",
	"Share of the town's electricity used by data centres, compared with Ireland in the same year (CSO data).",
]
const BUILD_ORDER := ["enterprise", "colocation", "hyperscale", "solar_farm", "offshore_wind", "water_works"]

var data: GameData
var simulation: SimulationManager
var _root: Control
var _stats: Dictionary = {}
var _stat_panels: Dictionary = {}
var _date: Label
var _speed_buttons: Dictionary = {}
var _build_buttons: Dictionary = {}
var _press_conference_button: Button
var _advisor: Label
var _advisor_panel: Panel
var _info: RichTextLabel
var _actions: VBoxContainer
var _breakdown: RichTextLabel
var _toast: PanelContainer
var _toast_label: Label
var _toast_time := 0.0
var _hover: PanelContainer
var _hover_label: Label
var _modal: Control
var _modal_kicker: Label
var _modal_title: Label
var _modal_body: RichTextLabel
var _modal_options: VBoxContainer
var _modal_continue: Button
var _coach: PanelContainer
var _coach_title: Label
var _coach_body: RichTextLabel
var _coach_next: Button
var _coach_step: Label
var _highlight: Panel
var _coach_target: Callable
var _time := 0.0
var _state: Dictionary = {}
var _armed := ""
var _selected: Dictionary = {}
var _preview: Dictionary = {}
var _restart_confirmation_open := false


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_header()
	_build_stats()
	_build_advisor()
	_build_side()
	_label("Map © OpenStreetMap contributors (ODbL) · Imagery: Sentinel-2 cloudless 2023 by EOX (CC BY-NC-SA 4.0) · Survey: Maynooth University · Energy data: CSO, SEAI, EirGrid, KPMG via BCP Data",
		Vector2(16, 884), Vector2(1400, 16), 10, Color(MUTED, 0.7))
	_build_toast()
	_build_hover()
	_build_modal()
	_build_coach()


func configure(game_data: GameData, sim: SimulationManager) -> void:
	data = game_data
	simulation = sim
	for id: String in data.building_order:
		var def: Dictionary = data.buildings[id]
		_build_buttons[id].text = String(def["name"])
		_build_buttons[id].tooltip_text = _building_summary(def)
	set_press_conference_available(data.quiz_bank.remaining_count())
	_show_default()


func _process(delta: float) -> void:
	_time += delta
	if _toast.visible:
		_toast_time -= delta
		if _toast_time <= 0.0:
			_toast.hide()
	if _hover.visible:
		var pos := get_viewport().get_mouse_position() + Vector2(18, 20)
		_hover.position = Vector2(minf(pos.x, SCREEN.x - _hover.size.x - 8), minf(pos.y, SCREEN.y - _hover.size.y - 8))
	if _coach.visible:
		_place_coach()


# ------------------------------------------------------------------ layout

func _build_header() -> void:
	_panel(Vector2(0, 0), Vector2(1440, 70), INK)
	_label("BOURNEMOUTH", Vector2(24, 10), Vector2(400, 34), 28, TEXT)
	_label("IRELAND'S DATA-CENTRE DECADE, REPLAYED ON THE SOUTH COAST", Vector2(26, 44), Vector2(700, 18), 11, MUTED)
	_date = _label("JAN 2015", Vector2(720, 14), Vector2(220, 40), 30, AMBER)
	_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var x := 968.0
	for entry: Array in [["Pause", 0.0], ["1×", 1.0], ["2×", 2.0], ["4×", 4.0]]:
		var width := 64.0 if entry[1] == 0.0 else 48.0
		var b := _button(entry[0], Vector2(x, 16), Vector2(width, 38), false)
		b.tooltip_text = "Pause (Space)" if entry[1] == 0.0 else "Run at %s speed. One month takes %.1f seconds." % [entry[0], 1.5 / float(entry[1])]
		var speed: float = entry[1]
		b.pressed.connect(func() -> void: speed_requested.emit(speed))
		_speed_buttons[speed] = b
		x += width + 6
	var restart := _button("Restart", Vector2(1330, 16), Vector2(94, 38), false)
	restart.pressed.connect(func() -> void: restart_requested.emit())


func _build_stats() -> void:
	for i in range(STAT_KEYS.size()):
		var x := 16.0 + i * 237.0
		var card := _panel(Vector2(x, 80), Vector2(229, 76), CARD)
		card.tooltip_text = STAT_HELP[i]
		card.mouse_default_cursor_shape = Control.CURSOR_HELP
		_stat_panels[STAT_KEYS[i]] = card
		_label(STAT_NAMES[i] + "  ⓘ", Vector2(x + 12, 86), Vector2(210, 16), 11, MUTED)
		var value := _label("—", Vector2(x + 12, 102), Vector2(210, 30), 23, TEXT)
		var detail := _label("", Vector2(x + 12, 133), Vector2(210, 16), 11, MUTED)
		var track := ColorRect.new()
		track.position = Vector2(x + 12, 150)
		track.size = Vector2(205, 3)
		track.color = Color(1, 1, 1, 0.08)
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(track)
		var bar := ColorRect.new()
		bar.position = track.position
		bar.size = track.size
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(bar)
		_stats[STAT_KEYS[i]] = {"value": value, "detail": detail, "bar": bar}


func _build_advisor() -> void:
	_advisor_panel = _panel(ADVISOR_RECT.position, ADVISOR_RECT.size, CARD)
	_label("NEXT STEP", ADVISOR_RECT.position + Vector2(14, 11), Vector2(90, 18), 11, GOLD)
	_advisor = _label("", ADVISOR_RECT.position + Vector2(100, 8), Vector2(ADVISOR_RECT.size.x - 112, 24), 15, TEXT)


func _build_side() -> void:
	_panel(Vector2(SIDE_X - 6, 164), Vector2(SIDE_W + 12, 716), PANEL)
	_label("BUILD", Vector2(SIDE_X + 8, 172), Vector2(200, 18), 12, GREEN)
	var i := 0
	for id: String in BUILD_ORDER:
		var b := _button(id, Vector2(SIDE_X + (i % 2) * 166, 194 + (i / 2) * 52), Vector2(160, 46), false)
		b.add_theme_font_size_override("font_size", 12)
		b.toggle_mode = true
		var building_id := id
		b.pressed.connect(func() -> void: build_selected.emit(building_id))
		_build_buttons[id] = b
		i += 1
	_press_conference_button = _button("Attend press conference", Vector2(SIDE_X, 350), Vector2(SIDE_W, 30), true)
	_press_conference_button.add_theme_font_size_override("font_size", 11)
	_press_conference_button.tooltip_text = "Choose when to answer the next unused press question."
	_press_conference_button.pressed.connect(func() -> void: press_conference_requested.emit())
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(SIDE_X, 388)
	scroll.size = Vector2(SIDE_W, 356)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(SIDE_W - 12, 0)
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.scroll_active = false
	_info.custom_minimum_size = Vector2(SIDE_W - 14, 0)
	_info.mouse_filter = Control.MOUSE_FILTER_PASS
	_info.add_theme_font_size_override("normal_font_size", 13)
	_info.add_theme_font_size_override("bold_font_size", 16)
	_info.add_theme_color_override("default_color", TEXT)
	box.add_child(_info)
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 5)
	box.add_child(_actions)
	_panel(Vector2(SIDE_X, 752), Vector2(SIDE_W, 124), CARD)
	_breakdown = RichTextLabel.new()
	_breakdown.bbcode_enabled = true
	_breakdown.position = Vector2(SIDE_X + 10, 758)
	_breakdown.size = Vector2(SIDE_W - 20, 116)
	_breakdown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_breakdown.add_theme_font_size_override("normal_font_size", 12)
	_breakdown.add_theme_font_size_override("bold_font_size", 13)
	_breakdown.add_theme_color_override("default_color", TEXT)
	_root.add_child(_breakdown)


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", _style(Color(INK, 0.92), 8, Color(GREEN, 0.4)))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.position = Vector2(MAP_RECT.position.x + 12, MAP_RECT.end.y - 50)
	_toast_label = _label("", Vector2.ZERO, Vector2.ZERO, 15, GREEN, _toast)
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_root.add_child(_toast)
	_toast.hide()


func _build_hover() -> void:
	_hover = PanelContainer.new()
	_hover.add_theme_stylebox_override("panel", _style(Color(INK, 0.94), 6, Color(1, 1, 1, 0.18)))
	_hover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_label = _label("", Vector2.ZERO, Vector2.ZERO, 13, TEXT, _hover)
	_hover_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_root.add_child(_hover)
	_hover.hide()


func _build_modal() -> void:
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_modal)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.05, 0.06, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)
	var card := Panel.new()
	card.position = Vector2(300, 110)
	card.size = Vector2(840, 690)
	card.add_theme_stylebox_override("panel", _style(PANEL, 16, Color(GREEN, 0.35)))
	_modal.add_child(card)
	_modal_kicker = _label("", Vector2(40, 30), Vector2(760, 20), 13, AMBER, card)
	_modal_title = _label("", Vector2(40, 54), Vector2(760, 80), 30, TEXT, card)
	_modal_body = RichTextLabel.new()
	_modal_body.bbcode_enabled = true
	_modal_body.position = Vector2(40, 140)
	_modal_body.size = Vector2(760, 300)
	_modal_body.add_theme_font_size_override("normal_font_size", 17)
	_modal_body.add_theme_font_size_override("bold_font_size", 17)
	_modal_body.add_theme_color_override("default_color", TEXT)
	card.add_child(_modal_body)
	_modal_options = VBoxContainer.new()
	_modal_options.position = Vector2(40, 440)
	_modal_options.size = Vector2(760, 220)
	_modal_options.add_theme_constant_override("separation", 8)
	card.add_child(_modal_options)
	_modal_continue = _button("Continue", Vector2(600, 620), Vector2(200, 46), true, card)
	_modal_continue.pressed.connect(func() -> void: event_closed.emit())
	_modal.hide()


func _build_coach() -> void:
	_highlight = Panel.new()
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := StyleBoxFlat.new()
	ring.bg_color = Color(GOLD, 0.08)
	ring.set_border_width_all(4)
	ring.border_color = GOLD
	ring.set_corner_radius_all(10)
	_highlight.add_theme_stylebox_override("panel", ring)
	_root.add_child(_highlight)
	_highlight.hide()
	_coach = PanelContainer.new()
	_coach.custom_minimum_size = Vector2(360, 0)
	var style := _style(Color("fdf6e3"), 12, GOLD)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_coach.add_theme_stylebox_override("panel", style)
	_coach.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_coach.add_child(box)
	_coach_step = Label.new()
	_coach_step.add_theme_font_size_override("font_size", 11)
	_coach_step.add_theme_color_override("font_color", Color("9a7b1c"))
	box.add_child(_coach_step)
	_coach_title = Label.new()
	_coach_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coach_title.add_theme_font_size_override("font_size", 20)
	_coach_title.add_theme_color_override("font_color", INK)
	box.add_child(_coach_title)
	_coach_body = RichTextLabel.new()
	_coach_body.bbcode_enabled = true
	_coach_body.fit_content = true
	_coach_body.scroll_active = false
	_coach_body.custom_minimum_size = Vector2(324, 0)
	_coach_body.add_theme_font_size_override("normal_font_size", 15)
	_coach_body.add_theme_font_size_override("bold_font_size", 15)
	_coach_body.add_theme_color_override("default_color", Color("1d2b2e"))
	box.add_child(_coach_body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var skip := Button.new()
	skip.text = "Skip tutorial"
	skip.flat = true
	skip.add_theme_font_size_override("font_size", 13)
	skip.add_theme_color_override("font_color", Color("6b7f84"))
	skip.add_theme_color_override("font_hover_color", INK)
	skip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	skip.pressed.connect(func() -> void: coach_skip.emit())
	row.add_child(skip)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_coach_next = Button.new()
	_coach_next.custom_minimum_size = Vector2(110, 36)
	_style_button(_coach_next, true)
	_coach_next.pressed.connect(func() -> void: coach_next.emit())
	row.add_child(_coach_next)
	_root.add_child(_coach)
	_coach.hide()


# ------------------------------------------------------------------ state

func update_state(state: Dictionary) -> void:
	_state = state
	set_press_conference_available(data.quiz_bank.remaining_count())
	var months := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
	_date.text = "%s %d" % [months[int(state["month"]) - 1], int(state["year"])]
	var net := float(state["net_income"])
	_set_stat("money", GameData.money(state["money"]), "%s%s / month" % ["+" if net >= 0 else "", GameData.money(net)], -1.0, GREEN if net >= 0 else RED)
	var e_ratio := float(state["electricity_used"]) / maxf(float(state["electricity_supply"]), 0.001)
	var e_detail := "Town %d · data centres %d" % [roundi(state["electricity_town"]), roundi(state["electricity_dc"])]
	if state["blackout"]:
		e_detail = "BLACKOUTS in homes"
	elif float(state["dc_output"]) < 0.999:
		e_detail = "Grid full: DCs throttled to %d%%" % roundi(float(state["dc_output"]) * 100.0)
	_set_stat("electricity", "%d / %d" % [roundi(state["electricity_used"]), roundi(state["electricity_supply"])], e_detail, e_ratio,
		RED if state["blackout"] else (AMBER if e_ratio > 0.97 else GREEN))
	var w_ratio := float(state["water_used"]) / maxf(float(state["water_supply"]), 0.001)
	_set_stat("water", "%d / %d" % [roundi(state["water_used"]), roundi(state["water_supply"])], "HOSEPIPE BAN" if state["water_shortage"] else "Used / supply",
		w_ratio, RED if state["water_shortage"] else (AMBER if w_ratio > 0.9 else GREEN))
	var met := minf(1.0, float(state["compute_local"]) / maxf(float(state["compute_demand"]), 0.001))
	_set_stat("compute", "%d / %d" % [roundi(state["compute_local"]), roundi(state["compute_demand"])],
		"%d%% local · importing %s/mo" % [roundi(met * 100.0), GameData.money(state["import_cost"])] if met < 0.999 else "Demand met locally", met, GREEN if met >= 0.999 else AMBER)
	var acc := float(state["acceptance"])
	var target := float(state["acceptance_target"])
	var arrow := "▲" if target > acc + 0.5 else ("▼" if target < acc - 0.5 else "■")
	_set_stat("acceptance", "%d%%" % roundi(acc), "%s heading to %d%% · lose at %d%%" % [arrow, roundi(target), roundi(float(data.scenario["lose_acceptance"]))],
		acc / 100.0, GREEN if acc >= 45.0 else (AMBER if acc >= 35.0 else RED))
	var ire := float(state["ireland_share"])
	_set_stat("share", "%.1f%%" % (float(state["dc_share"]) * 100.0),
		("Ireland %d: %.1f%%" % [int(state["year"]), ire * 100.0]) if ire >= 0.0 else "Ireland 2025: %s%%" % data.facts["share_2025"],
		float(state["dc_share"]) / 0.4, Color("b48cff"))
	_update_breakdown()
	if not _selected.is_empty():
		_show_selected()
	elif not _armed.is_empty():
		_show_armed()


func _set_stat(key: String, value: String, detail: String, ratio: float, color: Color) -> void:
	_stats[key]["value"].text = value
	_stats[key]["value"].add_theme_color_override("font_color", color)
	_stats[key]["detail"].text = detail
	var bar: ColorRect = _stats[key]["bar"]
	bar.visible = ratio >= 0.0
	bar.size.x = 205.0 * clampf(ratio, 0.0, 1.0)
	bar.color = color


func _update_breakdown() -> void:
	var p: Dictionary = _state.get("penalties", {})
	var lines := "[b]WHY ACCEPTANCE IS HEADING TO %d%%[/b]\n" % roundi(_state["acceptance_target"])
	lines += "[font_size=11]%s Start: %s%% supportive (%s surveyed)[/font_size]\n" % [_tag("opinion"), data.facts["support_pct"], data.facts["support_n"]]
	lines += "[color=#ffc970]−%.1f[/color] objecting neighbours (%s people)\n" % [p.get("local", 0.0), GameData.thousands(_state.get("objectors", 0.0))]
	lines += "[color=#ffc970]−%.1f[/color] data centres on greenfield land\n" % p.get("greenfield", 0.0)
	var other := float(p.get("curtailment", 0.0)) + float(p.get("blackout", 0.0)) + float(p.get("water", 0.0)) + float(p.get("policy", 0.0))
	lines += "[color=#ffc970]−%.1f[/color] blackouts, hosepipe bans, throttling, press" % other
	_breakdown.text = lines


## Advice for the "next step" bar. level: "info", "warn" or "bad".
func set_advice(text: String, level: String) -> void:
	_advisor.text = text
	var color: Color = {"info": GREEN, "warn": AMBER, "bad": RED}.get(level, TEXT)
	_advisor_panel.add_theme_stylebox_override("panel", _style(CARD, 10, Color(color, 0.7)))
	_advisor.add_theme_color_override("font_color", TEXT if level == "info" else color)


# ------------------------------------------------------------------ side panel

func set_armed(building_id: String) -> void:
	_armed = building_id
	_selected = {}
	_preview = {}
	for id: String in _build_buttons:
		_build_buttons[id].set_pressed_no_signal(id == building_id)
	if building_id.is_empty():
		_show_default()
	else:
		_show_armed()


func set_preview(preview: Dictionary) -> void:
	_preview = preview
	if not _armed.is_empty():
		_show_armed()


func set_selected(record: Dictionary) -> void:
	_selected = record
	_armed = ""
	for id: String in _build_buttons:
		_build_buttons[id].set_pressed_no_signal(false)
	if record.is_empty():
		_show_default()
	else:
		_show_selected()


func _show_default() -> void:
	_clear_actions()
	var t := "[b]How to play[/b]\n"
	t += "Demand for computing in Bournemouth will grow about [b]%sx[/b] by 2034, following Ireland's real curve. Meet it by building data centres, or pay every month to import it.\n\n" % data.facts["growth_2034"]
	t += "[b]1.[/b] Pick a building above.\n[b]2.[/b] Click a bright tile on the map.\n[b]3.[/b] Click a data centre to buy upgrades that win neighbours over.\n\n"
	t += "[b]Map key[/b]\n"
	t += "[color=#b8ed73]■[/color] Open land: build; greenfield penalty\n"
	t += "[color=#b3c7f2]■[/color] Industrial estate: build\n"
	t += "[color=#ffc773]■[/color] Shops & offices: build\n"
	t += "[color=#6a9e70]■[/color] Heath & parks: protected\n"
	t += "[color=#e8c9a4]■[/color] Homes: can't build; noise risk\n"
	t += "[color=#ff8a4d]■[/color] Orange wash: nearby homes\n\n"
	t += "[color=#9fb8b1]Scroll to zoom · right-drag to pan · right-click or Esc cancels · Space pauses[/color]\n\n"
	t += "[font_size=10]%s data · %s survey · %s rules[/font_size]" % [_tag("data"), _tag("opinion"), _tag("assumption")]
	_info.text = t


func _show_armed() -> void:
	_clear_actions()
	var def: Dictionary = data.buildings[_armed]
	var price_text := "site price on hover"
	if not _preview.is_empty():
		price_text = GameData.money(float(_preview.get("cost", simulation.build_cost(_armed))))
	var t := "[b]%s[/b]  [color=#ffc970]%s[/color]\n[color=#9fb8b1]%s[/color]\n" % [def["name"], price_text, def["description"]]
	t += _building_summary(def) + "\n"
	if def["category"] == "data_centre":
		var ref: Dictionary = data.real["facts"]["typical_data_centre_types"]["by_type"].get(def.get("real_type", ""), {})
		if not ref.is_empty():
			t += "%s A typical real %s (KPMG): %s GWh/yr, %s ML water/yr, %s sq ft\n" % [_tag("data"), String(def["real_type"]).to_lower(),
				GameData.thousands(ref["energy_gwh_per_year"]), GameData.thousands(ref["water_megalitres_per_year"]), GameData.thousands(ref["building_sqft"])]
	if _preview.is_empty():
		t += "\n[color=#ffd84d]Move the mouse over the map. Bright tiles are where this can go.[/color]"
	else:
		var site_type := String(_preview.get("site_type", "mixed site"))
		var site_name := String(TownMap.TERRAIN_NAMES.get(site_type, site_type.capitalize()))
		var site_multiplier := float(_preview.get("site_multiplier", 1.0))
		t += "\n[b]This site[/b] %s · build cost [color=#ffc970]%s[/color]\n" % [site_name, GameData.money(float(_preview.get("cost", simulation.build_cost(_armed))))]
		t += "Site price is %d%% of this building's baseline." % roundi(site_multiplier * 100.0)
		if site_multiplier < 0.999:
			t += " Lower-cost land."
		elif site_multiplier > 1.001:
			t += " Higher-cost town-centre land."
		t += "\n"
		if _preview.has("exposed"):
			t += "\n[b]On this tile[/b]\n%s residents within earshot, about [color=#ffc970]%s would object[/color]\n%s %s%% of %s respondents found a data centre within 5 km of home unacceptable\n" % [
				GameData.thousands(_preview["exposed"]), GameData.thousands(_preview.get("new_objectors", 0.0)), _tag("opinion"), data.facts["objection_pct"], data.facts["objection_n"]]
		if int(_preview.get("greenfield_tiles", 0)) > 0:
			t += "[color=#ffc970]Greenfield site: −%.1f acceptance.[/color] %s %s%% of %s respondents named land use as a top-2 negative impact. Industrial and shop/office land avoids this.\n" % [
				simulation.greenfield_penalty_per_tile() * int(_preview["greenfield_tiles"]), _tag("opinion"), data.facts["pct_land_use"], data.facts["land_use_n"]]
		if _preview["ok"]:
			t += "[color=#8fe3a4]Click to build here.[/color]"
		else:
			t += "[color=#ff7b72]%s[/color]" % _preview["problem"]
	_info.text = t


func _show_selected() -> void:
	var record := _selected
	var def: Dictionary = data.buildings[record["id"]]
	var t := "[b]%s[/b]\n" % def["name"]
	if def["category"] != "data_centre":
		t += "[color=#9fb8b1]%s[/color]\n%s" % [def["description"], _building_summary(def)]
		_info.text = t
		_rebuild_actions(record, false)
		return
	var output := float(_state.get("dc_output", 1.0))
	var ex: Dictionary = simulation.exposure_of(record)
	t += "%d compute%s · earns %s/month\n" % [def["compute_capacity"], (" (throttled to %d%%)" % roundi(output * 100.0)) if output < 0.999 else "", GameData.money(float(def["revenue_per_month"]) * output)]
	t += "Neighbours objecting: [color=#ffc970]%s[/color] of %s within earshot\n" % [GameData.thousands(ex["objectors"]), GameData.thousands(ex["exposed"])]
	t += "\n[b]Upgrades[/b]\nChoose a commitment based on its cost and real-world benefit. The public-opinion result is revealed after purchase. %s %s" % [_tag("opinion"), _tag("assumption")]
	if not record["upgrades"].is_empty():
		t += "\n\n[b]Revealed effects[/b]\n"
		for upgrade_id: String in record["upgrades"]:
			t += "✓ %s\n" % _upgrade_effect_summary(upgrade_id)
	_info.text = t
	_rebuild_actions(record, true)


func _building_summary(def: Dictionary) -> String:
	if def["category"] == "data_centre":
		return "+%d compute · uses %d electricity and %d water · earns %s/month · noise reaches %d tile%s (about %d m)" % [
			def["compute_capacity"], def["electricity_usage"], def["water_usage"], GameData.money(def["revenue_per_month"]),
			def["noise_radius"], "" if int(def["noise_radius"]) == 1 else "s", int(def["noise_radius"]) * 265]
	var parts: Array[String] = []
	if def.has("electricity_supply"):
		parts.append("+%d electricity supply" % def["electricity_supply"])
	if def.has("water_supply"):
		parts.append("+%d water supply" % def["water_supply"])
	parts.append("builds on " + ("the sea" if "sea" in def["terrain"] else "open or industrial land"))
	return " · ".join(parts)


func _upgrade_effect_summary(upgrade_id: String) -> String:
	var up: Dictionary = data.upgrades[upgrade_id]
	if upgrade_id == "renewable":
		return "%s: grid draw halved." % up["name"]
	return "%s: nearby objections reduced by %s%% after this commitment (survey signal, %s respondents)." % [
		up["name"], data.facts.get("pct_" + upgrade_id, "—"), data.facts.get("top3_n", "the survey")]


func _rebuild_actions(record: Dictionary, upgrades: bool) -> void:
	var key := "%d:%s" % [record["uid"], ",".join(record["upgrades"])] if upgrades else "%d" % record["uid"]
	if _actions.get_meta("key", "") == key:
		for b: Button in _actions.get_children():
			if b.has_meta("cost"):
				b.disabled = float(_state.get("money", 0)) < float(b.get_meta("cost"))
		return
	_clear_actions()
	_actions.set_meta("key", key)
	if upgrades:
		for upgrade_id: String in data.upgrade_order:
			var up: Dictionary = data.upgrades[upgrade_id]
			var owned: bool = upgrade_id in record["upgrades"]
			var cost := simulation.upgrade_cost(record, upgrade_id)
			var label := "✓ %s" % up["name"] if owned else "%s · %s" % [up["name"], GameData.money(cost)]
			var b := _action_button(label)
			b.tooltip_text = up["summary"]
			b.disabled = owned or float(_state.get("money", 0)) < cost
			if not owned:
				b.set_meta("cost", cost)
			var uid: int = record["uid"]
			var id := upgrade_id
			b.pressed.connect(func() -> void: upgrade_requested.emit(uid, id))
	var remove := _action_button("Decommission (no refund)")
	remove.add_theme_color_override("font_color", RED)
	var remove_uid: int = record["uid"]
	remove.pressed.connect(func() -> void: demolish_requested.emit(remove_uid))


func _action_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(SIDE_W - 14, 32)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 12)
	_style_button(b, false)
	_actions.add_child(b)
	return b


func _clear_actions() -> void:
	_actions.set_meta("key", "")
	for child in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()


func show_message(message: String, is_error: bool = false) -> void:
	_toast_label.text = message
	_toast_label.add_theme_color_override("font_color", RED if is_error else GREEN)
	_toast.reset_size()
	_toast.show()
	_toast_time = 4.0


## Small label that follows the mouse over the map.
func show_hover(text: String) -> void:
	if text.is_empty():
		_hover.hide()
		return
	_hover_label.text = text
	_hover.reset_size()
	_hover.show()


func set_speed(speed: float) -> void:
	for s: float in _speed_buttons:
		_style_button(_speed_buttons[s], is_equal_approx(s, speed))


func set_press_conference_available(remaining: int) -> void:
	if _press_conference_button == null:
		return
	_press_conference_button.disabled = remaining <= 0 or bool(_state.get("finished", false))
	_press_conference_button.text = "Attend press conference · %d left" % remaining if remaining > 0 else "No press conferences left"


# ------------------------------------------------------------------ screen rects for the tutorial

func stat_rect(key: String) -> Rect2:
	return _stat_panels[key].get_global_rect()


func build_button_rect(id: String) -> Rect2:
	return _build_buttons[id].get_global_rect()


func actions_rect() -> Rect2:
	return _actions.get_global_rect() if _actions.get_child_count() > 0 else Rect2(SIDE_X, 352, SIDE_W, 392)


func speed_rect() -> Rect2:
	var first: Rect2 = _speed_buttons[0.0].get_global_rect()
	return first.merge(_speed_buttons[4.0].get_global_rect())


# ------------------------------------------------------------------ tutorial coach

## Shows a tutorial card beside `target` (a Callable returning a screen Rect2).
func show_coach(step_label: String, title: String, text: String, button: String, target: Callable) -> void:
	_coach_step.text = step_label
	_coach_title.text = title
	_coach_body.text = text
	_coach_next.text = button
	_coach_next.visible = not button.is_empty()
	_coach_target = target
	_coach.reset_size()
	_coach.show()
	_highlight.show()
	_place_coach()


func hide_coach() -> void:
	_coach.hide()
	_highlight.hide()


func is_coaching() -> bool:
	return _coach.visible


func _place_coach() -> void:
	var target: Rect2 = _coach_target.call() if _coach_target.is_valid() else Rect2()
	_highlight.visible = target.size != Vector2.ZERO
	_highlight.position = target.position - Vector2(6, 6)
	_highlight.size = target.size + Vector2(12, 12)
	_highlight.modulate.a = 0.6 + 0.4 * sin(_time * 5.0)
	var size := _coach.get_combined_minimum_size()
	_coach.size = size
	var gap := 18.0
	var candidates := [
		Vector2(target.position.x, target.end.y + gap),
		Vector2(target.end.x + gap, target.position.y),
		Vector2(target.position.x - size.x - gap, target.position.y),
		Vector2(target.position.x, target.position.y - size.y - gap),
	]
	var screen := Rect2(Vector2(8, 8), SCREEN - Vector2(16, 16))
	var chosen := (SCREEN - size) * 0.5
	if target.size.x < 700.0:
		for c: Vector2 in candidates:
			var clamped := Vector2(clampf(c.x, 8, SCREEN.x - size.x - 8), clampf(c.y, 8, SCREEN.y - size.y - 8))
			var rect := Rect2(clamped, size)
			if screen.encloses(rect) and not rect.intersects(target.grow(4)):
				chosen = clamped
				break
	_coach.position = chosen


# ------------------------------------------------------------------ modal

func show_event(event: Dictionary) -> void:
	_modal.show()
	_hover.hide()
	var quiz: bool = event.get("kind") == "quiz"
	_set_quiz_layout(quiz)
	if quiz:
		_modal_kicker.text = "PRESS CONFERENCE" if event.get("quiz_source", "") in ["mandatory", "optional"] else String(event["category"]).replace("_", " ")
		_modal_title.text = QUIZ_TITLES[event["type"]]
		_modal_body.text = String(event["question"])
	else:
		_modal_kicker.text = String(event.get("kicker", "NEWS"))
		_modal_title.text = String(event["title"])
		_modal_body.text = _fill(String(event["body"]))
	_modal_body.scroll_to_line(0)
	_set_options(event.get("options", []), false, quiz)
	_modal_continue.hide()


func show_restart_confirmation() -> void:
	if is_modal_open():
		return
	_restart_confirmation_open = true
	_modal.show()
	_hover.hide()
	_set_quiz_layout(false)
	_modal_kicker.text = "RESTART TOWN"
	_modal_title.text = "Restart this game?"
	_modal_body.text = "Your current town, money, buildings, progress and question history will be lost."
	_modal_options.position.y = 440
	for child in _modal_options.get_children():
		_modal_options.remove_child(child)
		child.queue_free()
	var restart_button := Button.new()
	restart_button.text = "Restart town"
	restart_button.custom_minimum_size = Vector2(760, 48)
	_style_button(restart_button, true)
	restart_button.pressed.connect(func() -> void: restart_confirmed.emit())
	_modal_options.add_child(restart_button)
	var cancel_button := Button.new()
	cancel_button.text = "Keep playing"
	cancel_button.custom_minimum_size = Vector2(760, 48)
	_style_button(cancel_button, false)
	cancel_button.pressed.connect(func() -> void: restart_cancelled.emit())
	_modal_options.add_child(cancel_button)
	_modal_continue.hide()
	cancel_button.grab_focus()


func hide_restart_confirmation() -> void:
	if not _restart_confirmation_open:
		return
	_restart_confirmation_open = false
	_modal.hide()
	for child in _modal_options.get_children():
		_modal_options.remove_child(child)
		child.queue_free()


func reveal_event(event: Dictionary, chosen: int) -> void:
	var header := ""
	if event.get("kind") == "quiz":
		var options: Array = event["options"]
		var answer: int = options.find(event["correct_answer"])
		header = "[b]%s[/b]\n\n[b]%s[/b] Correct answer: %s.\n\n" % [event["question"], "Correct!" if chosen == answer else "Not quite.", event["correct_answer"]]
		var quiz_result: Dictionary = event.get("quiz_result", {})
		if not quiz_result.is_empty():
			var correct: bool = bool(quiz_result.get("correct", chosen == answer))
			var money_delta := float(quiz_result.get("money_delta", 0.0))
			var acceptance_delta := float(quiz_result.get("acceptance_delta", 0.0))
			var income_percent := roundi(float(quiz_result.get("income_fraction", 0.0)) * 100.0)
			var money_text := ("+" if money_delta >= 0.0 else "-") + GameData.money(absf(money_delta))
			var acceptance_text := ("+" if acceptance_delta >= 0.0 else "") + "%.1f" % acceptance_delta
			var result_color := GREEN if correct else RED
			var verdict := "You answered correctly. The public trust you more." if correct else "You answered incorrectly. The public trust you less."
			header += "[color=#%s][b]%s[/b] %s budget (%d%% of monthly income) · %s public trust[/color]\n\n" % [result_color.to_html(false), verdict, money_text, income_percent, acceptance_text]
		_modal_body.text = header + String(event["explanation"])
		for i in range(_modal_options.get_child_count()):
			var button: Button = _modal_options.get_child(i)
			button.disabled = true
			if i == answer:
				button.add_theme_stylebox_override("disabled", _style(Color("284a3c"), 8, GREEN))
				button.add_theme_color_override("font_disabled_color", GREEN)
			elif i == chosen:
				button.add_theme_stylebox_override("disabled", _style(Color("472b2c"), 8, RED))
				button.add_theme_color_override("font_disabled_color", RED)
	else:
		header = "[b]You chose:[/b] %s\n\n" % event["options"][chosen]
		_modal_body.text = header + _fill(String(event.get("reveal", "")))
		_set_options([])
	_modal_body.scroll_to_line(0)
	_modal_continue.text = "Continue"
	_modal_continue.show()
	_modal_continue.grab_focus()


func _set_quiz_layout(quiz: bool) -> void:
	_modal_body.size.y = 230 if quiz else 300
	_modal_options.position.y = 390 if quiz else 440


func show_end(state: Dictionary, summary: Dictionary) -> void:
	_modal.show()
	_set_quiz_layout(false)
	_hover.hide()
	hide_coach()
	var outcome: String = state["outcome"]
	_modal_kicker.text = "GAME OVER" if outcome != "completed" else "2034 · FINAL REPORT"
	_modal_title.text = {"lost_acceptance": "The town turned against you", "lost_money": "Bournemouth ran out of money",
		"completed": "You reached 2034"}[outcome]
	var t := ""
	if outcome == "lost_acceptance":
		t += "Acceptance fell to %d%%. The council halted all data-centre plans.\n\n" % roundi(state["acceptance"])
	elif outcome == "lost_money":
		t += "Importing compute and building infrastructure left the town %s in debt.\n\n" % GameData.money(state["money"])
	t += "[b]Score %d[/b]  ·  %s\n" % [summary["score"], summary["grade"]]
	t += "Demand met locally: %d%% on average · Final acceptance: %d%% · Blackout months: %d · Hosepipe-ban months: %d\n" % [
		roundi(summary["coverage"] * 100.0), roundi(state["acceptance"]), state["blackout_months"], state["water_shortage_months"]]
	t += "Your data centres used [b]%.1f%%[/b] of the town's electricity. %s Ireland's reached %s%% in 2025.\n\n" % [float(state["dc_share"]) * 100.0, _tag("data"), data.facts["share_2025"]]
	t += "[b]One last question.[/b] After playing, how do you feel about data centres?"
	_modal_body.text = t
	_set_options(["Very positive", "Somewhat positive", "Neutral / no strong feeling", "Somewhat negative", "Very negative"], true)
	_modal_continue.text = "Play again"
	_modal_continue.hide()


func reveal_attitude(choice: String) -> void:
	var q: Dictionary = data.survey["questions"]["gut_feeling"]
	var t := _modal_body.text.split("[b]One last question.[/b]")[0]
	t += "%s How %s surveyed people in Ireland described their gut feeling:\n" % [_tag("opinion"), int(q["valid_n"])]
	for option: String in q["counts"]:
		var share := float(q["counts"][option]) / float(q["valid_n"])
		var bar := "█".repeat(roundi(share * 60.0))
		var mark := "  ◀ you" if option == choice else ""
		t += "[font_size=13]%s[/font_size]\n[color=%s]%s[/color] %d%%%s\n" % [option, "#ffc970" if option == choice else "#8fe3a4", bar, roundi(share * 100.0), mark]
	_modal_body.text = t
	_set_options([])
	_modal_continue.show()


func hide_modal() -> void:
	_modal.hide()


func is_modal_open() -> bool:
	return _modal.visible


func _set_options(options: Array, attitude: bool = false, quiz: bool = false) -> void:
	for child in _modal_options.get_children():
		_modal_options.remove_child(child)
		child.queue_free()
	for i in range(options.size()):
		var b := Button.new()
		b.text = options[i]
		b.custom_minimum_size = Vector2(760, 48 if quiz else (38 if attitude else 42))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 16)
		_style_button(b, i == 0 and options.size() == 2 and not attitude and not quiz)
		var index := i
		var text: String = options[i]
		if attitude:
			b.pressed.connect(func() -> void: attitude_chosen.emit(text))
		else:
			b.pressed.connect(func() -> void: event_option_chosen.emit(index))
		_modal_options.add_child(b)


func _fill(text: String) -> String:
	for kind: String in TAG_COLORS:
		text = text.replace("[%s]" % kind, "[bgcolor=%s][color=#ffffff] " % TAG_COLORS[kind]).replace("[/%s]" % kind, " [/color][/bgcolor]")
	return text.format(data.facts)


func _tag(kind: String) -> String:
	return "[bgcolor=%s][color=#ffffff] %s [/color][/bgcolor]" % [TAG_COLORS[kind], kind.to_upper()]


# ------------------------------------------------------------------ helpers

func _panel(pos: Vector2, dimensions: Vector2, color: Color) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = dimensions
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _style(color, 10))
	_root.add_child(panel)
	return panel


func _label(value: String, pos: Vector2, dimensions: Vector2, font_size: int, color: Color, parent: Control = null) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = value
	label.position = pos
	label.size = dimensions
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	(parent if parent != null else _root).add_child(label)
	return label


func _button(value: String, pos: Vector2, dimensions: Vector2, primary: bool, parent: Control = null) -> Button:
	var button := Button.new()
	button.text = value
	button.position = pos
	button.size = dimensions
	_style_button(button, primary)
	(parent if parent != null else _root).add_child(button)
	return button


func _style_button(button: Button, primary: bool) -> void:
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", button.get_theme_font_size("font_size") if button.has_theme_font_size_override("font_size") else 14)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK if primary else TEXT)
	button.add_theme_color_override("font_disabled_color", Color(MUTED, 0.6))
	button.add_theme_stylebox_override("normal", _style(GREEN if primary else CARD, 8))
	button.add_theme_stylebox_override("hover", _style(Color("b5f0c3") if primary else CARD_HI, 8))
	button.add_theme_stylebox_override("pressed", _style(Color("5e8f6a") if not primary else Color("6fc788"), 8, GREEN))
	button.add_theme_stylebox_override("hover_pressed", _style(Color("5e8f6a"), 8, GREEN))
	button.add_theme_stylebox_override("disabled", _style(Color("233236"), 8))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _style(color: Color, radius: int, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8
	style.content_margin_right = 8
	if border.a > 0.0:
		style.set_border_width_all(2)
		style.border_color = border
	return style
