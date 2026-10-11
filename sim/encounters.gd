class_name Encounters
extends RefCounted
## All encounters live here as inner classes. Encounters.make(kind, temper, rng) builds one.

const INFO: Dictionary = {
	"binday": {"name": "Bin Day", "family": "Precision", "blurb": "Routine skip collection. Tractor beam practice.", "threat": 0},
	"casual": {"name": "Fly Casual", "family": "Stealth", "blurb": "Hegemony patrols ahead. Sneak past. Do NOT be loud.", "threat": 1},
	"mines": {"name": "Minefield", "family": "Hazard", "blurb": "Mines. Only Sensors can see them.", "threat": 2},
	"checkpoint": {"name": "Have You Seen This Pet?", "family": "Bluff", "blurb": "Customs checkpoint. Bluff your way through.", "threat": 1},
	"cake": {"name": "The Wedding Cake", "family": "Odd Job", "blurb": "Deliver a wedding cake. Gently. Very gently.", "threat": 1},
	"ducks": {"name": "4,000 Rubber Ducks", "family": "Odd Job", "blurb": "The cargo doors are broken. The ducks want freedom.", "threat": 1},
	"bees": {"name": "Definitely Not Bees", "family": "Odd Job", "blurb": "Don't hit anything. Don't get hot. Don't ask.", "threat": 2},
	"drones": {"name": "Grabber Ambush", "family": "Combat", "blurb": "Drones want to pry open your ship looking for the pet.", "threat": 2},
	"pods": {"name": "Snatch Pods", "family": "Combat", "blurb": "Boarding pods with a pet carrier built in.", "threat": 3},
	"bastion": {"name": "Bastion Cruiser", "family": "Combat", "blurb": "A fortress with a marching band deck. Weak spot at the rear.", "threat": 3},
	"photo": {"name": "Say Cheese", "family": "Calm", "blurb": "Proof of Life photo. Keep Pudding calm and the ship still.", "threat": 0},
	"dock": {"name": "Ma Gristle's Diner", "family": "Precision", "blurb": "Dock with a rotating diner. Pit stop ahead.", "threat": 0},
	"fin_haven": {"name": "Run to Haven", "family": "Finale", "blurb": "Outrun the Overlord to the Free Lanes' Haven.", "threat": 5},
	"fin_return": {"name": "Return to Sender", "family": "Finale", "blurb": "Dock with the Magnificence. Politely. Under fire.", "threat": 5},
	"fin_sell": {"name": "The Deal", "family": "Finale", "blurb": "Meet Velvet's ship. Don't get blown up on the way.", "threat": 4},
}

const MID_KINDS: Array = ["casual", "mines", "checkpoint", "cake", "ducks", "bees", "drones", "pods", "bastion", "photo"]

static func make(kind: String, temper: int = 1) -> Encounter:
	var e: Encounter
	match kind:
		"binday":
			e = BinDay.new()
		"casual":
			e = FlyCasual.new()
		"mines":
			e = Minefield.new()
		"checkpoint":
			e = Checkpoint.new()
		"cake", "ducks", "bees":
			e = OddJob.new()
			e.variant = kind
		"drones":
			e = DroneAmbush.new()
		"pods":
			e = SnatchPods.new()
		"bastion":
			e = BastionFight.new()
		"photo":
			e = SayCheese.new()
		"dock":
			e = DockDiner.new()
		"fin_haven", "fin_sell":
			e = FinaleRun.new()
			e.variant = kind
		"fin_return":
			e = FinaleReturn.new()
		_:
			e = BinDay.new()
	e.id = kind
	e.title = str(INFO.get(kind, {}).get("name", kind))
	e.family = str(INFO.get(kind, {}).get("family", "Precision"))
	return e

