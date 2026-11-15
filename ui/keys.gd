class_name Keys
extends RefCounted
## Rebindable keys. Every station keeps thinking in its default keys (KEY_A for "turn left"); a player's own
## bindings are translated back to those defaults on the way in, so a remap never touches station code.
## Saved per player (Web.setting "keys"): {station: {default keycode: chosen keycode}}.

## each station's actions, by default key: [default, what it does]
const ACTIONS: Dictionary = {
	"helm": [[KEY_A, "Turn left"], [KEY_D, "Turn right"], [KEY_R, "Barrel roll"]],
	"shields": [[KEY_Q, "Shield anticlockwise"], [KEY_E, "Shield clockwise"], [KEY_P, "Pet Pudding"], [KEY_C, "Shake the tin"], [KEY_N, "Snack"]],
	"engines": [[KEY_W, "Throttle up"], [KEY_S, "Throttle down"], [KEY_X, "All stop"], [KEY_B, "Boost"]],
	"weapons": [[KEY_A, "Turret left"], [KEY_D, "Turret right"], [KEY_SPACE, "Fire"], [KEY_L, "Load torpedo"], [KEY_T, "Fire torpedo"]],
	"sensors": [[KEY_SPACE, "Scan"], [KEY_TAB, "Next blip"], [KEY_T, "Tractor beam"], [KEY_Q, "Tune down"], [KEY_E, "Tune up"]],
	"engineer": [[KEY_R, "Repair"]],
}

## keys the whole game uses (menu, flip, mute, seat numbers): not available to bind
const RESERVED: Array = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_ESCAPE, KEY_QUOTELEFT, KEY_F, KEY_M]

static var _map: Dictionary = {}
static var _loaded: bool = false

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var raw: Variant = Web.setting("keys", {})
	_map = {}
	if raw is Dictionary:
		for st in (raw as Dictionary).keys():
			if ACTIONS.has(str(st)) and raw[st] is Dictionary:
				var m: Dictionary = {}
				for d in (raw[st] as Dictionary).keys():
					m[int(d)] = int(raw[st][d])
				_map[str(st)] = m

static func translate(seat: String, k: Key) -> Key:
	## the default key this press stands for at this station (KEY_NONE: a default that's been moved elsewhere)
	_load()
	var m: Dictionary = _map.get(seat, {})
	if m.is_empty():
		return k
	for d in m.keys():
		if int(m[d]) == int(k):
			return int(d) as Key
	if m.has(int(k)):
		return KEY_NONE
	return k

static func of(seat: String, def: Key) -> Key:
	_load()
	return int(_map.get(seat, {}).get(int(def), int(def))) as Key

static func hint(seat: String, def: Key) -> String:
	## what to print on a button: "Space", "R"...
	return OS.get_keycode_string(of(seat, def))

static func bind(seat: String, def: Key, k: Key) -> void:
	_load()
	var m: Dictionary = _map.get(seat, {})
	if int(k) == int(def):
		m.erase(int(def))
	else:
		m[int(def)] = int(k)
	_map[seat] = m
	_save()

static func reset() -> void:
	_map = {}
	_loaded = true
	_save()

static func _save() -> void:
	var out: Dictionary = {}
	for st in _map.keys():
		var m: Dictionary = {}
		for d in (_map[st] as Dictionary).keys():
			m[str(d)] = int(_map[st][d])
		if not m.is_empty():
			out[st] = m
	Web.set_setting("keys", out)
