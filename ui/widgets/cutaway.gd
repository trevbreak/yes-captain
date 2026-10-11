class_name Cutaway
extends Control
## The ship drawn as a cutaway (nose to the right) with a stamp on every room: broken, on fire, hot, chewed.
## The Engineer clicks rooms to pick what to fix; the captain sees the same picture at a glance.

signal room_clicked(id: String)

const SHORT: Dictionary = {
	"bridge": "STEERING", "engine_p": "PORT ENG", "engine_s": "STAR ENG", "gun": "GUN", "shield": "SHIELD",
	"sensors": "SENSORS", "tractor": "TRACTOR", "reactor": "REACTOR", "pen": "PUDDING",
}
const LOCKED_BY: Dictionary = {"tractor": "tractor", "pen": "pudding"}

var systems: Dictionary = {}
var selected: String = ""
var prog: float = 0.0
var repairing: bool = false
var pudding_room: String = ""
var stuck: Array = []          # grabber relative angles
var hot: Dictionary = {}       # room -> 0..1 heat
var blackout: bool = false
var clickable: bool = false
var features: Dictionary = {}
var _tex: Texture2D
var _flame: Texture2D
var _pud: Texture2D
var _grab: Texture2D
var _rooms: Dictionary = {}
var _hover: String = ""

func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(360, 210)
	_tex = Art.tex("ship_cutaway", 1.2)
	_flame = Art.tex("fx_flame", 1.0)
	_pud = Art.tex("obj_pudding", 1.0)
	_grab = Art.tex("obj_grabber", 0.8)
	var th: Variant = Art.layout("things")
	if th is Dictionary:
		_rooms = th.get("cutaway", {}).get("rooms", {})
	mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
	if clickable:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _process(_dt: float) -> void:
	queue_redraw()

func _frame() -> Rect2:
	var asp: float = 720.0 / 420.0
	var w: float = size.x
	var h: float = w / asp
	if h > size.y:
		h = size.y
		w = h * asp
	return Rect2((size - Vector2(w, h)) / 2.0, Vector2(w, h))

func room_rect(id: String) -> Rect2:
	var fr: Rect2 = _frame()
	var k: float = fr.size.x / 720.0
	var r: Array = _rooms.get(id, [0, 0, 0, 0])
	return Rect2(fr.position + Vector2(float(r[0]), float(r[1])) * k, Vector2(float(r[2]), float(r[3])) * k)

func _visible_room(id: String) -> bool:
	return not LOCKED_BY.has(id) or bool(features.get(LOCKED_BY[id], false))

func _room_at(p: Vector2) -> String:
	for id in _rooms.keys():
		if _visible_room(id) and room_rect(id).grow(4.0).has_point(p):
			return id
	return ""

func _gui_input(e: InputEvent) -> void:
	if not clickable:
		return
	if e is InputEventMouseMotion:
		var h: String = _room_at(e.position)
		if h != _hover:
			_hover = h
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var id: String = _room_at(e.position)
		if id != "":
			room_clicked.emit(id)
			UIK.sfx("blip")
		accept_event()

