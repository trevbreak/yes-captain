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
	"captain": {"name": "Captain", "color": "navy", "icon": "captain", "portrait": "captain",
		"persona": "Captain Mo Pennywhistle", "trait": "Has never once touched a button. Very proud of this.",
		"blurb": "Sees out the window. Touches nothing. Talks a LOT.",
		"job": "You are the only one who can see outside, read the objectives and hear the enemy. Tell everyone what to do.", "difficulty": 2},
	"helm": {"name": "Helm", "color": "helm", "icon": "helm", "portrait": "helm",
		"persona": "Dex Wheelwright", "trait": "Turns left to go right. Usually.",
		"blurb": "Points the ship. Fights drift. Has the Emergency Roll.",
		"job": "Turn the ship and strafe sideways. You only see a compass, so listen to the captain.", "difficulty": 2},
	"engines": {"name": "Engines", "color": "engines", "icon": "engines", "portrait": "engines",
		"persona": "Big Sal Throttleby", "trait": "Talks to the engines. They talk back.",
		"blurb": "Speed, heat and fuel mixture. Dampers OFF is a lifestyle.",
		"job": "Two throttles, one temper. Keep the fuel mixture in the green and the engines from cooking.", "difficulty": 2},
	"power": {"name": "Power", "color": "power", "icon": "power", "portrait": "power",
		"persona": "Pip Voltaire", "trait": "Has been mildly electrocuted 41 times.",
		"blurb": "Splits the pips. Cools the reactor. Overclock is a bad idea.",
		"job": "Share out the power, pump coolant, reset breakers and charge the jump drive. Everyone will want more.", "difficulty": 3},
	"weapons": {"name": "Weapons", "color": "weapons", "icon": "weapons", "portrait": "weapons",
		"persona": "Rhoda 'Boom' Blastworth", "trait": "Aims first. Asks never.",
		"blurb": "Turret arcs and hand-loaded torpedoes. Torpedoes can't read.",
		"job": "Load, aim and fire two turrets through a tiny scope. Torpedoes for the big stuff.", "difficulty": 2},
	"sensors": {"name": "Sensors", "color": "sensors", "icon": "sensors", "portrait": "sensors",
		"persona": "Ozzy Squint", "trait": "Can hear a mine blink.",
		"blurb": "The only map. Scans, comms, and where the captain looks.",
		"job": "You have the only radar. Scan contacts, tune in hails and point the captain's viewscreen.", "difficulty": 2},
	"ops": {"name": "Ops", "color": "ops", "icon": "ops", "portrait": "ops",
		"persona": "Nana Fluffington", "trait": "Carries snacks for every occasion.",
		"blurb": "Shields, tractor beam, cargo, and keeping Pudding calm.",
		"job": "Point the shields, run the tractor beam, mind the cargo and keep Pudding calm.", "difficulty": 1},
	"dc": {"name": "Damage Control", "color": "dc", "icon": "dc", "portrait": "dc",
		"persona": "Gus Spanner", "trait": "Has fixed everything once. Some things twice.",
		"blurb": "Anyone can come fix things. Your own post will not wait.",
		"job": "Fix fires, breaches, broken modules and cut cables. Anyone can come here.", "difficulty": 1},
}

static var _pal: Dictionary = {}

static func pal(n: String) -> Color:
	if _pal.is_empty():
		_pal = {
			# design system v2
			"card": Color.html("#FFFAF0"), "well": Color.html("#EFE8D9"), "ink": Color.html("#263150"),
			"ink_soft": Color.html("#6B7391"), "blue": Color.html("#3A9AD9"), "navy": Color.html("#4B5BBD"),
			"orange": Color.html("#F6A33A"), "red": Color.html("#EE5F5F"), "yellow": Color.html("#FFD23F"),
			"purple": Color.html("#8E7BD8"), "neutral": Color.html("#ECE5D6"), "night": Color.html("#1B1840"),
			"night2": Color.html("#2D2564"), "helm": Color.html("#2FAFD2"), "engines": Color.html("#F5883A"),
			"power": Color.html("#F2BE33"), "weapons": Color.html("#EC5A5A"), "sensors": Color.html("#3FC197"),
			"ops": Color.html("#9A84E0"), "dc": Color.html("#E0A83A"),
			"plum": Color.html("#2B2350"), "plum2": Color.html("#4A3F86"), "lilac": Color.html("#9A8FD6"),
			"tangerine": Color.html("#F28C38"), "mint": Color.html("#6CD4B0"), "butter": Color.html("#F6D365"),
			"teal": Color.html("#3FB6C8"), "mustard": Color.html("#E8B23A"), "coral": Color.html("#F2545B"),
			"gunmetal": Color.html("#4A4E5A"), "gunmetal2": Color.html("#6B7080"), "gold": Color.html("#CFA13A"),
			"magenta": Color.html("#C2367A"), "cream": Color.html("#FFF6E5"), "cream2": Color.html("#F1E2C2"),
			"white": Color.html("#FFFFFF"), "green": Color.html("#5CBF55"),
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
