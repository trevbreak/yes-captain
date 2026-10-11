extends SceneTree
# Full campaign with an AI captain and competent bots: lobby -> encounters -> map/ritual -> pit stop -> ending.

func _init() -> void:
	RunState.persist = false
	var seeds: int = int(OS.get_environment("SEEDS")) if OS.get_environment("SEEDS") != "" else 1
	var length: String = OS.get_environment("LENGTH") if OS.get_environment("LENGTH") != "" else "short"
	var endings: Dictionary = {}
	var overs: int = 0
	var bad: int = 0
	for sd in seeds:
		var h: GameHost = GameHost.new()
		h.broadcast_enabled = false
		h.mode = "run"
		h.run_length = length
		h.ai_captain = true
		h.default_personality = "competent"
		h.add_peer(1, "Test")
		h.start_game(5000 + sd * 31)
		var last_phase: String = ""
		var log: Array = []
		var limit: float = 4000.0
		var t_total: float = 0.0
		var t0: int = Time.get_ticks_msec()
		while t_total < limit and h.phase != "lobby" and h.phase != "ending" and h.phase != "gameover":
			h.sim_step(K.DT)
			t_total += K.DT
			if h.phase == "encounter" and h.world.enc != null and h.world.enc.t > 500.0 and int(h.world.enc.t * 30) % 900 == 0:
				var sh: Ship = h.world.ship
				var hh: Dictionary = h.world.enc.hint()
				print("HANG? enc=%s t=%.0f obj=%s pos=(%.0f,%.0f) goal=%s spd=%.1f head=%.2f thr=%.2f/%.2f crit=%d hint=%s" % [h.world.enc.id, h.world.enc.t, h.world.enc.objective_text, sh.pos.x, sh.pos.y, str(h.world.enc.goal), sh.speed(), sh.heading, sh.thr_p, sh.thr_s, sh.open_problems().critical, str(hh)])
				print("   alloc=", sh.alloc, " eng ok P/S ", sh.mod_state("ENG_P"), sh.mod_state("ENG_S"), " link ", sh.link, " rcs ", sh.mod_state("RCS_FP"), sh.mod_state("RCS_FS"), sh.mod_state("RCS_AP"), sh.mod_state("RCS_AS"), " cond ", sh.conduits)
				var ww: World = h.world
				var dr: Array = []
				for e in ww.ents:
					if e.kind in ["grabber","snatch"]:
						dr.append("%s st=%s d=%.0f rel=%s hp=%.0f scanned=%s age=%.0f" % [e.kind, e.state, e.pos.distance_to(sh.pos), str((e.pos - sh.pos).rotated(-sh.heading)), e.hp, str(ww.is_scanned(e)), ww.t - float(e.scan)])
				print("   stowed=", ww.stowed, " lock=", ww.lock_id, " sel=", ww.sel_turret, " track=", ww.track, " loadhold=", ww.load_hold, " tur=", ww.ship.modules["TUR_A"].loaded, ww.ship.modules["TUR_B"].loaded, ww.ship.mod_state("TUR_A"), ww.ship.mod_state("TUR_B"), " ang=", ww.ship.modules["TUR_A"].ang, ww.ship.modules["TUR_B"].ang, " tgt=", ww.ship.modules["TUR_A"].tgt, ww.ship.modules["TUR_B"].tgt, " pf_w=", ww.ship.pf("weapons"), " scan=", ww.scan, " drones=", dr)
				if h.world.enc.t > 700.0:
					break
			var tag: String = h.phase + ":" + (h.world.enc.id if h.world.enc != null and h.phase == "encounter" else "")
			if tag != last_phase:
				last_phase = tag
				log.append("%s@%.0f" % [tag, t_total])
		var res: String = h.phase
		if h.phase != "ending":
			bad += 1
		if h.phase == "ending":
			endings[h.ending.id] = int(endings.get(h.ending.id, 0)) + 1
		elif h.phase == "gameover":
			overs += 1
		print("run seed=%d result=%s t=%.0fs hull=%.0f temper=%d scrap=%d fuel=%d jumps=%d real=%dms" % [sd, res, t_total, h.world.ship.hull, h.run.temper_level(), h.run.scrap, h.run.fuel, h.run.jumps, Time.get_ticks_msec() - t0])
		print("   ", " > ".join(log))
		if h.phase == "gameover":
			print("   GAMEOVER reason: ", h.gameover_info.get("reason"))
		h.free()
	print("RUNS endings=", endings, " gameovers=", overs, " not-finished=", bad)
	quit(bad if OS.get_environment("ENFORCE") != "" else 0)
