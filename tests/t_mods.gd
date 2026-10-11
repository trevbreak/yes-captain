extends SceneTree
var fails: int = 0
func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		fails += 1

func _init() -> void:
	RunState.persist = false
	var h: GameHost = GameHost.new()
	h.broadcast_enabled = false
	h.mode = "shift"
	h.shift_kind = "casual"
	h.mods = ["glass", "newton", "pudding", "emp", "rotation", "jargon"]
	h.bot_on = {"helm": false, "engines": false, "power": false, "weapons": false, "sensors": false, "ops": false}
	h.add_peer(1, "Cap")
	h.claim(1, "captain")
	h.add_peer(2, "A")
	h.add_peer(3, "B")
	h.claim(2, "helm")
	h.claim(2, "engines")
	h.claim(3, "power")
	h.claim(3, "weapons")
	h.start_game(5)
	var w: World = h.world
	var s: Ship = w.ship
	print("-- modifiers applied")
	check(s.damage_mult == 2.0, "glass ship doubles module damage")
	check(not s.dampers and s.dampers_locked, "newton: dampers are off and locked")
	h.handle_msg(2, "active", {"seat": "engines"})
	h.handle_msg(2, "intent", {"station": "engines", "key": "dampers", "val": true})
	check(not s.dampers, "...and can't be turned back on")
	check(float(s.pud["mood"]) >= 70.0, "pudding mode: starts anxious")
	check(Snapshots.engines(w).dampers_ok == false, "engines UI sees dampers_ok=false")
	check("jargon" in Snapshots.common(w).mods, "jargon flag reaches the UI")
	print("-- EMP inversion")
	w.inverted["engines"] = 10.0
	h.handle_msg(2, "intent", {"station": "engines", "key": "thr", "val": 0.8})
	check(is_equal_approx(s.thr_p, -0.8), "EMP: throttle comes out backwards for a human")
	Intents.apply(w, "engines", "thr", 0.5)
	check(is_equal_approx(s.thr_p, 0.5), "...but robots are immune")
	check(float(h.snapshot_for(2).view.emp_t) > 0.0, "snapshot carries the EMP timer so the UI can show it")
	print("-- crew rotation")
	var before_helm: int = h.seat_owner["helm"]
	h.rotate_crew()
	check(h.seat_owner["engines"] == 3 and h.seat_owner.get("ops", 0) == 2, "rotation: each seat takes its neighbour's player (engines<-power's, ops<-helm's)")
	var all_ok: bool = true
	for st in h.seat_owner.keys():
		var o: int = h.seat_owner[st]
		if not (st in h.peers[o].seats):
			all_ok = false
	check(all_ok, "peers' seat lists match the seat map after rotating")
	check(h.seat_owner.has("captain") and h.seat_owner["captain"] == 1, "the captain does not rotate")
	check(h.peers[2].active in h.peers[2].seats or h.peers[2].active == "", "active seat stays valid")
	print("-- many seconds with all modifiers on, bots filling")
	var h2: GameHost = GameHost.new()
	h2.broadcast_enabled = false
	h2.mode = "shift"
	h2.shift_kind = "drones"
	h2.mods = ["glass", "newton", "pudding", "emp", "rotation", "jargon"]
	h2.ai_captain = true
	h2.default_personality = "competent"
	h2.add_peer(1, "Solo")
	h2.start_game(9)
	h2.world.director.cooldown = 3.0
	h2.advance(200.0)
	check(true, "ran 200s with every modifier without errors (phase=%s)" % h2.phase)
	print("DONE fails=", fails)
	quit(fails)
