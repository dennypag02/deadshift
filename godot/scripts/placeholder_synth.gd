extends RefCounted
## In-house renderer for the documented jsfxr oscillator/envelope parameter subset.
## No downloaded/generative models or sampled recordings; independent seeded noise.
static func render(p: Dictionary, seed_value: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rate := 44100
	var attack := maxi(1,roundi(pow(float(p.get("p_env_attack",0.0)),2)*100000))
	var sustain := maxi(1,roundi(pow(float(p.get("p_env_sustain",0.12)),2)*100000))
	var decay := maxi(1,roundi(pow(float(p.get("p_env_decay",0.18)),2)*100000))
	var samples := attack+sustain+decay
	var pcm := PackedByteArray()
	pcm.resize(samples*2)
	var period := 100.0/(pow(float(p.get("p_base_freq",0.3)),2)+0.001)
	var multiplier := 1.0-pow(float(p.get("p_freq_ramp",0.0)),3)*0.01
	var phase := 0.0
	var shape := int(p.get("wave_type",2))
	var values := PackedFloat32Array()
	values.resize(samples)
	var peak := 0.0001
	var noise := 0.0
	for i in range(samples):
		period = clampf(period*multiplier,8.0,100000.0)
		var sum := 0.0
		for j in range(8):
			phase += 1.0
			if phase>=period:
				phase = fmod(phase,period)
				noise = rng.randf_range(-1,1)
			var position := phase/period
			match shape:
				0: sum += 0.5 if position<0.5-float(p.get("p_duty",0))*0.5 else -0.5
				1: sum += 2.0*position-1.0
				2: sum += sin(position*TAU)
				3: sum += noise
		var env: float = float(i)/attack if i<attack else (1.0 if i<attack+sustain else 1.0-float(i-attack-sustain)/decay)
		# Two-ms click guard is normalization/trim preparation, not leading silence.
		var edge := minf(1.0,minf(float(i+1)/88.0,float(samples-i)/88.0))
		values[i] = sum/8.0*env*edge
		peak = maxf(peak,absf(values[i]))
	var gain := db_to_linear(-1.0)/peak
	for i in range(samples): pcm.encode_s16(i*2,roundi(clampf(values[i]*gain,-1,1)*32767.0))
	var result := AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate = rate
	result.stereo = false
	result.data = pcm
	return result
