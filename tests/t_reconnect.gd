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
	h.shift_kind = "drones"
	h.default_personality = "competent"
	h.add_peer(1, "Cap")
	h.claim(1, "captain")
	h.add_peer(2, "Pat")
	h.claim(2, "helm")
	h.claim(2, "weapons")
	h.start_game(3)
	check(not h.bots.has("helm") and not h.bots.has("weapons") and h.bots.has("power"), "bots fill only the empty seats")
	h.advance(2.0)
	h.remove_peer(2)
	check(h.bots.has("helm") and h.bots.has("weapons"), "when Pat drops, bots take over Pat's seats")
	h.advance(2.0)
	h.add_peer(5, "Pat")
	check(h.seat_owner.get("helm", 0) == 5 and h.seat_owner.get("weapons", 0) == 5, "Pat reconnects (new id) and gets the seats back")
	check(not h.bots.has("helm") and not h.bots.has("weapons"), "...and the bots step aside")
	check(h.peers[5].active in ["helm", "weapons"], "an active seat is restored")
	h.advance(2.0)
	# someone new joining mid-game is told the game has started
	var started: Array = [false]
	h.broadcast_enabled = true
	h.event_ready.connect(func(p: int, d: Dictionary): if p == 9 and d.get("t", "") == "started": started[0] = true)
	h.add_peer(9, "Latecomer")
	check(started[0], "a late joiner gets the 'started' event and lands in the game")
	check(h.peers[9].seats.is_empty(), "late joiner has no seat until they take a free one")
	h.handle_msg(9, "claim", {"seat": "ops"})
	check(h.seat_owner.get("ops", 0) == 9 and not h.bots.has("ops"), "late joiner takes over the Ops bot mid-flight")
	var snap: Dictionary = h.snapshot_for(9)
	check(snap.active == "ops" and snap.view.has("shield"), "and immediately receives Ops snapshots")
	print("DONE fails=", fails)
	quit(fails)
