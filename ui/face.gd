class_name Face
extends TextureRect
## A character's portrait that can change mood: "" (calm), "busy", "panic" or "cheer".
## The crew's faces react to what's happening to them; that's most of what makes them feel alive.

var who: String = ""
var px: int = 96
var mood: String = ""
var _pop: Tween

func _init(name: String = "igor", size_px: int = 96) -> void:
	who = name
	px = size_px
	custom_minimum_size = Vector2(px, px)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_show()

func _show() -> void:
	var n: String = "portrait_" + who
	if mood != "" and Art.has(n + "_" + mood):
		n += "_" + mood
	texture = Art.sized(n, px)

func set_who(name: String) -> void:
	if name != who:
		who = name
		_show()

func set_mood(m: String, pop: bool = true) -> void:
	if m == mood:
		return
	mood = m
	_show()
	if pop and is_inside_tree() and is_visible_in_tree():
		# a little squash and stretch when the face changes
		pivot_offset = size / 2.0
		if _pop != null and _pop.is_valid():
			_pop.kill()
		scale = Vector2(1.25, 0.8) if m == "panic" else Vector2(0.85, 1.2)
		_pop = create_tween()
		_pop.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
