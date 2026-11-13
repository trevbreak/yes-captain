class_name Deck
extends RefCounted
## What a crew's Shifts are dealt from. Every mechanic and every kind of job is in from the start; every finished shift adds
## ONE new card (a glitch, a place or a twist), introduced by IGOR at the next briefing. A crew twenty shifts in
## plays a much wilder game than a new one, and nobody was ever handed more than one new thing at a time.

const SHIFT_UNLOCKS_AT: int = 3     # the Shift opens once this many missions are unlocked (two flown)
const BASE_CARDS: int = 5
const JOBS_PER_SHIFT: int = 3

## the order cards arrive in. kind: glitch | place | twist. needs: mechanics the career must have taught first.
const ORDER: Array = [
	{"kind": "glitch", "id": "backwards_wheel"},
	{"kind": "place", "id": "rocks"},
	{"kind": "glitch", "id": "sticky_throttle"},
	{"kind": "twist", "id": "rush"},
	{"kind": "glitch", "id": "gun_pull"},
	# ---- everything below arrives one shift at a time
	{"kind": "glitch", "id": "drunk_compass"},
	{"kind": "twist", "id": "dented"},
	{"kind": "glitch", "id": "shield_slip"},
	{"kind": "place", "id": "shower"},
	{"kind": "glitch", "id": "upside_chart"},
	{"kind": "twist", "id": "one_engine"},
	{"kind": "glitch", "id": "mirror_scope"},
	{"kind": "place", "id": "mines"},
	{"kind": "glitch", "id": "flipped_throttle"},
	{"kind": "twist", "id": "fragile"},
	{"kind": "glitch", "id": "radar_ghosts"},
	{"kind": "glitch", "id": "igor_reboot"},
	{"kind": "place", "id": "fog"},
	{"kind": "twist", "id": "glitchy"},
	{"kind": "glitch", "id": "engine_hiccup"},
	{"kind": "twist", "id": "grumpy", "needs": ["pudding"]},
	{"kind": "glitch", "id": "wheel_drift"},
	{"kind": "glitch", "id": "dead_gauge", "needs": ["heat"]},
	{"kind": "twist", "id": "blind"},
	{"kind": "glitch", "id": "pudding_sat", "needs": ["pudding"]},
	{"kind": "place", "id": "junkyard", "needs": ["tractor"]},
	{"kind": "twist", "id": "weak_reactor", "needs": ["power"]},
	{"kind": "twist", "id": "thrupp", "needs": ["roll"]},
]

const PLACES: Dictionary = {
	"open": {"name": "Open lanes", "text": "Nothing in the way. IGOR is suspicious.", "danger": 0},
	"rocks": {"name": "The Rock Belt", "text": "Rocks. They do not move. You do. Go round.", "danger": 1},
	"shower": {"name": "Meteor Alley", "text": "Meteors arrive without warning. The captain sees them coming. Shields does not.", "danger": 1},
	"mines": {"name": "The Minefield", "text": "Old mines. They look like every other ? until Sensors scans them.", "danger": 2},
	"fog": {"name": "The Soup", "text": "Space fog. The radar only reaches half as far. The captain's chart has the same problem.", "danger": 1},
	"junkyard": {"name": "The Junkyard", "text": "Cargo pods float about. Each one hauled in is a bonus. Each one is also a detour.", "danger": 0},
}

const TWISTS: Dictionary = {
	"rush": {"name": "Rush order", "text": "The clock is a third shorter. The pay is better.", "pay": 0.25},
	"dented": {"name": "Second-hand ship", "text": "The last crew left dents. Hull starts at 65%.", "pay": 0.2},
	"one_engine": {"name": "Starboard engine is in bits", "text": "It starts broken. The ship pulls right until the Engineer mends it.", "pay": 0.15},
	"fragile": {"name": "Fragile cargo", "text": "Every bump and every hit comes out of the pay.", "pay": 0.3},
	"glitchy": {"name": "Friday-afternoon ship", "text": "Glitches arrive twice as often.", "pay": 0.3},
	"grumpy": {"name": "Pudding is in a mood", "text": "Pudding starts unhappy and gets unhappier. Somebody keep petting.", "pay": 0.2},
	"blind": {"name": "Sensor dish fell off", "text": "Sensors start broken. The chart is all question marks until it's mended.", "pay": 0.15},
	"weak_reactor": {"name": "Reactor is wheezing", "text": "Only 5 bars of power instead of 6.", "pay": 0.25},
	"thrupp": {"name": "Thrupp is watching", "text": "A Hegemony patrol follows you the whole way. It can't be shot.", "pay": 0.4},
}

