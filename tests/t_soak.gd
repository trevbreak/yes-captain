extends SceneTree
# Headless soak: an AI captain + competent bots play each encounter. Reports outcome per encounter.

func _init() -> void:
	RunState.persist = false
	var kinds: Array = []
	var arg: String = OS.get_environment("KINDS")
	if arg != "":
		kinds = arg.split(",")
	else:
		kinds = ["binday", "casual", "mines", "checkpoint", "cake", "ducks", "bees", "drones", "pods", "bastion", "photo", "dock", "fin_haven", "fin_return", "fin_sell"]
	var seeds: int = int(OS.get_environment("SEEDS")) if OS.get_environment("SEEDS") != "" else 1
	var temper_env: int = int(OS.get_environment("TEMPER")) if OS.get_environment("TEMPER") != "" else 2
	var wins: int = 0
	var total: int = 0
	for kind in kinds:
		for sd in seeds:
			var h: GameHost = GameHost.new()
			h.broadcast_enabled = false
			h.mode = "shift"
			h.shift_kind = kind
			h.ai_captain = true
			h.default_personality = "competent"
			h.add_peer(1, "Test")
			h.start_game(1000 + sd * 17)
			h.world.temper = temper_env
			if OS.get_environment("TRACTOR") != "":
				for b in h.world.of_kind("bastion"):
					b["tractor"] = true
			h.bot_captain.auto_continue = false
			if OS.get_environment("STRESS") != "":
				h.world.director.intensity = 4.0
				h.world.director.cooldown = 3.0
			var limit: float = 420.0
			var t0: int = Time.get_ticks_msec()
			while h.world.t < limit and (h.phase == "encounter" or h.phase == "briefing"):
				h.sim_step(K.DT)
			var enc: Encounter = h.world.enc
			var res: String = "TIMEOUT"
			if h.phase == "debrief":
				res = "WIN" if enc.success else "LOSE(%s)" % enc.fail_reason
			elif h.phase == "gameover":
				res = "GAMEOVER(%s)" % h.gameover_info.get("reason", "")
			total += 1
			if res == "WIN":
				wins += 1
			print("%-12s seed=%d %-40s t=%5.1f par=%3.0f hull=%5.1f damages=%5.1f real=%dms" % [kind, sd, res, h.world.t, enc.par if enc != null else 0, h.world.ship.hull, h.world.damages_billed, Time.get_ticks_msec() - t0])
			h.free()
	print("SOAK wins %d / %d" % [wins, total])
	quit(total - wins if OS.get_environment("ENFORCE") != "" else 0)
