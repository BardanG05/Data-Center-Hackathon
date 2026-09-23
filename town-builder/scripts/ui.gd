class_name TownUI
extends CanvasLayer
## Presents state and emits player requests. It never changes resources itself.

signal build_selected(building_id: String)
signal upgrade_requested(uid: int, upgrade_id: String)
signal demolish_requested(uid: int)
signal speed_requested(speed: float)
signal restart_requested
signal event_option_chosen(index: int)
signal event_closed
signal attitude_chosen(option: String)

const INK := Color("0e1c20")
const PANEL := Color("16292e")
const CARD := Color("1f3a40")
const CARD_HI := Color("2b4d54")
const TEXT := Color("eef4ea")
const MUTED := Color("9fb8b1")
const GREEN := Color("8fe3a4")
const AMBER := Color("ffc970")
const RED := Color("ff7b72")
const TAG_COLORS := {"data": "#2f6fd6", "opinion": "#8a4fd0", "assumption": "#5d6b70"}
const MAP_RECT := Rect2(16, 164, 1062, 720)
const SIDE_X := 1094.0
const SIDE_W := 330.0

var data: GameData
var simulation: SimulationManager
var _root: Control
var _stats: Dictionary = {}
var _date: Label
var _speed_buttons: Dictionary = {}
var _build_buttons: Dictionary = {}
var _info: RichTextLabel
var _actions: VBoxContainer
var _breakdown: RichTextLabel
var _toast: Label
var _modal: Control
var _modal_kicker: Label
var _modal_title: Label
var _modal_body: RichTextLabel
var _modal_options: VBoxContainer
var _modal_continue: Button
var _state: Dictionary = {}
var _armed := ""
var _selected: Dictionary = {}
var _preview: Dictionary = {}


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_header()
	_build_stats()
	_build_side()
	_toast = _label("", Vector2(28, 842), Vector2(1030, 30), 15, GREEN)
	_label("Map © OpenStreetMap contributors (ODbL) · Imagery: Sentinel-2 cloudless 2023 by EOX (CC BY-NC-SA 4.0) · Survey: Maynooth University · Energy data: CSO, SEAI, EirGrid, KPMG via BCP Data",
		Vector2(16, 884), Vector2(1400, 16), 10, Color(MUTED, 0.7))
	_build_modal()


func configure(game_data: GameData, sim: SimulationManager) -> void:
	data = game_data
	simulation = sim
	for id: String in data.building_order:
		var def: Dictionary = data.buildings[id]
		_build_buttons[id].text = "%s\n%s" % [def["name"], GameData.money(float(def["cost"]))]
	_show_default()


# ------------------------------------------------------------------ layout

func _build_header() -> void:
	_panel(Vector2(0, 0), Vector2(1440, 70), INK)
	_label("BOURNEMOUTH", Vector2(24, 10), Vector2(400, 34), 28, TEXT)
	_label("IRELAND'S DATA-CENTRE DECADE, REPLAYED ON THE SOUTH COAST", Vector2(26, 44), Vector2(700, 18), 11, MUTED)
	_date = _label("JAN 2015", Vector2(720, 14), Vector2(220, 40), 30, AMBER)
	_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var x := 968.0
	for entry: Array in [["Pause", 0.0], ["1×", 1.0], ["2×", 2.0], ["4×", 4.0]]:
		var b := _button(entry[0], Vector2(x, 16), Vector2(64 if entry[1] == 0.0 else 48, 38), false)
		var speed: float = entry[1]
		b.pressed.connect(func() -> void: speed_requested.emit(speed))
		_speed_buttons[speed] = b
		x += (64 if entry[1] == 0.0 else 48) + 6
	var restart := _button("Restart", Vector2(1330, 16), Vector2(94, 38), false)
	restart.pressed.connect(func() -> void: restart_requested.emit())


func _build_stats() -> void:
	var names := ["MONEY", "ELECTRICITY", "WATER", "COMPUTE", "PUBLIC ACCEPTANCE", "DATA CENTRES' SHARE"]
	var keys := ["money", "electricity", "water", "compute", "acceptance", "share"]
	for i in range(names.size()):
		var x := 16.0 + i * 237.0
		_panel(Vector2(x, 80), Vector2(229, 76), CARD)
		_label(names[i], Vector2(x + 12, 86), Vector2(210, 16), 11, MUTED)
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
		_stats[keys[i]] = {"value": value, "detail": detail, "bar": bar}