## IGOR found a part: bodged upgrades offered between jobs. Each has a catch.
const PARTS: Array = [
	{"id": "big_engine", "name": "Bigger Engine", "good": "25% faster", "bad": "engines heat up half as fast again", "mods": {"speed": 1.25, "heat": 1.5}},
	{"id": "wide_shield", "name": "Extra-Wide Shield", "good": "shield covers 40% more", "bad": "gun fires a fifth slower", "mods": {"shield_arc": 1.4, "gun_rate": 0.8}},
	{"id": "hair_trigger", "name": "Hair Trigger", "good": "gun fires 40% faster", "bad": "gun heats up much faster", "mods": {"gun_rate": 1.4, "gun_heat": 1.6}},
	{"id": "long_tractor", "name": "Long-Reach Tractor", "good": "tractor reaches 60% further", "bad": "ship is a tenth slower", "mods": {"tractor": 1.6, "speed": 0.9}},
	{"id": "duct_tape", "name": "Duct Tape Deluxe", "good": "repairs are half as quick again", "bad": "hull loses 15 points", "mods": {"repair": 1.5, "hull": -15.0}},
	{"id": "plating", "name": "Cast-Iron Plating", "good": "25 extra hull", "bad": "ship is a tenth slower", "mods": {"hull": 25.0, "speed": 0.9}},
	{"id": "sharp_dish", "name": "Sharpened Dish", "good": "scans take half the time", "bad": "repairs are a fifth slower", "mods": {"scan": 2.0, "repair": 0.8}},
	{"id": "fast_torps", "name": "Spring-Loaded Torpedoes", "good": "torpedoes load twice as fast", "bad": "gun heats up faster", "mods": {"torp_load": 2.0, "gun_heat": 1.3}, "needs": ["torpedo"]},
]

static func features_for(_career: Progress) -> Dictionary:
	## a crew on the Shift is assumed to have done basic training: every mechanic, every kind of job.
	## (Training is where the mechanics are taught one at a time; the Shift doesn't hold any of them back.)
	return Missions.features_upto(Missions.ORDER.size())

static func shift_open(career: Progress) -> bool:
	return career.unlocked() >= SHIFT_UNLOCKS_AT

static func _eligible(card: Dictionary, feats: Dictionary) -> bool:
	for n in card.get("needs", []):
		if not bool(feats.get(n, false)):
			return false
	if str(card.kind) == "glitch":
		for n2 in Glitches.DEFS[card.id].get("needs", []):
			if not bool(feats.get(n2, false)):
				return false
	return true

static func cards(career: Progress, upto_shifts: int = -1) -> Array:
	## the cards this crew holds: the base hand plus one per finished shift
	var feats: Dictionary = features_for(career)
	var n: int = BASE_CARDS + (career.shifts if upto_shifts < 0 else upto_shifts)
	var out: Array = []
	for c in ORDER:
		if out.size() >= n:
			break
		if _eligible(c, feats):
			out.append(c)
	return out

static func ids(career: Progress, kind: String) -> Array:
	var out: Array = []
	for c in cards(career):
		if str(c.kind) == kind:
			out.append(str(c.id))
	return out

static func newest(career: Progress) -> Dictionary:
	## the card the last finished shift earned ({} on the first shift, or when the deck is complete)
	if career.shifts <= 0:
		return {}
	var now: Array = cards(career)
	var before: Array = cards(career, career.shifts - 1)
	return now[now.size() - 1] if now.size() > before.size() else {}

static func describe(card: Dictionary) -> Dictionary:
	## {title, text, kind} for a briefing
	match str(card.get("kind", "")):
		"glitch":
			var d: Dictionary = Glitches.DEFS[card.id]
			return {"kind": "A NEW GLITCH", "title": str(d.name), "who": [str(d.station)],
				"text": "The ship has learned a new way to go wrong: %s. It will turn up when it likes. The Engineer's manual says how to fix it." % str(d.name).to_lower()}
		"place":
			var p: Dictionary = PLACES[card.id]
			return {"kind": "A NEW PLACE", "title": str(p.name), "who": [], "text": str(p.text)}
		"twist":
			var t: Dictionary = TWISTS[card.id]
			return {"kind": "A NEW SNAG", "title": str(t.name), "who": [], "text": str(t.text) + " Jobs with this snag pay more."}
	return {}

static func rent(career: Progress) -> int:
	## what the depot wants from a shift. It creeps up as the crew gets better at this.
	return 330 + mini(career.shifts, 20) * 12

static func part_offers(rng: RandomNumberGenerator, feats: Dictionary, have: Array) -> Array:
	var pool: Array = []
	for p in PARTS:
		var ok: bool = not (str(p.id) in have)
		for n in p.get("needs", []):
			if not bool(feats.get(n, false)):
				ok = false
		if str(p.id) == "big_engine" and not bool(feats.get("heat", false)):
			ok = false
		if str(p.id) == "hair_trigger" and not bool(feats.get("heat", false)):
			ok = false
		if str(p.id) == "long_tractor" and not bool(feats.get("tractor", false)):
			ok = false
		if ok:
			pool.append(p)
	var out: Array = []
	while out.size() < 2 and not pool.is_empty():
		var i: int = rng.randi() % pool.size()
		out.append(pool[i])
		pool.remove_at(i)
	return out

static func part(id: String) -> Dictionary:
	for p in PARTS:
		if str(p.id) == id:
			return p
	return {}