# ================================================================ Bin Day
class BinDay extends Encounter:
	var skips: Array = []
	var special_id: int = -1
	var collected: int = 0
	var special_done_t: float = -1.0
	var broke: bool = false

	func _setup() -> void:
		par = 200.0
		w.ship.pud["aboard"] = false
		w.ship.pud["mood"] = 10.0
		brief = "Bin run! Collect the 3 skips with the tractor beam (Ops), then the 4th. It's warm. Don't ask."
		var angs: Array = [-2.3, -1.2, -0.3, 0.9]
		for i in 4:
			var d: float = 170.0 + 90.0 * i
			var a: float = angs[i] + w.rng.randf_range(-0.2, 0.2)
			var p: Vector2 = Vector2.from_angle(a - PI / 2.0 + 0.4) * d
			var e: Dictionary = w.spawn("skip", p, {"vel": Vector2.from_angle(w.rng.randf() * TAU) * w.rng.randf_range(0.5, 2.0), "angvel": w.rng.randf_range(-0.5, 0.5)})
			if i == 3:
				e.name = "Warm Skip"
				e.r = 5.0
				special_id = e.id
			else:
				e.name = "Skip %d" % (i + 1)
			skips.append(e.id)

	func _tick(_dt: float) -> void:
		objective_text = "Skips collected: %d / 4" % collected
		prog = float(collected) / 4.0
		if not broke and t > 50.0:
			broke = true
			w.director.fire_incident("engine")
		if special_done_t > 0.0 and t - special_done_t > 7.0:
			finish(true)

	func on_event(type: String, data: Dictionary) -> void:
		if type == "collected":
			collected += 1
			if int(data.id) == special_id:
				special_done_t = t
				w.ship.pud["aboard"] = true
				w.ship.pud["mood"] = 55.0
				w.emit("pudding_found", {})
				w.hail("Admiral Thrupp", "Attention, garbage vessel. You have collected a... parcel. Please return it. Gently. I will be demoted.")

	func hint() -> Dictionary:
		var best: Dictionary = {}
		var bd: float = 1e9
		for sid in skips:
			var e: Dictionary = w.find(sid)
			if e.is_empty():
				continue
			var d: float = e.pos.distance_to(w.ship.pos)
			if sid == special_id:
				d += 2000.0
			if d < bd:
				bd = d
				best = e
		if best.is_empty():
			return {"goal": w.ship.pos, "speed": 0.0, "arrive": 30.0}
		return {"goal": best.pos, "speed": 30.0, "arrive": 12.0, "tractor": best.id, "match": best.vel, "tractor_range": 80.0}

# ================================================================ Fly Casual
class FlyCasual extends Encounter:
	var suspicion: float = 0.0
	var spotted: bool = false
	var patrols: Array = []
	var sig: float = 0.0

	func _setup() -> void:
		par = 150.0
		brief = "Fly Casual. Slip past the patrols to the green ring. Keep it slow (under 24 m/s), no pings, no fireworks. Suspicion is on YOUR sticky note only."
		place_goal(900.0, 0.25)
		var n: int = 2 if w.temper < 3 else 3
		for i in n:
			var y: float = -260.0 - 260.0 * i
			var side: float = -1.0 if i % 2 == 0 else 1.0
			var p: Dictionary = w.spawn("patrol", Vector2(side * 170.0, y), {"vel": Vector2(-side * 5.0, 0.0), "ang": PI if side > 0 else 0.0})
			p["side"] = side
			patrols.append(p.id)
		w.director.intensity = 0.7

	func _tick(dt: float) -> void:
		var s: Ship = w.ship
		sig = s.speed() / 30.0
		if w.ping_t > 0.0:
			sig += 2.0
		if absf(s.angvel) > 1.0:
			sig += 0.5
		if s.boost:
			sig += 0.8
		if float(s.pud["mood"]) > 70.0:
			sig += 0.8
		var seen: bool = false
		for pid in patrols:
			var p: Dictionary = w.find(pid)
			if p.is_empty():
				continue
			if p.state != "hostile":
				# patrols sweep back and forth across the lane
				if absf(p.pos.x) > 240.0:
					p.vel = Vector2(-signf(p.pos.x) * 5.0, 0.0)
			if p.pos.distance_to(s.pos) < 260.0:
				seen = true
		if seen and not spotted:
			suspicion += maxf(0.0, sig - 0.8) * 12.0 * dt
		else:
			suspicion = maxf(0.0, suspicion - 5.0 * dt)
		suspicion = clampf(suspicion, 0.0, 100.0)
		if suspicion >= 100.0 and not spotted:
			spotted = true
			temper_delta += 1
			for pid2 in patrols:
				var p2: Dictionary = w.find(pid2)
				if not p2.is_empty():
					p2.state = "hostile"
					p2.fire_t = 4.0
			spawn_wave("grabber", 2, 350.0)
			w.emit("spotted", {})
		objective_text = "Reach the green ring unnoticed" if not spotted else "SPOTTED! Reach the ring!"
		prog = clampf(1.0 - s.pos.distance_to(goal) / 900.0, 0.0, 1.0)
		if at_goal():
			finish(true)

	func captain_data() -> Dictionary:
		return {"meters": [{"label": "SUSPICION", "v": suspicion, "max": 100.0, "color": "coral"}]}

	func station_data(st: String) -> Dictionary:
		if st == "sensors":
			var rings: Array = []
			for pid in patrols:
				var p: Dictionary = w.find(pid)
				if not p.is_empty():
					rings.append({"pos": p.pos, "r": 260.0})
			return {"rings": rings}
		return {}

	func hint() -> Dictionary:
		return goal_hint(20.0, {"stealth": true, "no_fire": not spotted})

