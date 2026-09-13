extends Node

var game: Node
var running = false
var next_button: Button

func state() -> Dictionary:
	return game.court_state

func prepare(history_index: int) -> void:
	var review: Dictionary = {}
	if history_index >= 0 and history_index < game.history.size():
		review = game.history[history_index].get("review", {}).duplicate(true)
	if review.is_empty():
		var data: Dictionary = game.CASES[0]
		review = {"name":data.name, "file":data.file, "facts":data.facts.duplicate(),
			"expected_circle":data.circle, "expected_evidence":data.evidence,
			"explanation":data.explanation, "actual_circle":"Не сохранён", "actual_evidence":"Не сохранено", "control":true}
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
	var body = game.open_modal("СЛУЖЕБНЫЙ ТРИБУНАЛ", false)
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
	caption("Полномочия приостановлены. Займите место в очереди.")
	await pause(2.5)
	await fade(true)
	game.room.court_view(game.case_index, true)
	await fade(false)
	caption("Душа перед вами: «Прошу, вы не всё учли…»")
	await pause(2.5)
	game.room.stamp()
	caption("Старший судья: «Пятый круг. Следуйте к выходу».")
	await pause(1.8)
	await game.room.depart(3, game.CIRCLES[4])
	caption("«Следующий. Бывший регистратор».")
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
	var body = game.open_modal("ВАШЕ ДЕЛО · " + str(int(state().step) + 1) + "/5", false)
	var review: Dictionary = state().review
	match int(state().step):
		0:
			body.add_child(game.text_label("Служба была отсрочкой. Ваш личный приговор — VIII круг за подделку прошений за плату. Сейчас решается, останетесь ли вы судьёй.", 21))
			body.add_child(game.text_label("«Вы считали ошибки чужой проблемой. Теперь передо мной ваше дело»."))
			body.add_child(game.button("Я не должен быть в этой очереди", func(): choose("opening", 0, 0, 1)))
			body.add_child(game.button("Я прошу пересмотреть отстранение", func(): choose("opening", 1, 0, 1)))
		1:
			if review.get("control", false):
				body.add_child(game.text_label("В старой записи не хватает сведений. Суд предлагает контрольное дело; этот приговор вам не приписывается."))
			else:
				body.add_child(game.text_label("Ваше постановление: %s → %s\nОснование: %s" % [review.name, review.actual_circle, review.actual_evidence]))
			body.add_child(game.text_label("«Объясните, как вы пришли к этому решению»."))
			body.add_child(game.button("Я спутал мотив поступка с главным основанием", func(): choose("motive", 0, 1, 2)))
			body.add_child(game.button("Я хотел смягчить наказание", func(): choose("motive", 1, 1, 2)))
			body.add_child(game.button("Я не проверил все обстоятельства", func(): choose("motive", 2, 1, 2)))
		2:
			body.add_child(game.text_label("«Покажите, каким должно быть обоснованное постановление»."))
			var circles = OptionButton.new()
			circles.add_item("Исправленный круг…")
			for label in game.CIRCLES:
				circles.add_item(label)
			circles.selected = int(state().correction_circle) + 1
			circles.item_selected.connect(func(index: int): choose_correction("correction_circle", index - 1))
			body.add_child(circles)
			var evidence = OptionButton.new()
			evidence.add_item("Обоснование…")
			for label in review.facts:
				evidence.add_item(label)
			evidence.selected = int(state().correction_evidence) + 1
			evidence.item_selected.connect(func(index: int): choose_correction("correction_evidence", index - 1))
			body.add_child(evidence)
			next_button = game.button("Представить исправление", func(): choose("submitted", 1, 2, 3), int(state().correction_circle) < 0 or int(state().correction_evidence) < 0)
			body.add_child(next_button)
		3:
			body.add_child(game.text_label("«Вы готовы отвечать за пересмотр?»"))
			body.add_child(game.button("Я признаю ошибку и согласен на пересмотр", func(): choose("responsibility", 1, 3, 4)))
			body.add_child(game.button("Я хотел смягчить наказание, но приму пересмотр", func(): choose("responsibility", 2, 3, 4)))
			body.add_child(game.button("Я отказываюсь пересматривать решение", func(): choose("responsibility", 0, 3, 4)))
		4:
			body.add_child(game.text_label("Исправление: %s\nОснование: %s\nПересмотр: %s" % [game.CIRCLES[int(state().correction_circle)], review.facts[int(state().correction_evidence)], "согласен" if int(state().responsibility) > 0 else "отказываюсь"]))
			body.add_child(game.text_label("После подтверждения решение суда окончательно."))
			body.add_child(game.button("Завершить защиту", resolve))
			body.add_child(game.button("Изменить исправление", func(): choose("submitted", 0, 4, 2)))
			body.add_child(game.button("Изменить ответ о пересмотре", func(): choose("responsibility", -1, 4, 3)))
	body.add_child(game.button("Прочитать документы и правила", show_documents))

func show_documents() -> void:
	if state().phase != "defense":
		return
	var review: Dictionary = state().review
	var body = game.open_modal("МАТЕРИАЛЫ ПЕРЕСМОТРА · " + review.name, false)
	body.add_child(game.text_label(review.file))
	for index in range(9):
		body.add_child(game.text_label(game.CIRCLES[index] + " — " + game.Data.RULES[index]))
	body.add_child(game.text_label("Приоритет: особое доверие → способ причинения вреда → мотив. Дополнительный архив не требуется."))
	body.add_child(game.button("Вернуться к защите", show_defense))

func resolve() -> void:
	if state().phase != "defense" or int(state().step) != 4:
		return
	var review: Dictionary = state().review
	var corrected: bool = int(state().correction_circle) == int(review.expected_circle) and int(state().correction_evidence) == int(review.expected_evidence)
	var accepted: bool = int(state().responsibility) > 0
	state().phase = "restored" if corrected and accepted else "condemned"
	state()["reason"] = "Исправление обосновано, пересмотр принят." if corrected and accepted else ("Исправление не обосновано. " + review.explanation if not corrected else "Вы отказались от пересмотра своего постановления.")
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
	var body = game.open_modal("ОТСРОЧКА ПРОДЛЕНА" if success else "ОТСРОЧКА ОТМЕНЕНА", false)
	body.add_child(game.text_label(state().reason, 22))
	if success:
		body.add_child(game.text_label("«Вернитесь к обязанностям. Доверие восстановлено до 25. Ошибки останутся в вашем деле»."))
		body.add_child(game.button("Вернуться за стол", return_to_desk))
	else:
		body.add_child(game.text_label("Личный приговор вступает в силу: " + game.CIRCLES[game.personal_circle]))
		body.add_child(game.button("Следовать к назначенному кругу", start_execution))

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
	caption("Ваш круг: " + game.CIRCLES[game.personal_circle])
	await game.room.walk_to_hell(game.CIRCLES[game.personal_circle])
	await fade(true)
	state().phase = "over"
	game.save_game()
	running = false
	show_game_over()

func show_game_over() -> void:
	game.close_modal()
	var body = game.open_modal("СЛУЖБА ОКОНЧЕНА", false)
	var shade: ColorRect = game.overlay.get_child(0)
	shade.color.a = 1.0
	body.add_child(game.text_label(game.CIRCLES[game.personal_circle] + "\nЛичный приговор приведён в исполнение.", 25))
	body.add_child(game.button("Новое прохождение", game.restart))
	body.add_child(game.button("Выйти", func(): get_tree().quit()))
