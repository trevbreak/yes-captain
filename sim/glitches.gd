class_name Glitches
extends RefCounted
## Glitches: the ship misbehaves. Each one bends a rule of ONE existing control (no new buttons), lives in a
## room of the ship, and stays until the Engineer fixes it. The fix comes from IGOR's manual and always needs
## somebody ELSE to do something with their own control while the Engineer holds REPAIR, so a glitch makes
## three people talk: the one it happened to, the Engineer, and whoever the manual names.
##
## A glitch bends things in three places, all on the host:
##   bend_intent()  a control on its way in        (the wheel is on backwards)
##   bend_view()    a screen on its way out        (the compass reads wrong)
##   World._glitch_tick()  the ship itself         (the throttle creeps up)

const FIX_TIME: float = 2.2
const HINT_AFTER: float = 22.0

## id -> {name, sys (room), station (who suffers), needs (features), hint (IGOR, when it drags on), fixed (IGOR)}
const DEFS: Dictionary = {
	"backwards_wheel": {"name": "Wheel's on backwards", "sys": "bridge", "station": "helm",
		"hint": "Hint for Helm: left is right today. Right is also left. IGOR finds this very funny.",
		"fixed": "Wheel is on the right way round. Left is left again. Enjoy it while it lasts."},
	"drunk_compass": {"name": "Compass is drunk", "sys": "bridge", "station": "helm",
		"hint": "Hint: Helm's compass is lying. Captain's chart is not. One of you should say something.",
		"fixed": "Compass has sobered up. It is very sorry. It remembers nothing."},
	"wheel_drift": {"name": "Wheel wanders off", "sys": "bridge", "station": "helm",
		"hint": "Hint: the wheel is turning itself. Helm did not do that. For once.",
		"fixed": "Wheel has stopped wandering. It has been spoken to."},
	"sticky_throttle": {"name": "Throttle creeps up", "sys": "engine_p", "station": "engines",
		"hint": "Hint: the throttle is creeping up by itself. Engines, it is not a ghost. Probably.",
		"fixed": "Throttle stays where it is put. Like a good throttle."},
	"flipped_throttle": {"name": "Throttle's upside down", "sys": "engine_s", "station": "engines",
		"hint": "Hint for Engines: up is down. IGOR did not design this ship. IGOR would like that on record.",
		"fixed": "Throttle is the right way up. Up is up. Remarkable."},
	"engine_hiccup": {"name": "Engine hiccups", "sys": "engine_p", "station": "engines",
		"hint": "Hint: engine has hiccups. Somebody should frighten it. Engineer is quite frightening.",
		"fixed": "Engine hiccups are cured. Engineer held its breath for it."},
	"gun_pull": {"name": "Gun pulls to one side", "sys": "gun", "station": "weapons",
		"hint": "Hint for Weapons: the gun is not shooting where it points. Like the crew, it lacks focus.",
		"fixed": "Gun shoots straight again. Now misses are entirely Weapons' fault."},
	"mirror_scope": {"name": "Scope is back to front", "sys": "gun", "station": "weapons",
		"hint": "Hint: Weapons is seeing everything on the wrong side. Somebody fitted the scope backwards. A human.",
		"fixed": "Scope is the right way round. Left things are on the left. Luxury."},
	"shield_slip": {"name": "Shield dial slipped", "sys": "shield", "station": "shields",
		"hint": "Hint: the shield is NOT where Shields thinks it is. Captain can see the real one. Compare notes.",
		"fixed": "Shield dial is tight again. Shield is where it says. Novel."},
	"radar_ghosts": {"name": "Ghosts on the radar", "sys": "sensors", "station": "sensors",
		"hint": "Hint: some of those radar blips are not real. IGOR does not believe in ghosts. The radar does.",
		"fixed": "Radar ghosts are gone. They were never there. That is how ghosts work."},
	"upside_chart": {"name": "Chart's upside down", "sys": "sensors", "station": "captain",
		"hint": "Hint for Captain: look at the N on your chart. Is it pointing where N usually points?",
		"fixed": "Chart is the right way up. Captain may now be wrong in the normal direction."},
	"igor_reboot": {"name": "IGOR is rebooting", "sys": "reactor", "station": "captain",
		"hint": "",
		"fixed": "IGOR is back. IGOR had update. IGOR feels exactly the same. Slightly worse."},
	"dead_gauge": {"name": "Heat gauge is stuck", "sys": "engine_s", "station": "engines", "needs": ["heat"],
		"hint": "Hint: Engines' heat gauge is stuck on cold. The engines are not cold. Captain, do tell them.",
		"fixed": "Heat gauge works. It has bad news, but it works."},
	"pudding_sat": {"name": "Pudding is sitting on it", "sys": "pen", "station": "weapons", "needs": ["pudding"],
		"hint": "Hint: Pudding is asleep on the gun controls. Pudding looks very peaceful. Somebody is going to have to move Pudding.",
		"fixed": "Pudding has been moved. Pudding is furious. Gun works."},
}

