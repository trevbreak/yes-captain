class_name GameHost
extends Node
## The authoritative host: seats, robot crew, the mission, the briefing/ready-up, the debrief and saved progress.
## It never touches the network: it emits snapshots and events, and Net delivers them.

signal snap_ready(peer: int, data: Dictionary)
signal event_ready(peer: int, data: Dictionary)   # peer 0 = everyone
signal lobby_changed
signal kicked(peer: int)

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
var career: Progress = null         # this crew's unlocked missions and stars
var room_name: String = ""          # set by the Hub on a server
var room_code: String = ""
var voice: bool = false             # the crew is remote: microphones on
var mode: String = "career"         # "career" (training missions) or "shift" (three dealt jobs)
var shift_always: bool = false      # online rooms: the Shift is open from the start (and is what they start on)
var shift: Dictionary = {}          # the shift in progress: jobs done, money earned, parts fitted
var lobby_line: String = "IGOR is counting the crew. IGOR keeps getting a low number."
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
	for s in K.STATIONS:
		bot_on[s] = true
	career = Progress.local()

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
	pname = _unique_name(pname, id)
	peers[id] = {"name": pname, "seats": seats, "active": seats[0] if not seats.is_empty() else "", "gone": false, "ready": false}
	_lobby_say("joined", {"who": pname})
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
		_lobby_say("left", {"who": str(peers[id].name)})
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

func _unique_name(pname: String, id: int) -> String:
	var n: int = 1
	var out: String = pname
	var clash: bool = true
	while clash:
		clash = false
		for pid in peers.keys():
			if pid != id and not peers[pid].get("gone", false) and str(peers[pid].name) == out:
				clash = true
		if clash:
			n += 1
			out = "%s %d" % [pname, n]
	return out

func live_peers() -> Array:
	var out: Array = []
	for pid in peers.keys():
		if not peers[pid].get("gone", false):
			out.append(pid)
	return out

func claim_all(peer: int, seats: Array) -> bool:
	## take several seats at once (a pair), or none of them
	if not peers.has(peer) or seats.size() > K.SEATS.size():
		return false
	for s in seats:
		if not (s is String) or not (s in K.SEATS) or (seat_owner.has(s) and int(seat_owner[s]) != peer):
			return false
	for s2 in seats:
		claim(peer, s2)
	return true

func kick(peer: int) -> void:
	if peers.has(peer) and peer != admin:
		_event(peer, {"t": "kicked"})
		remove_peer(peer)
		peers.erase(peer)
		kicked.emit(peer)

func start_problem() -> String:
	## why the host can't start yet ("" = good to go)
	var humans: Array = live_peers()
	if humans.is_empty():
		return ""
	var cap: int = int(seat_owner.get("captain", 0))
	if cap == 0 or not peers.has(cap) or peers[cap].get("gone", false):
		return "Somebody has to be the Captain."
	for pid in humans:
		if pid != admin and not peers[pid].seats.is_empty() and not bool(peers[pid].get("ready", false)):
			return "Waiting for %s to be ready." % str(peers[pid].name)
	return ""

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
		pl[pid] = {"name": peers[pid].name, "seats": peers[pid].seats, "gone": peers[pid].gone, "ready": bool(peers[pid].get("ready", false))}
	var missions: Array = []
	for id in Missions.ORDER:
		missions.append({"id": id, "num": Missions.INFO[id].num, "title": Missions.INFO[id].title, "new": Missions.INFO[id].new,
			"unlocked": career.is_unlocked(id), "stars": career.stars(id)})
	var prob: String = start_problem()
	var held: Array = Deck.cards(career)
	var names: Array = []
	for c in held.slice(maxi(0, held.size() - 4)):
		names.append(str(Deck.describe(c).title))
	return {"t": "lobby", "seats": seats, "peers": pl, "mission": mission_id, "missions": missions, "phase": phase, "admin": admin,
		"room": {"name": room_name, "code": room_code}, "voice": voice, "problem": prob, "mode": mode,
		"shift": {"open": shift_open(), "rent": Deck.rent(career), "shifts": career.shifts, "best": career.best_pay,
			"cards": held.size(), "of": Deck.ORDER.size(), "latest": names, "needs": Deck.SHIFT_UNLOCKS_AT - 1},
		"igor": lobby_line}

