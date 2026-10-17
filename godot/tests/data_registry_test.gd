extends SceneTree

func _initialize() -> void:
	var registry_script := load("res://autoload/data_registry.gd")
	if registry_script == null:
		_fail("registry_script_missing")
		return
	var registry := registry_script.new()
	root.add_child(registry)
	await process_frame

	if not registry.reload_all():
		_fail("current_data_failed_validation")
		return

	var before := registry.errors.size()
	var valid := registry.validate_json_file("res://tests/fixtures/malformed.json")
	if valid:
		_fail("malformed_fixture_was_accepted")
		return
	if registry.errors.size() != before + 1:
		_fail("malformed_fixture_did_not_record_error")
		return
	var last_error := str(registry.errors[-1])
	if "DATAREGISTRY_ERROR" not in last_error or "malformed_json" not in last_error:
		_fail("malformed_fixture_error_not_clear")
		return

	var missing_probe := {"id": "probe"}
	var probe_path := "user://missing-field-probe.json"
	var probe_file := FileAccess.open(probe_path, FileAccess.WRITE)
	probe_file.store_string(JSON.stringify(missing_probe))
	probe_file.close()
	before = registry.errors.size()
	valid = registry.validate_json_file(probe_path, ["id", "name"])
	if valid:
		_fail("missing_field_fixture_was_accepted")
		return
	if registry.errors.size() != before + 1 or "missing_field field=name" not in str(registry.errors[-1]):
		_fail("missing_field_error_not_clear")
		return

	print("DATA_REGISTRY_TESTS_PASS")
	quit(0)

func _fail(reason: String) -> void:
	push_error("DATA_REGISTRY_TESTS_FAIL reason=%s" % reason)
	quit(1)
