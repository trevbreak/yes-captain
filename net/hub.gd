class_name Hub
extends Node
## The server's front desk: many rooms, each with its own GameHost. Players say hello, see the open sessions,
## start one or join one, and from then on everything they send goes to their room.
## It never touches the network itself: Net delivers what it emits.

signal send_event(peer: int, data: Dictionary)
signal send_snap(peer: int, data: Dictionary)

const CODE_LETTERS: String = "BCDFGHJKLMNPRSTVWZ"
const CODE_VOWELS: String = "AEIOU"
const IDLE_CLOSE_S: float = 45.0 * 60.0
const MAX_MSGS_PER_S: int = 150
const MAX_NAME: int = 16
const WATCHERS: int = 3

var max_rooms: int = 20
var empty_close_s: float = 90.0   # an empty room waits this long for someone to come back
var rooms: Dictionary = {}        # code -> {host: GameHost, name, code, listed, empty_t, idle_t}
var peer_room: Dictionary = {}    # peer -> code
var peer_name: Dictionary = {}    # peer -> name (said hello)
var _rate: Dictionary = {}        # peer -> messages this second
var _rate_t: float = 0.0
var _list_t: float = 0.0
var _list_sig: String = ""
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

# ================================================================ messages

func handle(peer: int, kind: String, raw: Dictionary) -> void:
	_rate[peer] = int(_rate.get(peer, 0)) + 1
	if int(_rate[peer]) > MAX_MSGS_PER_S or kind.length() > 24:
		return
	var d: Dictionary = clean(raw, 9000 if kind == "rtc" else 240)
	match kind:
		"hello":
			peer_name[peer] = clean_name(str(d.get("name", "")))
			_send_rooms(peer)
		"rooms":
			if peer_name.has(peer):
				_send_rooms(peer)
		"create":
			if peer_name.has(peer) and not peer_room.has(peer):
				_create(peer, str(d.get("name", "")), d.get("career"))
		"join":
			if peer_name.has(peer) and not peer_room.has(peer):
				_join(peer, str(d.get("code", "")).to_upper().strip_edges())
		"leave":
			_leave(peer, true)
		"rtc":
			_rtc(peer, d)
		_:
			var r: Dictionary = _room_of(peer)
			if not r.is_empty():
				r.idle_t = 0.0
				(r.host as GameHost).handle_msg(peer, kind, d)

func drop(peer: int) -> void:
	## the connection went away
	_leave(peer, false)
	peer_name.erase(peer)
	_rate.erase(peer)

static func clean_name(n: String) -> String:
	var out: String = ""
	for ch in n.strip_edges():
		var code: int = ch.unicode_at(0)
		if code >= 32 and code != 127 and not (ch in "<>{}[]\\"):
			out += ch
	out = out.left(MAX_NAME).strip_edges()
	return out if out != "" else "Crew"

static func clean(v: Dictionary, max_str: int, depth: int = 0) -> Dictionary:
	## keep only plain data from a player's message: short strings, numbers, bools, small nested lists
	var out: Dictionary = {}
	var n: int = 0
	for k in v.keys():
		n += 1
		if n > 24 or not (k is String) or (k as String).length() > 32:
			continue
		var c: Variant = _clean_val(v[k], max_str, depth)
		if c != null:
			out[k] = c
	return out

static func _clean_val(x: Variant, max_str: int, depth: int) -> Variant:
	if x is bool or x is int:
		return x
	if x is float:
		return x if is_finite(x) else 0.0
	if x is String:
		return (x as String).left(max_str)
	if x is Dictionary and depth < 2:
		return clean(x, max_str, depth + 1)
	if x is Array and depth < 2:
		var arr: Array = []
		for item in (x as Array).slice(0, 16):
			var ci: Variant = _clean_val(item, max_str, depth + 1)
			if ci != null:
				arr.append(ci)
		return arr
	return null

# ================================================================ rooms

func _room_of(peer: int) -> Dictionary:
	return rooms.get(str(peer_room.get(peer, "")), {})

func _new_code() -> String:
	for attempt in 200:
		var c: String = ""
		for i in 4:
			var src: String = CODE_VOWELS if i % 2 == 1 else CODE_LETTERS
			c += src[rng.randi() % src.length()]
		if not rooms.has(c):
			return c
	return ""

func _create(peer: int, rname: String, career: Variant) -> void:
	var code: String = _new_code()
	if rooms.size() >= max_rooms or code == "":
		send_event.emit(peer, {"t": "hub_error", "text": "The depot is full. Join a crew, or try again in a bit."})
		return
	var h: GameHost = GameHost.new()
	h.career = Progress.new()
	h.career.apply_dict(career)
	h.room_code = code
	# online crews start on the Shift: dealt jobs, never the same twice. Training is the other tab.
	h.shift_always = true
	h.mode = "shift"
	rname = clean_name(rname)
	h.room_name = rname if rname != "Crew" else "%s's crew" % str(peer_name[peer])
	h.admin = 0
	add_child(h)
	h.snap_ready.connect(func(pid: int, data: Dictionary): send_snap.emit(pid, data))
	h.event_ready.connect(_on_room_event.bind(code))
	h.kicked.connect(func(pid: int):
		peer_room.erase(pid)
		_send_rooms(pid))
	rooms[code] = {"host": h, "name": h.room_name, "code": code, "listed": true, "empty_t": 0.0, "idle_t": 0.0}
	print("HUB room %s opened by %s (%d open)" % [code, peer_name[peer], rooms.size()])
	_list_t = 99.0
	_enter(peer, code)

