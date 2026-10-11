extends SceneTree
## Dedicated headless host for the network test. A separate client process joins, takes seats and plays.
var net: Node
var booted: bool = false
var t: float = 0.0
var started: bool = false
var report_t: float = 0.0
var max_wheel: float = 0.0

func _init() -> void:
	Progress.persist = false
	net = load("res://net/net.gd").new()
	net.name = "Net"
	root.add_child.call_deferred(net)

func _boot() -> void:
	var err: Error = net.start_host("Server", 7791, true, false)
	print("SERVER listening err=", err)
	net.host.mission_id = "lesson"
	booted = true

func _process(delta: float) -> bool:
	if not booted:
		if net.is_inside_tree():
			_boot()
		return false
	t += delta
	var h: GameHost = net.host
	if not started and h.phase == "lobby" and h.seat_owner.has("helm") and h.seat_owner.has("captain") and h.seat_owner.has("engines") and t > 1.0:
		print("SERVER starting; seats=", h.seat_owner)
		h.start_game(4242)
		started = true
	report_t += delta
	if started and h.world != null:
		max_wheel = maxf(max_wheel, h.world.ship.wheel)
	if started and report_t > 2.0 and h.world != null:
		report_t = 0.0
		print("SERVER t=%.1f phase=%s wheel=%.2f throttle=%.2f speed=%.1f bots=%s" % [h.world.t, h.phase, h.world.ship.wheel, h.world.ship.throttle,
			h.world.ship.speed(), str(h.bots.keys())])
	if t > 22.0:
		var ok: bool = started and h.phase == "mission" and h.world.ship.throttle > 0.7 and absf(h.world.ship.wheel - 0.5) < 0.01
		print("SERVER sticky controls: wheel=%.2f throttle=%.2f -> %s" % [h.world.ship.wheel if h.world else -1.0, h.world.ship.throttle if h.world else -1.0, "PASS" if ok else "FAIL"])
		net.shutdown()
		quit(0 if ok else 1)
	return false
