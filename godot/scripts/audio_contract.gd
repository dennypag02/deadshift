extends RefCounted
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("AUDIO_FAIL "+label)
func run_checks(tree: SceneTree) -> int:
	var sm: Node = tree.root.get_node("SoundManager")
	var original_settings: Dictionary = sm.settings.duplicate()
	var old_path: String = sm.settings_path
	sm.settings_path = "user://audio_contract_settings.cfg"
	for name in ["Master","Music","SFX","UI"]: check(AudioServer.get_bus_index(name)>=0,"bus "+name)
	var limiter: AudioEffect = AudioServer.get_bus_effect(AudioServer.get_bus_index("SFX"),0)
	check(limiter is AudioEffectHardLimiter and limiter.ceiling_db==-1.0,"hard limiter ceiling")
	check(sm.filter is AudioEffectLowPassFilter,"music lowpass effect")
	check(sm.ready_samples and sm.config.sounds.size()==66,"entire spec SFX catalog loaded")
	check(not sm.config.sounds.has("shambler_voice") and not sm.config.sounds.has("footsteps"),"no ambient shambler vocals or footsteps")
	for name in sm.config.sounds:
		for voice in sm.pool: voice.stop()
		sm.last_play.clear()
		check(sm.play(name),"placeholder plays: "+name)
		var found := false
		for voice in sm.pool:
			if voice.playing and voice.get_meta("sound","")==name:
				found = true
				check(voice.stream is AudioStreamWAV and voice.stream.mix_rate==44100 and not voice.stream.stereo,"44.1k mono WAV: "+name)
		check(found,"pooled playback state: "+name)
		check(not sm.play(name),"cooldown blocks immediate repeat: "+name)
	for voice in sm.pool: voice.stop()
	sm.last_play.clear()
	var prior: Dictionary = sm.config.sounds.zombie_hit.duplicate()
	sm.config.sounds.zombie_hit.max_instances = 100
	sm.config.sounds.zombie_hit.cooldown_ms = 0
	for i in range(100): sm.play("zombie_hit")
	check(sm.voice_count()<=32 and sm.pool.size()<=30,"global cap includes two music slots")
	sm.last_play.erase("brute_roar")
	check(sm.play("brute_roar"),"warning replaces lower priority")
	var warning: AudioStreamPlayer2D
	for voice in sm.pool:
		if voice.get_meta("sound","")=="brute_roar": warning = voice
	for i in range(100): sm.play("zombie_hit")
	check(warning!=null and warning.playing and warning.get_meta("sound")=="brute_roar","warning never stolen by low priority")
	sm.config.sounds.zombie_hit = prior
	sm.set_setting("Music",0.23)
	sm.set_setting("SFX",0.41)
	sm.set_setting("UI",0.62)
	sm.set_setting("vibration",false)
	sm.set_setting("mute",true)
	sm.settings.Music = 1.0
	sm.load_settings()
	check(sm.settings.Music==0.23 and sm.settings.SFX==0.41 and sm.settings.UI==0.62,"sliders persisted")
	check(not sm.settings.vibration and sm.settings.mute and AudioServer.is_bus_mute(0),"toggle persistence")
	sm.set_backgrounded(true)
	for voice in sm.pool: check(voice.process_mode==Node.PROCESS_MODE_DISABLED,"background disables pending and active voices")
	check(not sm.play("level_up"),"no new sound in background")
	sm.set_backgrounded(false)
	for voice in sm.pool: check(not voice.stream_paused,"foreground resumes voices")
	sm.audio_clock = 10
	sm.xp_at = -100
	sm.xp_gem()
	sm.audio_clock += 0.1
	sm.xp_gem()
	check(sm.xp_steps==1,"XP climbs one semitone")
	sm.audio_clock += 0.31
	sm.xp_gem()
	check(sm.xp_steps==0,"XP chain resets after 0.3s")
	sm.duck("banner",true)
	sm._process(0.3)
	check(sm.duck_offset==-6.0,"duck six dB in0.3s")
	sm.duck("banner",false)
	sm._process(0.8)
	check(sm.duck_offset==0,"duck recovery0.8s")
	sm.set_phase("surge")
	check(sm.phase=="surge" and sm.played.has("surge_warning"),"adaptive surge cue")
	for voice in sm.pool: voice.stop()
	for voice in sm.music: voice.stop()
	sm.settings = original_settings
	sm.settings_path = old_path
	sm._apply_mix()
	DirAccess.remove_absolute("user://audio_contract_settings.cfg")
	print("AUDIO_TESTS_%s checks=%d failures=%d" % ["PASS" if failures==0 else "FAIL",checks,failures])
	return failures
