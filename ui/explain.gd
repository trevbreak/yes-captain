class_name Explain
extends CanvasLayer
## Tap to explain, for touch screens (where tooltips never show). Tap a chip, a face or a label that has an
## explanation and a little speech bubble says it; press and HOLD a button to read what it does instead of
## pressing it. With a mouse, ordinary hover tooltips still do the job, so this stays out of the way.

const HOLD_S: float = 0.5
const SLOP: float = 22.0

var bubble: PanelContainer
var text_lbl: Label
var _down: bool = false
var _down_at: Vector2 = Vector2.ZERO
var _down_t: float = 0.0
var _target: Control = null
var _shown_t: float = 0.0
var _swallow: BaseButton = null    # the button a long press explained: its release mustn't press it
var _swallow_was: bool = false

func _ready() -> void:
	layer = 55
	bubble = UIK.panel("panel_small", [6, 4, 6, 4])
	bubble.visible = false
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.custom_minimum_size = Vector2(240, 0)
	add_child(bubble)
	text_lbl = UIK.para("", 22)
	text_lbl.custom_minimum_size = Vector2(380, 0)
	text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(text_lbl)

static func _explained(c: Control) -> Control:
	## the control (or its nearest parent) that carries an explanation
	var n: Node = c
	while n != null and n is Control:
		if (n as Control).tooltip_text.strip_edges() != "":
			return n
		n = n.get_parent()
	return null

func _input(e: InputEvent) -> void:
	if not UIK.touch_ui or not (e is InputEventScreenTouch or e is InputEventScreenDrag):
		return
	if e is InputEventScreenTouch and (e as InputEventScreenTouch).index == 0:
		var t: InputEventScreenTouch = e
		if t.pressed:
			if bubble.visible:
				hide_bubble()
			_down = true
			_down_at = t.position
			_down_t = 0.0
			_target = _pick(t.position)
		else:
			if _down and _target != null and not (_target is BaseButton) and _down_t < HOLD_S:
				show_for(_target, t.position)   # a tap on something that explains itself
			_down = false
			if _swallow != null and is_instance_valid(_swallow):
				# the finger is up (the button already ignored the release): switch it back on
				var b: BaseButton = _swallow
				var was: bool = _swallow_was
				(func(): if is_instance_valid(b): b.disabled = was).call_deferred()
			_swallow = null
	elif e is InputEventScreenDrag and (e as InputEventScreenDrag).index == 0 and _down:
		if (e as InputEventScreenDrag).position.distance_to(_down_at) > SLOP:
			_down = false

func _pick(at: Vector2) -> Control:
	## the explained control under a finger. (Godot's "hovered" control only follows a mouse; a finger isn't one.)
	var p: Vector2 = at      # input events arrive here already in the game's own coordinates
	var best: Array = [null]
	_search(get_tree().root, p, best)
	return _explained(best[0]) if best[0] != null else null

func _search(n: Node, p: Vector2, best: Array) -> void:
	# depth first, later siblings drawn on top: the last hit wins (a CanvasLayer's contents count too)
	if (n is CanvasItem and not (n as CanvasItem).visible) or (n is CanvasLayer and not (n as CanvasLayer).visible):
		return
	if n is Control:
		var c: Control = n
		if c.mouse_filter != Control.MOUSE_FILTER_IGNORE and c.get_global_rect().has_point(p) and c != bubble:
			best[0] = c
	for ch in n.get_children():
		_search(ch, p, best)

func _process(dt: float) -> void:
	if bubble.visible:
		_shown_t += dt
		if _shown_t > 6.0:
			hide_bubble()
	if not _down:
		return
	_down_t += dt
	if _down_t >= HOLD_S and _target != null:
		_down = false
		show_for(_target, _down_at)
		if _target is BaseButton:
			# a long press asked "what is this?", not "do it": the button sits out until the finger lifts
			_swallow = _target
			_swallow_was = _swallow.disabled
			_swallow.disabled = true

func show_for(c: Control, at: Vector2) -> void:
	text_lbl.text = c.tooltip_text.strip_edges()
	bubble.visible = true
	bubble.reset_size()
	_shown_t = 0.0
	var vp: Vector2 = bubble.get_viewport_rect().size
	var p: Vector2 = at
	var bs: Vector2 = bubble.get_combined_minimum_size()
	var pos: Vector2 = p + Vector2(-bs.x / 2.0, -bs.y - 40.0)
	if pos.y < 8.0:
		pos.y = p.y + 48.0
	bubble.position = pos.clamp(Vector2(8, 8), vp - bs - Vector2(8, 8))
	UIK.sfx("blip")

func hide_bubble() -> void:
	bubble.visible = false
