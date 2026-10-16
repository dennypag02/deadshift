extends Node
## Audio-only RNG/state. Never writes player, enemy, loot or gameplay clocks.
const Synth = preload("res://scripts/placeholder_synth.gd")
var config: Dictionary
var settings := {"Music":0.7,"SFX":0.85,"UI":0.8,"mute":false,"vibration":true}
var settings_path := "user://audio_settings.cfg"
var pool: Array[AudioStreamPlayer2D] = []
var music: Array[AudioStreamPlayer] = []
var samples: Dictionary = {}
var last_play: Dictionary = {}
var last_variant: Dictionary = {}
var ducks: Dictionary = {}
var rng := RandomNumberGenerator.new()
var listener := Vector2.ZERO
var phase := "breather"
var music_id := ""
var music_slot := 0
var music_offset := -4.0
var duck_offset := 0.0
var filter: AudioEffectLowPassFilter
var transition: Tween
var fade: Tween
var backgrounded := false
var xp_at := -100.0
var xp_steps := 0
var peak_voices := 0
var played: Dictionary = {}
var dropped := 0
var ready_samples := false
var audio_clock := 0.0
var ending_clock := -1.0
var music_clock := 0.0
var protected_pending: Dictionary = {}
var processing_pending := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/sounds.json"))
	rng.seed = int(config.sfx_seed)
	for bus in ["Music","SFX","UI"]:
		if AudioServer.get_bus_index(bus)<0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
		AudioServer.set_bus_send(AudioServer.get_bus_index(bus),"Master")
	filter = AudioEffectLowPassFilter.new()
	filter.cutoff_hz = 900
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Music"),filter)
	for bus in ["SFX","Master"]:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -1.0
		AudioServer.add_bus_effect(AudioServer.get_bus_index(bus),limiter)
	for i in range(int(config.initial_pool)): _grow_pool()
	for i in range(int(config.music_reserved)):
		var player := AudioStreamPlayer.new()
		player.bus = "Music"
		add_child(player)
		music.append(player)
	load_settings()
	preload_sfx()

func _grow_pool() -> void:
	if pool.size()+music.size()>=int(config.hard_cap): return
	var player := AudioStreamPlayer2D.new()
	player.max_distance = float(config.position_max_distance)
	player.attenuation = 1.0
	player.panning_strength = 0.4
	add_child(player)
	pool.append(player)

func preload_sfx() -> void:
	if ready_samples: return
	var started := Time.get_ticks_msec()
	for preset in config.presets:
		var variants: Array[AudioStreamWAV] = []
		for i in range(4): variants.append(Synth.render(config.presets[preset],int(config.sfx_seed)+i))
		samples[preset] = variants
	ready_samples = true
	print("AUDIO_PRELOAD_COMPLETE sounds=%d shared_waveforms=%d ms=%d" % [config.sounds.size(),config.presets.size()*4,Time.get_ticks_msec()-started])

func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(settings_path)==OK:
		for key in settings: settings[key] = file.get_value("audio",key,settings[key])
	for key in ["Music","SFX","UI"]: settings[key] = clampf(float(settings[key]),0,1)
	_apply_mix()

func set_setting(key: String, value: Variant) -> void:
	if not settings.has(key): return
	settings[key] = bool(value) if key in ["mute","vibration"] else clampf(float(value),0,1)
	var file := ConfigFile.new()
	for name in settings: file.set_value("audio",name,settings[name])
	file.save(settings_path)
	_apply_mix()

func _apply_mix() -> void:
	AudioServer.set_bus_mute(0,bool(settings.mute))
	for bus in ["Music","SFX","UI"]:
		var value := float(settings[bus])
		AudioServer.set_bus_mute(AudioServer.get_bus_index(bus),value<=0)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus),linear_to_db(maxf(value,0.0001))+(music_offset+duck_offset if bus=="Music" else 0.0))

func voice_count() -> int:
	var count := 0
	for voice in pool:
		if voice.playing: count += 1
	for voice in music:
		if voice.playing: count += 1
	return count

