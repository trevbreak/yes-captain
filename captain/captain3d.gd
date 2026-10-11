class_name Captain3D
extends Node3D
## What the captain sees out of the window. The simulation is 2D; this renders it as chunky 3D.
## The captain cannot move this camera. Only Sensors can change the viewscreen direction.

const DUST_L: float = 1100.0
## soft round billboard puff: alpha falls off radially from the quad centre
const NEBULA_SH: String = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float alpha = 0.25;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float a = 1.0 - smoothstep(0.0, 1.0, d);
	ALBEDO = color.rgb;
	ALPHA = alpha * a * a;
}
"""

var cam: Camera3D
var sun: DirectionalLight3D
var env: WorldEnvironment
var ents_root: Node3D
var fx_root: Node3D
var stars: MultiMeshInstance3D
var nebulae: Node3D
var dust: MultiMeshInstance3D
var dust_mat: ShaderMaterial
var nodes: Dictionary = {}
var targets: Dictionary = {}
var ship_pos: Vector2 = Vector2.ZERO
var ship_vel: Vector2 = Vector2.ZERO
var view_ang: float = -PI / 2.0
var shown_view_ang: float = -PI / 2.0
var angvel: float = 0.0
var since_snap: float = 0.0
var t: float = 0.0
var bank: float = 0.0
var fov_punch: float = 0.0
var cam_height: float = 26.0
var lock_id: int = -1
var shake: float = 0.0
var bow: Node3D
var view_name: String = "fwd"
var fill: DirectionalLight3D

func _ready() -> void:
	env = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color.html("#241c47")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.html("#9a8fd6")
	e.ambient_light_energy = 0.55
	env.environment = e
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(40.0), 0)
	sun.light_color = Color.html("#fff2d6")
	sun.light_energy = 1.15
	add_child(sun)
	cam = Camera3D.new()
	cam.fov = 72.0
	cam.near = 0.5
	cam.far = 12000.0
	cam.current = true
	add_child(cam)
	fill = DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-20.0), deg_to_rad(-140.0), 0)
	fill.light_color = Color.html("#9fc8ff")
	fill.light_energy = 0.35
	add_child(fill)
	bow = Models.own_bow()
	bow.position = Vector3(0, -6.6, -11.0)
	cam.add_child(bow)
	ents_root = Node3D.new()
	add_child(ents_root)
	fx_root = Node3D.new()
	add_child(fx_root)
	_build_stars()
	_build_nebulae()
	_build_dust()

# ---------------------------------------------------------------- scenery

func _build_stars() -> void:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(1, 1)
	mm.mesh = q
	mm.instance_count = 520
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99
	var cols: Array = [Color.WHITE, K.pal("butter"), K.pal("pink"), K.pal("sky"), K.pal("mint")]
	for i in mm.instance_count:
		var dir: Vector3 = Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 1), rng.randf_range(-1, 1)).normalized()
		var p: Vector3 = dir * 8000.0
		var s: float = rng.randf_range(14.0, 44.0)
		var b: Basis = Basis.looking_at(-dir, Vector3.UP).scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, Transform3D(b, p))
		mm.set_instance_color(i, cols[rng.randi() % cols.size()] * rng.randf_range(0.6, 1.0))
	stars = MultiMeshInstance3D.new()
	stars.multimesh = mm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	stars.material_override = mat
	stars.custom_aabb = AABB(Vector3(-9000, -9000, -9000), Vector3(18000, 18000, 18000))
	add_child(stars)

func _build_nebulae() -> void:
	nebulae = Node3D.new()
	add_child(nebulae)
	var sh: Shader = Shader.new()
	sh.code = NEBULA_SH
	var cols: Array = [K.pal("purple"), K.pal("pink"), K.pal("sensors"), K.pal("navy"), K.pal("blue")]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	for i in 12:
		var m: MeshInstance3D = MeshInstance3D.new()
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2.ONE * rng.randf_range(2600, 4800)
		m.mesh = q
		var dir: Vector3 = Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.25, 0.55), rng.randf_range(-1, 1)).normalized()
		m.position = dir * 7400.0
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("color", cols[i % cols.size()])
		mat.set_shader_parameter("alpha", rng.randf_range(0.18, 0.3))
		m.material_override = mat
		m.extra_cull_margin = 4000.0
		nebulae.add_child(m)
	# a few chunky planets
	for j in 3:
		var pl: Node3D = Node3D.new()
		var dir2: Vector3 = Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 0.35), rng.randf_range(-1, 1)).normalized()
		pl.position = dir2 * 6000.0
		var r: float = rng.randf_range(260, 520)
		Models.mi(pl, Models.sphere(14, 9), [K.pal("tangerine"), K.pal("mint"), K.pal("pink")][j], Vector3.ZERO, Vector3.ONE * r, Vector3.ZERO, r * 0.03)
		Models.mi(pl, Models.torus(1.35, 1.7, 30, 4), [K.pal("butter"), K.pal("sky"), K.pal("lilac")][j], Vector3.ZERO, Vector3(r, r * 0.12, r), Vector3(0.4, 0, 0.2), r * 0.02)
		nebulae.add_child(pl)

func _build_dust() -> void:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Models.box(1.6, 1.6, 1.6)
	mm.instance_count = 260
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 21
	for i in mm.instance_count:
		var p: Vector3 = Vector3(rng.randf_range(0, DUST_L), rng.randf_range(-180, 180), rng.randf_range(0, DUST_L))
		var s: float = rng.randf_range(0.5, 2.2)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), p))
	dust = MultiMeshInstance3D.new()
	dust.multimesh = mm
	var sh: Shader = Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded;
uniform vec3 cam_pos = vec3(0.0);
uniform float L = 1100.0;
void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 rel = center - cam_pos;
	rel.x = mod(rel.x + L * 0.5, L) - L * 0.5;
	rel.z = mod(rel.z + L * 0.5, L) - L * 0.5;
	VERTEX += (cam_pos + rel) - center;
}
void fragment() {
	ALBEDO = vec3(0.85, 0.82, 1.0);
}
"""
	dust_mat = ShaderMaterial.new()
	dust_mat.shader = sh
	dust.material_override = dust_mat
	dust.custom_aabb = AABB(Vector3(-100000, -1000, -100000), Vector3(200000, 2000, 200000))
	add_child(dust)