func shift_open() -> bool:
	## solo and LAN crews earn the Shift with two training missions; online rooms have it from the start
	return shift_always or Deck.shift_open(career)

func _send_lobby() -> void:
	_event(0, lobby_dict())

func _lobby_say(key: String, ctx: Dictionary = {}) -> void:
	if phase == "lobby":
		var t: String = Igor.line(key, ctx)
		if t != "":
			lobby_line = t

func set_option(key: String, val: Variant) -> void:
	if phase != "lobby":
		return
	match key:
		"mission":
			if str(val) in Missions.ORDER and career.is_unlocked(str(val)):
				mission_id = str(val)
				mode = "career"
		"mode":
			if str(val) == "shift" and shift_open():
				mode = "shift"
			elif str(val) == "career":
				mode = "career"
		"bot_on":
			if val is Dictionary:
				bot_on[str(val.get("seat", ""))] = bool(val.get("on", true))
				_sync_bots()
		"voice":
			voice = bool(val)
		"unlock_all":
			career.unlock_all()
			for id in Missions.ORDER:
				if career.stars(id) == 0:
					career.star_map[id] = 1
			career.save()
			_send_career()
	_send_lobby()

# ================================================================ flow

func start_game(sd: int = 0) -> void:
	seed_value = sd
	rng.seed = sd if sd != 0 else int(Time.get_ticks_usec()) ^ int(randi())
	if mode == "shift" and shift_open():
		_shift_start()
	else:
		shift = {}
		_begin(mission_id)
	_event(0, {"t": "started"})

func _begin(id: String) -> void:
	mission_id = id
	world = World.new(seed_value)
	mission = Missions.make(id)
	mission.setup(world)
	_enter_briefing()

func _enter_briefing() -> void:
	_sync_bots()
	for b in bots.values():
		b.think_t = 0.0
	tally = {"inputs": {}, "kills": 0, "bumps": 0, "calm": 0.0, "said": {}}
	debrief = {}
	phase = "briefing"
	phase_t = 0.0
	briefing = {"ready": {}, "countdown": -1.0, "t": 0.0}
	_event(0, {"t": "briefing", "title": mission.title, "num": mission.num})

# ---------------------------------------------------------------- the Shift

func _shift_start() -> void:
	var card: Dictionary = Deck.describe(Deck.newest(career))
	if career.shifts == 0:
		card = {"kind": "NEW TODAY", "title": "The Shift, and glitches", "who": ["engineer"],
			"text": "A shift is three jobs. The depot wants its rent by the end. And from now on the ship GLITCHES: something stops behaving and nobody is told what. The Engineer finds the room, reads IGOR's manual OUT LOUD, and somebody else has to do what it says while the Engineer holds REPAIR."}
	shift = {"n": 0, "of": Deck.JOBS_PER_SHIFT, "earned": 0, "rent": Deck.rent(career), "mods": {}, "parts": [], "history": [],
		"card": card, "done": false, "tasks": []}
	_deal()

func _deal() -> void:
	## put three jobs on the board (and, between jobs, two bodged parts IGOR found)
	phase = "board"
	phase_t = 0.0
	world = null
	mission = null
	debrief = {}
	shift["offers"] = Jobs.offers(rng, career, shift.tasks)
	shift["votes"] = {}
	shift["part_offers"] = Deck.part_offers(rng, Deck.features_for(career), shift.parts) if int(shift.n) > 0 else []
	shift["part_pick"] = ""
	shift["line"] = Igor.line("shift_start", {"rent": "£%d" % int(shift.rent)}) if int(shift.n) == 0 else Igor.line("board")
	_event(0, {"t": "board"})
	_event(0, {"t": "igor", "text": str(shift.line), "prio": 2, "who": "igor", "speak": true})

