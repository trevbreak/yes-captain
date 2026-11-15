class_name TtsServer
extends Node
## IGOR's voice, made on the server so every player hears the same IGOR whatever computer they're on.
##
## A tiny HTTP service on 127.0.0.1 (Caddy passes /tts to it): GET /tts?r=1&t=<text> answers with a WAV.
## The words come from a speech engine (Piper, with a clear British voice, in the container); r=1 then puts
## them through a ring modulator and a short echo, the old trick that makes a clear voice sound like a robot
## without blurring the words. Every line is cached, in memory and on disk, so a line is only ever made once.
##
## The engine is a command: YC_TTS_CMD, with {in} (a text file) and {out} (the WAV to write). Both are paths
## this server chooses; a player's words only ever go into the text file, never into the command.

const MAX_TEXT: int = 240
const PORT: int = 7778
const DEFAULT_CMD: String = "LD_LIBRARY_PATH=/opt/piper /opt/piper/piper --model /opt/piper/voice.onnx --output_file {out} < {in} > /dev/null 2>&1"
const MAX_WAITING: int = 24
const MEMORY_LINES: int = 400
const DISK_LINES: int = 3000

var cmd: String = ""
var cache_dir: String = ""
var tcp: TCPServer = TCPServer.new()
var conns: Array = []             # [{peer, buf, t, key}]
var memory: Dictionary = {}       # key -> wav bytes
var _order: Array = []            # keys, oldest first
var _jobs: Array = []             # [{key, text, robot}] waiting for the worker
var _making: Dictionary = {}      # key -> true while queued or being made
var _done: Dictionary = {}        # key -> wav bytes (or empty on failure), handed back by the worker
var _mutex: Mutex = Mutex.new()
var _sem: Semaphore = Semaphore.new()
var _thread: Thread = Thread.new()
var _quit: bool = false
var _n: int = 0

static func available() -> bool:
	var c: String = OS.get_environment("YC_TTS_CMD")
	if c == "off":
		return false
	return c != "" or FileAccess.file_exists("/opt/piper/piper")

func start(port: int = PORT) -> Error:
	cmd = OS.get_environment("YC_TTS_CMD")
	if cmd == "":
		cmd = DEFAULT_CMD
	cache_dir = OS.get_environment("YC_TTS_CACHE")
	if cache_dir == "":
		cache_dir = OS.get_user_data_dir().path_join("tts")
	DirAccess.make_dir_recursive_absolute(cache_dir)
	# keep the disk cache from growing without end: past DISK_LINES lines, start it again
	var files: PackedStringArray = DirAccess.get_files_at(cache_dir)
	if files.size() > DISK_LINES:
		for fn in files:
			DirAccess.remove_absolute(cache_dir.path_join(fn))
	var err: Error = tcp.listen(port, "127.0.0.1")
	if err == OK:
		_thread.start(_work)
	print("TTS on 127.0.0.1:%d (err %d), cache %s" % [port, err, cache_dir])
	return err

func _exit_tree() -> void:
	_quit = true
	_sem.post()
	if _thread.is_started():
		_thread.wait_to_finish()
	tcp.stop()

# ---------------------------------------------------------------- http

func _process(_dt: float) -> void:
	while tcp.is_connection_available():
		var peer: StreamPeerTCP = tcp.take_connection()
		conns.append({"peer": peer, "buf": PackedByteArray(), "t": Time.get_ticks_msec(), "key": ""})
	for c in conns.duplicate():
		var peer: StreamPeerTCP = c.peer
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED or Time.get_ticks_msec() - int(c.t) > 20000:
			conns.erase(c)
			continue
		if str(c.key) == "":
			var n: int = peer.get_available_bytes()
			var buf: PackedByteArray = c.buf
			if n > 0:
				var got: Array = peer.get_partial_data(mini(n, 4096))
				buf.append_array(got[1])
				c.buf = buf     # a byte array taken from a dictionary is a copy: put it back
			var head: String = buf.get_string_from_utf8()
			if buf.size() > 8192:
				_reply(c, 413, "text/plain", "too long".to_utf8_buffer())
			elif "\r\n\r\n" in head:
				_request(c, head.get_slice("\r\n", 0))
		else:
			var key: String = c.key
			if memory.has(key):
				_reply(c, 200, "audio/wav", memory[key])
				continue
			_mutex.lock()
			var ready: bool = _done.has(key)
			var wav: PackedByteArray = _done.get(key, PackedByteArray())
			if ready:
				_done.erase(key)
				_making.erase(key)
			_mutex.unlock()
			if ready:
				if wav.is_empty():
					_reply(c, 500, "text/plain", "IGOR lost his voice".to_utf8_buffer())
				else:
					_remember(key, wav)
					_reply(c, 200, "audio/wav", wav)

