extends Control

const Data = preload("res://case_data.gd")
const Room = preload("res://reception_room.gd")
const Tribunal = preload("res://tribunal.gd")
const CASES = Data.CASES
const CIRCLES = Data.CIRCLES
const SAVE_PATH = "user://shift.json"
const Localization = preload("res://localization.gd")
var active_view = ""
var language_choice: OptionButton
var case_index = 0
var trust = 40
var requests = 2
var questioned = false
var dialogue_step = 0
var checked = false
var active = false
var phase = "waiting"
var history: Array = []
var selected_circle = -1
var selected_fact = -1
var room: Node3D
var hud: Control
var overlay: Control
var hint: Label
var verdict_button: Button
var save_enabled = true
var save_path = SAVE_PATH
var ui_root: Control
var court: Node
var court_state: Dictionary = {"phase":"none"}
var personal_circle = 7
var appointment_seen = false

func _ready() -> void:
	save_enabled = not "--test" in OS.get_cmdline_user_args()
	Localization.initialize(save_enabled)
	if not save_enabled:
		save_path = "user://test_shift.json"
	make_theme()
	var ui_layer = CanvasLayer.new()
	ui_layer.layer = 1
	add_child(ui_layer)
	ui_root = Control.new()
	ui_root.theme = theme
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(ui_root)
	build_language_selector()
	load_game()
	room = Room.new()
	add_child(room)
	court = Tribunal.new()
	court.game = self
	add_child(court)
	room.restore(case_index, active)
	if str(court_state.get("phase", "none")) != "none" or trust < 0:
		phase = "tribunal"
		build_hud()
		court.resume.call_deferred()
		return
	phase = "receiving" if active else "waiting"
	if case_index >= 3:
		phase = "finished"
	build_hud()
	if phase == "finished":
		show_summary()
	elif not appointment_seen:
		show_appointment()

func build_language_selector() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var controls = Control.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(controls)
	language_choice = OptionButton.new()
	language_choice.theme = theme
	language_choice.add_item("English")
	language_choice.add_item("Русский")
	language_choice.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	language_choice.position = Vector2(-190, 53)
	language_choice.size = Vector2(165, 36)
	language_choice.add_theme_font_size_override("font_size", 14)
	controls.add_child(language_choice)
	language_choice.selected = 1 if TranslationServer.get_locale() == "ru" else 0
	language_choice.item_selected.connect(func(index: int): change_language("ru" if index == 1 else "en"))

func can_change_language() -> bool:
	return phase not in ["approaching", "departing"] and not (is_instance_valid(court) and (court.running or str(court_state.get("phase", "none")) in ["pending", "queue", "execution"]))

func _process(_delta: float) -> void:
	if is_instance_valid(language_choice):
		language_choice.disabled = not can_change_language()

func change_language(locale: String) -> void:
	if not can_change_language() or locale not in ["en", "ru"]:
		return
	var view = active_view
	var scroll_position = 0
	if is_instance_valid(overlay):
		var scroll: ScrollContainer = overlay.get_child(1).get_child(0).get_child(1)
		scroll_position = scroll.scroll_vertical
	Localization.select(locale, save_enabled)
	language_choice.selected = 1 if locale == "ru" else 0
	room.refresh_language()
	build_hud()
	if phase == "tribunal":
		court.refresh_language()
	elif not view.is_empty():
		call(view)
	if is_instance_valid(overlay):
		var scroll: ScrollContainer = overlay.get_child(1).get_child(0).get_child(1)
		scroll.set_deferred("scroll_vertical", scroll_position)

