extends Node

var game: Node
var running = false
var next_button: Button
var active_view = ""

func state() -> Dictionary:
	return game.court_state

func refresh_language() -> void:
	if not running and active_view in ["show_defense", "show_documents", "show_result", "show_game_over"]:
		call(active_view)

func prepare(history_index: int) -> void:
	var review: Dictionary = {}
	if history_index >= 0 and history_index < game.history.size():
		review = game.history[history_index].get("review", {}).duplicate(true)
	if review.is_empty():
		var data: Dictionary = game.CASES[0]
		review = {"name":data.name, "file":data.file, "facts":data.facts.duplicate(),
			"expected_circle":data.circle, "expected_evidence":data.evidence,
			"explanation":data.explanation, "actual_circle":"MISSING_CIRCLE", "actual_evidence":"MISSING_EVIDENCE", "control":true}
	game.court_state = {"phase":"pending", "step":0, "review":review, "history_index":history_index,
		"correction_circle":-1, "correction_evidence":-1, "responsibility":-1, "opening":-1, "motive":-1}

func resume() -> void:
	if running:
		return
	if state().get("phase", "none") == "none":
		prepare(-1)
	game.phase = "tribunal"
	game.close_modal()
	game.build_hud()
	match state().phase:
		"pending", "queue":
			play_queue()
		"defense":
			game.room.court_view(game.case_index, false)
			show_defense()
		"restored":
			game.room.court_view(game.case_index, false)
			show_result()
		"condemned":
			game.room.court_view(game.case_index, false)
			show_result()
		"execution":
			game.room.court_view(game.case_index, false)
			play_execution()
		"over":
			show_game_over()

func pause(seconds: float) -> void:
	await get_tree().create_timer(seconds * game.room.cinematic_time).timeout

func caption(value: String) -> void:
	var body = game.open_modal(tr("COURT_TITLE"), false)
	active_view = "caption"
	var panel: Control = game.overlay.get_child(1)
	panel.anchor_left = 0.15
	panel.anchor_right = 0.85
	panel.anchor_top = 0.74
	panel.anchor_bottom = 0.97
	var shade: ColorRect = game.overlay.get_child(0)
	shade.color.a = 0.08
	body.add_child(game.text_label(value, 22))

func fade(out: bool) -> void:
	game.close_modal()
	var cover = ColorRect.new()
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.color = Color(0, 0, 0, 0 if out else 1)
	game.ui_root.add_child(cover)
	var tween = create_tween()
	tween.tween_property(cover, "color:a", 1.0 if out else 0.0, 0.45 * game.room.cinematic_time)
	await tween.finished
	if out:
		# Keep the opaque frame until the view is changed by the caller.
		await get_tree().process_frame
	cover.queue_free()

func play_queue() -> void:
	running = true
	state().phase = "queue"
	game.save_game()
	caption(tr("COURT_SUSPENDED"))
	await pause(2.5)
	await fade(true)
	game.room.court_view(game.case_index, true)
	await fade(false)
	caption(tr("COURT_SOUL_PLEA"))
	await pause(2.5)
	game.room.stamp()
	caption(tr("COURT_JUDGE_SENTENCE"))
	await pause(1.8)
	await game.room.depart(3, game.CIRCLES[4])
	caption(tr("COURT_NEXT"))
	await pause(1.0)
	await game.room.walk_to_judge()
	state().phase = "defense"
	game.save_game()
	running = false
	show_defense()

func choose(key: String, value: int, expected: int, next_step: int) -> void:
	if state().phase != "defense" or int(state().step) != expected:
		return
	state()[key] = value
	state().step = next_step
	game.save_game()
	show_defense()

func choose_correction(key: String, value: int) -> void:
	if state().phase != "defense" or int(state().step) != 2:
		return
	state()[key] = value
	game.save_game()
	if is_instance_valid(next_button):
		next_button.disabled = int(state().correction_circle) < 0 or int(state().correction_evidence) < 0

