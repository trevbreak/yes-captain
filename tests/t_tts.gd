extends SceneTree
## IGOR's voice service (net/tts_server.gd): WAVs in and out, the robot effect, rubbish text, and a real HTTP
## request answered through a stand-in speech engine (it copies a WAV this test writes). NONET=1 skips the HTTP part.

var fails: int = 0

func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		fails += 1

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# a WAV round trip
	var tone: PackedFloat32Array = PackedFloat32Array()
	for i in 22050:
		tone.append(0.5 * sin(TAU * 440.0 * i / 22050.0))
	var wav: PackedByteArray = TtsServer.write_wav(tone, 22050)
	var back: Dictionary = TtsServer.read_wav(wav)
	_check(not back.is_empty() and int(back.rate) == 22050 and (back.samples as PackedFloat32Array).size() == 22050, "a WAV reads back as it was written")
	_check(TtsServer.read_wav("not a wav at all, honest".to_utf8_buffer()).is_empty(), "rubbish isn't taken for a WAV")
	var st: AudioStreamWAV = TtsServer.wav_stream(wav)
	_check(st != null and st.mix_rate == 22050 and st.data.size() == 44100, "a WAV becomes something the game can play")
	var robot: PackedFloat32Array = TtsServer.normalise(TtsServer.robotize(tone.duplicate(), 22050))
	var peak: float = 0.0
	var differs: bool = false
	for i in robot.size():
		peak = maxf(peak, absf(robot[i]))
		if absf(robot[i] - tone[i]) > 0.05:
			differs = true
	_check(differs and peak <= 0.91 and peak > 0.8, "the robot effect changes the sound and keeps it at a sane level")
	_check(TtsServer.clean("  $(rm -rf /); `id` | <b>hi</b>  ") == "(rm -rf /) id  bhi/b", "shell and markup characters are dropped")
	_check(TtsServer.clean("x".repeat(500)).length() == TtsServer.MAX_TEXT, "long lines are cut short")
	if OS.get_environment("NONET") != "":
		print("TTS %s (HTTP part skipped)" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
		quit(1 if fails > 0 else 0)
		return
	# the service, with a stand-in engine that copies a WAV
	var dir: String = OS.get_user_data_dir().path_join("tts_test")
	DirAccess.make_dir_recursive_absolute(dir)
	for fn in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(fn))
	var fixture: String = dir.path_join("fixture.wav.src")
	var f: FileAccess = FileAccess.open(fixture, FileAccess.WRITE)
	f.store_buffer(wav)
	f.close()
	OS.set_environment("YC_TTS_CMD", "cp '%s' {out}" % fixture)
	OS.set_environment("YC_TTS_CACHE", dir)
	var srv: TtsServer = TtsServer.new()
	root.add_child(srv)
	_check(srv.start(7794) == OK, "the service starts")
	var r1: Array = await _fetch(srv, "/tts?r=1&t=Hello%20Captain")
	_check(int(r1[0]) == 200 and TtsServer.read_wav(r1[1]).size() == 2, "a line comes back as a WAV")
	var r2: Array = await _fetch(srv, "/tts?r=1&t=Hello%20Captain")
	_check(int(r2[0]) == 200 and r2[1] == r1[1], "the same line again comes from the cache")
	var r3: Array = await _fetch(srv, "/tts?t=")
	_check(int(r3[0]) == 400, "an empty line is refused")
	var r4: Array = await _fetch(srv, "/admin")
	_check(int(r4[0]) == 404, "anything but /tts is not found")
	srv.queue_free()
	print("TTS %s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)

func _fetch(_srv: TtsServer, path: String) -> Array:
	## [status, body]
	var peer: StreamPeerTCP = StreamPeerTCP.new()
	peer.connect_to_host("127.0.0.1", 7794)
	var got: PackedByteArray = PackedByteArray()
	var sent: bool = false
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8000:
		await process_frame
		peer.poll()
		var st: int = peer.get_status()
		if st == StreamPeerTCP.STATUS_CONNECTED:
			if not sent:
				peer.put_data(("GET %s HTTP/1.1\r\nHost: x\r\n\r\n" % path).to_utf8_buffer())
				sent = true
			var n: int = peer.get_available_bytes()
			if n > 0:
				got.append_array(peer.get_partial_data(n)[1])
		elif sent and (st == StreamPeerTCP.STATUS_NONE or st == StreamPeerTCP.STATUS_ERROR):
			break
	var text: String = got.slice(0, mini(got.size(), 300)).get_string_from_ascii()
	var code: int = int(text.get_slice(" ", 1)) if text.begins_with("HTTP/") else 0
	var split: int = -1
	for i in got.size() - 3:
		if got[i] == 13 and got[i + 1] == 10 and got[i + 2] == 13 and got[i + 3] == 10:
			split = i + 4
			break
	return [code, got.slice(split) if split >= 0 else PackedByteArray()]
