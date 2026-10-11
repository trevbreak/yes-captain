class_name GameHost
extends Node
## The authoritative host: owns the World, the run, the seats, the bots and the game flow.
## It never touches the network directly. It emits snapshots/events and Net delivers them.

signal snap_ready(peer: int, data: Dictionary)
signal event_ready(peer: int, data: Dictionary)   # peer 0 = everyone
signal lobby_changed

const ENDINGS: Dictionary = {
	"haven": {"title": "HAVEN", "text": "The Free Lanes cheer. The Overlord agrees to leave them alone in exchange for weekly video calls with Pudding. Pudding does not know what a video call is. Pudding is thriving."},
	"return": {"title": "RETURN TO SENDER", "text": "You hand Pudding back personally. The Overlord weeps with joy and pardons everyone. IGOR notes the pardon is written in crayon."},
	"secret": {"title": "PUDDING PICKS YOU", "text": "Pudding refuses to leave. The Overlord, weeping, lets Pudding choose. Pudding chooses the garbage truck. Pudding is now your ship's mascot. IGOR says nothing. IGOR is smiling. IGOR denies this."},
	"sell": {"title": "THE DEAL", "text": "Velvet pays handsomely. You are rich. The Overlord's temper becomes the galaxy's problem. IGOR would like to remind everyone that he did not approve."},
}

var world: World = null
var run: RunState = null
var phase: String = "lobby"
var mode: String = "run"
var shift_kind: String = "casual"
var run_length: String = "full"
var ship_name: String = "Second Opinion"
var peers: Dictionary = {}
var seat_owner: Dictionary = {}
var bots: Dictionary = {}
var bot_on: Dictionary = {}
var bot_kind: Dictionary = {}
var default_personality: String = "random"
var ai_captain: bool = false
var bot_captain: BotCaptain = null
var blackbox: BlackBox = BlackBox.new()
var ritual: Dictionary = {"node": -1}
var debrief: Dictionary = {}
var pit: Dictionary = {}
var ending: Dictionary = {}
var shared: Dictionary = {}
var share_offers: Dictionary = {}
var accum: float = 0.0
var snap_accum: float = 0.0
var igor_cd: float = 0.0
var igor_idle: float = 45.0
var jump_t: float = 0.0
var next_kind: String = ""
var pursuit_done: bool = false
var paused: bool = false
var broadcast_enabled: bool = true
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var step_count: int = 0
var admin: int = 1
var mods: Array = []
var emp_t: float = 45.0
var rot_t: float = 90.0
var time_scale: float = 1.0
var run_log: Array = []
var gameover_info: Dictionary = {}
var phase_t: float = 0.0
var cascade: Array = []

func _init() -> void:
	rng.randomize()
	for s in K.STATIONS:
		bot_on[s] = true
		bot_kind[s] = "competent"
	bot_captain = BotCaptain.new(self)

# ================================================================ peers & seats

func add_peer(id: int, pname: String) -> void:
	# reconnecting players get their seats back
	var seats: Array = []
	var old_id: int = 0
	for pid in peers.keys():
		if peers[pid].get("gone", false) and peers[pid].name == pname:
			old_id = pid
	if old_id != 0:
		seats = peers[old_id].seats.duplicate()
		peers.erase(old_id)
		for s in seats:
			if not seat_owner.has(s):
				seat_owner[s] = id
			else:
				seats.erase(s)
	peers[id] = {"name": pname, "seats": seats, "active": seats[0] if not seats.is_empty() else "", "gone": false}
	_sync_bots()
	lobby_changed.emit()
	_send_lobby()
	if phase != "lobby" and world != null:
		_event(id, {"t": "started"})

func remove_peer(id: int) -> void:
	if not peers.has(id):
		return
	for s in peers[id].seats:
		seat_owner.erase(s)
	if shared.get("peer", 0) == id:
		shared = {}
	share_offers.erase(id)
	if phase == "lobby":
		peers.erase(id)
	else:
		peers[id].gone = true
		peers[id].active = ""
	_sync_bots()
	lobby_changed.emit()
	_send_lobby()

func claim(peer: int, seat: String) -> bool:
	if not peers.has(peer) or not (seat in K.SEATS):
		return false
	if seat_owner.has(seat) and seat_owner[seat] != peer:
		return false
	seat_owner[seat] = peer
	if not (seat in peers[peer].seats):
		peers[peer].seats.append(seat)
	if peers[peer].active == "":
		peers[peer].active = seat
	_sync_bots()
	_send_lobby()
	return true

func release(peer: int, seat: String) -> void:
	if not peers.has(peer):
		return
	if seat_owner.get(seat, 0) == peer:
		seat_owner.erase(seat)
	peers[peer].seats.erase(seat)
	if peers[peer].active == seat:
		peers[peer].active = peers[peer].seats[0] if not peers[peer].seats.is_empty() else ""
	_sync_bots()
	_send_lobby()

func set_active(peer: int, seat: String) -> void:
	if not peers.has(peer):
		return
	if seat == "dc":
		if peers[peer].seats.is_empty():
			return
	elif not (seat in peers[peer].seats):
		return
	var old: String = peers[peer].active
	if old != "dc" and old != seat and world != null:
		_release_holds(peer)
	peers[peer].active = seat
	if shared.get("peer", 0) == peer and shared.get("station", "") != seat:
		shared = {}
	share_offers.erase(peer)

func _release_holds(peer: int) -> void:
	if world == null:
		return
	world.stop_hold("p%d" % peer)
	for s in K.STATIONS:
		world.stop_hold("q:%s:%d" % [s, peer])

func seat_is_bot(seat: String) -> bool:
	return bots.has(seat)

func human_seats() -> Array:
	return seat_owner.keys()

