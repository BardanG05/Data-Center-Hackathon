extends SceneTree
## Run after import: godot --headless --path . --script res://tests/question_bank_test.gd

const Bank = preload("res://scripts/quiz_bank.gd")
const TYPES := ["MULTIPLE_CHOICE", "MYTH_OR_FACT", "HIGHER_OR_LOWER"]

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_supplied_bank()
	_test_reset_and_reconfigure()
	_test_empty_and_disabled()
	_test_copy_isolation()
	_test_invalid_documents()
	print("%d question-bank checks, %d failures" % [checks, failures.size()])
	for failure in failures:
		print("FAIL: " + failure)
	quit(1 if failures.size() > 0 else 0)


func _test_supplied_bank() -> void:
	var file := FileAccess.open("res://data/question_bank.json", FileAccess.READ)
	_check(file != null, "The supplied question bank exists")
	if file == null:
		return
	var parser := JSON.new()
	var parse_error: Error = parser.parse(file.get_as_text())
	_check(parse_error == OK, "The supplied bank is valid JSON")
	if parse_error != OK:
		return
	_check(parser.data is Dictionary, "The supplied bank has an object root")
	if not parser.data is Dictionary:
		return
	var document: Dictionary = parser.data
	var bank = Bank.new()
	var configured: bool = bank.configure(document)
	_check(configured, "The supplied bank validates: " + bank.error_message)
	if not configured:
		return
	var originals: Dictionary = {}
	var types: Dictionary = {}
	for question: Dictionary in document["questions"]:
		if not question.get("enabled", true):
			continue
		var id: String = question["id"]
		_check(not originals.has(id), "The supplied question ID is unique: " + id)
		_check(question["correct_answer"] in question["options"], "The answer matches an option: " + id)
		_check(question["type"] in TYPES, "The question has a supported type: " + id)
		_check(not String(question["question"]).strip_edges().is_empty(), "The question has wording: " + id)
		_check(not String(question["explanation"]).strip_edges().is_empty(), "The answer has an explanation: " + id)
		_check(not String(question["source_label"]).strip_edges().is_empty(), "The answer identifies its source: " + id)
		originals[id] = question
		types[question["type"]] = true
	_check(types.size() == TYPES.size(), "The supplied bank includes all three question types")
	_check(originals.size() > 0, "The supplied bank has enabled questions")
	_check(bank.total_count() == originals.size(), "The total counts every enabled supplied question")
	_check(is_equal_approx(bank.interval_seconds, float(document["interval_seconds"])), "The interval comes from the data file")
	var drawn := _draw_all(bank, originals.size(), "Supplied bank")
	_check(drawn.size() == originals.size(), "Every enabled supplied question is drawn once")
	for id: String in drawn:
		_check(originals.has(id), "Every draw comes from the supplied bank: " + id)
		if originals.has(id):
			_check(drawn[id] == originals[id], "Drawing preserves question text, options, answer and source: " + id)
	_check_exhausted(bank, "Supplied bank")
	bank.reset()
	_check(bank.remaining_count() == originals.size(), "Restart restores the entire supplied bank")
	var restarted := _draw_all(bank, originals.size(), "Restarted supplied bank")
	_check(_same_ids(drawn, restarted), "Restart allows every original question again")
	_check_exhausted(bank, "Restarted supplied bank")


