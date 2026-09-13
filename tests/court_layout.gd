extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func require(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		quit(1)
		assert(value, message)

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.close_modal()
	game.phase = "tribunal"
	game.court.prepare(-1)
	game.court_state.phase = "defense"
	game.court_state.correction_circle = 3
	game.court_state.correction_evidence = 0
	game.court_state.responsibility = 1
	game.room.court_view(0, false)
	for locale in ["en", "ru"]:
		game.change_language(locale)
		for dimensions in [Vector2i(1280,720),Vector2i(1920,1080)]:
			root.size = dimensions
			await process_frame
			for step in range(5):
				game.court_state.step = step
				game.court.show_defense()
				await process_frame
				await process_frame
				var panel: Control = game.overlay.get_child(1)
				require(root.get_visible_rect().encloses(panel.get_global_rect()), "Court panel outside viewport")
				var scroll: ScrollContainer = panel.get_child(0).get_child(1)
				require(scroll.get_child(0).size.x <= scroll.size.x, "Court answer exceeds available width")
			game.court.show_documents()
			await process_frame
			await process_frame
			var scroll: ScrollContainer = game.overlay.get_child(1).get_child(0).get_child(1)
			scroll.scroll_vertical = 100000
			await process_frame
			var back: Control = scroll.get_child(0).get_children().back()
			require(back.global_position.y < scroll.global_position.y + scroll.size.y, "Return from court documents unreachable")
			var face: Vector2 = game.room.camera.unproject_position(Vector3(0,1.45,3.65))
			require(root.get_visible_rect().has_point(face), "Judge not in defendant camera view")
			game.room.court_view(0,true)
			for point in [Vector3(0,1.45,3.65),Vector3(0,1.55,0.1)]:
				require(root.get_visible_rect().has_point(game.room.camera.unproject_position(point)), "Queue view misses judge or preceding soul")
			game.room.court_view(0,false)
	print("PASS: all five court screens, scroll return and judge/queue framing at 720p and 1080p")
	game.queue_free()
	await process_frame
	quit()
