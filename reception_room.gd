extends Node3D

signal item_selected(item: String)

var camera: Camera3D
var visitors: Dictionary = {}
var exit_label: Label3D
var movement: Tween
var cinematic_time = 1.0
var stamp_handle: Node3D
var watched_soul: Node3D
const DESK_POSITION = Vector3(0, 0, 0.1)

func material(color: String, glow: float = 0.0) -> StandardMaterial3D:
	var result = StandardMaterial3D.new()
	result.albedo_color = Color(color)
	result.roughness = 0.92
	if glow > 0:
		result.emission_enabled = true
		result.emission = Color(color)
		result.emission_energy_multiplier = glow
	return result

func mesh(parent: Node3D, shape: Mesh, at: Vector3, surface: Material) -> MeshInstance3D:
	var part = MeshInstance3D.new()
	part.mesh = shape
	part.material_override = surface
	part.position = at
	parent.add_child(part)
	return part

func box(parent: Node3D, at: Vector3, dimensions: Vector3, surface: Material) -> MeshInstance3D:
	var shape = BoxMesh.new()
	shape.size = dimensions
	return mesh(parent, shape, at, surface)

func cylinder(parent: Node3D, at: Vector3, bottom: float, top: float, height: float, surface: Material) -> MeshInstance3D:
	var shape = CylinderMesh.new()
	shape.bottom_radius = bottom
	shape.top_radius = top
	shape.height = height
	shape.radial_segments = 10
	return mesh(parent, shape, at, surface)

func plaque(value: String, at: Vector3, size: int = 40) -> Label3D:
	var text = Label3D.new()
	text.text = value
	text.font_size = size
	text.pixel_size = 0.007
	text.modulate = Color("c2af88")
	text.outline_size = 2
	text.position = at
	add_child(text)
	return text

func lamp(at: Vector3, color: Color, energy: float, radius: float) -> void:
	var light = OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	add_child(light)