func make_theme() -> void:
	var palette = Theme.new()
	palette.default_font_size = 18
	for kind in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style = StyleBoxFlat.new()
			style.bg_color = Color("242925") if state == "normal" else Color("414239")
			if state == "disabled":
				style.bg_color = Color("171d1c")
			style.border_color = Color("75664b")
			style.set_border_width_all(1)
			style.set_content_margin_all(10)
			palette.set_stylebox(state, kind, style)
		palette.set_color("font_color", kind, Color("e1d6bd"))
		palette.set_color("font_disabled_color", kind, Color("787e72"))
	palette.set_color("font_color", "Label", Color("e1d6bd"))
	palette.set_color("default_color", "RichTextLabel", Color("e1d6bd"))
	var popup = StyleBoxFlat.new()
	popup.bg_color = Color("1b2421")
	popup.set_content_margin_all(12)
	palette.set_stylebox("panel", "PopupMenu", popup)
	palette.set_color("font_color", "PopupMenu", Color("e1d6bd"))
	theme = palette

func text_label(value: String, size: int = 18) -> Label:
	var node = Label.new()
	node.text = tr(value)
	node.add_theme_font_size_override("font_size", size)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func button(value: String, callback: Callable, disabled: bool = false) -> Button:
	var node = Button.new()
	node.text = tr(value)
	node.disabled = disabled
	node.pressed.connect(callback)
	return node

func surface() -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.065, 0.09, 0.085, 0.97)
	style.border_color = Color("75664b")
	style.set_border_width_all(1)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func build_hud() -> void:
	if is_instance_valid(hud):
		ui_root.remove_child(hud)
		hud.queue_free()
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(hud)
	var title = text_label("INFERNAL LAW", 30)
	title.position = Vector2(30, 22)
	title.size.x = 350
	hud.add_child(title)
	var subtitle = text_label(tr("UI_SUBTITLE"), 13)
	subtitle.position = Vector2(32, 62)
	subtitle.size.x = 480
	hud.add_child(subtitle)
	var stats = text_label(tr("UI_STATS") % [trust, requests], 16)
	stats.anchor_left = 1
	stats.anchor_right = 1
	stats.offset_left = -455
	stats.offset_right = -25
	stats.offset_top = 29
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(stats)
	var panel = surface()
	panel.anchor_top = 1
	panel.anchor_bottom = 1
	panel.anchor_right = 1
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = -171
	panel.offset_bottom = -20
	hud.add_child(panel)
	var stack = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 9)
	panel.add_child(stack)
	var description = tr("UI_WAITING")
	if phase == "approaching":
		description = tr("UI_APPROACHING")
	elif phase == "departing" or phase == "result":
		description = tr("UI_DEPARTING")
	elif phase == "receiving":
		description = "%s  /  %s" % [tr(CASES[case_index].name), tr(CASES[case_index].role)]
	elif phase == "finished":
		description = tr("UI_FINISHED")
	stack.add_child(text_label(description, 20))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	stack.add_child(row)
	var actions = [button(tr("ACTION_NEXT"), call_next, phase != "waiting"), button(tr("ACTION_FILE"), show_file, phase != "receiving"), button(tr("ACTION_DIALOGUE"), show_dialogue, phase != "receiving"), button(tr("ACTION_RULES"), show_rules), button(tr("ACTION_VERDICT"), show_verdict, phase != "receiving")]
	for entry in actions:
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(entry)
	hint = text_label(tr("UI_HINT"), 14)
	if trust < 25:
		hint.text = tr("UI_LOW_TRUST")
	stack.add_child(hint)
	hud.visible = phase != "tribunal"

func open_modal(title: String, dismissible: bool = true) -> VBoxContainer:
	close_modal()
	overlay = Control.new()
	overlay.set_meta("dismissible", dismissible)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(overlay)
	var shade = ColorRect.new()
	shade.color = Color(0.01, 0.025, 0.02, 0.66)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var panel = surface()
	panel.anchor_left = 0.16
	panel.anchor_right = 0.84
	panel.anchor_top = 0.13
	panel.anchor_bottom = 0.83
	overlay.add_child(panel)
	var frame = VBoxContainer.new()
	frame.add_theme_constant_override("separation", 12)
	panel.add_child(frame)
	frame.add_child(text_label(title, 25))
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	var body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 13)
	scroll.add_child(body)
	if dismissible:
		frame.add_child(button(tr("ACTION_CLOSE"), close_modal))
	return body

