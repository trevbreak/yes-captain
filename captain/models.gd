class_name Models
extends RefCounted
## Chunky, rounded, toy-like models (Two Point style): soft wrap lighting, gentle rim light,
## thin tinted outlines, and rounded boxes (superellipsoids) instead of sharp cubes.

const SOFT: String = """
shader_type spatial;
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 glow : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float glow_amount = 0.0;
uniform float rim_amount = 0.22;
void fragment() {
	ALBEDO = albedo.rgb;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	EMISSION = glow.rgb * glow_amount + mix(albedo.rgb, vec3(1.0), 0.4) * rim * rim_amount;
	ROUGHNESS = 0.7;
}
void light() {
	float nl = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float diff = smoothstep(0.15, 1.0, nl);
	// LIGHT_COLOR already includes energy * PI
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * diff / PI;
	vec3 h = normalize(LIGHT + VIEW);
	float spec = pow(clamp(dot(NORMAL, h), 0.0, 1.0), 28.0) * 0.25;
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * spec / PI;
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

static var _soft: Shader = null
static var _outline: Shader = null
static var _glow: Shader = null
static var _meshes: Dictionary = {}

static func shaders() -> void:
	if _soft == null:
		_soft = Shader.new()
		_soft.code = SOFT
		_outline = Shader.new()
		_outline.code = OUTLINE
		_glow = Shader.new()
		_glow.code = GLOWSH

static func toon_mat(color: Color, outline_w: float = 0.1, glow: float = 0.0) -> ShaderMaterial:
	shaders()
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _soft
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("glow", color)
	m.set_shader_parameter("glow_amount", glow)
	if outline_w > 0.0:
		var o: ShaderMaterial = ShaderMaterial.new()
		o.shader = _outline
		o.set_shader_parameter("width", outline_w)
		o.set_shader_parameter("color", color.darkened(0.55))
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

# ---------------------------------------------------------------- primitives

static func sphere(seg: int = 16, rings: int = 10) -> SphereMesh:
	var s: SphereMesh = SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = seg
	s.rings = rings
	return s

static func box(sx: float = 1.0, sy: float = 1.0, sz: float = 1.0) -> Mesh:
	return rbox(Vector3(sx, sy, sz), 0.35)

static func cyl(rt: float = 1.0, rb: float = 1.0, h: float = 1.0, seg: int = 16) -> CylinderMesh:
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c

static func torus(inner: float, outer: float, seg: int = 32, rings: int = 12) -> TorusMesh:
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
	c.radial_segments = 16
	c.rings = 6
	return c

static func _sgnpow(v: float, e: float) -> float:
	return signf(v) * pow(absf(v), e)

static func rbox(size: Vector3, roundness: float = 0.3, seg: int = 18) -> ArrayMesh:
	## Superellipsoid: a box with rounded edges. roundness 0 = sharp box, 1 = ellipsoid.
	var key: String = "%s|%.2f|%d" % [str(size), roundness, seg]
	if _meshes.has(key):
		return _meshes[key]
	var e: float = clampf(roundness, 0.08, 1.0)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a: Vector3 = size * 0.5
	var rings: int = seg
	var cols: int = seg * 2
	for i in rings + 1:
		var v: float = -PI / 2.0 + PI * float(i) / rings
		for j in cols + 1:
			var u: float = -PI + TAU * float(j) / cols
			var cv: float = cos(v)
			var sv: float = sin(v)
			var cu: float = cos(u)
			var su: float = sin(u)
			var p: Vector3 = Vector3(a.x * _sgnpow(cv, e) * _sgnpow(cu, e), a.y * _sgnpow(sv, e), a.z * _sgnpow(cv, e) * _sgnpow(su, e))
			var n: Vector3 = Vector3(_sgnpow(cv, 2.0 - e) * _sgnpow(cu, 2.0 - e) / a.x, _sgnpow(sv, 2.0 - e) / a.y, _sgnpow(cv, 2.0 - e) * _sgnpow(su, 2.0 - e) / a.z)
			if n.length() < 0.0001:
				n = Vector3(0, signf(sv) if sv != 0.0 else 1.0, 0)
			st.set_normal(n.normalized())
			st.add_vertex(p)
	for i2 in rings:
		for j2 in cols:
			var a0: int = i2 * (cols + 1) + j2
			var b0: int = a0 + cols + 1
			# Godot front faces wind clockwise when seen from outside
			st.add_index(a0)
			st.add_index(a0 + 1)
			st.add_index(b0)
			st.add_index(a0 + 1)
			st.add_index(b0 + 1)
			st.add_index(b0)
	var mesh: ArrayMesh = st.commit()
	_meshes[key] = mesh
	return mesh

static func marker(parent: Node3D, text: String, color: Color, y: float, size: float = 0.0011) -> Label3D:
	var l: Label3D = Label3D.new()
	l.text = text
	l.modulate = color
	l.outline_modulate = K.pal("night")
	l.outline_size = 12
	l.font = UIK.font_head()
	l.font_size = 40
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = size
	l.no_depth_test = true
	l.position = Vector3(0, y, 0)
	parent.add_child(l)
	return l

static func windows(parent: Node3D, origin: Vector3, count: int, spacing: float, size: float, color: Color = Color("#fff3b0")) -> void:
	for i in count:
		mi(parent, sphere(8, 6), color, origin + Vector3(float(i) * spacing, 0, 0), Vector3(size, size * 0.6, size * 0.4), Vector3.ZERO, 0.0, 1.2)

# ---------------------------------------------------------------- models

static func build(kind: String, r: float, name: String = "", extra: Dictionary = {}) -> Node3D:
	var root: Node3D = Node3D.new()
	var ow: float = maxf(0.04, r * 0.03)
	var pal: Callable = K.pal
	match kind:
		"asteroid":
			mi(root, sphere(12, 8), pal.call("rock"), Vector3.ZERO, Vector3(r, r * 0.8, r * 0.9), Vector3.ZERO, ow)
			mi(root, sphere(10, 6), pal.call("rock").darkened(0.12), Vector3(r * 0.5, r * 0.3, r * 0.2), Vector3.ONE * r * 0.45, Vector3.ZERO, ow)
			mi(root, sphere(10, 6), pal.call("rock").lightened(0.08), Vector3(-r * 0.4, -r * 0.2, r * 0.4), Vector3.ONE * r * 0.35, Vector3.ZERO, ow)
			mi(root, sphere(8, 6), pal.call("rock").darkened(0.25), Vector3(r * 0.1, r * 0.55, -r * 0.3), Vector3.ONE * r * 0.18, Vector3.ZERO, 0.0)
		"mine":
			mi(root, sphere(14, 10), pal.call("red"), Vector3.ZERO, Vector3.ONE * r, Vector3.ZERO, ow)
			for i in 6:
				var d: Vector3 = [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK][i]
				var rot: Vector3 = Vector3.ZERO
				if d.x != 0.0:
					rot = Vector3(0, 0, -d.x * PI / 2.0)
				elif d.z != 0.0:
					rot = Vector3(d.z * PI / 2.0, 0, 0)
				elif d.y < 0.0:
					rot = Vector3(PI, 0, 0)
				mi(root, cyl(0.0, 0.32, 0.9, 10), pal.call("yellow"), d * r * 1.15, Vector3.ONE * r, rot, ow)
			mi(root, sphere(8, 6), Color.WHITE, Vector3(0, r * 0.3, r * 0.8), Vector3.ONE * r * 0.22, Vector3.ZERO, 0.0, 1.5)
			marker(root, "!", pal.call("red"), r * 2.0)
		"grabber":
			mi(root, sphere(16, 10), pal.call("gunmetal2"), Vector3.ZERO, Vector3(r, r * 0.85, r), Vector3.ZERO, ow)
			mi(root, torus(0.82, 1.0, 24, 8), pal.call("gold"), Vector3.ZERO, Vector3.ONE * r * 1.05, Vector3(PI / 2.0, 0, 0), ow)
			for s in [-1.0, 1.0]:
				mi(root, rbox(Vector3(1.4, 0.32, 0.32)), pal.call("magenta"), Vector3(r * 0.9, 0, s * r * 0.9), Vector3.ONE * r * 0.8, Vector3(0, s * 0.5, 0), ow)
				mi(root, rbox(Vector3(0.45, 0.32, 0.95)), pal.call("magenta"), Vector3(r * 1.6, 0, s * r * 0.55), Vector3.ONE * r * 0.8, Vector3(0, s * -0.6, 0), ow)
			mi(root, sphere(10, 6), pal.call("red"), Vector3(r * 0.86, r * 0.2, 0), Vector3.ONE * r * 0.3, Vector3.ZERO, ow * 0.5, 1.5)
			marker(root, "▼", pal.call("red"), r * 2.4)
		"snatch":
			mi(root, rbox(Vector3(2.2, 1.2, 1.5), 0.35), pal.call("gunmetal2"), Vector3.ZERO, Vector3.ONE * r * 0.8, Vector3.ZERO, ow)
			mi(root, cyl(0.6, 0.6, 1.0, 14), pal.call("mint"), Vector3(r * 0.9, 0, 0), Vector3.ONE * r * 0.9, Vector3(0, 0, PI / 2.0), ow)
			mi(root, rbox(Vector3(0.2, 1.3, 1.6)), pal.call("gold"), Vector3(-r * 0.4, 0, 0), Vector3.ONE * r * 0.8, Vector3.ZERO, ow)
			mi(root, sphere(8, 6), pal.call("pink"), Vector3(r * 1.2, 0, 0), Vector3.ONE * r * 0.25, Vector3.ZERO, 0.0, 0.8)
			marker(root, "▼", pal.call("red"), r * 2.4)
		"patrol":
			mi(root, rbox(Vector3(2.6, 0.9, 1.2), 0.3), pal.call("gunmetal2"), Vector3.ZERO, Vector3.ONE * r * 0.9, Vector3.ZERO, ow)
			mi(root, rbox(Vector3(1.2, 0.6, 0.8), 0.4), pal.call("gunmetal"), Vector3(-r * 0.2, r * 0.68, 0), Vector3.ONE * r * 0.9, Vector3.ZERO, ow)
			for s2 in [-1.0, 1.0]:
				mi(root, rbox(Vector3(2.6, 0.12, 0.14), 0.5), pal.call("gold"), Vector3(0, r * 0.42, s2 * r * 0.58), Vector3.ONE * r * 0.9, Vector3.ZERO, 0.0, 0.3)
				mi(root, rbox(Vector3(0.1, 0.9, 0.55), 0.3), pal.call("magenta"), Vector3(-r * 0.5, 0, s2 * r * 0.62), Vector3.ONE * r * 0.9, Vector3.ZERO, ow)
				mi(root, cyl(0.3, 0.38, 0.5, 14), pal.call("orange"), Vector3(-r * 1.2, 0, s2 * r * 0.3), Vector3.ONE * r * 0.7, Vector3(0, 0, PI / 2.0), ow, 1.0)
			mi(root, cyl(0.45, 0.45, 0.12, 20), pal.call("gold"), Vector3(r * 0.4, r * 0.15, r * 0.6), Vector3.ONE * r * 0.7, Vector3(PI / 2.0, 0, 0), ow)
			mi(root, sphere(10, 8), pal.call("pink"), Vector3(r * 0.4, r * 0.15, r * 0.72), Vector3.ONE * r * 0.17, Vector3.ZERO, 0.0)
			windows(root, Vector3(-r * 0.5, r * 0.75, r * 0.38), 3, r * 0.3, r * 0.08)
			marker(root, "▼", pal.call("red"), r * 1.8)
		"bastion":
			mi(root, rbox(Vector3(3.2, 0.9, 1.4), 0.25), pal.call("gunmetal2"), Vector3.ZERO, Vector3.ONE * r * 0.7, Vector3.ZERO, ow)
			mi(root, rbox(Vector3(1.4, 0.9, 1.0), 0.3), pal.call("gunmetal"), Vector3(-r * 0.2, r * 0.6, 0), Vector3.ONE * r * 0.7, Vector3.ZERO, ow)
			mi(root, rbox(Vector3(0.6, 0.5, 0.6), 0.4), pal.call("gunmetal2"), Vector3(-r * 0.3, r * 1.0, 0), Vector3.ONE * r * 0.7, Vector3.ZERO, ow)
			for s3 in [-1.0, 1.0]:
				mi(root, rbox(Vector3(3.2, 0.1, 0.16), 0.5), pal.call("gold"), Vector3(0, r * 0.32, s3 * r * 0.5), Vector3.ONE * r * 0.7, Vector3.ZERO, 0.0, 0.3)
				mi(root, rbox(Vector3(0.9, 0.6, 0.35), 0.35), pal.call("magenta"), Vector3(r * 0.2, 0, s3 * r * 1.0), Vector3.ONE * r * 0.7, Vector3.ZERO, ow)
				mi(root, cyl(0.15, 0.15, 1.2, 10), pal.call("gold"), Vector3(r * 0.9, r * 0.05, s3 * r * 1.0), Vector3.ONE * r * 0.7, Vector3(0, 0, PI / 2.0), ow)
			windows(root, Vector3(-r * 0.9, r * 0.25, r * 0.5), 7, r * 0.26, r * 0.06)
			mi(root, sphere(16, 12), pal.call("gold"), Vector3(r * 0.9, r * 0.12, 0), Vector3.ONE * r * 0.4, Vector3.ZERO, ow)
			for s4 in [-1.0, 1.0]:
				mi(root, sphere(10, 8), Color.WHITE, Vector3(r * 1.22, r * 0.22, s4 * r * 0.15), Vector3.ONE * r * 0.09, Vector3.ZERO, ow * 0.6)
				mi(root, sphere(8, 6), pal.call("ink"), Vector3(r * 1.3, r * 0.22, s4 * r * 0.15), Vector3.ONE * r * 0.045, Vector3.ZERO, 0.0)
			mi(root, sphere(10, 8), pal.call("ink"), Vector3(r * 1.2, r * 0.0, 0), Vector3(r * 0.06, r * 0.05, r * 0.22), Vector3.ZERO, 0.0)
			var vent: MeshInstance3D = mi(root, cyl(0.2, 0.3, 0.3, 14), pal.call("red"), Vector3(-r * 0.9, 0, 0), Vector3.ONE * r * 0.5, Vector3(0, 0, PI / 2.0), ow, 1.0)
			vent.name = "vent"
			marker(root, "▼", pal.call("red"), r * 1.5)
		"magnificence":
			mi(root, sphere(24, 16), pal.call("gold"), Vector3.ZERO, Vector3.ONE * r, Vector3.ZERO, ow)
			mi(root, sphere(14, 10), pal.call("gold").lightened(0.08), Vector3(r * 0.95, -r * 0.05, 0), Vector3(r * 0.3, r * 0.22, r * 0.2), Vector3.ZERO, ow)
			for s5 in [-1.0, 1.0]:
				mi(root, sphere(14, 10), Color.WHITE, Vector3(r * 0.82, r * 0.3, s5 * r * 0.3), Vector3.ONE * r * 0.17, Vector3.ZERO, ow)
				mi(root, sphere(10, 8), pal.call("ink"), Vector3(r * 0.97, r * 0.3, s5 * r * 0.3), Vector3.ONE * r * 0.07, Vector3.ZERO, 0.0)
				mi(root, sphere(12, 8), pal.call("ink"), Vector3(r * 0.85, r * 0.1, s5 * r * 0.4), Vector3(r * 0.08, r * 0.08, r * 0.3), Vector3(0, 0, 0.2 * s5), 0.0)
				mi(root, cyl(0.0, 0.12, 0.5, 8), pal.call("magenta"), Vector3(r * 0.2, r * 0.95, s5 * r * 0.35), Vector3.ONE * r, Vector3.ZERO, ow)
			mi(root, cyl(0.0, 0.15, 0.6, 8), pal.call("magenta"), Vector3(r * 0.2, r * 1.0, 0), Vector3.ONE * r, Vector3.ZERO, ow)
			marker(root, "THE MAGNIFICENCE", pal.call("magenta"), r * 1.4)
		"freighter":
			mi(root, rbox(Vector3(2.6, 1.0, 1.0), 0.45), pal.call("orange"), Vector3.ZERO, Vector3.ONE * r, Vector3.ZERO, ow)
			mi(root, rbox(Vector3(0.8, 0.6, 0.9), 0.45), pal.call("sensors"), Vector3(r * 1.2, r * 0.3, 0), Vector3.ONE * r, Vector3.ZERO, ow)
			windows(root, Vector3(-r * 0.8, r * 0.2, r * 0.5), 4, r * 0.45, r * 0.12)
		"diner":
			mi(root, torus(r * 0.82, r, 40, 14), pal.call("red"), Vector3.ZERO, Vector3.ONE, Vector3.ZERO, ow)
			mi(root, torus(r * 0.9, r * 0.97, 40, 8), Color.WHITE, Vector3(0, r * 0.02, 0), Vector3(1, 1.9, 1), Vector3.ZERO, 0.0)
			mi(root, sphere(18, 12), pal.call("mint"), Vector3.ZERO, Vector3(r * 0.45, r * 0.35, r * 0.45), Vector3.ZERO, ow)
			mi(root, cyl(0.0, 0.5, 0.9, 12), pal.call("pink"), Vector3(0, r * 0.45, 0), Vector3.ONE * r * 0.4, Vector3.ZERO, ow)
			for i2 in 12:
				var a: float = float(i2) / 12.0 * TAU
				mi(root, sphere(8, 6), pal.call("yellow"), Vector3(cos(a) * r * 0.91, r * 0.13, sin(a) * r * 0.91), Vector3.ONE * r * 0.05, Vector3.ZERO, 0.0, 1.4)
			var dl: MeshInstance3D = mi(root, sphere(12, 8), pal.call("yellow"), Vector3(r + 7.5, 0, 0), Vector3.ONE * 3.5, Vector3.ZERO, 0.0, 2.0)
			dl.name = "dock"
			marker(root, "MA GRISTLE'S DINER", pal.call("yellow"), r * 1.1)
		"skip":
			var special: bool = bool(extra.get("special", false))
			var sc: Color = pal.call("pink") if special else pal.call("sensors")
			mi(root, rbox(Vector3(2.0, 1.4, 1.4), 0.3), sc, Vector3.ZERO, Vector3.ONE * r * 0.8, Vector3.ZERO, ow, 0.5 if special else 0.0)
			mi(root, rbox(Vector3(2.15, 0.22, 1.55), 0.4), pal.call("gunmetal2"), Vector3(0, r * 0.62, 0), Vector3.ONE * r * 0.8, Vector3.ZERO, ow)
			if special:
				marker(root, "WARM (purring)", pal.call("pink"), r * 2.2)
			else:
				marker(root, "SKIP", pal.call("mint"), r * 2.0, 0.0009)
		"pod":
			mi(root, capsule(0.5, 1.8), pal.call("purple"), Vector3.ZERO, Vector3.ONE * r, Vector3(0, 0, PI / 2.0), ow)
			mi(root, sphere(10, 8), pal.call("sky"), Vector3(r * 0.5, r * 0.3, 0), Vector3.ONE * r * 0.35, Vector3.ZERO, ow)
		"waypoint":
			mi(root, torus(r * 0.9, r, 40, 10), pal.call("green"), Vector3.ZERO, Vector3.ONE, Vector3(PI / 2.0, 0, 0), 0.0, 1.4)
			mi(root, torus(r * 0.55, r * 0.6, 32, 8), pal.call("yellow"), Vector3.ZERO, Vector3.ONE, Vector3(PI / 2.0, 0, 0), 0.0, 1.4)
			mi(root, cyl(0.0, 0.4, 2.0, 10), pal.call("green"), Vector3(0, r * 0.9, 0), Vector3.ONE * r * 0.35, Vector3(PI, 0, 0), 0.0, 1.2)
			marker(root, "◎ " + (name if name != "" else "WAYPOINT"), pal.call("green"), r * 1.6)
		"beacon":
			mi(root, cyl(0.6, 0.9, 1.6, 12), pal.call("pink"), Vector3.ZERO, Vector3.ONE * r, Vector3.ZERO, ow)
			mi(root, sphere(10, 8), pal.call("yellow"), Vector3(0, r * 1.2, 0), Vector3.ONE * r * 0.5, Vector3.ZERO, 0.0, 1.5)
		"debris":
			if name.begins_with("Rubber"):
				mi(root, sphere(12, 8), pal.call("yellow"), Vector3.ZERO, Vector3.ONE * r, Vector3.ZERO, ow)
				mi(root, sphere(10, 8), pal.call("yellow"), Vector3(r * 0.5, r * 0.7, 0), Vector3.ONE * r * 0.55, Vector3.ZERO, ow)
				mi(root, cyl(0.0, 0.5, 1.0, 8), pal.call("orange"), Vector3(r * 1.1, r * 0.7, 0), Vector3.ONE * r * 0.4, Vector3(0, 0, -PI / 2.0), ow)
			elif name.begins_with("Wedding"):
				mi(root, cyl(1.0, 1.0, 0.7, 18), Color.WHITE, Vector3.ZERO, Vector3.ONE * r, Vector3.ZERO, ow)
				mi(root, cyl(0.7, 0.7, 0.6, 18), pal.call("pink"), Vector3(0, r * 0.6, 0), Vector3.ONE * r, Vector3.ZERO, ow)
				mi(root, cyl(0.4, 0.4, 0.5, 18), Color.WHITE, Vector3(0, r * 1.1, 0), Vector3.ONE * r, Vector3.ZERO, ow)
			else:
				mi(root, rbox(Vector3(1, 1, 1), 0.3), pal.call("yellow"), Vector3.ZERO, Vector3.ONE * r, Vector3.ZERO, ow)
		"bullet":
			mi(root, capsule(0.18, 1.4), pal.call("yellow"), Vector3.ZERO, Vector3.ONE * 2.2, Vector3(0, 0, PI / 2.0), 0.0, 1.8)
		"ebullet":
			mi(root, sphere(10, 6), pal.call("red"), Vector3.ZERO, Vector3.ONE * 1.4, Vector3.ZERO, 0.0, 1.8)
		"eshell":
			mi(root, sphere(12, 8), pal.call("orange"), Vector3.ZERO, Vector3.ONE * 3.0, Vector3.ZERO, 0.0, 1.5)
			mi(root, sphere(10, 6), pal.call("yellow"), Vector3.ZERO, Vector3.ONE * 1.8, Vector3.ZERO, 0.0, 2.0)
		"torp":
			mi(root, capsule(0.5, 3.0), pal.call("orange"), Vector3.ZERO, Vector3.ONE * 1.6, Vector3(0, 0, PI / 2.0), 0.12)
			mi(root, sphere(8, 6), pal.call("yellow"), Vector3(-2.2, 0, 0), Vector3.ONE * 0.9, Vector3.ZERO, 0.0, 2.0)
		_:
			mi(root, sphere(12, 8), pal.call("purple"), Vector3.ZERO, Vector3.ONE * r, Vector3.ZERO, ow)
	return root

static func own_bow() -> Node3D:
	## The nose of the Second Opinion, seen from the bridge. Lives in front of the camera (-Z forward).
	var root: Node3D = Node3D.new()
	var hull: Color = K.pal("engines")
	mi(root, rbox(Vector3(12.0, 3.4, 13.0), 0.3), hull, Vector3(0, 0, 0), Vector3.ONE, Vector3.ZERO, 0.06)
	mi(root, rbox(Vector3(12.2, 0.9, 13.2), 0.5), K.pal("yellow"), Vector3(0, -0.6, 0), Vector3.ONE, Vector3.ZERO, 0.0)
	mi(root, rbox(Vector3(9.0, 1.6, 2.4), 0.4), K.pal("sensors"), Vector3(0, 1.9, 4.6), Vector3.ONE, Vector3.ZERO, 0.05)
	for s in [-1.0, 1.0]:
		mi(root, sphere(12, 8), Color("#fff6c8"), Vector3(s * 3.8, 0.4, -6.2), Vector3(0.9, 0.7, 0.4), Vector3.ZERO, 0.04, 1.6)
		mi(root, cyl(0.12, 0.12, 2.4, 8), K.pal("gunmetal"), Vector3(s * 5.2, 2.4, -2.5), Vector3.ONE, Vector3.ZERO, 0.03)
		mi(root, sphere(8, 6), K.pal("red"), Vector3(s * 5.2, 3.7, -2.5), Vector3.ONE * 0.35, Vector3.ZERO, 0.0, 1.5)
	for i in 5:
		mi(root, sphere(8, 6), hull.darkened(0.25), Vector3(-4.0 + i * 2.0, 1.75, -5.0), Vector3.ONE * 0.18, Vector3.ZERO, 0.0)
	return root
