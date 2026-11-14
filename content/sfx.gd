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
var music_player: AudioStreamPlayer
var mission_player: AudioStreamPlayer
var voice_player: AudioStreamPlayer
var _voice_req: HTTPRequest
var _voice_busy: bool = false
var _voice_queue: String = ""
var _voice_server: bool = true    # false once the server has said it cannot speak: then the browser voice
var music_on: bool = true
var _mood: String = ""

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
	streams["ring"] = _ring()
	_load_music()

func _load_music() -> void:
	## two loops: the stride piano for the menus (tools/make_music.py), the theremin matinee for missions
	## (tools/make_space_music.py). Moving between them fades one out and the other in.
	music_player = _music_track("res://assets/music/shift.wav")
	mission_player = _music_track("res://assets/music/mission.wav")

func _music_track(path: String) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	add_child(p)
	p.volume_db = -60.0
	if not ResourceLoader.exists(path) or DisplayServer.get_name() == "headless":
		return p
	var src: AudioStreamWAV = load(path)
	if src == null:
		return p
	var st: AudioStreamWAV = src.duplicate()
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = int(st.get_length() * st.mix_rate)
	p.stream = st
	return p

func music(mood: String) -> void:
	## "menu" (the piano, quiet and unhurried), "game" (the theremin), "danger" (the theremin, faster: the hull
	## is going), "off"
	if music_player == null or music_player.stream == null:
		return
	if mood == _mood:
		return
	_mood = mood
	_apply_music()

func _apply_music() -> void:
	var on: bool = music_on and enabled and _mood != "off" and _mood != ""
	var flying: bool = _mood in ["game", "danger"] and mission_player != null and mission_player.stream != null
	var want: AudioStreamPlayer = (mission_player if flying else music_player) if on else null
	var tw: Tween = null
	for p in [music_player, mission_player]:
		if p == null or p.stream == null:
			continue
		if tw == null:
			tw = create_tween().set_parallel(true)
		if p == want:
			if not p.playing:
				p.volume_db = -40.0
				p.play()
			var pitch: float = {"menu": 0.9, "game": 1.0, "danger": 1.1}.get(_mood, 1.0)
			var vol: float = {"menu": -19.0, "game": -21.0, "danger": -18.0}.get(_mood, -21.0)
			tw.tween_property(p, "pitch_scale", pitch, 0.8)
			tw.tween_property(p, "volume_db", vol, 0.8)
		elif p.playing:
			tw.tween_property(p, "volume_db", -50.0, 0.7)
			tw.chain().tween_callback(p.stop)

func set_music(on: bool) -> void:
	music_on = on
	if music_player != null and music_player.stream != null:
		_apply_music()

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
	## IGOR talks. In the browser the game's server makes the speech (one clear voice through a ring modulator,
	## the same for every player: see net/tts_server.gd). Without it, the computer's own voice at its normal pitch.
	play("chime")
	if not tts_on or not enabled or DisplayServer.get_name() == "headless":
		return
	stop_speech()
	if OS.has_feature("web") and _voice_server:
		_fetch_voice(text)
		return
	_system_voice(text)

func _fetch_voice(text: String) -> void:
	if _voice_req == null:
		_voice_req = HTTPRequest.new()
		_voice_req.timeout = 8.0
		add_child(_voice_req)
		_voice_req.request_completed.connect(_on_voice)
		voice_player = AudioStreamPlayer.new()
		add_child(voice_player)
	if _voice_busy:
		_voice_queue = text      # only the latest line matters: say it when this one arrives
		return
	_voice_busy = true
	var robot: bool = not (text.begins_with("ADMIRAL THRUPP:") or text.begins_with("MA GRISTLE:") or text.begins_with("PUDDING:"))
	var origin: String = str(JavaScriptBridge.eval("location.origin", true)) if OS.has_feature("web") else ""
	if origin == "" or origin == "null":
		_voice_busy = false
		_system_voice(text)
		return
	var err: int = _voice_req.request("%s/tts?r=%d&t=%s" % [origin, 1 if robot else 0, text.left(TtsServer.MAX_TEXT).uri_encode()])
	if err != OK:
		_voice_busy = false
		_system_voice(text)

func _on_voice(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_voice_busy = false
	var next: String = _voice_queue
	_voice_queue = ""
	if next != "":
		_fetch_voice(next)
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		if code == 404 or code == 501:
			_voice_server = false    # this server has no voice: use the browser's from now on
		return
	var st: AudioStreamWAV = TtsServer.wav_stream(body)
	if st != null and tts_on and enabled:
		voice_player.stream = st
		voice_player.volume_db = -2.0
		voice_player.play()

func _system_voice(text: String) -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return
	var voices: PackedStringArray = DisplayServer.tts_get_voices_for_language("en")
	if voices.is_empty():
		return
	if tts_voice == "":
		# a robot-ish voice if the computer has one, at its natural pitch so the words stay clear
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
	DisplayServer.tts_speak(text, tts_voice, 70, 1.0, 1.0)

func stop_speech() -> void:
	if voice_player != null:
		voice_player.stop()
	if DisplayServer.get_name() != "headless" and DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		DisplayServer.tts_stop()

func is_speaking() -> bool:
	if _voice_busy or (voice_player != null and voice_player.playing):
		return true
	if DisplayServer.get_name() == "headless" or not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return false
	return DisplayServer.tts_is_speaking()

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

func _ring() -> AudioStreamWAV:
	## an old telephone: two short trills
	var n: int = int(RATE * 0.9)
	var s: PackedFloat32Array = PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t: float = float(i) / RATE
		var on: bool = t < 0.32 or (t > 0.45 and t < 0.77)
		var trem: float = 0.5 + 0.5 * sin(TAU * 22.0 * t)
		s[i] = (sin(TAU * 1250.0 * t) + sin(TAU * 1480.0 * t)) * 0.16 * trem if on else 0.0
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
