class_name Models
extends RefCounted
## Chunky low-poly toy models built from primitives, with a 3-band toon shader and ink outlines.

const TOON: String = """
shader_type spatial;
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 glow : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float glow_amount = 0.0;
void fragment() {
	ALBEDO = albedo.rgb;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = glow.rgb * glow_amount + albedo.rgb * rim * 0.25;
}
void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float band = floor(nl * 3.0 + 0.5) / 3.0;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * band * 0.9;
}
"""

const OUTLINE: String = """
shader_type spatial;
render_mode cull_front, unshaded;
uniform float width = 0.1;
uniform vec4 color : source_color = vec4(0.18, 0.16, 0.23, 1.0);
void vertex() {
	VERTEX += NORMAL * width;
}
void fragment() {
	ALBEDO = color.rgb;
}
"""

const GLOWSH: String = """
shader_type spatial;
render_mode unshaded;
uniform vec4 color : source_color = vec4(1.0);
uniform float alpha = 1.0;
void fragment() {
	ALBEDO = color.rgb;
	ALPHA = alpha;
}
"""

static var _toon: Shader = null
static var _outline: Shader = null
static var _glow: Shader = null

static func shaders() -> void:
	if _toon == null:
		_toon = Shader.new()
		_toon.code = TOON
		_outline = Shader.new()
		_outline.code = OUTLINE
		_glow = Shader.new()
		_glow.code = GLOWSH

static func toon_mat(color: Color, outline_w: float = 0.1, glow: float = 0.0) -> ShaderMaterial:
	shaders()
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _toon
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("glow", color)
	m.set_shader_parameter("glow_amount", glow)
	if outline_w > 0.0:
		var o: ShaderMaterial = ShaderMaterial.new()
		o.shader = _outline
		o.set_shader_parameter("width", outline_w)
		m.next_pass = o
	return m

static func glow_mat(color: Color, alpha: float = 1.0) -> ShaderMaterial:
	shaders()
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _glow
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("alpha", alpha)
	if alpha < 1.0:
		m.render_priority = 5
	return m

static func mi(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO, outline: float = 0.08, glow: float = 0.0) -> MeshInstance3D:
	var n: MeshInstance3D = MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = toon_mat(color, outline, glow)
	n.position = pos
	n.scale = scl
	n.rotation = rot
	parent.add_child(n)
	return n

static func sphere(seg: int = 10, rings: int = 6) -> SphereMesh:
	var s: SphereMesh = SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = seg
	s.rings = rings
	return s

static func box(sx: float = 1.0, sy: float = 1.0, sz: float = 1.0) -> BoxMesh:
	var b: BoxMesh = BoxMesh.new()
	b.size = Vector3(sx, sy, sz)
	return b

static func cyl(rt: float = 1.0, rb: float = 1.0, h: float = 1.0, seg: int = 12) -> CylinderMesh:
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c

static func torus(inner: float, outer: float, seg: int = 24, rings: int = 8) -> TorusMesh:
	var t: TorusMesh = TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.ring_segments = seg
	t.rings = rings
	return t

static func capsule(r: float = 0.5, h: float = 2.0) -> CapsuleMesh:
	var c: CapsuleMesh = CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 8
	c.rings = 3
	return c

static func marker(parent: Node3D, text: String, color: Color, y: float, size: float = 0.0011) -> Label3D:
	var l: Label3D = Label3D.new()
	l.text = text
	l.modulate = color
	l.outline_modulate = K.pal("ink")
	l.outline_size = 10
	l.font = UIK.font()
	l.font_size = 40
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = size
	l.no_depth_test = true
	l.position = Vector3(0, y, 0)
	parent.add_child(l)
	return l