func _test_reset_and_reconfigure() -> void:
	var bank = Bank.new()
	var first := _document([_question("first"), _question("second"), _question("third")])
	_check(bank.configure(first), "A small bank configures")
	var initial: Dictionary = bank.draw()
	_check(not initial.is_empty() and bank.remaining_count() == 2, "One draw consumes one question")
	bank.reset()
	_check(bank.remaining_count() == 3, "Reset restores questions already seen in a partial game")
	var reset_draws := _draw_all(bank, 3, "Partially used bank after reset")
	_check(reset_draws.has(initial.get("id", "")), "A question seen before restart can appear after restart")
	_check_exhausted(bank, "Small bank")
	_check(bank.configure(first), "The same document can be configured again")
	_check(bank.total_count() == 3 and bank.remaining_count() == 3, "Reconfiguration clears seen state without duplicating questions")
	var replacement := _document([_question("replacement", "MYTH_OR_FACT")], 12.5)
	_check(bank.configure(replacement), "A replacement bank configures")
	_check(bank.total_count() == 1 and bank.remaining_count() == 1, "Reconfiguration discards old questions")
	_check(is_equal_approx(bank.interval_seconds, 12.5), "Reconfiguration replaces the popup interval")
	_check(bank.draw().get("id") == "replacement", "Only the replacement question can be drawn")
	_check_exhausted(bank, "Replacement bank")
	_check(bank.error_message.is_empty(), "Successful configuration leaves no validation error")


func _test_empty_and_disabled() -> void:
	var bank = Bank.new()
	var enabled := _question("enabled")
	enabled["enabled"] = true
	var disabled := _question("disabled")
	disabled["enabled"] = false
	_check(bank.configure(_document([enabled, disabled, _question("default_enabled")])), "Enabled and disabled entries can share a bank")
	_check(bank.total_count() == 2 and bank.remaining_count() == 2, "Disabled questions are excluded from both counts")
	var draws := _draw_all(bank, 2, "Bank with a disabled question")
	_check(draws.has("enabled") and draws.has("default_enabled") and not draws.has("disabled"), "Only explicitly or implicitly enabled questions appear")
	bank.reset()
	_check(bank.remaining_count() == 2, "Reset does not enable disabled questions")
	_check(bank.configure(_document([])), "An empty bank is valid")
	_check(bank.total_count() == 0 and bank.remaining_count() == 0, "An empty bank has zero questions")
	_check_exhausted(bank, "Empty bank")
	bank.reset()
	_check_exhausted(bank, "Empty bank after reset")
	_check(bank.configure(_document([disabled])), "A bank with all questions disabled is valid")
	_check(bank.total_count() == 0 and bank.remaining_count() == 0, "An all-disabled bank has zero playable questions")
	bank.reset()
	_check_exhausted(bank, "All-disabled bank after reset")


func _test_copy_isolation() -> void:
	var bank = Bank.new()
	var original := _question("original")
	var source := _document([original])
	_check(bank.configure(source), "The copy-isolation bank configures")
	original["id"] = "changed_in_source"
	original["options"][0] = "Changed answer"
	source["questions"].clear()
	var drawn: Dictionary = bank.draw()
	_check(drawn.get("id") == "original" and drawn.get("options", []) == ["One", "Two", "Three", "Four"], "Editing source dictionaries and arrays cannot change configured questions")
	drawn["id"] = "changed_after_draw"
	drawn["question"] = "Replaced wording"
	drawn["options"].clear()
	bank.reset()
	var redrawn: Dictionary = bank.draw()
	_check(redrawn == _question("original"), "Editing a drawn question cannot change the question restored on reset")
	_check(bank.total_count() == 1, "Caller mutations do not change the bank size")