func _build_side() -> void:
	_panel(Vector2(SIDE_X - 6, 164), Vector2(SIDE_W + 12, 720), PANEL)
	_label("BUILD", Vector2(SIDE_X + 8, 172), Vector2(200, 18), 12, GREEN)
	var i := 0
	for id: String in ["enterprise", "colocation", "hyperscale", "solar_farm", "offshore_wind", "water_works"]:
		var b := _button(id, Vector2(SIDE_X + (i % 2) * 166, 194 + (i / 2) * 56), Vector2(160, 50), false)
		b.add_theme_font_size_override("font_size", 12)
		b.toggle_mode = true
		var building_id := id
		b.pressed.connect(func() -> void: build_selected.emit(building_id))
		_build_buttons[id] = b
		i += 1
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = false
	_info.scroll_active = true
	_info.position = Vector2(SIDE_X + 4, 366)
	_info.size = Vector2(SIDE_W - 8, 250)
	_info.mouse_filter = Control.MOUSE_FILTER_PASS
	_info.add_theme_font_size_override("normal_font_size", 13)
	_info.add_theme_font_size_override("bold_font_size", 17)
	_info.add_theme_color_override("default_color", TEXT)
	_root.add_child(_info)
	_actions = VBoxContainer.new()
	_actions.position = Vector2(SIDE_X + 4, 560)
	_actions.size = Vector2(SIDE_W - 8, 160)
	_actions.add_theme_constant_override("separation", 5)
	_root.add_child(_actions)
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


# ------------------------------------------------------------------ state

func update_state(state: Dictionary) -> void:
	_state = state
	var months := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
	_date.text = "%s %d" % [months[int(state["month"]) - 1], int(state["year"])]
	var net := float(state["net_income"])
	_set_stat("money", GameData.money(state["money"]), "%s%s / month" % ["+" if net >= 0 else "", GameData.money(net)], -1.0, GREEN if net >= 0 else RED)
	var e_ratio := float(state["electricity_used"]) / maxf(float(state["electricity_supply"]), 0.001)
	var e_detail := "Town %d · DCs %d" % [roundi(state["electricity_town"]), roundi(state["electricity_dc"])]
	if state["blackout"]:
		e_detail = "BLACKOUTS in homes"
	elif float(state["dc_output"]) < 0.999:
		e_detail = "Grid full: DCs throttled to %d%%" % roundi(float(state["dc_output"]) * 100.0)
	_set_stat("electricity", "%d / %d" % [roundi(state["electricity_used"]), roundi(state["electricity_supply"])], e_detail, e_ratio,
		RED if state["blackout"] else (AMBER if e_ratio > 0.97 else GREEN))
	var w_ratio := float(state["water_used"]) / maxf(float(state["water_supply"]), 0.001)
	_set_stat("water", "%d / %d" % [roundi(state["water_used"]), roundi(state["water_supply"])], "HOSEPIPE BAN" if state["water_shortage"] else "Use / supply",
		w_ratio, RED if state["water_shortage"] else (AMBER if w_ratio > 0.9 else GREEN))
	var met := minf(1.0, float(state["compute_local"]) / maxf(float(state["compute_demand"]), 0.001))
	_set_stat("compute", "%d / %d" % [roundi(state["compute_local"]), roundi(state["compute_demand"])],
		"%d%% local · importing %s/mo" % [roundi(met * 100.0), GameData.money(state["import_cost"])] if met < 0.999 else "Demand met locally", met, GREEN if met >= 0.999 else AMBER)
	var acc := float(state["acceptance"])
	var target := float(state["acceptance_target"])
	var arrow := "▲" if target > acc + 0.5 else ("▼" if target < acc - 0.5 else "■")
	_set_stat("acceptance", "%d%%" % roundi(acc), "%s heading to %d%% · lose at %d%%" % [arrow, roundi(target), roundi(float(data.scenario["lose_acceptance"]))],
		acc / 100.0, GREEN if acc >= 45.0 else (AMBER if acc >= 28.0 else RED))
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
	lines += "%s Start: %s%% of %s respondents supportive\n" % [_tag("opinion"), data.facts["support_pct"], data.facts["support_n"]]
	lines += "[color=#ffc970]−%.1f[/color] objecting neighbours (%s people)\n" % [p.get("local", 0.0), GameData.thousands(_state.get("objectors", 0.0))]
	lines += "[color=#ffc970]−%.1f[/color] data centres on greenfield land
