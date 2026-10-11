class_name Paper
extends ColorRect
## Mottled old-paper background (procedural, so it never tiles visibly).

const SH: String = """
shader_type canvas_item;
uniform vec4 base : source_color = vec4(0.949, 0.886, 0.753, 1.0);
uniform vec4 dark : source_color = vec4(0.83, 0.725, 0.52, 1.0);
uniform float amount = 0.55;
uniform vec2 offset = vec2(0.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int k = 0; k < 4; k++) { v += a * vnoise(p); p *= 2.03; a *= 0.5; } return v; }
void fragment() {
	vec2 p = FRAGCOORD.xy + offset;
	float blotch = fbm(p / 260.0);
	float fibre = fbm(vec2(p.x / 9.0, p.y / 60.0)) * 0.5 + fbm(vec2(p.x / 70.0, p.y / 6.0)) * 0.5;
	float n = blotch * 0.7 + fibre * 0.3 + (hash(p) - 0.5) * 0.08;
	COLOR = mix(base, dark, clamp((n - 0.35) * amount * 1.6, 0.0, 1.0));
}
"""

static var _shader: Shader = null

func _init(base_col: Color = Color("#f2e2c0"), dark_col: Color = Color("#d4b985"), amt: float = 0.55) -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SH
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("base", base_col)
	m.set_shader_parameter("dark", dark_col)
	m.set_shader_parameter("amount", amt)
	material = m
	color = Color.WHITE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
