class_name K
extends RefCounted
## Shared constants, the palette, the crew personas and small helpers.

const SEATS: Array = ["captain", "helm", "engines", "weapons", "sensors", "shields", "engineer"]
const STATIONS: Array = ["helm", "engines", "weapons", "sensors", "shields", "engineer"]
## The crew is four people: the Captain and three roles. Each role works two of the six stations on one screen.
## (Everything underneath, from the simulation to the robots, still thinks in stations; roles are a layer on top.)
const ROLES: Dictionary = {
	"driver": {"name": "Driver", "seats": ["helm", "shields"], "color": "blue", "icon": "helm", "face": "helm", "persona": "Dex Wheelwright",
		"blurb": "Steers the ship and swings the shield. Keeps Pudding calm."},
	"stoker": {"name": "Stoker", "seats": ["engines", "weapons"], "color": "orange", "icon": "engines", "face": "engines", "persona": "Big Sal Throttleby",
		"blurb": "Sets the speed and works the gun. Both make heat."},
	"tech": {"name": "Tech", "seats": ["sensors", "engineer"], "color": "green", "icon": "engineer", "face": "engineer", "persona": "Gus Spanner",
		"blurb": "Scans what's out there and fixes what breaks."},
}
const CREW: Array = ["captain", "driver", "stoker", "tech"]

static func role_of(seat: String) -> String:
	## the role a station belongs to ("captain" for the captain, "" for nonsense)
	if seat == "captain" or ROLES.has(seat):
		return seat
	for id in ROLES.keys():
		if seat in ROLES[id].seats:
			return id
	return ""

static func role_seats(id: String) -> Array:
	## the stations a role (or a station's role) works; the captain is just the captain
	var r: String = role_of(id)
	if r == "captain":
		return ["captain"]
	return (ROLES[r].seats as Array).duplicate() if ROLES.has(r) else []

static func role_name(id: String) -> String:
	return "Captain" if id == "captain" else str(ROLES.get(id, {}).get("name", id))

static func role_color(id: String) -> String:
	return "navy" if id == "captain" else str(ROLES.get(id, {}).get("color", "ink"))

static func role_face(id: String) -> String:
	## the character for a seat: a role (or any station of it) shows its role's face
	var r: String = role_of(id)
	if r == "captain":
		return "captain"
	return str(ROLES.get(r, {}).get("face", id))

static func role_persona(id: String) -> String:
	var r: String = role_of(id)
	return persona("captain") if r == "captain" else str(ROLES.get(r, {}).get("persona", ""))

static func role_icon(id: String) -> String:
	return "captain" if id == "captain" else str(ROLES.get(id, {}).get("icon", "crew"))

## a player with a role (two crew stations) sees both on one screen
static func combined(seats: Array) -> bool:
	return seats.size() == 2 and str(seats[0]) in STATIONS and str(seats[1]) in STATIONS

const DT: float = 1.0 / 30.0
const SNAP_HZ: float = 15.0
const PORT_DEFAULT: int = 7777

const SEAT_INFO: Dictionary = {
	"captain": {"name": "Captain", "color": "navy", "icon": "captain", "animal": "walrus",
		"persona": "Captain Mo Pennywhistle", "trait": "Has never once touched a button. Very proud of this.",
		"job": "You see the whole picture: the chart, the goals, the ship and the crew. You touch nothing. Talk!"},
	"helm": {"name": "Helm", "color": "blue", "icon": "helm", "animal": "duck",
		"persona": "Dex Wheelwright", "trait": "Turns left to go right. Usually.",
		"job": "Steer with the wheel. You only see a compass, so listen to the captain."},
	"engines": {"name": "Engines", "color": "orange", "icon": "engines", "animal": "bulldog",
		"persona": "Big Sal Throttleby", "trait": "Talks to the engines. They talk back.",
		"job": "Set the speed with the throttle. You can't see where you're going."},
	"weapons": {"name": "Weapons", "color": "red", "icon": "weapons", "animal": "cat",
		"persona": "Rhoda 'Boom' Blastworth", "trait": "Aims first. Asks never.",
		"job": "Turn the turret and fire. You only see down the barrel, so ask where to aim."},
	"sensors": {"name": "Sensors", "color": "green", "icon": "sensors", "animal": "owl",
		"persona": "Ozzy Squint", "trait": "Can hear a mine blink.",
		"job": "Click blips on the radar and hold SCAN to find out what they are. The captain sees what you find."},
	"shields": {"name": "Shields", "color": "purple", "icon": "shields", "animal": "turtle",
		"persona": "Nana Fluffington", "trait": "Carries snacks for every occasion.",
		"job": "Turn the shield to face the danger. You can't see what's coming, so listen for where."},
	"engineer": {"name": "Engineer", "color": "mustard", "icon": "engineer", "animal": "raccoon",
		"persona": "Gus Spanner", "trait": "Has fixed everything once. Some things twice.",
		"job": "When something breaks, click it on the ship and hold REPAIR. Fires first!"},
}

const PALETTE: Dictionary = {
	"ink": "#1d1712", "paper": "#f2e2c0", "paper2": "#e3cd9f", "paper3": "#d4b985", "cream": "#fbf2dc", "white": "#fffaf0",
	"red": "#c9413a", "red2": "#a5302b", "orange": "#e07b39", "mustard": "#e2a93b", "gold": "#d9a43a",
	"yellow": "#f2cf5b", "teal": "#3f8f86", "blue": "#4a79a8", "sky": "#8fb8c9", "navy": "#2f3e5c",
	"green": "#6f9a4a", "olive": "#8a8b3c", "pink": "#e79a9a", "rose": "#d9737a", "purple": "#7a5a8c",
	"lilac": "#a98fb8", "brown": "#8a5a3b", "tan": "#c79a68", "sand": "#e3c08c", "grey": "#8f8c86",
	"grey2": "#b9b4a8", "steel": "#6d7a86", "night": "#232338", "night2": "#34324f", "ink_soft": "#6b5a48",
}

static var _pal: Dictionary = {}

static func pal(n: String) -> Color:
	if _pal.is_empty():
		for k in PALETTE.keys():
			_pal[k] = Color.html(PALETTE[k])
	return _pal.get(n, Color.MAGENTA)

static func seat_color(seat: String) -> Color:
	return pal(str(SEAT_INFO.get(seat, {}).get("color", "ink")))

static func wrap_pi(a: float) -> float:
	return wrapf(a, -PI, PI)

static func fmt_time(t: float) -> String:
	var s: int = int(maxf(0.0, t))
	return "%d:%02d" % [s / 60, s % 60]

static func seat_name(s: String) -> String:
	return str(SEAT_INFO.get(s, {}).get("name", s))

static func persona(s: String) -> String:
	return str(SEAT_INFO.get(s, {}).get("persona", s))

static func bearing_deg(a: float) -> int:
	## sim angle (radians, 0 = +x, y down) -> compass degrees (0 = up/north, clockwise)
	return int(round(rad_to_deg(a) + 90.0 + 360.0)) % 360

static func clock(rel: float) -> int:
	## relative angle (0 = dead ahead) -> o'clock (12 = ahead, 3 = starboard)
	var h: int = int(round(wrapf(rel, 0.0, TAU) / TAU * 12.0)) % 12
	return 12 if h == 0 else h
