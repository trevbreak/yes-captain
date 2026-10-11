class_name GameHost
extends Node
## The authoritative host: seats, robot crew, the mission, the briefing/ready-up, the debrief and saved progress.
## It never touches the network: it emits snapshots and events, and Net delivers them.

signal snap_ready(peer: int, data: Dictionary)
signal event_ready(peer: int, data: Dictionary)   # peer 0 = everyone
signal lobby_changed

const IGOR_COOLDOWN: float = 5.0

var world: World = null
var mission: Mission = null
var mission_id: String = "lesson"
var phase: String = "lobby"
var peers: Dictionary = {}          # id -> {name, seats: [], active, gone}
var seat_owner: Dictionary = {}     # seat -> peer id
var bots: Dictionary = {}           # station -> Bot
var bot_on: Dictionary = {}         # station -> bool (fill with a robot when no human)
var admin: int = 1
var accum: float = 0.0
var snap_accum: float = 0.0
var igor_cd: float = 0.0
var igor_idle: float = 40.0
var briefing: Dictionary = {}
var debrief: Dictionary = {}
var phase_t: float = 0.0
var time_scale: float = 1.0
var paused: bool = false
var tally: Dictionary = {}          # per-mission fun stats for awards
var seed_value: int = 0
var autopilot: bool = false        # tests/screenshots: robots drive every station, even ones humans hold

func _init() -> void:
	for s in K.STATIONS:
		bot_on[s] = true

# ================================================================ peers & seats

func add_peer(id: int, pname: String) -> void:
	var seats: Array = []
	var old_id: int = 0
	for pid in peers.keys():
		if peers[pid].get("gone", false) and peers[pid].name == pname:
			old_id = pid
	if old_id != 0:
		seats = peers[old_id].seats.duplicate()
		peers.erase(old_id)
		for s in seats.duplicate():
			if not seat_owner.has(s) or int(seat_owner[s]) == old_id:
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
		if int(seat_owner.get(s, 0)) == id:
			seat_owner.erase(s)
	if phase == "lobby":
		peers.erase(id)
	else:
		peers[id].gone = true
		peers[id].active = ""
	if admin == id:
		admin = 0
		for pid in peers.keys():
			if not peers[pid].gone:
				admin = pid
				break
	_sync_bots()
	lobby_changed.emit()
	_send_lobby()

func claim(peer: int, seat: String) -> bool:
	if not peers.has(peer) or not (seat in K.SEATS):
		return false
	if seat_owner.has(seat) and int(seat_owner[seat]) != peer:
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
	if int(seat_owner.get(seat, 0)) == peer:
		seat_owner.erase(seat)
	peers[peer].seats.erase(seat)
	if peers[peer].active == seat:
		peers[peer].active = peers[peer].seats[0] if not peers[peer].seats.is_empty() else ""
	if world != null and seat in K.STATIONS:
		_release_controls(seat)
	_sync_bots()
	_send_lobby()

func set_active(peer: int, seat: String) -> void:
	if not peers.has(peer) or not (seat in peers[peer].seats):
		return
	var old: String = peers[peer].active
	if old != seat and world != null and old in K.STATIONS:
		_release_controls(old)
	peers[peer].active = seat

func _release_controls(st: String) -> void:
	## let go of anything held down when a player leaves a station (sticky dials stay put)
	if world == null:
		return
	match st:
		"weapons":
			Intents.apply(world, "weapons", "fire", false)
		"sensors":
			Intents.apply(world, "sensors", "scan", false)
		"shields":
			Intents.apply(world, "shields", "tractor", false)
			Intents.apply(world, "shields", "pet", false)
			Intents.apply(world, "shields", "tin", false)
		"engineer":
			Intents.apply(world, "engineer", "repair", false)
		"engines":
			Intents.apply(world, "engines", "boost", false)

func humans_with_seats() -> Array:
	var out: Array = []
	for pid in peers.keys():
		if not peers[pid].gone and not peers[pid].seats.is_empty():
			out.append(pid)
	return out

func seat_is_bot(seat: String) -> bool:
	return bots.has(seat)