func close_modal() -> void:
	active_view = ""
	if is_instance_valid(overlay):
		ui_root.remove_child(overlay)
		overlay.queue_free()
	overlay = null

func show_file() -> void:
	if phase != "receiving":
		return
	var body = open_modal(tr("FILE_TITLE") % [case_index + 1, tr(CASES[case_index].name)])
	active_view = "show_file"
	body.add_child(text_label(CASES[case_index].file))
	if checked:
		body.add_child(text_label(tr("ARCHIVE_HEADING") + tr(CASES[case_index].archive)))
	body.add_child(button(tr("ACTION_ARCHIVE"), check_archive, checked or requests <= 0))

func show_dialogue() -> void:
	if phase != "receiving":
		return
	var body = open_modal(tr("DIALOGUE_TITLE") + tr(CASES[case_index].name))
	active_view = "show_dialogue"
	var panel: Control = overlay.get_child(1)
	panel.anchor_left = 0.25
	panel.anchor_right = 0.92
	panel.anchor_top = 0.56
	panel.anchor_bottom = 0.97
	var shade: ColorRect = overlay.get_child(0)
	shade.color.a = 0.12
	var steps: Array = CASES[case_index].dialogue
	if dialogue_step == 0:
		body.add_child(text_label(tr(CASES[case_index].intro)))
	else:
		var reply: Dictionary = steps[dialogue_step - 1]
		body.add_child(text_label(tr("JUDGE_PREFIX") + tr(reply.question), 16))
		body.add_child(text_label(tr(CASES[case_index].name) + ": " + tr(reply.answer)))
	if dialogue_step < steps.size():
		var expected_step = dialogue_step
		body.add_child(button(steps[dialogue_step].question, func(): ask_question(expected_step)))
	else:
		body.add_child(text_label(tr("DIALOGUE_DONE"), 16))
	if dialogue_step > 0:
		body.add_child(button(tr("ACTION_HISTORY"), show_dialogue_history))

func show_dialogue_history() -> void:
	if phase != "receiving":
		return
	var body = open_modal(tr("HISTORY_TITLE") + tr(CASES[case_index].name))
	active_view = "show_dialogue_history"
	body.add_child(text_label(tr(CASES[case_index].name) + ": " + tr(CASES[case_index].intro)))
	for index in range(dialogue_step):
		var reply: Dictionary = CASES[case_index].dialogue[index]
		body.add_child(text_label(tr("JUDGE_PREFIX") + tr(reply.question) + "\n" + tr(CASES[case_index].name) + ": " + tr(reply.answer)))
	body.add_child(button(tr("ACTION_CONTINUE"), show_dialogue))

func ask_question(expected_step: int = -1) -> void:
	if phase != "receiving" or dialogue_step >= CASES[case_index].dialogue.size():
		return
	if expected_step >= 0 and expected_step != dialogue_step:
		return
	dialogue_step += 1
	questioned = true
	save_game()
	show_dialogue()

func check_archive() -> void:
	if phase != "receiving" or checked or requests <= 0:
		return
	checked = true
	requests -= 1
	save_game()
	build_hud()
	show_file()

func show_rules() -> void:
	if phase == "tribunal":
		return
	var body = open_modal(tr("RULEBOOK_TITLE"))
	active_view = "show_rules"
	body.add_child(text_label(tr("TRUST_RULES")))
	for index in range(9):
		body.add_child(text_label(tr(CIRCLES[index]) + "\n" + tr(Data.RULES[index])))
	body.add_child(text_label(tr("RULE_PRIORITY")))

