extends RefCounted

const EN = preload("res://localization/en.tres")
const RU = preload("res://localization/ru.tres")
const SETTINGS_PATH = "user://settings.cfg"

static func initialize(persist: bool, path: String = SETTINGS_PATH) -> void:
	TranslationServer.add_translation(EN)
	TranslationServer.add_translation(RU)
	var settings = ConfigFile.new()
	var locale = "en"
	if persist and settings.load(path) == OK:
		locale = str(settings.get_value("language", "locale", "en"))
	TranslationServer.set_locale(locale if locale in ["en", "ru"] else "en")

static func select(locale: String, persist: bool, path: String = SETTINGS_PATH) -> void:
	if locale not in ["en", "ru"]:
		return
	TranslationServer.set_locale(locale)
	if persist:
		var settings = ConfigFile.new()
		settings.set_value("language", "locale", locale)
		var error = settings.save(path)
		if error != OK:
			push_warning("Could not save language preference: " + str(error))

# Preserve unknown historical wording rather than changing the evidence.
static func migrate(value: Variant) -> Variant:
	if value is String:
		for translation in [RU, EN]:
			for key in translation.get_message_list():
				if str(translation.get_message(key)) == value:
					return str(key)
		return value
	if value is Array:
		var result: Array = []
		for entry in value:
			result.append(migrate(entry))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[key] = migrate(value[key])
		# Older tribunal saves combined a reason with the case explanation.
		if str(result.get("reason", "")).begins_with(str(RU.get_message("COURT_REASON_WRONG"))):
			result.reason = "COURT_REASON_WRONG"
		return result
	return value