## the things IGOR's manual can ask another crew member to do (all with controls they already have)
static func _asks(w: World) -> Array:
	var out: Array = [
		{"station": "engines", "key": "throttle", "val": 0.0, "tol": 0.06, "text": "Engines pulls the throttle all the way to ZERO"},
		{"station": "engines", "key": "throttle", "val": 0.5, "tol": 0.08, "text": "Engines sets the throttle to exactly HALF"},
		{"station": "helm", "key": "wheel", "val": 0.0, "tol": 0.08, "text": "Helm holds the wheel dead CENTRE"},
		{"station": "helm", "key": "wheel", "val": -1.0, "tol": 0.2, "text": "Helm holds the wheel hard LEFT"},
		{"station": "helm", "key": "wheel", "val": 1.0, "tol": 0.2, "text": "Helm holds the wheel hard RIGHT"},
		{"station": "sensors", "key": "scan", "val": 1.0, "tol": 0.1, "text": "Sensors holds SCAN (on anything)"},
		{"station": "weapons", "key": "fire", "val": 1.0, "tol": 0.1, "text": "Weapons holds FIRE (at nothing in particular)"},
	]
	for st in [["weapons", "aim", "Weapons points the gun at %d o'clock"], ["shields", "dir", "Shields points the shield at %d o'clock"]]:
		var hour: int = [3, 6, 9, 12][w.rng.randi() % 4]
		out.append({"station": st[0], "key": st[1], "val": K.wrap_pi(float(hour % 12) / 12.0 * TAU), "tol": 0.32, "text": str(st[2]) % hour})
	return out

static func pick_ask(w: World, def: Dictionary) -> Dictionary:
	var pool: Array = []
	for a in _asks(w):
		if str(a.station) == str(def.station):
			continue   # never the person it happened to: they have enough problems
		if str(a.key) == "fire" and not w.ship.ok("gun"):
			continue
		pool.append(a)
	return pool[w.rng.randi() % pool.size()]

static func ask_met(w: World, g: Dictionary) -> bool:
	var a: Dictionary = g.get("ask", {})
	if a.is_empty():
		return true
	var s: Ship = w.ship
	var cur: float = 0.0
	match str(a.key):
		"throttle":
			cur = s.throttle
		"wheel":
			cur = s.wheel
		"aim":
			return absf(K.wrap_pi(s.aim - float(a.val))) <= float(a.tol)
		"dir":
			return absf(K.wrap_pi(s.shield_dir - float(a.val))) <= float(a.tol)
		"scan":
			cur = 1.0 if w.scanning else 0.0
		"fire":
			cur = 1.0 if s.firing else 0.0
	return absf(cur - float(a.val)) <= float(a.tol)

static func can_have(w: World, id: String) -> bool:
	var def: Dictionary = DEFS.get(id, {})
	if def.is_empty() or w.has_glitch(id):
		return false
	for need in def.get("needs", []):
		if not w.feat(str(need)):
			return false
	if id == "pudding_sat" and w.ship.pud_out:
		return false
	# one glitch per room, and one per crew member: it should be a puzzle, not a pile-up
	for g in w.glitches:
		if str(g.sys) == str(def.sys) or str(g.station) == str(def.station):
			return false
	return not w.ship.broken(str(def.sys))

static func available(w: World, deck: Array = []) -> Array:
	var out: Array = []
	for id in DEFS.keys():
		if (deck.is_empty() or id in deck) and can_have(w, id):
			out.append(id)
	return out

# ---------------------------------------------------------------- controls on their way in

