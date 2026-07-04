extends Node
## Minimal JSON-based persistence layer for user:// save data.

const SAVE_PATH: String = "user://savegame.json"


## Serializes a data dictionary to JSON and writes it to the save file.
func save_game(data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: could not open '%s' for writing." % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


## Reads and parses the save file, returning an empty dictionary if missing or invalid.
func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: could not open '%s' for reading." % SAVE_PATH)
		return {}
	var raw_text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(raw_text)
	if parsed is Dictionary:
		return parsed
	push_error("SaveManager: save file did not contain a valid JSON object.")
	return {}