# ================================================================ Minefield
class Minefield extends Encounter:
	func _setup() -> void:
		par = 170.0
		brief = "Minefield! The mines are invisible from the window. Sensors is the only one who can see them. Talk each other through."
		place_goal(850.0, 0.1)
		var n: int = 34
		var placed: int = 0
		var tries: int = 0
		while placed < n and tries < 500:
			tries += 1
			var along: float = w.rng.randf_range(160.0, 700.0)
			var across: float = w.rng.randf_range(-170.0, 170.0)
			var p: Vector2 = Vector2(across, -along)
			p = p.rotated(goal.angle() + PI / 2.0)
			if p.distance_to(goal) < 70.0:
				continue
			var ok: bool = true
			for e in w.ents:
				if e.kind == "mine" and e.pos.distance_to(p) < 42.0:
					ok = false
					break
			if ok:
				w.spawn("mine", p)
				placed += 1
		w.director.intensity = 0.6

	func _tick(_dt: float) -> void:
		objective_text = "Cross the minefield to the green ring"
		prog = clampf(1.0 - w.ship.pos.distance_to(goal) / 850.0, 0.0, 1.0)
		if at_goal():
			finish(true)

	func hint() -> Dictionary:
		var avoid: Array = []
		for e in w.ents:
			if e.kind == "mine":
				avoid.append([e.pos, 46.0])
		return goal_hint(16.0, {"avoid": avoid})

