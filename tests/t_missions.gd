extends SceneTree
## Soak test: a full robot crew must finish every mission. Prints time, hull, stars and key stats.
## SEEDS=n (default 2), ONLY=id, VERBOSE=1

func _init() -> void:
	var seeds: int = int(OS.get_environment("SEEDS")) if OS.get_environment("SEEDS") != "" else 2
	var only: String = OS.get_environment("ONLY")
	var verbose: bool = OS.get_environment("VERBOSE") != ""
	var fails: int = 0
	for id in Missions.ORDER:
		if only != "" and id != only:
			continue
		for sd in seeds:
			var r: Dictionary = run_mission(id, 1000 + sd * 77, verbose)
			var ok: bool = r.done
			if not ok:
				fails += 1
			print("%-10s seed %d  %s  t=%5.1fs (par %d)  hull=%3d  stars=%d  step=%d/%d  %s  %s" % [id, sd, "PASS" if ok else "FAIL", r.t, r.par, r.hull,
				r.stars, r.step, r.steps, r.reason, r.stats])
	print("MISSIONS ", "ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)

func run_mission(id: String, seed_value: int, verbose: bool) -> Dictionary:
	var w: World = World.new(seed_value)
	var m: Mission = Missions.make(id)
	m.setup(w)
	var bots: Array = []
	for st in K.STATIONS:
		bots.append(Bot.new(st))
	var dt: float = K.DT
	var limit: float = m.par * 3.0 + 120.0
	var last_step: int = -1
	while w.t < limit and not m.done and not m.failed:
		for b in bots:
			b.tick(w, dt)
		w.step(dt)
		for ev in w.events:
			m.on_event(str(ev[0]), ev[1])
			if verbose and str(ev[0]) in ["step", "broke", "blackout", "pudding_out", "mission_failed", "latched", "hail_heard", "torp_hit"]:
				print("   %6.1f %s %s" % [w.t, ev[0], ev[1]])
		w.events.clear()
		if verbose and int(w.t * 30.0) % 150 == 0:
			print("   %6.1f step %d pos %s spd %.0f thr %.2f wheel %.2f hdg %d goal %s" % [w.t, m.step, w.ship.pos.round(), w.ship.speed(), w.ship.throttle, w.ship.wheel, K.bearing_deg(w.ship.heading), m.goal_pos()])
	var st: Dictionary = w.stats.duplicate()
	return {"done": m.done, "t": w.t, "par": m.par, "hull": int(w.ship.hull), "stars": m.stars(), "step": m.step, "steps": m.steps.size(),
		"reason": m.reason, "stats": "shots %d hits %d blocked %d taken %d repairs %d fires %d overloads %d escapes %d" % [st.shots, st.hits, st.blocked,
			st.hits_taken, st.repairs, st.fires, st.overloads, st.escapes]}
