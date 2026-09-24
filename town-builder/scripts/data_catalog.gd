class_name GameData
extends Node
## Only this component reads gameplay files. Survey opinion, sourced data and
## gameplay balance stay in separate files and are combined here.

var buildings: Dictionary = {}
var building_order: Array[String] = []
var upgrades: Dictionary = {}
var upgrade_order: Array[String] = []
var scenario: Dictionary = {}
var map: Dictionary = {}
var survey: Dictionary = {}
var real: Dictionary = {}
var events: Array = []
var quiz_bank: QuizBank = QuizBank.new()
## Rates the simulation uses, derived from survey.json.
var rates: Dictionary = {}
## Display values for event text, e.g. {"share_2025": "23.2"}.
var facts: Dictionary = {}
var error_message: String = ""


func load_all(data_dir: String = "res://data") -> bool:
	error_message = ""
	var building_file := _read_object(data_dir.path_join("buildings.json"))
	scenario = _read_object(data_dir.path_join("scenario.json"))
	map = _read_object(data_dir.path_join("map.json"))
	survey = _read_object(data_dir.path_join("survey.json"))
	real = _read_object(data_dir.path_join("real_world_data.json"))
	var event_file := _read_object(data_dir.path_join("events.json"))
	var question_file := _read_object(data_dir.path_join("question_bank.json"))
	if not error_message.is_empty():
		return false
	if not quiz_bank.configure(question_file):
		return _fail(quiz_bank.error_message)
	for entry: Dictionary in question_file.get("questions", []):
		var link: Variant = entry.get("survey_compare")
		if link != null and (not link is Dictionary or not survey.get("questions", {}).has(link.get("question", ""))):
			return _fail("Question '%s' has a survey_compare that does not match a survey.json question." % entry.get("id", "?"))
	buildings.clear()
	building_order.clear()
	for entry: Dictionary in building_file.get("buildings", []):
		if buildings.has(entry["id"]):
			return _fail("Duplicate building id: %s" % entry["id"])
		buildings[entry["id"]] = entry
		building_order.append(entry["id"])
	upgrades.clear()
	upgrade_order.clear()
	for entry: Dictionary in building_file.get("upgrades", []):
		upgrades[entry["id"]] = entry
		upgrade_order.append(entry["id"])
	events = event_file.get("events", [])
	if buildings.is_empty():
		return _fail("buildings.json has no buildings.")
	if map.get("rows", []).size() != int(map.get("height", -1)):
		return _fail("map.json rows do not match its height.")
	return _derive()


## Irish data-centre demand relative to 2015, interpolated by month.
func demand_index(year: int, month: int = 1) -> float:
	var table: Dictionary = real["derived"]["dc_demand_index"]["by_year"]
	var a := float(table.get(str(year), table[str(_clamp_year(table, year))]))
	var b := float(table.get(str(year + 1), a))
	return lerpf(a, b, float(month - 1) / 12.0)


## Growth of Ireland's other electricity customers; extrapolated past the data.
func other_demand_index(year: int) -> float:
	var table: Dictionary = real["derived"]["other_demand_index"]["by_year"]
	if table.has(str(year)):
		return float(table[str(year)])
	var last := _clamp_year(table, year)
	return float(table[str(last)]) * pow(1.0 + float(scenario["other_demand_growth_after_data"]), year - last)


## Ireland's data-centre share of metered electricity, or -1 without CSO data.
func ireland_dc_share(year: int) -> float:
	var cso: Dictionary = real["facts"]["cso_electricity_gwh"]["by_year"]
	if not cso.has(str(year)):
		return -1.0
	return float(cso[str(year)]["data_centres"]) / float(cso[str(year)]["total"])


## Game money is shown in thousands of pounds: 400 -> "£400k", 4000 -> "£4.0m".
static func money(value: float) -> String:
	var sign := "-" if value < 0.0 else ""
	var v := absf(value)
	if v >= 1000.0:
		return "%s£%.1fm" % [sign, v / 1000.0]
	return "%s£%dk" % [sign, roundi(v)]


static func thousands(value: float) -> String:
	var digits := str(absi(roundi(value)))
	var out := ""
	for i in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return ("-" if value < -0.5 else "") + out


