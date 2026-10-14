extends SceneTree

func _initialize() -> void:
	call_deferred("_check")

func _fail(message: String) -> void:
	push_error("PHASE_B_CHECK_FAIL " + message)
	quit(1)

func _check() -> void:
	var scene: PackedScene = load("res://scenes/Outskirts.tscn")
	var game := scene.instantiate()
	get_root().add_child(game)
	for i in range(15):
		await process_frame

	var p = game.progression
	if p == null:
		_fail("missing progression")
		return
	var cfg: Dictionary = p.config
	if cfg.get("weapons", {}).size() != 8:
		_fail("expected 8 weapons")
		return
	if cfg.get("passives", {}).size() != 11:
		_fail("expected 11 passives")
		return
	if int(cfg.get("limits", {}).get("weapons", 0)) != 6 or int(cfg.get("limits", {}).get("passives", 0)) != 6:
		_fail("build limits are not 6+6")
		return
	if int(cfg.get("limits", {}).get("active_enemies", 0)) != 250:
		_fail("active enemy cap")
		return
	if int(cfg.get("limits", {}).get("damage_numbers", 0)) != 40:
		_fail("damage-number cap")
		return

	var rarity: Dictionary = cfg.get("rarity", {})
	var rarity_sum: float = 0.0
	for key in ["common", "rare", "epic", "legendary"]:
		rarity_sum += float(rarity.get(key, {}).get("chance", 0.0))
	if absf(rarity_sum - 1.0) > 0.0001:
		_fail("rarity odds do not total 1")
		return
	if absf(float(rarity.get("common", {}).get("chance", 0.0)) - 0.70) > 0.0001:
		_fail("common odds")
		return
	if absf(float(rarity.get("rare", {}).get("chance", 0.0)) - 0.22) > 0.0001:
		_fail("rare odds")
		return
	if absf(float(rarity.get("epic", {}).get("chance", 0.0)) - 0.07) > 0.0001:
		_fail("epic odds")
		return
	if absf(float(rarity.get("legendary", {}).get("chance", 0.0)) - 0.01) > 0.0001:
		_fail("legendary odds")
		return

	if p.rerolls_left != 2 or p.banishes_left != 1:
		_fail("reroll/banish starting counts")
		return
	if not p.use_reroll() or p.rerolls_left != 1:
		_fail("reroll consumption")
		return
	p.choice_rarities["boomstick"] = "COMMON"
	if not p.banish("boomstick") or p.banishes_left != 0:
		_fail("banish consumption")
		return

	p.weapons.clear()
	for id in cfg["weapons"]:
		p.weapons[id] = int(cfg["weapons"][id].get("max_level", 5))
	p.passives.clear()
	for id in cfg["passives"]:
		p.passives[id] = int(cfg["passives"][id].get("max_level", 5))
	p.banished.clear()
	var fallback: Array[String] = p.available_choices()
	if fallback.size() != 3 or not fallback.has("fallback_gold") or not fallback.has("fallback_heal"):
		_fail("fallback cards missing at max build")
		return

	p.weapons = {"scrap_smg": 1}
	p.passives.clear()
	p.weapon_steps = {"scrap_smg": [1.0]}
	p.passive_steps.clear()
	p.gems.clear()
	p.xp = 0
	p.level = 1
	p.pending_levels = 0
	p.choosing = false
	p.xp_dropped_total = 0
	p.xp_collected_total = 0
	game.wave_active = true
	p.drop_xp(game.player_pos + Vector2(700, 0), "shambler")
	p.gems[0]["age"] = float(cfg.get("xp", {}).get("vacuum_age_seconds", 8.0)) + 1.0
	for i in range(8):
		p._physics_process(0.1)
	if p.xp_collected_total != 1 or not p.gems.is_empty():
		_fail("aged gem vacuum did not collect XP")
		return

	if float(cfg.get("damage_numbers", {}).get("merge_window_seconds", 0.0)) != 0.15:
		_fail("damage-number merge window")
		return

	print("PHASE_B_CHECK_PASS weapons=8 passives=11 limits=6+6 rarity=70/22/7/1 vacuum=PASS damage_cap=40")
	quit(0)
