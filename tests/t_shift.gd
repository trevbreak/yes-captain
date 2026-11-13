extends SceneTree
## A whole Shift run by the host with a robot crew: job board -> three dealt jobs -> rent -> a new card.
## Also checks the glitch plumbing a human crew relies on: bent controls, bent screens and the manual.

func _init() -> void:
	Progress.persist = false
	var fails: Array = []
	var h: GameHost = GameHost.new()
	h.career = Progress.new()
	h.career.unlock_all()
	for id in Missions.ORDER:
		h.career.star_map[id] = 1
	var cards_before: int = Deck.cards(h.career).size()
	h.set_option("mode", "shift")
	h.start_game(77)
	var seen: Dictionary = {}
	var pays: Array = []
	var t: float = 0.0
	var last_phase: String = ""
	var card_title: String = ""
	while t < 1500.0 and not (h.phase == "lobby" and t > 1.0):
		h.sim_step(K.DT)
		t += K.DT
		if h.phase != last_phase:
			last_phase = h.phase
			seen[h.phase] = int(seen.get(h.phase, 0)) + 1
			if h.phase == "debrief":
				pays.append(int(h.debrief.get("pay", 0)))
				card_title = str(h.debrief.get("card", {}).get("title", card_title))
				print("  job %d: %-22s ok=%s pay=%d  earned %d of %d" % [int(h.debrief.n), h.debrief.title, h.debrief.ok, int(h.debrief.pay), int(h.debrief.earned), int(h.debrief.rent)])
	print("  phases: ", seen, "  sim time %.0fs" % t)
	_check(fails, int(seen.get("board", 0)) == 3 and int(seen.get("briefing", 0)) == 3 and int(seen.get("debrief", 0)) == 3, "three jobs were dealt, flown and paid")
	_check(fails, h.phase == "lobby", "the shift ends back in the crew room")
	_check(fails, h.career.shifts == 1, "the shift was counted")
	_check(fails, Deck.cards(h.career).size() == cards_before + 1 and card_title != "", "the crew earned a new card (%s)" % card_title)
	# ---- a brand-new online crew: assumed trained, so every kind of job can be dealt
	var fresh: GameHost = GameHost.new()
	fresh.career = Progress.new()
	_check(fails, Jobs.open_tasks(Deck.features_for(fresh.career)).size() == Jobs.TASKS.size(), "a new crew can be dealt every kind of job")
	var dealt_kinds: Dictionary = {}
	var orng: RandomNumberGenerator = RandomNumberGenerator.new()
	orng.seed = 5
	for i in 30:
		for o in Jobs.offers(orng, fresh.career):
			dealt_kinds[o.task] = true
	_check(fails, dealt_kinds.size() == Jobs.TASKS.size(), "the job board deals all %d kinds of job to a new crew (saw %d)" % [Jobs.TASKS.size(), dealt_kinds.size()])
	fresh.shift_always = true
	fresh.mode = "shift"
	fresh.start_game(91)
	var debriefs: int = 0
	var lp: String = ""
	var t2: float = 0.0
	while t2 < 1500.0 and not (fresh.phase == "lobby" and t2 > 1.0):
		fresh.sim_step(K.DT)
		t2 += K.DT
		if fresh.phase != lp:
			lp = fresh.phase
			if fresh.phase == "debrief":
				debriefs += 1
				print("  new crew job %d: %-22s ok=%s pay=%d" % [int(fresh.debrief.n), fresh.debrief.title, fresh.debrief.ok, int(fresh.debrief.pay)])
	_check(fails, debriefs == 3 and fresh.phase == "lobby" and fresh.career.shifts == 1, "a brand-new crew can fly a whole shift")
	fresh.free()
	# ---- glitches
	var w: World = World.new(5)
	var m: Mission = Missions.make("haven")
	m.setup(w)
	_check(fails, w.add_glitch("backwards_wheel"), "a glitch can be added")
	Intents.apply(w, "helm", "wheel", 0.6)
	_check(fails, absf(w.ship.wheel + 0.6) < 0.001, "backwards wheel: the ship gets the opposite of what Helm asked")
	_check(fails, absf(float(Glitches.bend_view(w, "helm", Snapshots.helm(w)).wheel) - 0.6) < 0.001, "...but Helm's screen still shows the wheel where they put it")
	Intents.apply(w, "helm", "wheel", 0.3, true)
	_check(fails, absf(w.ship.wheel - 0.3) < 0.001, "robots are not fooled")
	_check(fails, not w.add_glitch("drunk_compass"), "one glitch per room")
	var g: Dictionary = w.glitch("backwards_wheel")
	var info: Dictionary = Glitches.engineer_info(w)
	_check(fails, info.has("bridge") and str(info.bridge.ask) != "" and str(g.ask.station) != "helm", "the manual names somebody other than Helm: '%s'" % str(info.get("bridge", {}).get("ask", "")))
	# the Engineer holds REPAIR on the room: nothing happens until the manual's condition is met
	w.ship.repair_target = "bridge"
	w.ship.repairing = true
	_set_ask(w, g, false)
	for i in 120:
		w._repairs(K.DT)
	_check(fails, w.has_glitch("backwards_wheel") and float(g.fix) <= 0.01, "holding REPAIR alone doesn't fix a glitch")
	_set_ask(w, g, true)
	for i in 120:
		w._repairs(K.DT)
	_check(fails, not w.has_glitch("backwards_wheel"), "REPAIR plus the manual's condition fixes it")
	w.add_glitch("upside_chart")
	_check(fails, bool(Glitches.bend_view(w, "captain", Snapshots.captain(w)).get("flip", false)), "the captain's chart flips")
	_check(fails, not Snapshots.helm(w).has("flip") and not Glitches.bend_view(w, "helm", Snapshots.helm(w)).has("ents"), "glitches never leak another seat's data")
	# every glitch can be added, described and removed
	for id in Glitches.DEFS.keys():
		var w2: World = World.new(9)
		Missions.make("haven").setup(w2)
		if not w2.add_glitch(id):
			fails.append("could not add " + id)
		for st in K.SEATS:
			var v: Dictionary = {}
			match st:
				"captain":
					v = Snapshots.captain(w2)
				"helm":
					v = Snapshots.helm(w2)
				"engines":
					v = Snapshots.engines(w2)
				"weapons":
					v = Snapshots.weapons(w2)
				"sensors":
					v = Snapshots.sensors(w2)
				"shields":
					v = Snapshots.shields(w2)
				"engineer":
					v = Snapshots.engineer(w2)
			Glitches.bend_view(w2, st, v)
		for i in 300:
			w2.step(K.DT)
	print("SHIFT ", "PASS" if fails.is_empty() else "FAIL: %s" % str(fails))
	h.free()
	quit(0 if fails.is_empty() else 1)

func _set_ask(w: World, g: Dictionary, met: bool) -> void:
	var a: Dictionary = g.ask
	var s: Ship = w.ship
	var v: float = float(a.val) if met else float(a.val) + (0.5 if str(a.key) in ["throttle", "scan", "fire"] else 1.2)
	match str(a.key):
		"throttle":
			s.throttle = clampf(v if met else (1.0 if float(a.val) < 0.5 else 0.0), 0.0, 1.0)
		"wheel":
			s.wheel = float(a.val) if met else (0.5 if absf(float(a.val)) < 0.5 else 0.0)
		"aim":
			s.aim = K.wrap_pi(v)
		"dir":
			s.shield_dir = K.wrap_pi(v)
		"scan":
			w.scanning = met
		"fire":
			s.firing = met

func _check(fails: Array, ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails.append(what)