static func build(kind: String, r: float, name: String = "", extra: Dictionary = {}) -> Node3D:
	var root: Node3D = Node3D.new()
	var ow: float = maxf(0.05, r * 0.045)
	var pal: Callable = K.pal
	match kind:
		"asteroid":
			var m: MeshInstance3D = mi(root, sphere(8, 5), pal.call("rock"), Vector3.ZERO, Vector3(r, r * 0.8, r * 0.9), Vector3.ZERO, ow)
			mi(root, sphere(6, 4), pal.call("rock").darkened(0.15), Vector3(r * 0.5, r * 0.3, r * 0.2), Vector3.ONE * r * 0.45, Vector3.ZERO, ow)
			mi(root, sphere(6, 4), pal.call("rock").lightened(0.1), Vector3(-r * 0.4, -r * 0.2, r * 0.4), Vector3.ONE * r * 0.35, Vector3.ZERO, ow)
		"mine":
			mi(root, sphere(8, 5), pal.call("coral"), Vector3.ZERO, Vector3.ONE * r, Vector3.ZERO, ow)
			for i in 6:
				var d: Vector3 = [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK][i]
				mi(root, cyl(0.0, 0.35, 0.9, 6), pal.call("butter"), d * r * 1.15, Vector3.ONE * r, Vector3(d.z * PI / 2.0, 0, -d.x * PI / 2.0) if d.y == 0.0 else (Vector3(PI, 0, 0) if d.y < 0 else Vector3.ZERO), ow)
			marker(root, "!", pal.call("coral"), r * 2.0)
		"grabber":
			mi(root, sphere(10, 6), pal.call("gunmetal"), Vector3.ZERO, Vector3(r, r * 0.8, r), Vector3.ZERO, ow)
			mi(root, torus(0.82, 1.0, 16, 6), pal.call("gold"), Vector3.ZERO, Vector3.ONE * r * 1.05, Vector3(PI / 2.0, 0, 0), ow)
			for s in [-1.0, 1.0]:
				mi(root, box(1.4, 0.3, 0.3), pal.call("magenta"), Vector3(r * 0.9, 0, s * r * 0.9), Vector3.ONE * r * 0.8, Vector3(0, s * 0.5, 0), ow)
				mi(root, box(0.4, 0.3, 0.9), pal.call("magenta"), Vector3(r * 1.6, 0, s * r * 0.55), Vector3.ONE * r * 0.8, Vector3(0, s * -0.6, 0), ow)
			mi(root, sphere(6, 4), pal.call("coral"), Vector3(r * 0.85, r * 0.2, 0), Vector3.ONE * r * 0.28, Vector3.ZERO, ow * 0.5, 1.0)
			marker(root, "▼", pal.call("coral"), r * 2.4)
		"snatch":
			mi(root, box(2.2, 1.1, 1.5), pal.call("gunmetal"), Vector3.ZERO, Vector3.ONE * r * 0.8, Vector3.ZERO, ow)
			mi(root, cyl(0.6, 0.6, 1.0, 8), pal.call("mint"), Vector3(r * 0.9, 0, 0), Vector3.ONE * r * 0.9, Vector3(0, 0, PI / 2.0), ow)
			mi(root, box(0.15, 1.2, 1.5), pal.call("gold"), Vector3(-r * 0.4, 0, 0), Vector3.ONE * r * 0.8, Vector3.ZERO, ow)
			marker(root, "▼", pal.call("coral"), r * 2.4)
		"patrol":
			mi(root, box(2.4, 0.9, 1.1), pal.call("gunmetal"), Vector3.ZERO, Vector3.ONE * r * 0.9, Vector3.ZERO, ow)
			mi(root, box(1.2, 0.5, 0.8), pal.call("gunmetal2"), Vector3(-r * 0.2, r * 0.7, 0), Vector3.ONE * r * 0.9, Vector3.ZERO, ow)
			mi(root, box(2.5, 0.12, 0.2), pal.call("gold"), Vector3(0, r * 0.42, r * 0.6), Vector3.ONE * r * 0.9, Vector3.ZERO, ow)
			mi(root, box(2.5, 0.12, 0.2), pal.call("gold"), Vector3(0, r * 0.42, -r * 0.6), Vector3.ONE * r * 0.9, Vector3.ZERO, ow)
			mi(root, cyl(0.45, 0.45, 0.12, 14), pal.call("gold"), Vector3(r * 0.3, r * 0.2, r * 0.62), Vector3.ONE * r * 0.7, Vector3(PI / 2.0, 0, 0), ow)
			mi(root, sphere(8, 5), pal.call("pink"), Vector3(r * 0.3, r * 0.2, r * 0.75), Vector3.ONE * r * 0.18, Vector3.ZERO, ow)
			for s2 in [-1.0, 1.0]:
				mi(root, box(0.1, 0.9, 0.5), pal.call("magenta"), Vector3(-r * 0.5, 0, s2 * r * 0.5), Vector3.ONE * r * 0.9, Vector3.ZERO, ow)
				mi(root, cyl(0.28, 0.35, 0.5, 10), pal.call("tangerine"), Vector3(-r * 1.15, 0, s2 * r * 0.3), Vector3.ONE * r * 0.7, Vector3(0, 0, PI / 2.0), ow, 0.8)
			marker(root, "▼", pal.call("coral"), r * 1.8)
		"bastion":
			mi(root, box(3.2, 0.9, 1.3), pal.call("gunmetal"), Vector3.ZERO, Vector3.ONE * r * 0.7, Vector3.ZERO, ow)
			mi(root, box(1.3, 0.8, 0.9), pal.call("gunmetal2"), Vector3(-r * 0.2, r * 0.6, 0), Vector3.ONE * r * 0.7, Vector3.ZERO, ow)
			for s3 in [-1.0, 1.0]:
				mi(root, box(3.2, 0.1, 0.18), pal.call("gold"), Vector3(0, r * 0.32, s3 * r * 0.45), Vector3.ONE * r * 0.7, Vector3.ZERO, ow)
				mi(root, box(0.8, 0.5, 0.35), pal.call("magenta"), Vector3(r * 0.2, r * 0.0, s3 * r * 0.9), Vector3.ONE * r * 0.7, Vector3.ZERO, ow)
				mi(root, cyl(0.15, 0.15, 1.2, 8), pal.call("gold"), Vector3(r * 0.9, r * 0.0, s3 * r * 0.9), Vector3.ONE * r * 0.7, Vector3(0, 0, PI / 2.0), ow)
			# the Overlord's face on the prow
			mi(root, sphere(10, 7), pal.call("gold"), Vector3(r * 0.85, r * 0.1, 0), Vector3.ONE * r * 0.38, Vector3.ZERO, ow)
			for s4 in [-1.0, 1.0]:
				mi(root, sphere(6, 4), pal.call("white"), Vector3(r * 1.15, r * 0.2, s4 * r * 0.14), Vector3.ONE * r * 0.09, Vector3.ZERO, ow * 0.6)
			# weak spot: glowing rear vent
			var vent: MeshInstance3D = mi(root, cyl(0.2, 0.3, 0.3, 8), pal.call("coral"), Vector3(-r * 0.85, 0, 0), Vector3.ONE * r * 0.5, Vector3(0, 0, PI / 2.0), ow, 1.0)
			vent.name = "vent"
			marker(root, "▼", pal.call("coral"), r * 1.4)
		"magnificence":
			mi(root, sphere(14, 9), pal.call("gold"), Vector3.ZERO, Vector3.ONE * r, Vector3.ZERO, ow)
			mi(root, cyl(0.0, 0.25, 0.7, 6), pal.call("gold").lightened(0.1), Vector3(r * 0.95, -r * 0.05, 0), Vector3.ONE * r, Vector3(0, 0, -PI / 2.0), ow)
			for s5 in [-1.0, 1.0]:
				mi(root, sphere(8, 6), pal.call("white"), Vector3(r * 0.82, r * 0.3, s5 * r * 0.3), Vector3.ONE * r * 0.17, Vector3.ZERO, ow)
				mi(root, sphere(6, 4), pal.call("ink"), Vector3(r * 0.97, r * 0.3, s5 * r * 0.3), Vector3.ONE * r * 0.07, Vector3.ZERO, ow * 0.4)
				mi(root, sphere(6, 4), pal.call("ink"), Vector3(r * 0.85, r * 0.12, s5 * r * 0.55), Vector3(r * 0.07, r * 0.07, r * 0.28), Vector3.ZERO, ow * 0.4)
				mi(root, cyl(0.0, 0.12, 0.5, 6), pal.call("magenta"), Vector3(r * 0.2, r * 0.95, s5 * r * 0.35), Vector3.ONE * r, Vector3.ZERO, ow)
			mi(root, cyl(0.0, 0.15, 0.6, 6), pal.call("magenta"), Vector3(r * 0.2, r * 1.0, 0), Vector3.ONE * r, Vector3.ZERO, ow)
			mi(root, torus(0.15, 0.5, 20, 6), pal.call("gold").darkened(0.1), Vector3(r * 0.85, -r * 0.35, 0), Vector3(r * 0.5, r * 0.3, r * 0.9), Vector3(PI / 2.0, 0, -PI / 2.0), ow)
			marker(root, "THE MAGNIFICENCE", pal.call("magenta"), r * 1.4)
		"freighter":
			mi(root, capsule(0.5, 2.6), pal.call("tangerine"), Vector3.ZERO, Vector3.ONE * r, Vector3(0, 0, PI / 2.0), ow)
			mi(root, box(0.8, 0.5, 0.9), pal.call("mint"), Vector3(r * 0.5, r * 0.45, 0), Vector3.ONE * r * 0.7, Vector3.ZERO, ow)
		"diner":
			mi(root, torus(r * 0.82, r, 28, 10), pal.call("coral"), Vector3.ZERO, Vector3(1, 1.0, 1), Vector3.ZERO, ow)
			mi(root, torus(r * 0.9, r * 0.97, 28, 6), pal.call("butter"), Vector3(0, 0, 0), Vector3(1, 1.8, 1), Vector3.ZERO, ow * 0.5)
			mi(root, sphere(12, 8), pal.call("mint"), Vector3.ZERO, Vector3.ONE * r * 0.45, Vector3.ZERO, ow)
			mi(root, cyl(0.0, 0.5, 0.9, 6), pal.call("pink"), Vector3(0, r * 0.5, 0), Vector3.ONE * r * 0.4, Vector3.ZERO, ow)
			for i in 8:
				var a: float = float(i) / 8.0 * TAU
				mi(root, box(0.1, 0.1, 0.1), pal.call("butter"), Vector3(cos(a) * r * 0.9, r * 0.12, sin(a) * r * 0.9), Vector3.ONE * r * 0.6, Vector3.ZERO, ow, 1.0)
			var dl: MeshInstance3D = mi(root, sphere(8, 5), pal.call("butter"), Vector3(r + 7.5, 0, 0), Vector3.ONE * 3.5, Vector3.ZERO, 0.1, 1.0)
			dl.name = "dock"
			marker(root, "MA GRISTLE'S DINER", pal.call("butter"), r * 1.1)
		"skip":
			var special: bool = bool(extra.get("special", false))
			mi(root, box(2.0, 1.4, 1.4), pal.call("pink") if special else pal.call("mint"), Vector3.ZERO, Vector3.ONE * r * 0.8, Vector3.ZERO, ow, 0.4 if special else 0.0)
			mi(root, box(2.1, 0.2, 1.5), pal.call("gunmetal2"), Vector3(0, r * 0.62, 0), Vector3.ONE * r * 0.8, Vector3.ZERO, ow)
			if special:
				marker(root, "WARM (purring)", pal.call("pink"), r * 2.2)
			else:
				marker(root, "SKIP", pal.call("mint"), r * 2.0, 0.0009)
		"pod":
			mi(root, capsule(0.5, 1.8), pal.call("lilac"), Vector3.ZERO, Vector3.ONE * r, Vector3(0, 0, PI / 2.0), ow)
			mi(root, sphere(8, 5), pal.call("sky"), Vector3(r * 0.5, r * 0.3, 0), Vector3.ONE * r * 0.35, Vector3.ZERO, ow)
		"waypoint":
			mi(root, torus(r * 0.92, r, 30, 6), pal.call("green"), Vector3.ZERO, Vector3.ONE, Vector3(PI / 2.0, 0, 0), ow * 0.5, 1.0)
			mi(root, torus(r * 0.55, r * 0.6, 24, 6), pal.call("butter"), Vector3.ZERO, Vector3.ONE, Vector3(PI / 2.0, 0, 0), ow * 0.3, 1.0)
			mi(root, cyl(0.0, 0.4, 2.0, 6), pal.call("green"), Vector3(0, r * 0.9, 0), Vector3.ONE * r * 0.35, Vector3(PI, 0, 0), ow * 0.5, 1.0)
			marker(root, "◎ " + (name if name != "" else "WAYPOINT"), pal.call("green"), r * 1.6)
		"beacon":
			mi(root, cyl(0.6, 0.9, 1.6, 8), pal.call("pink"), Vector3.ZERO, Vector3.ONE * r, Vector3.ZERO, ow)
			mi(root, sphere(6, 4), pal.call("butter"), Vector3(0, r * 1.2, 0), Vector3.ONE * r * 0.5, Vector3.ZERO, ow, 1.0)
		"debris":
			if name.begins_with("Rubber"):
				mi(root, sphere(8, 5), pal.call("butter"), Vector3.ZERO, Vector3.ONE * r, Vector3.ZERO, ow)
				mi(root, cyl(0.0, 0.5, 1.0, 6), pal.call("tangerine"), Vector3(r * 0.9, 0, 0), Vector3.ONE * r * 0.5, Vector3(0, 0, -PI / 2.0), ow)
			elif name.begins_with("Wedding"):
				mi(root, cyl(1.0, 1.0, 0.7, 10), pal.call("white"), Vector3.ZERO, Vector3.ONE * r, Vector3.ZERO, ow)
				mi(root, cyl(0.7, 0.7, 0.6, 10), pal.call("pink"), Vector3(0, r * 0.6, 0), Vector3.ONE * r, Vector3.ZERO, ow)
				mi(root, cyl(0.4, 0.4, 0.5, 10), pal.call("white"), Vector3(0, r * 1.1, 0), Vector3.ONE * r, Vector3.ZERO, ow)
			else:
				mi(root, box(1.0, 1.0, 1.0), pal.call("butter"), Vector3.ZERO, Vector3.ONE * r, Vector3.ZERO, ow)
		"bullet":
			mi(root, capsule(0.18, 1.4), pal.call("butter"), Vector3.ZERO, Vector3.ONE * 2.2, Vector3(0, 0, PI / 2.0), 0.0, 1.0)
		"ebullet":
			mi(root, sphere(6, 4), pal.call("coral"), Vector3.ZERO, Vector3.ONE * 1.4, Vector3.ZERO, 0.0, 1.0)
		"eshell":
			mi(root, sphere(8, 5), pal.call("tangerine"), Vector3.ZERO, Vector3.ONE * 3.0, Vector3.ZERO, 0.2, 1.0)
			mi(root, sphere(8, 5), pal.call("butter"), Vector3.ZERO, Vector3.ONE * 1.8, Vector3.ZERO, 0.0, 1.0)
		"torp":
			mi(root, capsule(0.5, 3.0), pal.call("tangerine"), Vector3.ZERO, Vector3.ONE * 1.6, Vector3(0, 0, PI / 2.0), 0.15)
			mi(root, sphere(6, 4), pal.call("butter"), Vector3(-2.2, 0, 0), Vector3.ONE * 0.9, Vector3.ZERO, 0.0, 1.0)
		_:
			mi(root, sphere(8, 5), pal.call("lilac"), Vector3.ZERO, Vector3.ONE * r, Vector3.ZERO, ow)
	return root
