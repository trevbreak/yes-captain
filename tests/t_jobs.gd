extends SceneTree
## Soak test for the Shift: robot crews fly dealt jobs (every task, with places, twists and the director's
## glitches switched on). A job robots can't finish would be a job humans get stuck on.
## SEEDS=n (default 3), ONLY=task, VERBOSE=1

func _init() -> void:
	Progress.persist = false
	var seeds: int = int(OS.get_environment("SEEDS")) if OS.get_environment("SEEDS") != "" else 3
	var only: String = OS.get_environment("ONLY")
	var verbose: bool = OS.get_environment("VERBOSE") != ""
	var career: Progress = Progress.new()
	career.unlock_all()
	for id in Missions.ORDER:
		career.star_map[id] = 1
	career.shifts = 40
	var fails: int = 0
	var runs: int = 0
	var places: Array = ["open"] + Deck.ids(career, "place")
	var twists: Array = Deck.ids(career, "twist")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99
	for task in Jobs.TASKS.keys():
		if only != "" and task != only:
			continue
		for sd in seeds:
			var tw: Array = []
			for k in sd % 3:
				var x: String = twists[rng.randi() % twists.size()]
				if not (x in tw) and not (x == "one_engine" and task == "pursuit"):
					tw.append(x)
			var spec: Dictionary = {"task": task, "place": places[(sd + task.length()) % places.size()], "twists": tw, "seed": 500 + sd * 31,
				"title": task, "pay": int(Jobs.TASKS[task].pay), "danger": 1 + sd % 4, "client": "igor", "blurb": ""}
			if task == "storm" and spec.place == "shower":
				spec.place = "open"
			var r: Dictionary = run_job(spec, career, verbose)
			runs += 1
			if not r.done:
				fails += 1
			print("%-10s %-8s %-28s %s t=%5.1f (par %3d) hull=%3d pay=%4d incidents=%d glitches=%d/%d %s" % [task, spec.place, ",".join(PackedStringArray(tw)),
				"PASS" if r.done else "FAIL", r.t, r.par, r.hull, r.pay, r.incidents, r.fixed, r.glitches, r.reason])
	# the board must always be able to deal three different jobs, even for a brand-new crew
	var green: Progress = Progress.new()
	green.unlocked_n = Deck.SHIFT_UNLOCKS_AT
	var offers: Array = Jobs.offers(rng, green)
	var ok_board: bool = offers.size() == 3
	print("job board for a green crew: ", offers.map(func(o): return "%s@%s%s £%d" % [o.task, o.place, str(o.twists), o.pay]))
	if not ok_board:
		fails += 1
	print("JOBS ", "ALL PASS" if fails == 0 else "%d FAILED" % fails, " (%d runs)" % runs)
	quit(1 if fails > 0 else 0)

func run_job(spec: Dictionary, career: Progress, verbose: bool) -> Dictionary:
	var w: World = World.new(int(spec.seed))
	var m: Mission = Jobs.make(spec, career)
	m.setup(w)
	var bots: Array = []
	for st in K.STATIONS:
		bots.append(Bot.new(st))
	var dt: float = K.DT
	var limit: float = m.par * 3.0 + 120.0
	while w.t < limit and not m.done and not m.failed:
		for b in bots:
			b.tick(w, dt)
		w.step(dt)
		for ev in w.events:
			m.on_event(str(ev[0]), ev[1])
			if verbose and str(ev[0]) in ["step", "broke", "glitch", "glitch_fixed", "incident", "radio_done", "radio_missed", "hail", "mission_failed", "bonus", "latched"]:
				print("   %6.1f %s %s" % [w.t, ev[0], ev[1]])
		w.events.clear()
		if verbose and int(w.t * 30.0) % 300 == 0:
			print("   %6.1f step %d pos %s spd %.0f thr %.2f hull %d goal %s" % [w.t, m.step, w.ship.pos.round(), w.ship.speed(), w.ship.throttle, int(w.ship.hull), m.goal_pos()])
	return {"done": m.done, "t": w.t, "par": int(m.par), "hull": int(w.ship.hull), "pay": int(m.result().pay), "reason": m.reason,
		"incidents": m.count("incidents"), "glitches": int(w.stats.get("glitches", 0)), "fixed": int(w.stats.get("glitches_fixed", 0))}