func play(id: String, at: Vector2 = Vector2.INF, extra_pitch: float = 1.0) -> bool:
	if not ready_samples or backgrounded or not config.sounds.has(id): return false
	var entry: Dictionary = config.sounds[id]
	var now := audio_clock
	if now-float(last_play.get(id,-100.0))<float(entry.cooldown_ms)/1000.0: return false
	var instances := 0
	var voice: AudioStreamPlayer2D
	for candidate in pool:
		if candidate.playing and candidate.get_meta("sound","")==id: instances += 1
		if not candidate.playing: voice = candidate
	if instances>=int(entry.max_instances): return false
	if voice==null and pool.size()<int(config.hard_cap)-int(config.music_reserved):
		_grow_pool()
		voice = pool[-1]
	if voice==null or voice_count()>=int(config.hard_cap):
		voice = null
		var score := INF
		for candidate in pool:
			if bool(candidate.get_meta("protected",false)): continue
			var candidate_priority := int(candidate.get_meta("priority",0))
			if candidate_priority>int(entry.priority): continue
			var quietness := candidate.volume_db-20*log(1+candidate.position.distance_to(listener)/300.0)/log(10)
			var rank := candidate_priority*1000.0+quietness
			if rank<score:
				score = rank
				voice = candidate
		if voice==null:
			if bool(entry.protected):
				protected_pending[id] = {"at":at,"pitch":extra_pitch}
			else: dropped += 1
			return false # Protected cues coalesce by ID and wait rather than cutting another reward.
		voice.stop()
	var variant := rng.randi_range(0,int(entry.variants)-1)
	if variant==int(last_variant.get(id,-1)): variant = (variant+1)%int(entry.variants)
	last_variant[id] = variant
	var stream: AudioStreamWAV = samples[entry.preset][variant]
	if bool(entry.loop):
		stream = stream.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = stream.data.size()/2
	voice.stream = stream
	voice.bus = str(entry.bus)
	voice.position = listener if at==Vector2.INF else at
	voice.set_meta("follow",at==Vector2.INF)
	voice.set_meta("sound",id)
	voice.set_meta("protected",bool(entry.protected))
	voice.set_meta("priority",int(entry.priority))
	voice.pitch_scale = clampf(float(entry.pitch_base)*extra_pitch*rng.randf_range(entry.pitch_range[0],entry.pitch_range[1]),0.25,4.0)
	voice.volume_db = float(entry.volume_db)+rng.randf_range(-float(entry.volume_variation_db),float(entry.volume_variation_db))
	voice.play()
	last_play[id] = now
	played[id] = int(played.get(id,0))+1
	peak_voices = maxi(peak_voices,voice_count())
	return true

func stop_sound(id: String) -> void:
	for voice in pool:
		if voice.get_meta("sound","")==id: voice.stop()

func loop_sound(id: String, enabled: bool, at: Vector2 = Vector2.INF) -> void:
	if not enabled:
		stop_sound(id)
		return
	for voice in pool:
		if voice.playing and voice.get_meta("sound","")==id:
			if at!=Vector2.INF: voice.position = at
			return
	play(id,at)

func xp_gem() -> void:
	xp_steps = mini(xp_steps+1,int(config.xp_max_semitones)) if audio_clock-xp_at<=float(config.xp_chain_seconds) else 0
	xp_at = audio_clock
	play("xp_gem",Vector2.INF,pow(2.0,xp_steps/12.0))

func set_phase(value: String) -> void:
	if value==phase: return
	phase = value
	if not config.adaptive.has(value): return
	if transition!=null: transition.kill()
	var target: Array = config.adaptive[value]
	transition = create_tween().set_parallel(true)
	var seconds := float(config.music_announce_seconds if value=="announce" else config.music_transition_seconds)
	transition.tween_property(filter,"cutoff_hz",float(target[0]),seconds)
	transition.tween_property(self,"music_offset",float(target[1]),seconds)
	if value=="surge": play("surge_warning")

