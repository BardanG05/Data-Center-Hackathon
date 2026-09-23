extends SceneTree
## Run after import: godot --headless --path . --script res://tests/quiz_flow_test.gd
## Add -- --capture in a rendered run for quiz and explanation screenshots.

var failures: Array[String] = []
var checks: int = 0
var game: Node
var capture: bool = false
var captured_types: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	_freeze_processing()
	await process_frame
	_check(game.data.error_message.is_empty(), "Game loads question bank: " + game.data.error_message)
	if not game.data.error_message.is_empty():
		_finish()
		return
	var interval: float = game.data.quiz_bank.interval_seconds
	var total: int = game.data.quiz_bank.total_count()
	_check(total == 36, "All 36 supplied questions load into the game")
	_check(game.active_event.get("id") == "welcome", "Welcome is the first modal")
	game._advance_quiz_timer(interval * 100.0)
	_check(game.data.quiz_bank.remaining_count() == total and is_zero_approx(game._quiz_elapsed), "Welcome time does not consume questions or timer")
	game.ui.event_option_chosen.emit(1)
	_check(game.active_event.is_empty() and not game.ui.is_modal_open() and not game.simulation.paused, "Skipping the welcome starts play without an immediate quiz")
	game._advance_quiz_timer(interval * 0.5)
	_check(not game.ui.is_modal_open(), "First quiz waits for the configured interval")
	game.set_speed(0.0)
	game._advance_quiz_timer(interval * 100.0)
	_check(is_equal_approx(game._quiz_elapsed, interval * 0.5), "Paused time creates no quiz backlog")
	game.set_speed(4.0)
	game._advance_quiz_timer(interval * 0.25)
	_check(is_equal_approx(game._quiz_elapsed, interval * 0.75) and not game.ui.is_modal_open(), "4x simulation speed does not accelerate quiz frequency")
	game._advance_quiz_timer(-1.0)
	game._advance_quiz_timer(INF)
	game._advance_quiz_timer(NAN)
	_check(is_equal_approx(game._quiz_elapsed, interval * 0.75), "Invalid elapsed time is ignored")
	game.simulation.state["finished"] = true
	game._advance_quiz_timer(interval * 100.0)
	_check(is_equal_approx(game._quiz_elapsed, interval * 0.75), "Finished games do not advance the timer")
	game.simulation.state["finished"] = false
	game._advance_quiz_timer(interval * 0.25)
	_check(game.active_event.get("kind") == "quiz" and game.simulation.paused, "The interval opens a quiz and pauses the simulation")
	_check(game.data.quiz_bank.remaining_count() == total - 1, "A question is consumed when it appears")

	var seen: Dictionary = {}
	for index in range(total):
		if index > 0:
			game._advance_quiz_timer(interval - 0.25)
			_check(game.active_event.is_empty(), "Question %d waits for a fresh interval" % (index + 1))
			game._advance_quiz_timer(0.25)
		if game.active_event.get("kind") != "quiz":
			_check(false, "Expected quiz %d to open" % (index + 1))
			break
		var question: Dictionary = game.active_event.duplicate(true)
		var id: String = question["id"]
		_check(not seen.has(id), "Question '%s' does not repeat" % id)
		seen[id] = true
		_check(game.data.quiz_bank.remaining_count() == total - index - 1, "Pool decreases once for '%s'" % id)
		if index == 0:
			# A due policy must wait until the currently displayed quiz is closed.
			game.simulation.state["year"] = 2023
			game.simulation.state["month"] = 1
			game._check_events()
			_check(game.active_event.get("id") == id and game.fired_events.is_empty(), "A due policy does not replace an open quiz")
		await _answer_quiz(question, index % 2 == 0)
		game.ui.event_closed.emit()
		if index == 0:
			_policy_after_quiz(total - 1, interval)
		_check(not game.ui.is_modal_open() and game.active_event.is_empty(), "Continue closes '%s'" % id)
		_check(not game.simulation.paused and is_equal_approx(game.simulation.speed, 4.0), "Continue restores the previous 4x speed")
		_check(is_zero_approx(game._quiz_elapsed), "Closing a quiz starts a fresh interval")

	_check(seen.size() == total and game.data.quiz_bank.remaining_count() == 0, "A full game can show every question exactly once")
	for _attempt in range(3):
		game._advance_quiz_timer(interval * 1000.0)
	_check(game.active_event.is_empty() and not game.ui.is_modal_open() and game.data.quiz_bank.remaining_count() == 0, "Exhausted questions never refill during the same game")
	await _restart_and_tutorial_test(total, seen)
	_finish()


