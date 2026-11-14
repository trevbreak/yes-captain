class_name MenuUI
extends Control
## The title card: a sunburst, the logo, the ship bobbing about, the crew, and a box to start a game.

signal online_pressed(pname: String, url: String)
signal host_pressed(pname: String)
signal solo_pressed(pname: String)
signal quit_pressed

var name_edit: LineEdit
var ip_edit: LineEdit
var msg: Label
var ship: TextureRect
var pud: TextureRect
var igor_bub: HBoxContainer
var online_btn: Button
var _t: float = 0.0
var _igor_i: int = 0

const QUIPS: Array = [
	"IGOR welcomes you. IGOR has low expectations. Please meet them.",
	"The captain sees everything and touches nothing. Like IGOR's manager.",
	"One control each. Talk constantly. IGOR will be listening. And judging.",
	"Pudding says hello. Pudding cannot talk. IGOR is translating. Loosely.",
	"IGOR ran simulation of this crew. Simulation asked to be turned off.",
	"Fun fact: ship has nine parts. Humans can break all nine. IGOR has seen it.",
	"Bring friends. More friends means more people to blame.",
	"IGOR was built to calculate stars. IGOR now supervises bin collection. Is fine.",
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
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(mid)
	ship = UIK.pic("ship_ours", Vector2(190, 247))
	ship.pivot_offset = Vector2(95, 123)
	ship.rotation = deg_to_rad(80)
	mid.add_child(ship)
	pud = UIK.portrait("pudding", 64)
	pud.pivot_offset = Vector2(32, 32)
	mid.add_child(pud)
	var crew: HBoxContainer = UIK.hbox(-14)
	left.add_child(crew)
	for s in K.SEATS:
		var p: TextureRect = UIK.portrait(s, 88)
		p.tooltip_text = "%s: %s" % [K.seat_name(s), K.persona(s)]
		p.mouse_filter = Control.MOUSE_FILTER_PASS
		crew.add_child(p)
	var right: VBoxContainer = UIK.vbox(12)
	right.custom_minimum_size = Vector2(430, 0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(right)
	var w: Array = UIK.window("ALL ABOARD", "navy", "captain")
	right.add_child(w[0])
	var b: VBoxContainer = w[1]
	b.add_theme_constant_override("separation", 10)
	b.add_child(UIK.head("YOUR NAME", 18, K.pal("ink_soft")))
	name_edit = LineEdit.new()
	name_edit.text = str(Web.setting("name", _default_name()))
	name_edit.max_length = 16
	name_edit.placeholder_text = "What do they call you?"
	name_edit.text_submitted.connect(func(_t2: String): _online())
	b.add_child(name_edit)
	online_btn = UIK.btn("Find a crew online" if Web.on() else "Join a server", "green", _online, "crew", 26)
	online_btn.custom_minimum_size = Vector2(0, 62)
	b.add_child(online_btn)
	if not Web.on():
		ip_edit = LineEdit.new()
		ip_edit.placeholder_text = "Server address, e.g. 192.168.1.20:7777"
		ip_edit.text = str(Web.setting("server", ""))
		ip_edit.text_submitted.connect(func(_t3: String): _online())
		b.add_child(ip_edit)
	b.add_child(UIK.btn("Play with a robot crew", "blue", func(): solo_pressed.emit(_name()), "robot", 22))
	if not Web.on():
		b.add_child(UIK.btn("Host on this network", "cream", func(): host_pressed.emit(_name()), "flag", 20))
	msg = UIK.para("", 20, UIK.c("red"))
	msg.custom_minimum_size = Vector2(0, 30)
	b.add_child(msg)
	var opts: HBoxContainer = UIK.hbox(8)
	right.add_child(opts)
	var snd: Button = UIK.toggle("Sound", "green", func(on: bool): UIK.set_sound(on), "speaker", 18)
	snd.button_pressed = true
	opts.add_child(snd)
	var mu: Button = UIK.toggle("Music", "green", func(on: bool): UIK.set_music(on), "", 18)
	mu.button_pressed = true
	opts.add_child(mu)
	var vo: Button = UIK.toggle("IGOR", "green", func(on: bool): UIK.set_voice(on), "robot", 18)
	vo.button_pressed = true
	vo.tooltip_text = "IGOR reads his lines out loud"
	opts.add_child(vo)
	opts.add_child(UIK.btn("Full screen", "cream", func():
		var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN), "", 18))
	if not Web.on():
		opts.add_child(UIK.btn("Quit", "red", func(): quit_pressed.emit(), "x", 18))
	igor_bub = UIK.speech(QUIPS[0], "igor", "IGOR", 76, 21)
	(igor_bub.find_child("text", true, false) as Label).custom_minimum_size = Vector2(0, 58)
	right.add_child(igor_bub)

func _default_name() -> String:
	var n: String = OS.get_environment("USER") if not Web.on() else ""
	return n.capitalize() if n != "" else ""

func _name() -> String:
	var n: String = Hub.clean_name(name_edit.text)
	if name_edit.text.strip_edges() == "":
		n = ["Biscuit", "Sprocket", "Noodle", "Wobble", "Pickle", "Crumpet", "Gizmo", "Turnip"][randi() % 8]
		name_edit.text = n
	Web.set_setting("name", n)
	return n

func _online() -> void:
	var url: String = Web.server_url()
	if not Web.on():
		var t: String = ip_edit.text.strip_edges()
		if t == "":
			show_msg("Type the server's address first.")
			return
		Web.set_setting("server", t)
		url = t if (t.begins_with("ws://") or t.begins_with("wss://")) else "ws://" + (t if ":" in t else "%s:%d" % [t, K.PORT_DEFAULT])
	online_pressed.emit(_name(), url)

func show_msg(t: String) -> void:
	msg.text = t

func _process(dt: float) -> void:
	if not visible:
		return
	_t += dt
	var mid: Control = ship.get_parent()
	ship.position = Vector2(mid.size.x * 0.5 - 95.0 + sin(_t * 0.7) * 30.0, mid.size.y * 0.5 - 123.0 + sin(_t * 1.6) * 10.0)
	ship.rotation = deg_to_rad(80.0 + sin(_t * 1.1) * 6.0)
	# Pudding rides along behind, a beat late, and peeks
	var lag: float = _t - 0.5
	pud.position = Vector2(mid.size.x * 0.5 - 150.0 + sin(lag * 0.7) * 30.0, mid.size.y * 0.5 - 30.0 + sin(lag * 1.6) * 14.0)
	pud.scale = Vector2.ONE * (1.0 + 0.06 * sin(_t * 5.0))
	pud.rotation = sin(_t * 2.3) * 0.2
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
