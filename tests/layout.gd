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
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = dimensions
		await process_frame
		await process_frame
		var frame = root.get_visible_rect()
		for entry in scene.hud.find_children("*", "Button", true, false):
			require(frame.encloses(entry.get_global_rect()), "HUD button outside window: " + entry.text)
		scene.active = true
		scene.phase = "receiving"
		for method in ["show_file", "show_rules", "show_verdict", "show_dialogue"]:
			scene.call(method)
			await process_frame
			await process_frame
			var panel: Control = scene.overlay.get_child(1)
			require(frame.encloses(panel.get_global_rect()), "Modal outside viewport: " + method)
			var close_button: Control = panel.get_child(0).get_children().back()
			require(frame.encloses(close_button.get_global_rect()), "Close button outside viewport")
		scene.close_modal()
		await physics_frame
		for item in [["file", Vector3(-0.82, 1.0, 2.25)], ["rules", Vector3(0, 1.03, 2.25)], ["verdict", Vector3(0.7, 1.08, 2.24)], ["bell", Vector3(1.12, 1.05, 2.3)]]:
			var point: Vector2 = scene.room.camera.unproject_position(item[1])
			print("PICK ", dimensions, " ", item[0], " ", point)
			require(frame.has_point(point) and point.y < frame.size.y - 171, "Desk object hidden behind HUD: " + item[0])
			require(scene.room.pick(point) == item[0], "Desk object ray selection: " + item[0])
		for index in range(3):
			var face: Vector2 = scene.room.camera.unproject_position(scene.room.queue_position(index) + Vector3(0, 1.6, 0))
			require(frame.has_point(face) and face.y < frame.size.y - 171, "Queue face outside scene")
	print("PASS: viewport bounds, queue framing and four desk ray selections at 720p/1080p")
	quit()
