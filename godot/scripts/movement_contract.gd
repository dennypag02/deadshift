extends RefCounted
## Deterministic fixture assertions, separate from input-only survival qualification.
var g: Node2D
var checks := 0
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("MOVEMENT_FAIL " + message)
func advance(seconds: float) -> void:
	g.run_clock += seconds
	g.wave_clock += seconds
	g.events.tick(seconds)
func offer(number: int) -> void:
	g.events.interrupt("fixture_transition")
	g.events.offered_waves.erase(number)
	g._start_wave(number)
	advance(float(g.rules.objectives.breather_seconds))
	g.guidance.refresh_target()
	g.hud_overlay._update_event_card()
func reset_hp(hp: int = 100) -> void:
	g.player_max_hp = 100
	g.player_hp = hp
	g.fairness.recent.clear()
	g.fairness.grace_left = 0
	g.progression.invulnerability = 0
	g.player_hit_invulnerability = 0
	g.phase_ui.god_mode = false
	g.guidance.briefing = false
func run_on(game: Node2D) -> int:
	g = game
	g.get_tree().paused = false
	g.telemetry.set_process(false)
	g.set_physics_process(false)
	g.progression.set_physics_process(false)
	g.guidance.disabled_for_test = true
	g.run_log.begin()
	reset_hp()
	# Damage from many sources must share a sliding, not wall-second-aligned, budget.
	g.run_clock = 10.9
	check(g.fairness.apply(1000,"pump_explosion")==30,"single pump at most thirty percent")
	check(g.fairness.apply(1000,"acid")==5,"stacked acid uses remaining shared five percent")
	check(g.fairness.apply(1000,"fire")==0,"fire cannot bypass aggregate cap")
	g.run_clock = 11.0
	check(g.fairness.apply(1000,"brute")==0,"wall-clock boundary does not reset rolling cap")
	g.run_clock = 11.901
	check(g.fairness.apply(1000,"brute")==35,"budget replenishes after one active second")
	check(g.player_hp==30,"stacked fixture total bounded")
	reset_hp()
	g.guidance.briefing = true
	check(g.fairness.apply(100,"pump_explosion")==0,"pan protects pump damage")
	g.guidance.briefing = false
	g.fairness.protect_after_reveal()
	g.fairness.tick(0.999)
	check(g.fairness.apply(100,"acid")==0,"reveal grace covers full one second")
	g.fairness.tick(0.002)
	check(g.fairness.apply(3,"acid")==3,"normal damage resumes after grace")
	reset_hp()
	g.run_log.current_wave.clear()
	g.run_log.start_wave()
	g.player_hp = 6
	g.fairness.apply(1,"acid")
	g.player_hp = 100
	g.run_log.close_wave("completed")
	check(g.run_log.waves[-1].min_hp==5,"five HP minimum survives immediate healing")
	# Local nearby events, explicit verbs, all rows and rewards remain accounted for.
	for number in range(1,10):
		g.player_pos = Vector2(16,22)*g.TILE
		offer(number)
		check(not g.events.active.is_empty(),"wave %d has one delayed event" % number)
		check(g.events.active.verb in ["HOLD","GRAB","DESTROY"],"one of three interaction verbs")
		var distance: float = g.events.active.row.offered_distance_m
		check(distance>=20 and distance<=40,"offered distance 20-40m wave %d" % number)
		for point in g.events.active.points:
			check(not g._circle_hits_blocker(point,g.PLAYER_RADIUS),"objective footprint walkable")
		check(not g.hud_overlay.crate_row.visible,"no leaking legacy crate row in two-line card")
		check(g.hud_overlay.reward_icon.texture!=null,"reward icon resolves")
		check(g.hud_overlay.countdown.visible,"independent countdown visible")
		check(g.hud_overlay.card_panel.size.y<=float(g.rules.ui.card_height),"two-line compact card")
		if number==1:
			check(g._active_horde_target()<=14,"first-event spawn relief retained")
			var mid: Vector2 = (g.player_pos+Vector2(g.events.target().pos))/2
			check(not g.events.spawn_allowed(mid,24),"tutorial corridor protected")
			g.player_pos = g.events.target().pos
			advance(1)
			check(float(g.events.active.charge)>0,"HOLD charge accumulates")
			g.fairness.apply(1,"shambler")
			check(float(g.events.active.charge)>0,"new HOLD does not reset from incidental damage")
			advance(4)
			check(g.events.active.is_empty() and g.generator_active,"generator completes by hold")
			check(g.events.earned.has("auto_turret") and g.events.earned.has("floodlights"),"generator rewards preserved")
		elif g.events.active.verb=="GRAB":
			for step in range(int(g.events.active.count)):
				g.player_pos = g.events.target().pos
				advance(0.05)
			check(g.events.active.is_empty(),"GRAB completes from actual pickup")
		elif g.events.kind()=="relay":
			for step in range(3):
				g.player_pos = g.events.target().pos
				advance(1.3)
			check(g.events.active.is_empty() and g.events.earned.has("airstrike"),"relay HOLD pads reward")
		elif g.events.active.verb=="DESTROY" and g.events.kind()!="mechanic":
			var at: Vector2 = g.events.target().pos
			var before: float = g.events.active.hp
			g.player_pos = at
			advance(0.1)
			check(g.events.active.hp==before,"proximity alone never destroys objective")
			g.events.hit_bullet(at,before-1)
			check(g.events.active.hp==1,"DESTROY has actual remaining HP")
			g.events.hit_bullet(at,1)
			check(g.events.active.is_empty(),"DESTROY only completes at zero HP")
	# Misses, UI pauses and reward idempotence.
	g.player_pos = Vector2(16,22)*g.TILE
	offer(1)
	var time_before: float = g.events.active.elapsed
	g.telemetry.offline = true
	g.get_tree().paused = true
	g.telemetry._process(5)
	check(g.events.active.elapsed==time_before,"paused UI freezes objective deadline")
	g.get_tree().paused = false
	advance(60)
	check(g.events.toast_text=="MISSED","quiet miss toast")
	check(g.guidance.target.is_empty(),"miss removes guidance")
	var offered_count: int = g.run_log.rows.size()
	advance(3)
	check(g.run_log.rows.size()==offered_count,"next event waits for next wave")
	# FIFO band; never a centered notification or parallel overlay.
	g.hud_overlay.clear_notifications()
	g.banner.text = ""
	g.hud_overlay.notify("FIRST")
	g.hud_overlay.notify("SECOND")
	g.hud_overlay._process(0.01)
	check(g.hud_overlay.band_text.text=="FIRST","FIFO starts first message")
	check(g.hud_overlay.backdrop.position.y+g.hud_overlay.backdrop.size.y<g.get_viewport_rect().size.y*0.35,"banner stays in top band")
	check(g.hud_overlay.notification_left<=1.5,"banner lifetime at most 1.5 seconds")
	g.hud_overlay._process(1.501)
	check(g.hud_overlay.band_text.text=="SECOND","second banner waits its turn")
	check(not g.banner.visible,"legacy center label always hidden")
	# All installed icons, plus fallback deliberately exercised without deleting approved art.
	for id in g.phase_ui.icon_map:
		check(g.phase_ui.icon_textures.has(id),"mapped promoted icon exists: "+id)
	g.phase_ui.current_choices.assign(["scrap_smg","boomstick","magnet"])
	g.phase_ui._refresh_choices()
	for icon in g.phase_ui.card_art: check(icon.texture!=null,"level-up card has actual texture")
	var saved: Dictionary = g.phase_ui.icon_textures.duplicate()
	g.phase_ui.icon_textures.clear()
	g.phase_ui._refresh_choices()
	for i in range(g.phase_ui.current_choices.size()):
		check(not g.phase_ui.card_art[i].visible and g.phase_ui.card_icons[i].color.a>0,"missing-icon placeholder fallback")
	g.phase_ui.icon_textures = saved
	# Ground hazards are bounded and preserve a safe fixed destination to sidestep.
	g.events.interrupt("hazard_fixture")
	g.enemies.clear()
	g.wave = 3
	g._append_enemy("spitter",g.player_pos+Vector2(300,0))
	g.stage1_hazards.clear()
	var old_spot: Vector2 = g.player_pos
	g._warn_acid(g.enemies[-1])
	check(g.stage1_hazards[0].pos==old_spot and g.stage1_hazards[0].life==0.8,"spitter locks exact current spot for 0.8 seconds")
	g.player_pos += Vector2(0,200)
	reset_hp()
	g._stage1_update_hazards(0.81)
	g._stage1_update_hazards(0.1)
	check(g.player_hp==100,"sidestep fully avoids acid")
	for i in range(20): g.add_hazard("goo",g.player_pos,float(g.rules.goo.radius),5,"",-1)
	g._enforce_goo_cap()
	var goo := 0
	for h in g.stage1_hazards:
		if h.kind=="goo": goo += 1
	check(goo<=6,"maximum six visible goo puddles")
	check(g.rules.goo.radius==57.5 and g.rules.goo.fade_seconds==1,"half-size goo and final-second fade data")
	# The brute locks its warning lane and never steers the charge toward the dodge.
	g.enemies.clear()
	g.player_pos = Vector2(16.5,22.5)*g.TILE
	g._append_enemy("brute",g.player_pos+Vector2(280,0))
	var brute: Dictionary = g.enemies[-1]
	g._update_enemy(brute,0.01)
	var fixed_direction: Vector2 = brute.charge_target
	check(brute.charge<0,"early brute displays warning before movement")
	g.player_pos += Vector2(0,180)
	for i in range(100): g._update_enemy(brute,0.016)
	check(brute.charge_target==fixed_direction,"brute charge never follows sidestep")
	check(g.player_hp==100,"full sidestep avoids the locked charge")
	# No passive XP transport; real pickup and expiry work.
	g.progression.gems.clear()
	g.progression.choosing = false
	g.progression.weapons.clear()
	g.progression.gems.append({"pos":g.player_pos+Vector2(800,0),"value":1,"age":10.0})
	var gem_before: Vector2 = g.progression.gems[0].pos
	g.progression._physics_process(0.1)
	check(g.progression.gems[0].pos==gem_before,"old gems never fly to idle survivor")
	g.progression.vacuum_all_gems()
	check(g.progression.gems[0].pos==gem_before,"wave break no automatic collection")
	g.progression.gems[0].age = 19.99
	g.progression._physics_process(0.02)
	check(g.progression.gems.is_empty(),"gems expire at twenty seconds")
	for i in range(25):
		var drop: Vector2 = g.reward_position(g.player_pos)
		var distance: float = drop.distance_to(g.player_pos)/g.metres(1)
		check(distance>=6 and distance<=12,"physical rewards 6-12m away")
	# Retained facing and bounded forward cones, not autoaim at a chasing enemy.
	g.bullets.clear()
	g.facing = Vector2.RIGHT
	g.transient_pool.push(g.bullets,"bullets",{"pos":g.player_pos,"dir":Vector2.LEFT,"life":1.6,"hits_left":1,"damage_mult":1.0,"knockback":0.0},400)
	g._update_bullets(0)
	check(not g.bullets.is_empty() and Vector2(g.bullets[0].dir).dot(Vector2.RIGHT)>0.99,"SMG follows facing")
	# Camp grace/reset and all-four-side pressure do not alter enemy base speed.
	g.stage1_hazards.clear()
	g.wave_active = true
	g.camp_origin = g.player_pos
	g.camp_seconds = 0
	g.camp_active = false
	g._tick_camp(8.01)
	check(g.camp_active and not g.stage1_hazards.is_empty(),"eight-second camping triggers pressure and one aimed spitter")
	g.player_pos += Vector2(g.metres(3.1),0)
	g._tick_camp(0.1)
	check(not g.camp_active and g.camp_seconds==0,"moving beyond three metres resets camp pressure")
	# Final actual damage determines killer and exact tail is persisted.
	reset_hp(3)
	g.run_log.ended = false
	g.run_clock += 6
	g.fairness.apply(3,"pump_explosion")
	g.run_log.finish("death")
	check(FileAccess.file_exists(g.run_log.directory.path_join("death_damage.json")),"last-five-second death receipt persisted")
	var death: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(g.run_log.directory.path_join("death_damage.json")))
	check(death.killed_by=="Pump explosion" and death.ticks[-1].amount==3,"named killer and final tick accurate")
	g.phase_ui.show_game_over(g.run_clock,g.wave,1,0,0,0,false)
	check(g.phase_ui.game_over_stats.text.contains("Killed by: Pump explosion"),"killer shown on game-over")
	check(not g.phase_ui.game_over_stats.text.contains("SCRAP EARNED"),"Garage-only scrap hidden")
	var summary: Dictionary = g.run_log.summary()
	check(summary.events_offered==summary.events_completed+summary.events_missed+summary.events_interrupted+summary.events_active,"event accounting balances")
	check(not summary.human_survival_rate_inferred,"fixture cannot imply human difficulty")
	print("MOVEMENT_TESTS_%s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL",checks,failures.size()])
	return failures.size()