func _answer_quiz(question: Dictionary, choose_correct: bool) -> void:
	var ui: TownUI = game.ui
	var options: Array = question["options"]
	var correct_index: int = options.find(question["correct_answer"])
	var chosen := correct_index if choose_correct else (correct_index + 1) % options.size()
	_check(ui._modal_options.get_child_count() == options.size(), "The popup has all answer choices")
	_check(ui._modal_body.text == question["question"] and not ui._modal_continue.visible, "The question appears before its explanation")
	var player_text: String = ui._modal_kicker.text + ui._modal_title.text + ui._modal_body.text
	_check(not player_text.contains(question["id"]) and not player_text.contains(question["source_label"]), "Technical IDs and source metadata stay out of the popup")
	for index in range(options.size()):
		var button: Button = ui._modal_options.get_child(index)
		_check(button.text == options[index] and not button.disabled, "Option %d is available before answering" % (index + 1))
	game.ui.event_option_chosen.emit(-1)
	game.ui.event_option_chosen.emit(options.size())
	game.ui.event_closed.emit()
	_check(not game._event_answered and game.active_event.get("id") == question["id"] and ui.is_modal_open(), "Invalid answers and premature Continue leave the question open")
	var remaining: int = game.data.quiz_bank.remaining_count()
	# Independently exercise the modal guard even if another caller resumes time.
	game.simulation.paused = false
	game._advance_quiz_timer(game.data.quiz_bank.interval_seconds * 100.0)
	game.simulation.paused = true
	_check(is_zero_approx(game._quiz_elapsed) and game.data.quiz_bank.remaining_count() == remaining, "Reading a question adds no timer backlog or overlapping quiz")
	var screenshot_names: Array[String] = []
	var type: String = question["type"]
	if not captured_types.has(type):
		captured_types[type] = true
		screenshot_names.append("quiz-" + type.to_lower())
	if question["id"] in ["small_prompt_scale", "tsmc_vs_hyperscale_water"]:
		screenshot_names.append("quiz-long-" + String(question["id"]))
	for name: String in screenshot_names:
		await _screenshot(name + "-question")
	var before: Dictionary = game.simulation.state.duplicate(true)
	ui.event_option_chosen.emit(chosen)
	_check(game._event_answered and ui._modal_continue.visible, "An answer reveals Continue")
	_check(ui._modal_body.text.contains(question["explanation"]) and ui._modal_body.text.contains("Correct answer: " + String(question["correct_answer"])), "The reveal explains the exact correct answer")
	_check(ui._modal_body.text.contains("Correct!" if choose_correct else "Not quite."), "The reveal reports whether the chosen answer was correct")
	_check(game.simulation.state == before, "Correct and wrong quiz answers do not change gameplay state, money or acceptance")
	for index in range(options.size()):
		var button: Button = ui._modal_options.get_child(index)
		_check(button.disabled, "Revealed answer buttons are disabled")
	var correct_button: Button = ui._modal_options.get_child(correct_index)
	_check(correct_button.get_theme_color("font_disabled_color") == TownUI.GREEN, "The correct answer is highlighted")
	var revealed_text: String = ui._modal_body.text
	ui.event_option_chosen.emit((chosen + 1) % options.size())
	_check(ui._modal_body.text == revealed_text and game.simulation.state == before, "A second answer cannot change feedback or apply effects")
	game._advance_quiz_timer(game.data.quiz_bank.interval_seconds * 100.0)
	_check(is_zero_approx(game._quiz_elapsed) and game.active_event.get("id") == question["id"], "Reading the explanation adds no backlog")
	for name: String in screenshot_names:
		await _screenshot(name + "-reveal")