func _sync_bots() -> void:
	for s in K.STATIONS:
		var human: bool = seat_owner.has(s) and not peers.get(seat_owner[s], {}).get("gone", false) and not autopilot
		var want: bool = (not human) and bool(bot_on.get(s, true))
		if want and not bots.has(s):
			bots[s] = Bot.new(s)
		elif not want and bots.has(s):
			bots.erase(s)
			if world != null:
				_release_controls(s)

# ================================================================ lobby

func lobby_dict() -> Dictionary:
	var seats: Dictionary = {}
	for s in K.SEATS:
		var o: int = int(seat_owner.get(s, 0))
		seats[s] = {"owner": o, "owner_name": peers[o].name if peers.has(o) else "", "bot": bots.has(s),
			"bot_on": bool(bot_on.get(s, true)) if s != "captain" else false}
	var pl: Dictionary = {}
	for pid in peers.keys():
		pl[pid] = {"name": peers[pid].name, "seats": peers[pid].seats, "gone": peers[pid].gone}
	var missions: Array = []
	for id in Missions.ORDER:
		missions.append({"id": id, "num": Missions.INFO[id].num, "title": Missions.INFO[id].title, "new": Missions.INFO[id].new,
			"unlocked": Progress.is_unlocked(id), "stars": Progress.stars(id)})
	return {"t": "lobby", "seats": seats, "peers": pl, "mission": mission_id, "missions": missions, "phase": phase, "admin": admin}

func _send_lobby() -> void:
	_event(0, lobby_dict())

func set_option(key: String, val: Variant) -> void:
	if phase != "lobby":
		return
	match key:
		"mission":
			if str(val) in Missions.ORDER and Progress.is_unlocked(str(val)):
				mission_id = str(val)
		"bot_on":
			if val is Dictionary:
				bot_on[str(val.get("seat", ""))] = bool(val.get("on", true))
				_sync_bots()
		"unlock_all":
			Progress.unlock_all()
	_send_lobby()

# ================================================================ flow

func start_game(sd: int = 0) -> void:
	seed_value = sd
	_begin(mission_id)
	_event(0, {"t": "started"})

func _begin(id: String) -> void:
	mission_id = id
	world = World.new(seed_value)
	mission = Missions.make(id)
	mission.setup(world)
	_sync_bots()
	for b in bots.values():
		b.think_t = 0.0
	tally = {"inputs": {}, "kills": 0, "bumps": 0}
	debrief = {}
	phase = "briefing"
	phase_t = 0.0
	briefing = {"ready": {}, "countdown": -1.0, "t": 0.0}
	_event(0, {"t": "briefing", "title": mission.title, "num": mission.num})

func _launch() -> void:
	phase = "mission"
	phase_t = 0.0
	briefing = {}
	igor_cd = 3.0
	igor_idle = 40.0
	_event(0, {"t": "mission_start", "title": mission.title})
	_event(0, {"t": "step", "text": mission.cur().get("text", ""), "n": 0})

func _briefing_tick(dt: float) -> void:
	briefing["t"] = float(briefing.get("t", 0.0)) + dt
	var cd: float = float(briefing.get("countdown", -1.0))
	if cd >= 0.0:
		cd -= dt
		briefing["countdown"] = cd
		if cd <= 0.0:
			_launch()
		return
	var humans: Array = humans_with_seats()
	var all_ready: bool = not humans.is_empty()
	for pid in humans:
		if not bool(briefing["ready"].get(pid, false)):
			all_ready = false
	if humans.is_empty():
		all_ready = float(briefing["t"]) > 1.5
	if all_ready:
		briefing["countdown"] = 3.0
		_event(0, {"t": "countdown"})

func set_ready(peer: int, on: bool) -> void:
	if phase != "briefing":
		return
	briefing["ready"][peer] = on
	if not on and float(briefing.get("countdown", -1.0)) >= 0.0:
		briefing["countdown"] = -1.0

func force_launch() -> void:
	if phase == "briefing":
		_launch()

