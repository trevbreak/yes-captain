class_name Ship
extends RefCounted
## Our ship: arcade flight, a handful of systems that break and get fixed, and the optional mechanics
## (heat, power, Pudding, boost, roll) that missions switch on one at a time.

const SYSTEMS: Array = ["bridge", "engine_p", "engine_s", "gun", "shield", "sensors", "tractor", "reactor", "pen"]
const SYS_NAME: Dictionary = {
	"bridge": "Steering", "engine_p": "Port engine", "engine_s": "Starboard engine", "gun": "Gun", "shield": "Shield",
	"sensors": "Sensors", "tractor": "Tractor beam", "reactor": "Reactor", "pen": "Pudding pen",
}
## which station suffers when a system breaks
const SYS_OWNER: Dictionary = {
	"bridge": "helm", "engine_p": "engines", "engine_s": "engines", "gun": "weapons", "shield": "shields",
	"sensors": "sensors", "tractor": "shields", "reactor": "engineer", "pen": "shields",
}
## where each system sits (ship-relative angle, 0 = nose), so hits from a side damage what's on that side
const SYS_SIDE: Dictionary = {
	"bridge": 0.0, "sensors": 0.0, "gun": -0.9, "shield": 0.9, "pen": -1.9, "tractor": 1.9, "reactor": PI,
	"engine_p": -2.6, "engine_s": 2.6,
}
const NEIGHBOURS: Dictionary = {
	"bridge": ["sensors", "gun", "shield"], "sensors": ["bridge", "gun", "shield", "reactor"], "gun": ["bridge", "sensors", "pen"],
	"shield": ["bridge", "sensors", "tractor"], "pen": ["gun", "reactor", "engine_p"], "tractor": ["shield", "reactor", "engine_s"],
	"reactor": ["pen", "tractor", "sensors", "engine_p", "engine_s"], "engine_p": ["pen", "reactor"], "engine_s": ["tractor", "reactor"],
}

const MAX_SPEED: float = 70.0
const TURN_RATE: float = 1.5
const SHIELD_HALF_ARC: float = deg_to_rad(65.0)
const REPAIR_TIME: float = 3.5
const FIRE_TIME: float = 2.5

var pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var heading: float = -PI / 2.0
var angvel: float = 0.0
var hull: float = 100.0
var hull_max: float = 100.0

# controls (all sticky: they stay where the player leaves them)
var wheel: float = 0.0
var throttle: float = 0.0
var aim: float = 0.0            # turret angle relative to the nose
var firing: bool = false
var shield_dir: float = 0.0     # shield centre relative to the nose
var boost: bool = false
var roll_t: float = 0.0         # > 0 while barrel-rolling (shots miss)
var roll_cd: float = 0.0

# systems
var sys: Dictionary = {}        # id -> {hp, state: ok|broken|fire, fire_t}
var engine_heat: float = 0.0
var gun_heat: float = 0.0
var gun_cd: float = 0.0
var torp: String = "empty"      # empty | loading | ready
var torp_load: float = 0.0

# engineer
var repair_target: String = ""
var repairing: bool = false
var repair_prog: float = 0.0

# power (mission 8+): bars per group, 0..3, the reactor supplies POWER_CAP
const POWER_CAP: float = 6.0
var power: Dictionary = {"engines": 2, "weapons": 2, "shields": 2}
var draw: float = 0.0
var overload: float = 0.0       # 0..100: blackout at 100
var blackout_t: float = 0.0

# pudding (mission 4+)
var pud_mood: float = 85.0
var pud_out: bool = false
var pud_room: String = "pen"
var pud_chew_t: float = 8.0
var pud_hop_t: float = 4.0
var snacks: int = 5
var petting: bool = false
var tin: bool = false
var tin_prog: float = 0.0

# tractor (mission 2+)
var tractor_on: bool = false
var tractor_target: int = -1

func _init() -> void:
	for s in SYSTEMS:
		sys[s] = {"hp": 100.0, "state": "ok", "fire_t": 0.0}

func reset_for_mission() -> void:
	pos = Vector2.ZERO
	vel = Vector2.ZERO
	heading = -PI / 2.0
	angvel = 0.0
	hull = hull_max
	wheel = 0.0
	throttle = 0.0
	aim = 0.0
	firing = false
	shield_dir = 0.0
	boost = false
	roll_t = 0.0
	roll_cd = 0.0
	engine_heat = 0.0
	gun_heat = 0.0
	torp = "empty"
	torp_load = 0.0
	repair_target = ""
	repairing = false
	repair_prog = 0.0
	power = {"engines": 2, "weapons": 2, "shields": 2}
	overload = 0.0
	blackout_t = 0.0
	pud_mood = 85.0
	pud_out = false
	pud_room = "pen"
	snacks = 5
	petting = false
	tin = false
	tractor_on = false
	tractor_target = -1
	for s in SYSTEMS:
		sys[s] = {"hp": 100.0, "state": "ok", "fire_t": 0.0}

# ---------------------------------------------------------------- queries

func fwd() -> Vector2:
	return Vector2.from_angle(heading)

func speed() -> float:
	return vel.length()

func ok(s: String) -> bool:
	return str(sys[s].state) == "ok" and blackout_t <= 0.0

func broken(s: String) -> bool:
	return str(sys[s].state) != "ok"

func on_fire(s: String) -> bool:
	return str(sys[s].state) == "fire"

func engines_working() -> int:
	return int(ok("engine_p")) + int(ok("engine_s"))

func turret_world() -> float:
	return heading + aim

func power_factor(group: String, features: Dictionary) -> float:
	## how hard a group can work: 1.0 normally; scales with power bars once the power mechanic is on
	if not features.get("power", false):
		return 1.0
	var bars: int = int(power.get(group, 2))
	var f: float = [0.0, 0.55, 1.0, 1.3][clampi(bars, 0, 3)]
	if not ok("reactor"):
		f *= 0.5
	return f

func shield_covers(world_dir: float) -> bool:
	## does the shield cover a hit arriving FROM world direction world_dir?
	if not ok("shield"):
		return false
	var rel: float = K.wrap_pi(world_dir - heading)
	return absf(K.wrap_pi(rel - shield_dir)) <= SHIELD_HALF_ARC

func side_system(rel: float) -> String:
	## the system closest to a hit from relative angle rel
	var best: String = "bridge"
	var bd: float = 99.0
	for s in SYS_SIDE.keys():
		var d: float = absf(K.wrap_pi(rel - float(SYS_SIDE[s])))
		if d < bd:
			bd = d
			best = s
	return best

func any_problem() -> bool:
	for s in SYSTEMS:
		if broken(s):
			return true
	return false