func _ready() -> void:
	var stone = material("343d3b")
	var trim = material("202725")
	var iron = material("111716")
	var brass = material("857151")
	var wood = material("302a25")
	var bone = material("baad90")
	var ember = material("dfad69", 1.1)
	var environment = WorldEnvironment.new()
	var settings = Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("111b1c")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("8baba8")
	settings.ambient_light_energy = 0.48
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)
	camera = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 1.65, 4.0)
	camera.look_at(Vector3(0, 1.12, -1.3))
	camera.fov = 64
	camera.current = true
	box(self, Vector3(0, -0.16, -1), Vector3(10, 0.3, 14), trim)
	box(self, Vector3(0, 2.4, -7), Vector3(10, 4.8, 0.4), stone)
	for side in [-1, 1]:
		box(self, Vector3(side * 4.7, 2.4, -1), Vector3(0.35, 4.8, 12), stone)
		for depth in [-6.5, -3.5, -0.5, 2.5]:
			box(self, Vector3(side * 4.42, 2.25, depth), Vector3(0.42, 4.5, 0.5), trim)
			box(self, Vector3(side * 4.2, 3.7, depth), Vector3(0.8, 0.2, 0.8), brass)
	for row in range(12):
		for col in range(9):
			var tile_material = material("3a403b" if (row + col) % 3 == 0 else "2b3230")
			box(self, Vector3(col - 4, 0.005, row - 7), Vector3(0.97, 0.025, 0.97), tile_material)
	# Back-wall masonry gives the room depth without external textures.
	for row in range(6):
		for col in range(8):
			box(self, Vector3(-4.4 + col * 1.25 + (row % 2) * 0.3, row * 0.73 + 0.4, -6.76), Vector3(1.2, 0.68, 0.08), trim)
	# Entrance on the left and a separate sentencing gate on the right.
	for x in [-2.85, 2.85]:
		box(self, Vector3(x, 1.45, -5.6), Vector3(1.7, 2.9, 0.25), iron)
		for offset in [-0.93, 0.93]:
			box(self, Vector3(x + offset, 1.6, -5.4), Vector3(0.2, 3.2, 0.4), stone)
		box(self, Vector3(x, 3.15, -5.4), Vector3(2.05, 0.25, 0.4), brass)
		for bar in range(7):
			box(self, Vector3(x - 0.7 + bar * 0.23, 1.5, -5.39), Vector3(0.045, 2.8, 0.08), brass)
		lamp(Vector3(x, 2.8, -4.8), Color("bcad83"), 1.3, 4)
	plaque("ОЖИДАНИЕ", Vector3(-2.85, 3.5, -5.3), 28)
	exit_label = plaque("РАСПРЕДЕЛЕНИЕ", Vector3(2.85, 3.5, -5.3), 28)
	plaque("НИ ОДНА ДУША НЕ ЗАБЫТА", Vector3(0, 4.05, -6.45), 27)
	# Brass queue railing leaves the front approach completely open.
	for depth in [-4.3, -3.1, -1.9]:
		cylinder(self, Vector3(-1.8, 0.55, depth), 0.055, 0.055, 1.1, brass)
	box(self, Vector3(-1.8, 1.05, -3.1), Vector3(0.065, 0.065, 2.5), brass)
	# Desk, carved front and paired candles.
	box(self, Vector3(0, 0.84, 2.35), Vector3(3.45, 0.18, 1.35), wood)
	box(self, Vector3(0, 0.4, 2.75), Vector3(3.1, 0.8, 0.2), trim)
	for x in [-1.45, 1.45]:
		box(self, Vector3(x, 0.4, 2.35), Vector3(0.18, 0.8, 1.2), wood)
		cylinder(self, Vector3(x, 1.06, 1.95), 0.08, 0.065, 0.3, bone)
		cylinder(self, Vector3(x, 1.25, 1.95), 0.035, 0.002, 0.12, ember)
		lamp(Vector3(x, 1.55, 1.6), Color("ffce8c"), 1.6, 4.5)
	box(self, Vector3(-0.82, 0.965, 2.25), Vector3(0.62, 0.055, 0.65), material("9e9277"))
	for line in range(5):
		box(self, Vector3(-0.82, 0.995, 2.05 + line * 0.075), Vector3(0.41, 0.003, 0.014), wood)
	box(self, Vector3(0.0, 0.98, 2.25), Vector3(0.5, 0.11, 0.62), material("4e3230"))
	box(self, Vector3(0.0, 1.04, 2.25), Vector3(0.35, 0.01, 0.43), brass)
	stamp_handle = cylinder(self, Vector3(0.7, 1.08, 2.24), 0.1, 0.05, 0.28, wood)
	box(self, Vector3(0.7, 0.96, 2.24), Vector3(0.23, 0.06, 0.2), brass)
	cylinder(self, Vector3(1.12, 1.02, 2.3), 0.14, 0.035, 0.17, brass)
	for entry in [["file", Vector3(-0.82, 1.0, 2.25)], ["rules", Vector3(0, 1.03, 2.25)], ["verdict", Vector3(0.7, 1.08, 2.24)], ["bell", Vector3(1.12, 1.05, 2.3)]]:
		var area = Area3D.new()
		area.set_meta("item", entry[0])
		area.position = entry[1]
		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(0.45, 0.35, 0.5)
		collision.shape = shape
		area.add_child(collision)
		add_child(area)
	lamp(Vector3(0, 3.5, -0.8), Color("bec8b6"), 1.5, 7)
	var key_light = SpotLight3D.new()
	add_child(key_light)
	key_light.position = Vector3(-1.2, 3.7, 2.3)
	key_light.look_at(Vector3(0, 0.8, 0))
	key_light.light_color = Color("ffe0ac")
	key_light.light_energy = 1.8
	key_light.spot_range = 8
	key_light.spot_angle = 48
	key_light.shadow_enabled = true
	# This wall becomes visible when the player stands before their former desk.
	box(self, Vector3(0, 2.4, 5.8), Vector3(9.4, 4.8, 0.3), stone)
	for x in [-3.5, -1.8, 1.8, 3.5]:
		box(self, Vector3(x, 2.2, 5.55), Vector3(0.28, 4.4, 0.25), trim)
	var court_sign = plaque("СЛУЖБА НЕ ЕСТЬ ОПРАВДАНИЕ", Vector3(0, 3.2, 5.5), 30)
	court_sign.rotation.y = PI
	lamp(Vector3(0, 2.6, 3.7), Color("cfb78f"), 1.3, 4)

func queue_position(slot: int) -> Vector3:
	return Vector3(-2.8 - slot * 0.15, 0, -1.2 - slot * 1.45)

func create_visitor(index: int) -> Node3D:
	var person = Node3D.new()
	person.name = "Soul%d" % index
	add_child(person)
	var cloth = material("33282a" if index == 4 else ["484637", "383f42", "493535"][index % 3])
	var dark = material("151b1a")
	var face = material("b6b29d")
	cylinder(person, Vector3(0, 0.72, 0), 0.38, 0.24, 1.35, cloth)
	var hood_shape = SphereMesh.new()
	hood_shape.radius = 0.26
	hood_shape.height = 0.59
	hood_shape.radial_segments = 12
	hood_shape.rings = 6
	mesh(person, hood_shape, Vector3(0, 1.57, 0), dark)
	var mask_shape = SphereMesh.new()
	mask_shape.radius = 0.19
	mask_shape.height = 0.44
	mask_shape.radial_segments = 10
	mask_shape.rings = 6
	var mask = mesh(person, mask_shape, Vector3(0, 1.56, 0.16), face)
	mask.scale.z = 0.5
	for side in [-1, 1]:
		var arm = cylinder(person, Vector3(side * 0.3, 0.94, 0.03), 0.08, 0.12, 0.78, cloth)
		arm.rotation.z = side * 0.15
		box(person, Vector3(side * 0.076, 1.61, 0.255), Vector3(0.075, 0.043, 0.015), dark)
	box(person, Vector3(0, 1.43, 0.25), Vector3(0.07, 0.018, 0.014), dark)
	box(person, Vector3(0, 0.98, 0.25), Vector3(0.045, 0.66, 0.035), material("867957"))
	person.scale = [Vector3(1.1, 1.0, 1), Vector3(0.88, 0.96, 0.9), Vector3(1.0, 1.14, 1)][index % 3]
	if index == 4:
		person.scale = Vector3(1.2, 1.0, 1.1)
		box(person, Vector3(0, 1.32, 0.27), Vector3(0.35, 0.06, 0.04), material("94805a"))
	visitors[index] = person
	return person