# ================================================================ Checkpoint
class Checkpoint extends Encounter:
	const PAINTS: Array = ["Blue", "Green", "Red", "Yellow"]
	const CARGOS: Array = ["Poultry", "Antiques", "Rubber Ducks", "Nothing At All"]
	const TXS: Array = ["K-417", "M-902", "T-118", "Z-663"]
	const ANSWERS: Array = ["Poultry delivery", "Family holiday", "Definitely not smuggling", "Lost, sorry"]
	const SIGS: Array = ["Low", "Medium", "High"]
	var req: Dictionary = {}
	var settings: Dictionary = {"paint": "Blue", "cargo": "Poultry", "tx": "K-417", "answer": "Poultry delivery", "sig": "Low"}
	var chk_id: int = -1
	var inspect: float = 0.0
	var result: String = ""
	var after_t: float = 0.0

	func _setup() -> void:
		par = 160.0
		req = {"paint": PAINTS[w.rng.randi() % 4], "cargo": CARGOS[w.rng.randi() % 4], "tx": TXS[w.rng.randi() % 4],
			"answer": ANSWERS[w.rng.randi() % 4], "sig": SIGS[w.rng.randi() % 3]}
		var opts: Dictionary = {"paint": PAINTS, "cargo": CARGOS, "tx": TXS, "answer": ANSWERS, "sig": SIGS}
		for k in req.keys():
			var arr: Array = opts[k]
			settings[k] = arr[0] if arr[0] != req[k] else arr[1]
		brief = "Customs! Read the APPROVED VESSEL sheet to your crew. Every station sets one thing. Then park at the checkpoint and sit still."
		var c: Dictionary = w.spawn("patrol", Vector2(0.0, -500.0), {"name": "Customs Cruiser", "r": 22.0})
		c.vel = Vector2.ZERO
		chk_id = c.id
		goal = c.pos
		w.hail("Customs Officer", "Please approach and hold station for inspection. Smile, you are being scanned.")
		w.director.intensity = 0.5

	func _count() -> int:
		var n: int = 0
		for k in req.keys():
			if settings[k] == req[k]:
				n += 1
		if w.stowed:
			n += 1
		return n

	func _tick(dt: float) -> void:
		var s: Ship = w.ship
		var c: Dictionary = w.find(chk_id)
		if result == "":
			var close: bool = s.pos.distance_to(c.pos) < 120.0 + 22.0
			if close and s.speed() < 6.0:
				inspect += dt / 22.0
			else:
				inspect = maxf(0.0, inspect - dt / 40.0)
			objective_text = "Approach the checkpoint and hold still" if inspect <= 0.01 else "INSPECTING... %d%%" % int(inspect * 100.0)
			prog = inspect
			if inspect >= 1.0:
				var good: bool = _count() >= 5 and float(s.pud["mood"]) < 60.0
				if good:
					result = "pass"
					temper_delta = -1
					w.emit("checkpoint_pass", {})
					w.hail("Customs Officer", "All in order. Have a lovely day. Report any fluffy sightings.")
					after_t = t
				else:
					result = "fail"
					temper_delta = 1
					w.emit("checkpoint_fail", {"count": _count()})
					w.hail("Customs Officer", "Hmm. Something is off. Please remain where you are. SEND THE DRONES.")
					spawn_wave("grabber", 3, 260.0)
					after_t = t
		else:
			if result == "pass" and t - after_t > 3.0:
				finish(true)
			if result == "fail":
				objective_text = "BUSTED! Survive the drones"
				if w.of_kind("grabber").is_empty() and t - after_t > 6.0:
					finish(true)
				elif t - after_t > 70.0:
					finish(true)

	func on_intent(st: String, key: String, v: Variant) -> bool:
		if key == "set" and result == "":
			var cid: String = str(v.get("id", ""))
			if settings.has(cid):
				settings[cid] = v.get("value")
				return true
		return false

	func captain_data() -> Dictionary:
		return {"sheet": [
			"APPROVED VESSEL: 'The Wobbly Hen'",
			"Hull paint: %s" % req.paint,
			"Declared cargo: %s" % req.cargo,
			"Transponder: %s" % req.tx,
			"Engine signature: %s" % req.sig,
			"Guns: STOWED",
			"If asked 'purpose of voyage': \"%s\"" % req.answer,
		], "meters": [{"label": "INSPECTION", "v": inspect * 100.0, "max": 100.0, "color": "teal"}]}

	func station_data(st: String) -> Dictionary:
		match st:
			"ops":
				return {"controls": [
					{"id": "paint", "label": "Hull paint", "options": PAINTS, "value": settings.paint},
					{"id": "cargo", "label": "Declared cargo", "options": CARGOS, "value": settings.cargo}], "title": "CUSTOMS FORM (Ops)"}
			"sensors":
				return {"controls": [
					{"id": "tx", "label": "Transponder", "options": TXS, "value": settings.tx},
					{"id": "answer", "label": "Purpose of voyage?", "options": ANSWERS, "value": settings.answer}], "title": "CUSTOMS FORM (Sensors)"}
			"engines":
				return {"controls": [{"id": "sig", "label": "Engine signature", "options": SIGS, "value": settings.sig}], "title": "CUSTOMS FORM (Engines)"}
			"weapons":
				return {"info": "Customs wants the guns STOWED. Use the Stow button."}
		return {}

	func hint() -> Dictionary:
		var stop: bool = w.ship.pos.distance_to(goal) < 130.0
		return goal_hint(0.0 if stop else 18.0, {"arrive": 100.0, "stop": stop, "stow": true, "settings": {
			"ops": {"paint": req.paint, "cargo": req.cargo}, "sensors": {"tx": req.tx, "answer": req.answer},
			"engines": {"sig": req.sig}}, "calm": true})