" % p.get("greenfield", 0.0)
	var other := float(p.get("curtailment", 0.0)) + float(p.get("blackout", 0.0)) + float(p.get("water", 0.0)) + float(p.get("policy", 0.0))
	lines += "[color=#ffc970]−%.1f[/color] blackouts, hosepipe bans, throttling, press" % other
	_breakdown.text = lines


# ------------------------------------------------------------------ side panel

func set_armed(building_id: String) -> void:
	_armed = building_id
	_selected = {}
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
	_info.text = "[b]Your job[/b]\nBournemouth's appetite for compute will grow along [b]Ireland's real curve[/b]: about %sx between 2015 and 2034. Build data centres to meet it, or pay to import compute.\n\nEvery centre needs electricity and water, and annoys the homes within its noise radius. Keep acceptance above %d%% and stay out of debt until 2034.\n\n[color=#9fb8b1]Pick a building above, then click the map. Only open land, industrial estates and shops/offices (tinted tiles) can be built on. Click a data centre to upgrade it. Scroll to zoom, right-drag to pan.[/color]\n\n%s %s %s" % [
		data.facts["growth_2034"], roundi(float(data.scenario["lose_acceptance"])), _tag("data"), _tag("opinion"), _tag("assumption")]


func _show_armed() -> void:
	_clear_actions()
	var def: Dictionary = data.buildings[_armed]
	var t := "[b]%s[/b]  [color=#ffc970]%s[/color]\n[color=#9fb8b1]%s[/color]\n" % [def["name"], GameData.money(float(_preview.get("cost", def["cost"]))), def["description"]]
	if def["category"] == "data_centre":
		t += "+%d compute · %d electricity · %d water · +%s/month\nNoise radius: %d tiles (about %d m)\n" % [
			def["compute_capacity"], def["electricity_usage"], def["water_usage"], GameData.money(def["revenue_per_month"]), def["noise_radius"], def["noise_radius"] * 275]
		var ref: Dictionary = data.real["facts"]["typical_data_centre_types"]["by_type"].get(def.get("real_type", ""), {})
		if not ref.is_empty():
			t += "%s KPMG typical %s: %s GWh/yr, %s ML water/yr, %s sq ft\n" % [_tag("data"), String(def["real_type"]).to_lower(),
				GameData.thousands(ref["energy_gwh_per_year"]), GameData.thousands(ref["water_megalitres_per_year"]), GameData.thousands(ref["building_sqft"])]
	else:
		if def.has("electricity_supply"):
			t += "+%d electricity supply\n" % def["electricity_supply"]
		if def.has("water_supply"):
			t += "+%d water supply\n" % def["water_supply"]
	if not _preview.is_empty():
		if _preview.has("exposed"):
			t += "\n[b]Here:[/b] %s residents within earshot, about [color=#ffc970]%s would object[/color]\n%s %s%% of %s respondents found a data centre within 5 km of home unacceptable\n" % [
				GameData.thousands(_preview["exposed"]), GameData.thousands(_preview.get("new_objectors", 0.0)), _tag("opinion"), data.facts["objection_pct"], data.facts["objection_n"]]
		if int(_preview.get("greenfield_tiles", 0)) > 0:
			t += "[color=#ffc970]Greenfield site: −%.1f acceptance.[/color] %s %s%% of %s respondents named land use as a top-2 negative impact. Industrial and shop/office land avoids this.
" % [
				simulation.greenfield_penalty_per_tile() * int(_preview["greenfield_tiles"]), _tag("opinion"), data.facts["pct_land_use"], data.facts["land_use_n"]]
		if not _preview["ok"]:
			t += "[color=#ff7b72]%s[/color]" % _preview["problem"]
	_info.text = t