func _request(c: Dictionary, line: String) -> void:
	var parts: PackedStringArray = line.split(" ")
	if parts.size() < 2 or parts[0] != "GET" or not parts[1].begins_with("/tts"):
		_reply(c, 404, "text/plain", "no".to_utf8_buffer())
		return
	var q: Dictionary = {}
	var query: String = parts[1].get_slice("?", 1) if "?" in parts[1] else ""
	for kv in query.split("&"):
		if "=" in kv:
			q[kv.get_slice("=", 0)] = kv.get_slice("=", 1).replace("+", " ").uri_decode()
	var text: String = clean(str(q.get("t", "")))
	if text == "":
		_reply(c, 400, "text/plain", "nothing to say".to_utf8_buffer())
		return
	var robot: bool = str(q.get("r", "1")) != "0"
	var key: String = ("%d|%s" % [1 if robot else 0, text]).sha256_text()
	c.key = key
	if memory.has(key):
		return
	var path: String = cache_dir.path_join(key + ".wav")
	if FileAccess.file_exists(path):
		_remember(key, FileAccess.get_file_as_bytes(path))
		return
	_mutex.lock()
	var busy: bool = _making.has(key)
	var full: bool = _jobs.size() >= MAX_WAITING
	if not busy and not full:
		_making[key] = true
		_jobs.append({"key": key, "text": text, "robot": robot})
	_mutex.unlock()
	if full and not busy:
		_reply(c, 503, "text/plain", "IGOR is busy talking".to_utf8_buffer())
	elif not busy:
		_sem.post()

func _reply(c: Dictionary, code: int, ctype: String, body: PackedByteArray) -> void:
	var peer: StreamPeerTCP = c.peer
	var status: String = {200: "OK", 400: "Bad Request", 404: "Not Found", 413: "Too Large", 500: "Server Error", 503: "Busy"}.get(code, "OK")
	var head: String = "HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: %s\r\nConnection: close\r\n\r\n" % [
		code, status, ctype, body.size(), "public, max-age=604800" if code == 200 else "no-store"]
	peer.put_data(head.to_utf8_buffer())
	peer.put_data(body)
	peer.disconnect_from_host()
	conns.erase(c)

func _remember(key: String, wav: PackedByteArray) -> void:
	if memory.has(key):
		return
	memory[key] = wav
	_order.append(key)
	while _order.size() > MEMORY_LINES:
		memory.erase(_order.pop_front())

static func clean(t: String) -> String:
	## plain words only, and not too many of them
	var out: String = ""
	for ch in t:
		var code: int = ch.unicode_at(0)
		if code >= 32 and code != 127 and not (ch in "<>{}[]\\`$|;&"):
			out += ch
	return out.strip_edges().left(MAX_TEXT)

# ---------------------------------------------------------------- the worker: one line at a time

func _work() -> void:
	while true:
		_sem.wait()
		if _quit:
			return
		_mutex.lock()
		var job: Dictionary = _jobs.pop_front() if not _jobs.is_empty() else {}
		_mutex.unlock()
		if job.is_empty():
			continue
		var wav: PackedByteArray = _make(str(job.text), bool(job.robot))
		if not wav.is_empty():
			var f: FileAccess = FileAccess.open(cache_dir.path_join(str(job.key) + ".wav"), FileAccess.WRITE)
			if f != null:
				f.store_buffer(wav)
				f.close()
		_mutex.lock()
		_done[job.key] = wav
		_mutex.unlock()

