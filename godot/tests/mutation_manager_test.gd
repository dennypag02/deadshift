extends SceneTree

func _initialize() -> void:
	await process_frame
	if MutationManager.definitions.size() != 15:
		_fail("expected_15_mutations_loaded_%d" % MutationManager.definitions.size())
		return

	var expected_slots := {"arms":3,"legs":3,"torso":3,"back":3,"head":3}
	var slot_counts := {"arms":0,"legs":0,"torso":0,"back":0,"head":0}
	for id in MutationManager.definitions:
		var row: Dictionary = MutationManager.definitions[id]
		var slot := str(row["slot"])
		slot_counts[slot] = int(slot_counts.get(slot,0)) + 1
		if (row["levels"] as Array).size() != 3:
			_fail("%s_levels_not_3" % id)
			return
	for slot in expected_slots:
		if int(slot_counts[slot]) != int(expected_slots[slot]):
			_fail("slot_count_%s_%d" % [slot,slot_counts[slot]])
			return

	for id in MutationManager.definitions:
		MutationManager.reset_run()
		for level in range(1,4):
			var result: Dictionary = MutationManager.take_mutation(str(id))
			if not bool(result.get("ok",false)) or MutationManager.held_level(str(id)) != level:
				_fail("leveling_failed_%s_%d" % [id,level])
				return

	MutationManager.reset_run()
	if not bool(MutationManager.take_mutation("bone_blade").get("ok",false)):
		_fail("bone_blade_take_failed")
		return
	var replacement: Dictionary = MutationManager.take_mutation("tesla_knuckles")
	if not bool(replacement.get("ok",false)) or str(replacement.get("replaced","")) != "bone_blade":
		_fail("slot_replacement_failed")
		return
	if MutationManager.held_level("bone_blade") != 0 or MutationManager.held_level("tesla_knuckles") != 1:
		_fail("replacement_state_wrong")
		return

	MutationManager.reset_run()
	MutationManager.take_mutation("ribcage_nest")
	MutationManager.take_mutation("capacitor_hump")
	if int(RunState.tag_counts["swarm"]) != 1 or int(RunState.tag_counts["bone"]) != 1:
		_fail("ribcage_dual_tags_wrong")
		return
	if int(RunState.tag_counts["shock"]) != 1 or int(RunState.tag_counts["fire"]) != 1:
		_fail("capacitor_dual_tags_wrong")
		return

	var offers := MutationManager._generate_offers()
	if offers.size() != 3:
		_fail("offer_count_not_3")
		return

	print("MUTATION_MANAGER_TESTS_PASS mutations=15 slots=5 levels=3 replacement=true offers=3")
	quit(0)

func _fail(reason: String) -> void:
	push_error("MUTATION_MANAGER_TESTS_FAIL reason=%s" % reason)
	quit(1)
