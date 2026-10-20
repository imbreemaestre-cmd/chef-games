class_name SaveGame
extends RefCounted
## Save and load for Sunberry Hollow.
##
## One JSON file in user:// holds the whole run: inventory, tools, party,
## flags, quest step, recipe knowledge and chef progression. Missing keys on
## load fall back to defaults, so an older save never breaks a new build.

const PATH := "user://sunberry_save.json"
const VERSION := 1


static func has_save() -> bool:
	return FileAccess.file_exists(PATH)


static func save(state: Dictionary) -> bool:
	var payload := state.duplicate(true)
	payload["version"] = VERSION
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Sunberry Hollow: could not open save file for writing")
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


static func load_state() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary


static func erase() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
