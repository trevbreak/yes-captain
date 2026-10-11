class_name RunState
extends RefCounted
## One attempt to get Pudding to safety: a layered sector map, resources, and the Overlord's Temper.

const RANKS: Array = ["Grand Admiral", "Admiral", "Commodore", "Captain", "Lieutenant", "Ensign", "Cadet", "Deck Swabber"]
const TEMPER_NAMES: Array = ["", "Peeved", "Cross", "Furious", "Livid", "TANTRUM"]

const ITEMS: Array = [
	{"id": "hull", "station": "ops", "name": "Hull Patch Kit", "desc": "+30 hull integrity", "cost": 30},
	{"id": "turbo", "station": "engines", "name": "Turbo Injectors", "desc": "+10% engine thrust", "cost": 35},
	{"id": "torp", "station": "weapons", "name": "Bigger Warhead", "desc": "Torpedoes hit harder", "cost": 35},
	{"id": "cooler", "station": "power", "name": "Industrial Cooler", "desc": "Reactor cools faster", "cost": 30},
	{"id": "antenna", "station": "sensors", "name": "Fancy Antenna", "desc": "+20% sensor range", "cost": 25},
	{"id": "rcs", "station": "helm", "name": "Sporty Thrusters", "desc": "+15% turning power", "cost": 30},
	{"id": "pen", "station": "ops", "name": "Plush Pudding Pen", "desc": "Pudding stresses less", "cost": 25},
	{"id": "snacks", "station": "ops", "name": "Pudding Snacks x5", "desc": "Blue pellets. He likes the blue ones.", "cost": 10},
	{"id": "beacon", "station": "sensors", "name": "Decoy Beacons x2", "desc": "Fake Pudding sightings lower the Overlord's Temper", "cost": 15},
	{"id": "fuel", "station": "engines", "name": "Fuel x2", "desc": "Jumps cost fuel", "cost": 10},
]

static var persist: bool = true
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var nodes: Array = []
var cur: int = 0
var temper_pts: float = 0.0
var scrap: int = 40
var fuel: int = 6
var upgrades: Dictionary = {}
var mood_sum: float = 0.0
var mood_n: int = 0
var jumps: int = 0
var finished: bool = false
var ending: String = ""
var length: String = "full"
var thrupp_idx: int = 1
var encounters_done: int = 0
var visited: Array = []

func _init(seed_value: int = 0, run_length: String = "full") -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	length = run_length
	make_map()

func temper_level() -> int:
	return clampi(1 + int(temper_pts / 2.0), 1, 5)

func temper_name() -> String:
	return TEMPER_NAMES[temper_level()]

func rank_title() -> String:
	return RANKS[clampi(thrupp_idx, 0, RANKS.size() - 1)]

func add_temper(x: float) -> bool:
	## returns true if the level changed
	var before: int = temper_level()
	temper_pts = maxf(0.0, temper_pts + x)
	return temper_level() != before

func calm_score() -> float:
	if mood_n == 0:
		return 0.0
	return mood_sum / float(mood_n)

func _node(col: int, row: int, kind: String) -> Dictionary:
	var info: Dictionary = Encounters.INFO.get(kind, {})
	var n: Dictionary = {"id": nodes.size(), "col": col, "row": row, "kind": kind,
		"name": str(info.get("name", kind)), "next": [], "threat": int(info.get("threat", 1)),
		"code": "%03d-%02d" % [rng.randi_range(100, 999), rng.randi_range(10, 99)], "pit": kind == "dock"}
	nodes.append(n)
	return n