func _sync_bots() -> void:
	for s in K.STATIONS:
		var human: bool = seat_owner.has(s) and not peers.get(seat_owner[s], {}).get("gone", false)
		var want: bool = (not human) and bool(bot_on.get(s, true))
		if want and not bots.has(s):
			var kind: String = str(bot_kind.get(s, "competent"))
			if default_personality == "random" and kind == "competent":
				var pool: Array = ["eager", "literal", "nervous", "sleepy", "knowitall", "competent"]
				kind = pool[rng.randi() % pool.size()]
			var b: Bot = Bot.new(s, kind, self)
			bots[s] = b
		elif not want and bots.has(s):
			bots.erase(s)

func order(seat: String, verb: String, args: Dictionary = {}, from_human: bool = false) -> void:
	if world != null and from_human:
		world.stats["orders"] = int(world.stats["orders"]) + 1
	if bots.has(seat):
		var bark: String = bots[seat].order(verb, args, from_human)
		if bark != "":
			_event(0, {"t": "bark", "text": bark})
	elif seat_owner.has(seat):
		_event(int(seat_owner[seat]), {"t": "order", "seat": seat, "text": order_text(seat, verb, args)})

func order_text(seat: String, verb: String, a: Dictionary) -> String:
	var n: String = K.seat_name(seat)
	match verb:
		"face":
			return "%s: face heading %d degrees" % [n, int(round(rad_to_deg(float(a.get("heading", 0.0))) + 90.0 + 360.0)) % 360]
		"turn":
			return "%s: turn %s %d degrees" % [n, "starboard" if float(a.get("dir", 1.0)) > 0.0 else "port", int(rad_to_deg(float(a.get("amount", 0.5))))]
		"hold":
			return "%s: hold heading" % n
		"speed":
			return "%s: speed %d" % [n, int(a.get("v", 0.0))]
		"stop":
			return "%s: all stop" % n
		"profile":
			return "%s: power profile %s" % [n, a.get("name", "balanced")]
		"engage":
			return "%s: engage hostiles" % n
		"hold_fire":
			return "%s: hold fire" % n
		"torp":
			return "%s: torpedo the target" % n
		"scan":
			return "%s: scan contacts" % n
		"tractor":
			return "%s: tractor beam on the target" % n
		"calm":
			return "%s: keep Pudding calm" % n
		"repair":
			return "%s: go fix %s" % [n, str(a.get("target", "")).substr(4)]
		"set":
			return "%s: set %s to %s" % [n, a.get("id", ""), a.get("value", "")]
		"code":
			return "%s: enter coordinates %s" % [n, a.get("code", "")]
		"secure":
			return "%s: secure the cargo" % n
		"stow":
			return "%s: stow the guns" % n
		"gentle":
			return "%s: easy on the throttle" % n
	return "%s: %s" % [n, verb]

func bot_code(code: String) -> void:
	_helm_code(code)

# ================================================================ lobby

func lobby_dict() -> Dictionary:
	var seats: Dictionary = {}
	for s in K.SEATS:
		var o: int = int(seat_owner.get(s, 0))
		seats[s] = {"owner": o, "owner_name": peers[o].name if peers.has(o) else "",
			"bot": bots.has(s), "bot_on": bool(bot_on.get(s, true)) if s != "captain" else false,
			"kind": bot_kind.get(s, "competent")}
	var pl: Dictionary = {}
	for pid in peers.keys():
		pl[pid] = {"name": peers[pid].name, "seats": peers[pid].seats, "gone": peers[pid].gone}
	return {"t": "lobby", "seats": seats, "peers": pl, "mode": mode, "shift_kind": shift_kind, "length": run_length,
		"ship_name": ship_name, "ai_captain": ai_captain, "phase": phase, "admin": admin, "defected": RunState.load_defected(),
		"personality": default_personality, "mods": mods}

func _send_lobby() -> void:
	_event(0, lobby_dict())

func set_option(peer: int, key: String, val: Variant) -> void:
	if phase != "lobby" and key != "ship_name":
		return
	match key:
		"mode":
			mode = str(val)
		"shift_kind":
			shift_kind = str(val)
		"length":
			run_length = str(val)
		"ship_name":
			ship_name = str(val).substr(0, 24)
		"ai_captain":
			ai_captain = bool(val)
		"mods":
			mods = val if val is Array else []
		"personality":
			default_personality = str(val)
		"bot_on":
			bot_on[str(val.get("seat", ""))] = bool(val.get("on", true))
			_sync_bots()
		"bot_kind":
			var seat: String = str(val.get("seat", ""))
			bot_kind[seat] = str(val.get("kind", "competent"))
			bots.erase(seat)
			_sync_bots()
	_send_lobby()

# ================================================================ starting

func start_game(seed_value: int = 0) -> void:
	world = World.new(seed_value)
	world.ship.hull = world.ship.hull_max
	_sync_bots()
	for s in bots.keys():
		bots[s].host = self
	blackbox.reset(0.0)
	gameover_info = {}
	ending = {}
	shared = {}
	if mode == "run":
		run = RunState.new(seed_value, run_length)
		run.thrupp_idx = RunState.load_rank()
		world.ship.pud["aboard"] = false
		_begin_encounter("binday")
	else:
		run = null
		world.ship.pud["aboard"] = true
		_begin_encounter(shift_kind)
	_event(0, {"t": "started"})

func _apply_mods() -> void:
	var s: Ship = world.ship
	world.mods = mods.duplicate()
	s.damage_mult = 2.0 if "glass" in mods else 1.0
	s.dampers_locked = "newton" in mods
	if s.dampers_locked:
		s.dampers = false
	elif not s.dampers:
		s.dampers = true
	if "pudding" in mods:
		s.pud["mood"] = 78.0
		s.pen_bonus = maxf(s.pen_bonus, 2.0)
	if "glass" in mods:
		world.director.intensity = 1.6
	world.inverted.clear()
	emp_t = rng.randf_range(30.0, 50.0)
	rot_t = 80.0