func _policy_after_quiz(remaining: int, interval: float) -> void:
	_check(game.active_event.get("id") == "renewable_rule" and game.active_event.get("kind") == "policy", "The due policy opens after Continue, without overlap")
	_check(game.data.quiz_bank.remaining_count() == remaining, "Policy popups do not consume quiz questions")
	game._advance_quiz_timer(interval * 100.0)
	_check(is_zero_approx(game._quiz_elapsed), "Policy reading time adds no quiz backlog")
	game.ui.event_option_chosen.emit(1)
	var after_choice: Dictionary = game.simulation.state.duplicate(true)
	game.ui.event_option_chosen.emit(0)
	_check(game.simulation.state == after_choice, "A policy cannot apply its effects twice")
	game.ui.event_closed.emit()
	_check(game.fired_events.size() == 1 and game.data.quiz_bank.remaining_count() == remaining, "A policy fires once and leaves the quiz pool intact")


func _restart_and_tutorial_test(total: int, previously_seen: Dictionary) -> void:
	var old_instance_id: int = game.get_instance_id()
	game.ui.restart_requested.emit()
	_check(game.ui.is_modal_open() and game.ui._modal_title.text == "Restart this game?", "Restart opens a confirmation popup")
	_check(game.simulation.paused, "Restart confirmation pauses the game")
	game.ui.restart_cancelled.emit()
	_check(not game.ui.is_modal_open() and not game.simulation.paused, "Cancelling restart keeps the current game running")
	game.ui.restart_requested.emit()
	_check(game.ui.is_modal_open(), "Restart can be requested again after cancelling")
	game.ui.restart_confirmed.emit()
	await process_frame
	await process_frame
	game = current_scene
	_check(game != null and game.get_instance_id() != old_instance_id, "The actual restart signal reloads the scene")
	if game == null:
		return
	_freeze_processing()
	_check(game.data.quiz_bank.remaining_count() == total and game.data.quiz_bank.shown_ids.is_empty(), "Restart replenishes the entire question bank")
	_check(game.simulation.state["year"] == 2015 and game.simulation.state["month"] == 1 and game.fired_events.is_empty(), "Restart resets the calendar and policy history")
	_check(is_zero_approx(game._quiz_elapsed) and game.active_event.get("id") == "welcome", "Restart resets the timer and returns to welcome")
	game.ui.event_option_chosen.emit(0)
	_check(game.tutorial.active and game.ui.is_coaching(), "The tutorial starts through the welcome choice")
	game.simulation.paused = false
	game._advance_quiz_timer(game.data.quiz_bank.interval_seconds * 100.0)
	game.simulation.paused = true
	_check(game.active_event.is_empty() and is_zero_approx(game._quiz_elapsed) and game.data.quiz_bank.remaining_count() == total, "Tutorial reading time cannot trigger or queue quizzes")
	game.ui.coach_skip.emit()
	_check(not game.tutorial.active and not game.ui.is_modal_open() and not game.simulation.paused, "Leaving the tutorial begins play without an immediate quiz")
	game._advance_quiz_timer(game.data.quiz_bank.interval_seconds - 0.25)
	_check(game.active_event.is_empty(), "A fresh interval is required after the tutorial")
	game._advance_quiz_timer(0.25)
	_check(game.active_event.get("kind") == "quiz" and previously_seen.has(game.active_event.get("id")), "A new game can reuse a question from the previous game")
	_check(game.data.quiz_bank.remaining_count() == total - 1, "The new game has its own unused question pool")


func _freeze_processing() -> void:
	game.set_process(false)
	game.simulation.set_process(false)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _screenshot(name: String) -> void:
	if not capture:
		return
	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-output"))
	root.get_texture().get_image().save_png("res://test-output/%s.png" % name)


func _finish() -> void:
	print("Quiz flow: %d checks, %d failures" % [checks, failures.size()])
	for failure: String in failures:
		print("FAIL: " + failure)
	quit(1 if not failures.is_empty() else 0)
