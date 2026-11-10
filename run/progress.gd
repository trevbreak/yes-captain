class_name Progress
extends RefCounted
## A crew's career: which missions are unlocked, their best stars, and what the Shift has earned them.
## Every room on a server has its own. The player who hosts a room brings theirs along (it lives in their
## browser or on their disk, at user://progress.cfg) and gets it back when it changes.

const PATH: String = "user://progress.cfg"
static var persist: bool = true
static var _local: Progress = null

var unlocked_n: int = 1
var star_map: Dictionary = {}
var shifts: int = 0             # finished shifts: each one adds a card to the deck
var best_pay: int = 0
var stickers: Dictionary = {}   # award title -> times earned
var is_local: bool = false

static func local() -> Progress:
	## this player's own career
	if _local == null:
		_local = Progress.new()
		_local.is_local = true
		if persist:
			var c: ConfigFile = ConfigFile.new()
			if c.load(PATH) == OK:
				_local.apply_dict({"unlocked": c.get_value("career", "unlocked", 1), "stars": c.get_value("career", "stars", {}),
					"shifts": c.get_value("career", "shifts", 0), "best_pay": c.get_value("career", "best_pay", 0),
					"stickers": c.get_value("career", "stickers", {})})
	return _local

static func forget_local() -> void:
	_local = null

func to_dict() -> Dictionary:
	return {"unlocked": unlocked_n, "stars": star_map.duplicate(), "shifts": shifts, "best_pay": best_pay, "stickers": stickers.duplicate()}

func apply_dict(d: Variant) -> void:
	## careful: this arrives from players, so nothing in it is trusted
	if not (d is Dictionary):
		return
	unlocked_n = clampi(_num(d.get("unlocked", 1)), 1, Missions.ORDER.size())
	star_map = {}
	var st: Variant = d.get("stars", {})
	if st is Dictionary:
		for id in Missions.ORDER:
			if st.has(id):
				star_map[id] = clampi(_num(st[id]), 0, 3)
	shifts = clampi(_num(d.get("shifts", 0)), 0, 9999)
	best_pay = clampi(_num(d.get("best_pay", 0)), 0, 999999)
	stickers = {}
	var sk: Variant = d.get("stickers", {})
	if sk is Dictionary:
		for k in sk.keys():
			if stickers.size() < 64 and k is String and (k as String).length() <= 40:
				stickers[k] = clampi(_num(sk[k]), 0, 9999)

static func _num(v: Variant) -> int:
	return int(v) if (v is int or v is float) else 0

func save() -> void:
	if not is_local or not persist:
		return
	var c: ConfigFile = ConfigFile.new()
	c.set_value("career", "unlocked", unlocked_n)
	c.set_value("career", "stars", star_map)
	c.set_value("career", "shifts", shifts)
	c.set_value("career", "best_pay", best_pay)
	c.set_value("career", "stickers", stickers)
	c.save(PATH)

func unlocked() -> int:
	## how many missions are playable (1 = just the first)
	return clampi(unlocked_n, 1, Missions.ORDER.size())

func is_unlocked(id: String) -> bool:
	return Missions.ORDER.find(id) < unlocked()

func career_done() -> bool:
	return stars(Missions.ORDER[Missions.ORDER.size() - 1]) > 0

func stars(id: String) -> int:
	return int(star_map.get(id, 0))

func record(id: String, got: int) -> bool:
	## returns true if this unlocked a new mission
	if got > stars(id):
		star_map[id] = got
	var idx: int = Missions.ORDER.find(id)
	var opened: bool = false
	if got > 0 and idx >= 0 and idx + 2 > unlocked_n:
		unlocked_n = mini(idx + 2, Missions.ORDER.size())
		opened = true
	save()
	return opened

func add_stickers(titles: Array) -> void:
	for t in titles:
		stickers[str(t)] = int(stickers.get(str(t), 0)) + 1
	save()

func unlock_all() -> void:
	unlocked_n = Missions.ORDER.size()
	save()

func reset() -> void:
	unlocked_n = 1
	star_map = {}
	shifts = 0
	best_pay = 0
	stickers = {}
	save()