func make_map() -> void:
	nodes.clear()
	var cols: Array = []
	cols.append([_node(0, 0, "binday")])
	var mid_cols: int = 8 if length == "full" else 3
	var pit_cols: Array = [3, 6] if length == "full" else [2]
	for c in range(1, mid_cols + 1):
		var count: int = 2 if c == 1 else (3 if c % 2 == 0 else 2)
		var col: Array = []
		var used: Array = []
		for r in count:
			var kind: String = ""
			if c in pit_cols and r == 0:
				kind = "dock"
			else:
				kind = _pick_kind(c, mid_cols, used)
				used.append(kind)
			col.append(_node(c, r, kind))
		cols.append(col)
	var fin: Array = [_node(mid_cols + 1, 0, "fin_haven"), _node(mid_cols + 1, 1, "fin_return"), _node(mid_cols + 1, 2, "fin_sell")]
	cols.append(fin)
	for ci in range(cols.size() - 1):
		var a: Array = cols[ci]
		var b: Array = cols[ci + 1]
		for i in a.size():
			var n1: int = clampi(int(round(float(i) * float(b.size() - 1) / maxf(1.0, float(a.size() - 1)))), 0, b.size() - 1)
			var n2: int = clampi(n1 + (1 if n1 + 1 < b.size() else -1), 0, b.size() - 1)
			if ci + 1 == cols.size() - 1:
				a[i].next = [b[0].id, b[1].id, b[2].id]
			else:
				a[i].next = [b[n1].id] if n1 == n2 else [b[n1].id, b[n2].id]
		# ensure every node in b is reachable
		for j in b.size():
			var reach: bool = false
			for n in a:
				if b[j].id in n.next:
					reach = true
			if not reach:
				a[a.size() - 1 if j >= a.size() else j].next.append(b[j].id)
	cur = 0

func _pick_kind(col: int, last_col: int, used: Array) -> String:
	var pool: Array
	if col <= 2:
		pool = ["casual", "cake", "ducks", "checkpoint", "photo", "mines", "casual", "cake"]
	elif col <= 5:
		pool = ["drones", "mines", "checkpoint", "bees", "cake", "pods", "casual", "ducks", "photo"]
	else:
		pool = ["pods", "bastion", "drones", "mines", "bees", "bastion", "checkpoint", "drones"]
	var tries: int = 0
	var k: String = pool[rng.randi() % pool.size()]
	while k in used and tries < 20:
		k = pool[rng.randi() % pool.size()]
		tries += 1
	return k

func options() -> Array:
	var out: Array = []
	for nid in nodes[cur].next:
		out.append(nodes[nid])
	return out

func node_by_code(code: String) -> Dictionary:
	var c: String = code.strip_edges().replace(" ", "")
	for n in options():
		if str(n.code) == c or str(n.code).replace("-", "") == c.replace("-", ""):
			return n
	return {}

func apply_item(id: String, ship: Ship, world: World) -> void:
	upgrades[id] = int(upgrades.get(id, 0)) + 1
	match id:
		"hull":
			ship.hull = minf(ship.hull_max, ship.hull + 30.0)
		"turbo":
			ship.thrust_bonus *= 1.1
		"torp":
			world.torp_bonus *= 1.35
		"cooler":
			ship.cooler_bonus *= 1.3
		"antenna":
			world.sensor_bonus *= 1.2
		"rcs":
			ship.rcs_bonus *= 1.15
		"pen":
			ship.pen_bonus *= 0.7
		"snacks":
			ship.snacks += 5
		"beacon":
			ship.beacons += 2
		"fuel":
			fuel += 2

static func load_rank() -> int:
	if not persist:
		return 1
	var cf: ConfigFile = ConfigFile.new()
	if cf.load("user://yes_captain.cfg") == OK:
		return int(cf.get_value("thrupp", "rank", 1))
	return 1

static func save_rank(idx: int, defected: bool) -> void:
	if not persist:
		return
	var cf: ConfigFile = ConfigFile.new()
	cf.load("user://yes_captain.cfg")
	cf.set_value("thrupp", "rank", clampi(idx, 0, RANKS.size() - 1))
	if defected:
		cf.set_value("thrupp", "defected", true)
	cf.save("user://yes_captain.cfg")

static func load_defected() -> bool:
	if not persist:
		return false
	var cf: ConfigFile = ConfigFile.new()
	if cf.load("user://yes_captain.cfg") == OK:
		return bool(cf.get_value("thrupp", "defected", false))
	return false
