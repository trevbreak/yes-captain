class_name PuddingFace
extends Control
## Pudding: a fluffy glowing beanbag. Puffs up and goes red as its mood climbs.

var mood: float = 20.0
var loose: bool = false
var t: float = 0.0

func _init() -> void:
	custom_minimum_size = Vector2(150, 150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	var c: Vector2 = size * 0.5 + Vector2(0, 6)
	var ink: Color = K.pal("ink")
	var f: float = clampf(mood / 100.0, 0.0, 1.0)
	var puff: float = 1.0 + f * 0.25 + sin(t * (3.0 + f * 14.0)) * (0.02 + f * 0.04)
	var rr: float = minf(size.x, size.y) * 0.34 * puff
	var base: Color = K.pal("pink").lerp(K.pal("coral"), clampf((f - 0.5) * 2.0, 0.0, 1.0))
	if f > 0.8:
		draw_circle(c, rr + 12.0, Color(K.pal("coral"), 0.25 + 0.2 * sin(t * 12.0)))
	# fluff
	for i in 14:
		var a: float = float(i) / 14.0 * TAU
		draw_circle(c + Vector2.from_angle(a) * rr * 0.92, rr * 0.28, ink)
	for i in 14:
		var a2: float = float(i) / 14.0 * TAU
		draw_circle(c + Vector2.from_angle(a2) * rr * 0.92, rr * 0.22, base)
	draw_circle(c, rr * 0.95, base)
	# feet
	draw_circle(c + Vector2(-rr * 0.4, rr * 0.95), 8.0, ink)
	draw_circle(c + Vector2(rr * 0.4, rr * 0.95), 8.0, ink)
	# eyes
	var eye_open: float = 1.0 - clampf(f * 0.2, 0.0, 0.2)
	for sx in [-1.0, 1.0]:
		var ep: Vector2 = c + Vector2(sx * rr * 0.34, -rr * 0.1)
		draw_circle(ep, rr * 0.21, K.pal("white"))
		draw_arc(ep, rr * 0.21, 0, TAU, 20, ink, 2.0)
		draw_circle(ep + Vector2(sin(t * 0.8) * 2.0, 0), rr * 0.11 * (1.0 + f * 0.5) * eye_open, ink)
		draw_circle(ep + Vector2(-2, -3), rr * 0.04, K.pal("white"))
	# mouth
	var my: float = c.y + rr * 0.35
	if f < 0.35:
		draw_arc(Vector2(c.x, my - rr * 0.1), rr * 0.2, 0.3, PI - 0.3, 12, ink, 3.0)
	elif f < 0.7:
		draw_line(Vector2(c.x - rr * 0.14, my), Vector2(c.x + rr * 0.14, my), ink, 3.0)
	else:
		draw_arc(Vector2(c.x, my + rr * 0.12), rr * 0.17, PI + 0.4, TAU - 0.4, 12, ink, 3.0)
	if loose:
		draw_string(get_theme_default_font(), Vector2(0, 14), "LOOSE!", HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, K.pal("coral"))
