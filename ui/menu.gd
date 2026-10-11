class_name MenuUI
extends Control
## Title screen: logo, the ship, the crew, and three ways to play.

signal host_pressed(name: String)
signal solo_pressed(name: String)
signal join_pressed(name: String, ip: String, port: int)
signal quit_pressed

var name_edit: LineEdit
var ip_edit: LineEdit
var port_edit: LineEdit
var msg: Label
var t: float = 0.0
var quote_i: int = -1
var igor_bubble: HBoxContainer
var ship: TextureRect
var ship_base_y: float = 0.0

const QUOTES: Array = [
	"IGOR will be doing all real work. You may touch buttons.",
	"On Foundry, national sport is standing still. IGOR's uncle won gold medal.",
	"Creature is loose again. Creature has no discipline. Like human.",
	"Human must sleep eight hours. Very inefficient. IGOR sleeps zero hours.",
	"Overlord is now Furious. Last time IGOR saw face this red, was warning light.",
]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIK.space_bg(self)
	var root: HBoxContainer = UIK.hbox(30)
	var m: MarginContainer = UIK.margin(root, 36)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(m)
	# ---- left: logo + menu card
	var left: VBoxContainer = UIK.vbox(14)
	left.custom_minimum_size = Vector2(540, 0)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(left)
	var logo: Label = UIK.title("YES, CAPTAIN!", 76, K.pal("yellow"), K.pal("plum").darkened(0.35))
	left.add_child(logo)
	left.add_child(UIK.wrapped(UIK.label("One captain can see but not touch. Everyone else can touch but not see.", 20, Color(1, 1, 1, 0.85))))
	var w: Array = UIK.window("READY FOR DUTY?", "blue", "crew", 16)
	left.add_child(w[0])
	var body: VBoxContainer = w[1]
	var nr: HBoxContainer = UIK.hbox(10)
	body.add_child(nr)
	nr.add_child(UIK.heading("Your name", 17))
	name_edit = LineEdit.new()
	name_edit.text = OS.get_environment("USER").capitalize() if OS.get_environment("USER") != "" else "Crew"
	name_edit.max_length = 16
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nr.add_child(name_edit)
	var host: Button = UIK.btn("Host a game  (friends join over the LAN)", "green", func(): host_pressed.emit(name_edit.text), "play")
	host.custom_minimum_size.y = 54
	body.add_child(host)
	var solo: Button = UIK.btn("Play with a robot crew", "blue", func(): solo_pressed.emit(name_edit.text), "robot")
	solo.custom_minimum_size.y = 54
	body.add_child(solo)
	var jr: HBoxContainer = UIK.hbox(8)
	body.add_child(jr)
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "Host address, e.g. 192.168.1.20"
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jr.add_child(ip_edit)
	port_edit = LineEdit.new()
	port_edit.text = str(K.PORT_DEFAULT)
	port_edit.custom_minimum_size = Vector2(84, 0)
	jr.add_child(port_edit)
	jr.add_child(UIK.btn("Join", "orange", func(): join_pressed.emit(name_edit.text, ip_edit.text.strip_edges(), int(port_edit.text)), "crew"))
	var br: HBoxContainer = UIK.hbox(8)
	body.add_child(br)
	var snd: Button = UIK.toggle_btn("Sound", "neutral", func(on: bool): Sfx.enabled = on)
	snd.button_pressed = Sfx.enabled
	br.add_child(snd)
	var tts: Button = UIK.toggle_btn("IGOR's voice", "neutral", func(on: bool): Sfx.tts_on = on)
	tts.button_pressed = Sfx.tts_on
	br.add_child(tts)
	br.add_child(UIK.btn("Fullscreen", "neutral", _toggle_fs))
	br.add_child(UIK.spacer(true))
	br.add_child(UIK.btn("Quit", "red", func(): quit_pressed.emit()))
	msg = UIK.label("", 17, K.pal("yellow"))
	left.add_child(msg)
	# ---- right: the ship, the crew, IGOR
	var right: VBoxContainer = UIK.vbox(16)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(right)
	var ship_box: Control = Control.new()
	ship_box.custom_minimum_size = Vector2(520, 330)
	ship_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right.add_child(ship_box)
	ship = TextureRect.new()
	ship.texture = UIK.tex("art_ship", 1040)
	ship.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ship.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ship.size = Vector2(520, 325)
	ship_box.add_child(ship)
	var crew_row: HBoxContainer = UIK.hbox(-14)
	crew_row.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_child(crew_row)
	for s in K.SEATS:
		var pr: TextureRect = UIK.portrait(str(K.SEAT_INFO[s].portrait), 76)
		pr.tooltip_text = "%s (%s)" % [K.SEAT_INFO[s].persona, K.seat_name(s)]
		pr.mouse_filter = Control.MOUSE_FILTER_PASS
		crew_row.add_child(pr)
	igor_bubble = UIK.speech(QUOTES[0], "igor", "IGOR, ship's robot", 72)
	igor_bubble.custom_minimum_size = Vector2(520, 0)
	igor_bubble.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right.add_child(igor_bubble)

func _toggle_fs() -> void:
	var fs: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)

func show_msg(tt: String) -> void:
	msg.text = tt

func _process(delta: float) -> void:
	t += delta
	if ship != null:
		ship.position.y = sin(t * 1.2) * 8.0
		ship.rotation = sin(t * 0.9) * 0.015
	var qi: int = int(t / 7.0) % QUOTES.size()
	if qi != quote_i:
		quote_i = qi
		var l: Label = igor_bubble.find_child("text", true, false)
		if l != null:
			l.text = QUOTES[qi]