func _mods_tick(dt: float) -> void:
	if phase != "encounter" or mods.is_empty():
		return
	if "emp" in mods:
		emp_t -= dt
		if emp_t <= 0.0:
			emp_t = rng.randf_range(35.0, 55.0)
			var st: String = K.STATIONS[rng.randi() % K.STATIONS.size()]
			world.inverted[st] = 20.0
			_igor("emp", {"station": K.seat_name(st)}, 3)
			_event(0, {"t": "toast", "text": "EMP hit %s! Their controls are inverted for 20s." % K.seat_name(st)})
			blackbox.log_event(world.t, st, "EMP: controls inverted", "bad")
	if "rotation" in mods:
		rot_t -= dt
		if rot_t <= 0.0:
			rot_t = 80.0
			rotate_crew()

func rotate_crew() -> void:
	var order: Array = K.STATIONS
	var owners: Dictionary = {}
	for s in order:
		owners[s] = int(seat_owner.get(s, 0))
	var humans: int = 0
	for s2 in order:
		if owners[s2] != 0:
			humans += 1
	if humans < 2:
		return
	for pid in peers.keys():
		var keep: Array = []
		for s3 in peers[pid].seats:
			if not (s3 in order):
				keep.append(s3)
		peers[pid].seats = keep
	for s4 in order:
		seat_owner.erase(s4)
	for i in order.size():
		var o: int = owners[order[(i + 1) % order.size()]]
		if o != 0 and peers.has(o):
			seat_owner[order[i]] = o
			peers[o].seats.append(order[i])
	for pid2 in peers.keys():
		var p: Dictionary = peers[pid2]
		_release_holds(pid2)
		if p.active != "captain":
			p.active = p.seats[0] if not p.seats.is_empty() else ""
		elif not (p.active in p.seats):
			p.active = p.seats[0] if not p.seats.is_empty() else ""
	share_offers.clear()
	shared = {}
	_sync_bots()
	_send_lobby()
	_igor("rotation", {}, 3)
	_event(0, {"t": "toast", "text": "CREW ROTATION! Everyone shifts one seat. Good luck."})
	blackbox.log_event(world.t, "captain", "CREW ROTATION", "info")

func _reset_ship_pose() -> void:
	var s: Ship = world.ship
	s.pos = Vector2.ZERO
	s.vel = Vector2.ZERO
	s.heading = -PI / 2.0
	s.angvel = 0.0
	s.yaw = 0.0
	s.strafe = 0.0
	s.thr_p = 0.0
	s.thr_s = 0.0
	s.roll_t = 0.0
	s.charging = false
	s.jump_charge = 0.0

func _begin_encounter(kind: String) -> void:
	_reset_ship_pose()
	world.clear_entities()
	world.ship.reset_for_encounter()
	world.ship.cargo.clear()
	world.ship.cargo_secured = false
	if mode != "run":
		world.ship.hull = world.ship.hull_max
		world.damages_billed = 0.0
	world.reset_stats()
	world.stowed = false
	world.view_dir = "fwd"
	world.holds.clear()
	world.mash.clear()
	world.load_hold.clear()
	world.track = {"TUR_A": false, "TUR_B": false}
	world.temper = run.temper_level() if run != null else 2
	world.thrupp_title = run.rank_title() if run != null else "Admiral"
	world.director = Director.new(world)
	world.damages_billed = 0.0
	blackbox.reset(world.t)
	_apply_mods()
	var enc: Encounter = Encounters.make(kind, world.temper)
	world.enc = enc
	enc.setup(world)
	phase = "encounter"
	phase_t = 0.0
	pursuit_done = false
	shared = {}
	if bot_captain != null:
		bot_captain.on_phase_change()
	_event(0, {"t": "encounter_start", "title": enc.title, "family": enc.family})
	if run != null and run.encounters_done == 0:
		_igor("welcome", {}, 3)
	blackbox.log_event(world.t, "captain", "Encounter begins: %s" % enc.title, "info")

# ================================================================ messages from peers

func handle_msg(peer: int, kind: String, d: Dictionary) -> void:
	if not peers.has(peer) and kind != "hello":
		return
	match kind:
		"hello":
			add_peer(peer, str(d.get("name", "Crew %d" % peer)))
			if admin == 0:
				admin = peer
		"claim":
			claim(peer, str(d.get("seat", "")))
		"release":
			release(peer, str(d.get("seat", "")))
		"active":
			set_active(peer, str(d.get("seat", "")))
		"intent":
			_intent(peer, str(d.get("station", "")), str(d.get("key", "")), d.get("val"))
		"share":
			var st: String = peers[peer].active
			if bool(d.get("on", false)) and st != "" and st != "captain":
				share_offers[peer] = st
			else:
				share_offers.erase(peer)
				if shared.get("peer", 0) == peer:
					shared = {}
		"cap":
			if seat_owner.get("captain", 0) == peer:
				_captain_cmd(str(d.get("cmd", "")), d)
		"opt":
			if peer == admin:
				set_option(peer, str(d.get("key", "")), d.get("val"))
		"start":
			if peer == admin and phase == "lobby":
				start_game()
		"pit_request":
			if pit.has("requests") and peers[peer].active in K.STATIONS:
				pit.requests[str(d.get("id", ""))] = peers[peer].active