func show_verdict() -> void:
	if phase != "receiving":
		return
	var body = open_modal(tr("VERDICT_TITLE") + tr(CASES[case_index].name))
	active_view = "show_verdict"
	body.add_child(text_label(tr("VERDICT_HELP")))
	var circle_choice = OptionButton.new()
	circle_choice.add_item(tr("SELECT_CIRCLE"))
	for circle in CIRCLES:
		circle_choice.add_item(tr(circle))
	circle_choice.selected = selected_circle + 1
	circle_choice.item_selected.connect(func(index: int): selected_circle = index - 1; update_verdict())
	body.add_child(circle_choice)
	var fact_choice = OptionButton.new()
	fact_choice.add_item(tr("SELECT_EVIDENCE"))
	for fact in CASES[case_index].facts:
		fact_choice.add_item(tr(fact))
	fact_choice.selected = selected_fact + 1
	fact_choice.item_selected.connect(func(index: int): selected_fact = index - 1; update_verdict())
	body.add_child(fact_choice)
	verdict_button = button(tr("ACTION_PREPARE"), confirm_verdict)
	body.add_child(verdict_button)
	update_verdict()

func update_verdict() -> void:
	if is_instance_valid(verdict_button):
		verdict_button.disabled = selected_circle < 0 or selected_fact < 0

func confirm_verdict() -> void:
	if phase != "receiving" or selected_circle < 0 or selected_fact < 0:
		return
	var body = open_modal(tr("CONFIRM_TITLE"))
	active_view = "confirm_verdict"
	body.add_child(text_label(tr("CONFIRM_BODY") % [tr(CASES[case_index].name), tr(CIRCLES[selected_circle]), tr(CASES[case_index].facts[selected_fact])], 22))
	body.add_child(button(tr("ACTION_STAMP"), deliver_verdict))
	body.add_child(button(tr("ACTION_CHANGE"), show_verdict))

func call_next() -> void:
	if phase != "waiting" or case_index >= 3:
		return
	close_modal()
	phase = "approaching"
	active = true
	save_game()
	build_hud()
	await room.approach(case_index)
	phase = "receiving"
	build_hud()

func deliver_verdict() -> void:
	if phase != "receiving" or selected_circle < 0 or selected_fact < 0:
		return
	phase = "result"
	var data: Dictionary = CASES[case_index]
	var correct: bool = selected_circle == data.circle and selected_fact == data.evidence
	var sentenced_circle: String = CIRCLES[selected_circle]
	var trust_before = trust
	if not correct:
		trust -= 25
	history.append({"name":data.name, "circle":sentenced_circle, "correct":correct,
		"case_id":data.id, "decision_circle":selected_circle, "decision_evidence":selected_fact,
		"trust_before":trust_before, "trust_after":trust, "reviewed":false,
		"review":{"name":data.name, "file":data.file, "facts":data.facts.duplicate(),
		"expected_circle":data.circle, "expected_evidence":data.evidence,
		"explanation":data.explanation, "actual_circle":sentenced_circle,
		"actual_evidence":data.facts[selected_fact]}})
	if trust < 0:
		court.prepare(history.size() - 1)
	case_index += 1
	active = false
	questioned = false
	dialogue_step = 0
	checked = false
	selected_circle = -1
	selected_fact = -1
	save_game()
	build_hud()
	show_case_result()

func show_case_result() -> void:
	var sentenced_index = case_index - 1
	var data: Dictionary = CASES[sentenced_index]
	var record: Dictionary = history.back()
	var correct: bool = record.correct
	var sentenced_circle: String = record.circle
	var body = open_modal(tr("RESULT_TITLE"), false)
	active_view = "show_case_result"
	body.add_child(text_label(tr("RESULT_CORRECT") if correct else tr("RESULT_WRONG"), 23))
	body.add_child(text_label(data.explanation))
	body.add_child(button(tr("ACTION_DEPART"), func(): finish_departure(sentenced_index, sentenced_circle)))

