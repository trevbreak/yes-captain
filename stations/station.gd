class_name Station
extends Control
## A crew station: one big hero control in the middle, and a narrow column on the right with "your job now"
## and any extra controls this mission has unlocked. Controls that aren't unlocked yet are hidden, not greyed.

var seat: String = ""
var hero: HBoxContainer
var side: VBoxContainer
var hint_lbl: Label
var keys_lbl: Label
var odd_chip: PanelContainer
var features: Dictionary = {}
var _held: Dictionary = {}
var _odd_t: float = 0.0

func _init(st: String) -> void:
	seat = st

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row: HBoxContainer = UIK.hbox(14)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(row)
	var console: PanelContainer = PanelContainer.new()
	console.add_theme_stylebox_override("panel", Art.box("desk_" + str(K.SEAT_INFO[seat].color), Color.WHITE, [0, -2, 0, -6]))
	console.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(console)
	var cv: VBoxContainer = UIK.vbox(4)
	console.add_child(cv)
	hero = UIK.hbox(26)
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cv.add_child(hero)
	# the bottom edge of the desk: how to work it, and whatever its owner left lying about
	var foot: HBoxContainer = UIK.hbox(8)
	cv.add_child(foot)
	var things: Array = DOODADS.get(seat, ["mug", "note"])
	foot.add_child(_doodad(str(things[0]), -0.06))
	keys_lbl = UIK.label("", 18, K.pal("ink_soft"), HORIZONTAL_ALIGNMENT_CENTER)
	keys_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keys_lbl.clip_text = true
	keys_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	foot.add_child(keys_lbl)
	foot.add_child(_doodad(str(things[1]), 0.05))
	var sc: ScrollContainer = ScrollContainer.new()
	sc.custom_minimum_size = Vector2(318, 0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(sc)
	side = UIK.vbox(14)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(side)
	var jw: Array = UIK.window("YOUR JOB NOW", str(K.SEAT_INFO[seat].color), str(K.SEAT_INFO[seat].icon))
	side.add_child(jw[0])
	hint_lbl = UIK.para("", 22)
	(jw[1] as VBoxContainer).add_child(hint_lbl)
	odd_chip = UIK.chip("SOMETHING'S NOT RIGHT...", "purple", "question", 16)
	odd_chip.visible = false
	odd_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	odd_chip.tooltip_text = "Your station has a glitch. Tell the captain what's odd. The Engineer has the manual."
	(jw[1] as VBoxContainer).add_child(odd_chip)
	build()

func _process(dt: float) -> void:
	if odd_chip != null and odd_chip.visible:
		_odd_t += dt
		odd_chip.rotation = sin(_odd_t * 9.0) * 0.03
		odd_chip.modulate.a = 0.75 + 0.25 * sin(_odd_t * 6.0)

func build() -> void:
	pass

const DOODADS: Dictionary = {
	"helm": ["mug", "note"], "engines": ["spanner", "mug"], "weapons": ["note", "pencil"], "sensors": ["pencil", "bowl"],
	"shields": ["bowl", "fluff"], "engineer": ["spanner", "note"],
}

func _doodad(name: String, tilt: float) -> TextureRect:
	var t: TextureRect = UIK.pic("doodad_" + name, Vector2(58, 46))
	t.rotation = tilt
	t.pivot_offset = Vector2(29, 23)
	if name == "note":
		t.tooltip_text = "DO NOT TOUCH. THIS MEANS YOU. - IGOR"
		t.mouse_filter = Control.MOUSE_FILTER_PASS
	return t

func send(key: String, val: Variant) -> void:
	Net.intent(seat, key, val)

func side_window(title: String, col: String, icon: String = "") -> VBoxContainer:
	var w: Array = UIK.window(title, col, icon)
	side.add_child(w[0])
	return w[1]

func apply(v: Dictionary, com: Dictionary) -> void:
	features = com.get("features", {})
	hint_lbl.text = str(com.get("hint", ""))
	odd_chip.visible = bool(com.get("glitchy", false))
	refresh(v, com)

func refresh(_v: Dictionary, _com: Dictionary) -> void:
	pass

func feat(f: String) -> bool:
	return bool(features.get(f, false))

func on_key(_key: Key, _down: bool) -> bool:
	## return true if handled
	return false

func _input(e: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if e is InputEventKey and not e.echo:
		var k: Key = (e as InputEventKey).physical_keycode
		if k in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_ESCAPE, KEY_QUOTELEFT, KEY_F, KEY_M]:
			return
		var down: bool = e.pressed
		if bool(_held.get(k, false)) == down and not down:
			return
		_held[k] = down
		if on_key(k, down):
			get_viewport().set_input_as_handled()

func held(k: Key) -> bool:
	return bool(_held.get(k, false))

func release_all() -> void:
	_held.clear()
