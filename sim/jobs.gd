class_name Jobs
extends RefCounted
## The Shift's jobs are dealt, not written:   a TASK  x  a PLACE  x  one or two TWISTS
## and then a Director drops trouble into the job as it goes (glitches, drones, radio calls, meteors...),
## in waves, backing off when the crew already has its hands full. No two jobs come out the same.

## needs: mechanics the crew must know.  pay: base pay.  danger: 1..3.  par: seconds.
const TASKS: Dictionary = {
	"delivery": {"titles": ["Hot Soup Run", "Parcel Dash", "The Gravy Express"], "client": "gristle", "needs": [], "pay": 100, "danger": 1, "par": 150.0,
		"blurb": "Ma Gristle needs a delivery. Through the rings, park at the diner, and it had better still be warm."},
	"pest": {"titles": ["Pest Control", "Drone Clearance", "Swat Team"], "client": "igor", "needs": [], "pay": 130, "danger": 2, "par": 170.0,
		"blurb": "Hegemony drones are bothering the lanes. The Free Lanes pay per drone. IGOR is told this is called bounty. IGOR calls it tidying."},
	"storm": {"titles": ["Storm Watch", "Rock Sitting", "Weather Duty"], "client": "igor", "needs": [], "pay": 110, "danger": 1, "par": 150.0,
		"blurb": "Somebody must sit in a meteor shower and write down how bad it is. It is bad. That is the whole job."},
	"haul": {"titles": ["Bin Round", "Skip Run", "The Big Collection"], "client": "igor", "needs": ["tractor"], "pay": 120, "danger": 1, "par": 210.0,
		"blurb": "Three skips, one depot. Haul each skip aboard and drop the lot at the depot. Nobody look inside this time."},
	"inspection": {"titles": ["Spot Check", "Papers, Please", "Routine Inspection"], "client": "thrupp", "needs": ["comms"], "pay": 130, "danger": 1, "par": 190.0,
		"blurb": "The Hegemony wants to inspect the ship. Do exactly what the officer says on the radio. Do not mention the pink blob."},
	"bigone": {"titles": ["Cruiser Trouble", "The Big One, Again", "Thrupp's Revenge"], "client": "thrupp", "needs": ["torpedo"], "pay": 220, "danger": 3, "par": 220.0,
		"blurb": "A Hegemony cruiser is parked across the lane. It has a weak spot at the back. Everything else about it is strong spot."},
	"pursuit": {"titles": ["Hot Pursuit", "Leg It", "The Scenic Escape"], "client": "thrupp", "needs": ["boost"], "pay": 190, "danger": 3, "par": 140.0,
		"blurb": "A patrol has spotted us. It cannot be shot. It can be outrun, by a crew that listens. IGOR will pack."},
	"nest": {"titles": ["Grabber Nest", "Clingy Company", "De-lousing"], "client": "igor", "needs": ["grabbers"], "pay": 170, "danger": 2, "par": 180.0,
		"blurb": "A nest of grabber drones. They latch on and chew. Shake them, shield them or shoot them, in any order you can agree on."},
}

