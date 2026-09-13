extends SceneTree

var checks = 0

func _initialize() -> void:
	call_deferred("run")

func require(value: bool, message: String) -> void:
	checks += 1
	if not value:
		push_error("FAIL: " + message)
		quit(1)
		assert(value, message)

func make_game() -> Node:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.save_path = "user://tribunal_test.json"
	game.room.cinematic_time = 0.015
	game.close_modal()
	return game

func seat(game: Node, index: int) -> void:
	game.case_index = index
	game.active = true
	game.phase = "receiving"
	game.room.restore(index, true)
	game.close_modal()

func wrong(game: Node) -> void:
	game.selected_circle = 0
	game.selected_fact = 0
	game.deliver_verdict()

func save_and_reload(game: Node) -> Node:
	game.save_enabled = true
	game.save_game()
	game.save_enabled = false
	var loaded = make_game()
	loaded.save_enabled = true
	loaded.load_game()
	loaded.save_enabled = false
	return loaded

func defend(game: Node, good: bool, accept: bool = true) -> void:
	var court: Node = game.court
	court.choose("opening", 0, 0, 1)
	court.choose("opening", 0, 0, 1)
	require(game.court_state.step == 1, "Opening duplicate ignored")
	court.choose("motive", 0, 1, 2)
	var review: Dictionary = game.court_state.review
	court.choose_correction("correction_circle", int(review.expected_circle) if good else 0)
	court.choose_correction("correction_evidence", int(review.expected_evidence))
	court.choose("submitted", 1, 2, 3)
	court.choose("responsibility", 1 if accept else 0, 3, 4)
	court.resolve()
	court.resolve()

func run() -> void:
	var game = make_game()
	require(game.trust == 40, "New trust balance")
	seat(game, 0)
	wrong(game)
	require(game.trust == 15 and game.court_state.phase == "none", "First error stays on duty")
	game.finish_departure(0, game.CIRCLES[0])
	await create_timer(3.0).timeout
	require(game.phase == "waiting", "First ordinary departure")
	seat(game, 1)
	game.requests = 1
	wrong(game)
	game.deliver_verdict()
	require(game.trust == -10 and game.history.size() == 2, "Second error below zero only once")
	require(game.court_state.phase == "pending", "Tribunal pending until departure")
	require(game.court_state.review.actual_circle == game.CIRCLES[0] and game.history[1].case_id == "agata_water", "Real ruling recorded")
	var pending_load = save_and_reload(game)
	pending_load.court.resume()
	require(pending_load.court_state.phase == "queue", "Pending tribunal resumes as queue scene")
	var queue_load = save_and_reload(pending_load)
	queue_load.court.resume()
	await create_timer(0.5).timeout
	require(queue_load.court_state.phase == "defense", "Queue checkpoint resumes without losing the hearing")
	pending_load.queue_free()
	queue_load.queue_free()
	await process_frame
	game.finish_departure(1, game.CIRCLES[0])
	game.finish_departure(1, game.CIRCLES[0])
	await create_timer(3.4).timeout
	require(game.court_state.phase == "defense", "Queue film reaches defense")
	require(not game.hud.visible and game.room.visitors.has(4) and not game.room.visitors.has(3), "Judge present and preceding soul gone")
	require(game.room.camera.position.distance_to(Vector3(0,1.65,0.1)) < 0.01, "Player at defendant marker")
	game.court.choose("opening", 0, 0, 1)
	game.court.choose("motive", 1, 1, 2)
	game.court.choose_correction("correction_circle", 7)
	var loaded = save_and_reload(game)
	loaded.court.resume()
	require(loaded.trust == -10 and loaded.court_state.step == 2 and loaded.court_state.correction_circle == 7, "Negative trust and defense progress reload")
	loaded.queue_free()
	game.court.choose_correction("correction_evidence", 1)
	game.court.choose("submitted", 1, 2, 3)
	game.court.choose("responsibility", 2, 3, 4)
	game.court.resolve()
	game.court.resolve()
	require(game.trust == 25 and game.court_state.phase == "restored", "Successful defense restores fixed trust")
	require(game.history[1].reviewed and game.requests == 1, "Review flag and archive retained")
	loaded = save_and_reload(game)
	loaded.court.resume()
	require(loaded.court_state.phase == "restored" and loaded.trust == 25, "Granted appeal persists")
	loaded.queue_free()
	game.court.return_to_desk()
	game.court.return_to_desk()
	await create_timer(0.12).timeout
	require(game.phase == "waiting" and game.case_index == 2 and game.room.visitors.size() == 1, "Return preserves remaining queue")
	seat(game, 2)
	wrong(game)
	require(game.trust == 0 and game.court_state.phase == "none", "Exactly zero does not demote")
	game.finish_departure(2, game.CIRCLES[0])
	await create_timer(3.0).timeout
	require(game.phase == "finished", "Zero trust completes shift")
	game.restart()
	game.close_modal()
	game.trust = 0
	seat(game, 2)
	wrong(game)
	game.finish_departure(2, game.CIRCLES[0])
	await create_timer(3.4).timeout
	require(game.court_state.phase == "defense" and game.phase == "tribunal", "Last-case tribunal precedes summary")
	defend(game, true)
	game.court.return_to_desk()
	await create_timer(0.12).timeout
	require(game.phase == "finished", "Recovery after last case shows summary")
	game.restart()
	game.close_modal()
	game.trust = -10
	game.court.prepare(-1)
	require(game.court_state.review.control, "Missing old ruling uses explicit control case")
	game.court_state.phase = "defense"
	game.court.resume()
	defend(game, false)
	require(game.court_state.phase == "condemned" and game.trust == -10, "Bad correction fails appeal")
	loaded = save_and_reload(game)
	loaded.court.resume()
	require(loaded.court_state.phase == "condemned", "Failed verdict cannot be replayed on load")
	loaded.queue_free()
	game.court.start_execution()
	game.court.start_execution()
	loaded = save_and_reload(game)
	loaded.court.resume()
	await create_timer(0.18).timeout
	require(loaded.court_state.phase == "over", "Execution checkpoint completes the sentence")
	loaded.queue_free()
	require(game.court_state.phase == "over", "Sentencing reaches game over")
	require(game.room.exit_label.text == game.CIRCLES[7].to_upper(), "Own eighth circle displayed")
	loaded = save_and_reload(game)
	loaded.court.resume()
	require(loaded.court_state.phase == "over", "Game over persists")
	loaded.queue_free()
	game.restart()
	require(game.trust == 40 and game.court_state.phase == "none" and game.history.is_empty(), "New run resets tribunal")
	game.trust = -10
	game.court.prepare(-1)
	game.court_state.phase = "defense"
	game.court.resume()
	defend(game, true, false)
	require(game.court_state.phase == "condemned", "Refusal of review fails even with correct correction")
	await create_timer(0.3).timeout
	game.queue_free()
	await process_frame
	print("PASS: ", checks, " tribunal checks")
	quit()