func _board_data(peer: int) -> Dictionary:
	var votes: Dictionary = {}
	for pid in shift.get("votes", {}).keys():
		if peers.has(pid) and not peers[pid].gone:
			var i: int = int(shift.votes[pid])
			if not votes.has(i):
				votes[i] = []
			(votes[i] as Array).append({"name": str(peers[pid].name), "seat": str(peers[pid].seats[0]) if not peers[pid].seats.is_empty() else "captain"})
	var parts: Array = []
	for p in shift.get("part_offers", []):
		parts.append({"id": p.id, "name": p.name, "good": p.good, "bad": p.bad})
	var fitted: Array = []
	for pid2 in shift.get("parts", []):
		fitted.append(str(Deck.part(str(pid2)).get("name", pid2)))
	return {"offers": shift.get("offers", []), "votes": votes, "my_vote": int(shift.get("votes", {}).get(peer, -1)), "n": int(shift.n), "of": int(shift.of),
		"earned": int(shift.earned), "rent": int(shift.rent), "can_pick": _is_boss(peer), "parts": parts, "part_pick": str(shift.get("part_pick", "")),
		"fitted": fitted, "line": str(shift.get("line", "")), "history": shift.get("history", []),
		"places": Deck.PLACES, "twists": Deck.TWISTS}

func _vote(peer: int, i: int) -> void:
	if phase == "board" and i >= 0 and i < (shift.offers as Array).size():
		shift.votes[peer] = i

func _pick_part(id: String) -> void:
	if phase != "board":
		return
	for p in shift.get("part_offers", []):
		if str(p.id) == id:
			shift["part_pick"] = "" if str(shift.part_pick) == id else id

func _pick_job(i: int) -> void:
	if phase != "board" or i < 0 or i >= (shift.offers as Array).size():
		return
	var pid: String = str(shift.get("part_pick", ""))
	if pid != "":
		var part: Dictionary = Deck.part(pid)
		(shift.parts as Array).append(pid)
		for k in part.mods.keys():
			if k == "hull":
				shift.mods[k] = float(shift.mods.get(k, 0.0)) + float(part.mods[k])
			else:
				shift.mods[k] = float(shift.mods.get(k, 1.0)) * float(part.mods[k])
	var spec: Dictionary = shift.offers[i]
	(shift.tasks as Array).append(str(spec.task))
	var offers: Array = shift.offers
	var pick_line: String = ""
	if offers.size() > 1 and int(spec.danger) == int(offers[offers.size() - 1].danger) and int(spec.danger) >= 3:
		pick_line = Igor.line("board_spicy")
	elif offers.size() > 1 and i == 0:
		pick_line = Igor.line("board_safe")
	world = World.new(int(spec.seed))
	var job: Jobs.Job = Jobs.make(spec, career, int(shift.n) + 1)
	job.mods = (shift.mods as Dictionary).duplicate()
	mission = job
	mission.setup(world)
	_enter_briefing()
	if pid != "":
		_event(0, {"t": "igor", "text": Igor.line("part", {"name": str(Deck.part(pid).name)}), "prio": 2, "who": "igor", "speak": false})
	elif pick_line != "":
		_event(0, {"t": "igor", "text": pick_line, "prio": 2, "who": "igor", "speak": false})

# ---------------------------------------------------------------- briefing -> mission -> debrief

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
	var awards: Array = _awards(ok)
	var titles: Array = []
	for a in awards:
		titles.append(str(a.title))
	debrief = {"ok": ok, "stars": stars, "reason": mission.reason, "title": mission.title, "num": mission.num, "time": mission.t,
		"par": mission.par, "hull": world.ship.hull, "awards": awards, "next": "", "opened": false, "final": false,
		"stats": world.stats.duplicate(), "job": mission.is_job()}
	if mission.is_job():
		_finish_job(ok, titles)
	else:
		var opened: bool = career.record(mission_id, stars) if ok else false
		var idx: int = Missions.ORDER.find(mission_id)
		var next_id: String = Missions.ORDER[idx + 1] if idx + 1 < Missions.ORDER.size() else ""
		debrief["next"] = next_id if (ok and next_id != "" and career.is_unlocked(next_id)) else ""
		debrief["opened"] = opened
		debrief["final"] = ok and next_id == ""
		debrief["shift_opened"] = opened and career.unlocked() == Deck.SHIFT_UNLOCKS_AT and not shift_always
		debrief["said"] = Igor.line("mission_done" if ok else "mission_failed", _names())
		career.add_stickers(titles)
		_event(0, {"t": "igor", "text": str(debrief.said), "prio": 3, "who": "igor", "speak": true})
	_event(0, {"t": "debrief", "ok": ok})
	_send_career()

