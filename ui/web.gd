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

static func copy(text: String) -> void:
	if on():
		js("(function(t){ if (navigator.clipboard && window.isSecureContext) { navigator.clipboard.writeText(t); } else { var a = document.createElement('textarea'); a.value = t; document.body.appendChild(a); a.select(); try { document.execCommand('copy'); } catch (e) {} a.remove(); document.getElementById('canvas').focus(); } })(%s)" % JSON.stringify(text))
	else:
		DisplayServer.clipboard_set(text)

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