# ================================================================ Odd job (cake / ducks / bees)
class OddJob extends Encounter:
	var variant: String = "cake"
	var item: Dictionary = {}
	var chaser_t: float = 0.0
	var lost_start: int = 0

	func _setup() -> void:
		par = 180.0
		var s: Ship = w.ship
		s.cargo_secured = false
		match variant:
			"cake":
				item = {"name": "Wedding Cake", "limit": 5.0, "fragility": 1.5, "integrity": 100.0}
				brief = "Deliver the WEDDING CAKE to the green ring. It breaks above 5 m/s^2 of acceleration. Tell Engines: gently!"
			"ducks":
				item = {"name": "Rubber Ducks", "limit": 4.0, "fragility": 0.4, "integrity": 100.0, "leaks": true, "lost": 0}
				brief = "4,000 RUBBER DUCKS. The cargo doors are stuck open. Accelerate hard and they pour out. Deliver most of them."
				s.modules["CARGO"].hp = 30.0
				s.modules["CARGO"].fault = "doors"
			"bees":
				item = {"name": "Definitely Not Bees", "limit": 8.0, "fragility": 0.6, "integrity": 100.0}
				brief = "Definitely Not Bees. Don't get hit. Don't get hot (keep the reactor cool). We don't talk about it."
		s.cargo = [item]
		place_goal(950.0, 0.3, 32.0)
		par = 200.0

	func _tick(dt: float) -> void:
		var s: Ship = w.ship
		if variant == "bees":
			if s.reactor_heat > 72.0:
				item["integrity"] = maxf(0.0, float(item["integrity"]) - 2.5 * dt)
		objective_text = "Deliver the %s gently" % item.name
		prog = clampf(1.0 - s.pos.distance_to(goal) / 950.0, 0.0, 1.0)
		if w.temper >= 2 and chaser_t >= 0.0:
			chaser_t += dt
			if chaser_t > 40.0:
				chaser_t = -1.0
				spawn_wave("grabber", 1 + (w.temper - 1) / 2, 400.0)
		if float(item["integrity"]) <= 0.0:
			finish(false, "The %s is now a hat." % item.name)
			return
		if at_goal(32.0) and s.speed() < 6.0:
			s.cargo.clear()
			finish(true)

	func on_event(type: String, data: Dictionary) -> void:
		if variant == "bees" and (type == "hull_hit" or type == "collision"):
			item["integrity"] = maxf(0.0, float(item["integrity"]) - (float(data.get("amount", 5.0)) * 1.2 if type == "hull_hit" else 6.0))

	func captain_data() -> Dictionary:
		var meters: Array = [{"label": str(item.name).to_upper(), "v": float(item["integrity"]), "max": 100.0, "color": "butter"}]
		if variant == "ducks":
			meters.append({"label": "DUCKS LOST", "v": float(item.get("lost", 0)), "max": 60.0, "color": "coral", "invert": true})
		return {"meters": meters}

	func station_data(st: String) -> Dictionary:
		if st == "ops":
			return {"info": "Cargo: %s - %d%%" % [item.name, int(item["integrity"])]}
		return {}

	func hint() -> Dictionary:
		var d: float = w.ship.pos.distance_to(goal)
		return goal_hint(11.0 if variant == "cake" else 14.0, {"gentle": true, "arrive": 18.0, "stop": d < 34.0, "keep_cool": variant == "bees"})

# ================================================================ Grabber ambush
class DroneAmbush extends Encounter:
	var total: int = 4
	var spawned: int = 0
	var timer: float = 4.0

	func _setup() -> void:
		par = 120.0
		total = clampi(3 + w.temper, 4, 8)
		brief = "Grabber drones inbound! They latch on and pry your ship open. Shoot them, or spin hard to shake them off. Kill all %d." % total
		w.director.intensity = 0.8
		w.hail("Admiral Thrupp", "Release the pet or I will release the DRONES. They have been briefed to be gentle. Mostly.")

	func _tick(dt: float) -> void:
		timer -= dt
		if spawned < total and timer <= 0.0:
			timer = 8.0
			var n: int = mini(3, total - spawned)
			spawn_wave("grabber", n, 380.0, rand_ang(), 0.5)
			spawned += n
		var alive: int = w.of_kind("grabber").size()
		objective_text = "Destroy the drones (%d left)" % (alive + total - spawned)
		prog = float(total - alive - (total - spawned)) / float(total)
		if spawned >= total and alive == 0:
			finish(true)

	func hint() -> Dictionary:
		var tgts: Array = []
		for g in w.of_kind("grabber"):
			tgts.append(g.id)
		return {"goal": w.ship.pos, "speed": 0.0, "arrive": 40.0, "fire": tgts, "scan": tgts, "combat": true}