func _finish_job(ok: bool, titles: Array) -> void:
	var res: Dictionary = mission.result()
	shift.earned = int(shift.earned) + int(res.pay)
	shift.n = int(shift.n) + 1
	(shift.history as Array).append({"title": mission.title, "pay": int(res.pay), "ok": ok})
	var last: bool = int(shift.n) >= int(shift.of)
	debrief["lines"] = res.lines
	debrief["pay"] = int(res.pay)
	debrief["earned"] = int(shift.earned)
	debrief["rent"] = int(shift.rent)
	debrief["n"] = int(shift.n)
	debrief["of"] = int(shift.of)
	debrief["shift_done"] = last
	debrief["history"] = shift.history
	career.add_stickers(titles)
	var said: String = Igor.line("mission_done" if ok else "mission_failed", _names())
	if last:
		shift.done = true
		var made: bool = int(shift.earned) >= int(shift.rent)
		debrief["made_rent"] = made
		said = Igor.line("rent_made") if made else Igor.line("rent_missed", {"short": "£%d" % (int(shift.rent) - int(shift.earned))})
		var review: Array = []
		for s in K.SEATS:
			var o: int = int(seat_owner.get(s, 0))
			if o != 0 and peers.has(o) and not peers[o].gone:
				review.append({"seat": s, "who": str(peers[o].name), "text": Igor.review(s)})
		debrief["review"] = review.slice(0, 4)
		career.shifts += 1
		career.best_pay = maxi(career.best_pay, int(shift.earned))
		if made:
			career.add_stickers(["Made Rent"])
		career.save()
		debrief["card"] = Deck.describe(Deck.newest(career))
	debrief["said"] = said
	_event(0, {"t": "igor", "text": said, "prio": 3, "who": "igor", "speak": true})

func _send_career() -> void:
	## the room's host keeps the career in their own browser
	if admin != 0:
		_event(admin, {"t": "career", "data": career.to_dict()})

func next_mission() -> void:
	if phase != "debrief":
		return
	if bool(debrief.get("job", false)):
		if bool(shift.get("done", false)):
			to_lobby()
		else:
			_deal()
	elif str(debrief.get("next", "")) != "":
		_begin(str(debrief.next))

func retry() -> void:
	if phase == "debrief" and not bool(debrief.get("job", false)):
		_begin(mission_id)

func to_lobby() -> void:
	phase = "lobby"
	world = null
	mission = null
	shift = {}
	for pid in peers.keys():
		if peers[pid].gone:
			peers.erase(pid)
		else:
			peers[pid].ready = false
	if mode == "career" and career.is_unlocked(mission_id):
		# line up the next mission the crew hasn't flown yet
		var idx: int = Missions.ORDER.find(mission_id)
		if career.stars(mission_id) > 0 and idx + 1 < Missions.ORDER.size() and career.is_unlocked(Missions.ORDER[idx + 1]):
			mission_id = Missions.ORDER[idx + 1]
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
			if d.get("seats") is Array:
				claim_all(peer, d.seats)
			else:
				claim(peer, str(d.get("seat", "")))
		"release_all":
			for s in peers[peer].seats.duplicate():
				release(peer, str(s))
		"lobby_ready":
			peers[peer].ready = bool(d.get("on", true))
			_send_lobby()
		"kick":
			var who: Variant = d.get("peer")
			if peer == admin and (who is int or who is float):
				kick(int(who))
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
				var prob: String = start_problem()
				if prob == "" or (bool(d.get("force", false)) and not prob.begins_with("Somebody")):
					start_game()
				else:
					_event(peer, {"t": "toast", "text": prob, "kind": "bad"})
		"ready":
			set_ready(peer, bool(d.get("on", true)))
		"launch":
			if _is_boss(peer) and phase == "briefing":
				briefing["countdown"] = 3.0 if float(briefing.get("countdown", -1.0)) < 0.0 else minf(float(briefing.countdown), 3.0)
		"vote":
			if not peers[peer].seats.is_empty():
				_vote(peer, _int(d.get("i")))
		"part":
			if _is_boss(peer):
				_pick_part(str(d.get("id", "")))
		"pick":
			if _is_boss(peer):
				_pick_job(_int(d.get("i")))
		"next":
			if _is_boss(peer):
				next_mission()
		"retry":
			if _is_boss(peer):
				retry()
		"shuffle":
			if _is_boss(peer) and phase in ["debrief", "board", "lobby"]:
				shuffle_seats()
		"lobby":
			if _is_boss(peer):
				to_lobby()