# ---------------------------------------------------------------- updates

func apply(v: Dictionary) -> void:
	since_snap = 0.0
	ship_pos = Vector2(float(v.x), float(v.y))
	ship_vel = Vector2(float(v.vx), float(v.vy))
	view_ang = float(v.view_ang)
	view_name = str(v.get("view", "fwd"))
	angvel = float(v.av)
	shake = float(v.shake)
	lock_id = int(v.get("lock", -1))
	var seen: Dictionary = {}
	for e in v.ents:
		var id: int = int(e.id)
		seen[id] = true
		targets[id] = e
		if not nodes.has(id):
			var n: Node3D = Models.build(str(e.k), float(e.r), str(e.n), {"special": e.get("special", false)})
			n.position = Vector3(float(e.x), _ey(id, float(e.r)), float(e.y))
			n.rotation.y = -float(e.a)
			ents_root.add_child(n)
			nodes[id] = n
	for id2 in nodes.keys():
		if not seen.has(id2):
			nodes[id2].queue_free()
			nodes.erase(id2)
			targets.erase(id2)
	dust_mat.set_shader_parameter("cam_pos", Vector3(ship_pos.x, 0, ship_pos.y))

func _ey(id: int, r: float) -> float:
	return sin(float(id) * 7.31) * minf(r * 0.6, 14.0)