func _intent(peer: int, station: String, key: String, val: Variant) -> void:
	if world == null or phase == "lobby":
		return
	var p: Dictionary = peers[peer]
	if station == "dc":
		if p.active != "dc":
			return
		var v: Dictionary = val if val is Dictionary else {}
		v["quick"] = ""
		Intents.apply(world, "dc", key, v, "p%d" % peer, true)
		return
	if not (station in K.STATIONS):
		return
	if seat_owner.get(station, 0) != peer or p.active != station:
		return
	if phase == "debrief" or phase == "gameover" or phase == "ending":
		return
	_note_input(station, key, val)
	match key:
		"fix":
			var v2: Dictionary = val
			var actor: String = "q:%s:%d" % [station, peer]
			if v2.get("click", false):
				world.click_work(str(v2.get("target", "")), station)
			else:
				Intents.apply(world, "dc", "hold", {"target": v2.get("target", ""), "on": v2.get("on", false), "quick": station}, actor)
			return
		"set":
			if world.enc != null:
				world.enc.on_intent(station, "set", val)
			return
		"code":
			if station == "helm":
				_helm_code(str(val))
			return
		"beacon":
			if station == "sensors":
				deploy_beacon()
			return
	Intents.apply(world, station, key, val, "", true)

func _note_input(station: String, key: String, val: Variant) -> void:
	var t: float = world.t
	var text: String = ""
	match key:
		"boost":
			text = "BOOST %s" % ("ON" if bool(val) else "off")
		"dampers":
			text = "DAMPERS %s" % ("ON" if bool(val) else "OFF!")
		"roll":
			text = "EMERGENCY ROLL"
		"torp_fire":
			text = "fired a torpedo"
		"oc":
			text = "OVERCLOCK %s" % str(val)
		"vent":
			text = "vented the reactor"
		"ping":
			text = "ACTIVE PING"
		"jettison":
			text = "jettisoned cargo"
		"stow":
			text = "stowed guns" if bool(val) else "unstowed guns"
		"thr":
			if absf(float(val)) > 0.9:
				text = "THROTTLE %s" % ("FULL AHEAD" if float(val) > 0 else "FULL REVERSE")
		"view":
			text = "viewscreen: %s" % str(val)
	if text != "":
		blackbox.log_event(t, station, text, "input")

func deploy_beacon() -> void:
	if world == null:
		return
	var s: Ship = world.ship
	if s.beacons <= 0:
		return
	s.beacons -= 1
	world.spawn("beacon", s.pos - s.fwd() * 40.0, {"vel": -s.fwd() * 5.0})
	if run != null:
		if run.add_temper(-1.0):
			_igor("temper_down", {"level": run.temper_name()}, 2)
			world.temper = run.temper_level()
	blackbox.log_event(world.t, "sensors", "deployed a decoy beacon", "input")

# ================================================================ captain commands

func _captain_cmd(cmd: String, d: Dictionary) -> void:
	match cmd:
		"accept_share":
			var pid: int = int(d.get("peer", 0))
			if share_offers.has(pid):
				shared = {"peer": pid, "station": share_offers[pid]}
		"stop_share":
			shared = {}
		"decline_share":
			share_offers.erase(int(d.get("peer", 0)))
		"order":
			order(str(d.get("seat", "")), str(d.get("verb", "")), d.get("args", {}), true)
			blackbox.log_event(world.t if world != null else 0.0, "captain", "ordered %s: %s" % [d.get("seat", ""), d.get("verb", "")], "order")
		"continue":
			captain_continue()
		"retry":
			if mode == "shift" and (phase == "debrief" or phase == "gameover"):
				_begin_encounter(shift_kind)
		"lobby":
			to_lobby()
		"punch":
			captain_punch()
		"pit_buy":
			pit_buy(str(d.get("id", "")))
		"pit_done":
			pit_done()

func to_lobby() -> void:
	phase = "lobby"
	world = null
	run = null
	for pid in peers.keys():
		if peers[pid].gone:
			peers.erase(pid)
	_send_lobby()
	_event(0, {"t": "to_lobby"})

# ================================================================ ritual (staging)

func _begin_staging() -> void:
	_reset_ship_pose()
	world.clear_entities()
	world.ship.cargo.clear()
	world.enc = null
	world.stowed = false
	world.director = Director.new(world)
	world.director.intensity = 0.5
	world.temper = run.temper_level()
	phase = "staging"
	phase_t = 0.0
	pursuit_done = false
	ritual = {"node": -1, "pw_t": 0.0, "en_t": 0.0, "target_speed": float(rng.randi_range(26, 40)), "over": false,
		"ok": {"helm": false, "power": false, "engines": false, "ops": false}, "t": 0.0, "msg": ""}
	shared = {}
	if bot_captain != null:
		bot_captain.on_phase_change()
	_event(0, {"t": "staging"})

func _helm_code(code: String) -> void:
	if phase != "staging" or run == null:
		return
	var n: Dictionary = run.node_by_code(code)
	if n.is_empty():
		ritual["msg"] = "No such coordinates: %s" % code
		_event(0, {"t": "toast", "text": "Helm: no such coordinates '%s'" % code})
		return
	ritual["node"] = n.id
	ritual["ok"]["helm"] = true
	ritual["msg"] = ""
	_event(0, {"t": "toast", "text": "Course laid in: %s" % n.code})

func _ritual_tick(dt: float) -> void:
	var s: Ship = world.ship
	ritual["t"] = float(ritual["t"]) + dt
	if int(ritual["node"]) < 0:
		return
	# power: charge capacitor into the green band for 2 s
	var ch: float = s.jump_charge
	if ch > 0.85:
		ritual["over"] = true
	if ch >= 0.45 and ch <= 0.62:
		ritual["pw_t"] = float(ritual["pw_t"]) + dt
	else:
		ritual["pw_t"] = 0.0
	ritual["ok"]["power"] = float(ritual["pw_t"]) >= 2.0
	# engines: hold speed inside the window
	if absf(s.speed() - float(ritual["target_speed"])) <= 4.0:
		ritual["en_t"] = float(ritual["en_t"]) + dt
	else:
		ritual["en_t"] = 0.0
	ritual["ok"]["engines"] = float(ritual["en_t"]) >= 2.0
	ritual["ok"]["ops"] = s.cargo_secured
	if run.temper_level() >= 3 and not pursuit_done and float(ritual["t"]) > 20.0:
		pursuit_done = true
		for i in 2:
			world.spawn("grabber", s.pos + Vector2.from_angle(rng.randf() * TAU) * 420.0)
		world.hail("Admiral Thrupp", "Pull over! Pull over! Hand over the pet and the paperwork-free zone is yours!")

