class_name Station
extends Control
## A crew station: one big hero control in the middle, and a narrow column on the right with "your job now"
## and any extra controls this mission has unlocked. Controls that aren't unlocked yet are hidden, not greyed.

signal focus_wanted(seat: String)

var seat: String = ""
var keys_on: bool = true          # on a combined screen only the half you last touched hears the keyboard
var hero: HBoxContainer
var _row: HBoxContainer
var compact: bool = false         # half of a combined screen: no job panel or desk footer (the shell shows the hints)
var _foot: HBoxContainer
var _job_win: Control
var _side_sc: ScrollContainer
var _console: PanelContainer
var extras_host: Container = null # on a role desk: where this station's extra panels go (set before it's added)
var side: VBoxContainer
var hint_lbl: Label
var keys_lbl: Label
var odd_chip: PanelContainer
var features: Dictionary = {}
var _held: Dictionary = {}
var _keyed: Array = []            # [BigButton, default key]: the hints to redraw when keys are rebound
var _odd_t: float = 0.0

func _init(st: String) -> void:
	seat = st

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row: HBoxContainer = UIK.hbox(14)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(row)
	_row = row
	# a plain Control doesn't pass its children's size up: say how much room the desk really needs,
	# so the FitBox it sits in can shrink it to fit a small screen instead of letting it spill
	row.minimum_size_changed.connect(update_minimum_size)
	var console: PanelContainer = PanelContainer.new()
	console.add_theme_stylebox_override("panel", Art.box("desk_" + str(K.SEAT_INFO[seat].color), Color.WHITE, [0, -2, 0, -6]))
	console.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(console)
	_console = console
	var cv: VBoxContainer = UIK.vbox(4)
	console.add_child(cv)
	hero = UIK.hbox(26)
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cv.add_child(hero)
	# the bottom edge of the desk: how to work it, and whatever its owner left lying about
	var foot: HBoxContainer = UIK.hbox(8)
	cv.add_child(foot)
	_foot = foot
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
	sc.set_meta("scroll_ok", true)    # a lone station's extras may outgrow the screen (on a role desk they never scroll)
	row.add_child(sc)
	_side_sc = sc
	side = UIK.vbox(14)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(side)
	var jw: Array = UIK.window("YOUR JOB NOW", str(K.SEAT_INFO[seat].color), str(K.SEAT_INFO[seat].icon))
	side.add_child(jw[0])
	_job_win = jw[0]
	hint_lbl = UIK.para("", 22)
	(jw[1] as VBoxContainer).add_child(hint_lbl)
	odd_chip = UIK.chip("SOMETHING'S NOT RIGHT...", "purple", "question", 16)
	odd_chip.visible = false
	odd_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	odd_chip.tooltip_text = "Your station has a glitch. Tell the captain what's odd. The Tech has the manual."
	(jw[1] as VBoxContainer).add_child(odd_chip)
	build()
	add_to_group("input_hints_labels")
	_on_input_kind()
	if extras_host != null:
		# part of a role desk: the desk draws the console; this station's extras join the desk's middle column
		_console.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		sc.remove_child(side)
		extras_host.add_child(side)
		_side_sc.visible = false
		set_compact(true)

func _process(dt: float) -> void:
	if odd_chip != null and odd_chip.visible:
		_odd_t += dt
		odd_chip.rotation = sin(_odd_t * 9.0) * 0.03
		odd_chip.modulate.a = 0.75 + 0.25 * sin(_odd_t * 6.0)

func build() -> void:
	pass

func _get_minimum_size() -> Vector2:
	return _row.get_combined_minimum_size() if _row != null else Vector2.ZERO

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

func keyed(b: BigButton, def: Key) -> void:
	## this button's keyboard key (rebindable): shown on the button when the player is using keys
	b.key_hint = Keys.hint(seat, def)
	_keyed.append([b, def])

func refresh_keys() -> void:
	for p in _keyed:
		var b: BigButton = p[0]
		b.key_hint = Keys.hint(seat, p[1])
		b._fit_label()
		b.queue_redraw()

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
	if compact:
		_tidy_side()

func _on_input_kind() -> void:
	## the desk's footer only tells you keys; on a touch screen it's noise
	_foot.visible = not compact and UIK.keys_shown()

func set_compact(on: bool) -> void:
	compact = on
	_foot.visible = not on and UIK.keys_shown()
	_job_win.visible = not on
	_tidy_side()

func _tidy_side() -> void:
	## the side column only earns its width when it has something in it
	var any: bool = false
	for c in side.get_children():
		if (c as Control).visible:
			any = true
	if extras_host != null:
		side.visible = any
	else:
		_side_sc.visible = any

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
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and not keys_on:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * (e as InputEventMouseButton).position
		if Rect2(Vector2.ZERO, size).has_point(local):
			focus_wanted.emit(seat)
		return
	if not keys_on:
		return
	if e is InputEventKey and not e.echo:
		var raw: Key = (e as InputEventKey).physical_keycode
		if raw in Keys.RESERVED:
			return
		var k: Key = Keys.translate(seat, raw)      # the player's own bindings, back to this station's defaults
		if k == KEY_NONE:
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

func set_keys_on(on: bool) -> void:
	if keys_on and not on:
		# let go of any key held down in this half: on_key(up) sends the release
		for k in _held.keys():
			if bool(_held[k]):
				_held[k] = false
				on_key(k, false)
	keys_on = on
	keys_lbl.modulate.a = 1.0 if on else 0.45