func _finish(ok: bool) -> void:
	phase = "debrief"
	phase_t = 0.0
	for st in K.STATIONS:
		_release_controls(st)
	var stars: int = mission.stars() if ok else 0
	var opened: bool = Progress.record(mission_id, stars) if ok else false
	var idx: int = Missions.ORDER.find(mission_id)
	var next_id: String = Missions.ORDER[idx + 1] if idx + 1 < Missions.ORDER.size() else ""
	debrief = {"ok": ok, "stars": stars, "reason": mission.reason, "title": mission.title, "num": mission.num, "time": mission.t,
		"par": mission.par, "hull": world.ship.hull, "awards": _awards(ok), "next": next_id if (ok and next_id != "" and Progress.is_unlocked(next_id)) else "",
		"opened": opened, "final": ok and next_id == "", "stats": world.stats.duplicate()}
	_igor("mission_done" if ok else "mission_failed", {}, 3)
	_event(0, {"t": "debrief", "ok": ok})

func next_mission() -> void:
	if phase == "debrief" and str(debrief.get("next", "")) != "":
		_begin(str(debrief.next))

func retry() -> void:
	if phase == "debrief":
		_begin(mission_id)

func to_lobby() -> void:
	phase = "lobby"
	world = null
	mission = null
	for pid in peers.keys():
		if peers[pid].gone:
			peers.erase(pid)
	_send_lobby()
	_event(0, {"t": "to_lobby"})

# ================================================================ messages

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
		"opt":
			if peer == admin:
				set_option(str(d.get("key", "")), d.get("val"))
		"start":
			if peer == admin and phase == "lobby":
				start_game()
		"ready":
			set_ready(peer, bool(d.get("on", true)))
		"launch":
			if _is_boss(peer) and phase == "briefing":
				briefing["countdown"] = 3.0 if float(briefing.get("countdown", -1.0)) < 0.0 else minf(float(briefing.countdown), 3.0)
		"next":
			if _is_boss(peer):
				next_mission()
		"retry":
			if _is_boss(peer):
				retry()
		"lobby":
			if _is_boss(peer):
				to_lobby()

func _is_boss(peer: int) -> bool:
	return peer == admin or int(seat_owner.get("captain", 0)) == peer

func _intent(peer: int, station: String, key: String, val: Variant) -> void:
	if world == null or phase != "mission" or not (station in K.STATIONS):
		return
	if int(seat_owner.get(station, 0)) != peer or peers[peer].active != station:
		return
	var inputs: Dictionary = tally.inputs
	inputs[station] = int(inputs.get(station, 0)) + 1
	Intents.apply(world, station, key, val)

# ================================================================ the loop

func _process(delta: float) -> void:
	if paused:
		return
	accum += delta * time_scale
	var steps: int = 0
	while accum >= K.DT and steps < 8:
		accum -= K.DT
		sim_step(K.DT)
		steps += 1
	snap_accum += delta
	if snap_accum >= 1.0 / K.SNAP_HZ:
		snap_accum = 0.0
		send_snapshots()

func sim_step(dt: float) -> void:
	phase_t += dt
	if world == null:
		return
	match phase:
		"briefing":
			_briefing_tick(dt)
			return
		"debrief":
			# nobody human to press the button: carry on by ourselves (robot-only runs and tests)
			if humans_with_seats().is_empty() and phase_t > 4.0:
				if str(debrief.get("next", "")) != "":
					next_mission()
				else:
					to_lobby()
			return
		"mission":
			pass
		_:
			return
	for b in bots.values():
		b.tick(world, dt)
	world.step(dt)
	_drain_events()
	igor_cd -= dt
	igor_idle -= dt
	if igor_idle <= 0.0:
		igor_idle = 50.0
		_igor("idle", {}, 0)
	if mission.done:
		_finish(true)
	elif mission.failed:
		_finish(false)

func advance(seconds: float) -> void:
	## for tests: run the host forward without real time passing
	var n: int = int(seconds / K.DT)
	for i in n:
		sim_step(K.DT)

func _drain_events() -> void:
	var evs: Array = world.events.duplicate()
	world.events.clear()
	for ev in evs:
		var type: String = str(ev[0])
		var d: Dictionary = ev[1]
		mission.on_event(type, d)
		_on_world_event(type, d)