func _test_invalid_documents() -> void:
	var invalid: Array[Dictionary] = []
	for interval in [0, -1, "30", true, null, INF, NAN]:
		invalid.append({"label": "Invalid interval %s" % str(interval), "document": _document([_question("one")], interval)})
	var document := _document([_question("one"), _question("one")])
	invalid.append({"label": "Duplicate question IDs", "document": document})
	for id in ["", "   ", 7]:
		document = _document([_question("one")])
		document["questions"][0]["id"] = id
		invalid.append({"label": "Invalid question ID %s" % str(id), "document": document})
	for type in ["UNSUPPORTED", "", 5]:
		document = _document([_question("one")])
		document["questions"][0]["type"] = type
		invalid.append({"label": "Invalid question type %s" % str(type), "document": document})
	for options in [[], ["One"], ["One", "Two"], ["One", "One", "Three", "Four"], ["", "Two", "Three", "Four"], ["One", "Two", 3, "Four"], "One,Two,Three,Four"]:
		document = _document([_question("one")])
		document["questions"][0]["options"] = options
		invalid.append({"label": "Invalid multiple-choice options %s" % str(options), "document": document})
	for type: String in ["MYTH_OR_FACT", "HIGHER_OR_LOWER"]:
		document = _document([_question("one", type)])
		document["questions"][0]["options"].append("Third option")
		invalid.append({"label": "Too many options for " + type, "document": document})
	for answer in ["Missing option", "", 1]:
		document = _document([_question("one")])
		document["questions"][0]["correct_answer"] = answer
		invalid.append({"label": "Invalid correct answer %s" % str(answer), "document": document})
	for missing: String in ["id", "type", "category", "question", "options", "correct_answer", "explanation", "source_type", "source_label"]:
		document = _document([_question("one")])
		document["questions"][0].erase(missing)
		invalid.append({"label": "Missing question field " + missing, "document": document})
	document = _document([_question("one")])
	document["questions"] = "not an array"
	invalid.append({"label": "Questions must be an array", "document": document})
	document = _document(["not a question"])
	invalid.append({"label": "Questions must contain objects", "document": document})
	document = _document([_question("one")])
	document["questions"][0]["enabled"] = "false"
	invalid.append({"label": "Enabled must be a boolean", "document": document})
	document = _document([_question("one")])
	document["schema_version"] = 99
	invalid.append({"label": "Unsupported schema version", "document": document})
	document = _document([_question("one")])
	document.erase("schema_version")
	invalid.append({"label": "Missing schema version", "document": document})
	for test_case: Dictionary in invalid:
		var bank = Bank.new()
		_check(not bank.configure(test_case["document"]), "Rejects: " + test_case["label"])
		_check(not bank.error_message.is_empty(), "Explains validation failure: " + test_case["label"])
		_check(bank.configure(_document([_question("recovered")])) and bank.error_message.is_empty(), "Valid configuration recovers after: " + test_case["label"])


func _draw_all(bank, count: int, label: String) -> Dictionary:
	var drawn: Dictionary = {}
	for index in range(count):
		var question: Dictionary = bank.draw()
		_check(not question.is_empty(), "%s: draw %d returns a question" % [label, index + 1])
		if question.is_empty():
			continue
		var id: String = question["id"]
		_check(not drawn.has(id), "%s: %s has not appeared earlier in this game" % [label, id])
		drawn[id] = question
		_check(bank.remaining_count() == count - index - 1, "%s: remaining count decreases once per draw" % label)
		_check(bank.total_count() == count, "%s: drawing does not change the total" % label)
	return drawn


func _check_exhausted(bank, label: String) -> void:
	_check(bank.remaining_count() == 0, label + ": no questions remain")
	for attempt in range(5):
		_check(bank.draw().is_empty(), "%s: exhausted draw %d never refills the pool" % [label, attempt + 1])
	_check(bank.remaining_count() == 0, label + ": exhausted draws keep the count at zero")


func _same_ids(first: Dictionary, second: Dictionary) -> bool:
	if first.size() != second.size():
		return false
	for id in first:
		if not second.has(id):
			return false
	return true


func _question(id: String, type: String = "MULTIPLE_CHOICE") -> Dictionary:
	var options: Array = ["One", "Two", "Three", "Four"]
	if type == "MYTH_OR_FACT":
		options = ["Myth", "Fact"]
	elif type == "HIGHER_OR_LOWER":
		options = ["Higher", "Lower"]
	return {
		"id": id, "type": type, "category": "TEST", "question": "Question " + id + "?",
		"options": options, "correct_answer": options[0], "explanation": "Explanation for " + id + ".",
		"source_type": "GENERAL", "source_label": "Test fixture",
	}


func _document(questions: Array, interval = 30.0) -> Dictionary:
	return {"schema_version": 1, "interval_seconds": interval, "questions": questions}


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