static func _int(v: Variant) -> int:
	return int(v) if (v is int or v is float) else -1

func _is_boss(peer: int) -> bool:
	return peer == admin or int(seat_owner.get("captain", 0)) == peer

func shuffle_seats() -> void:
	## everybody moves one place round, so everyone gets a go at being Captain
	var humans: Array = humans_with_seats()
	if humans.size() < 2:
		return
	humans.sort()
	var held: Array = []
	for pid in humans:
		held.append(peers[pid].seats.duplicate())
	for i in humans.size():
		var pid2: int = humans[i]
		var seats: Array = held[(i + 1) % humans.size()]
		peers[pid2].seats = seats
		peers[pid2].active = seats[0] if not seats.is_empty() else ""
		for s in seats:
			seat_owner[s] = pid2
	_sync_bots()
	_send_lobby()
	_event(0, {"t": "toast", "text": "All change! Check your new seat.", "kind": "info"})

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
	if phase == "board":
		# nobody human to choose: carry on by ourselves (robot-only runs and tests)
		if humans_with_seats().is_empty() and phase_t > 2.0:
			_pick_job(0)
		return
	if world == null:
		return
	match phase:
		"briefing":
			_briefing_tick(dt)
			return
		"debrief":
			if humans_with_seats().is_empty() and phase_t > 4.0:
				if bool(debrief.get("job", false)) or str(debrief.get("next", "")) != "":
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
	_commentary(dt)
	if mission.done:
		_finish(true)
	elif mission.failed:
		_finish(false)

func advance(seconds: float) -> void:
	## for tests: run the host forward without real time passing
	var n: int = int(seconds / K.DT)
	for i in n:
		sim_step(K.DT)

func _commentary(dt: float) -> void:
	## the things IGOR says because of how it's going, rather than because of one event
	igor_cd -= dt
	igor_idle -= dt
	tally["calm"] = float(tally.get("calm", 0.0)) + dt
	var said: Dictionary = tally.said
	if float(tally.calm) > 60.0 and not said.has("quiet"):
		said["quiet"] = true
		_igor("quiet", {}, 1)
	if world.ship.hull < 34.0 and not said.has("hull"):
		said["hull"] = true
		_igor("hull_low", {}, 2)
	if mission.t > mission.par and not said.has("late"):
		said["late"] = true
		_igor("late", {}, 1)
	if igor_idle <= 0.0:
		igor_idle = 45.0
		_igor("idle", {}, 0)

func _drain_events() -> void:
	var evs: Array = world.events.duplicate()
	world.events.clear()
	for ev in evs:
		var type: String = str(ev[0])
		var d: Dictionary = ev[1]
		mission.on_event(type, d)
		_on_world_event(type, d)

func _who(seat: String) -> String:
	## the player in a seat by name, or the seat's own name when a robot has it
	var o: int = int(seat_owner.get(seat, 0))
	if o != 0 and peers.has(o) and not peers[o].gone:
		return str(peers[o].name)
	return K.seat_name(seat)

func _names() -> Dictionary:
	return {"eng": _who("engineer"), "shd": _who("shields"), "sns": _who("sensors"), "wpn": _who("weapons"), "hlm": _who("helm"),
		"egn": _who("engines"), "cap": _who("captain")}

