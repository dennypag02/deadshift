extends SceneTree
var errors:=0
func check(ok:bool,why:String) -> void:
	if not ok:
		errors+=1
		push_error("PERFORMANCE_FAIL "+why)
func _initialize()->void:
	call_deferred("run")
func run()->void:
	var g=load("res://scenes/Outskirts.tscn").instantiate()
	root.add_child(g)
	g.telemetry.set_process(false)
	g.set_physics_process(false)
	g.progression.set_physics_process(false)
	g.guidance.disabled_for_test=true
	paused=false
	g.events.interrupt("performance_fixture") # Budget test is independent of tutorial spawns.
	g.enemies.clear()
	for i in range(270): g._append_enemy("shambler",g.player_pos+Vector2(i*2,0))
	check(g.enemies.size()==250,"250 enemy budget")
	var count:int=g.enemies.size()
	g.wave=1;g.wave_active=true;g.wave_clock=0
	g._tick_wave_clock(59.99)
	check(g.wave_active,"wave must last 60 active seconds")
	Engine.time_scale=.02
	g._tick_wave_clock(.01)
	check(not g.wave_active,"hit-stop must not extend wave deadline")
	check(g.enemies.size()==count,"wave end retains zombies")
	var mutation_manager: Node = root.get_node_or_null("MutationManager")
	check(mutation_manager != null and bool(mutation_manager.get("offer_open")),"between-wave mutation offer opens")
	check(g.break_clock==0.0 and g.wave==1,"wave waits while mutation offer is open")
	mutation_manager.call("skip_offer")
	check(not paused and is_equal_approx(g.break_clock,1.0),"skip closes mutation offer and resumes run")
	g._tick_wave_clock(1.0)
	check(g.wave==2 and g.wave_active,"mutation decision resumes next wave")
	g._tick_wave_clock(67.5)
	check(not g.wave_active,"later wave ends at 67.5s")
	Engine.time_scale=1.0
	g.actors._process(.016)
	check(g.actors.allocations==4,"constant batch-node allocation, not per enemy")
	check(g.actors.active.size()==250,"250 valid renderer identities")
	var rendered:int=g.actors.front.multimesh.visible_instance_count+g.actors.behind.multimesh.visible_instance_count
	check(rendered==g.actors.visible_actors,"batched instance counts")
	g._rebuild_enemy_grid()
	var hits:Array=g.enemy_indices_near(g.player_pos,55.0)
	for i in range(g.enemies.size()):
		if Vector2(g.enemies[i].pos).distance_to(g.player_pos)<=55: check(hits.has(i),"grid must not lose nearby enemy")
	g._phase_a_kill_enemy(0)
	for idx in g.enemy_indices_near(g.player_pos,75): check(idx>=0 and idx<g.enemies.size(),"grid survives removal")
	for i in range(500):
		g.juice_fx.emit("blood",g.player_pos,Vector2.ZERO,.1)
		g.juice_fx.damage_number(i,g.player_pos,1,false)
		g.juice_fx.kill(g.player_pos,1)
	check(g.juice_fx.effects.size()<=96,"particle budget")
	check(g.juice_fx.damage_numbers.size()<=40,"damage-number budget")
	check(g.juice_fx.decals.size()<=40,"decal budget")
	for i in range(500):g.progression.drop_xp(g.player_pos,"shambler")
	check(g.progression.gems.size()<=200,"merge gem overflow")
	for c in g.route_cells: check(not g._tile_char(c.x,c.y) in ["x",":","o"],"objective corridor free of slows")
	var hazards:=0
	for y in range(g.MAP_H):
		for x in range(g.MAP_W):
			if g._tile_char(x,y) in ["x",":","o"]: hazards+=1
	check(hazards>0,"off-route tactical terrain preserved")
	check(g.progression.xp_required(1)==12,"data-driven first level cost")
	for n in range(2,30): check(g.progression.xp_required(n)>=g.progression.xp_required(n-1),"nondecreasing XP cost including curve tail")
	g.bullets.clear()
	g.progression.rockets.clear()
	g.progression.chakrams.clear()
	g.progression.lightning_arcs.clear()
	g.progression.drone_shots.clear()
	for i in range(399):g.transient_pool.push(g.bullets,"bullets",{"pos":g.player_pos,"dir":Vector2.RIGHT,"life":1.0},400)
	g.progression.weapons["rocket"]=5
	g.progression._spawn_rockets()
	check(g.projectile_count()==400,"shared projectile cap stops multi-shot overflow")
	g.progression.weapons["chakram"]=5
	g.progression._spawn_chakrams()
	check(g.projectile_count()==400,"all weapon families share projectile cap")
	print("PERFORMANCE_TESTS_%s errors=%d corridor_cells=%d off_route_slows=%d" % ["PASS" if errors==0 else "FAIL",errors,g.route_cells.size(),hazards])
	quit(errors)
