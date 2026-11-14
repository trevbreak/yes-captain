extends SceneTree
## The server with rooms, and four players, all in this one process (each with its own network branch).
## Checks: the sessions board, create / join by code, two rooms flying at once with nothing crossing between
## them, seat secrecy inside a room, ready-up, kick, room limits, rubbish input, and empty rooms closing.

const PORT: int = 7793
var nets: Dictionary = {}       # name -> Net node
var ev: Dictionary = {}         # name -> [events]
var snaps: Dictionary = {}      # name -> [snapshots]
var t: float = 0.0
var step: int = 0
var fails: Array = []
var code_a: String = ""
var code_b: String = ""
var booted: bool = false

func _init() -> void:
	Progress.persist = false

func _mk(nm: String) -> Node:
	var holder: Node = Node.new()
	holder.name = nm
	root.add_child(holder)
	set_multiplayer(SceneMultiplayer.new(), holder.get_path())
	var n: Node = load("res://net/net.gd").new()
	n.name = "Net"
	holder.add_child(n)
	nets[nm] = n
	ev[nm] = []
	snaps[nm] = []
	n.event.connect(func(d: Dictionary): ev[nm].append(d))
	n.snapshot.connect(func(d: Dictionary): snaps[nm].append(d))
	return n

func _boot() -> void:
	var s: Node = _mk("S")
	var err: Error = s.start_server(PORT, 2)
	s.hub.empty_close_s = 1.0
	print("HUB TEST server err=", err)
	for nm in ["A", "B", "C", "D"]:
		_mk(nm).join("127.0.0.1", PORT, {"A": "Alice", "B": "Bob", "C": "Cat\n<b>", "D": "Dee"}[nm])
	booted = true

func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails.append(what)

func last(nm: String, kind: String) -> Dictionary:
	var arr: Array = ev[nm]
	for i in range(arr.size() - 1, -1, -1):
		if str(arr[i].get("t", "")) == kind:
			return arr[i]
	return {}

func count(nm: String, kind: String) -> int:
	var n: int = 0
	for e in ev[nm]:
		if str(e.get("t", "")) == kind:
			n += 1
	return n

func hub() -> Hub:
	return nets["S"].hub