# ================================================================ Snatch pods
class SnatchPods extends Encounter:
	var total: int = 3
	var spawned: int = 0
	var timer: float = 5.0

	func _setup() -> void:
		par = 120.0
		total = clampi(2 + w.temper / 2, 2, 5)
		brief = "Snatch pods! They go for the Pudding pen. If one stays latched for 14 seconds, Pudding is gone. Kill all %d." % total
		w.director.intensity = 0.6

	func _tick(dt: float) -> void:
		timer -= dt
		if spawned < total and timer <= 0.0:
			timer = 9.0
			spawn_wave("snatch", 1, 380.0, rand_ang(), PI)
			spawned += 1
		var alive: int = w.of_kind("snatch").size()
		objective_text = "Destroy the snatch pods (%d left)" % (alive + total - spawned)
		prog = float(total - alive - (total - spawned)) / float(total)
		if spawned >= total and alive == 0:
			finish(true)

	func on_event(type: String, _data: Dictionary) -> void:
		if type == "pudding_snatched":
			finish(false, "Pudding was snatched. The Overlord is delighted.")

	func hint() -> Dictionary:
		var tgts: Array = []
		for g in w.of_kind("snatch"):
			tgts.append(g.id)
		return {"goal": w.ship.pos, "speed": 0.0, "arrive": 40.0, "fire": tgts, "scan": tgts, "combat": true}

# ================================================================ Bastion cruiser
class BastionFight extends Encounter:
	var bid: int = -1
	var weak_scanned: bool = false

	func _setup() -> void:
		par = 150.0
		brief = "A Bastion cruiser. Its broadsides take 3 seconds to charge: Sensors watches for the red arc. Torpedo its REAR vent (weak spot) twice, or run for the green ring."
		var b: Dictionary = w.spawn("bastion", Vector2(0.0, -470.0), {"ang": PI / 2.0})
		bid = b.id
		if w.temper >= 4:
			b["tractor"] = true
		place_goal(1000.0, 0.0, 30.0)
		goal = Vector2(700.0, 500.0)
		for e in w.ents:
			if e.kind == "waypoint":
				e.pos = goal
		w.hail("Bastion Captain", "Halt, vessel. This ship has a band. The band will play while we annihilate you.")

	func _tick(_dt: float) -> void:
		var b: Dictionary = w.find(bid)
		if b.is_empty() or b.state == "dead":
			spoils = {"scrap": 70, "fuel": 1, "snacks": 2, "beacons": 0}
			temper_delta = -1
			finish(true)
			return
		objective_text = "Torpedo the rear vent (Bastion hull %d%%) or reach the ring" % int(100.0 * float(b.hp) / float(b.hpmax))
		prog = 1.0 - float(b.hp) / float(b.hpmax)
		if at_goal(30.0):
			finish(true)

	func hint() -> Dictionary:
		var b: Dictionary = w.find(bid)
		var tg: Array = [] if b.is_empty() else [b.id]
		if not b.is_empty() and not b.get("tractor", false):
			# the cowardly route: run for the ring (the bastion's volleys chase you)
			return {"goal": goal, "speed": 44.0, "arrive": 25.0, "fire": [], "scan": tg, "combat": true, "shield_face": true, "profile": "run"}
		return {"goal": w.ship.pos, "speed": 0.0, "arrive": 60.0, "fire": [], "scan": tg, "torp": bid, "combat": true, "weak": true, "shield_face": true, "profile": "bastion"}

