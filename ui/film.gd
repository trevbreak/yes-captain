class_name Film
extends CanvasLayer
## Old-cartoon film over everything: grain, a soft vignette, the odd dust speck and scratch. Purely visual.

const SH: String = """
shader_type canvas_item;
uniform float grain = 0.09;
uniform float vignette = 0.42;
uniform float flicker = 0.015;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	float fr = floor(TIME * 14.0);
	vec2 px = floor(FRAGCOORD.xy / 1.5);
	float g = hash(px + fr * 19.31) - 0.5;
	vec2 c = UV - 0.5;
	c.x *= 1.25;
	float v = smoothstep(0.32, 0.78, length(c)) * vignette;
	float a = v + max(-g, 0.0) * grain + flicker * hash(vec2(fr, 3.0));
	// a scratch now and then
	if (hash(vec2(fr, 7.0)) > 0.95) {
		float x = hash(vec2(fr, 11.0));
		a += smoothstep(0.0010, 0.0, abs(UV.x - x)) * 0.22 * step(hash(vec2(fr, floor(UV.y * 6.0))), 0.6);
	}
	// dust specks
	vec2 cell = floor(FRAGCOORD.xy / 6.0);
	if (hash(cell + fr * 3.7) > 0.99985) { a += 0.6; }
	COLOR = vec4(0.11, 0.085, 0.06, clamp(a, 0.0, 0.9));
}
"""

static var enabled: bool = true

func _ready() -> void:
	add_to_group("film")
	layer = 100
	var r: ColorRect = ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m: ShaderMaterial = ShaderMaterial.new()
	var sh: Shader = Shader.new()
	sh.code = SH
	m.shader = sh
	r.material = m
	add_child(r)
	visible = enabled
