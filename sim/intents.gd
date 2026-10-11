class_name Intents
extends RefCounted
## Every control in the game, per station. Controls that a mission hasn't taught yet are ignored.

static func apply(w: World, station: String, key: String, val: Variant) -> void:
	var s: Ship = w.ship
	match station:
		"helm":
			match key:
				"wheel":
					s.wheel = clampf(float(val), -1.0, 1.0)
				"roll":
					if w.feat("roll") and s.roll_cd <= 0.0 and s.blackout_t <= 0.0:
						s.roll_t = 1.1
						s.roll_cd = 5.0
						w.emit("roll")
		"engines":
			match key:
				"throttle":
					s.throttle = clampf(float(val), 0.0, 1.0)
				"boost":
					s.boost = bool(val) and w.feat("boost")
		"weapons":
			match key:
				"aim":
					s.aim = K.wrap_pi(float(val))
				"fire":
					s.firing = bool(val) and s.ok("gun")
				"load":
					if w.feat("torpedo") and s.torp == "empty" and bool(val):
						s.torp = "loading"
						s.torp_load = 0.0
					elif s.torp == "loading" and not bool(val):
						s.torp = "empty"
						s.torp_load = 0.0
				"torpedo":
					if w.feat("torpedo"):
						w.fire_torpedo()
		"sensors":
			match key:
				"select":
					var id: int = int(val)
					if id != w.scan_target:
						w.scan_target = id
						w.scan_prog = 0.0
				"scan":
					w.scanning = bool(val)
				"freq":
					if w.feat("comms"):
						w.comms_freq = clampf(float(val), 0.0, 1.0)
		"shields":
			match key:
				"dir":
					s.shield_dir = K.wrap_pi(float(val))
				"tractor":
					s.tractor_on = bool(val) and w.feat("tractor")
				"pet":
					s.petting = bool(val) and w.feat("pudding") and not s.pud_out
				"snack":
					if w.feat("pudding") and s.snacks > 0 and not s.pud_out:
						s.snacks -= 1
						s.pud_mood = minf(100.0, s.pud_mood + 30.0)
						w.emit("snack")
				"tin":
					s.tin = bool(val) and w.feat("pudding") and s.pud_out
		"engineer":
			match key:
				"select":
					var sid: String = str(val)
					if sid != s.repair_target:
						s.repair_target = sid if s.sys.has(sid) else ""
						s.repair_prog = 0.0
				"repair":
					s.repairing = bool(val)
				"power":
					if w.feat("power") and val is Dictionary:
						var g: String = str(val.get("group", ""))
						if s.power.has(g):
							s.power[g] = clampi(int(val.get("bars", 2)), 0, 3)
