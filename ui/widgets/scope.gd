class_name Scope
extends Control
## Weapons' view down the barrel: a periscope onto a narrow slice of space. Things in the cone appear across it
## (left/right = angle off the barrel, size = how close). Unknown contacts are inky question marks.

var view: Dictionary = {}
var aim: float = 0.0
var firing: bool = false
var gun_ok: bool = true
var _bezel: Texture2D
var _stars: Array = []
var _tex: Dictionary = {}

const SPRITE: Dictionary = {
	"unknown": "obj_unknown", "target": "obj_target", "buoy": "obj_buoy", "drone": "obj_drone", "grabber": "obj_grabber",
	"mine": "obj_mine", "cruiser": "obj_cruiser", "patrol": "obj_patrol", "rock": "obj_rock", "junk": "obj_junk", "skip": "obj_skip",
	"pod": "obj_pod", "customs": "obj_customs", "haven": "obj_haven", "diner": "obj_diner",
}

func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(380, 380)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bezel = Art.tex("prop_scope", 1.4)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for i in 90:
		_stars.append([rng.randf() * TAU, rng.randf_range(-1.0, 1.0), rng.randf_range(1.0, 2.6)])

func _t(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = Art.tex(name, 0.9)
	return _tex[name]

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	var r: float = minf(size.x, size.y) / 2.0
	var c: Vector2 = size / 2.0
	var inner: float = r * 0.784
	draw_circle(c, inner, UIK.c("night"))
	draw_circle(c, inner * 0.7, Color(UIK.c("night2"), 0.6))
	var cone: float = float(view.get("cone", 0.42))
	var rng_max: float = float(view.get("range", 560.0))
	# stars slide past as the turret turns
	for st in _stars:
		var x: float = wrapf((float(st[0]) - aim) / cone * 0.5, -3.0, 3.0)
		var p: Vector2 = c + Vector2(x * inner, float(st[1]) * inner * 0.9)
		if p.distance_to(c) < inner - 4.0:
			draw_circle(p, float(st[2]), Color(UIK.c("cream"), 0.7))
	# contacts, far first
	var items: Array = view.get("view", []).duplicate()
	items.sort_custom(func(a, b): return float(a.dist) > float(b.dist))
	for it in items:
		var x2: float = clampf(float(it.rel) / cone, -1.1, 1.1)
		var near: float = 1.0 - clampf(float(it.dist) / rng_max, 0.0, 1.0)
		var px: float = (90.0 + 160.0 * near) * (float(it.r) / 24.0) * 0.5 + 18.0
		px = clampf(px, 26.0, inner * 1.2)
		var pos: Vector2 = c + Vector2(x2 * inner * 0.92, (0.25 - near * 0.45) * inner)
		var key: String = SPRITE.get(str(it.kind), "obj_unknown")
		var tex: Texture2D = _t(key)
		var asp: float = float(tex.get_height()) / float(tex.get_width())
		var sz: Vector2 = Vector2(px, px * asp)
		if pos.distance_to(c) > inner + sz.x * 0.2:
			continue
		draw_texture_rect(tex, Rect2(pos - sz / 2.0, sz), false)
		var f: Font = UIK.font("head")
		var d: String = "%dm" % int(it.dist)
		draw_string_outline(f, pos + Vector2(-16, sz.y / 2.0 + 18), d, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, UIK.ink())
		draw_string(f, pos + Vector2(-16, sz.y / 2.0 + 18), d, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UIK.c("cream"))
		if bool(it.get("weak", false)):
			draw_string_outline(f, pos + Vector2(-48, -sz.y / 2.0 - 6), "WEAK SPOT: BACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, UIK.ink())
			draw_string(f, pos + Vector2(-48, -sz.y / 2.0 - 6), "WEAK SPOT: BACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UIK.c("yellow"))
	# bullets flying away from us / at us
	for b in view.get("bullets", []):
		var x3: float = float(b.rel) / cone
		var near2: float = 1.0 - clampf(float(b.dist) / rng_max, 0.0, 1.0)
		var bp: Vector2 = c + Vector2(x3 * inner * 0.92, (0.25 - near2 * 0.45) * inner + near2 * inner * 0.6)
		if bp.distance_to(c) < inner:
			var bc: Color = UIK.c("yellow") if b.from == "us" else UIK.c("red")
			draw_circle(bp, 3.0 + near2 * 9.0, UIK.ink())
			draw_circle(bp, 1.5 + near2 * 7.0, bc)
	# crosshair
	var ch: Color = UIK.c("red") if gun_ok else UIK.c("grey")
	draw_arc(c, inner * 0.18, 0.0, TAU, 40, ch, 3.0, true)
	draw_line(c + Vector2(-inner, 0), c + Vector2(-inner * 0.24, 0), ch, 2.5, true)
	draw_line(c + Vector2(inner * 0.24, 0), c + Vector2(inner, 0), ch, 2.5, true)
	draw_line(c + Vector2(0, -inner), c + Vector2(0, -inner * 0.24), ch, 2.5, true)
	draw_line(c + Vector2(0, inner * 0.24), c + Vector2(0, inner), ch, 2.5, true)
	if firing and gun_ok and int(Time.get_ticks_msec() / 70) % 2 == 0:
		draw_circle(c + Vector2(0, inner * 0.7), 26.0, Color(UIK.c("yellow"), 0.7))
	if not gun_ok:
		var f2: Font = UIK.font("head")
		draw_string_outline(f2, c + Vector2(-92, -inner * 0.3), "GUN BROKEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 8, UIK.ink())
		draw_string(f2, c + Vector2(-92, -inner * 0.3), "GUN BROKEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UIK.c("red"))
	draw_texture_rect(_bezel, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)
