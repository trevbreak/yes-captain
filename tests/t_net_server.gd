extends SceneTree
# Dedicated headless host. A remote client joins, claims seats, and plays.
var net: Node
var await_ready: bool = false
var booted: bool = false
var t: float = 0.0
var started: bool = false
var report_t: float = 0.0

func _init() -> void:
	RunState.persist = false
	net = load("res://net/net.gd").new()
	net.name = "Net"
	root.add_child.call_deferred(net)
	await_ready = true

func _boot() -> void:
	var err: Error = net.start_host("Server", 7791, true, false)
	print("SERVER listening err=", err)
	net.host.default_personality = "competent"
	net.host.mode = "shift"
	net.host.shift_kind = "drones"
	booted = true

func _process(delta: float) -> bool:
	if not booted:
		if net.is_inside_tree():
			_boot()
		return false
	t += delta
	var h: GameHost = net.host
	if not started and h.peers.size() > 0 and h.phase == "lobby" and t > 1.0:
		var n: int = h.peers.size()
		if h.seat_owner.has("helm") and h.seat_owner.has("captain") and h.seat_owner.has("engines"):
			print("SERVER starting game; peers=", h.peers.keys(), " seats=", h.seat_owner)
			h.start_game(4242)
			started = true
	report_t += delta
	if started and report_t > 2.0:
		report_t = 0.0
		print("SERVER t=%.1f phase=%s ship_pos=%s helm_yaw=%.2f thr=%.2f bots=%s" % [h.world.t, h.phase, str(h.world.ship.pos), h.world.ship.yaw, h.world.ship.thr_p, str(h.bots.keys())])
	if t > 22.0:
		print("SERVER done")
		net.shutdown()
		quit(0)
	return false