func _process(delta: float) -> void:
	t += delta
	since_snap += delta
	var pos: Vector2 = ship_pos + ship_vel * minf(since_snap, 0.2)
	shown_view_ang = lerp_angle(shown_view_ang, view_ang, 1.0 - exp(-9.0 * delta))
	var dir: Vector3 = Vector3(cos(shown_view_ang), 0.0, sin(shown_view_ang))
	var sh: Vector3 = Vector3.ZERO
	if shake > 0.02:
		sh = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.6
	var eye: Vector3 = Vector3(pos.x, cam_height, pos.y) + sh
	cam.global_position = eye
	var look: Vector3 = eye + dir * 100.0 + Vector3(0, -7.0, 0)
	cam.look_at(look, Vector3.UP)
	bank = lerpf(bank, clampf(-angvel * 0.07, -0.25, 0.25), 1.0 - exp(-6.0 * delta))
	cam.rotate_object_local(Vector3.FORWARD, bank + sh.x * 0.01)
	fov_punch = lerpf(fov_punch, 0.0, 1.0 - exp(-4.0 * delta))
	if bow != null:
		bow.visible = view_name == "fwd"
		bow.position.y = -6.6 + sin(t * 1.7) * 0.08
	cam.fov = 72.0 + fov_punch
	# scenery follows the camera so it feels infinitely far away
	stars.global_position = eye
	if nebulae != null:
		nebulae.global_position = eye
	# entities glide toward their latest snapshot position
	for id in nodes.keys():
		var n: Node3D = nodes[id]
		var e: Dictionary = targets.get(id, {})
		if e.is_empty():
			continue
		var tgt: Vector3 = Vector3(float(e.x), _ey(int(id), float(e.r)), float(e.y))
		var k: float = 1.0 - exp(-18.0 * delta)
		if (n.position - tgt).length() > 300.0:
			n.position = tgt
		else:
			n.position = n.position.lerp(tgt, k)
		n.rotation.y = lerp_angle(n.rotation.y, -float(e.a), k)
		match str(e.k):
			"waypoint":
				n.rotation.y += delta * 0.5
				n.position.y += sin(t * 2.0) * 0.2
			"mine":
				var s: float = 1.0 + 0.2 * sin(t * 10.0)
				n.scale = Vector3.ONE * s
			"diner", "magnificence":
				n.rotation.y = -float(e.a)
		if str(e.k) == "bastion":
			var vent: Node = n.get_node_or_null("vent")
			if vent != null:
				var mat: ShaderMaterial = (vent as MeshInstance3D).material_override
				mat.set_shader_parameter("glow_amount", 1.0 if str(e.get("st", "")) != "telegraph" else 1.0 + 3.0 * (0.5 + 0.5 * sin(t * 16.0)))
		if int(id) == lock_id:
			n.scale = Vector3.ONE * (1.0 + 0.04 * sin(t * 8.0))

func boom(p: Vector2, size: float) -> void:
	var n: MeshInstance3D = MeshInstance3D.new()
	n.mesh = Models.sphere(10, 6)
	var m: ShaderMaterial = Models.glow_mat(K.pal("butter"), 0.9)
	n.material_override = m
	n.position = Vector3(p.x, 0.0, p.y)
	n.scale = Vector3.ONE * maxf(0.5, size * 0.3)
	fx_root.add_child(n)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(n, "scale", Vector3.ONE * size * 1.6, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(a: float): m.set_shader_parameter("alpha", a), 0.9, 0.0, 0.6)
	tw.tween_callback(n.queue_free).set_delay(0.62)
	# a puffy orange ring
	var r: MeshInstance3D = MeshInstance3D.new()
	r.mesh = Models.sphere(8, 5)
	var m2: ShaderMaterial = Models.glow_mat(K.pal("tangerine"), 0.7)
	r.material_override = m2
	r.position = n.position
	r.scale = Vector3.ONE * maxf(0.5, size * 0.2)
	fx_root.add_child(r)
	var tw2: Tween = create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(r, "scale", Vector3.ONE * size * 2.2, 0.8).set_ease(Tween.EASE_OUT)
	tw2.tween_method(func(a: float): m2.set_shader_parameter("alpha", a), 0.7, 0.0, 0.8)
	tw2.tween_callback(r.queue_free).set_delay(0.85)

func jump_fx() -> void:
	fov_punch = 50.0
