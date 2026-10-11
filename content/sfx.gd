extends Node
## Procedural sound effects (autoload "Sfx"): chunky clicks, clacks and a flat "bing-bong" IGOR chime.
## No audio files: everything is synthesized once at startup.

const RATE: int = 22050

var enabled: bool = true
var volume_db: float = -6.0
var streams: Dictionary = {}
var players: Array = []
var next_player: int = 0
var tts_on: bool = true
var tts_voice: String = ""

func _ready() -> void:
	for i in 10:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	streams["click"] = _tone([1300.0], 0.035, 0.5, 40.0)
	streams["blip"] = _tone([880.0], 0.07, 0.4, 25.0)
	streams["ding"] = _tone([1320.0, 1980.0], 0.25, 0.4, 9.0)
	streams["clack"] = _noise(0.09, 0.6, 38.0, 0.35)
	streams["clunk"] = _tone([95.0, 140.0], 0.18, 0.8, 14.0)
	streams["bonk"] = _tone([180.0, 120.0], 0.22, 0.8, 11.0)
	streams["boom"] = _noise(0.55, 0.9, 5.0, 0.12)
	streams["zap"] = _noise(0.25, 0.6, 9.0, 0.9)
	streams["alarm"] = _alarm()
	streams["chime"] = _chime()
	streams["whoosh"] = _sweep(200.0, 1200.0, 0.5, 0.5)
	streams["powerdown"] = _sweep(700.0, 60.0, 0.9, 0.7)
	streams["pop"] = _sweep(300.0, 900.0, 0.1, 0.5)

func play(name: String, pitch: float = 1.0, vol: float = 0.0) -> void:
	if not enabled or not streams.has(name) or players.is_empty():
		return
	var p: AudioStreamPlayer = players[next_player]
	next_player = (next_player + 1) % players.size()
	p.stream = streams[name]
	p.pitch_scale = pitch
	p.volume_db = volume_db + vol
	p.play()

func speak(text: String) -> void:
	## IGOR talks. System TTS if available (slow, low, flat), otherwise the chime only.
	play("chime")
	if not tts_on or not enabled or not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return
	if DisplayServer.get_name() == "headless":
		return
	var voices: PackedStringArray = DisplayServer.tts_get_voices_for_language("en")
	if voices.is_empty():
		return
	if tts_voice == "":
		# IGOR prefers a robot-ish voice: Fred if the system has it, then a few flat ones
		tts_voice = voices[0]
		var found: bool = false
		for want in ["fred", "ralph", "daniel", "alex", "lee"]:
			for v in voices:
				if want in str(v).to_lower():
					tts_voice = v
					found = true
					break
			if found:
				break
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(text, tts_voice, 60, 0.55, 0.85)

# ---------------------------------------------------------------- synthesis

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v: int = clampi(int(samples[i] * 32000.0), -32768, 32767)
		bytes.encode_s16(i * 2, v)
	w.data = bytes
	return w

func _tone(freqs: Array, dur: float, vol: float, decay: float) -> AudioStreamWAV:
	var n: int = int(RATE * dur)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t: float = float(i) / RATE
		var v: float = 0.0
		for f in freqs:
			v += sin(TAU * float(f) * t)
		v /= float(freqs.size())
		s[i] = v * vol * exp(-decay * t)
	return _wav(s)

func _noise(dur: float, vol: float, decay: float, tone: float) -> AudioStreamWAV:
	var n: int = int(RATE * dur)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var lp: float = 0.0
	for i in n:
		var t: float = float(i) / RATE
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), tone)
		s[i] = lp * vol * exp(-decay * t)
	return _wav(s)

func _alarm() -> AudioStreamWAV:
	var n: int = int(RATE * 0.6)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t: float = float(i) / RATE
		var f: float = 620.0 if int(t * 5.0) % 2 == 0 else 820.0
		s[i] = (1.0 if sin(TAU * f * t) > 0.0 else -1.0) * 0.25 * minf(1.0, (0.6 - t) * 6.0)
	return _wav(s)

func _chime() -> AudioStreamWAV:
	## flat "bing-bong"
	var n: int = int(RATE * 0.9)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t: float = float(i) / RATE
		var v: float = 0.0
		if t < 0.4:
			v = sin(TAU * 784.0 * t) * exp(-6.0 * t)
		if t >= 0.35:
			var t2: float = t - 0.35
			v += sin(TAU * 622.0 * t2) * exp(-5.0 * t2)
		s[i] = v * 0.35
	return _wav(s)

func _sweep(f0: float, f1: float, dur: float, vol: float) -> AudioStreamWAV:
	var n: int = int(RATE * dur)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	var ph: float = 0.0
	for i in n:
		var t: float = float(i) / RATE
		var f: float = lerpf(f0, f1, t / dur)
		ph += TAU * f / RATE
		s[i] = sin(ph) * vol * (1.0 - t / dur)
	return _wav(s)
