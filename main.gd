extends Control

const SAVE_PATH = "user://shift.json"
const CIRCLES = ["I · Лимб", "II · Похоть", "III · Чревоугодие", "IV · Алчность", "V · Гнев", "VI · Ересь", "VII · Насилие", "VIII · Обман", "IX · Предательство"]
const RULES = ["Недостаточно доказательств для другого круга.", "Вред ради обладания человеком или удовлетворения желания.", "Избыточное потребление, лишающее других необходимого.", "Сознательный вред ради прибыли и накопления.", "Вред, вызванный местью или ненавистью.", "Насильственное навязывание догмы вопреки известному вреду.", "Намеренное тяжёлое насилие. Необходимая защита — исключение.", "Обман как основной способ эксплуатации других.", "Тяжёлый вред через сознательное нарушение особого доверия."]
const CASES = [
 {"name":"Матвей", "role":"Управляющий зернохранилищем", "file":"Во время голода поднял цену на зерно в четыре раза.\n\nЖурнал склада: запасов хватало для выдачи пайков.\n\nБанковская запись: выручка поступила на его личный счёт.", "intro":"Я берег зерно до зимы. Если бы раздал всё сразу, погибло бы ещё больше людей.", "question":"Почему выручка оказалась на личном счёте?", "answer":"Хорошо. Я хотел заработать. Но часть денег ушла на лекарство для дочери.", "archive":"Память подтверждает: Матвей знал, что запасов достаточно. Особой клятвы жителям он не давал.", "facts":["Личная прибыль при достаточных запасах", "Он лечил дочь", "Он умер во время голода"], "circle":3, "evidence":0, "explanation":"IV круг: доказаны прибыль как мотив и сознательное лишение жителей необходимого. Лечение дочери не отменяет этих фактов."},
 {"name":"Агата", "role":"Продавец чудес", "file":"Продавала больным обычную воду под видом лекарства.\n\nПисьмо помощнику: «Никакого действия нет. Продолжай писать отзывы от имени врачей».\n\nПрямое физическое насилие не установлено.", "intro":"Я давала людям надежду. Разве надежда ничего не стоит?", "question":"Кто написал отзывы врачей?", "answer":"Мой помощник. Я диктовала. Настоящие врачи отказались нас поддержать.", "archive":"Агата прочитала заключение о бесполезности воды до начала продаж и уничтожила его.", "facts":["Дорогая цена бутылки", "Заведомо ложное лечение и поддельные отзывы", "Покупатели хотели верить"], "circle":7, "evidence":1, "explanation":"VIII круг: ложные медицинские обещания были самим способом эксплуатации. Прибыль сопутствует обману, но не заменяет ведущую квалификацию."},
 {"name":"Северин", "role":"Хранитель убежища", "file":"Принял семьи под личную защиту и обещал сохранить адрес в тайне.\n\nПодписанная расписка: передал адрес преследователям за вознаграждение.\n\nПосле нападения убежище уничтожено.", "intro":"Они всё равно нашли бы убежище. Я просто выиграл немного времени для себя.", "question":"Вы знали, что произойдёт после передачи адреса?", "answer":"Да. Они сказали прямо. А я всё равно поставил подпись.", "archive":"В момент сделки Северину предлагали безопасный уход без вознаграждения. Принуждения не было.", "facts":["Полученное вознаграждение", "Он боялся преследователей", "Сознательная выдача доверившихся ему людей"], "circle":8, "evidence":2, "explanation":"IX круг: доказано сознательное нарушение личного обязательства защиты с тяжёлыми последствиями для доверившихся людей."}
]

var case_index = 0
var trust = 100
var requests = 2
var questioned = false
var checked = false
var selected_circle = -1
var selected_fact = -1
var history: Array = []
var root_box: VBoxContainer
var status: Label
var speech: RichTextLabel
var verdict_button: Button
var result_dialog: AcceptDialog
var confirmation: ConfirmationDialog

func _ready() -> void:
	var theme_data = Theme.new()
	theme_data.default_font_size = 18
	for kind in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style = StyleBoxFlat.new()
			style.bg_color = Color("30262b") if state == "normal" else Color("574039")
			style.border_color = Color("927053")
			style.set_border_width_all(1)
			style.set_content_margin_all(12)
			theme_data.set_stylebox(state, kind, style)
	theme_data.set_color("font_color", "Label", Color("eadcc3"))
	theme_data.set_color("default_color", "RichTextLabel", Color("eadcc3"))
	theme = theme_data
	load_game()
	build_screen()

func label_text(value: String, size: int = 18) -> Label:
	var node = Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size", size)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node

func action(value: String, callback: Callable) -> Button:
	var node = Button.new()
	node.text = value
	node.pressed.connect(callback)
	return node

func paragraph(value: String) -> RichTextLabel:
	var node = RichTextLabel.new()
	node.text = value
	node.fit_content = true
	node.custom_minimum_size.y = 100
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return node

