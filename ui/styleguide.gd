class_name StyleGuide
extends Control
## Visual reference for the design system (run with: godot --path . -- --styleguide).

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIK.space_bg(self)
	var root: VBoxContainer = UIK.vbox(12)
	add_child(UIK.margin(root, 18))
	(get_child(get_child_count() - 1) as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(UIK.title("YES, CAPTAIN!  design system", 34))
	var row: HBoxContainer = UIK.hbox(12)
	root.add_child(row)
	for s in K.SEATS:
		var pc: PersonaCard = PersonaCard.new(s)
		row.add_child(pc)
		match s:
			"captain":
				pc.set_state.call_deferred("mine", "", true)
			"helm":
				pc.set_state.call_deferred("taken", "Alex", true)
			"engines":
				pc.set_state.call_deferred("bot", "Eager")
			_:
				pc.set_state.call_deferred("open")
	var row2: HBoxContainer = UIK.hbox(12)
	root.add_child(row2)
	var w: Array = UIK.window("MISSION BRIEFING", "blue", "map")
	row2.add_child(w[0])
	(w[0] as Control).custom_minimum_size = Vector2(420, 0)
	(w[1] as VBoxContainer).add_child(UIK.speech("Skip is alive. IGOR does not collect alive things. This is not in IGOR's job.", "igor", "IGOR"))
	var bh: HBoxContainer = UIK.hbox(8)
	(w[1] as VBoxContainer).add_child(bh)
	bh.add_child(UIK.btn("READY", "green", Callable(), "check"))
	bh.add_child(UIK.btn("Back", "neutral", Callable(), "back"))
	bh.add_child(UIK.icon_btn("menu", "neutral"))
	var w2: Array = UIK.window("BUTTONS", "orange", "star")
	row2.add_child(w2[0])
	var g: GridContainer = UIK.grid(3, 8, 8)
	(w2[1] as VBoxContainer).add_child(g)
	for col in ["green", "blue", "orange", "red", "yellow", "purple", "neutral", "helm", "weapons"]:
		g.add_child(UIK.btn(col.capitalize(), col))
	var dis: Button = UIK.btn("Disabled", "green")
	dis.disabled = true
	g.add_child(dis)
	var w3: Array = UIK.window("CHIPS & BADGES", "purple", "crew")
	row2.add_child(w3[0])
	var ch: HFlowContainer = HFlowContainer.new()
	(w3[1] as VBoxContainer).add_child(ch)
	ch.add_child(UIK.chip("Hull 92%", "red", "hull"))
	ch.add_child(UIK.chip("Fuel 6", "orange", "fuel"))
	ch.add_child(UIK.chip("Scrap 40", "yellow", "scrap"))
	ch.add_child(UIK.chip("Peeved", "purple", "temper"))
	var bb: HBoxContainer = UIK.hbox(8)
	(w3[1] as VBoxContainer).add_child(bb)
	for ic in ["helm", "engines", "power", "weapons", "sensors", "ops", "dc"]:
		bb.add_child(UIK.badge(ic, ic, 40))
	(w3[1] as VBoxContainer).add_child(UIK.wrapped(UIK.label("Body text is Nunito Bold. Headings are Fredoka SemiBold. Never black outlines: borders are a darker shade of the fill.", 15), 300))
