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
var _key_t: float = 0.0

func _init() -> void:
	super("helm")

func build() -> void:
	wheel = ShipWheel.new()
	wheel.custom_minimum_size = Vector2(400, 400)
	wheel.changed.connect(func(v: float): send("wheel", v))
	hero.add_child(wheel)
	var col: VBoxContainer = UIK.vbox(10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_child(col)
	compass = CompassDial.new()
	compass.custom_minimum_size = Vector2(250, 250)
	col.add_child(compass)
	head_lbl = UIK.title("000°", 54, UIK.c("cream"), HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(head_lbl)
	col.add_child(UIK.btn("Straighten up", "cream", func():
		wheel.set_value(0.0, true), "", 20))
	pull_lbl = UIK.para("", 20, UIK.c("red"))
	pull_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pull_lbl.custom_minimum_size = Vector2(250, 0)
	col.add_child(pull_lbl)
	roll_box = side_window("BARREL ROLL", "blue", "helm")
	roll_box.add_child(UIK.para("Dodge sideways: shots miss while you roll. Wait for the captain's shout!", 19))
	roll_btn = BigButton.new("ROLL!", "blue", false, 120)
	roll_btn.key_hint = "R"
	roll_btn.pressed_once.connect(func(): send("roll", true))
	roll_box.add_child(UIK.center(roll_btn))
	keys_lbl.text = "Drag the wheel round, or A / D.   S straightens up.   It stays where you leave it."

func refresh(v: Dictionary, _com: Dictionary) -> void:
	if not wheel._drag:
		wheel.set_value(float(v.get("wheel", 0.0)))
	compass.heading = float(v.get("heading", 0))
	compass.queue_redraw()
	head_lbl.text = "%03d°" % int(v.get("heading", 0))
	var msg: String = ""
	if not bool(v.get("steer_ok", true)):
		msg = "Steering is BROKEN: turns are slow. Ask the Engineer!"
	elif float(v.get("pull", 0.0)) < 0.0:
		msg = "The ship is pulling LEFT (an engine is out). Steer right to fly straight."
	elif float(v.get("pull", 0.0)) > 0.0:
		msg = "The ship is pulling RIGHT (an engine is out). Steer left to fly straight."
	elif bool(v.get("shaking", false)):
		msg = "Spinning! Hold it to shake off grabbers."
	pull_lbl.text = msg
	roll_box.get_parent().get_parent().visible = feat("roll")
	var cd: float = float(v.get("roll_cd", 0.0))
	roll_btn.set_disabled(cd > 0.0)
	roll_btn.label = "ROLL!" if cd <= 0.0 else "%.0fs" % ceil(cd)
	roll_btn.queue_redraw()

func on_key(k: Key, down: bool) -> bool:
	match k:
		KEY_A, KEY_LEFT:
			if down:
				wheel.set_value(wheel.value - 0.25, true)
			return true
		KEY_D, KEY_RIGHT:
			if down:
				wheel.set_value(wheel.value + 0.25, true)
			return true
		KEY_S, KEY_DOWN:
			if down:
				wheel.set_value(0.0, true)
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
