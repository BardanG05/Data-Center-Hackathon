class_name GameData
extends Node
## Only this component reads gameplay files. Facts/surveys stay separate from balance.

var buildings: Dictionary = {}
var scenario: Dictionary = {}
var error_message: String = ""


func load_all(data_dir: String = "res://data") -> bool:
	buildings.clear()
	scenario.clear()
	error_message = ""
	var building_file := _read_object(data_dir.path_join("buildings.json"))
	if not error_message.is_empty():
		return false
	var entries: Variant = building_file.get("buildings")
	if not entries is Array or entries.is_empty():
		return _fail("buildings.json needs a non-empty buildings array.")
	for entry in entries:
		if not entry is Dictionary:
			return _fail("Every building must be a JSON object.")
		for key in ["id", "name", "description"]:
			if not entry.get(key) is String or str(entry[key]).is_empty():
				return _fail("Building needs a non-empty '%s'." % key)
		if buildings.has(entry["id"]):
			return _fail("Duplicate building id: %s" % entry["id"])
		for key in ["cost", "electricity_usage", "water_usage", "compute_capacity"]:
			if not _nonnegative_number(entry, key):
				return _fail("Building '%s' needs a non-negative number for '%s'." % [entry["id"], key])
		buildings[entry["id"]] = entry.duplicate(true)
	if not buildings.has("data_centre"):
		return _fail("MVP 0.1 requires a building with id 'data_centre'.")
	scenario = _read_object(data_dir.path_join("scenario.json"))
	if not error_message.is_empty():
		return false
	for key in ["starting_money", "population", "electricity_capacity", "electricity_usage",
		"water_capacity", "water_usage", "compute_capacity", "compute_demand", "tick_seconds"]:
		if not _nonnegative_number(scenario, key):
			return _fail("scenario.json needs a non-negative number for '%s'." % key)
	if float(scenario["tick_seconds"]) <= 0.0:
		return _fail("tick_seconds must be greater than zero.")
	return true


func _read_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_fail("Missing data file: %s" % path)
		return {}
	var parser := JSON.new()
	var result := parser.parse(FileAccess.get_file_as_string(path))
	if result != OK:
		_fail("%s, line %d: %s" % [path, parser.get_error_line(), parser.get_error_message()])
		return {}
	if not parser.data is Dictionary:
		_fail("Expected a JSON object in %s." % path)
		return {}
	var object: Dictionary = parser.data
	if object.get("schema_version") != 1:
		_fail("Unsupported or missing schema_version in %s." % path)
		return {}
	return object


func _nonnegative_number(object: Dictionary, key: String) -> bool:
	var value: Variant = object.get(key)
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0


func _fail(message: String) -> bool:
	error_message = message
	return false