func captain_punch() -> void:
	if phase != "staging" or run == null or int(ritual.get("node", -1)) < 0:
		return
	var ok: Dictionary = ritual["ok"]
	var all_ok: bool = ok.helm and ok.power and ok.engines and ok.ops and not bool(ritual["over"])
	var node: Dictionary = run.nodes[int(ritual["node"])]
	var kind: String = node.kind
	if run.fuel > 0:
		run.fuel -= 1
	else:
		run.add_temper(1.0)
	if not all_ok:
		world.stats["misjump"] = int(world.stats["misjump"]) + 1
		var pool: Array = Encounters.MID_KINDS.duplicate()
		kind = pool[rng.randi() % pool.size()]
		run.add_temper(1.0)
		_igor("misjump", {}, 3)
		blackbox.log_event(world.t, "captain", "PUNCHED IT with the ritual incomplete. Misjump!", "bad")
		_event(0, {"t": "toast", "text": "MISJUMP! We are somewhere else."})
	else:
		_igor("jump_ok", {}, 1)
	run.cur = int(node.id)
	run.visited.append(int(node.id))
	run.jumps += 1
	if run.add_temper(0.8):
		_igor("temper_up", {"level": run.temper_name()}, 2)
	next_kind = kind
	jump_t = 2.6
	phase = "jumping"
	_event(0, {"t": "fx", "fx": "jump"})

# ================================================================ pit stop

func _begin_pitstop() -> void:
	phase = "pitstop"
	phase_t = 0.0
	pit = {"requests": {}, "bought": []}
	shared = {}
	world.ship.cargo.clear()
	if bot_captain != null:
		bot_captain.on_phase_change()
	_igor("pit_enter", {}, 2)
	_event(0, {"t": "pitstop"})

func pit_buy(id: String) -> void:
	if phase != "pitstop" or run == null:
		return
	for it in RunState.ITEMS:
		if it.id == id and run.scrap >= int(it.cost):
			run.scrap -= int(it.cost)
			run.apply_item(id, world.ship, world)
			pit["bought"].append(id)
			pit.requests.erase(id)
			_event(0, {"t": "toast", "text": "Bought: %s" % it.name})
			return

func pit_done() -> void:
	if phase == "pitstop":
		_begin_staging()

# ================================================================ stepping

func _process(delta: float) -> void:
	if world == null or phase == "lobby" or paused:
		return
	accum += minf(delta, 0.25) * time_scale
	var n: int = 0
	while accum >= K.DT and n < int(6.0 * maxf(1.0, time_scale)):
		accum -= K.DT
		n += 1
		sim_step(K.DT)
	snap_accum += delta
	if snap_accum >= 1.0 / K.SNAP_HZ:
		snap_accum = 0.0
		if broadcast_enabled:
			send_snapshots()

func sim_step(dt: float) -> void:
	if world == null:
		return
	step_count += 1
	phase_t += dt
	if phase == "debrief" or phase == "gameover" or phase == "ending" or phase == "pitstop":
		# the world idles but bots/captain still tick (so AI captain can move on)
		if ai_captain and bot_captain != null:
			bot_captain.tick(dt)
		return
	for s in bots.keys():
		bots[s].tick(dt)
	if ai_captain and bot_captain != null:
		bot_captain.tick(dt)
	if phase == "jumping":
		jump_t -= dt
		world.step(dt)
		_drain_events()
		if jump_t <= 0.0:
			_begin_encounter(next_kind)
		return
	world.step(dt)
	blackbox.record(world, dt)
	_drain_events()
	_mods_tick(dt)
	if phase == "staging":
		_ritual_tick(dt)
		if world.ship.hull <= 0.0:
			_game_over("The ship was destroyed during the jump ritual.")
	elif phase == "encounter":
		if world.enc != null and world.enc.done:
			_end_encounter()
		if run != null:
			run.mood_sum += float(world.ship.pud["mood"]) * dt
			run.mood_n += 1 if step_count % 30 == 0 else 0
	igor_cd = maxf(0.0, igor_cd - dt)
	igor_idle -= dt
	if igor_idle <= 0.0:
		igor_idle = rng.randf_range(55.0, 90.0)
		_igor("idle", {}, 0)

func advance(seconds: float) -> void:
	var n: int = int(seconds / K.DT)
	for i in n:
		sim_step(K.DT)

# ================================================================ world events

func _drain_events() -> void:
	var evs: Array = world.events.duplicate()
	world.events.clear()
	for ev in evs:
		_on_world_event(str(ev[0]), ev[1])
		if world.enc != null:
			world.enc.on_event(str(ev[0]), ev[1])
	if not world.events.is_empty():
		# encounters may emit events while handling others
		var more: Array = world.events.duplicate()
		world.events.clear()
		for ev2 in more:
			_on_world_event(str(ev2[0]), ev2[1])

