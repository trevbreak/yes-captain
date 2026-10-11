class_name Schematic
extends Control
## The ship's module grid for Damage Control. Click a cell to select it.

signal picked(id: String)

var mods: Array = []
var cons: Dictionary = {}
var selected: String = ""
var pud_at: String = ""
var t: float = 0.0
const CW: float = 102.0
const CH: float = 84.0

func _init() -> void:
	custom_minimum_size = Vector2(CW * 5.0 + 8.0, CH * 5.0 + 8.0)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _cell_rect(m: Dictionary) -> Rect2:
	return Rect2(4.0 + float(m.gx) * CW, 4.0 + float(m.gy) * CH, CW - 8.0, CH - 8.0)

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		for m in mods:
			if _cell_rect(m).has_point(ev.position):
				selected = str(m.id)
				picked.emit(selected)
				return

func _draw() -> void:
	var ink: Color = K.pal("ink")
	var fh: Font = UIK.font_head()
	var fb: Font = UIK.font_bold()
	# hull silhouette behind the grid
	draw_style_box(UIK.sb(K.pal("well"), 40, Color(0, 0, 0, 0), 0, 0), Rect2(CW * 0.4, 0, CW * 4.2, CH * 5.0 + 8.0))
	for m in mods:
		var r: Rect2 = _cell_rect(m)
		var st: int = int(m.state)
		var col: Color = [K.pal("card"), K.pal("yellow").lightened(0.3), K.pal("orange"), K.pal("red")][clampi(st, 0, 3)]
		if bool(m.fire):
			col = K.pal("red").lerp(K.pal("orange"), 0.5 + 0.5 * sin(t * 8.0))
		if bool(m.nopower):
			col = col.lerp(Color(0.6, 0.6, 0.66), 0.6)
		var sel: bool = str(m.id) == selected
		var s: StyleBoxFlat = UIK.sb(col, 12, K.pal("blue") if sel else col.darkened(0.2), 4 if sel else 2, 0)
		s.border_width_bottom = 5 if not sel else 4
		draw_style_box(s, r)
		var tc: Color = UIK.text_on(col)
		draw_string(fh, r.position + Vector2(6, 20), str(m.label), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 10, 14, tc)
		var sub: String = ""
		var ic: String = ""
		if bool(m.fire):
			sub = "FIRE!"
			ic = "fire"
		elif bool(m.breach):
			sub = "BREACH"
			ic = "warning"
		elif bool(m.nopower):
			sub = "no power"
			ic = "power"
		elif bool(m.warn):
			sub = "about to fail"
			ic = "warning"
		elif st >= 1:
			sub = ["", "rattling", "faulted", "FAILED"][st]
			ic = "dc" if st >= 2 else ""
		if sub != "":
			draw_string(fb, r.position + Vector2(6, 40), sub, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 10, 13, tc)
		if ic != "":
			var tex: Texture2D = UIK.icon(ic, 40)
			draw_texture_rect(tex, Rect2(r.end.x - 26, r.end.y - 26, 20, 20), false, tc)
		if str(m.conduit) != "":
			var cut: bool = bool(cons.get(str(m.conduit), {}).get("cut", false))
			draw_string(fb, Vector2(r.position.x + 6, r.end.y - 9), "cable " + str(m.conduit).substr(2).to_lower(), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 34, 11, Color(tc, 0.55) if not cut else K.pal("red").darkened(0.3))
		var wprog: float = float(m.work)
		if wprog > 0.01:
			draw_style_box(UIK.sb(K.pal("green"), 3, Color(0, 0, 0, 0), 0, 0), Rect2(r.position.x + 6, r.position.y + 46, (r.size.x - 12) * wprog, 6))
		if str(m.id) == pud_at:
			draw_texture_rect(UIK.portrait_tex("pudding", 64), Rect2(r.end.x - 34, r.position.y + 2, 30, 30), false)
		if int(m.patched) > 0:
			var tp: Rect2 = Rect2(r.end.x - 22, r.position.y + 26, 16, 8)
			draw_rect(tp, Color(0.78, 0.74, 0.6))
			draw_rect(tp, Color(0.55, 0.5, 0.4), false, 1.0)
