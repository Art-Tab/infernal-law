extends Control

const Data = preload("res://case_data.gd")
const Room = preload("res://reception_room.gd")
const CASES = Data.CASES
const CIRCLES = Data.CIRCLES
const SAVE_PATH = "user://shift.json"
var case_index = 0
var trust = 100
var requests = 2
var questioned = false
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

func _ready() -> void:
	save_enabled = not "--test" in OS.get_cmdline_user_args()
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
	load_game()
	room = Room.new()
	add_child(room)
	room.restore(case_index, active)
	phase = "receiving" if active else "waiting"
	if case_index >= 3:
		phase = "finished"
	build_hud()
	if phase == "finished":
		show_summary()

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
	node.text = value
	node.add_theme_font_size_override("font_size", size)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func button(value: String, callback: Callable, disabled: bool = false) -> Button:
	var node = Button.new()
	node.text = value
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
	var subtitle = text_label("КАНЦЕЛЯРИЯ ПОСЛЕДНЕГО СУДА   /   0.0.2", 13)
	subtitle.position = Vector2(32, 62)
	subtitle.size.x = 480
	hud.add_child(subtitle)
	var stats = text_label("СМЕНА 01   ·   ДОВЕРИЕ %d   ·   АРХИВ %d/2" % [trust, requests], 16)
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
	var description = "Место приёма свободно. Позвоните, чтобы вызвать следующего."
	if phase == "approaching":
		description = "Посетитель подходит. Дождитесь, пока он остановится перед столом."
	elif phase == "departing" or phase == "result":
		description = "Приговор зарегистрирован. Место приёма ещё занято."
	elif phase == "receiving":
		description = "%s  /  %s" % [CASES[case_index].name, CASES[case_index].role]
	elif phase == "finished":
		description = "Очередь закончилась. Смена закрыта."
	stack.add_child(text_label(description, 20))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	stack.add_child(row)
	var actions = [button("Следующий", call_next, phase != "waiting"), button("Досье", show_file, phase != "receiving"), button("Допрос", show_dialogue, phase != "receiving"), button("Справочник", show_rules), button("Вынести приговор", show_verdict, phase != "receiving")]
	for entry in actions:
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(entry)
	hint = text_label("Судите по фактам. Ожидающие никуда не торопятся.", 14)
	stack.add_child(hint)

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
		frame.add_child(button("Вернуться к столу · Esc", close_modal))
	return body

func close_modal() -> void:
	if is_instance_valid(overlay):
		ui_root.remove_child(overlay)
		overlay.queue_free()
	overlay = null

func show_file() -> void:
	if phase != "receiving":
		return
	var body = open_modal("ДОСЬЕ № 00%d · %s" % [case_index + 1, CASES[case_index].name])
	body.add_child(text_label(CASES[case_index].file))
	if checked:
		body.add_child(text_label("АРХИВ ПАМЯТИ\n" + CASES[case_index].archive))
	body.add_child(button("Запросить память · 1 запрос", check_archive, checked or requests <= 0))

func show_dialogue() -> void:
	if phase != "receiving":
		return
	var body = open_modal("ПОКАЗАНИЯ · " + CASES[case_index].name)
	var panel: Control = overlay.get_child(1)
	panel.anchor_left = 0.25
	panel.anchor_right = 0.92
	panel.anchor_top = 0.56
	panel.anchor_bottom = 0.97
	var shade: ColorRect = overlay.get_child(0)
	shade.color.a = 0.12
	body.add_child(text_label(CASES[case_index].intro))
	if questioned:
		body.add_child(text_label("Судья: " + CASES[case_index].question + "\n\n" + CASES[case_index].answer))
	else:
		body.add_child(button(CASES[case_index].question, ask_question))

func ask_question() -> void:
	if phase != "receiving":
		return
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
	var body = open_modal("КОДЕКС ДЕВЯТИ КРУГОВ")
	for index in range(9):
		body.add_child(text_label(CIRCLES[index] + "\n" + Data.RULES[index]))
	body.add_child(text_label("Приоритет: особое доверие → основной способ вреда → мотив.\nСудите по доказанным фактам. Архив необязателен. Лечение близких не отменяет умысла."))

func show_verdict() -> void:
	if phase != "receiving":
		return
	var body = open_modal("ПОСТАНОВЛЕНИЕ · " + CASES[case_index].name)
	body.add_child(text_label("Выберите круг и подтверждённое основание. Печать необратима."))
	var circle_choice = OptionButton.new()
	circle_choice.add_item("Выберите круг…")
	for circle in CIRCLES:
		circle_choice.add_item(circle)
	circle_choice.selected = selected_circle + 1
	circle_choice.item_selected.connect(func(index: int): selected_circle = index - 1; update_verdict())
	body.add_child(circle_choice)
	var fact_choice = OptionButton.new()
	fact_choice.add_item("Основание приговора…")
	for fact in CASES[case_index].facts:
		fact_choice.add_item(fact)
	fact_choice.selected = selected_fact + 1
	fact_choice.item_selected.connect(func(index: int): selected_fact = index - 1; update_verdict())
	body.add_child(fact_choice)
	verdict_button = button("ПОДГОТОВИТЬ ПЕЧАТЬ", confirm_verdict)
	body.add_child(verdict_button)
	update_verdict()