func finish_departure(index: int, circle: String) -> void:
	if phase != "result":
		return
	phase = "departing"
	close_modal()
	build_hud()
	await room.depart(index, circle)
	if trust < 0:
		phase = "tribunal"
		build_hud()
		court.resume()
		return
	phase = "finished" if case_index >= 3 else "waiting"
	build_hud()
	if phase == "finished":
		show_summary()

func show_summary() -> void:
	var body = open_modal(tr("SUMMARY_TITLE"), false)
	active_view = "show_summary"
	body.add_child(text_label(tr("SUMMARY_BODY"), 23))
	for entry in history:
		body.add_child(text_label("%s → %s · %s" % [tr(entry.name), tr(entry.circle), tr("STATUS_CORRECT") if entry.correct else tr("STATUS_WRONG")]))
	body.add_child(button(tr("ACTION_NEW_SHIFT"), restart))
	body.add_child(button(tr("ACTION_QUIT"), func(): get_tree().quit()))

func restart() -> void:
	close_modal()
	case_index = 0
	trust = 40
	requests = 2
	active = false
	questioned = false
	dialogue_step = 0
	checked = false
	selected_circle = -1
	selected_fact = -1
	history.clear()
	court_state = {"phase":"none"}
	appointment_seen = false
	phase = "waiting"
	room.desk_view(0)
	save_game()
	build_hud()
	show_appointment()

func show_appointment() -> void:
	var body = open_modal(tr("APPOINTMENT_TITLE"), false)
	active_view = "show_appointment"
	body.add_child(text_label(tr("APPOINTMENT_BODY"), 22))
	body.add_child(text_label(tr("APPOINTMENT_RULES")))
	body.add_child(button(tr("ACTION_BEGIN"), func(): appointment_seen = true; save_game(); close_modal()))

func save_game() -> void:
	if not save_enabled:
		return
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"schema":5, "court":court_state, "personal_circle":personal_circle, "appointment_seen":appointment_seen, "dialogue_step":dialogue_step, "active":active, "case_index":case_index, "trust":trust, "requests":requests, "history":history, "questioned":questioned, "checked":checked}))
	else:
		push_warning(tr("SAVE_ERROR") + str(FileAccess.get_open_error()))

func load_game() -> void:
	if not save_enabled or not FileAccess.file_exists(save_path):
		return
	var parsed = Localization.migrate(JSON.parse_string(FileAccess.get_file_as_string(save_path)))
	if parsed is Dictionary:
		case_index = clampi(int(parsed.get("case_index", 0)), 0, 3)
		trust = mini(int(parsed.get("trust", 100)), 100)
		court_state = parsed.get("court", {"phase":"none"})
		personal_circle = clampi(int(parsed.get("personal_circle", 7)), 0, 8)
		appointment_seen = bool(parsed.get("appointment_seen", true))
		requests = clampi(int(parsed.get("requests", 2)), 0, 2)
		history = parsed.get("history", [])
		questioned = bool(parsed.get("questioned", false))
		var step_count: int = CASES[case_index].dialogue.size() if case_index < CASES.size() else 0
		dialogue_step = clampi(int(parsed.get("dialogue_step", step_count if questioned else 0)), 0, step_count)
		questioned = dialogue_step > 0
		checked = bool(parsed.get("checked", false))
		active = bool(parsed.get("active", questioned or checked)) and case_index < 3

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and is_instance_valid(overlay):
		if overlay.get_meta("dismissible", true):
			close_modal()
		get_viewport().set_input_as_handled()
	if is_instance_valid(overlay) or phase == "tribunal":
		return
	if event is InputEventMouseMotion and is_instance_valid(hint):
		var item: String = room.pick(event.position)
		hint.text = {"file":tr("HINT_FILE"), "rules":tr("RULEBOOK_TITLE"), "verdict":tr("HINT_STAMP"), "bell":tr("HINT_BELL")}.get(item, tr("UI_HINT"))
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		match room.pick(event.position):
			"file": show_file()
			"rules": show_rules()
			"verdict": show_verdict()
			"bell": call_next()
