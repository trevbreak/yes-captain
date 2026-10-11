extends SceneTree
# Human-flow tests through the host's message API (no UI): repairs, isolation/zap, share-to-captain,
# authorization, the jump ritual, pit stop purchases, Black Box/debrief.

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
	h.mode = "run"
	h.run_length = "short"
	h.bot_on = {"helm": false, "engines": false, "power": false, "weapons": false, "sensors": false, "ops": false}
	h.add_peer(1, "Cap")
	h.handle_msg(1, "claim", {"seat": "captain"})
	h.add_peer(2, "Crew")
	for s in K.STATIONS:
		h.handle_msg(2, "claim", {"seat": s})
	h.start_game(777)
	var w: World = h.world
	print("-- authorization")
	h.handle_msg(2, "active", {"seat": "helm"})
	h.handle_msg(2, "intent", {"station": "helm", "key": "yaw", "val": 0.7})
	check(is_equal_approx(w.ship.yaw, 0.7), "active owner can steer")
	h.handle_msg(2, "intent", {"station": "engines", "key": "thr", "val": 0.9})
	check(is_equal_approx(w.ship.thr_p, 0.0), "inactive station intents are rejected")
	h.handle_msg(1, "intent", {"station": "helm", "key": "yaw", "val": -1.0})
	check(is_equal_approx(w.ship.yaw, 0.7), "captain cannot touch the ship")
	h.handle_msg(2, "cap", {"cmd": "continue"})
	h.handle_msg(1, "claim", {"seat": "helm"})
	check(h.seat_owner["helm"] == 2, "can't steal an owned seat")

	print("-- quick fix at own station vs damage control")
	w.ship.modules["RCS_FP"].hp = 50.0   # rattling: owner can quick-fix
	h.handle_msg(2, "intent", {"station": "helm", "key": "fix", "val": {"target": "mod:RCS_FP", "on": true}})
	h.advance(3.0)
	check(w.ship.modules["RCS_FP"].hp >= 99.0, "helm quick-fixed a soft fault from their own screen")
	w.ship.modules["RCS_FP"].hp = 4.0     # failed: needs DC
	h.handle_msg(2, "intent", {"station": "helm", "key": "fix", "val": {"target": "mod:RCS_FP", "on": true}})
	h.advance(5.0)
	check(w.ship.modules["RCS_FP"].hp < 50.0, "failed module can NOT be quick-fixed at the station")
	h.handle_msg(2, "intent", {"station": "helm", "key": "fix", "val": {"target": "mod:RCS_FP", "on": false}})
	h.handle_msg(2, "active", {"seat": "dc"})
	h.handle_msg(2, "intent", {"station": "dc", "key": "hold", "val": {"target": "mod:RCS_FP", "on": true}})
	h.advance(5.0)
	check(w.ship.modules["RCS_FP"].hp >= 99.0, "damage control repairs a failed module (tab away from your post)")
	check(h.peers[2].active == "dc", "the engineer is parked in DC, so their own station is unattended")

	print("-- fire -> breach -> module order")
	w.ship.set_fire("ENG_P")
	w.ship.set_breach("ENG_P")
	w.ship.modules["ENG_P"].hp = 10.0
	for target_kind in ["fire", "breach", "repair"]:
		var task: Dictionary = w.target_task("mod:ENG_P")
		check(task.get("kind", "") == target_kind, "next task is %s (got %s)" % [target_kind, task.get("kind", "?")])
		h.handle_msg(2, "intent", {"station": "dc", "key": "hold", "val": {"target": "mod:ENG_P", "on": true}})
		h.advance(5.0)
	check(w.target_task("mod:ENG_P").is_empty(), "engine fully repaired after fire+breach+module")

	print("-- conduit splice zaps unless Power isolates")
	w.ship.cut_conduit("C_PORT", true)
	check(w.ship.eff("ENG_P") == 0.0, "port engine is dead while C_PORT is cut")
	var zapped: bool = false
	h.handle_msg(2, "intent", {"station": "dc", "key": "hold", "val": {"target": "con:C_PORT", "on": true}})
	for i in 30 * 6:
		h.sim_step(K.DT)
		for ev in h.blackbox.events:
			if "zapped" in str(ev.text):
				zapped = true
	check(zapped, "splicing a live conduit zaps you")
	check(w.ship.conduits["C_PORT"].cut, "...and the conduit is still cut")
	h.handle_msg(2, "active", {"seat": "power"})
	h.handle_msg(2, "intent", {"station": "power", "key": "isolate", "val": {"cid": "C_PORT", "on": true}})
	h.handle_msg(2, "active", {"seat": "dc"})
	h.handle_msg(2, "intent", {"station": "dc", "key": "hold", "val": {"target": "con:C_PORT", "on": true}})
	h.advance(6.0)
	check(not w.ship.conduits["C_PORT"].cut, "isolated conduit splices cleanly")
	h.handle_msg(2, "active", {"seat": "power"})
	h.handle_msg(2, "intent", {"station": "power", "key": "isolate", "val": {"cid": "C_PORT", "on": false}})

	print("-- hidden faults need tracing")
	w.ship.cut_conduit("C_STAR", true)
	var dcs: Dictionary = Snapshots.dc(w)
	check(dcs.cons["C_STAR"].unknown and not dcs.cons["C_STAR"].cut, "hidden cut shows as ??? in DC")
	var ps: Dictionary = Snapshots.power(w)
	check(ps.cons["C_STAR"].unknown, "and as ??? on Power")
	Intents.apply(w, "sensors", "iscan", true)
	check(Snapshots.dc(w).cons["C_STAR"].cut, "sensors internal scan reveals the break")
	w.reveal_t = 0.0
	h.handle_msg(2, "active", {"seat": "dc"})
	h.handle_msg(2, "intent", {"station": "dc", "key": "hold", "val": {"target": "trc:C_STAR", "on": true}})
	h.advance(3.0)
	check(Snapshots.dc(w).cons["C_STAR"].cut, "tracing in DC reveals it too")
	w.ship.repair_conduit("C_STAR")

	print("-- share to captain")
	h.handle_msg(2, "active", {"seat": "sensors"})
	h.handle_msg(2, "share", {"on": true})
	var cs: Dictionary = h.snapshot_for(1)
	check(cs.offers.size() == 1 and cs.offers[0].station == "sensors", "captain sees the share offer")
	check(not cs.has("shared"), "nothing shared until the captain accepts")
	h.handle_msg(1, "cap", {"cmd": "accept_share", "peer": 2})
	cs = h.snapshot_for(1)
	check(cs.has("shared") and cs.shared.station == "sensors" and cs.shared.view.has("contacts"), "captain now gets the sensors view")
	h.handle_msg(2, "active", {"seat": "ops"})
	check(not h.snapshot_for(1).has("shared"), "sharing stops when the player leaves that station")
	h.handle_msg(2, "active", {"seat": "sensors"})
	h.handle_msg(2, "share", {"on": true})
	h.handle_msg(1, "cap", {"cmd": "accept_share", "peer": 2})
	h.handle_msg(1, "cap", {"cmd": "stop_share"})
	check(not h.snapshot_for(1).has("shared"), "captain can go back to the window")

	print("-- Bin Day -> debrief -> staging -> ritual -> jump")
	w.enc.finish(true)
	h.advance(0.2)
	check(h.phase == "debrief", "encounter end -> debrief")
	check(h.debrief.has("awards") and h.debrief.has("trail"), "debrief carries awards and a replay trail")
	h.handle_msg(2, "cap", {"cmd": "continue"})
	check(h.phase == "debrief", "only the captain can continue")
	h.handle_msg(1, "cap", {"cmd": "continue"})
	check(h.phase == "staging", "captain continues to the map")
	var opts: Array = h.run.options()
	check(opts.size() >= 1, "map offers destinations")
	h.handle_msg(2, "active", {"seat": "helm"})
	h.handle_msg(2, "intent", {"station": "helm", "key": "code", "val": "000-00"})
	check(int(h.ritual.node) == -1, "bad coordinates are refused")
	h.handle_msg(2, "intent", {"station": "helm", "key": "code", "val": str(opts[0].code)})
	check(int(h.ritual.node) == int(opts[0].id), "helm lays in the course from the coordinates")
	var hs: Dictionary = h.snapshot_for(2)
	check(hs.ph.options[0].has("code") and not hs.ph.options[0].has("name"), "helm sees coordinates but NOT the destination names")
	var cs2: Dictionary = h.snapshot_for(1)
	check(cs2.ph.options[0].has("name") and cs2.ph.has("map"), "captain sees names, blurbs and the full map")
	# misjump: punch with nothing done
	var fuel0: int = h.run.fuel
	h.handle_msg(1, "cap", {"cmd": "punch"})
	check(h.phase == "jumping" and h.run.fuel == fuel0 - 1, "punching it costs fuel")
	check(int(h.world.stats["misjump"]) == 1, "an incomplete ritual MISJUMPS")
	h.advance(3.5)
	check(h.phase == "encounter", "jump lands in an encounter")

	print("-- pit stop")
	h.world.enc.dock_request = true
	h.world.enc.finish(true)
	h.advance(0.2)
	h.handle_msg(1, "cap", {"cmd": "continue"})
	check(h.phase == "pitstop", "docking leads to the budget meeting")
	h.run.scrap = 100
	h.handle_msg(2, "active", {"seat": "engines"})
	h.handle_msg(2, "pit_request", {"id": "turbo"})
	var ps2: Dictionary = h.snapshot_for(1)
	var req: bool = false
	for it in ps2.ph.items:
		if it.id == "turbo" and it.requested and it.by == "engines":
			req = true
	check(req, "captain sees who asked for what")
	var thrust0: float = h.world.ship.thrust_bonus
	h.handle_msg(1, "cap", {"cmd": "pit_buy", "id": "turbo"})
	check(h.run.scrap == 65 and h.world.ship.thrust_bonus > thrust0, "captain approves: scrap spent, upgrade applied")
	h.handle_msg(1, "cap", {"cmd": "pit_buy", "id": "hull"})
	h.handle_msg(1, "cap", {"cmd": "pit_buy", "id": "cooler"})
	h.handle_msg(1, "cap", {"cmd": "pit_buy", "id": "torp"})
	check(h.run.scrap >= 0, "can't overspend")
	h.handle_msg(1, "cap", {"cmd": "pit_done"})
	check(h.phase == "staging", "leave the diner -> map")

	print("-- failure states")
	h.handle_msg(1, "cap", {"cmd": "punch"})
	check(h.phase == "staging", "punch before choosing a destination does nothing")
	h.world.ship.hull = -1.0
	h.advance(0.2)
	check(h.phase == "gameover", "destroyed ship -> Hegemony broadcast")
	h.handle_msg(1, "cap", {"cmd": "continue"})
	check(h.phase == "lobby", "back to lobby")
	print("DONE fails=", fails)
	quit(fails)
