extends SceneTree
var net: Node
var await_ready: bool = false
var booted: bool = false
var t: float = 0.0
var snaps: int = 0
var step: int = 0
var got_helm: bool = false
var got_captain: bool = false
var leaked: bool = false
var lobby_seen: bool = false
var igor: int = 0
var last_helm: Dictionary = {}

func _init() -> void:
	net = load("res://net/net.gd").new()
	net.name = "Net"
	root.add_child.call_deferred(net)
	await_ready = true

func _boot() -> void:
	net.snapshot.connect(_on_snap)
	net.event.connect(_on_event)
	net.connected.connect(func(): print("CLIENT connected id=", net.my_id))
	net.join_failed.connect(func(r): print("CLIENT join failed: ", r); quit(1))
	var err: Error = net.join("127.0.0.1", 7791, "Tester")
	print("CLIENT join err=", err)
	booted = true

func _on_event(d: Dictionary) -> void:
	if d.t == "lobby":
		lobby_seen = true
	if d.t == "igor":
		igor += 1

func _on_snap(d: Dictionary) -> void:
	snaps += 1
	if d.active == "helm":
		got_helm = true
		last_helm = d.view
		# information asymmetry: a helm snapshot must NOT contain a contact list, entities or sensor data
		for banned in ["contacts", "ents", "locks", "scope", "incoming"]:
			if d.view.has(banned):
				leaked = true
				print("CLIENT LEAK: helm view contains ", banned)
	if d.active == "captain":
		got_captain = true

func _process(delta: float) -> bool:
	if not booted:
		if net.is_inside_tree():
			_boot()
		return false
	t += delta
	if t > 1.5 and step == 0:
		step = 1
		net.send("claim", {"seat": "captain"})
		net.send("claim", {"seat": "helm"})
		net.send("claim", {"seat": "engines"})
		net.send("active", {"seat": "helm"})
		print("CLIENT claimed captain, helm, engines")
	if step == 1 and t > 4.0:
		step = 2
		net.intent("helm", "yaw", 0.5)
		net.send("active", {"seat": "engines"})
		net.intent("engines", "thr", 0.8)
		print("CLIENT sent yaw + throttle intents")
	if step == 2 and t > 9.0:
		step = 3
		net.send("active", {"seat": "captain"})
	if step == 3 and t > 11.0:
		step = 4
		# an intent for a station we are NOT active on must be rejected
		net.intent("helm", "yaw", -1.0)
		net.send("active", {"seat": "helm"})
	if t > 19.0:
		print("CLIENT result: snaps=%d lobby=%s got_helm=%s got_captain=%s leaked=%s igor_events=%d" % [snaps, str(lobby_seen), str(got_helm), str(got_captain), str(leaked), igor])
		if last_helm.has("heading"):
			print("CLIENT helm heading=%.2f angvel=%.2f yaw=%.2f" % [last_helm.heading, last_helm.angvel, last_helm.yaw])
		var ok: bool = snaps > 50 and got_helm and got_captain and not leaked and lobby_seen
		print("CLIENT ", "PASS" if ok else "FAIL")
		quit(0 if ok else 1)
	return false
