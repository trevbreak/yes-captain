extends SceneTree
## The online Shift's dealer: an online crew holds the whole deck from the first shift. Deal many boards, fly
## every job with robot crews, and check the danger budget keeps each tier sane and the boards varied.
## BOARDS=n (default 12), VERBOSE=1

func _init() -> void:
	Progress.persist = false
	var boards: int = int(OS.get_environment("BOARDS")) if OS.get_environment("BOARDS") != "" else 12
	var verbose: bool = OS.get_environment("VERBOSE") != ""
	var career: Progress = Progress.new()
	career.full_deck = true
	var fails: int = 0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2026
	var tier_runs: Array = [0, 0, 0]
	var tier_ok: Array = [0, 0, 0]
	var tier_load: Array = [0, 0, 0]
	var tier_pay: Array = [0, 0, 0]
	var tier_hull: Array = [0, 0, 0]
	var max_load: Array = [0, 0, 0]
	var combos: Dictionary = {}
	var places_seen: Dictionary = {}
	var twists_seen: Dictionary = {}
	var glitches_seen: Dictionary = {}
	for bi in boards:
		var offers: Array = Jobs.offers(rng, career)
		if offers.size() != 3:
			fails += 1
			print("FAIL board %d dealt %d jobs" % [bi, offers.size()])
			continue
		for i in 3:
			var o: Dictionary = offers[i]
			var ld: int = Jobs.load_of(str(o.task), str(o.place), o.twists)
			combos["%s|%s|%s" % [o.task, o.place, ",".join(PackedStringArray(o.twists))]] = true
			places_seen[o.place] = true
			for x in o.twists:
				twists_seen[x] = true
			var r: Dictionary = run_job(o, career, glitches_seen)
			tier_runs[i] += 1
			tier_ok[i] += 1 if r.done else 0
			tier_load[i] += ld
			max_load[i] = maxi(max_load[i], ld)
			tier_pay[i] += int(r.pay)
			tier_hull[i] += int(r.hull)
			if verbose or not r.done:
				print("  board %2d tier %d load %d  %-10s %-8s %-26s %s t=%5.1f/%3d hull=%3d pay=%4d glitches=%d/%d %s" % [bi, i, ld, o.task, o.place,
					",".join(PackedStringArray(o.twists)), "PASS" if r.done else "FAIL", r.t, r.par, r.hull, r.pay, r.fixed, r.glitches, r.reason])
	var names: Array = ["easy", "middling", "spicy"]
	var rent: int = Deck.rent(career)
	var shift_pay: int = 0
	for i in 3:
		var n: int = maxi(1, tier_runs[i])
		print("%-9s done %2d/%2d  avg load %.1f (max %d, budget %d)  avg pay £%d  avg hull %d" % [names[i], tier_ok[i], tier_runs[i],
			float(tier_load[i]) / n, max_load[i], int(Jobs.TIERS[i].budget), tier_pay[i] / n, tier_hull[i] / n])
		shift_pay += tier_pay[i] / n
		if max_load[i] > int(Jobs.TIERS[i].budget):
			fails += 1
			print("FAIL %s went over its budget" % names[i])
	print("variety: %d different jobs in %d dealt; places %d/%d, snags %d/%d, glitches seen %d/%d" % [combos.size(), boards * 3,
		places_seen.size(), Deck.PLACES.size(), twists_seen.size(), Deck.TWISTS.size(), glitches_seen.size(), Glitches.DEFS.size()])
	print("a shift of the average job: £%d against rent £%d" % [shift_pay, rent])
	# robots are not people, but a tier robots can't finish is a tier people will hate
	if tier_ok[0] < tier_runs[0]:
		fails += 1
		print("FAIL robots lost an easy job")
	if tier_ok[2] * 10 < tier_runs[2] * 7:
		fails += 1
		print("FAIL robots lost too many spicy jobs")
	# within one shift (three boards, nine jobs on offer) a crew should hardly ever see the same job twice
	var repeats: int = 0
	var srng: RandomNumberGenerator = RandomNumberGenerator.new()
	srng.seed = 7
	for sh in 40:
		var flown: Array = []
		var shift_seen: Dictionary = {}
		for b in 3:
			var board: Array = Jobs.offers(srng, career, flown)
			for o in board:
				var key: String = "%s|%s|%s" % [o.task, o.place, ",".join(PackedStringArray(o.twists))]
				if shift_seen.has(key):
					repeats += 1
				shift_seen[key] = true
			flown.append(str(board[srng.randi() % board.size()].task))
	print("repeats inside a shift: %d in 40 shifts" % repeats)
	if repeats > 4:
		fails += 1
		print("FAIL the boards repeat themselves inside a shift")
	print("DEAL ", "ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)

func run_job(spec: Dictionary, career: Progress, glitches_seen: Dictionary) -> Dictionary:
	var w: World = World.new(int(spec.seed))
	var m: Mission = Jobs.make(spec, career)
	m.setup(w)
	var bots: Array = []
	for st in K.STATIONS:
		bots.append(Bot.new(st))
	var limit: float = m.par * 3.0 + 120.0
	while w.t < limit and not m.done and not m.failed:
		for b in bots:
			b.tick(w, K.DT)
		w.step(K.DT)
		for ev in w.events:
			m.on_event(str(ev[0]), ev[1])
			if str(ev[0]) == "glitch":
				glitches_seen[str(ev[1].get("id", ev[1].get("name", "?")))] = true
		w.events.clear()
	return {"done": m.done, "t": w.t, "par": int(m.par), "hull": int(w.ship.hull), "pay": int(m.result().pay), "reason": m.reason,
		"glitches": int(w.stats.get("glitches", 0)), "fixed": int(w.stats.get("glitches_fixed", 0))}
