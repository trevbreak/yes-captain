class_name K
extends RefCounted
## Shared constants, palette and small helpers.

const SEATS: Array = ["captain", "helm", "engines", "power", "weapons", "sensors", "ops"]
const STATIONS: Array = ["helm", "engines", "power", "weapons", "sensors", "ops"]
const SYSTEMS: Array = ["engines", "rcs", "weapons", "shields", "sensors", "ops"]
const CONDUITS: Array = ["C_PORT", "C_STAR", "C_CORE", "C_UTIL"]
const DT: float = 1.0 / 30.0
const SNAP_HZ: float = 15.0
const PORT_DEFAULT: int = 7777

const SEAT_INFO: Dictionary = {
	"captain": {"name": "Captain", "color": "plum2", "blurb": "Sees out the window. Touches nothing. Talks a LOT."},
	"helm": {"name": "Helm", "color": "teal", "blurb": "Points the ship. Fights drift. Has the Emergency Roll."},
	"engines": {"name": "Engines", "color": "tangerine", "blurb": "Speed, heat and fuel mixture. Dampers OFF is a lifestyle."},
	"power": {"name": "Power", "color": "butter", "blurb": "Splits the pips. Cools the reactor. Overclock is a bad idea."},
	"weapons": {"name": "Weapons", "color": "coral", "blurb": "Turret arcs and hand-loaded torpedoes. Torpedoes can't read."},
	"sensors": {"name": "Sensors", "color": "mint", "blurb": "The only map. Scans, comms, and where the captain looks."},
	"ops": {"name": "Ops", "color": "lilac", "blurb": "Shields, tractor beam, cargo, and keeping Pudding calm."},
	"dc": {"name": "Damage Control", "color": "mustard", "blurb": "Anyone can come fix things. Your own post will not wait."},
}

static var _pal: Dictionary = {}

static func pal(n: String) -> Color:
	if _pal.is_empty():
		_pal = {
			"plum": Color.html("#2B2350"), "plum2": Color.html("#4A3F86"), "lilac": Color.html("#9A8FD6"),
			"tangerine": Color.html("#F28C38"), "mint": Color.html("#6CD4B0"), "butter": Color.html("#F6D365"),
			"teal": Color.html("#3FB6C8"), "mustard": Color.html("#E8B23A"), "coral": Color.html("#F2545B"),
			"gunmetal": Color.html("#4A4E5A"), "gunmetal2": Color.html("#6B7080"), "gold": Color.html("#CFA13A"),
			"magenta": Color.html("#C2367A"), "cream": Color.html("#FFF6E5"), "cream2": Color.html("#F1E2C2"),
			"ink": Color.html("#2E2A3A"), "white": Color.html("#FFFFFF"), "green": Color.html("#5CC96B"),
			"rock": Color.html("#8C7B72"), "pink": Color.html("#FF9FC2"), "sky": Color.html("#8FD3F4"),
		}
	return _pal.get(n, Color.MAGENTA)

static func wrap_pi(a: float) -> float:
	return wrapf(a, -PI, PI)

static func fmt_time(t: float) -> String:
	var s: int = int(t)
	return "%d:%02d" % [s / 60, s % 60]

static func seat_name(s: String) -> String:
	return str(SEAT_INFO.get(s, {}).get("name", s))
