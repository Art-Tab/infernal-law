extends SceneTree

const L10n = preload("res://localization.gd")
var checks = 0

func _initialize() -> void:
	call_deferred("run")

func require(value: bool, message: String) -> void:
	checks += 1
	if not value:
		push_error(message)
		quit(1)
		assert(value, message)

func visible_text(node: Node) -> String:
	var result = ""
	if node is Label or node is Button or node is Label3D:
		result += node.text + "\n"
	if node is OptionButton:
		for index in range(node.item_count):
			result += node.get_item_text(index) + "\n"
	for child in node.get_children():
		result += visible_text(child)
	return result

func check_screen(game: Node) -> void:
	var content = visible_text(game)
	for key in L10n.EN.get_message_list():
		require(not content.contains(key), "Visible translation key: " + key)
	require(root.get_visible_rect().encloses(game.language_choice.get_global_rect()), "Language selector fits viewport")
	if is_instance_valid(game.overlay):
		var panel: Control = game.overlay.get_child(1)
		require(root.get_visible_rect().encloses(panel.get_global_rect()), "Localized panel fits viewport")
		var scroll: ScrollContainer = panel.get_child(0).get_child(1)
		require(scroll.get_child(0).size.x <= scroll.size.x, "Localized content fits panel width")

func run() -> void:
	var en_keys = L10n.EN.get_message_list()
	var ru_keys = L10n.RU.get_message_list()
	en_keys.sort()
	ru_keys.sort()
	require(en_keys == ru_keys, "Both languages have identical keys")
	var placeholders = RegEx.new()
	placeholders.compile("%[ds]")
	for key in en_keys:
		var english: String = L10n.EN.get_message(key)
		var russian: String = L10n.RU.get_message(key)
		require(not english.is_empty() and not russian.is_empty(), "No empty translation: " + key)
		var en_params: Array = []
		var ru_params: Array = []
		for found in placeholders.search_all(english):
			en_params.append(found.get_string())
		for found in placeholders.search_all(russian):
			ru_params.append(found.get_string())
		require(en_params == ru_params, "Matching format arguments: " + key)

	var settings_path = "user://localization_test.cfg"
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(settings_path)
	L10n.initialize(true, settings_path)
	require(TranslationServer.get_locale() == "en", "First run defaults to English")
	L10n.select("ru", true, settings_path)
	L10n.select("en", false)
	L10n.initialize(true, settings_path)
	require(TranslationServer.get_locale() == "ru", "Language preference survives initialization")
	var invalid = ConfigFile.new()
	invalid.set_value("language", "locale", "xx")
	invalid.save(settings_path)
	L10n.initialize(true, settings_path)
	require(TranslationServer.get_locale() == "en", "Unsupported saved locale falls back to English")
	DirAccess.remove_absolute(settings_path)

	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.save_path = "user://localization_shift_test.json"
	await process_frame
	for locale in ["ru", "en"]:
		game.change_language(locale)
		await process_frame
		await process_frame
		check_screen(game)
		require(visible_text(game.overlay).contains(game.tr("APPOINTMENT_BODY")), "Appointment refreshes")
	game.close_modal()
	game.phase = "receiving"
	game.active = true
	for case_index in range(3):
		game.case_index = case_index
		game.dialogue_step = 1
		game.checked = true
		game.selected_circle = game.CASES[case_index].circle
		game.selected_fact = game.CASES[case_index].evidence
		for method in ["show_file", "show_dialogue", "show_dialogue_history", "show_rules", "show_verdict", "confirm_verdict"]:
			game.call(method)
			for locale in ["ru", "en"]:
				var before = [game.trust, game.requests, game.dialogue_step, game.selected_circle, game.selected_fact]
				game.change_language(locale)
				await process_frame
				await process_frame
				check_screen(game)
				require(before == [game.trust, game.requests, game.dialogue_step, game.selected_circle, game.selected_fact], "Switching does not mutate decisions")
				require(game.active_view == method, "Open screen preserved")
				if method == "show_dialogue":
					require(visible_text(game.overlay).contains(game.tr(game.CASES[case_index].dialogue[0].answer)), "Current answer translated")
				require(game.room.exit_label.text == game.tr("ROOM_DISTRIBUTION"), "Room sign translated")

	game.deliver_verdict()
	var history_size: int = game.history.size()
	game.change_language("ru")
	await process_frame
	await process_frame
	check_screen(game)
	require(game.history.size() == history_size and game.case_index == 3, "Result refresh does not sentence twice")
	require(game.history.back().name == "CASE_SEVERIN_NAME", "History stores keys")
	game.show_summary()
	game.change_language("en")
	await process_frame
	await process_frame
	check_screen(game)

	# Migrate an actual schema-4 style snapshot, including the combined failure reason.
	var old = {"schema":4, "case_index":1, "trust":-10, "active":false, "court":{
		"phase":"condemned", "step":4, "history_index":0,
		"reason":str(L10n.RU.get_message("COURT_REASON_WRONG")) + str(L10n.RU.get_message("CASE_MATVEY_EXPLANATION")),
		"review":{"name":str(L10n.RU.get_message("CASE_MATVEY_NAME")), "file":str(L10n.RU.get_message("CASE_MATVEY_FILE")),
			"facts":[str(L10n.RU.get_message("CASE_MATVEY_FACTS_1"))],
			"expected_circle":3, "expected_evidence":0, "actual_circle":str(L10n.RU.get_message("CIRCLE_1")),
			"actual_evidence":str(L10n.RU.get_message("CASE_MATVEY_FACTS_1")), "explanation":str(L10n.RU.get_message("CASE_MATVEY_EXPLANATION"))}},
		"history":[{"name":str(L10n.RU.get_message("CASE_MATVEY_NAME")), "circle":str(L10n.RU.get_message("CIRCLE_1")), "correct":false}]}
	var file = FileAccess.open(game.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	game.save_enabled = true
	game.load_game()
	game.save_enabled = false
	require(game.court_state.review.name == "CASE_MATVEY_NAME" and game.history[0].circle == "CIRCLE_1", "Legacy names and circles migrated")
	require(game.court_state.reason == "COURT_REASON_WRONG" and game.trust == -10, "Legacy reason migrated without changing outcome")
	require(L10n.migrate("Unknown historical wording") == "Unknown historical wording", "Unknown historical evidence preserved")
	game.court.resume()
	for locale in ["ru", "en"]:
		game.change_language(locale)
		await process_frame
		await process_frame
		check_screen(game)
		require(visible_text(game.overlay).contains(game.tr("CASE_MATVEY_EXPLANATION")), "Migrated reason explanation translated")
	DirAccess.remove_absolute(game.save_path)
	game.court.prepare(-1)
	game.court_state.phase = "defense"
	game.court_state.correction_circle = 3
	game.court_state.correction_evidence = 0
	game.court_state.responsibility = 1
	for step in range(5):
		game.court_state.step = step
		for method in ["show_defense", "show_documents"]:
			game.court.call(method)
			var snapshot = game.court_state.duplicate(true)
			for locale in ["ru", "en"]:
				game.change_language(locale)
				await process_frame
				await process_frame
				check_screen(game)
				require(game.court_state == snapshot and game.court.active_view == method, "Defense and selected answers preserved")
	game.court.resolve()
	for locale in ["ru", "en"]:
		game.change_language(locale)
		await process_frame
		await process_frame
		check_screen(game)
		require(game.trust == 25, "Successful review stays successful")
	game.court_state.phase = "over"
	game.court.show_game_over()
	game.change_language("ru")
	await process_frame
	await process_frame
	check_screen(game)
	game.restart()
	require(TranslationServer.get_locale() == "ru", "New game preserves language")
	game.phase = "approaching"
	game.change_language("en")
	require(TranslationServer.get_locale() == "ru", "Language change blocked during movement")
	game.phase = "tribunal"
	game.court.running = true
	game.change_language("en")
	require(TranslationServer.get_locale() == "ru", "Language change blocked during court cinematics")
	await create_timer(0.4).timeout
	game.queue_free()
	await process_frame
	print("PASS: ", checks, " localization checks (EN/RU, screens, state, settings and legacy saves)")
	quit()
