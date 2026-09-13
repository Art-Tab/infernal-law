extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func require(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		quit(1)
		assert(value, message)

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.save_path = "user://dialogue_test.json"
	for index in range(3):
		scene.restart()
		scene.case_index = index
		scene.phase = "receiving"
		scene.active = true
		for step in range(3):
			scene.show_dialogue()
			await process_frame
			var question_button: Button
			var available = 0
			for entry in scene.overlay.find_children("*", "Button", true, false):
				for pair in scene.CASES[index].dialogue:
					if entry.text == scene.tr(pair.question):
						available += 1
						question_button = entry
			require(available == 1 and question_button.text == scene.tr(scene.CASES[index].dialogue[step].question), "Only next question is offered")
			question_button.pressed.emit()
			question_button.pressed.emit()
			require(scene.dialogue_step == step + 1, "Double-click does not skip an answer")
			scene.close_modal()
			scene.show_dialogue()
			require(scene.dialogue_step == step + 1, "Reopening preserves step")
			scene.save_enabled = true
			scene.save_game()
			scene.save_enabled = false
			var restored = load("res://main.tscn").instantiate()
			root.add_child(restored)
			restored.save_path = scene.save_path
			restored.save_enabled = true
			restored.load_game()
			require(restored.dialogue_step == step + 1 and restored.case_index == index, "Save restores exact question progress")
			restored.queue_free()
			scene.show_dialogue_history()
			var history_text = ""
			for entry in scene.overlay.find_children("*", "Label", true, false):
				history_text += entry.text
			require(history_text.contains(scene.tr(scene.CASES[index].dialogue[step].answer)), "Answered line in history")
			if step < 2:
				require(not history_text.contains(scene.tr(scene.CASES[index].dialogue[step + 1].answer)), "History does not reveal future answers")
			scene.show_dialogue()
			await process_frame
			await process_frame
			var panel: Control = scene.overlay.get_child(1)
			require(root.get_visible_rect().encloses(panel.get_global_rect()), "Dialogue fits viewport")
			scene.close_modal()
			scene.show_verdict()
			require(not scene.overlay == null, "Verdict available during incomplete dialogue")
		scene.ask_question()
		require(scene.dialogue_step == 3, "Completed dialogue cannot advance further")
	# A completed legacy single-question interrogation stays completed.
	var file = FileAccess.open(scene.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"case_index":1,"questioned":true,"checked":false,"history":[]}))
	file.close()
	scene.save_enabled = true
	scene.load_game()
	scene.save_enabled = false
	require(scene.dialogue_step == 3 and scene.active, "Legacy interrogation migrated")
	scene.restart()
	require(scene.dialogue_step == 0, "Restart clears dialogue progress")
	print("PASS: sequential dialogue for all 3 cases, duplicate clicks, saved progress, hidden future replies, layout and legacy migration")
	quit()
