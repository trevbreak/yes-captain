class_name PersonaCard
extends PanelContainer
## A role card: the persona's portrait, who they are, what the role does, and who's sitting in it.

signal take_pressed(seat: String)
signal leave_pressed(seat: String)

var seat: String = ""
var compact: bool = false
var status_chip: PanelContainer
var action: Button
var ready_badge: Control
var name_lbl: Label
var bot_lbl: Label
var state: String = ""

func _init(seat_name: String, is_compact: bool = false) -> void:
	seat = seat_name
	compact = is_compact

func _ready() -> void:
	var info: Dictionary = K.SEAT_INFO[seat]
	var col: Color = K.pal(str(info.color))
	var st: StyleBoxFlat = UIK.sb(K.pal("card"), UIK.RADIUS, col.darkened(0.05), 3, 0, 10)
	add_theme_stylebox_override("panel", st)
	custom_minimum_size = Vector2(132 if compact else 140, 0)
	var v: VBoxContainer = UIK.vbox(6)
	add_child(v)
	# coloured header with role name + icon
	var head: PanelContainer = PanelContainer.new()
	var hs: StyleBoxFlat = UIK.sb(col, UIK.RADIUS - 2, Color(0, 0, 0, 0), 0, 6, 0)
	hs.corner_radius_bottom_left = 0
	hs.corner_radius_bottom_right = 0
	hs.border_width_bottom = 4
	hs.border_color = col.darkened(0.2)
	head.add_theme_stylebox_override("panel", hs)
	var hh: HBoxContainer = UIK.hbox(6)
	hh.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(hh)
	hh.add_child(UIK.icon_rect(str(info.icon), 20, UIK.text_on(col)))
	hh.add_child(UIK.heading(str(info.name).to_upper(), 17, UIK.text_on(col)))
	v.add_child(head)
	var inner: VBoxContainer = UIK.vbox(4)
	v.add_child(UIK.margin(inner, 8))
	var pr: TextureRect = UIK.portrait(str(info.portrait), 84 if compact else 104)
	pr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(pr)
	var pn: Label = UIK.heading(str(info.persona), 15, K.pal("ink"), 1)
	UIK.wrapped(pn)
	inner.add_child(pn)
	if not compact:
		var tr: Label = UIK.label("\"%s\"" % str(info.trait), 13, K.pal("ink_soft"), 1)
		UIK.wrapped(tr)
		inner.add_child(tr)
		var stars: HBoxContainer = UIK.hbox(2)
		stars.alignment = BoxContainer.ALIGNMENT_CENTER
		for i in 3:
			stars.add_child(UIK.icon_rect("star", 14, K.pal("yellow") if i < int(info.difficulty) else Color(K.pal("ink"), 0.15)))
		inner.add_child(stars)
		var job: Label = UIK.label(str(info.job), 13, K.pal("ink"), 1)
		UIK.wrapped(job)
		job.size_flags_vertical = Control.SIZE_EXPAND_FILL
		inner.add_child(job)
	status_chip = UIK.chip("Open", "neutral", "", 14)
	status_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(status_chip)
	action = UIK.btn("Take role", "green", _on_action)
	action.add_theme_font_size_override("font_size", 16)
	inner.add_child(action)

func _on_action() -> void:
	if state == "mine":
		leave_pressed.emit(seat)
	else:
		take_pressed.emit(seat)

func set_state(new_state: String, who: String = "", ready: bool = false) -> void:
	## new_state: "mine", "taken", "bot", "open"
	state = new_state
	var txt: String = "Open seat"
	var col: String = "neutral"
	match new_state:
		"mine":
			txt = "YOU" + ("  ✔ ready" if ready else "")
			col = "green"
		"taken":
			txt = (who if who.length() <= 12 else who.left(11) + "…") + ("  ✔" if ready else "")
			col = "blue"
		"bot":
			txt = "Robot"
			tooltip_text = "Played by IGOR's relative: " + who
			col = "purple"
	_set_chip(txt, col)
	action.visible = new_state != "taken"
	action.text = "Leave role" if new_state == "mine" else ("Take over" if new_state == "bot" else "Take role")
	UIK.style_btn(action, "neutral" if new_state == "mine" else "green")

func _set_chip(txt: String, col: String) -> void:
	var c: Color = K.pal(col)
	var s: StyleBoxFlat = (status_chip.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	s.bg_color = c
	status_chip.add_theme_stylebox_override("panel", s)
	for l in status_chip.find_children("*", "Label", true, false):
		(l as Label).text = txt
		(l as Label).add_theme_color_override("font_color", UIK.text_on(c))
