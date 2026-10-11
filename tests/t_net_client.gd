extends SceneTree
## Network test client: joins the headless host, takes captain + helm + engines, readies up, steers, and checks
## that each seat only gets what it's allowed to know.
var net: Node
var booted: bool = false
var t: float = 0.0
var snaps: int = 0
var step: int = 0
var got_helm: bool = false
var got_captain: bool = false
var captain_sees: bool = false
var leaked: bool = false
var lobby_seen: bool = false
var briefing_seen: bool = false
var in_mission: bool = false

func _init() -> void:
	net = load("res://net/net.gd").new()
	net.name = "Net"
	root.add_child.call_deferred(net)

func _boot() -> void:
	net.snapshot.connect(_on_snap)
	net.event.connect(_on_event)
	net.connected.connect(func(): print("CLIENT connected id=", net.my_id))
	net.join_failed.connect(func(r):
		print("CLIENT join failed: ", r)
		quit(1))
	print("CLIENT join err=", net.join("127.0.0.1", 7791, "Tester"))
	booted = true

func _on_event(d: Dictionary) -> void:
	if d.t == "lobby":
		lobby_seen = true

func _on_snap(d: Dictionary) -> void:
	snaps += 1
	if d.phase == "briefing":
		briefing_seen = true
	if d.phase == "mission":
		in_mission = true
	if d.active == "helm" and d.phase == "mission":
		got_helm = true
		# the helm only gets a compass: no map, no contacts, no radar, no mission goals
		for banned in ["ents", "blips", "view", "warnings", "steps", "goal", "board"]:
			if d.view.has(banned):
				leaked = true
				print("CLIENT LEAK: helm view contains ", banned)
	if d.active == "captain" and d.phase == "mission":
		got_captain = true
		captain_sees = d.view.has("ents") and d.view.has("crew") and d.view.has("warnings")

func _process(delta: float) -> bool:
	if not booted:
		if net.is_inside_tree():
			_boot()
		return false
	t += delta
	if t > 1.5 and step == 0:
		step = 1
		for s in ["captain", "helm", "engines"]:
			net.send("claim", {"seat": s})
		print("CLIENT claimed captain, helm, engines")
	if step == 1 and briefing_seen:
		step = 2
		net.send("ready", {"on": true})
		print("CLIENT ready")
	if step == 2 and in_mission:
		step = 3
		net.send("active", {"seat": "helm"})
		net.intent("helm", "wheel", 0.5)
		net.send("active", {"seat": "engines"})
		net.intent("engines", "throttle", 0.8)
		print("CLIENT set the wheel and throttle")
	if step == 3 and t > 13.0:
		step = 4
		net.send("active", {"seat": "captain"})
		# an intent for a station we're NOT active on must be ignored (the wheel must stay at 0.5)
		net.intent("helm", "wheel", -1.0)
	if step == 4 and t > 16.0:
		step = 5
		net.send("active", {"seat": "helm"})
	if t > 20.0:
		print("CLIENT result: snaps=%d lobby=%s briefing=%s helm=%s captain=%s captain_sees=%s leaked=%s" % [snaps, lobby_seen, briefing_seen,
			got_helm, got_captain, captain_sees, leaked])
		var ok: bool = snaps > 50 and got_helm and got_captain and captain_sees and not leaked and lobby_seen and briefing_seen
		print("CLIENT ", "PASS" if ok else "FAIL")
		quit(0 if ok else 1)
	return false