func _show_selected() -> void:
	var record := _selected
	var def: Dictionary = data.buildings[record["id"]]
	var t := "[b]%s[/b]\n" % def["name"]
	if def["category"] != "data_centre":
		t += "[color=#9fb8b1]%s[/color]" % def["description"]
		_info.text = t
		_rebuild_actions(record, false)
		return
	var sim_state := _state
	var output := float(sim_state.get("dc_output", 1.0))
	var ex: Dictionary = simulation.exposure_of(record)
	t += "%d compute%s · %s/month\n" % [def["compute_capacity"], (" (throttled to %d%%)" % roundi(output * 100.0)) if output < 0.999 else "", GameData.money(float(def["revenue_per_month"]) * output)]
	t += "Neighbours objecting: [color=#ffc970]%s[/color] of %s within earshot\n" % [GameData.thousands(ex["objectors"]), GameData.thousands(ex["exposed"])]
	t += "\n[b]Upgrades[/b]  %s share of respondents who picked it as a top-3 condition. %s Each wins over that share of objectors." % [_tag("opinion"), _tag("assumption")]
	_info.text = t
	_rebuild_actions(record, true)


func _rebuild_actions(record: Dictionary, upgrades: bool) -> void:
	var key := "%d:%s" % [record["uid"], ",".join(record["upgrades"])] if upgrades else "%d" % record["uid"]
	if _actions.get_meta("key", "") == key:
		for b: Button in _actions.get_children():
			if b.has_meta("cost"):
				b.disabled = float(_state.get("money", 0)) < float(b.get_meta("cost"))
		return
	_clear_actions()
	_actions.set_meta("key", key)
	var sim := simulation
	if upgrades:
		for upgrade_id: String in data.upgrade_order:
			var up: Dictionary = data.upgrades[upgrade_id]
			var owned: bool = upgrade_id in record["upgrades"]
			var cost := sim.upgrade_cost(record, upgrade_id)
			var label := "✓ %s" % up["name"] if owned else "%s · %s · %s%%" % [up["name"], GameData.money(cost), data.facts["pct_" + upgrade_id]]
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
	b.custom_minimum_size = Vector2(SIDE_W - 8, 30)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 12)
	_style_button(b, false)
	_actions.add_child(b)
	return b


func _clear_actions() -> void:
	_actions.set_meta("key", "")
	for child in _actions.get_children():
		child.queue_free()


func show_message(message: String, is_error: bool = false) -> void:
	_toast.text = message
	_toast.add_theme_color_override("font_color", RED if is_error else GREEN)


func set_speed(speed: float) -> void:
	for s: float in _speed_buttons:
		_style_button(_speed_buttons[s], is_equal_approx(s, speed))


# ------------------------------------------------------------------ modal

func show_event(event: Dictionary) -> void:
	_modal.show()
	_modal_kicker.text = String(event.get("kicker", "NEWS"))
	_modal_title.text = String(event["title"])
	_modal_body.text = _fill(String(event["body"]))
	_set_options(event.get("options", []))
	_modal_continue.hide()


func reveal_event(event: Dictionary, chosen: int) -> void:
	var header := ""
	if event.get("kind") == "quiz":
		var answer := int(event["answer"])
		var options: Array = event["options"]
		header = "[b]%s[/b]  You said %s. Closest to the data: %s.\n\n" % ["Spot on." if chosen == answer else "Not quite.", options[chosen], options[answer]]
	else:
		header = "[b]You chose:[/b] %s\n\n" % event["options"][chosen]
	_modal_body.text = header + _fill(String(event.get("reveal", "")))
	_set_options([])
	_modal_continue.text = "Continue"
	_modal_continue.show()


func show_end(state: Dictionary, summary: Dictionary) -> void:
	_modal.show()
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


func _set_options(options: Array, attitude: bool = false) -> void:
	for child in _modal_options.get_children():
		child.queue_free()
	for i in range(options.size()):
		var b := Button.new()
		b.text = options[i]
		b.custom_minimum_size = Vector2(760, 38 if attitude else 42)
		b.add_theme_font_size_override("font_size", 16)
		_style_button(b, false)
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