func _clamp_year(table: Dictionary, year: int) -> int:
	var years: Array = table.keys().map(func(k: String) -> int: return int(k))
	return clampi(year, years.min(), years.max())


func _derive() -> bool:
	var q: Dictionary = survey.get("questions", {})
	var attitude: Dictionary = q["attitude"]
	var near: Dictionary = q["accept_within_5km"]
	rates["support"] = _share(attitude, ["Strongly supportive", "Somewhat supportive"])
	rates["objection_near"] = _share(near, ["Somewhat unacceptable", "Completely unacceptable"])
	rates["greenfield"] = _share(q["most_negative_areas"], ["Land use and built infrastructure (Manufactured)"])
	facts["pct_land_use"] = _pct(rates["greenfield"])
	facts["land_use_n"] = str(int(q["most_negative_areas"]["valid_n"]))
	var top3: Dictionary = q["top3_conditions"]
	for id: String in upgrade_order:
		var option: String = upgrades[id]["survey_option"]
		if not top3["counts"].has(option):
			return _fail("Upgrade '%s' refers to a survey option that is not in survey.json." % id)
		rates["upgrade_" + id] = float(top3["counts"][option]) / float(top3["valid_n"])
		facts["pct_" + id] = _pct(rates["upgrade_" + id])
	facts["top3_n"] = str(int(top3["valid_n"]))
	facts["support_pct"] = _pct(rates["support"])
	facts["support_n"] = str(int(attitude["valid_n"]))
	facts["objection_pct"] = _pct(rates["objection_near"])
	facts["objection_n"] = str(int(near["valid_n"]))
	facts["fossil_true"] = _pct(_share(q["belief_fossil_fuels"], ["True"]))
	facts["significant_true"] = _pct(_share(q["belief_significant_share"], ["True"]))
	facts["sample_size"] = str(int(survey["sample_size"]))
	var f: Dictionary = real["facts"]
	facts["share_2015"] = "%.1f" % (ireland_dc_share(2015) * 100.0)
	facts["share_2025"] = "%.1f" % (ireland_dc_share(2025) * 100.0)
	facts["gwh_2025"] = thousands(float(f["cso_electricity_gwh"]["by_year"]["2025"]["data_centres"]))
	facts["renew_2015"] = "%.1f" % (float(f["renewable_share_of_demand"]["by_year"]["2015"]) * 100.0)
	facts["renew_2025"] = "%.1f" % (float(f["renewable_share_of_demand"]["by_year"]["2025"]) * 100.0)
	facts["growth_2034"] = "%.1f" % demand_index(2034)
	var prio: Dictionary = f["energy_shortage_priority"]["by_sector"]
	facts["prio_health"] = _pct(prio["Public healthcare services"])
	facts["prio_food"] = _pct(prio["Agriculture / Food supply"])
	facts["prio_housing"] = _pct(prio["Housing / Residential"])
	facts["prio_dc"] = _pct(prio["Data centres"])
	return true


## "54% of 189" style comparison for a quiz reveal, or {} if the question has none.
func survey_comparison(question: Dictionary) -> Dictionary:
	var link: Variant = question.get("survey_compare")
	if not link is Dictionary:
		return {}
	var q: Dictionary = survey["questions"][link["question"]]
	return {"pct": _pct(_share(q, link.get("options", []))), "n": str(int(q["valid_n"])), "text": link.get("text", "")}


func _share(question: Dictionary, keys: Array) -> float:
	var total := 0.0
	for key: String in keys:
		total += float(question["counts"].get(key, 0))
	return total / maxf(float(question["valid_n"]), 1.0)


func _pct(fraction: float) -> String:
	var value := fraction * 100.0
	return str(roundi(value)) if value >= 10.0 else "%.1f" % value


func _read_object(path: String) -> Dictionary:
	if not error_message.is_empty():
		return {}
	if not FileAccess.file_exists(path):
		_fail("Missing data file: %s" % path)
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		_fail("%s, line %d: %s" % [path, parser.get_error_line(), parser.get_error_message()])
		return {}
	if not parser.data is Dictionary or parser.data.get("schema_version") != 1:
		_fail("Expected a schema_version 1 JSON object in %s." % path)
		return {}
	return parser.data


func _fail(message: String) -> bool:
	error_message = message
	return false
