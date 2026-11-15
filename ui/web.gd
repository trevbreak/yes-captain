class_name Web
extends RefCounted
## Things that differ between the browser build and the desktop build, plus the few settings a player keeps.

const SETTINGS: String = "user://settings.cfg"
static var _cfg: ConfigFile = null

static func on() -> bool:
	return OS.has_feature("web")

static func js(code: String) -> Variant:
	return JavaScriptBridge.eval(code, true) if on() else null

static func server_url() -> String:
	## where the game server lives: next to the page, at /ws (or ?server=ws://... while developing)
	if not on():
		return ""
	var forced: String = str(js("new URLSearchParams(location.search).get('server') || ''"))
	if forced.begins_with("ws://") or forced.begins_with("wss://"):
		return forced
	return str(js("(location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '/ws'"))

static func room_param() -> String:
	if not on():
		return ""
	return str(js("new URLSearchParams(location.search).get('room') || ''")).to_upper().left(8)

static func invite_link(code: String) -> String:
	if on():
		return str(js("(function(c){ var u = new URL(location.href); u.searchParams.set('room', c); return u.origin + u.pathname + u.search; })(%s)" % JSON.stringify(code)))
	return code

static func set_room_in_url(code: String) -> void:
	## keep the address bar in step, so a refresh or a copied address lands in the same crew room
	if on():
		js("(function(c){ var u = new URL(location.href); if (c) { u.searchParams.set('room', c); } else { u.searchParams.delete('room'); } history.replaceState(null, '', u.pathname + u.search); })(%s)" % JSON.stringify(code))

static func site_name() -> String:
	## the address people type, without the https:// and the trailing slash ("yescaptain.example")
	if not on():
		return ""
	return str(js("location.host"))

static func copy(text: String) -> void:
	if on():
		js("(function(t){ if (navigator.clipboard && window.isSecureContext) { navigator.clipboard.writeText(t); } else { var a = document.createElement('textarea'); a.value = t; document.body.appendChild(a); a.select(); try { document.execCommand('copy'); } catch (e) {} a.remove(); document.getElementById('canvas').focus(); } })(%s)" % JSON.stringify(text))
	else:
		DisplayServer.clipboard_set(text)

static var _ask_cb: JavaScriptObject = null
static var _ask_t: int = 0

static func native_text(le: LineEdit, title: String) -> void:
	## In the browser, clicking or tapping this box opens a real HTML text box over the game instead. Godot's own
	## boxes take typing through a hidden page element that loses anything not sent as plain key presses:
	## Android keyboards (letters never appeared), paste from a menu, autofill, dictation, some input methods.
	if UIK.touch_ui:
		le.custom_minimum_size.y = maxf(le.custom_minimum_size.y, UIK.TOUCH_MIN)
	if not on():
		return
	le.gui_input.connect(func(e: InputEvent):
		var tap: bool = (e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
			or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed)
		if not tap:
			return
		le.accept_event()
		if Time.get_ticks_msec() - _ask_t < 600:
			return    # the touch and the mouse click it turns into: one box, not two
		_ask_t = Time.get_ticks_msec()
		_ask(le, title))

static func _ask(le: LineEdit, title: String) -> void:
	var win: JavaScriptObject = JavaScriptBridge.get_interface("window")
	var cb: Callable = func(args: Array):
		if not is_instance_valid(le):
			return
		var t: String = str(args[0]) if args.size() > 0 else le.text
		if le.max_length > 0:
			t = t.left(le.max_length)
		if t != le.text:
			le.text = t
			le.caret_column = t.length()
			le.text_changed.emit(t)
	_ask_cb = JavaScriptBridge.create_callback(cb)
	if win != null and bool(js("typeof window.YCAsk === 'function'")):
		win.YCAsk(title, le.text, le.max_length, _ask_cb)
	else:
		var got: Variant = js("prompt(%s, %s)" % [JSON.stringify(title), JSON.stringify(le.text)])
		if got != null:
			cb.call([str(got)])

static func toggle_fullscreen(landscape: bool = false) -> void:
	## full screen, and on phones that allow it (Android) lock the screen sideways too
	if on():
		js("(function(l){ var d = document.documentElement; if (document.fullscreenElement) { document.exitFullscreen(); return; }" +
			" var p = d.requestFullscreen ? d.requestFullscreen({navigationUI: 'hide'}) : null;" +
			" if (p && l && screen.orientation && screen.orientation.lock) { p.then(function(){ screen.orientation.lock('landscape').catch(function(){}); }).catch(function(){}); } })(%s)" % ("true" if landscape else "false"))
	else:
		var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)

static func buzz(ms: int) -> void:
	## a little shake on phones that can (Android); everyone else ignores it
	if on() and UIK.touch_ui:
		js("navigator.vibrate && navigator.vibrate(%d)" % ms)

static func can_voice() -> bool:
	return on() and bool(js("!!(window.YCVoice && window.YCVoice.supported())"))

# ---------------------------------------------------------------- settings

static func _load() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(SETTINGS)
	return _cfg

static func setting(key: String, def: Variant) -> Variant:
	return _load().get_value("player", key, def)

static func set_setting(key: String, val: Variant) -> void:
	_load().set_value("player", key, val)
	_cfg.save(SETTINGS)