func _join(peer: int, code: String) -> void:
	if not rooms.has(code):
		send_event.emit(peer, {"t": "hub_error", "text": "No crew called %s. It may have gone home." % code.left(8)})
		_send_rooms(peer)
		return
	var h: GameHost = rooms[code].host
	if h.live_peers().size() >= K.SEATS.size() + WATCHERS:
		send_event.emit(peer, {"t": "hub_error", "text": "That crew is full."})
		return
	_enter(peer, code)

func _enter(peer: int, code: String) -> void:
	var r: Dictionary = rooms[code]
	var h: GameHost = r.host
	peer_room[peer] = code
	send_event.emit(peer, {"t": "joined", "code": code, "name": r.name})
	h.add_peer(peer, str(peer_name[peer]))
	if h.admin == 0 or not h.peers.has(h.admin) or h.peers[h.admin].get("gone", false):
		h.admin = peer
		h._send_lobby()
	r.empty_t = 0.0

func _leave(peer: int, tell: bool) -> void:
	var r: Dictionary = _room_of(peer)
	peer_room.erase(peer)
	if not r.is_empty():
		var h: GameHost = r.host
		h.remove_peer(peer)
		_peers_event(h, {"t": "rtc_left", "peer": peer})
	if tell:
		send_event.emit(peer, {"t": "left"})
		_send_rooms(peer)

func _close(code: String) -> void:
	var r: Dictionary = rooms.get(code, {})
	if r.is_empty():
		return
	var h: GameHost = r.host
	for pid in h.live_peers():
		peer_room.erase(pid)
		send_event.emit(pid, {"t": "left", "text": "IGOR has closed the crew room. Nobody was doing anything."})
	h.queue_free()
	rooms.erase(code)
	print("HUB room %s closed (%d open)" % [code, rooms.size()])
	_list_t = 99.0

func _on_room_event(pid: int, data: Dictionary, code: String) -> void:
	if pid != 0:
		send_event.emit(pid, data)
		return
	var r: Dictionary = rooms.get(code, {})
	if r.is_empty():
		return
	_peers_event(r.host, data)

func _peers_event(h: GameHost, data: Dictionary) -> void:
	for p in h.live_peers():
		send_event.emit(p, data)

func _rtc(peer: int, d: Dictionary) -> void:
	## voice chat handshakes: pass a small message from one player to another in the same room
	var to: Variant = d.get("to")
	var r: Dictionary = _room_of(peer)
	if r.is_empty() or not (to is int or to is float) or not (d.get("data") is Dictionary):
		return
	var target: int = int(to)
	if str(peer_room.get(target, "")) != str(r.code) or not (r.host as GameHost).voice:
		return
	send_event.emit(target, {"t": "rtc", "from": peer, "data": d.data})

# ================================================================ the sessions board

func room_list() -> Array:
	var out: Array = []
	for code in rooms.keys():
		var r: Dictionary = rooms[code]
		if not bool(r.listed):
			continue
		var h: GameHost = r.host
		var hostname: String = str(h.peers[h.admin].name) if h.peers.has(h.admin) else "nobody"
		var doing: String = "In the crew room"
		if h.phase != "lobby" and h.mission != null:
			doing = "%s: %s" % ["Briefing" if h.phase == "briefing" else ("Debrief" if h.phase == "debrief" else "Flying"), h.mission.title]
		var open: Array = []
		for s in K.SEATS:
			if not h.seat_owner.has(s):
				open.append(s)
		out.append({"code": code, "name": r.name, "host": hostname, "players": h.live_peers().size(), "max": K.SEATS.size(),
			"doing": doing, "phase": h.phase, "open": open})
	out.sort_custom(func(a, b): return str(a.code) < str(b.code))
	return out

func _send_rooms(peer: int) -> void:
	send_event.emit(peer, {"t": "rooms", "rooms": room_list(), "you": str(peer_name.get(peer, "")), "full": rooms.size() >= max_rooms})

func _process(delta: float) -> void:
	_rate_t += delta
	if _rate_t >= 1.0:
		_rate_t = 0.0
		_rate.clear()
	for code in rooms.keys():
		var r: Dictionary = rooms[code]
		var h: GameHost = r.host
		r.idle_t = float(r.idle_t) + delta
		r.empty_t = 0.0 if not h.live_peers().is_empty() else float(r.empty_t) + delta
		if float(r.empty_t) > empty_close_s or float(r.idle_t) > IDLE_CLOSE_S:
			_close(code)
	_list_t += delta
	if _list_t >= 1.5:
		_list_t = 0.0
		var sig: String = JSON.stringify(room_list())
		if sig != _list_sig:
			_list_sig = sig
			for p in peer_name.keys():
				if not peer_room.has(p):
					_send_rooms(p)