# ================================================================ Say cheese
class SayCheese extends Encounter:
	func _setup() -> void:
		par = 60.0
		brief = "PROOF OF LIFE. Hold the ship dead still and keep Pudding calm (mood under 35) for 14 seconds. Say cheese!"
		w.ship.pud["aboard"] = true
		w.ship.pud["mood"] = maxf(float(w.ship.pud["mood"]), 55.0)
		spoils = {"scrap": 10, "fuel": 0, "snacks": 2, "beacons": 0}
		temper_delta = -1
		w.director.intensity = 0.7

	func _tick(dt: float) -> void:
		var s: Ship = w.ship
		var ok: bool = s.speed() < 2.5 and absf(s.angvel) < 0.15 and float(s.pud["mood"]) < 35.0 and not bool(s.pud["loose"])
		if ok:
			prog = minf(1.0, prog + dt / 14.0)
		else:
			prog = maxf(0.0, prog - dt / 4.0)
		objective_text = "Hold still, keep Pudding calm: %d%%" % int(prog * 100.0)
		if prog >= 1.0:
			finish(true)

	func captain_data() -> Dictionary:
		return {"meters": [{"label": "PHOTO", "v": prog * 100.0, "max": 100.0, "color": "pink"}]}

	func hint() -> Dictionary:
		return {"goal": w.ship.pos, "speed": 0.0, "arrive": 1.0, "stop": true, "calm": true}

# ================================================================ Dock with the diner
class DockDiner extends Encounter:
	var did: int = -1
	var hold_t: float = 0.0

	func _setup() -> void:
		par = 120.0
		brief = "Dock with Ma Gristle's diner. The ring rotates! Match its spin: slow to its speed at the glowing dock light and face the diner."
		var d: Dictionary = w.spawn("diner", Vector2(0.0, -600.0), {"ang": w.rng.randf() * TAU})
		did = d.id
		goal = d.pos
		w.director.quiet = true
		w.hail("Ma Gristle", "Hello dearie! Come on in. Mind the spin. Soup's on.")

	func port_pos(d: Dictionary) -> Vector2:
		return d.pos + Vector2(float(d.r) + w.ship.radius + 0.5, 0.0).rotated(d.ang)

	func port_vel(d: Dictionary) -> Vector2:
		var r: Vector2 = port_pos(d) - d.pos
		return d.vel + Vector2(-r.y, r.x) * 0.12

	func _tick(dt: float) -> void:
		var d: Dictionary = w.find(did)
		var s: Ship = w.ship
		var pp: Vector2 = port_pos(d)
		var rel: float = (s.vel - port_vel(d)).length()
		var dist: float = s.pos.distance_to(pp)
		var face: float = absf(K.wrap_pi(s.heading - (d.pos - s.pos).angle()))
		objective_text = "Dock at the dock light (dist %dm, rel speed %.1f)" % [int(dist), rel]
		prog = clampf(1.0 - dist / 600.0, 0.0, 1.0)
		if dist < 14.0 and rel < 4.0 and face < 0.7:
			hold_t += dt
			prog = 0.8 + hold_t / 2.0 * 0.2
			if hold_t >= 2.0:
				dock_request = true
				finish(true)
		else:
			hold_t = maxf(0.0, hold_t - dt)

	func station_data(st: String) -> Dictionary:
		var d: Dictionary = w.find(did)
		if d.is_empty():
			return {}
		return {"dock": {"port": port_pos(d), "pvel": port_vel(d), "center": d.pos}}

	func hint() -> Dictionary:
		var d: Dictionary = w.find(did)
		if d.is_empty():
			return {"goal": w.ship.pos, "speed": 0.0}
		return {"goal": port_pos(d), "speed": 28.0, "arrive": 8.0, "match": port_vel(d), "face": d.pos, "dock": true}

