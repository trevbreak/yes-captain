class_name Pointer
extends RefCounted
## Fingers and the mouse as one kind of thing, with every finger kept apart, so a desk can be worked with both
## thumbs at once (hold FIRE with one, drag the turret with the other).
##
## Godot also turns the FIRST finger into a pretend mouse. Those pretend mouse events are skipped here (the real
## touch event for that finger is already handled), so a finger is never counted twice.
##
## A control keeps the id of the pointer that pressed it and only listens to that pointer until it lifts:
##   var id: int = Pointer.down(e)      # NONE unless something just pressed
##   Pointer.moved(e) / Pointer.up(e)   # same, for drags and releases

const NONE: int = -999
const MOUSE: int = -1000

static func _emulated(e: InputEvent) -> bool:
	return e.device == InputEvent.DEVICE_ID_EMULATION

static func down(e: InputEvent) -> int:
	if e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed:
		return (e as InputEventScreenTouch).index
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
			and (e as InputEventMouseButton).pressed and not _emulated(e):
		return MOUSE
	return NONE

static func up(e: InputEvent) -> int:
	if e is InputEventScreenTouch and not (e as InputEventScreenTouch).pressed:
		return (e as InputEventScreenTouch).index
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
			and not (e as InputEventMouseButton).pressed and not _emulated(e):
		return MOUSE
	return NONE

static func moved(e: InputEvent) -> int:
	if e is InputEventScreenDrag:
		return (e as InputEventScreenDrag).index
	if e is InputEventMouseMotion and not _emulated(e):
		return MOUSE
	return NONE

static func swallow(e: InputEvent) -> bool:
	## a pretend mouse event made from a finger: the control should ignore it (and eat it)
	return (e is InputEventMouseButton or e is InputEventMouseMotion) and _emulated(e)
