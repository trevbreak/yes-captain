class_name Fx
extends CanvasLayer
## Old-cartoon stagecraft over the whole screen: the iris that opens on each new scene, a mission title card,
## and the screen shake when the ship takes a knock. Purely visual; sits under the film grain.

const IRIS: String = """
shader_type canvas_item;
uniform float open = 1.5;
uniform vec2 aspect = vec2(1.0, 1.0);
void fragment() {
	vec2 p = (UV - 0.5) * aspect;
	float d = length(p);
	float edge = smoothstep(open - 0.006, open + 0.006, d);
	COLOR = vec4(0.11, 0.09, 0.07, edge);
}
"""

static var inst: Fx = null

var target: Control = null        # what shakes
var iris_rect: ColorRect
var iris_mat: ShaderMaterial
var card: PanelContainer
var card_title: Label
var card_sub: Label
var _shake: float = 0.0
var _iris_tw: Tween
var _card_tw: Tween

func _ready() -> void:
	inst = self
	layer = 90
	iris_rect = ColorRect.new()
	iris_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	iris_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	iris_mat = ShaderMaterial.new()
	var sh: Shader = Shader.new()
	sh.code = IRIS
	iris_mat.shader = sh
	iris_rect.material = iris_mat
	iris_rect.visible = false
	add_child(iris_rect)
	var cc: CenterContainer = CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	card = UIK.panel("panel", [34, 8, 34, 10])
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.visible = false
	cc.add_child(card)
	var v: VBoxContainer = UIK.vbox(-4)
	card.add_child(v)
	card_sub = UIK.head("", 24, UIK.c("red"), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(card_sub)
	card_title = UIK.title("", 64, UIK.c("cream"), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(card_title)

static func iris() -> void:
	## the scene opens out from a dot, the way every cartoon of the period did
	if inst != null:
		inst._iris()

static func shake(amount: float = 8.0) -> void:
	if inst != null:
		inst._shake = maxf(inst._shake, amount)

static func title_card(sub: String, title: String) -> void:
	if inst != null:
		inst._title(sub, title)

func _iris() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	iris_mat.set_shader_parameter("aspect", Vector2(vp.x / maxf(1.0, vp.y), 1.0))
	iris_mat.set_shader_parameter("open", 0.0)
	iris_rect.visible = true
	if _iris_tw != null and _iris_tw.is_valid():
		_iris_tw.kill()
	_iris_tw = create_tween()
	_iris_tw.tween_method(func(x: float): iris_mat.set_shader_parameter("open", x), 0.0, 1.3, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_iris_tw.tween_callback(func(): iris_rect.visible = false)

func _title(sub: String, title: String) -> void:
	card_sub.text = sub
	card_title.text = title
	card.visible = true
	card.modulate.a = 1.0
	card.pivot_offset = card.size / 2.0
	card.scale = Vector2(0.4, 0.4)
	card.rotation = -0.12
	if _card_tw != null and _card_tw.is_valid():
		_card_tw.kill()
	_card_tw = create_tween()
	_card_tw.set_parallel(true)
	_card_tw.tween_property(card, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_card_tw.tween_property(card, "rotation", -0.02, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_card_tw.set_parallel(false)
	_card_tw.tween_interval(1.5)
	_card_tw.tween_property(card, "modulate:a", 0.0, 0.35)
	_card_tw.tween_callback(func(): card.visible = false)

func _process(dt: float) -> void:
	if target == null:
		return
	if _shake > 0.2:
		target.position = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		_shake = lerpf(_shake, 0.0, 1.0 - exp(-9.0 * dt))
	elif target.position != Vector2.ZERO:
		target.position = Vector2.ZERO
		_shake = 0.0
