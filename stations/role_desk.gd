class_name RoleDesk
extends PanelContainer
## One crew role's desk: its two stations on one console, in the role's colour. The first station sits
## under the left thumb, the second under the right, and both stations' extras (roll, boost, Pudding, power,
## torpedo, comms...) share one column in the middle. Each station keeps its own controls and logic.

signal focus_wanted(seat: String)

var role: String
var stations: Dictionary = {}     # seat -> Station
var row: BoxContainer
var extras: GridContainer

func _init(r: String) -> void:
	role = r

func _ready() -> void:
	add_theme_stylebox_override("panel", Art.box("desk_" + K.role_color(role), Color.WHITE, [0, -2, 0, -6]))
	row = BoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	# one column per station's extras, side by side, so the desk doesn't grow tall
	extras = GridContainer.new()
	extras.columns = 2
	extras.add_theme_constant_override("h_separation", 12)
	extras.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var seats: Array = K.role_seats(role)
	for i in seats.size():
		var st: Station = _make(str(seats[i]))
		st.extras_host = extras
		st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		st.size_flags_vertical = Control.SIZE_EXPAND_FILL
		st.focus_wanted.connect(func(s: String): focus_wanted.emit(s))
		stations[seats[i]] = st
		row.add_child(st)
		if i == 0:
			row.add_child(extras)

static func _make(st: String) -> Station:
	match st:
		"helm":
			return HelmUI.new()
		"engines":
			return EnginesUI.new()
		"weapons":
			return WeaponsUI.new()
		"sensors":
			return SensorsUI.new()
		"shields":
			return ShieldsUI.new()
	return EngineerUI.new()

func set_vertical(on: bool) -> void:
	## a tall screen: the two stations one above the other, extras between
	row.vertical = on

func _process(_dt: float) -> void:
	# the middle column only earns its width when a station has something in it
	var n: int = 0
	for c in extras.get_children():
		if (c as Control).visible:
			n += 1
	if extras.visible != (n > 0):
		extras.visible = n > 0
	if n > 0 and extras.columns != n:
		extras.columns = n