func _on_world_event(type: String, d: Dictionary) -> void:
	match type:
		"broke":
			tally["calm"] = 0.0
			var why: String = str(d.get("why", ""))
			var owner_seat: String = str(Ship.SYS_OWNER.get(str(d.get("sys", "")), "engineer"))
			if bool(d.get("fire", false)):
				_igor("fire", {"name": str(d.name).to_lower()}, 2)
				_event(0, {"t": "fx", "fx": "alarm"})
			elif "overheated" in why and str(d.sys).begins_with("engine"):
				_igor("overheat", {"name": d.name, "who": _who("engines")}, 2)
			elif "jammed" in why:
				_igor("jam", {"who": _who("weapons")}, 2)
			elif "Pudding" in why:
				_igor("pudding_chew", {"name": str(d.name).to_lower()}, 2)
			else:
				_igor("broke", {"name": d.name, "who": _who(owner_seat)}, 1)
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
			var nb: int = int(tally.bumps)
			_igor("bump" if nb < 2 else "bump_again", {"name": str(d.get("name", "it")), "who": _who("helm"), "n": nb}, 1)
			_event(0, {"t": "fx", "fx": "bump"})
		"friendly_fire":
			_igor("friendly_fire", {"name": str(d.get("name", "it")), "who": _who("weapons")}, 2)
		"roll":
			_igor("roll", {}, 0)
		"dodged":
			if randf() < 0.4:
				_igor("dodged", {"who": _who("helm")}, 0)
		"blocked":
			if randf() < 0.2:
				_igor("blocked", {"who": _who("shields")}, 0)
			_event(0, {"t": "fx", "fx": "block"})
		"latched":
			_igor("latched", {}, 2)
		"unlatched":
			_igor("unlatched", {}, 1)
		"ent_destroyed":
			tally["kills"] = int(tally.get("kills", 0)) + 1
			_event(0, {"t": "fx", "fx": "boom"})
			if str(d.get("kind", "")) in ["drone", "grabber", "cruiser", "target"]:
				var nk: int = int(tally.kills)
				_igor("kill_streak" if nk in [3, 5, 8] else "kill", {"who": _who("weapons"), "n": nk}, 0)
		"ent_exploded":
			_event(0, {"t": "fx", "fx": "boom"})
		"hit":
			tally["calm"] = 0.0
			_event(0, {"t": "fx", "fx": "hit"})
		"scanned":
			_event(0, {"t": "toast", "text": "Scanned: %s" % str(d.get("name", "?")), "kind": "info", "who": "sensors"})
		"ghost_scanned":
			_igor("ghost", {"who": _who("sensors")}, 2)
		"weak_found":
			_igor("weak_found", {}, 2)
		"torp_hit":
			_igor("torp_hit" if bool(d.get("weak", false)) else "torp_bounce", {"who": _who("weapons")}, 2)
		"hail":
			_igor("radio_new", {}, 1)
			_event(0, {"t": "fx", "fx": "ring"})
		"hail_heard":
			_igor("hail_heard", {}, 1)
		"radio_done":
			_event(0, {"t": "igor", "text": Igor.line("radio_done", {"from": str(d.get("from", "")), "reward": "£%d" % int(d.get("reward", 0))}), "prio": 2, "who": "igor", "speak": false})
			_event(0, {"t": "toast", "text": "+£%d  %s is happy" % [int(d.get("reward", 0)), str(d.get("from", ""))], "kind": "good"})
			_event(0, {"t": "fx", "fx": "ding"})
		"radio_missed":
			_igor("radio_missed", {"from": str(d.get("from", ""))}, 1)
		"collected":
			_igor("collected", {"name": str(d.get("name", "it")), "who": _who("shields")}, 1)
		"bonus":
			_igor("bonus", {"amount": "£%d" % int(d.get("amount", 0))}, 1)
			_event(0, {"t": "toast", "text": "+£%d bonus" % int(d.get("amount", 0)), "kind": "good"})
		"glitch":
			tally["calm"] = 0.0
			if str(d.get("id", "")) == "igor_reboot":
				_event(0, {"t": "igor", "text": "IGOR is installing update 1 of 847. Do not turn off IGOR. Captain: you are on your own. Bzzt.", "prio": 3, "who": "igor", "speak": true})
				igor_cd = 20.0
			else:
				_igor("glitch", {}, 2)
			_event(0, {"t": "fx", "fx": "glitch"})
		"glitch_hint":
			var hint: String = str(Glitches.DEFS.get(str(d.get("id", "")), {}).get("hint", ""))
			if hint != "":
				_event(0, {"t": "igor", "text": hint, "prio": 2, "who": "igor", "speak": true})
				igor_cd = IGOR_COOLDOWN
		"glitch_fixed":
			var fixed: String = str(Glitches.DEFS.get(str(d.get("id", "")), {}).get("fixed", ""))
			_event(0, {"t": "igor", "text": fixed if (fixed != "" and randf() < 0.75) else Igor.line("glitch_fixed", _names()), "prio": 2, "who": "igor", "speak": false})
			igor_cd = IGOR_COOLDOWN
			_event(0, {"t": "toast", "text": "Glitch fixed: %s" % str(d.get("name", "")), "kind": "good", "who": "engineer"})
			_event(0, {"t": "fx", "fx": "ding"})
		"incident":
			_igor("incident_" + str(d.get("kind", "")), {}, 2)
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
	var full: Dictionary = _names()
	full.merge(ctx, true)
	var text: String = Igor.line(key, full)
	if text == "":
		return
	igor_cd = IGOR_COOLDOWN
	igor_idle = 45.0
	_event(0, {"t": "igor", "text": text, "prio": prio, "who": "igor", "speak": prio >= 2})