func _stamp(c: Vector2, text: String, col: Color, rot: float, fs: int) -> void:
	var f: Font = UIK.font("head")
	var ts: Vector2 = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_set_transform(c, rot, Vector2.ONE)
	var r: Rect2 = Rect2(Vector2(-ts.x / 2.0 - 7.0, -ts.y / 2.0 - 2.0), Vector2(ts.x + 14.0, ts.y + 4.0))
	draw_rect(r, Color(UIK.c("cream"), 0.85))
	draw_rect(r, col, false, 3.0)
	draw_string(f, Vector2(-ts.x / 2.0, ts.y * 0.32), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _compact(rr: Rect2, state: String, st: Dictionary, id: String) -> void:
	## small ship board (the captain's): icons that always fit inside the room
	var c: Vector2 = rr.get_center()
	var r: float = minf(rr.size.x, rr.size.y) * 0.32
	var t: float = Time.get_ticks_msec() / 1000.0
	if state == "fire":
		draw_rect(rr.grow(-2.0), Color(UIK.c("red"), 0.3 + 0.15 * sin(t * 8.0)))
		var fsz: float = minf(rr.size.x, rr.size.y) * 0.8
		draw_texture_rect(_flame, Rect2(c - Vector2(fsz * 0.4, fsz * 0.5), Vector2(fsz * 0.8, fsz)), false)
	elif state == "broken":
		draw_rect(rr.grow(-2.0), Color(UIK.c("red"), 0.18))
		draw_circle(c, r, UIK.ink())
		draw_circle(c, r - 2.5, UIK.c("red"))
		var k: float = r * 0.45
		draw_line(c + Vector2(-k, -k), c + Vector2(k, k), UIK.c("cream"), 3.0, true)
		draw_line(c + Vector2(k, -k), c + Vector2(-k, k), UIK.c("cream"), 3.0, true)
	else:
		var heat: float = float(hot.get(id, 0.0))
		if heat > 0.7:
			draw_circle(c, r, UIK.ink())
			draw_circle(c, r - 2.5, UIK.c("orange") if heat < 0.9 else UIK.c("red"))
		elif float(st.get("hp", 100.0)) < 100.0:
			var w: float = rr.size.x * 0.7
			draw_rect(Rect2(c.x - w / 2.0, c.y + r * 0.6, w, 6.0), Color(UIK.ink(), 0.3))
			draw_rect(Rect2(c.x - w / 2.0, c.y + r * 0.6, w * float(st.get("hp", 100.0)) / 100.0, 6.0), UIK.c("mustard"))

func _draw() -> void:
	var fr: Rect2 = _frame()
	draw_texture_rect(_tex, fr, false)
	var k: float = fr.size.x / 720.0
	var f: Font = UIK.font("head")
	var fs: int = int(clampf(13.0 * k * 1.25, 10.0, 17.0))
	var t: float = Time.get_ticks_msec() / 1000.0
	for id in _rooms.keys():
		var rr: Rect2 = room_rect(id)
		if not _visible_room(id):
			draw_rect(rr.grow(-3.0), Color(UIK.c("grey"), 0.55))
			continue
		var st: Dictionary = systems.get(id, {"state": "ok", "hp": 100.0})
		var state: String = str(st.get("state", "ok"))
		var lbl: String = SHORT.get(id, id)
		if f.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x < rr.size.x - 10.0:
			draw_string(f, rr.position + Vector2(6, fs + 3), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UIK.ink(), 0.8))
		var c: Vector2 = rr.get_center() + Vector2(0, fs * 0.4)
		if rr.size.x < 90.0:
			_compact(rr, state, st, id)
		elif state == "fire":
			draw_rect(rr.grow(-3.0), Color(UIK.c("red"), 0.25 + 0.15 * sin(t * 8.0)))
			var fsz: float = minf(rr.size.x, rr.size.y) * (0.72 + 0.06 * sin(t * 11.0 + rr.position.x))
			draw_texture_rect(_flame, Rect2(c - Vector2(fsz * 0.42, fsz * 0.55), Vector2(fsz * 0.84, fsz)), false)
		elif state == "broken":
			_stamp(c, "BROKEN", UIK.c("red"), -0.12, int(fs * 1.35))
		else:
			var hp: float = float(st.get("hp", 100.0))
			var heat: float = float(hot.get(id, 0.0))
			if heat > 0.7:
				_stamp(c, "HOT!" if heat < 0.9 else "SO HOT!", UIK.c("orange"), 0.1, int(fs * 1.3))
			elif hp < 100.0:
				var w: float = rr.size.x * 0.7
				draw_rect(Rect2(c.x - w / 2.0, c.y + 4.0, w, 9.0), Color(UIK.ink(), 0.3))
				draw_rect(Rect2(c.x - w / 2.0, c.y + 4.0, w * hp / 100.0, 9.0), UIK.c("mustard"))
				draw_rect(Rect2(c.x - w / 2.0, c.y + 4.0, w, 9.0), UIK.ink(), false, 2.0)
		if id == pudding_room:
			var ps: float = minf(rr.size.x, rr.size.y) * 0.62
			var bob: float = sin(t * 6.0) * 4.0
			draw_texture_rect(_pud, Rect2(Vector2(rr.end.x - ps * 1.02, rr.position.y + ps * 0.08 + bob), Vector2(ps, ps * 0.89)), false)
		if id == selected:
			draw_rect(rr.grow(2.0), UIK.c("yellow"), false, 5.0)
			if repairing or prog > 0.0:
				var w2: float = rr.size.x - 12.0
				draw_rect(Rect2(rr.position.x + 6.0, rr.end.y - 16.0, w2, 10.0), Color(UIK.ink(), 0.4))
				draw_rect(Rect2(rr.position.x + 6.0, rr.end.y - 16.0, w2 * prog, 10.0), UIK.c("green"))
		elif id == _hover and clickable:
			draw_rect(rr.grow(1.0), Color(UIK.c("yellow"), 0.7), false, 3.0)
	# grabbers stuck on the hull (the drawing faces right: angle 0 = nose)
	var hc: Vector2 = fr.get_center()
	for rel in stuck:
		var p: Vector2 = hc + Vector2(cos(float(rel)) * fr.size.x * 0.47, sin(float(rel)) * fr.size.y * 0.47)
		var gs: float = 40.0 * k * 1.4
		draw_texture_rect(_grab, Rect2(p - Vector2(gs, gs) / 2.0, Vector2(gs, gs)), false)
	if blackout:
		draw_rect(fr, Color(0.05, 0.04, 0.08, 0.55))
		_stamp(fr.get_center(), "BLACKOUT", UIK.c("yellow"), -0.08, 34)
