class_name Progress
extends RefCounted
## Which missions the crew has unlocked, and their best stars. Saved to user://progress.cfg.

const PATH: String = "user://progress.cfg"
static var persist: bool = true
static var _unlocked: int = -1
static var _stars: Dictionary = {}

static func _load() -> void:
	if _unlocked >= 0:
		return
	_unlocked = 1
	_stars = {}
	if not persist:
		return
	var c: ConfigFile = ConfigFile.new()
	if c.load(PATH) == OK:
		_unlocked = int(c.get_value("career", "unlocked", 1))
		_stars = c.get_value("career", "stars", {})

static func _save() -> void:
	if not persist:
		return
	var c: ConfigFile = ConfigFile.new()
	c.set_value("career", "unlocked", _unlocked)
	c.set_value("career", "stars", _stars)
	c.save(PATH)

static func unlocked() -> int:
	## how many missions are playable (1 = just the first)
	_load()
	return clampi(_unlocked, 1, Missions.ORDER.size())

static func is_unlocked(id: String) -> bool:
	return Missions.ORDER.find(id) < unlocked()

static func stars(id: String) -> int:
	_load()
	return int(_stars.get(id, 0))

static func record(id: String, got: int) -> bool:
	## returns true if this unlocked a new mission
	_load()
	if got > stars(id):
		_stars[id] = got
	var idx: int = Missions.ORDER.find(id)
	var opened: bool = false
	if got > 0 and idx + 2 > _unlocked:
		_unlocked = mini(idx + 2, Missions.ORDER.size())
		opened = true
	_save()
	return opened

static func unlock_all() -> void:
	_load()
	_unlocked = Missions.ORDER.size()
	_save()

static func reset() -> void:
	_unlocked = 1
	_stars = {}
	_save()