func build_screen() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	root_box = VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 16)
	margin.add_child(root_box)
	root_box.add_child(label_text("КАНЦЕЛЯРИЯ ПРЕИСПОДНЕЙ", 32))
	status = label_text("Смена 01   /   Дело %d из 3   /   Доверие: %d   /   Архив: %d" % [mini(case_index + 1, 3), trust, requests])
	root_box.add_child(status)
	if case_index >= CASES.size():
		show_summary()
		return
	var data: Dictionary = CASES[case_index]
	root_box.add_child(label_text("Изучите дело → задайте вопрос → выберите круг и доказательство → поставьте печать.", 16))
	var columns = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 24)
	root_box.add_child(columns)
	var left = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	left.add_child(label_text("ДОСЬЕ № 00%d" % (case_index + 1), 22))
	left.add_child(label_text(data.name + " · " + data.role, 24))
	left.add_child(paragraph(data.file))
	left.add_child(action("Открыть справочник девяти кругов", show_rules))
	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	right.add_child(label_text("ПОКАЗАНИЯ", 22))
	speech = paragraph(data.intro)
	if questioned:
		speech.text += "\n\nСудья: " + data.question + "\n\n" + data.answer
	if checked:
		speech.text += "\n\nАРХИВ: " + data.archive
	right.add_child(speech)
	var question_button = action("Допросить: уточнить обстоятельства", ask_question)
	question_button.disabled = questioned
	right.add_child(question_button)
	var archive_button = action("Запросить память · 1 запрос", check_archive)
	archive_button.disabled = checked or requests <= 0
	right.add_child(archive_button)
	root_box.add_child(label_text("ПОСТАНОВЛЕНИЕ", 22))
	var choices = HBoxContainer.new()
	root_box.add_child(choices)
	var circle_choice = OptionButton.new()
	circle_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	circle_choice.add_item("Выберите круг…")
	for circle in CIRCLES:
		circle_choice.add_item(circle)
	circle_choice.selected = selected_circle + 1
	circle_choice.item_selected.connect(func(index: int): selected_circle = index - 1; update_verdict())
	choices.add_child(circle_choice)
	var fact_choice = OptionButton.new()
	fact_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fact_choice.add_item("Основание приговора…")
	for fact in data.facts:
		fact_choice.add_item(fact)
	fact_choice.selected = selected_fact + 1
	fact_choice.item_selected.connect(func(index: int): selected_fact = index - 1; update_verdict())
	choices.add_child(fact_choice)
	verdict_button = action("ПОСТАВИТЬ ПЕЧАТЬ", confirm_verdict)
	root_box.add_child(verdict_button)
	update_verdict()
	root_box.add_child(label_text("Авторская трактовка кругов ада. Прототип · сохранение после каждого приговора.", 14))

func update_verdict() -> void:
	verdict_button.disabled = selected_circle < 0 or selected_fact < 0

func ask_question() -> void:
	questioned = true
	build_screen()

func check_archive() -> void:
	if checked or requests <= 0:
		return
	checked = true
	requests -= 1
	save_game()
	build_screen()

func show_rules() -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Справочник судьи"
	dialog.dialog_text = ""
	for index in range(CIRCLES.size()):
		dialog.dialog_text += CIRCLES[index] + " — " + RULES[index] + "\n\n"
	dialog.dialog_text += "Приоритет: особое доверие → основной способ вреда → мотив.\nСудите по доказанным фактам. Архив необязателен.\nМотив лечения близких не отменяет умысла."
	add_child(dialog)
	dialog.popup_centered(Vector2i(1050, 650))
	dialog.confirmed.connect(dialog.queue_free)

func confirm_verdict() -> void:
	confirmation = ConfirmationDialog.new()
	confirmation.title = "Подтверждение приговора"
	confirmation.dialog_text = "Отправить %s: %s?\nПосле печати изменить решение нельзя." % [CASES[case_index].name, CIRCLES[selected_circle]]
	confirmation.ok_button_text = "Поставить печать"
	confirmation.cancel_button_text = "Вернуться к делу"
	add_child(confirmation)
	confirmation.confirmed.connect(deliver_verdict)
	confirmation.popup_centered()

func deliver_verdict() -> void:
	var data: Dictionary = CASES[case_index]
	var correct: bool = selected_circle == data.circle and selected_fact == data.evidence
	if not correct:
		trust = maxi(0, trust - 20)
	history.append({"name": data.name, "circle": CIRCLES[selected_circle], "correct": correct})
	case_index += 1
	questioned = false
	checked = false
	selected_circle = -1
	selected_fact = -1
	save_game()
	result_dialog = AcceptDialog.new()
	result_dialog.title = "Приговор зарегистрирован"
	result_dialog.dialog_text = ("Проверка: приговор обоснован.\n\n" if correct else "Проверка: ошибка квалификации или основания. Доверие −20.\n\n") + data.explanation
	result_dialog.ok_button_text = "Продолжить смену"
	add_child(result_dialog)
	result_dialog.confirmed.connect(build_screen)
	result_dialog.canceled.connect(build_screen)
	result_dialog.popup_centered(Vector2i(850, 260))

func show_summary() -> void:
	root_box.add_child(label_text("СМЕНА ЗАКРЫТА", 38))
	var ending = "Начальство утвердило ваше назначение. Завтра очередь станет длиннее." if trust >= 80 else "Назначена повторная аттестация. Начальство требует перечитать справочник."
	root_box.add_child(paragraph(ending))
	for item in history:
		root_box.add_child(label_text("%s → %s · %s" % [item.name, item.circle, "обосновано" if item.correct else "нарушение"]))
	root_box.add_child(action("Начать новую смену", restart))
	root_box.add_child(action("Выйти", func(): get_tree().quit()))

func restart() -> void:
	case_index = 0
	trust = 100
	requests = 2
	questioned = false
	checked = false
	history.clear()
	save_game()
	build_screen()

func save_game() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"case_index":case_index, "trust":trust, "requests":requests, "history":history, "questioned":questioned, "checked":checked}))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if parsed is Dictionary:
		case_index = clampi(int(parsed.get("case_index", 0)), 0, CASES.size())
		trust = int(parsed.get("trust", 100))
		requests = int(parsed.get("requests", 2))
		history = parsed.get("history", [])
		questioned = parsed.get("questioned", false)
		checked = parsed.get("checked", false)
