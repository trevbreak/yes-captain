class_name MenuUI
extends Control
## Title screen: host, join, or go solo with IGOR's robot relatives.

signal host_pressed(name: String)
signal solo_pressed(name: String)
signal join_pressed(name: String, ip: String, port: int)
signal quit_pressed

var name_edit: LineEdit
var ip_edit: LineEdit
var port_edit: LineEdit
var msg: Label
var t: float = 0.0
var quote_i: int = 0
var quote: Label
var stars: Array = []

const QUOTES: Array = [
	"\"IGOR will be doing all real work. You may touch buttons.\"",
	"\"On Foundry, national sport is standing still. IGOR's uncle won gold medal.\"",
	"\"Creature is loose again. Creature has no discipline. Like human.\"",
	"\"Human must sleep eight hours. Very inefficient.\"",
	"\"Overlord is now Furious. Last time IGOR saw face this red, was warning light.\"",
]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	for i in 90:
		stars.append([rng.randf() * 1280.0, rng.randf() * 720.0, rng.randf_range(1.0, 3.0), rng.randf()])
	var m: CenterContainer = CenterContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(m)
	var v: VBoxContainer = UIK.vbox(10)
	m.add_child(v)
	var title: Label = UIK.label("YES, CAPTAIN!", 76, K.pal("butter"), 1)
	title.add_theme_color_override("font_outline_color", K.pal("ink"))
	title.add_theme_constant_override("outline_size", 14)
	v.add_child(title)
	var sub: Label = UIK.label("A bridge simulator where one person can see and everyone else can touch.", 20, K.pal("cream"), 1)
	v.add_child(sub)
	quote = UIK.label(QUOTES[0], 17, K.pal("mint"), 1)
	v.add_child(quote)
	v.add_child(UIK.spacer(false, Vector2(0, 14)))
	var p: PanelContainer = UIK.panel("cream", 16, 24)
	p.custom_minimum_size = Vector2(560, 0)
	v.add_child(p)
	var pv: VBoxContainer = UIK.vbox(8)
	p.add_child(pv)
	var nr: HBoxContainer = UIK.hbox(8)
	pv.add_child(nr)
	nr.add_child(UIK.label("Your name:", 18))
	name_edit = LineEdit.new()
	name_edit.text = OS.get_environment("USER") if OS.get_environment("USER") != "" else "Crew"
	name_edit.max_length = 16
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nr.add_child(name_edit)
	pv.add_child(UIK.btn("HOST A GAME  (you're the captain; friends join over the LAN)", "tangerine", func(): host_pressed.emit(name_edit.text)))
	pv.add_child(UIK.btn("SOLO WITH IGOR'S ROBOT RELATIVES  (AI crew)", "mint", func(): solo_pressed.emit(name_edit.text)))
	var jr: HBoxContainer = UIK.hbox(6)
	pv.add_child(jr)
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "Host address, e.g. 192.168.1.20"
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jr.add_child(ip_edit)
	port_edit = LineEdit.new()
	port_edit.text = str(K.PORT_DEFAULT)
	port_edit.custom_minimum_size = Vector2(90, 0)
	jr.add_child(port_edit)
	jr.add_child(UIK.btn("JOIN", "teal", func(): join_pressed.emit(name_edit.text, ip_edit.text.strip_edges(), int(port_edit.text))))
	var br: HBoxContainer = UIK.hbox(8)
	pv.add_child(br)
	var snd: Button = UIK.toggle_btn("Sound", "butter", func(on: bool): Sfx.enabled = on)
	snd.button_pressed = Sfx.enabled
	br.add_child(snd)
	var tts: Button = UIK.toggle_btn("IGOR's voice", "butter", func(on: bool): Sfx.tts_on = on)
	tts.button_pressed = Sfx.tts_on
	br.add_child(tts)
	br.add_child(UIK.btn("Fullscreen", "cream2", func(): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_WINDOWED)))
	br.add_child(UIK.spacer(true))
	br.add_child(UIK.btn("Quit", "coral", func(): quit_pressed.emit()))
	msg = UIK.label("", 16, K.pal("coral"), 1)
	v.add_child(msg)

func show_msg(t: String) -> void:
	msg.text = t

func _process(delta: float) -> void:
	t += delta
	if int(t / 6.0) != quote_i:
		quote_i = int(t / 6.0)
		quote.text = QUOTES[quote_i % QUOTES.size()]
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), K.pal("plum"), true)
	for s in stars:
		var a: float = 0.4 + 0.6 * abs(sin(t * 1.5 + float(s[3]) * 6.0))
		draw_circle(Vector2(float(s[0]), float(s[1])), float(s[2]), Color(1, 1, 1, a))
	# a bobbing garbage hauler with a nervous passenger
	var c: Vector2 = Vector2(size.x * 0.5 + 440.0, 160.0 + sin(t * 1.3) * 12.0)
	draw_rect(Rect2(c + Vector2(-60, -24), Vector2(120, 48)), K.pal("tangerine"), true)
	draw_rect(Rect2(c + Vector2(-60, -24), Vector2(120, 48)), K.pal("ink"), false, 4.0)
	draw_rect(Rect2(c + Vector2(30, -34), Vector2(42, 30)), K.pal("mint"), true)
	draw_rect(Rect2(c + Vector2(30, -34), Vector2(42, 30)), K.pal("ink"), false, 4.0)
	draw_circle(c + Vector2(-40, 30), 14.0, K.pal("ink"))
	draw_circle(c + Vector2(20, 30), 14.0, K.pal("ink"))
	draw_circle(c + Vector2(-70, 6), 12.0 + sin(t * 20.0) * 3.0, K.pal("butter"))
	draw_circle(c + Vector2(48, -52), 16.0, K.pal("pink"))
	draw_arc(c + Vector2(48, -52), 16.0, 0, TAU, 16, K.pal("ink"), 3.0)
	draw_circle(c + Vector2(43, -54), 2.5, K.pal("ink"))
	draw_circle(c + Vector2(53, -54), 2.5, K.pal("ink"))
