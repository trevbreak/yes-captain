extends SceneTree
# Core sim smoke test: physics asymmetry, power, damage, repair.

func _init() -> void:
	var fails: int = 0
	var w: World = World.new(1234)
	var s: Ship = w.ship
	# 1. symmetric thrust goes straight
	s.thr_p = 1.0
	s.thr_s = 1.0
	for i in 150:
		w.step(K.DT)
	print("straight: speed=%.1f angvel=%.3f heading=%.3f" % [s.speed(), s.angvel, s.heading])
	if absf(s.angvel) > 0.05:
		print("FAIL straight flight has spin"); fails += 1
	# 2. kill port engine => spins toward the dead side's opposite (starboard engine alone pushes right... check sign)
	var w2: World = World.new(5)
	w2.ship.thr_p = 1.0
	w2.ship.thr_s = 1.0
	w2.ship.modules["ENG_P"].hp = 5.0
	for i in 90:
		w2.step(K.DT)
	print("port engine dead: angvel=%.3f (negative = turning left toward dead engine)" % w2.ship.angvel)
	if w2.ship.angvel >= -0.05:
		print("FAIL expected spin toward dead engine"); fails += 1
	# 3. hit + damage + repair
	var w3: World = World.new(9)
	w3.ship.hit(Vector2(0, 1), 40.0, "test")
	print("after hit: hull=%.1f shield0=%.1f" % [w3.ship.hull, w3.ship.shield[0]])
	var oc: Dictionary = w3.ship.open_problems()
	print("open problems:", oc)
	for k in 10:
		w3.ship.hit(Vector2.from_angle(randf() * TAU), 30.0, "test")
	var broken: Array = []
	for id in w3.ship.mod_order:
		if w3.ship.mod_state(id) >= 2:
			broken.append(id)
	print("broken: ", broken)
	for id in broken:
		w3.ship.repair_module(id)
	for c in K.CONDUITS:
		if w3.ship.conduits[c].cut:
			w3.ship.repair_conduit(c)
	var left: int = 0
	for id in w3.ship.mod_order:
		if w3.ship.mod_state(id) >= 1:
			left += 1
	print("still damaged after repairs: ", left)
	# 4. power scram
	var w4: World = World.new(3)
	w4.ship.alloc["engines"] = 5
	w4.ship.alloc["weapons"] = 4
	w4.ship.pump = false
	w4.ship.cool_p = 0.0
	var scram: bool = false
	for i in 30 * 200:
		w4.step(K.DT)
		for ev in w4.events:
			if ev[0] == "scram":
				scram = true
		w4.events.clear()
		if scram:
			break
	print("scram happened: ", scram, " at t=%.1f" % w4.t)
	# 5. encounters can be constructed and ticked
	for kind in Encounters.INFO.keys():
		var wx: World = World.new(77)
		var enc: Encounter = Encounters.make(kind, 2)
		wx.enc = enc
		enc.setup(wx)
		for i in 60:
			wx.step(K.DT)
		print("enc ", kind, " ok ents=", wx.ents.size(), " obj=", enc.objective_text)
	print("DONE fails=", fails)
	quit(fails)