func _on_world_event(type: String, d: Dictionary) -> void:
	var t: float = world.t
	match type:
		"module_rattle":
			_igor("rattle", {"label": d.label}, 1)
			blackbox.log_event(t, d.owner if d.owner != "" else "ship", "%s is rattling" % d.label, "warn")
		"module_fail":
			_igor("fail", {"label": d.label}, 2)
			blackbox.log_event(t, d.owner if d.owner != "" else "ship", "%s FAILED" % d.label, "bad")
			cascade.append(t)
			cascade = cascade.filter(func(x): return t - x < 10.0)
			if cascade.size() >= 3:
				blackbox.mark(world, "Cascading failures!")
				cascade.clear()
		"fire":
			_igor("fire", {"label": d.label}, 2)
			blackbox.counts["fires"] = int(blackbox.counts.get("fires", 0)) + 1
			blackbox.log_event(t, d.owner if d.owner != "" else "ship", "FIRE in %s" % d.label, "bad")
			blackbox.mark(world, "Fire in %s" % d.label)
		"breach":
			_igor("breach", {"label": d.label}, 2)
			blackbox.log_event(t, d.owner if d.owner != "" else "ship", "hull breach in %s" % d.label, "bad")
		"conduit_cut":
			_igor("conduit", {}, 1)
			blackbox.log_event(t, "power", "a conduit was cut (%s)" % d.id, "bad")
		"scram":
			_igor("scram", {}, 3)
			blackbox.log_event(t, "power", "REACTOR SCRAM. Lights out.", "bad")
			blackbox.mark(world, "Reactor scram")
			_event(0, {"t": "fx", "fx": "scram"})
		"power_back":
			_igor("power_back", {}, 1)
		"pudding_loose":
			_igor("pudding_loose", {}, 3)
			blackbox.log_event(t, "ops", "Pudding escaped the pen", "bad")
		"pudding_chew":
			_igor("pudding_chew", {"label": d.label}, 2)
			blackbox.log_event(t, "ship", "Pudding chewed %s" % d.label, "bad")
		"pudding_back":
			_igor("pudding_back", {}, 1)
		"pudding_found":
			_igor("pudding_found", {}, 3)
		"collision":
			var who: String = blackbox.blame(world)
			if float(d.speed) > 6.0:
				_igor("collision", {"name": d.name}, 2)
			blackbox.counts["collide_blame"] = who if who != "" else "helm"
			blackbox.log_event(t, who if who != "" else "helm", "hit %s at %.0f m/s" % [d.name, d.speed], "bad")
			if float(d.speed) > 12.0:
				blackbox.mark(world, "Collision at %.0f m/s" % d.speed)
		"friendly_fire":
			_igor("friendly_fire", {"name": d.name}, 3)
			blackbox.log_event(t, "weapons", "shot %s. That was not the enemy." % d.name, "bad")
			blackbox.mark(world, "Friendly fire: %s" % d.name)
		"zap":
			_igor("zap", {}, 2)
			blackbox.log_event(t, "dc", "got zapped splicing %s" % d.id, "bad")
		"overclock":
			_igor("overclock", {}, 1)
		"dampers":
			if not d.on:
				_igor("dampers_off", {}, 1)
		"roll":
			_igor("roll", {}, 1)
			blackbox.log_event(t, "helm", "EMERGENCY ROLL", "input")
		"latched":
			_igor("latched" if d.kind == "grabber" else "snatch", {}, 2)
			blackbox.log_event(t, "ship", "a %s latched onto %s" % [d.kind, d.mod], "bad")
		"shaken_off":
			_igor("shaken", {}, 1)
			blackbox.log_event(t, "helm", "shook off a %s" % d.kind, "good")
		"kill":
			_igor("kill", {}, 0)
			blackbox.log_event(t, "weapons", "destroyed %s" % d.name, "good")
		"bastion_telegraph":
			_igor("bastion", {}, 2)
			_event(0, {"t": "fx", "fx": "alarm"})
		"hull_hit":
			for b in bots.values():
				b.notify_hit()
		"repaired":
			var la: String = world.last_actor
			var by_human: bool = la.begins_with("p") or (la.begins_with("q:") and la.count(":") >= 2)
			_igor("repaired_human" if by_human else "repaired_bot", {"label": d.label}, 1)
			blackbox.log_event(t, "dc", "repaired %s" % d.label, "good")
		"fire_out":
			blackbox.log_event(t, "dc", "put out the fire in %s" % d.label, "good")
		"breach_sealed":
			blackbox.log_event(t, "dc", "sealed the breach in %s" % d.label, "good")
		"spotted":
			_igor("spotted", {}, 3)
			blackbox.log_event(t, "captain", "SPOTTED by the patrol", "bad")
			blackbox.mark(world, "Spotted!")
			if run != null:
				run.add_temper(1.0)
		"checkpoint_pass":
			_igor("checkpoint_pass", {}, 3)
			blackbox.log_event(t, "captain", "Passed customs", "good")
		"checkpoint_fail":
			_igor("checkpoint_fail", {}, 3)
			blackbox.log_event(t, "captain", "Failed customs (%d/6 correct)" % int(d.count), "bad")
		"hail":
			_event(0, {"t": "hail", "from": d.from, "text": d.text})
			blackbox.log_event(t, "sensors", "relayed a hail from %s" % d.from, "info")
		"hail_lost":
			_event(0, {"t": "toast", "text": "Signal lost: %s" % d.from})
		"scanned":
			pass
		"collected":
			_event(0, {"t": "toast", "text": "Collected: %s" % d.name})
			blackbox.log_event(t, "ops", "tractored %s" % d.name, "good")
		"boom":
			_event(0, {"t": "fx", "fx": "boom", "x": d.pos.x, "y": d.pos.y, "size": d.size})
		"mine_hit":
			blackbox.log_event(t, blackbox.blame(world) if blackbox.blame(world) != "" else "helm", "triggered a mine", "bad")
			blackbox.mark(world, "Mine!")
		"near_miss":
			blackbox.log_event(t, "helm", "near miss", "info")
		"cargo_leak":
			pass
		"jettison":
			blackbox.log_event(t, "ops", "jettisoned %s" % d.name, "bad")
		"pudding_snatched":
			blackbox.log_event(t, "ship", "Pudding was snatched!", "bad")
		"weak_hit":
			blackbox.log_event(t, "weapons", "torpedo in the weak spot!", "good")
			blackbox.mark(world, "Direct hit on the weak spot")
		"toast_text":
			_event(0, {"t": "toast", "text": d.text})
		"incident":
			pass

