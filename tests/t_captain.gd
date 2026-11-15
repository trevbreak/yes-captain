extends SceneTree
## Practice on your own: one human at a crew desk, nobody in the Captain's chair. IGOR must let the mission
## start, read out each new goal, and call the right things for that human's role (and only that role).

func _init() -> void:
	Progress.persist = false
	var fails: Array = []
	var check: Callable = func(ok: bool, what: String):
		print("  %s  %s" % ["ok  " if ok else "FAIL", what])
		if not ok:
			fails.append(what)
	var h: GameHost = GameHost.new()
	h.career = Progress.new()
	h.career.unlock_all()
	var said: Array = []
	h.event_ready.connect(func(_pid: int, d: Dictionary):
		if str(d.get("t", "")) == "igor":
			said.append(str(d.get("text", ""))))
	h.add_peer(1, "Solo")
	h.admin = 1
	h.claim_role(1, "driver")
	check.call(h.start_problem() == "" and h.robot_captain(), "one player as Driver, no Captain: allowed, and IGOR captains")
	h.set_option("mission", "lesson")
	h.start_game(5)
	h.force_launch()
	var steer_ok: int = 0
	var steer_n: int = 0
	var t: float = 0.0
	var last_n: int = 0
	while t < 90.0 and h.phase == "mission":
		# the "human" does exactly what IGOR says to the Driver, and nothing else
		for i in range(last_n, said.size()):
			var line: String = said[i]
			if line.begins_with("Driver: turn"):
				steer_n += 1
				var rel: float = K.wrap_pi(((h.mission.goal_pos() as Vector2) - h.world.ship.pos).angle() - h.world.ship.heading) if h.mission.goal_pos() is Vector2 else 0.0
				if (rel > 0.0) == line.contains("RIGHT"):
					steer_ok += 1
				Intents.apply(h.world, "helm", "wheel", 1.0 if line.contains("RIGHT") else -1.0)
			elif line.begins_with("Driver: straight"):
				Intents.apply(h.world, "helm", "wheel", 0.0)
		last_n = said.size()
		h.sim_step(K.DT)
		t += K.DT
	var goals: int = 0
	var others: int = 0
	for l in said:
		if l.begins_with("Captain IGOR:"):
			goals += 1
		if l.begins_with("Stoker:") or l.begins_with("Tech:"):
			others += 1
	check.call(h.phase != "lobby", "the mission ran with IGOR in the chair (phase %s)" % h.phase)
	check.call(goals >= 2, "IGOR read out the goals as they came (%d)" % goals)
	check.call(steer_n >= 2 and steer_ok == steer_n, "IGOR's steering calls point the right way (%d of %d)" % [steer_ok, steer_n])
	check.call(others == 0, "IGOR only talks to the human's own role (%d calls to robots)" % others)
	check.call(h.mission.step >= 2, "following IGOR alone gets the Driver through the first steps (step %d)" % h.mission.step)
	# two humans: the Captain is needed again
	h.to_lobby()
	h.add_peer(2, "Friend")
	check.call(not h.robot_captain() and h.start_problem() != "", "with two players aboard, somebody has to be the Captain")
	print("CAPTAIN TEST ", "PASS" if fails.is_empty() else "FAIL %s" % str(fails))
	quit(0 if fails.is_empty() else 1)