func update_verdict() -> void:
	if is_instance_valid(verdict_button):
		verdict_button.disabled = selected_circle < 0 or selected_fact < 0

func confirm_verdict() -> void:
	if phase != "receiving" or selected_circle < 0 or selected_fact < 0:
		return
	var body = open_modal("ПОСЛЕДНЕЕ ПОДТВЕРЖДЕНИЕ")
	body.add_child(text_label("%s → %s\n\nОснование: %s" % [CASES[case_index].name, CIRCLES[selected_circle], CASES[case_index].facts[selected_fact]], 22))
	body.add_child(button("ПОСТАВИТЬ ПЕЧАТЬ", deliver_verdict))
	body.add_child(button("Изменить решение", show_verdict))

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
	show_dialogue()

func deliver_verdict() -> void:
	if phase != "receiving" or selected_circle < 0 or selected_fact < 0:
		return
	phase = "result"
	var data: Dictionary = CASES[case_index]
	var correct: bool = selected_circle == data.circle and selected_fact == data.evidence
	var sentenced_index = case_index
	var sentenced_circle: String = CIRCLES[selected_circle]
	if not correct:
		trust = maxi(0, trust - 20)
	history.append({"name":data.name, "circle":sentenced_circle, "correct":correct})
	case_index += 1
	active = false
	questioned = false
	checked = false
	selected_circle = -1
	selected_fact = -1
	save_game()
	build_hud()
	var body = open_modal("ПРИГОВОР ЗАРЕГИСТРИРОВАН", false)
	body.add_child(text_label("Приговор обоснован." if correct else "Ошибка круга или основания. Доверие −20.", 23))
	body.add_child(text_label(data.explanation))
	body.add_child(button("Отправить осуждённого", func(): finish_departure(sentenced_index, sentenced_circle)))

func finish_departure(index: int, circle: String) -> void:
	if phase != "result":
		return
	phase = "departing"
	close_modal()
	build_hud()
	await room.depart(index, circle)
	phase = "finished" if case_index >= 3 else "waiting"
	build_hud()
	if phase == "finished":
		show_summary()

func show_summary() -> void:
	var body = open_modal("СМЕНА ЗАКРЫТА", false)
	body.add_child(text_label("Назначение утверждено. Завтра очередь станет длиннее." if trust >= 80 else "Назначена повторная аттестация. Перечитайте кодекс.", 23))
	for entry in history:
		body.add_child(text_label("%s → %s · %s" % [entry.name, entry.circle, "обосновано" if entry.correct else "нарушение"]))
	body.add_child(button("Начать новую смену", restart))
	body.add_child(button("Выйти из игры", func(): get_tree().quit()))

func restart() -> void:
	close_modal()
	case_index = 0
	trust = 100
	requests = 2
	active = false
	questioned = false
	checked = false
	selected_circle = -1
	selected_fact = -1
	history.clear()
	phase = "waiting"
	room.restore(0, false)
	save_game()
	build_hud()

func save_game() -> void:
	if not save_enabled:
		return
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"schema":2, "active":active, "case_index":case_index, "trust":trust, "requests":requests, "history":history, "questioned":questioned, "checked":checked}))
	else:
		push_warning("Не удалось записать сохранение: " + str(FileAccess.get_open_error()))

func load_game() -> void:
	if not save_enabled or not FileAccess.file_exists(save_path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if parsed is Dictionary:
		case_index = clampi(int(parsed.get("case_index", 0)), 0, 3)
		trust = clampi(int(parsed.get("trust", 100)), 0, 100)
		requests = clampi(int(parsed.get("requests", 2)), 0, 2)
		history = parsed.get("history", [])
		questioned = bool(parsed.get("questioned", false))
		checked = bool(parsed.get("checked", false))
		active = bool(parsed.get("active", questioned or checked)) and case_index < 3

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and is_instance_valid(overlay):
		if overlay.get_meta("dismissible", true):
			close_modal()
		get_viewport().set_input_as_handled()
	if is_instance_valid(overlay):
		return
	if event is InputEventMouseMotion and is_instance_valid(hint):
		var item: String = room.pick(event.position)
		hint.text = {"file":"Досье · нажмите, чтобы прочитать", "rules":"Кодекс девяти кругов", "verdict":"Печать приговора", "bell":"Звонок · следующий посетитель"}.get(item, "Судите по фактам. Ожидающие никуда не торопятся.")
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		match room.pick(event.position):
			"file": show_file()
			"rules": show_rules()
			"verdict": show_verdict()
			"bell": call_next()
