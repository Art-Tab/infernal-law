extends SceneTree

var checks = 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("FAIL: " + message)
		quit(1)
		assert(value, message)
	checks += 1

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.phase == "waiting" and scene.room.visitors.size() == 3, "Fresh queue")
	scene.call_next()
	scene.call_next()
	check(scene.phase == "approaching" and scene.case_index == 0, "Duplicate calls blocked")
	await create_timer(1.9).timeout
	check(scene.phase == "receiving", "Approach completes")
	scene.show_file()
	scene.check_archive()
	scene.check_archive()
	check(scene.requests == 1, "Archive charged once")
	scene.ask_question()
	scene.save_enabled = true
	scene.save_game()
	scene.save_enabled = false
	var restored = load("res://main.tscn").instantiate()
	root.add_child(restored)
	restored.save_enabled = true
	restored.load_game()
	check(restored.active and restored.checked and restored.questioned and restored.requests == 1, "Active case reload")
	restored.queue_free()
	# Check legacy 0.0.1 files without schema or active marker.
	var old_file = FileAccess.open(scene.save_path, FileAccess.WRITE)
	old_file.store_string(JSON.stringify({"case_index":1,"requests":0,"checked":true,"questioned":false,"trust":80,"history":[]}))
	old_file.close()
	var legacy = load("res://main.tscn").instantiate()
	root.add_child(legacy)
	legacy.save_enabled = true
	legacy.load_game()
	legacy.room.restore(legacy.case_index, legacy.active)
	check(legacy.active and legacy.case_index == 1 and legacy.room.visitors.size() == 2, "Legacy save compatibility")
	legacy.queue_free()
	for index in range(3):
		if index > 0:
			scene.call_next()
			await create_timer(1.9).timeout
		scene.show_rules()
		scene.close_modal()
		scene.show_verdict()
		scene.selected_circle = scene.CASES[index].circle
		scene.selected_fact = scene.CASES[index].evidence
		scene.confirm_verdict()
		scene.deliver_verdict()
		scene.deliver_verdict()
		check(scene.case_index == index + 1 and scene.history.size() == index + 1, "Single verdict per case")
		scene.save_enabled = true
		scene.save_game()
		scene.save_enabled = false
		var saved = JSON.parse_string(FileAccess.get_file_as_string(scene.save_path))
		check(not saved.active and saved.case_index == index + 1, "Sentenced soul not restored")
		scene.finish_departure(index, scene.CIRCLES[scene.CASES[index].circle])
		scene.finish_departure(index, "ignored")
		await create_timer(3.0).timeout
		check(scene.room.visitors.size() == 2 - index, "Soul leaves queue permanently")
	check(scene.phase == "finished" and scene.trust == 100, "Full shift and correct verdicts")
	scene.restart()
	check(scene.phase == "waiting" and scene.room.visitors.size() == 3 and scene.requests == 2, "Restart resets shift")
	scene.call_next()
	await create_timer(1.9).timeout
	scene.selected_circle = 0
	scene.selected_fact = 0
	scene.deliver_verdict()
	check(scene.trust == 80, "Incorrect verdict penalty")
	print("PASS: ", checks, " gameplay/save checks")
	quit(0)