func restore(index: int, active: bool) -> void:
	if movement and movement.is_valid():
		movement.kill()
	for person in visitors.values():
		remove_child(person)
		person.queue_free()
	visitors.clear()
	for i in range(index, 3):
		var person = create_visitor(i)
		person.position = DESK_POSITION if active and i == index else queue_position(i - index - (1 if active else 0))
		exit_label.text = "РАСПРЕДЕЛЕНИЕ"

func approach(index: int) -> void:
	movement = create_tween()
	movement.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	movement.tween_property(visitors[index], "position", Vector3(-1.25, 0, 0.1), 0.8)
	movement.tween_property(visitors[index], "position", DESK_POSITION, 0.8)
	for i in range(index + 1, 3):
		var shift = create_tween()
		shift.tween_property(visitors[i], "position", queue_position(i - index - 1), 1.2)
	await movement.finished

func depart(index: int, circle: String) -> void:
	exit_label.text = circle.to_upper()
	var person: Node3D = visitors[index]
	movement = create_tween()
	movement.tween_property(person, "rotation:y", -PI / 2, 0.2)
	if index >= 3:
		movement.set_speed_scale(1.0 / cinematic_time)
		watched_soul = person
	movement.tween_property(person, "position", Vector3(2.85, 0, 0.1), 0.9)
	movement.tween_property(person, "rotation:y", PI, 0.2)
	movement.tween_property(person, "position", Vector3(2.85, 0, -5.1), 1.3)
	await movement.finished
	if watched_soul == person:
		camera.look_at(person.position + Vector3(0, 1.2, 0))
		watched_soul = null
	visitors.erase(index)
	person.queue_free()

func _process(delta: float) -> void:
	if is_instance_valid(watched_soul):
		var direction = watched_soul.position + Vector3(0, 1.2, 0) - camera.position
		var target_rotation = Basis.looking_at(direction).get_rotation_quaternion()
		camera.quaternion = camera.quaternion.slerp(target_rotation, minf(1.0, delta * 5.0 / cinematic_time))

func court_view(index: int, in_queue: bool) -> void:
	restore(index, false)
	for soul in visitors.values():
		soul.visible = false
	var judge = create_visitor(4)
	judge.position = Vector3(0, -0.12, 3.65)
	judge.rotation.y = PI
	if in_queue:
		var preceding = create_visitor(3)
		preceding.position = DESK_POSITION
		camera.position = Vector3(-2.8, 1.65, -1.2)
	else:
		camera.position = Vector3(0, 1.65, 0.1)
	camera.look_at(Vector3(0, 1.4, 1.5 if in_queue else 3.65))

func walk_to_judge() -> void:
	var destination = Vector3(0, 1.65, 0.1)
	var final_transform = Transform3D(Basis.looking_at(Vector3(0, 1.4, 3.65) - destination), destination)
	var travel = create_tween()
	travel.tween_property(camera, "transform", final_transform, 2.5 * cinematic_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await travel.finished

func desk_view(index: int) -> void:
	restore(index, false)
	camera.position = Vector3(0, 1.65, 4)
	camera.look_at(Vector3(0, 1.12, -1.3))

func walk_to_hell(circle: String) -> void:
	exit_label.text = circle.to_upper()
	var travel = create_tween()
	var first = Vector3(2.85, 1.65, 0.1)
	var last = Vector3(2.85, 1.65, -5.1)
	travel.tween_property(camera, "transform", Transform3D(Basis.looking_at(Vector3(1, 0, 0)), first), 1.5 * cinematic_time)
	travel.tween_property(camera, "transform", Transform3D(Basis.looking_at(Vector3(0, 0, -1)), last), 2.5 * cinematic_time)
	await travel.finished

func stamp() -> void:
	var motion = create_tween()
	motion.tween_property(stamp_handle, "position:y", 0.95, 0.12 * cinematic_time)
	motion.tween_property(stamp_handle, "position:y", 1.08, 0.18 * cinematic_time)
	var sound = AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	var samples = PackedByteArray()
	samples.resize(4400 * 2)
	for index in range(4400):
		var t = float(index) / 22050.0
		var value = sin(t * TAU * 95) * exp(-t * 34) * 16000
		samples.encode_s16(index * 2, int(value))
	sound.data = samples
	var player = AudioStreamPlayer.new()
	player.stream = sound
	player.volume_db = -10
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func pick(screen_position: Vector2) -> String:
	var start = camera.project_ray_origin(screen_position)
	var query = PhysicsRayQueryParameters3D.create(start, start + camera.project_ray_normal(screen_position) * 12)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result = get_world_3d().direct_space_state.intersect_ray(query)
	return str(result.collider.get_meta("item", "")) if not result.is_empty() else ""
