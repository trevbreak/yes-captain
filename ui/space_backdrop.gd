class_name SpaceBackdrop
extends Control
## Night-sky gradient with soft nebula glows and twinkling stars. Used behind menus and screens.

static var _glow: Texture2D = null
var stars: Array = []
var puffs: Array = []
var t: float = 0.0

static func glow_tex() -> Texture2D:
	if _glow == null:
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.35))
		var gt: GradientTexture2D = GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 256
		gt.height = 256
		_glow = gt
	return _glow

func _ready() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	for i in 150:
		stars.append([rng.randf(), rng.randf(), rng.randf_range(0.8, 2.3), rng.randf() * TAU])
	var cols: Array = [K.pal("purple"), K.pal("blue"), K.pal("pink"), K.pal("sensors"), K.pal("purple")]
	for j in 5:
		puffs.append([rng.randf(), rng.randf(), rng.randf_range(260.0, 520.0), cols[j % cols.size()]])
	set_process(true)

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	var top: Color = K.pal("night")
	var bot: Color = K.pal("night2")
	var n: int = 32
	for i in n:
		var y0: float = size.y * float(i) / n
		draw_rect(Rect2(0, y0, size.x, size.y / n + 1.0), top.lerp(bot, float(i) / (n - 1)))
	var gt: Texture2D = glow_tex()
	for p in puffs:
		var cpos: Vector2 = Vector2(float(p[0]) * size.x, float(p[1]) * size.y)
		var r: float = float(p[2])
		draw_texture_rect(gt, Rect2(cpos - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(p[3], 0.16))
	for s in stars:
		var a: float = 0.3 + 0.7 * absf(sin(t * 0.9 + float(s[3])))
		draw_circle(Vector2(float(s[0]) * size.x, float(s[1]) * size.y), float(s[2]), Color(1, 1, 1, a * 0.8))
