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
	await process_frame
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = dimensions
		await process_frame
		for index in range(3):
			scene.case_index = index
			scene.phase = "receiving"
			scene.checked = true
			scene.questioned = true
			for method in ["show_file", "show_dialogue", "show_verdict"]:
				scene.call(method)
				await process_frame
				await process_frame
				var panel: Control = scene.overlay.get_child(1)
				require(root.get_visible_rect().encloses(panel.get_global_rect()), "Story panel overflow")
				var scroll: ScrollContainer = panel.get_child(0).get_child(1)
				require(scroll.get_child(0).size.x <= scroll.size.x, "Story text horizontal overflow")
				scroll.scroll_vertical = 100000
				await process_frame
				var last: Control = scroll.get_child(0).get_children().back()
				require(last.global_position.y < scroll.global_position.y + scroll.size.y, "Final story element unreachable")
				scene.close_modal()
	print("PASS: all three rewritten cases fit scrollable file, dialogue and verdict panels at both resolutions")
	quit()
