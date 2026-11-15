class_name HelmUI
extends Station
## Helm: a ship's wheel and a compass. That's it. Helm can't see where we're going; the captain can.
## Later: the barrel roll (mission 7).

var wheel: ShipWheel
var compass: CompassDial
var head_lbl: Label
var pull_lbl: Label
var roll_box: VBoxContainer
var roll_btn: BigButton
var left_btn: BigButton
var right_btn: BigButton
var _left: bool = false
var _right: bool = false
var _sent: float = 0.0
var _shown: float = 0.0          # where the wheel is drawn: it swings round to where the ship's wheel really is

func _init() -> void:
	super("helm")

func build() -> void:
	# hold an arrow to turn at a steady rate; let go (or hold both) and the ship flies straight.
	# The wheel in the middle shows it, so the captain's "hard left!" still means something.
	left_btn = BigButton.new("LEFT", "blue", true, 120)
	left_btn.arrow = -1
	keyed(left_btn, KEY_A)
	left_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left_btn.held.connect(func(on: bool):
		_left = on
		_steer())
	hero.add_child(left_btn)
	wheel = ShipWheel.new()
	wheel.disabled = true
	wheel.mouse_default_cursor_shape = Control.CURSOR_ARROW
	wheel.custom_minimum_size = Vector2(340, 340)
	wheel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hero.add_child(wheel)
	right_btn = BigButton.new("RIGHT", "blue", true, 120)
	right_btn.arrow = 1
	keyed(right_btn, KEY_D)
	right_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right_btn.held.connect(func(on: bool):
		_right = on
		_steer())
	hero.add_child(right_btn)
	var col: VBoxContainer = UIK.vbox(10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_child(col)
	compass = CompassDial.new()
	compass.custom_minimum_size = Vector2(240, 240)
	col.add_child(compass)
	head_lbl = UIK.title("000°", 54, UIK.c("cream"), HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(head_lbl)
	pull_lbl = UIK.para("", 20, UIK.c("red"))
	pull_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pull_lbl.custom_minimum_size = Vector2(240, 0)
	col.add_child(pull_lbl)
	roll_box = side_window("BARREL ROLL", "blue", "helm")
	roll_box.add_child(UIK.para("Dodge sideways: shots miss while you roll. Wait for the captain's shout!", 19))
	roll_btn = BigButton.new("ROLL!", "blue", false, 120)
	keyed(roll_btn, KEY_R)
	roll_btn.pressed_once.connect(func(): send("roll", true))
	roll_box.add_child(UIK.center(roll_btn))
	keys_lbl.text = "HOLD an arrow (or A / D) to turn. Let go to fly straight."

func _steer() -> void:
	var d: float = (1.0 if _right else 0.0) - (1.0 if _left else 0.0)
	if d != _sent:
		_sent = d
		send("wheel", d)

func _process(dt: float) -> void:
	super._process(dt)
	if is_visible_in_tree():
		wheel.set_value(lerpf(wheel.value, _shown, 1.0 - exp(-9.0 * dt)))

func release_all() -> void:
	super.release_all()
	_left = false
	_right = false
	if left_btn != null:
		left_btn.press_key(false)
		right_btn.press_key(false)
	_sent = 0.0

func refresh(v: Dictionary, _com: Dictionary) -> void:
	_shown = float(v.get("wheel", 0.0))
	compass.heading = float(v.get("heading", 0))
	compass.queue_redraw()
	head_lbl.text = "%03d°" % int(v.get("heading", 0))
	var msg: String = ""
	if not bool(v.get("steer_ok", true)):
		msg = "Steering is BROKEN: turns are slow. Ask the Tech!"
	elif float(v.get("pull", 0.0)) < 0.0:
		msg = "The ship is pulling LEFT (an engine is out). Nudge RIGHT to fly straight."
	elif float(v.get("pull", 0.0)) > 0.0:
		msg = "The ship is pulling RIGHT (an engine is out). Nudge LEFT to fly straight."
	elif bool(v.get("shaking", false)):
		msg = "Spinning! Keep holding to shake off grabbers."
	pull_lbl.text = msg
	roll_box.get_parent().get_parent().visible = feat("roll")
	var cd: float = float(v.get("roll_cd", 0.0))
	roll_btn.set_disabled(cd > 0.0)
	roll_btn.set_label("ROLL!" if cd <= 0.0 else "%.0fs" % ceil(cd))

func on_key(k: Key, down: bool) -> bool:
	match k:
		KEY_A, KEY_LEFT:
			left_btn.press_key(down)
			return true
		KEY_D, KEY_RIGHT:
			right_btn.press_key(down)
			return true
		KEY_R:
			if down and feat("roll"):
				roll_btn.press_key(true)
				roll_btn.press_key(false)
			return true
	return false

class CompassDial extends Control:
	## a compass card that turns under a fixed lubber line, like a ship's binnacle
	var heading: float = 0.0
	var _bezel: Texture2D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bezel = Art.tex("prop_dial", 1.0)

	func _draw() -> void:
		var r: float = minf(size.x, size.y) / 2.0
		var c: Vector2 = size / 2.0
		var inner: float = r * 0.8
		draw_circle(c, inner, UIK.c("cream"))
		var f: Font = UIK.font("head")
		var rot: float = -deg_to_rad(heading)
		for d in range(0, 360, 10):
			var a: float = deg_to_rad(d) + rot - PI / 2.0
			var big: bool = d % 30 == 0
			draw_line(c + Vector2.from_angle(a) * (inner - 4.0), c + Vector2.from_angle(a) * (inner - (16.0 if big else 9.0)), UIK.ink(),
				3.0 if big else 1.5, true)
		for pair in [[0, "N"], [90, "E"], [180, "S"], [270, "W"]]:
			var a2: float = deg_to_rad(float(pair[0])) + rot - PI / 2.0
			var p: Vector2 = c + Vector2.from_angle(a2) * (inner - 38.0)
			var t: String = str(pair[1])
			var ts: Vector2 = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 30)
			draw_string(f, p + Vector2(-ts.x / 2.0, 11), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UIK.c("red") if t == "N" else UIK.ink())
		for pair2 in [[45, "45"], [135, "135"], [225, "225"], [315, "315"]]:
			var a3: float = deg_to_rad(float(pair2[0])) + rot - PI / 2.0
			var p3: Vector2 = c + Vector2.from_angle(a3) * (inner - 36.0)
			var t3: String = str(pair2[1])
			var ts3: Vector2 = f.get_string_size(t3, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
			draw_string(f, p3 + Vector2(-ts3.x / 2.0, 6), t3, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UIK.c("ink_soft"))
		# our nose: the lubber line
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -inner + 2), c + Vector2(13, -inner + 30), c + Vector2(-13, -inner + 30)]), UIK.c("orange"))
		draw_polyline(PackedVector2Array([c + Vector2(0, -inner + 2), c + Vector2(13, -inner + 30), c + Vector2(-13, -inner + 30), c + Vector2(0, -inner + 2)]),
			UIK.ink(), 3.0, true)
		draw_circle(c, 8.0, UIK.ink())
		draw_texture_rect(_bezel, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)
