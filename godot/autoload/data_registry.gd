extends Node
## Loads and validates data files without owning gameplay behavior.
## Milestone 2 intentionally keeps schema rules minimal while the mutation
## content files do not exist yet; later milestones register required fields.

const DATA_ROOT := "res://data"

var records: Dictionary = {}
var errors: Array[String] = []
var loaded_files := 0

func _ready() -> void:
	reload_all()
	var probe := OS.get_environment("DEADSHIFT_DATAREGISTRY_TEST_FILE")
	if not probe.is_empty():
		validate_json_file(probe)

func reload_all() -> bool:
	records.clear()
	errors.clear()
	loaded_files = 0
	_scan_directory(DATA_ROOT)
	if errors.is_empty():
		print("DATAREGISTRY_READY files=%d errors=0" % loaded_files)
		return true
	print("DATAREGISTRY_FAILED files=%d errors=%d" % [loaded_files, errors.size()])
	return false

func _scan_directory(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		_record_error(path, "directory_unavailable")
		return
	directory.list_dir_begin()
	while true:
		var name := directory.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue
		var child := path.path_join(name)
		if directory.current_is_dir():
			_scan_directory(child)
		elif name.get_extension().to_lower() == "json":
			validate_json_file(child)
	directory.list_dir_end()

func validate_json_file(path: String, required_fields: Array = []) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_record_error(path, "file_unavailable:%s" % error_string(FileAccess.get_open_error()))
		return false
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	if parse_error != OK:
		_record_error(path, "malformed_json line=%d message=%s" % [parser.get_error_line(), parser.get_error_message()])
		return false
	var value: Variant = parser.data
	if not (value is Dictionary or value is Array):
		_record_error(path, "invalid_root expected=object_or_array")
		return false
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		for field in required_fields:
			if not dictionary_value.has(field):
				_record_error(path, "missing_field field=%s" % field)
				return false
	records[path] = value
	loaded_files += 1
	return true

func get_record(path: String, fallback: Variant = null) -> Variant:
	return records.get(path, fallback)

func _record_error(path: String, reason: String) -> void:
	var message := "DATAREGISTRY_ERROR path=%s reason=%s" % [path, reason]
	errors.append(message)
	push_error(message)