# ================================================================ Finale: run to haven / the deal
class FinaleRun extends Encounter:
	var variant: String = "fin_haven"
	var mag_id: int = -1
	var wave_t: float = 15.0

	func _setup() -> void:
		par = 150.0
		goal = Vector2(0.0, -1500.0)
		if variant == "fin_haven":
			brief = "THE TANTRUM. The Overlord's flagship is in pursuit. Run for Haven, the green ring. Shields on the flagship's side, and DON'T stop."
		else:
			brief = "Meet Velvet's ship at the green ring. The Overlord is not pleased. Neither is Velvet's hairdresser."
		var wp: Dictionary = w.spawn("waypoint", goal, {"r": 40.0, "name": "Haven" if variant == "fin_haven" else "Velvet's Yacht"})
		var m: Dictionary = w.spawn("magnificence", Vector2(300.0, 500.0), {"vel": Vector2(0.0, -16.0), "ang": -PI / 2.0})
		mag_id = m.id
		w.hail("Overlord Malgrim", "WRETCHED VERMIN! Return my... is that him? Is that my little dumpling? Hello Pudding! ... I WILL BURN YOUR STARS.")
		w.director.intensity = 0.9

	func _tick(dt: float) -> void:
		wave_t -= dt
		if wave_t <= 0.0:
			wave_t = 25.0
			spawn_wave("grabber", 2, 400.0, rand_ang(-PI / 2.0, 0.6), 0.4)
		var m: Dictionary = w.find(mag_id)
		if not m.is_empty():
			# the flagship chases but is slowish
			var want: Vector2 = (w.ship.pos - m.pos).normalized() * 34.0
			m.vel = m.vel.move_toward(want, 2.0 * dt)
		objective_text = "Reach %s: %dm to go" % ["Haven" if variant == "fin_haven" else "Velvet's yacht", int(w.ship.pos.distance_to(goal))]
		prog = clampf(1.0 - w.ship.pos.distance_to(goal) / 1500.0, 0.0, 1.0)
		if at_goal(40.0):
			finish(true)

	func hint() -> Dictionary:
		return goal_hint(46.0, {"arrive": 30.0, "combat": true, "shield_face": true, "fire": []})

# ================================================================ Finale: Return to Sender
class FinaleReturn extends Encounter:
	var mag_id: int = -1
	var hold_t: float = 0.0
	var calm_t: float = 0.0

	func _setup() -> void:
		par = 150.0
		brief = "RETURN TO SENDER. Dock at the Magnificence's bay and hand Pudding back personally. He stops shooting when he sees Pudding is okay. Probably."
		var m: Dictionary = w.spawn("magnificence", Vector2(0.0, -900.0), {"ang": w.rng.randf() * TAU})
		mag_id = m.id
		m["spin"] = 0.05
		goal = m.pos
		w.hail("Overlord Malgrim", "Is that... PUDDING? Bring him HERE. Slowly. Mind the paint. I will deal with you AFTER.")
		w.director.intensity = 0.6

	func port_pos(m: Dictionary) -> Vector2:
		return m.pos + Vector2(float(m.r) + w.ship.radius + 0.5, 0.0).rotated(m.ang)

	func port_vel(m: Dictionary) -> Vector2:
		var r: Vector2 = port_pos(m) - m.pos
		return m.vel + Vector2(-r.y, r.x) * 0.05

	func _tick(dt: float) -> void:
		var m: Dictionary = w.find(mag_id)
		m.ang += 0.05 * dt
		m.vel = Vector2.ZERO
		var s: Ship = w.ship
		var pp: Vector2 = port_pos(m)
		var dist: float = s.pos.distance_to(pp)
		if dist < 360.0:
			m.fire_t = 99.0  # he sees Pudding and stops shooting
		var rel: float = (s.vel - port_vel(m)).length()
		var face: float = absf(K.wrap_pi(s.heading - (m.pos - s.pos).angle()))
		objective_text = "Dock at the Magnificence's bay: %dm, rel speed %.1f" % [int(dist), rel]
		prog = clampf(1.0 - dist / 900.0, 0.0, 1.0)
		if dist < 16.0 and rel < 4.0 and face < 0.7:
			hold_t += dt
			if hold_t >= 2.5:
				finish(true)
		else:
			hold_t = maxf(0.0, hold_t - dt)

	func station_data(_st: String) -> Dictionary:
		var m: Dictionary = w.find(mag_id)
		if m.is_empty():
			return {}
		return {"dock": {"port": port_pos(m), "pvel": port_vel(m), "center": m.pos}}

	func hint() -> Dictionary:
		var m: Dictionary = w.find(mag_id)
		return {"goal": port_pos(m), "speed": 34.0, "arrive": 8.0, "match": port_vel(m), "face": m.pos, "dock": true}