## radio callers: {from, portrait, lines: [[text, test, val, who]]}. %s in the text is filled from the test.
const CALLERS: Array = [
	{"from": "Ma Gristle", "pic": "gristle", "reward": 30, "lines": [
		["Is that my delivery ship? Turn your SHIELD to %s o'clock so I can read your number plate, love.", "shield"],
		["You're going too fast past my diner. Engines to ZERO, right now, or no pudding. The food kind.", "stop"],
		["Point that GUN at %s o'clock, away from my windows. I've just had them done.", "gun"]]},
	{"from": "Depot Dispatch", "pic": "igor", "reward": 25, "lines": [
		["Dispatch here. Paperwork says you must face %s for the photograph. Don't ask.", "heading"],
		["Dispatch. We've lost your signal. SCAN something, anything, so we know you're alive.", "scan"],
		["Dispatch. Safety drill. All STOP. Engines to zero until we say. This is us saying.", "stop"]]},
	{"from": "Customs Officer", "pic": "thrupp", "reward": 35, "lines": [
		["Spot check. Turn to face %s. Slowly. We are writing things down.", "heading"],
		["Point your SHIELD at %s o'clock. We like to see what you're hiding behind it.", "shield"],
		["GUN to %s o'clock and keep it there. Do NOT fire it. We know that look.", "gun"]]},
	{"from": "A Telemarketing Robot", "pic": "igor", "reward": 20, "lines": [
		["Hello! Have you considered extended hull warranty? To decline, point your GUN at %s o'clock.", "gun"],
		["Congratulations! You have won a cruise. To claim, face %s. To stop these calls, also face %s.", "heading"],
		["This call may be recorded. To opt out, bring your ship to a complete STOP.", "stop"]]},
	{"from": "Admiral Thrupp", "pic": "thrupp", "reward": 40, "lines": [
		["Thrupp here. I see you. Turn your SHIELD to %s o'clock and I may be merciful. I will not be.", "shield"],
		["This is Admiral Thrupp. Face %s and prepare to be boarded. Or laughed at. I haven't decided.", "heading"]]},
]

const HEADINGS: Array = [["NORTH", -PI / 2.0], ["EAST", 0.0], ["SOUTH", PI / 2.0], ["WEST", PI]]

static func open_tasks(feats: Dictionary) -> Array:
	var out: Array = []
	for id in TASKS.keys():
		var ok: bool = true
		for n in TASKS[id].needs:
			if not bool(feats.get(n, false)):
				ok = false
		if ok:
			out.append(id)
	return out

## the board's three jobs: easy, middling, spicy. Each one is dealt at random from the crew's deck, but its
## task, place and snags have to fit inside that tier's danger budget, so the dice never stack the Minefield,
## Thrupp and a Friday-afternoon ship onto one job.
const TIERS: Array = [
	{"budget": 3, "snags": 1},
	{"budget": 5, "snags": 1},
	{"budget": 7, "snags": 2},
]

static func load_of(task: String, place: String, twists: Array) -> int:
	## how much trouble a job is: the task, plus the place, plus each snag
	var n: int = int(TASKS[task].danger) + int(Deck.PLACES[place].danger)
	for x in twists:
		n += int(Deck.TWISTS[x].get("danger", 1))
	return n

static func offers(rng: RandomNumberGenerator, career: Progress, avoid: Array = []) -> Array:
	## three job cards: an easy one, a middling one and a spicy one
	var feats: Dictionary = Deck.features_for(career)
	var tasks: Array = open_tasks(feats)
	var fresh: Array = tasks.filter(func(t): return not (t in avoid))
	if fresh.size() >= 3:
		tasks = fresh
	_shuffle(rng, tasks)
	var places: Array = ["open"] + Deck.ids(career, "place")
	var twists: Array = Deck.ids(career, "twist")
	var out: Array = []
	var used: Array = []
	for i in mini(TIERS.size(), tasks.size()):
		var tier: Dictionary = TIERS[i]
		var budget: int = int(tier.budget)
		# the first task that fits this tier (the easy job gets an easy task)
		var tid: String = ""
		for cand in tasks:
			if not (cand in used) and int(TASKS[cand].danger) <= (2 if i == 0 else budget - 1):
				tid = cand
				break
		if tid == "":
			for cand in tasks:
				if not (cand in used):
					tid = cand
					break
		used.append(tid)
		var t: Dictionary = TASKS[tid]
		var left: int = budget - int(t.danger)
		# the place: the easy job is usually in open lanes
		var place: String = "open"
		if not (i == 0 and rng.randf() < 0.35):
			var fit: Array = places.filter(func(pl): return int(Deck.PLACES[pl].danger) <= left - int(tier.snags) / 2 \
				and not (tid == "storm" and pl == "shower"))
			if not fit.is_empty():
				place = str(fit[rng.randi() % fit.size()])
		left -= int(Deck.PLACES[place].danger)
		# the snags, while there is budget for them
		var tw: Array = []
		var pool: Array = twists.duplicate()
		_shuffle(rng, pool)
		for x in pool:
			if tw.size() >= int(tier.snags):
				break
			if i == 0 and rng.randf() < 0.5:
				break      # the easy job only has a snag half the time
			var cost: int = int(Deck.TWISTS[x].get("danger", 1))
			if cost > left or (tid == "pursuit" and x in ["one_engine", "thrupp"]):   # a chase already has Thrupp
				continue
			tw.append(x)
			left -= cost
		var mult: float = 1.0 + 0.15 * float(Deck.PLACES[place].danger)
		for x in tw:
			mult += float(Deck.TWISTS[x].pay)
		var danger: int = clampi(load_of(tid, place, tw) - 1, 1, 5)
		out.append({"task": tid, "place": place, "twists": tw, "seed": rng.randi(), "title": str(t.titles[rng.randi() % t.titles.size()]),
			"pay": int(round(float(t.pay) * mult / 5.0)) * 5, "danger": danger, "client": str(t.client), "blurb": str(t.blurb)})
	out.sort_custom(func(a, b): return int(a.danger) < int(b.danger))
	return out

