class_name MenuUI
extends Control
## The title card: a sunburst, the logo, the ship bobbing about, the crew, and a box to start a game.

signal host_pressed(pname: String)
signal solo_pressed(pname: String)
signal join_pressed(pname: String, ip: String, port: int)
signal quit_pressed

var name_edit: LineEdit
var ip_edit: LineEdit
var msg: Label
var ship: TextureRect
var igor_bub: HBoxContainer
var _t: float = 0.0
var _igor_i: int = 0

const QUIPS: Array = [
	"IGOR welcomes you. IGOR has low expectations. Please meet them.",
	"The captain sees everything and touches nothing. Like IGOR's manager.",
	"One control each. Talk constantly. IGOR will be listening.",
	"Pudding says hello. Pudding cannot talk. IGOR is translating.",
]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIK.bg(self)
	var sb: Sunburst = Sunburst.new()
	sb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sb)
	var row: HBoxContainer = UIK.hbox(20)
	var m: MarginContainer = UIK.margin(row, 28)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(m)
	var left: VBoxContainer = UIK.vbox(4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	left.add_child(UIK.title("YES, CAPTAIN!", 92, UIK.c("red")))
	left.add_child(UIK.head("A BRIDGE SIMULATOR FOR LOUD FRIENDS", 24, UIK.ink()))
	var mid: Control = Control.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(mid)
	ship = UIK.pic("ship_ours", Vector2(190, 247))
	ship.pivot_offset = Vector2(95, 123)
	ship.rotation = deg_to_rad(80)
	mid.add_child(ship)
	var crew: HBoxContainer = UIK.hbox(-14)
	left.add_child(crew)
	for s in K.SEATS:
		var p: TextureRect = UIK.portrait(s, 88)
		p.tooltip_text = "%s: %s" % [K.seat_name(s), K.persona(s)]
		p.mouse_filter = Control.MOUSE_FILTER_PASS
		crew.add_child(p)
	crew.add_child(UIK.portrait("pudding", 70))
	var right: VBoxContainer = UIK.vbox(14)
	right.custom_minimum_size = Vector2(430, 0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(right)
	var w: Array = UIK.window("ALL ABOARD", "navy", "captain")
	right.add_child(w[0])
	var b: VBoxContainer = w[1]
	b.add_theme_constant_override("separation", 12)
	b.add_child(UIK.head("YOUR NAME", 18, K.pal("ink_soft")))
	name_edit = LineEdit.new()
	name_edit.text = _default_name()
	name_edit.max_length = 16
	b.add_child(name_edit)
	b.add_child(UIK.btn("Play with a robot crew", "green", func(): solo_pressed.emit(name_edit.text), "robot", 24))
	b.add_child(UIK.btn("Host a LAN game", "blue", func(): host_pressed.emit(name_edit.text), "crew", 24))
	var jr: HBoxContainer = UIK.hbox(8)
	b.add_child(jr)
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "Host address"
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_edit.text_submitted.connect(func(_t2: String): _join())
	jr.add_child(ip_edit)
	jr.add_child(UIK.btn("Join", "orange", _join, "play", 22))
	msg = UIK.para("", 20, UIK.c("red"))
	b.add_child(msg)
	var opts: HBoxContainer = UIK.hbox(8)
	right.add_child(opts)
	var snd: Button = UIK.toggle("Sound", "green", func(on: bool): UIK.set_sound(on), "speaker", 18)
	snd.button_pressed = true
	opts.add_child(snd)
	var vo: Button = UIK.toggle("IGOR voice", "green", func(on: bool): UIK.set_voice(on), "robot", 18)
	vo.button_pressed = true
	opts.add_child(vo)
	opts.add_child(UIK.btn("Full screen", "cream", func():
		var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN), "", 18))
	opts.add_child(UIK.btn("Quit", "red", func(): quit_pressed.emit(), "x", 18))
	igor_bub = UIK.speech(QUIPS[0], "igor", "IGOR", 76, 21)
	right.add_child(igor_bub)

func _default_name() -> String:
	var n: String = OS.get_environment("USER")
	return n.capitalize() if n != "" else "Captain"

func _join() -> void:
	var t: String = ip_edit.text.strip_edges()
	var port: int = K.PORT_DEFAULT
	if ":" in t:
		port = int(t.get_slice(":", 1))
		t = t.get_slice(":", 0)
	join_pressed.emit(name_edit.text, t, port)

func show_msg(t: String) -> void:
	msg.text = t

func _process(dt: float) -> void:
	if not visible:
		return
	_t += dt
	var mid: Control = ship.get_parent()
	ship.position = Vector2(mid.size.x * 0.5 - 95.0 + sin(_t * 0.7) * 30.0, mid.size.y * 0.5 - 123.0 + sin(_t * 1.6) * 10.0)
	ship.rotation = deg_to_rad(80.0 + sin(_t * 1.1) * 6.0)
	if int(_t / 7.0) != _igor_i:
		_igor_i = int(_t / 7.0)
		(igor_bub.find_child("text", true, false) as Label).text = QUIPS[_igor_i % QUIPS.size()]

class Sunburst extends Control:
	## slowly turning cartoon rays behind everything
	var _a: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(dt: float) -> void:
		_a += dt * 0.04
		queue_redraw()

	func _draw() -> void:
		var c: Vector2 = Vector2(size.x * 0.32, size.y * 0.55)
		var r: float = size.length()
		var n: int = 24
		for i in n:
			if i % 2:
				continue
			var a0: float = _a + i * TAU / n
			var a1: float = a0 + TAU / n
			draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a0) * r, c + Vector2.from_angle(a1) * r]), Color(1, 0.97, 0.88, 0.35))
