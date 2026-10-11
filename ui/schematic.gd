class_name Schematic
extends Control
## The ship's module grid for Damage Control. Click a cell to select it.

signal picked(id: String)

var mods: Array = []
var cons: Dictionary = {}
var selected: String = ""
var pud_at: String = ""
var t: float = 0.0
const CW: float = 104.0
const CH: float = 76.0

func _init() -> void:
	custom_minimum_size = Vector2(CW * 5.0 + 12.0, CH * 5.0 + 12.0)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _cell_rect(m: Dictionary) -> Rect2:
	return Rect2(6.0 + float(m.gx) * CW, 6.0 + float(m.gy) * CH, CW - 6.0, CH - 6.0)

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		for m in mods:
			if _cell_rect(m).has_point(ev.position):
				selected = str(m.id)
				picked.emit(selected)
				return

func _draw() -> void:
	var ink: Color = K.pal("ink")
	var font: Font = get_theme_default_font()
	draw_string(font, Vector2(8, size.y - 4), "FRONT is up. Click a module.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(ink, 0.6))
	for m in mods:
		var r: Rect2 = _cell_rect(m)
		var st: int = int(m.state)
		var col: Color = K.pal("white")
		match st:
			0:
				col = K.pal("mint").lightened(0.35)
			1:
				col = K.pal("butter")
			2:
				col = K.pal("tangerine")
			3:
				col = K.pal("coral")
		if bool(m.nopower):
			col = col.lerp(Color(0.55, 0.55, 0.6), 0.65)
		var bw: int = 5 if str(m.id) == selected else 3
		var bc: Color = K.pal("plum2") if str(m.id) == selected else ink
		draw_style_box(UIK.box(col, bc, 12, bw, 0), r)
		draw_string(font, r.position + Vector2(4, 20), str(m.label), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 14, ink)
		var sub: String = ""
		if bool(m.fire):
			sub = "FIRE!"
			draw_circle(r.position + Vector2(r.size.x - 18, r.size.y - 22), 9.0 + sin(t * 12.0) * 2.0, K.pal("tangerine"))
			draw_circle(r.position + Vector2(r.size.x - 18, r.size.y - 22), 5.0, K.pal("butter"))
		elif bool(m.breach):
			sub = "BREACH"
			draw_arc(r.position + Vector2(r.size.x - 18, r.size.y - 22), 8.0, 0, TAU, 12, K.pal("sky"), 3.0)
		elif bool(m.nopower):
			sub = "NO POWER"
		elif bool(m.warn):
			sub = "about to fail!"
		elif st >= 1:
			sub = ["", "rattling", "faulted", "FAILED"][st]
		if sub != "":
			draw_string(font, r.position + Vector2(4, 40), sub, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 14, K.pal("ink"))
		# conduit tag
		var ccut: bool = false
		if str(m.conduit) != "":
			var cd: Dictionary = cons.get(str(m.conduit), {})
			ccut = bool(cd.get("cut", false))
			draw_string(font, r.position + Vector2(4, r.size.y - 6), str(m.conduit).substr(2), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(ink, 0.6 if not ccut else 1.0))
		# repair progress
		var wprog: float = float(m.work)
		if wprog > 0.01:
			draw_rect(Rect2(r.position.x + 4, r.end.y - 14, (r.size.x - 8) * wprog, 5), K.pal("green"))
		if str(m.id) == pud_at:
			draw_circle(r.position + Vector2(r.size.x - 20, 16), 10.0, K.pal("pink"))
			draw_string(font, r.position + Vector2(r.size.x - 28, 21), "P", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
		if int(m.patched) > 0:
			draw_rect(Rect2(r.end.x - 16, r.position.y + 28, 12, 7), Color(0.7, 0.65, 0.5), true)
			draw_rect(Rect2(r.end.x - 16, r.position.y + 28, 12, 7), ink, false, 1.0)