func duck(reason: String, enabled: bool) -> void:
	if enabled: ducks[reason] = true
	else: ducks.erase(reason)

func start_music(id: String) -> void:
	if music_id==id: return
	music_id = id
	if not config.music.has(id): return
	if fade!=null: fade.kill()
	var old := music[music_slot]
	music_slot = (music_slot+1)%music.size()
	var next := music[music_slot]
	next.stop()
	var entry: Dictionary = config.music[id]
	var stream: AudioStreamOggVorbis = load(str(entry.path)).duplicate()
	stream.loop = bool(entry.loop) or bool(entry.get("placeholder",false))
	next.stream = stream
	next.pitch_scale = float(entry.pitch)
	next.volume_db = -80
	next.play()
	next.stream_paused = backgrounded
	fade = create_tween().set_parallel(true)
	fade.tween_property(old,"volume_db",-80.0,float(config.end_music_fade_seconds))
	fade.tween_property(next,"volume_db",0.0,float(config.end_music_fade_seconds))
	fade.chain().tween_callback(old.stop)
	ending_clock = float(entry.duration_s) if not bool(entry.loop) else -1.0
	music_clock = 0.0

func boss_phase_three() -> void:
	if music_id=="trucker_boss": music[music_slot].pitch_scale = float(config.music.trucker_boss.pitch)*1.03
	loop_sound("trailer_drag",true)

func set_backgrounded(value: bool) -> void:
	backgrounded = value
	for voice in pool:
		voice.stream_paused = value
		voice.process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
	for voice in music:
		voice.stream_paused = value
		voice.process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_PAUSED: set_backgrounded(true)
	elif what==NOTIFICATION_APPLICATION_RESUMED: set_backgrounded(false)

func _process(delta: float) -> void:
	if backgrounded: return
	var dt := delta/maxf(0.02,Engine.time_scale)
	audio_clock += dt
	music_clock += dt
	if not protected_pending.is_empty() and not processing_pending:
		processing_pending = true
		for id in protected_pending.keys():
			var pending: Dictionary = protected_pending[id]
			if play(id,pending.at,pending.pitch): protected_pending.erase(id)
		processing_pending = false
	if config.music.has(music_id) and bool(config.music[music_id].get("placeholder",false)):
		var entry: Dictionary = config.music[music_id]
		var notes: Array = config.placeholder_music_sequence
		var note: int = floori(music_clock*float(entry.bpm)/60.0)%notes.size()
		var target_pitch := float(entry.pitch)*float(notes[note])
		music[music_slot].pitch_scale = lerpf(music[music_slot].pitch_scale,target_pitch,minf(1.0,dt/float(config.music_note_glide_seconds)))
	for voice in pool:
		if voice.playing and bool(voice.get_meta("follow",false)): voice.position = listener
	var target := float(config.duck_db) if not ducks.is_empty() and phase not in ["levelup","pause"] else 0.0
	var seconds := float(config.duck_in_seconds) if target<duck_offset else float(config.duck_out_seconds)
	duck_offset = move_toward(duck_offset,target,absf(float(config.duck_db))*dt/seconds)
	if ending_clock>=0:
		ending_clock -= dt
		if ending_clock<float(config.end_music_fade_seconds): music[music_slot].volume_db = linear_to_db(maxf(0.0001,ending_clock/float(config.end_music_fade_seconds)))
		if ending_clock<0: music[music_slot].stop()
	_apply_mix()
	peak_voices = maxi(peak_voices,voice_count())

func report() -> Dictionary:
	return {"master_peak_db":AudioServer.get_bus_peak_volume_left_db(0,0),"output_device":AudioServer.output_device,"mix_rate":AudioServer.get_mix_rate(),"sounds_loaded":config.sounds.size(),"waveform_count":config.presets.size()*4,"peak_voices":peak_voices,"hard_cap":config.hard_cap,"played":played.duplicate(),"protected_pending":protected_pending.size(),"dropped":dropped,"backgrounded":backgrounded,"music":music_id,"phase":phase,"cutoff_hz":filter.cutoff_hz,"placeholder_only":true}