func _on_world_event(type: String, d: Dictionary) -> void:
	match type:
		"broke":
			var why: String = str(d.get("why", ""))
			if bool(d.get("fire", false)):
				_igor("fire", {"name": str(d.name).to_lower()}, 2)
				_event(0, {"t": "fx", "fx": "alarm"})
			elif "overheated" in why and str(d.sys).begins_with("engine"):
				_igor("overheat", {"name": d.name}, 2)
			elif "jammed" in why:
				_igor("jam", {}, 2)
			elif "Pudding" in why:
				_igor("pudding_chew", {"name": str(d.name).to_lower()}, 2)
			else:
				_igor("broke", {"name": d.name}, 1)
			_event(0, {"t": "toast", "text": "%s %s!" % [d.name, "is on FIRE" if bool(d.get("fire", false)) else "broke"], "kind": "bad", "who": "engineer"})
		"fire_out":
			_igor("fire_out", {"name": str(d.name).to_lower()}, 1)
		"repaired":
			_igor("repaired", {"name": d.name}, 1)
			_event(0, {"t": "toast", "text": "%s fixed" % d.name, "kind": "good", "who": "engineer"})
		"blackout":
			_igor("blackout", {}, 3)
			_event(0, {"t": "fx", "fx": "blackout"})
		"power_back":
			_igor("power_back", {}, 2)
		"pudding_out":
			_igor("pudding_out", {}, 3)
			_event(0, {"t": "toast", "text": "PUDDING ESCAPED!", "kind": "bad", "who": "shields"})
		"pudding_back":
			_igor("pudding_back", {}, 2)
		"bump":
			tally["bumps"] = int(tally.get("bumps", 0)) + 1
			_igor("bump", {"name": str(d.get("name", "it"))}, 1)
			_event(0, {"t": "fx", "fx": "bump"})
		"friendly_fire":
			_igor("friendly_fire", {"name": str(d.get("name", "it"))}, 2)
		"roll":
			_igor("roll", {}, 0)
		"latched":
			_igor("latched", {}, 2)
		"unlatched":
			_igor("unlatched", {}, 1)
		"ent_destroyed":
			tally["kills"] = int(tally.get("kills", 0)) + 1
			_event(0, {"t": "fx", "fx": "boom"})
			if str(d.get("kind", "")) in ["drone", "grabber", "cruiser", "target"]:
				_igor("kill", {}, 0)
		"ent_exploded":
			_event(0, {"t": "fx", "fx": "boom"})
		"hit":
			_event(0, {"t": "fx", "fx": "hit"})
		"scanned":
			_event(0, {"t": "toast", "text": "Scanned: %s" % str(d.get("name", "?")), "kind": "info", "who": "sensors"})
		"weak_found":
			_igor("weak_found", {}, 2)
		"torp_hit":
			_igor("torp_hit" if bool(d.get("weak", false)) else "torp_bounce", {}, 2)
		"hail_heard":
			_igor("hail_heard", {}, 1)
		"collected":
			_igor("collected", {"name": str(d.get("name", "it"))}, 1)
		"step_done":
			_igor("step_done", {}, 1)
			_event(0, {"t": "fx", "fx": "ding"})
		"step":
			_event(0, {"t": "step", "text": str(d.get("text", "")), "n": int(d.get("n", 0))})
		"story":
			_event(0, {"t": "igor", "text": str(d.get("text", "")), "who": str(d.get("who", "igor")), "prio": 3, "speak": true})
			igor_cd = IGOR_COOLDOWN
		"ring":
			_event(0, {"t": "fx", "fx": "ding"})

func _igor(key: String, ctx: Dictionary = {}, prio: int = 1) -> void:
	if prio < 3 and igor_cd > 0.0:
		return
	var text: String = Igor.line(key, ctx)
	if text == "":
		return
	igor_cd = IGOR_COOLDOWN
	igor_idle = 50.0
	_event(0, {"t": "igor", "text": text, "prio": prio, "who": "igor", "speak": prio >= 2})