func show_defense() -> void:
	if state().phase != "defense":
		return
	var body = game.open_modal(tr("COURT_CASE_TITLE") + str(int(state().step) + 1) + "/5", false)
	active_view = "show_defense"
	var review: Dictionary = state().review
	match int(state().step):
		0:
			body.add_child(game.text_label(tr("COURT_BACKSTORY"), 21))
			body.add_child(game.text_label(tr("COURT_ACCUSATION")))
			body.add_child(game.button(tr("COURT_OPEN_DENY"), func(): choose("opening", 0, 0, 1)))
			body.add_child(game.button(tr("COURT_OPEN_REVIEW"), func(): choose("opening", 1, 0, 1)))
		1:
			if review.get("control", false):
				body.add_child(game.text_label(tr("COURT_LEGACY")))
			else:
				body.add_child(game.text_label(tr("COURT_ACTUAL") % [tr(review.name), tr(review.actual_circle), tr(review.actual_evidence)]))
			body.add_child(game.text_label(tr("COURT_EXPLAIN")))
			body.add_child(game.button(tr("COURT_MOTIVE_CONFUSED"), func(): choose("motive", 0, 1, 2)))
			body.add_child(game.button(tr("COURT_MOTIVE_MERCY"), func(): choose("motive", 1, 1, 2)))
			body.add_child(game.button(tr("COURT_MOTIVE_UNCHECKED"), func(): choose("motive", 2, 1, 2)))
		2:
			body.add_child(game.text_label(tr("COURT_CORRECT_PROMPT")))
			var circles = OptionButton.new()
			circles.add_item(tr("COURT_SELECT_CIRCLE"))
			for label in game.CIRCLES:
				circles.add_item(tr(label))
			circles.selected = int(state().correction_circle) + 1
			circles.item_selected.connect(func(index: int): choose_correction("correction_circle", index - 1))
			body.add_child(circles)
			var evidence = OptionButton.new()
			evidence.add_item(tr("COURT_SELECT_EVIDENCE"))
			for label in review.facts:
				evidence.add_item(tr(label))
			evidence.selected = int(state().correction_evidence) + 1
			evidence.item_selected.connect(func(index: int): choose_correction("correction_evidence", index - 1))
			body.add_child(evidence)
			next_button = game.button(tr("COURT_SUBMIT"), func(): choose("submitted", 1, 2, 3), int(state().correction_circle) < 0 or int(state().correction_evidence) < 0)
			body.add_child(next_button)
		3:
			body.add_child(game.text_label(tr("COURT_RESPONSIBILITY")))
			body.add_child(game.button(tr("COURT_ACCEPT"), func(): choose("responsibility", 1, 3, 4)))
			body.add_child(game.button(tr("COURT_ACCEPT_MERCY"), func(): choose("responsibility", 2, 3, 4)))
			body.add_child(game.button(tr("COURT_REFUSE"), func(): choose("responsibility", 0, 3, 4)))
		4:
			body.add_child(game.text_label(tr("COURT_CONFIRM") % [tr(game.CIRCLES[int(state().correction_circle)]), tr(review.facts[int(state().correction_evidence)]), tr("COURT_AGREE") if int(state().responsibility) > 0 else tr("COURT_DISAGREE")]))
			body.add_child(game.text_label(tr("COURT_FINAL_WARNING")))
			body.add_child(game.button(tr("COURT_FINISH"), resolve))
			body.add_child(game.button(tr("COURT_CHANGE_CORRECTION"), func(): choose("submitted", 0, 4, 2)))
			body.add_child(game.button(tr("COURT_CHANGE_RESPONSIBILITY"), func(): choose("responsibility", -1, 4, 3)))
	body.add_child(game.button(tr("COURT_DOCUMENTS"), show_documents))

func show_documents() -> void:
	if state().phase != "defense":
		return
	var review: Dictionary = state().review
	var body = game.open_modal(tr("COURT_DOCUMENTS_TITLE") + tr(review.name), false)
	active_view = "show_documents"
	body.add_child(game.text_label(review.file))
	for index in range(9):
		body.add_child(game.text_label(tr(game.CIRCLES[index]) + " — " + tr(game.Data.RULES[index])))
	body.add_child(game.text_label(tr("COURT_PRIORITY")))
	body.add_child(game.button(tr("COURT_BACK"), show_defense))

func resolve() -> void:
	if state().phase != "defense" or int(state().step) != 4:
		return
	var review: Dictionary = state().review
	var corrected: bool = int(state().correction_circle) == int(review.expected_circle) and int(state().correction_evidence) == int(review.expected_evidence)
	var accepted: bool = int(state().responsibility) > 0
	state().phase = "restored" if corrected and accepted else "condemned"
	state()["reason"] = "COURT_REASON_SUCCESS" if corrected and accepted else ("COURT_REASON_WRONG" if not corrected else "COURT_REASON_REFUSED")
	if corrected and accepted:
		game.trust = 25
		var index = int(state().history_index)
		if index >= 0 and index < game.history.size():
			game.history[index]["reviewed"] = true
	game.save_game()
	game.room.stamp()
	show_result()

func show_result() -> void:
	var success: bool = state().phase == "restored"
	var body = game.open_modal(tr("COURT_RESTORED") if success else tr("COURT_CONDEMNED"), false)
	active_view = "show_result"
	body.add_child(game.text_label(state().reason, 22))
	if state().reason == "COURT_REASON_WRONG":
		body.add_child(game.text_label(state().review.explanation))
	if success:
		body.add_child(game.text_label(tr("COURT_RETURN_SPEECH")))
		body.add_child(game.button(tr("COURT_RETURN"), return_to_desk))
	else:
		body.add_child(game.text_label(tr("COURT_SENTENCE_PREFIX") + tr(game.CIRCLES[game.personal_circle])))
		body.add_child(game.button(tr("COURT_EXECUTE"), start_execution))

func return_to_desk() -> void:
	if state().phase != "restored" or running:
		return
	running = true
	await fade(true)
	game.room.desk_view(game.case_index)
	await fade(false)
	game.court_state = {"phase":"none"}
	game.active = false
	game.phase = "finished" if game.case_index >= 3 else "waiting"
	game.save_game()
	game.build_hud()
	running = false
	if game.phase == "finished":
		game.show_summary()

func start_execution() -> void:
	if state().phase != "condemned" or running:
		return
	state().phase = "execution"
	game.save_game()
	play_execution()

func play_execution() -> void:
	running = true
	caption(tr("COURT_CIRCLE_PREFIX") + tr(game.CIRCLES[game.personal_circle]))
	await game.room.walk_to_hell(game.CIRCLES[game.personal_circle])
	await fade(true)
	state().phase = "over"
	game.save_game()
	running = false
	show_game_over()

func show_game_over() -> void:
	game.close_modal()
	var body = game.open_modal(tr("GAME_OVER_TITLE"), false)
	active_view = "show_game_over"
	var shade: ColorRect = game.overlay.get_child(0)
	shade.color.a = 1.0
	body.add_child(game.text_label(tr(game.CIRCLES[game.personal_circle]) + tr("GAME_OVER_BODY"), 25))
	body.add_child(game.button(tr("ACTION_NEW_GAME"), game.restart))
	body.add_child(game.button(tr("ACTION_EXIT"), func(): get_tree().quit()))