func _awards(ok: bool) -> Array:
	var st: Dictionary = world.stats
	var out: Array = []
	if int(st.get("glitches_fixed", 0)) >= 2:
		out.append({"title": "Read The Manual", "seat": "engineer", "text": "%d glitches fixed" % int(st.glitches_fixed)})
	if mission.count("asks_done") >= 2:
		out.append({"title": "Switchboard", "seat": "sensors", "text": "%d radio calls handled" % mission.count("asks_done")})
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
	if int(tally.get("bumps", 0)) >= 4:
		out.append({"title": "Dodgem Driver", "seat": "helm", "text": "%d bumps" % int(tally.bumps)})
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
	for a in out:
		a["who"] = _who(str(a.seat))
	return out.slice(0, 5)

# ================================================================ snapshots

func _event(peer: int, data: Dictionary) -> void:
	event_ready.emit(peer, data)

func send_snapshots() -> void:
	if phase == "lobby" or (world == null and phase != "board"):
		return
	for pid in peers.keys():
		if peers[pid].gone:
			continue
		snap_ready.emit(pid, snapshot_for(pid))

func snapshot_for(peer: int) -> Dictionary:
	var p: Dictionary = peers[peer]
	var act: String = str(p.active)
	var d: Dictionary = {"phase": phase, "active": act, "seats": p.seats, "you": peer}
	if phase == "board" or world == null:
		d["common"] = {}
		d["view"] = {}
		d["phase_data"] = _board_data(peer) if phase == "board" else {}
		return d
	d["common"] = Snapshots.common(world, act)
	if mission.is_job():
		d["common"]["shift"] = {"n": int(shift.get("n", 0)) + 1, "of": int(shift.get("of", 3)), "earned": int(shift.get("earned", 0)), "rent": int(shift.get("rent", 0))}
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
	if d["view"] is Dictionary and not (d["view"] as Dictionary).is_empty():
		d["view"] = Glitches.bend_view(world, act if act != "" else "captain", d["view"])
	d["phase_data"] = _phase_data(peer)
	return d

func _phase_data(peer: int) -> Dictionary:
	match phase:
		"briefing":
			var b: Dictionary = mission.briefing()
			if mission.is_job():
				b["shift"] = {"n": int(shift.n) + 1, "of": int(shift.of), "earned": int(shift.earned), "rent": int(shift.rent)}
				if int(shift.n) == 0 and not (shift.get("card", {}) as Dictionary).is_empty():
					b["card"] = shift.card
			return {"brief": b, "countdown": float(briefing.get("countdown", -1.0)), "roster": roster(peer),
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