func _awards(ok: bool) -> Array:
	var st: Dictionary = world.stats
	var out: Array = []
	if int(st.repairs) >= 2:
		out.append({"title": "Duct Tape Hero", "seat": "engineer", "text": "%d repairs" % int(st.repairs)})
	if int(st.blocked) >= 4:
		out.append({"title": "The Wall", "seat": "shields", "text": "%d hits blocked" % int(st.blocked)})
	if int(st.shots) > 0 and float(st.hits) / float(st.shots) > 0.45 and int(st.hits) >= 3:
		out.append({"title": "Sharpshooter", "seat": "weapons", "text": "%d%% of shots hit" % int(100.0 * float(st.hits) / float(st.shots))})
	if int(st.scans) >= 3:
		out.append({"title": "Eagle Eye", "seat": "sensors", "text": "%d contacts scanned" % int(st.scans)})
	if int(tally.get("bumps", 0)) == 0 and ok:
		out.append({"title": "Steady Hands", "seat": "helm", "text": "didn't bump into anything"})
	if int(st.dodges) >= 2:
		out.append({"title": "Barrel Roll Champion", "seat": "helm", "text": "%d shots dodged" % int(st.dodges)})
	if world.feat("heat") and world.ship.engines_working() == 2 and ok:
		out.append({"title": "Cool Customer", "seat": "engines", "text": "never cooked the engines"})
	if int(st.friendly_fire) > 0:
		out.append({"title": "IGOR's Disappointment", "seat": "weapons", "text": "shot a friend"})
	if int(st.overloads) > 0:
		out.append({"title": "Lights Out", "seat": "engineer", "text": "%d blackout%s" % [int(st.overloads), "" if int(st.overloads) == 1 else "s"]})
	if world.feat("pudding") and int(st.escapes) == 0 and ok:
		out.append({"title": "Pudding Whisperer", "seat": "shields", "text": "Pudding stayed calm"})
	return out.slice(0, 5)

# ================================================================ snapshots

func _event(peer: int, data: Dictionary) -> void:
	event_ready.emit(peer, data)

func send_snapshots() -> void:
	if world == null or phase == "lobby":
		return
	for pid in peers.keys():
		if peers[pid].gone:
			continue
		snap_ready.emit(pid, snapshot_for(pid))

func snapshot_for(peer: int) -> Dictionary:
	var p: Dictionary = peers[peer]
	var act: String = str(p.active)
	var d: Dictionary = {"phase": phase, "active": act, "seats": p.seats, "you": peer}
	d["common"] = Snapshots.common(world, act)
	match act:
		"captain":
			d["view"] = Snapshots.captain(world)
		"helm":
			d["view"] = Snapshots.helm(world)
		"engines":
			d["view"] = Snapshots.engines(world)
		"weapons":
			d["view"] = Snapshots.weapons(world)
		"sensors":
			d["view"] = Snapshots.sensors(world)
		"shields":
			d["view"] = Snapshots.shields(world)
		"engineer":
			d["view"] = Snapshots.engineer(world)
		_:
			d["view"] = Snapshots.captain(world) if p.seats.is_empty() else {}
	d["phase_data"] = _phase_data(peer)
	return d

func _phase_data(peer: int) -> Dictionary:
	match phase:
		"briefing":
			return {"brief": mission.briefing(), "countdown": float(briefing.get("countdown", -1.0)), "roster": roster(peer),
				"you_ready": bool(briefing.get("ready", {}).get(peer, false)), "can_launch": _is_boss(peer)}
		"debrief":
			var dd: Dictionary = debrief.duplicate()
			dd["can_continue"] = _is_boss(peer)
			return dd
	return {}

func roster(for_peer: int = 0) -> Array:
	var out: Array = []
	for s in K.SEATS:
		var o: int = int(seat_owner.get(s, 0))
		var who: String = "Empty"
		var kind: String = "empty"
		if o != 0 and peers.has(o) and not peers[o].gone:
			who = "You" if o == for_peer else str(peers[o].name)
			kind = "human"
		elif bots.has(s):
			who = "Robot"
			kind = "bot"
		out.append({"seat": s, "who": who, "kind": kind, "ready": kind != "human" or bool(briefing.get("ready", {}).get(o, false)),
			"mine": o == for_peer})
	return out