func _igor(key: String, ctx: Dictionary = {}, prio: int = 1) -> void:
	if igor_cd > 0.0 and prio < 3:
		return
	var text: String = Igor.line(key, ctx)
	if text == "":
		return
	igor_cd = 2.5 if prio >= 2 else 5.0
	igor_idle = maxf(igor_idle, 30.0)
	_event(0, {"t": "igor", "text": text, "prio": prio})

# ================================================================ end of encounter

func _end_encounter() -> void:
	var enc: Encounter = world.enc
	var ok: bool = enc.success
	var fatal: bool = (not ok) and (enc.fail_reason.contains("destroyed") or enc.fail_reason.contains("snatched"))
	var summary: Dictionary = {"ok": ok, "reason": enc.fail_reason, "title": enc.title, "time": enc.t, "par": enc.par,
		"damages": world.damages_billed}
	if run != null:
		if ok:
			run.scrap += int(enc.spoils.get("scrap", 20))
			run.fuel += int(enc.spoils.get("fuel", 0)) + (1 if rng.randf() < 0.45 else 0)
			world.ship.snacks += int(enc.spoils.get("snacks", 0))
			world.ship.beacons += int(enc.spoils.get("beacons", 0))
			if enc.temper_delta != 0:
				if run.add_temper(float(enc.temper_delta) * 1.0):
					_igor("temper_up" if enc.temper_delta > 0 else "temper_down", {"level": run.temper_name()}, 2)
			run.encounters_done += 1
			# Thrupp gets demoted for losing
			if enc.id != "binday" and enc.id != "dock" and rng.randf() < 0.55:
				var old: String = run.rank_title()
				run.thrupp_idx = mini(run.thrupp_idx + 1, RunState.RANKS.size() - 1)
				summary["thrupp"] = "Thrupp has been demoted: %s -> %s" % [old, run.rank_title()]
				world.thrupp_title = run.rank_title()
				if run.thrupp_idx >= RunState.RANKS.size() - 1:
					RunState.save_rank(run.thrupp_idx, true)
					summary["thrupp"] += "  He DEFECTS! 'Grovelling' is now an AI crew personality."
					_igor("defect", {}, 3)
		else:
			if not fatal:
				run.add_temper(1.0)
				summary["setback"] = "Setback! The Overlord is angrier (+1 Temper)."
			var old2: String = run.rank_title()
			run.thrupp_idx = maxi(run.thrupp_idx - 1, 0)
			summary["thrupp"] = "Thrupp has been PROMOTED: %s -> %s" % [old2, run.rank_title()]
	summary["events"] = blackbox.events.slice(maxi(0, blackbox.events.size() - 14))
	summary["awards"] = blackbox.awards(world, bots.keys())
	summary["trail"] = blackbox.downsample(blackbox.trail, 220)
	summary["marks"] = blackbox.marks.slice(0, 12)
	summary["frames"] = blackbox.downsample(blackbox.frames, 120)
	summary["stats"] = {"collisions": world.stats["collisions"], "kills": world.stats["kills"], "repairs": world.stats["repairs"],
		"fires": world.stats["fires_put_out"], "friendly": world.stats["friendly_fire"]}
	summary["spoils"] = enc.spoils if ok else {}
	summary["goal"] = [enc.goal.x, enc.goal.y]
	debrief = summary
	_igor("success" if ok else "fail_end", {}, 3)
	if fatal:
		gameover_info = summary
		_game_over(enc.fail_reason)
		return
	phase = "debrief"
	phase_t = 0.0
	if bot_captain != null:
		bot_captain.on_phase_change()
	_event(0, {"t": "debrief"})
	if run != null and ok and enc.id.begins_with("fin_"):
		_finish_run(enc.id)

func _finish_run(finale_id: String) -> void:
	var eid: String = "haven"
	match finale_id:
		"fin_haven":
			eid = "secret" if run.calm_score() < 38.0 and run.encounters_done >= 3 else "haven"
		"fin_return":
			eid = "return"
		"fin_sell":
			eid = "sell"
	run.finished = true
	run.ending = eid
	var old: int = run.thrupp_idx
	run.thrupp_idx = mini(run.thrupp_idx + 2, RunState.RANKS.size() - 1)
	RunState.save_rank(run.thrupp_idx, run.thrupp_idx >= RunState.RANKS.size() - 1)
	ending = ENDINGS[eid].duplicate()
	ending["id"] = eid
	ending["thrupp"] = "Thrupp ends the day as: %s" % run.rank_title()
	ending["scrap"] = run.scrap
	ending["jumps"] = run.jumps
	ending["calm"] = run.calm_score()
	_igor("endings", {}, 3)

func _game_over(reason: String) -> void:
	phase = "gameover"
	phase_t = 0.0
	var lines: Array = []
	for e in blackbox.events:
		if e.kind == "bad":
			lines.append("%s: %s" % [K.seat_name(e.who) if e.who in K.SEATS else str(e.who).capitalize(), e.text])
	lines = lines.slice(maxi(0, lines.size() - 5))
	if run != null:
		run.thrupp_idx = maxi(run.thrupp_idx - 1, 0)
		RunState.save_rank(run.thrupp_idx, false)
	gameover_info = {"reason": reason, "lines": lines, "thrupp": run.rank_title() if run != null else "Admiral",
		"events": blackbox.events.slice(maxi(0, blackbox.events.size() - 14)), "trail": blackbox.downsample(blackbox.trail, 220),
		"frames": blackbox.downsample(blackbox.frames, 120), "marks": blackbox.marks.slice(0, 12),
		"awards": blackbox.awards(world, bots.keys()), "goal": [world.enc.goal.x, world.enc.goal.y] if world.enc != null else [0, 0]}
	_igor("fail_end", {}, 3)
	_event(0, {"t": "gameover"})

