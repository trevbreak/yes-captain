extends Control
## Prototype: the v3 kit on paper, for art review.

func _ready() -> void:
	theme = UIK.theme()
	add_child(Paper.new())
	var m: MarginContainer = UIK.margin(UIK.hbox(20), 24)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(m)
	var row: HBoxContainer = m.get_child(0)
	var left: VBoxContainer = UIK.vbox(18)
	left.custom_minimum_size = Vector2(560, 0)
	row.add_child(left)
	left.add_child(UIK.title("YES, CAPTAIN!", 64))
	var w: Array = UIK.window("MISSION 1: DRIVING LESSON", "red", "")
	left.add_child(w[0])
	var b: VBoxContainer = w[1]
	b.add_child(UIK.speech("IGOR will explain. Slowly. For the meat. You fly through three rings. Do not hit them. They are expensive.", "igor", "IGOR", 88))
	var br: HBoxContainer = UIK.hbox(12)
	b.add_child(br)
	br.add_child(UIK.btn("I'M READY", "green", Callable(), ""))
	br.add_child(UIK.btn("Leave", "red"))
	br.add_child(UIK.btn("Options", "cream"))
	var chips: HBoxContainer = UIK.hbox(8)
	left.add_child(chips)
	for cc in [["HULL 100%", "red"], ["PUDDING: CALM", "pink"], ["HOT!", "orange"], ["OK", "green"], ["BROKEN", "ink"]]:
		chips.add_child(UIK.chip(cc[0], cc[1]))
	var right: VBoxContainer = UIK.vbox(16)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var g: GridContainer = UIK.grid(4, 10)
	right.add_child(g)
	for n in ["captain", "helm", "engines", "weapons", "sensors", "shields", "engineer", "igor"]:
		g.add_child(UIK.portrait(n, 132))
	var w2: Array = UIK.window("ENGINES", "orange", "")
	right.add_child(w2[0])
	(w2[1] as VBoxContainer).add_child(UIK.para("Big Sal Throttleby. Set the speed with the throttle. You can't see where you're going.", 22))
	var w3: Array = UIK.window("THE CHART", "navy", "", "panel_dark")
	w3[0].size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(w3[0])
	(w3[1] as VBoxContainer).add_child(UIK.label("dark panel for night things", 22, UIK.c("cream")))
	add_child(Film.new())
