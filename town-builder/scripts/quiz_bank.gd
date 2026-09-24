class_name QuizBank
extends RefCounted
## A shuffled pool for one game. Drawing consumes a question; only reset refills it.

const DEFAULT_INTERVAL_SECONDS: float = 60.0
const REQUIRED_TEXT_FIELDS: Array[String] = [
	"id", "type", "category", "question", "correct_answer", "explanation",
	"source_type", "source_label",
]
const OPTION_COUNTS: Dictionary = {
	"MULTIPLE_CHOICE": 4,
	"MYTH_OR_FACT": 2,
	"HIGHER_OR_LOWER": 2,
}

var error_message: String = ""
var interval_seconds: float = DEFAULT_INTERVAL_SECONDS
var shown_ids: Array[String] = []
## Drawn first in every game, so the opening hook is predictable. Empty = fully random.
var opening_question_id: String = ""
var _questions: Array[Dictionary] = []
var _unused: Array[Dictionary] = []


func configure(bank_data: Dictionary) -> bool:
	error_message = ""
	_questions.clear()
	_unused.clear()
	shown_ids.clear()
	interval_seconds = DEFAULT_INTERVAL_SECONDS
	opening_question_id = ""
	if bank_data.get("schema_version") != 1:
		return _fail("question_bank.json must use schema_version 1.")
	var interval: Variant = bank_data.get("interval_seconds", DEFAULT_INTERVAL_SECONDS)
	if not (interval is int or interval is float):
		return _fail("question_bank.json interval_seconds must be a positive number.")
	if not is_finite(float(interval)) or float(interval) <= 0.0:
		return _fail("question_bank.json interval_seconds must be a positive finite number.")
	var entries: Variant = bank_data.get("questions")
	if not entries is Array:
		return _fail("question_bank.json questions must be an array.")
	var ids: Dictionary = {}
	var enabled_questions: Array[Dictionary] = []
	for index in range(entries.size()):
		var entry: Variant = entries[index]
		var location := "question_bank.json question %d" % (index + 1)
		if not entry is Dictionary:
			return _fail("%s must be an object." % location)
		for field: String in REQUIRED_TEXT_FIELDS:
			if not entry.get(field) is String or String(entry.get(field)).strip_edges().is_empty():
				return _fail("%s needs a non-empty string for '%s'." % [location, field])
		var id: String = entry["id"]
		location = "question_bank.json question '%s'" % id
		if ids.has(id):
			return _fail("Duplicate question id: %s" % id)
		ids[id] = true
		if not OPTION_COUNTS.has(entry["type"]):
			return _fail("%s has an unsupported question type." % location)
		if entry.has("enabled") and not entry["enabled"] is bool:
			return _fail("%s enabled must be true or false." % location)
		var options: Variant = entry.get("options")
		if not options is Array:
			return _fail("%s options must be an array." % location)
		if options.size() != int(OPTION_COUNTS[entry["type"]]):
			return _fail("%s needs exactly %d options." % [location, OPTION_COUNTS[entry["type"]]])
		var unique_options: Dictionary = {}
		for option: Variant in options:
			if not option is String or String(option).strip_edges().is_empty():
				return _fail("%s options must be non-empty strings." % location)
			if unique_options.has(option):
				return _fail("%s has a duplicate answer option." % location)
			unique_options[option] = true
		if not unique_options.has(entry["correct_answer"]):
			return _fail("%s correct_answer must exactly match one option." % location)
		if entry.get("enabled", true):
			enabled_questions.append(entry.duplicate(true))
	var opening: Variant = bank_data.get("opening_question_id", "")
	if not opening is String:
		return _fail("question_bank.json opening_question_id must be a string.")
	if not String(opening).is_empty() and not ids.has(opening):
		return _fail("question_bank.json opening_question_id '%s' is not a question id." % opening)
	opening_question_id = opening
	interval_seconds = float(interval)
	_questions = enabled_questions
	reset()
	return true


func reset() -> void:
	shown_ids.clear()
	_unused.assign(_questions.duplicate(true))
	_unused.shuffle()
	# draw() pops from the back, so park the opening question there.
	for i in range(_unused.size()):
		if _unused[i]["id"] == opening_question_id:
			_unused.append(_unused.pop_at(i))
			break


func draw() -> Dictionary:
	if _unused.is_empty():
		return {}
	var question: Dictionary = _unused.pop_back()
	shown_ids.append(question["id"])
	return question.duplicate(true)


func remaining_count() -> int:
	return _unused.size()


func total_count() -> int:
	return _questions.size()


func _fail(message: String) -> bool:
	error_message = message
	return false