static func bend_intent(w: World, station: String, key: String, val: Variant) -> Variant:
	if w.glitches.is_empty():
		return val
	match station:
		"helm":
			if key == "wheel" and w.has_glitch("backwards_wheel"):
				return -float(val)
		"engines":
			if key == "throttle" and w.has_glitch("flipped_throttle"):
				return 1.0 - float(val)
		"shields":
			if key == "dir" and w.has_glitch("shield_slip"):
				return K.wrap_pi(float(val) + float(w.glitch("shield_slip").get("off", 1.0)))
		"weapons":
			if w.has_glitch("pudding_sat") and key in ["fire", "torpedo", "load"]:
				return false
	return val

# ---------------------------------------------------------------- screens on their way out

static func bend_view(w: World, station: String, v: Dictionary) -> Dictionary:
	if w.glitches.is_empty():
		return v
	match station:
		"helm":
			if w.has_glitch("backwards_wheel"):
				v["wheel"] = -float(v.get("wheel", 0.0))     # the wheel on screen stays where Helm put it
			if w.has_glitch("drunk_compass"):
				var off: float = float(w.glitch("drunk_compass").get("off", PI / 2.0))
				v["heading_rad"] = K.wrap_pi(float(v.get("heading_rad", 0.0)) + off)
				v["heading"] = K.bearing_deg(float(v.heading_rad))
		"engines":
			if w.has_glitch("flipped_throttle"):
				v["throttle"] = 1.0 - float(v.get("throttle", 0.0))
			if w.has_glitch("dead_gauge"):
				v["heat"] = 4.0
		"weapons":
			if w.has_glitch("mirror_scope"):
				for e in v.get("view", []):
					e["rel"] = -float(e.rel)
					e["heading"] = -float(e.get("heading", 0.0))
				for b in v.get("bullets", []):
					b["rel"] = -float(b.rel)
			if w.has_glitch("pudding_sat"):
				v["pudding_sat"] = true
		"shields":
			if w.has_glitch("shield_slip"):
				v["dir"] = K.wrap_pi(float(v.get("dir", 0.0)) - float(w.glitch("shield_slip").get("off", 1.0)))
		"sensors":
			if w.has_glitch("radar_ghosts") and bool(v.get("ok", true)):
				var blips: Array = v.get("blips", [])
				for gh in w.glitch("radar_ghosts").get("ghosts", []):
					var a: float = float(gh.a) + w.t * float(gh.spin)
					var p: Vector2 = Vector2.from_angle(a) * float(gh.d)
					blips.append({"id": int(gh.id), "x": snappedf(p.x, 0.1), "y": snappedf(p.y, 0.1), "kind": "unknown", "name": "Unknown contact",
						"scanned": false, "hostile": false, "weak": false, "dist": snappedf(float(gh.d), 0.1)})
				v["blips"] = blips
		"captain":
			if w.has_glitch("upside_chart"):
				v["flip"] = true
			if w.has_glitch("igor_reboot"):
				v["warnings"] = [{"text": "IGOR IS REBOOTING. PLEASE WAIT. OR PANIC.", "level": 1, "who": ""}]
				v["rebooting"] = true
	return v

# ---------------------------------------------------------------- what people are told

static func engineer_info(w: World) -> Dictionary:
	## room -> what the Engineer's manual says about the glitch in it
	var out: Dictionary = {}
	for g in w.glitches:
		out[str(g.sys)] = {"name": str(DEFS[g.id].name), "ask": str(g.ask.get("text", "")), "met": ask_met(w, g),
			"who": str(g.ask.get("station", "")), "prog": snappedf(float(g.get("fix", 0.0)), 0.01)}
	return out

static func rooms(w: World) -> Array:
	var out: Array = []
	for g in w.glitches:
		out.append(str(g.sys))
	return out

static func bothers(w: World, station: String) -> bool:
	## true once a glitch has been annoying this station long enough that we admit something is up
	for g in w.glitches:
		if str(g.station) == station and float(g.t) > 5.0:
			return true
	return false

static func bot_ask(w: World, station: String) -> Dictionary:
	## what a robot at this station should do to help the Engineer right now ({} = nothing)
	if not w.ship.repairing:
		return {}
	for g in w.glitches:
		if str(g.sys) == w.ship.repair_target and str(g.ask.get("station", "")) == station:
			return g.ask
	return {}