static func _shuffle(rng: RandomNumberGenerator, a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var tmp: Variant = a[i]
		a[i] = a[j]
		a[j] = tmp

static func make(spec: Dictionary, career: Progress, n_in_shift: int = 1) -> Job:
	var j: Job = Job.new()
	j.spec = spec
	j.id = "job_" + str(spec.task)
	j.num = n_in_shift
	j.title = str(spec.title)
	j.features = Deck.features_for(career)
	j.glitch_deck = Deck.ids(career, "glitch")
	return j

# ================================================================ a dealt job

class Job extends Mission:
	var spec: Dictionary = {}
	var glitch_deck: Array = []
	var mods: Dictionary = {}          # bodged upgrades carried through the shift
	var bonus: int = 0
	var fines: int = 0
	var notes: Array = []              # [{text, amount}] for the debrief
	# the radio: a caller wants something done (robots read `current`, like the customs mission)
	var current: Dictionary = {}
	var ok_t: float = 0.0
	var asks_before: int = 0
	var required_asks: Array = []
	# the director
	var dir_t: float = 14.0
	var route: Array = []
	var meteor_t: float = 6.0
	var end_pos: Vector2 = Vector2.ZERO

	func is_job() -> bool:
		return true

	func has(twist: String) -> bool:
		return twist in spec.get("twists", [])

	func build() -> void:
		var t: Dictionary = Jobs.TASKS[spec.task]
		place = str(Deck.PLACES[spec.place].name)
		narrator = str(spec.get("client", "igor"))
		story = str(spec.get("blurb", ""))
		par = float(t.par) * (0.68 if has("rush") else 1.0)
		w.rng.seed = int(spec.get("seed", 1))
		# the way through: a wobbly line heading north
		var p: Vector2 = Vector2.ZERO
		route = [p]
		for i in 5:
			p += Vector2(w.rng.randf_range(-330.0, 330.0), -w.rng.randf_range(430.0, 560.0))
			route.append(p)
		_apply_mods()
		_apply_twists()
		call("_task_" + str(spec.task))
		_apply_place()
		new_thing = {"title": "Today's snags", "who": [], "text": _snag_text()}

	func _snag_text() -> String:
		var bits: Array = ["%s. %s" % [Deck.PLACES[spec.place].name, Deck.PLACES[spec.place].text]]
		for x in spec.get("twists", []):
			bits.append("%s: %s" % [Deck.TWISTS[x].name, Deck.TWISTS[x].text])
		bits.append("And the ship will glitch. It always does. The Engineer's manual has the fixes.")
		return " ".join(PackedStringArray(bits))

	func _apply_mods() -> void:
		var s: Ship = w.ship
		for k in mods.keys():
			if k == "hull":
				s.hull_max = maxf(40.0, 100.0 + float(mods[k]))
				s.hull = s.hull_max
			else:
				s.mods[k] = float(mods[k])

	func _apply_twists() -> void:
		var s: Ship = w.ship
		if has("dented"):
			s.hull = minf(s.hull, s.hull_max * 0.65)
		if has("one_engine"):
			s.sys.engine_s.state = "broken"
			s.sys.engine_s.hp = 0.0
		if has("blind"):
			s.sys.sensors.state = "broken"
			s.sys.sensors.hp = 0.0
		if has("grumpy") and w.feat("pudding"):
			s.pud_mood = 42.0
		if has("weak_reactor"):
			s.power_cap = 5.0
		if spec.place == "fog":
			w.radar_range = World.RADAR_RANGE * 0.55

	func _clear_of(pt: Vector2, keep: Array, gap: float) -> bool:
		for kp in keep:
			if pt.distance_to(kp) < gap:
				return false
		return true

	func _scatter(kind: String, n: int, opts: Dictionary, gap: float) -> void:
		## sprinkle things along the route, never on top of anything that matters
		var keep: Array = [Vector2.ZERO]
		for e in w.ents:
			keep.append(e.pos)
		var placed: int = 0
		var tries: int = 0
		var last: int = maxi(1, _route_len())
		while placed < n and tries < n * 12:
			tries += 1
			var seg: int = w.rng.randi() % last
			var a: Vector2 = route[seg]
			var b: Vector2 = route[seg + 1]
			var pt: Vector2 = a.lerp(b, w.rng.randf()) + Vector2(w.rng.randf_range(-260.0, 260.0), w.rng.randf_range(-120.0, 120.0))
			if not _clear_of(pt, keep, gap) or pt.length() < 240.0:
				continue
			w.spawn(kind, pt, opts)
			keep.append(pt)
			placed += 1

	func _route_len() -> int:
		## how many legs of the route this task actually uses
		for i in range(route.size() - 1, 0, -1):
			if (route[i] as Vector2).distance_to(end_pos) < 1.0:
				return i
		return route.size() - 1

	func _apply_place() -> void:
		match str(spec.place):
			"rocks":
				_scatter("rock", 7, {"scanned": true}, 150.0)
			"mines":
				_scatter("mine", 6, {"ai": "mine"}, 170.0)
			"junkyard":
				_scatter("pod", 4, {"tag": "bonus", "name": "Stray cargo pod"}, 170.0)
				_scatter("rock", 3, {"scanned": true}, 150.0)

	# ---------------------------------------------------------------- tasks

	func _exit_ring(at: Vector2) -> void:
		end_pos = at
		ring(at, "exit", "green")
		add("Out through the green ring", {"helm": "To the green ring. The captain has the map.", "engines": "Home time. Don't cook it on the last leg."},
			func(): return passed("exit"), Callable(), func(): return pos_of("exit"))

	func _dock_step(tag: String, text: String) -> void:
		add(text, {"engines": "Gently does it. Stop right next to it.", "helm": "Line up. Slow ships turn tighter."},
			func():
				var d: Variant = pos_of(tag)
				return d != null and w.ship.pos.distance_to(d) < 175.0 and w.ship.speed() < 9.0, Callable(), func(): return pos_of(tag), {"stop": 115.0})

	func _task_delivery() -> void:
		for i in 3:
			ring(route[i + 1], "r%d" % i)
		var dock: Vector2 = route[4]
		end_pos = dock
		w.spawn("diner", dock, {"tag": "dock", "scanned": true})
		for i in 3:
			add("Through ring %d of 3" % (i + 1), {"helm": "Ring to ring, as the captain calls it.", "engines": "Quick, but ease off for the corners."},
				func(): return passed("r%d" % i), Callable(), func(): return pos_of("r%d" % i))
		_dock_step("dock", "Deliver: stop right next to the diner")

	func _task_pest() -> void:
		add("Scan the drones, then shoot all of them (wave 1)", {
			"sensors": "Scan each new blip: the captain's chart names it, and Weapons gets an aiming mark.",
			"weapons": "Aim where the captain says. Scanned drones show a diamond: put the crosshair on it.",
			"shields": "Drones shoot back. Shield towards them."},
			func(): return count("killed_drone") >= 2, func():
				w.spawn("drone", ahead(450, 0.9), {"ai": "drone"})
				w.spawn("drone", ahead(470, -0.8), {"ai": "drone"}))
		add("More of them! Clear the second wave", {"weapons": "Short bursts. Ask Sensors which blip is which.", "sensors": "New blips: scan them."},
			func(): return count("killed_drone") + count("killed_grabber") >= (6 if w.feat("grabbers") else 5), func():
				for k in 3:
					w.spawn("drone", around(460), {"ai": "drone"})
				if w.feat("grabbers"):
					w.spawn("grabber", around(430), {"ai": "grabber"}))
		_exit_ring(route[2])

	func _task_storm() -> void:
		add("Ride out the meteor shower for 50 seconds", {
			"shields": "Block the meteors. The captain can see them coming; you can't.",
			"captain": "Meteors come from all sides. Call the clock: 'Shield to 4!'",
			"weapons": "You can shoot meteors too, if somebody tells you where to look.",
			"engineer": "Whatever gets through breaks something. Stay on top of it."},
			func(): return step_t >= 50.0)
		_exit_ring(route[2])

	func _task_haul() -> void:
		for i in 3:
			w.spawn("skip", route[i + 1], {"tag": "cargo", "scanned": true, "name": "Skip %d" % (i + 1)})
		var dock: Vector2 = route[4]
		end_pos = dock
		w.spawn("haven", dock, {"tag": "dock", "scanned": true, "name": "The depot"})
		for i in 3:
			add("Haul in the skips with the tractor beam (%d of 3)" % (i + 1), {
				"shields": "Hold TRACTOR when your screen says a skip is in range.",
				"engines": "Get close, then slow right down.",
				"captain": "Get close, get slow, then shout TRACTOR."},
				func(): return count("cargo_in") >= i + 1, Callable(), func(): return _nearest_cargo(), {"seek": "tractor", "stop": 85.0})
		_dock_step("dock", "Drop them off: stop right next to the depot")

	func _nearest_cargo() -> Variant:
		var best: Variant = null
		var bd: float = 1e9
		for e in w.ents:
			if e.alive and e.tag == "cargo" and e.pos.distance_to(w.ship.pos) < bd:
				bd = e.pos.distance_to(w.ship.pos)
				best = e.pos
		return best

	func _task_inspection() -> void:
		var post: Vector2 = route[2]
		w.spawn("customs", post, {"tag": "customs", "scanned": true})
		ring(post + Vector2(0, 230), "line", "mustard")
		add("Stop inside the yellow inspection ring", {"engines": "Slow, then stop inside the ring.", "helm": "Line up with the yellow ring."},
			func():
				var lp: Variant = pos_of("line")
				return lp != null and w.ship.pos.distance_to(lp) < 60.0 and w.ship.speed() < 10.0, Callable(), func(): return pos_of("line"), {"stop": 0.0})
		for i in 3:
			add("The officer is on the radio! Sensors: tune in and read it out (%d of 3)" % (i + 1), {
				"sensors": "Turn the COMMS dial until the signal locks. Then READ THE MESSAGE OUT LOUD.",
				"captain": "Only Sensors can hear the officer. Make them read it out, then tell the right crew.",
				"*": "The officer might want something from you. Listen!"},
				func(): return current.is_empty() and count("asks_done") > asks_before, func():
					asks_before = count("asks_done")
					_radio(Jobs.CALLERS[2], true), Callable(), {"stop": 1e6})
		_exit_ring(route[4])

	func _task_bigone() -> void:
		var at: Vector2 = route[2]
		w.spawn("cruiser", at, {"tag": "cruiser", "ai": "cruiser", "heading": PI / 2.0})
		add("Scan the cruiser twice to find its weak spot", {
			"sensors": "Click the big blip and hold SCAN. Then scan it AGAIN for the weak spot.",
			"shields": "It fires broadsides. The captain will shout when it glows red.",
			"captain": "When the cruiser glows red it's about to fire. Call it!"},
			func():
				var cr: Dictionary = tagged("cruiser")
				return cr.is_empty() or bool(cr.weak_known), Callable(), func(): return pos_of("cruiser"), {"stop": 330.0})
		add("Get behind the cruiser and torpedo its back vent", {
			"weapons": "Hold LOAD, then FIRE TORPEDO when the captain says you're lined up behind it.",
			"helm": "Swing round BEHIND the cruiser.",
			"captain": "Get Helm behind it and Weapons lined up. Only the back counts."},
			func(): return none_left("cruiser"), Callable(), Callable(), {"behind": "cruiser"})
		_exit_ring(route[4])

	func _task_pursuit() -> void:
		var far: Vector2 = route[5] + Vector2(0, -500)
		route.append(far)
		_scatter("mine", 4, {"ai": "mine"}, 190.0)
		end_pos = far
		ring(far, "exit", "green")
		add("Outrun the patrol to the far ring", {
			"engines": "BOOST when the captain says, but don't cook the engines.",
			"helm": "ROLL when the captain shouts! Steer round the mines.",
			"sensors": "Scan the ?s ahead: some of them are mines.",
			"captain": "It fires in threes: when it glows, shout ROLL. Keep clear of mines."},
			func(): return passed("exit"), func():
				w.spawn("patrol", ahead(-430), {"ai": "patrol", "speed": 61.0, "tag": "patrol"}), func(): return pos_of("exit"), {"run": true})

	func _task_nest() -> void:
		add("Grabbers! Get rid of four of them", {
			"helm": "When the captain says SPIN, turn the wheel all the way and hold it.",
			"shields": "Point the shield at a stuck grabber for 2 seconds to knock it off.",
			"weapons": "Aim the turret at a stuck grabber and fire.",
			"captain": "The ship board shows where they're stuck. Pick a plan and call it."},
			func(): return count("killed_grabber") >= 4, func():
				for k in 3:
					w.spawn("grabber", around(430), {"ai": "grabber"}))
		_exit_ring(route[3])

	# ---------------------------------------------------------------- the radio

	func _radio(caller: Dictionary, required: bool = false) -> void:
		var line: Array = caller.lines[w.rng.randi() % caller.lines.size()]
		var test: String = str(line[1])
		var val: float = 0.0
		var word: String = ""
		var who: String = ""
		match test:
			"heading":
				var h: Array = Jobs.HEADINGS[w.rng.randi() % 4]
				word = str(h[0])
				val = float(h[1])
				who = "helm"
			"shield", "gun":
				var hour: int = [3, 6, 9, 12][w.rng.randi() % 4]
				word = str(hour)
				val = K.wrap_pi(float(hour % 12) / 12.0 * TAU)
				who = "shields" if test == "shield" else "weapons"
			"stop":
				who = "engines"
			"scan":
				who = "sensors"
		var text: String = str(line[0]).replace("%s", word)
		current = {"test": test, "val": val, "who": who, "from": str(caller.from), "pic": str(caller.pic), "reward": int(caller.reward),
			"need": required, "heard_t": -1.0}
		ok_t = 0.0
		counters["rescan_mark"] = count("rescanned") + count("scanned")
		w.send_hail(str(caller.from), text)

	func _radio_ok() -> bool:
		var s: Ship = w.ship
		match str(current.test):
			"heading":
				return absf(K.wrap_pi(s.heading - float(current.val))) < deg_to_rad(16.0)
			"shield":
				return absf(K.wrap_pi(s.shield_dir - float(current.val))) < 0.42
			"gun":
				return absf(K.wrap_pi(s.aim - float(current.val))) < 0.34 and not s.firing
			"stop":
				return s.throttle < 0.05 and s.speed() < 4.0
			"scan":
				return count("rescanned") + count("scanned") > count("rescan_mark")
		return false

	func _radio_tick(dt: float) -> void:
		if current.is_empty():
			return
		if w.hail.is_empty():
			current = {}
			return
		var heard: bool = bool(w.hail.get("heard", false))
		if heard and float(current.heard_t) < 0.0:
			current.heard_t = w.t
		if heard:
			ok_t = ok_t + dt if _radio_ok() else 0.0
			if ok_t > 1.4:
				var r: int = int(current.reward)
				bonus += r
				notes.append({"text": "Did as %s asked" % str(current.from), "amount": r})
				counters["asks_done"] = count("asks_done") + 1
				w.emit("radio_done", {"from": current.from, "reward": r, "who": current.who})
				current = {}
				w.hail = {}
				return
		# they don't wait for ever
		var waited: float = w.t - float(w.hail.get("t", w.t))
		if (not heard and waited > 40.0) or (heard and w.t - float(current.heard_t) > 38.0):
			if bool(current.need):
				fines += 25
				notes.append({"text": "Kept %s waiting" % str(current.from), "amount": -25})
				counters["asks_done"] = count("asks_done") + 1
			w.emit("radio_missed", {"from": current.from, "need": bool(current.need)})
			current = {}
			w.hail = {}

	# ---------------------------------------------------------------- the director

	func _trouble() -> int:
		var n: int = w.glitches.size()
		for e in w.ents:
			if e.alive and e.hostile and e.kind in ["drone", "grabber"]:
				n += 1
		for id in Ship.SYSTEMS:
			if w.ship.broken(id):
				n += 1
		if not current.is_empty():
			n += 1
		return n

	func _direct(dt: float) -> void:
		dir_t -= dt
		if dir_t > 0.0:
			return
		var danger: int = int(spec.get("danger", 2))
		if _trouble() >= 2 + danger / 2:
			dir_t = 5.0      # they have enough on: let them breathe
			return
		var gap: float = lerpf(25.0, 15.0, clampf(float(danger - 1) / 4.0, 0.0, 1.0))
		dir_t = w.rng.randf_range(gap * 0.75, gap * 1.25)
		var opts: Array = []
		var gl: Array = Glitches.available(w, glitch_deck)
		if not gl.is_empty() and w.glitches.size() < 2:
			for k in (8 if has("glitchy") else 5):
				opts.append("glitch")
		var task: String = str(spec.task)
		if task not in ["inspection", "pursuit", "nest"]:
			opts.append_array(["drones", "drones"])
		if task != "storm":
			opts.append_array(["meteors", "meteors"])
		if w.feat("comms") and current.is_empty() and w.hail.is_empty():
			opts.append_array(["radio", "radio", "radio"])
		if w.feat("grabbers") and task not in ["inspection", "nest"]:
			opts.append("grabber")
		if w.feat("tractor") and w.alive("pod", "bonus").size() < 2:
			opts.append_array(["pod", "pod"])
		if w.feat("pudding") and not w.ship.pud_out:
			opts.append("fright")
		if w.feat("fire"):
			opts.append("kettle")
		if opts.is_empty():
			return
		var pick: String = opts[w.rng.randi() % opts.size()]
		counters["incidents"] = count("incidents") + 1
		match pick:
			"glitch":
				w.add_glitch(str(gl[w.rng.randi() % gl.size()]))
			"drones":
				var n: int = 1 if danger <= 2 else 2
				for k2 in n:
					w.spawn("drone", around(450), {"ai": "drone"})
				w.emit("incident", {"kind": "drones", "n": n})
			"meteors":
				for k3 in 3:
					throw_junk("rock", 100.0, 440.0 + k3 * 70.0)
				w.emit("incident", {"kind": "meteors"})
			"radio":
				_radio(Jobs.CALLERS[w.rng.randi() % Jobs.CALLERS.size()])
			"grabber":
				w.spawn("grabber", around(440), {"ai": "grabber"})
				w.emit("incident", {"kind": "grabber"})
			"pod":
				w.spawn("pod", around(w.rng.randf_range(300.0, 420.0)), {"tag": "bonus", "name": "Stray cargo pod"})
				w.emit("incident", {"kind": "pod"})
			"fright":
				w.ship.pud_mood = maxf(4.0, w.ship.pud_mood - 34.0)
				w.emit("incident", {"kind": "fright"})
			"kettle":
				var rooms: Array = []
				for id in ["pen", "tractor", "sensors", "bridge"]:
					if w.ship.ok(id) and w.glitch_in(id).is_empty():
						rooms.append(id)
				if not rooms.is_empty():
					w.break_system(str(rooms[w.rng.randi() % rooms.size()]), "caught fire (somebody left the kettle on)", true)

	func extra(dt: float) -> void:
		_radio_tick(dt)
		_direct(dt)
		var task: String = str(spec.task)
		if task == "storm" and step == 0:
			var n: int = int(step_t / 2.7)
			if n > count("thrown") and step_t < 48.0:
				counters["thrown"] = n
				throw_junk("rock", 88.0 + step_t * 0.8, 440.0)
		elif spec.place == "shower":
			meteor_t -= dt
			if meteor_t <= 0.0:
				meteor_t = w.rng.randf_range(6.0, 10.0)
				throw_junk("rock", 95.0, 450.0)
		if task == "nest" and step == 0 and step_t > 20.0 and count("wave2") == 0:
			counters["wave2"] = 1
			for k in 3:
				w.spawn("grabber", around(450), {"ai": "grabber"})
		if has("grumpy") and w.feat("pudding") and not w.ship.pud_out:
			w.ship.pud_mood = maxf(0.0, w.ship.pud_mood - 0.9 * dt)
		if has("thrupp") and count("thrupp_in") == 0 and t > 8.0:
			counters["thrupp_in"] = 1
			w.spawn("patrol", ahead(-460), {"ai": "patrol", "speed": 44.0, "tag": "patrol", "lazy": true})   # watching, mostly: fires half as often
			w.emit("story", {"who": "thrupp", "text": "Thrupp here. I shall be following you today. For the paperwork. And the gloating."})

	func on_event(type: String, d: Dictionary) -> void:
		super.on_event(type, d)
		match type:
			"collected":
				if str(d.get("tag", "")) == "bonus":
					bonus += 40
					notes.append({"text": "Hauled in a stray pod", "amount": 40})
					w.emit("bonus", {"amount": 40})
				elif str(d.get("tag", "")) == "cargo":
					counters["cargo_in"] = count("cargo_in") + 1
			"hit", "bump":
				if has("fragile"):
					fines += 12
					counters["breakages"] = count("breakages") + 1

	# ---------------------------------------------------------------- pay

	func result() -> Dictionary:
		## what the job paid, line by line
		var lines: Array = []
		var total: int = 0
		if done:
			var base: int = int(spec.get("pay", 100))
			lines.append({"text": "The job: %s" % title, "amount": base})
			total += base
			if t <= par:
				var quick: int = int(round(base * 0.25 / 5.0)) * 5
				lines.append({"text": "On time (%s, wanted %s)" % [K.fmt_time(t), K.fmt_time(par)], "amount": quick})
				total += quick
			else:
				lines.append({"text": "Late (%s, wanted %s)" % [K.fmt_time(t), K.fmt_time(par)], "amount": 0})
			var lost: float = w.ship.hull_max - w.ship.hull
			if has("dented"):
				lost = maxf(0.0, w.ship.hull_max * 0.65 - w.ship.hull)
			var dmg: int = int(round(lost * 1.5 / 5.0)) * 5
			if dmg > 0:
				lines.append({"text": "Panel beating (%d%% hull left)" % int(w.ship.hull), "amount": -dmg})
				total -= dmg
			var merged: Dictionary = {}
			for nt in notes:
				merged[str(nt.text)] = int(merged.get(str(nt.text), 0)) + int(nt.amount)
			for k in merged.keys():
				lines.append({"text": k, "amount": int(merged[k])})
				total += int(merged[k])
			if has("fragile") and count("breakages") > 0:
				lines.append({"text": "Breakages (%d knocks)" % count("breakages"), "amount": -count("breakages") * 12})
				total -= count("breakages") * 12
		else:
			lines.append({"text": "Towing fee. IGOR called the tow truck. IGOR knows the driver now.", "amount": -60})
			total -= 60
		return {"pay": total, "lines": lines}

	func briefing() -> Dictionary:
		var b: Dictionary = super.briefing()
		b["job"] = true
		b["pay"] = int(spec.get("pay", 0))
		b["danger"] = int(spec.get("danger", 1))
		return b