func _make(text: String, robot: bool) -> PackedByteArray:
	_n += 1
	var tin: String = cache_dir.path_join("job%d.txt" % (_n % 4))
	var tout: String = cache_dir.path_join("job%d.wav" % (_n % 4))
	var f: FileAccess = FileAccess.open(tin, FileAccess.WRITE)
	if f == null:
		return PackedByteArray()
	f.store_string(text + "\n")
	f.close()
	if FileAccess.file_exists(tout):
		DirAccess.remove_absolute(tout)
	OS.execute("sh", ["-c", cmd.replace("{in}", "'%s'" % tin).replace("{out}", "'%s'" % tout)])
	if not FileAccess.file_exists(tout):
		return PackedByteArray()
	var raw: PackedByteArray = FileAccess.get_file_as_bytes(tout)
	var pcm: Dictionary = read_wav(raw)
	if pcm.is_empty():
		return PackedByteArray()
	var samples: PackedFloat32Array = pcm.samples
	if robot:
		samples = robotize(samples, int(pcm.rate))
	return write_wav(normalise(samples), int(pcm.rate))

# ---------------------------------------------------------------- sound

static func read_wav(b: PackedByteArray) -> Dictionary:
	## {rate, samples} from a 16-bit PCM WAV (stereo is mixed down); {} if it isn't one
	if b.size() < 44 or b.slice(0, 4).get_string_from_ascii() != "RIFF" or b.slice(8, 12).get_string_from_ascii() != "WAVE":
		return {}
	var i: int = 12
	var rate: int = 22050
	var channels: int = 1
	var bits: int = 16
	while i + 8 <= b.size():
		var id: String = b.slice(i, i + 4).get_string_from_ascii()
		var size: int = b.decode_u32(i + 4)
		if id == "fmt ":
			channels = b.decode_u16(i + 10)
			rate = b.decode_u32(i + 12)
			bits = b.decode_u16(i + 22)
		elif id == "data":
			if bits != 16:
				return {}
			var end: int = mini(b.size(), i + 8 + size)
			var out: PackedFloat32Array = PackedFloat32Array()
			out.resize((end - i - 8) / (2 * channels))
			var k: int = 0
			var j: int = i + 8
			while j + 2 * channels <= end and k < out.size():
				var v: float = 0.0
				for ch in channels:
					v += b.decode_s16(j + ch * 2) / 32768.0
				out[k] = v / channels
				k += 1
				j += 2 * channels
			return {"rate": rate, "samples": out}
		i += 8 + size + (size % 2)
	return {}

static func robotize(x: PackedFloat32Array, rate: int) -> PackedFloat32Array:
	## a ring modulator (the voice multiplied by a low hum) mixed with the clear voice, then a short metal echo
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(x.size())
	var w: float = TAU * 38.0 / float(rate)
	for i in x.size():
		out[i] = x[i] * (0.45 + sin(w * i))
	var d: int = int(0.018 * rate)
	for i in range(d, out.size()):
		out[i] += out[i - d] * 0.25
	return out

static func normalise(x: PackedFloat32Array) -> PackedFloat32Array:
	var peak: float = 0.0001
	for v in x:
		peak = maxf(peak, absf(v))
	var k: float = 0.9 / peak
	for i in x.size():
		x[i] *= k
	return x

static func write_wav(x: PackedFloat32Array, rate: int) -> PackedByteArray:
	var data: PackedByteArray = PackedByteArray()
	data.resize(x.size() * 2)
	for i in x.size():
		data.encode_s16(i * 2, int(clampf(x[i], -1.0, 1.0) * 32767.0))
	var h: PackedByteArray = PackedByteArray()
	h.resize(44)
	h.encode_u32(0, 0x46464952)      # RIFF
	h.encode_u32(4, 36 + data.size())
	h.encode_u32(8, 0x45564157)      # WAVE
	h.encode_u32(12, 0x20746d66)     # "fmt "
	h.encode_u32(16, 16)
	h.encode_u16(20, 1)
	h.encode_u16(22, 1)
	h.encode_u32(24, rate)
	h.encode_u32(28, rate * 2)
	h.encode_u16(32, 2)
	h.encode_u16(34, 16)
	h.encode_u32(36, 0x61746164)     # data
	h.encode_u32(40, data.size())
	h.append_array(data)
	return h

static func wav_stream(b: PackedByteArray) -> AudioStreamWAV:
	## a WAV the server sent, ready to play
	var w: Dictionary = read_wav(b)
	if w.is_empty():
		return null
	var x: PackedFloat32Array = w.samples
	var data: PackedByteArray = PackedByteArray()
	data.resize(x.size() * 2)
	for i in x.size():
		data.encode_s16(i * 2, int(clampf(x[i], -1.0, 1.0) * 32767.0))
	var st: AudioStreamWAV = AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = int(w.rate)
	st.stereo = false
	st.data = data
	return st
