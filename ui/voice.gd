class_name Voice
extends RefCounted
## Voice chat for a crew room (browser build only). The talking is done by deploy/voice.js in the page;
## this is the game's side of it: switch it on and off with the room's setting, pass handshakes through
## Net, and report who is talking so the screen can show it.

static var active: bool = false       # we asked the page to start
static var muted: bool = false
static var error: String = ""
static var connected: Dictionary = {} # peer id -> bool
static var levels: Dictionary = {}    # peer id -> 0..1 (how loud right now); our own is under Net.my_id
static var names: Dictionary = {}     # peer id -> name
static var _cb: JavaScriptObject = null
static var _poll_t: float = 0.0
static var _peers_sig: String = ""

static func available() -> bool:
	return Web.on() and bool(Web.js("!!window.YCVoice"))

static func sync(lobby: Dictionary) -> void:
	## called with every lobby update: voice follows the room's switch
	names = {}
	var ids: Array = []
	var peers: Dictionary = lobby.get("peers", {})
	for pid in peers.keys():
		if not bool(peers[pid].get("gone", false)):
			names[int(pid)] = str(peers[pid].name)
			ids.append(int(pid))
	var want: bool = bool(lobby.get("voice", false)) and str(lobby.get("room", {}).get("code", "")) != ""
	if not available():
		error = "Voice chat only works in the browser." if want else ""
		return
	if want and not active:
		active = true
		if _cb == null:
			_cb = JavaScriptBridge.create_callback(_on_js_send)
			JavaScriptBridge.get_interface("YCVoice").onSend = _cb
		Web.js("window.YCVoice.setMuted(%s); window.YCVoice.start(%d);" % ["true" if muted else "false", Net.my_id])
		_peers_sig = ""
	elif not want and active:
		stop()
	if active:
		var sig: String = JSON.stringify(ids)
		if sig != _peers_sig:
			_peers_sig = sig
			Web.js("window.YCVoice.setPeers(%s)" % JSON.stringify(sig))

static func stop() -> void:
	if active and available():
		Web.js("window.YCVoice.stop()")
	active = false
	connected = {}
	levels = {}
	error = ""
	_peers_sig = ""

static func set_muted(m: bool) -> void:
	muted = m
	if available():
		Web.js("window.YCVoice.setMuted(%s)" % ("true" if m else "false"))

static func _on_js_send(a: Array) -> void:
	if a.size() >= 2:
		Net.send("rtc", {"to": int(a[0]), "data": {"j": str(a[1])}})

static func on_event(d: Dictionary) -> void:
	if not active or not available():
		return
	match str(d.get("t", "")):
		"rtc":
			var j: String = str(d.get("data", {}).get("j", ""))
			Web.js("window.YCVoice.signal(%d, %s)" % [int(d.get("from", 0)), JSON.stringify(j)])
		"rtc_left":
			Web.js("window.YCVoice.drop(%d)" % int(d.get("peer", 0)))

static func poll(dt: float) -> void:
	## a few times a second: ask the page who is connected and who is talking
	if not active:
		return
	_poll_t += dt
	if _poll_t < 0.12:
		return
	_poll_t = 0.0
	var st: Variant = JSON.parse_string(str(Web.js("window.YCVoice.state()")))
	if not (st is Dictionary):
		return
	error = str(st.get("error", ""))
	# the page may still be waiting for the microphone: re-send the crew once it is on
	if bool(st.get("on", false)) and _peers_sig != "" and connected.is_empty() and (st.get("peers", {}) as Dictionary).is_empty():
		Web.js("window.YCVoice.setPeers(%s)" % JSON.stringify(_peers_sig))
	connected = {}
	levels = {Net.my_id: float(st.get("me", 0.0))}
	var ps: Dictionary = st.get("peers", {})
	for k in ps.keys():
		connected[int(k)] = bool(ps[k].get("c", false))
		levels[int(k)] = float(ps[k].get("l", 0.0))

static func talking(pid: int) -> bool:
	return float(levels.get(pid, 0.0)) > 0.12

class Bar extends HBoxContainer:
	## a strip for the top of the screen: a mute button, and a dot per crew member that lights up when they talk
	var mute_btn: Button
	var dots: HBoxContainer
	var note: Label
	var _sig: String = ""

	func _ready() -> void:
		add_theme_constant_override("separation", 6)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mute_btn = UIK.toggle("Mic", "red", func(on: bool):
			Voice.set_muted(on)
			mute_btn.text = "MUTED" if on else "MIC ON", "speaker", 16)
		mute_btn.text = "MIC ON"
		mute_btn.tooltip_text = "Mute or unmute your microphone (M)"
		add_child(mute_btn)
		dots = UIK.hbox(2)
		add_child(dots)
		note = UIK.label("", 16, UIK.c("red"))
		add_child(note)
		visible = false

	func _process(_dt: float) -> void:
		var show: bool = Voice.active or Voice.error != ""
		if show != visible:
			visible = show
		if not show:
			return
		note.text = Voice.error
		mute_btn.visible = Voice.error == ""
		mute_btn.set_pressed_no_signal(Voice.muted)
		mute_btn.text = "MUTED" if Voice.muted else "MIC ON"
		var ids: Array = Voice.names.keys()
		ids.sort()
		var sig: String = str(ids)
		if sig != _sig:
			_sig = sig
			for c in dots.get_children():
				c.queue_free()
			for pid in ids:
				var d: Dot = Dot.new()
				d.pid = int(pid)
				dots.add_child(d)

	class Dot extends Control:
		var pid: int = 0
		var _lvl: float = 0.0

		func _ready() -> void:
			custom_minimum_size = Vector2(30, 30)
			mouse_filter = Control.MOUSE_FILTER_PASS

		func _process(dt: float) -> void:
			var target: float = float(Voice.levels.get(pid, 0.0))
			_lvl = maxf(target, _lvl - dt * 3.0)
			tooltip_text = "%s%s" % [str(Voice.names.get(pid, "?")), "" if pid == Net.my_id or bool(Voice.connected.get(pid, false)) else " (connecting...)"]
			queue_redraw()

		func _draw() -> void:
			var c: Vector2 = size / 2.0
			var linked: bool = pid == Net.my_id or bool(Voice.connected.get(pid, false))
			var r: float = 9.0 + 4.0 * _lvl
			draw_circle(c, r + 2.5, UIK.ink())
			draw_circle(c, r, UIK.c("green") if (linked and _lvl > 0.12) else (UIK.c("cream") if linked else UIK.c("grey2")))
			var nm: String = str(Voice.names.get(pid, "?")).left(1).to_upper()
			var f: Font = UIK.font("head")
			var ts: Vector2 = f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
			draw_string(f, c + Vector2(-ts.x / 2.0, 5.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIK.ink())
