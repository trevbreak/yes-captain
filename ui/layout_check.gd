class_name LayoutCheck
extends RefCounted
## Automated layout QA. Finds controls that are off-screen, overflow their container, are clipped
## by a parent, or overlap another clickable control. Used by the --layoutcheck autotest.

static func _interactive(n: Control) -> bool:
	return n is BaseButton or n is LineEdit or n is Lever or n is PipRow or n is Radar or n is Schematic

static func _checkable(n: Control) -> bool:
	if n is Label:
		return (n as Label).text.strip_edges() != ""
	return _interactive(n) or n is Dial or n is BarGauge or n is TextureRect or n is PanelContainer

static func _overlay_root(n: Node) -> Node:
	var p: Node = n
	while p != null:
		if p is Control and (p as Control).has_meta("overlay"):
			return p
		p = p.get_parent()
	return null

static func _in_scroll(n: Node) -> bool:
	var p: Node = n.get_parent()
	while p != null:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false

static func _clip_rect(n: Control) -> Rect2:
	var r: Rect2 = Rect2(-1e6, -1e6, 2e6, 2e6)
	var p: Node = n.get_parent()
	while p != null:
		if p is Control and (p as Control).clip_contents and not (p is ScrollContainer):
			r = r.intersection((p as Control).get_global_rect())
		p = p.get_parent()
	return r

static func _desc(n: Control) -> String:
	var t: String = ""
	if n is Label:
		t = (n as Label).text
	elif n is Button:
		t = (n as Button).text
	return "%s[%s]'%s' @%s" % [n.get_class(), n.name, t.substr(0, 28).replace("\n", " "), str(n.get_global_rect()).replace(" ", "")]

static func check(root: Control) -> Array:
	var issues: Array = []
	var vp: Rect2 = root.get_viewport_rect()
	var nodes: Array = root.find_children("*", "Control", true, false)
	var inter: Array = []
	for nn in nodes:
		var n: Control = nn
		if not n.is_visible_in_tree():
			continue
		var r: Rect2 = n.get_global_rect()
		if r.size.x < 1.0 or r.size.y < 1.0:
			continue
		if not _checkable(n):
			continue
		if _in_scroll(n):
			continue
		# 1. off-screen
		if r.position.x < vp.position.x - 2.0 or r.position.y < vp.position.y - 2.0 or r.end.x > vp.end.x + 2.0 or r.end.y > vp.end.y + 2.0:
			issues.append("OFF-SCREEN " + _desc(n))
			continue
		# 2. overflow out of a container parent
		var par: Node = n.get_parent()
		if par is Container and not (par is ScrollContainer):
			var pr: Rect2 = (par as Control).get_global_rect()
			if r.end.x > pr.end.x + 3.0 or r.end.y > pr.end.y + 3.0 or r.position.x < pr.position.x - 3.0 or r.position.y < pr.position.y - 3.0:
				issues.append("OVERFLOW " + _desc(n) + " outside parent " + str(pr).replace(" ", ""))
				continue
		# 3. clipped away by a clipping ancestor
		var cr: Rect2 = _clip_rect(n)
		if cr.size.x < 1e5 and not cr.encloses(r.grow(-3.0)):
			issues.append("CLIPPED " + _desc(n))
			continue
		# label text wider than its box
		if n is Label:
			var lb: Label = n
			if lb.autowrap_mode == TextServer.AUTOWRAP_OFF and not lb.clip_text and lb.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
				var w: float = lb.get_theme_font("font").get_string_size(lb.text, HORIZONTAL_ALIGNMENT_LEFT, -1, lb.get_theme_font_size("font_size")).x
				if w > r.size.x + 4.0 and not lb.text.contains("\n"):
					issues.append("TEXT-OVERFLOW " + _desc(n))
			elif lb.autowrap_mode == TextServer.AUTOWRAP_OFF and lb.clip_text and lb.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
				var w2: float = lb.get_theme_font("font").get_string_size(lb.text, HORIZONTAL_ALIGNMENT_LEFT, -1, lb.get_theme_font_size("font_size")).x
				if w2 > r.size.x + 4.0 and not lb.text.contains("\n"):
					issues.append("TEXT-CLIPPED " + _desc(n))
		if _interactive(n):
			inter.append(n)
	# 4. overlapping clickable controls
	for i in inter.size():
		for j in range(i + 1, inter.size()):
			var a: Control = inter[i]
			var b: Control = inter[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			if _overlay_root(a) != _overlay_root(b):
				continue
			var ov: Rect2 = a.get_global_rect().intersection(b.get_global_rect())
			if ov.size.x > 3.0 and ov.size.y > 3.0:
				issues.append("OVERLAP " + _desc(a) + " x " + _desc(b))
	return issues