func captain_continue() -> void:
	match phase:
		"debrief":
			if run != null:
				if run.finished:
					phase = "ending"
					_event(0, {"t": "ending"})
				elif world.enc != null and world.enc.dock_request:
					_begin_pitstop()
				else:
					_begin_staging()
			else:
				_begin_encounter(shift_kind)
		"gameover", "ending":
			to_lobby()

# ================================================================ snapshots

func _event(peer: int, data: Dictionary) -> void:
	if not broadcast_enabled:
		return
	event_ready.emit(peer, data)

func send_snapshots() -> void:
	for pid in peers.keys():
		if peers[pid].gone:
			continue
		snap_ready.emit(pid, snapshot_for(pid))

func snapshot_for(peer: int) -> Dictionary:
	var p: Dictionary = peers.get(peer, {"active": "", "seats": []})
	var act: String = p.active
	var d: Dictionary = {"t": "snap", "phase": phase, "active": act, "seats": p.seats}
	if world == null:
		return d
	d["common"] = Snapshots.common(world)
	d["common"]["ship_name"] = ship_name
	d["common"]["phase_t"] = phase_t
	if run != null:
		d["run"] = {"scrap": run.scrap, "fuel": run.fuel, "temper": run.temper_level(), "temper_name": run.temper_name(),
			"rank": run.rank_title(), "jumps": run.jumps, "cur": run.cur, "act": 1 if run.cur < 2 else (2 if run.cur < run.nodes.size() - 4 else 3)}
	else:
		d["run"] = {"scrap": 0, "fuel": 0, "temper": 2, "temper_name": "Cross", "rank": "Admiral", "jumps": 0}
	if act == "captain":
		d["view"] = Snapshots.captain(world)
		var offers: Array = []
		for pid in share_offers.keys():
			offers.append({"peer": pid, "station": share_offers[pid], "name": peers[pid].name})
		d["offers"] = offers
		if not shared.is_empty():
			d["shared"] = {"station": shared.station, "view": _station_view(shared.station)}
		d["bots"] = bots.keys()
		d["orders"] = _order_menu()
	elif act == "dc":
		d["view"] = Snapshots.dc(world)
	elif act != "":
		d["view"] = _station_view(act)
		d["view"]["emp_t"] = float(world.inverted.get(act, 0.0))
		d["sharing"] = share_offers.has(peer)
		d["shared_now"] = shared.get("peer", 0) == peer
	d["ph"] = _phase_data(act, peer)
	return d

func _station_view(st: String) -> Dictionary:
	match st:
		"helm":
			return Snapshots.helm(world)
		"engines":
			return Snapshots.engines(world)
		"power":
			return Snapshots.power(world)
		"weapons":
			return Snapshots.weapons(world)
		"sensors":
			return Snapshots.sensors(world)
		"ops":
			return Snapshots.ops(world)
		"dc":
			return Snapshots.dc(world)
	return {}

func _order_menu() -> Dictionary:
	return {"hostiles": world.hostiles().size()}

func _phase_data(act: String, peer: int) -> Dictionary:
	var d: Dictionary = {}
	match phase:
		"staging":
			var rit: Dictionary = ritual.duplicate(true)
			d["ritual"] = rit
			var opts: Array = []
			if run != null:
				for n in run.options():
					if act == "captain":
						opts.append({"id": n.id, "name": n.name, "code": n.code, "kind": n.kind, "threat": n.threat,
							"blurb": Encounters.INFO.get(n.kind, {}).get("blurb", ""), "pit": n.pit})
					elif act == "helm":
						opts.append({"code": n.code})
				d["options"] = opts
			if act == "captain" and run != null:
				d["map"] = _map_dict()
		"pitstop":
			d["scrap"] = run.scrap if run != null else 0
			var items: Array = []
			for it in RunState.ITEMS:
				if act == "captain" or it.station == act:
					items.append({"id": it.id, "station": it.station, "name": it.name, "desc": it.desc, "cost": it.cost,
						"requested": pit.get("requests", {}).has(it.id), "by": pit.get("requests", {}).get(it.id, ""),
						"bought": it.id in pit.get("bought", [])})
			d["items"] = items
		"debrief":
			d["debrief"] = debrief if act == "captain" else {"ok": debrief.get("ok", false), "title": debrief.get("title", ""), "awards": debrief.get("awards", []), "thrupp": debrief.get("thrupp", ""), "setback": debrief.get("setback", ""), "reason": debrief.get("reason", ""), "time": debrief.get("time", 0.0), "par": debrief.get("par", 0.0), "damages": debrief.get("damages", 0.0), "spoils": debrief.get("spoils", {})}
			d["mode"] = mode
		"gameover":
			d["over"] = gameover_info if act == "captain" else {"reason": gameover_info.get("reason", ""), "lines": gameover_info.get("lines", [])}
			d["mode"] = mode
		"ending":
			d["ending"] = ending
		"jumping":
			d["jump_t"] = jump_t
	return d

func _map_dict() -> Dictionary:
	var ns: Array = []
	for n in run.nodes:
		ns.append({"id": n.id, "col": n.col, "row": n.row, "kind": n.kind, "name": n.name, "next": n.next, "code": n.code, "pit": n.pit, "threat": n.threat})
	return {"nodes": ns, "cur": run.cur, "visited": run.visited}
