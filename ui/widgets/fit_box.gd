class_name FitBox
extends Container
## Holds one screen and shrinks it, evenly, until it fits. A station is laid out for a big landscape screen;
## on a narrow or squat one (or squeezed into half of a combined screen) its controls would spill over each
## other. In here they just get smaller. When there is room to spare, the screen stretches to fill it.

const MIN_SCALE: float = 0.35

var _need_sig: Vector2 = Vector2.ZERO
var _shown_at: int = 0       # the frame a screen last appeared: wrapped text needs a moment to settle

static func need(c: Control) -> Vector2:
	## how much room a screen really needs. A plain Control doesn't pass its children's sizes up, so look at them.
	var m: Vector2 = c.get_combined_minimum_size()
	if not (c is Container):
		for ch in c.get_children():
			if ch is Control and (ch as Control).visible and not (ch as Control).has_meta("overlay"):
				m = m.max(need(ch as Control))
	return m

func _notification_visible() -> void:
	_shown_at = Engine.get_process_frames()

func _ready() -> void:
	visibility_changed.connect(_notification_visible)
	_shown_at = Engine.get_process_frames()

func _settling() -> bool:
	return Engine.get_process_frames() - _shown_at < 3

var _was_settling: bool = true

func _process(_dt: float) -> void:
	if _settling():
		_was_settling = true
		queue_sort()
		return
	if _was_settling:
		_was_settling = false
		queue_sort()     # settled: one proper fit
	# a screen's needs change as it fills in (lobby cards, long names): re-fit when they do
	for c in get_children():
		if c is Control and (c as Control).visible:
			var n: Vector2 = need(c)
			if n != _need_sig:
				_need_sig = n
				queue_sort()

func _init() -> void:
	clip_contents = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS

func _get_minimum_size() -> Vector2:
	return Vector2.ZERO

func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	for c in get_children():
		if not (c is Control) or not (c as Control).visible:
			continue
		var ctl: Control = c
		var m: Vector2 = need(ctl)
		var k: float = 1.0
		if m.x > 0.0 and size.x > 0.0:
			k = minf(k, size.x / m.x)
		if m.y > 0.0 and size.y > 0.0:
			k = minf(k, size.y / m.y)
		k = maxf(k, MIN_SCALE)
		if k > 0.995 or _settling():
			k = 1.0     # near enough (or still settling): lay it out at full size

		ctl.set_anchors_preset(Control.PRESET_TOP_LEFT)
		ctl.scale = Vector2(k, k)
		var inner: Vector2 = size / k
		ctl.size = inner if k == 1.0 else Vector2(maxf(inner.x, m.x), maxf(inner.y, m.y))
		# centre what's left over when the shrink was set by the other side
		ctl.position = ((size - ctl.size * k) / 2.0).max(Vector2.ZERO)