func _process(delta: float) -> bool:
	if not booted:
		_boot()
		return false
	t += delta
	match step:
		0:
			if t > 1.5:
				check(not last("A", "rooms").is_empty() and (last("A", "rooms").rooms as Array).is_empty(), "everyone lands in an empty depot")
				check(str(last("C", "rooms").get("you", "")) == "Catb", "names are cleaned (got '%s')" % str(last("C", "rooms").get("you", "")))
				nets["A"].send("create", {"name": "Alpha", "career": {"unlocked": 4, "stars": {"lesson": 3, "nonsense": 9}}})
				nets["B"].send("create", {"name": "", "career": "rubbish"})
				step = 1
				t = 0.0
		1:
			if t > 1.0:
				code_a = str(last("A", "joined").get("code", ""))
				code_b = str(last("B", "joined").get("code", ""))
				check(code_a.length() == 4 and code_b.length() == 4 and code_a != code_b, "two rooms opened: %s and %s" % [code_a, code_b])
				check(str(last("B", "joined").get("name", "")) == "Bob's crew", "an unnamed room is named after its host")
				var la: Dictionary = last("A", "lobby")
				check(int(la.get("admin", 0)) == nets["A"].my_id, "the creator is the host")
				var unlocked: int = 0
				for m in la.get("missions", []):
					unlocked += int(bool(m.unlocked))
				check(unlocked == 4, "the host's career came along (%d missions open)" % unlocked)
				var lb: Dictionary = last("B", "lobby")
				check(str(la.get("mode", "")) == "shift" and str(lb.get("mode", "")) == "shift", "online rooms start on the Shift")
				check(bool(lb.get("shift", {}).get("open", false)), "the Shift is open even for a brand-new crew")
				# room A goes back to Training, to test the career flow below
				nets["A"].send("opt", {"key": "mode", "val": "career"})
				check((last("C", "rooms").rooms as Array).size() == 2, "the depot shows both rooms to the others")
				nets["D"].send("create", {"name": "Third"})
				nets["C"].send("join", {"code": "ZZZZ"})
				step = 2
				t = 0.0
		2:
			if t > 1.0:
				check(not last("D", "hub_error").is_empty() and hub().rooms.size() == 2, "the room limit holds")
				check(not last("C", "hub_error").is_empty(), "a wrong code is refused politely")
				nets["C"].send("join", {"code": code_a.to_lower()})
				nets["A"].send("claim", {"seat": "captain"})
				nets["B"].send("claim", {"seat": "captain"})
				step = 3
				t = 0.0
		3:
			if t > 1.0:
				check(str(last("C", "joined").get("code", "")) == code_a, "joining by code works (any case)")
				nets["C"].send("claim", {"seats": ["helm", "engines"]})
				nets["C"].send("claim", {"seats": ["weapons", "captain"]})   # captain is taken: must take neither
				step = 4
				t = 0.0
		4:
			if t > 0.6:
				var h: GameHost = hub().rooms[code_a].host
				check(h.peers[nets["C"].my_id].seats == ["helm", "engines"], "a pair is taken whole, or not at all: %s" % str(h.peers[nets["C"].my_id].seats))
				nets["A"].send("start")   # C isn't ready: must be refused
				step = 41
				t = 0.0
		41:
			if t > 0.6:
				var h3: GameHost = hub().rooms[code_a].host
				check(h3.phase == "lobby" and not last("A", "toast").is_empty(), "the host can't start until the crew is ready")
				nets["C"].send("lobby_ready", {"on": true})
				step = 5
				t = 0.0
		5:
			if t > 0.6:
				nets["A"].send("start")
				nets["B"].send("opt", {"key": "voice", "val": true})
				step = 6
				t = 0.0
		6:
			if t > 1.0:
				check(hub().rooms[code_a].host.phase == "briefing", "room A is in its briefing")
				check(hub().rooms[code_b].host.phase == "lobby", "room B is still in its crew room")
				check(count("B", "briefing") == 0 and count("B", "started") == 0 and snaps["B"].is_empty(), "nothing from room A reached room B")
				nets["A"].send("ready", {"on": true})
				nets["C"].send("ready", {"on": true})
				nets["B"].send("start")
				# voice handshakes only travel inside a room that has voice on
				nets["B"].send("rtc", {"to": nets["A"].my_id, "data": {"j": "x"}})
				nets["A"].send("rtc", {"to": nets["C"].my_id, "data": {"j": "x"}})
				step = 7
				t = 0.0
		7:
			if t > 5.5:
				check(hub().rooms[code_a].host.phase == "mission" and hub().rooms[code_b].host.phase == "board", "two rooms run side by side (A flying, B at its job board)")
				check((hub().rooms[code_b].host.shift.get("offers", []) as Array).size() == 3, "a brand-new crew gets three jobs on the board")
				check(count("A", "rtc") == 0 and count("C", "rtc") == 0, "voice handshakes can't cross rooms or run with voice off")
				nets["C"].send("active", {"seat": "helm"})
				nets["C"].intent("helm", "wheel", 0.5)
				# rubbish: none of this may hurt the server
				nets["C"].send("intent", {"station": ["helm"], "key": {"a": {"b": {"c": {"d": 1}}}}, "val": "x".repeat(30000)})
				nets["C"].send("kick", {"peer": "everyone"})
				nets["C"].send("opt", {"key": "unlock_all"})
				nets["C"].send("x".repeat(500), {})
				nets["D"].send("claim", {"seat": "captain"})
				for i in 400:
					nets["D"].send("rooms")
				step = 8
				t = 0.0
		8:
			if t > 1.5:
				var h2: GameHost = hub().rooms[code_a].host
				check(absf(h2.world.ship.wheel - 0.5) < 0.01, "the pilot's wheel reached the ship")
				var sc: Dictionary = snaps["C"][snaps["C"].size() - 1]
				var leak: bool = false
				for banned in ["ents", "blips", "warnings", "steps", "goal", "board", "crew"]:
					if (sc.get("view", {}) as Dictionary).has(banned):
						leak = true
				check(str(sc.get("active", "")) == "helm" and not leak, "the helm's screen data holds no map, contacts or goals")
				var sa: Dictionary = snaps["A"][snaps["A"].size() - 1]
				check((sa.get("view", {}) as Dictionary).has("ents") and (sa.view as Dictionary).has("warnings"), "the captain gets the whole picture")
				check(h2.career.unlocked() == 4 and h2.peers.has(nets["C"].my_id), "a crew member can't unlock missions or kick")
				check(count("D", "rooms") < 300, "a flood of messages is throttled (%d answered)" % count("D", "rooms"))
				nets["A"].send("kick", {"peer": nets["C"].my_id})
				nets["B"].send("leave")
				step = 9
				t = 0.0
		9:
			if t > 2.6:
				check(not last("C", "kicked").is_empty() and not hub().peer_room.has(nets["C"].my_id), "the host can send someone home")
				check(not hub().rooms.has(code_b), "an empty room closes")
				check(hub().rooms.has(code_a) and hub().rooms[code_a].host.bots.has("helm"), "a robot took the empty helm")
				nets["A"].shutdown()
				step = 10
				t = 0.0
		10:
			if t > 2.6:
				check(hub().rooms.is_empty() and hub().peer_name.size() == 3, "a host who vanishes takes the room with them, in time")
				print("HUB TEST ", "PASS" if fails.is_empty() else "FAIL: %s" % str(fails))
				for n in nets.values():
					n.shutdown()
				quit(0 if fails.is_empty() else 1)
	return false
