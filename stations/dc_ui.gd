class_name DamageControlUI
extends StationUI

var sch: Schematic
var info: Label
var task_box: VBoxContainer
var task_sig: String = ""
var con_box: VBoxContainer
var con_sig: String = ""
var con_labels: Dictionary = {}
var selected: String = ""
var mods_by_id: Dictionary = {}

func build() -> void:
	side.get_parent().visible = false
	var h: HBoxContainer = UIK.hbox(12)
	add_body(h)
	var sw: Array = UIK.window("THE SHIP  (front is up · click a module)", "dc", "dc", 8)
	h.add_child(sw[0])
	sch = Schematic.new()
	sch.picked.connect(func(id: String): selected = id)
	(sw[1] as VBoxContainer).add_child(sch)
	var right: VBoxContainer = UIK.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	var mw: Array = UIK.window("SELECTED MODULE", "orange", "dc", 10)
	right.add_child(mw[0])
	info = UIK.wrapped(UIK.label("Pick a module on the left.", 16))
	(mw[1] as VBoxContainer).add_child(info)
	task_box = UIK.vbox(6)
	(mw[1] as VBoxContainer).add_child(task_box)
	var cw: Array = UIK.window("CONDUITS  (power cables)", "purple", "power", 10)
	(cw[0] as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(cw[0])
	con_box = UIK.vbox(6)
	(cw[1] as VBoxContainer).add_child(con_box)
	(cw[1] as VBoxContainer).add_child(UIK.wrapped(UIK.label("Order of work: fire, then breach, then the module. Splicing a cable zaps you unless Power isolates it first. Shout at Power.", 13, K.pal("ink_soft"))))

func _task_button(target: String, task: Dictionary) -> Button:
	var b: Button
	if task.get("mash", false):
		b = UIK.btn("Kick it! (click fast)", "orange", func(): send("click", {"target": target}), "dc")
	else:
		b = UIK.hold_btn("Hold: %s" % task.label, "green", func(on: bool): send("hold", {"target": target, "on": on}), "dc")
	b.disabled = readonly
	b.custom_minimum_size = Vector2(0, 52)
	return b

func refresh() -> void:
	var mods: Array = view.get("mods", [])
	var cons: Dictionary = view.get("cons", {})
	sch.mods = mods
	sch.cons = cons
	sch.selected = selected
	sch.pud_at = str(view.get("pud_at", ""))
	mods_by_id.clear()
	for m in mods:
		mods_by_id[m.id] = m
	var sm: Dictionary = mods_by_id.get(selected, {})
	if sm.is_empty():
		info.text = "Pick a module on the left. While you're down here, your own station is unattended."
		_set_tasks("", {})
	else:
		var st: String = ["healthy", "rattling", "faulted", "FAILED"][int(sm.state)]
		var extra: String = ""
		if sm.fire:
			extra += " On fire."
		if sm.breach:
			extra += " Breached (vents like a thruster)."
		if sm.nopower:
			extra += " No power: check cable %s." % str(sm.conduit).substr(2)
		if str(sm.fault) != "":
			extra += " Fault: %s." % str(sm.fault).replace("_", " ")
		info.text = "%s: %s, %d%%.%s\nLooked after by: %s" % [sm.label, st, int(sm.hp), extra, K.seat_name(str(sm.owner)) if str(sm.owner) != "" else "nobody"]
		_set_tasks(selected, sm.task)
	var sig: String = ""
	for c in K.CONDUITS:
		var cd: Dictionary = cons.get(c, {})
		sig += "%s:%s:%s:%s|" % [c, cd.get("cut", false), cd.get("unknown", false), cd.get("hidden_cut", false)]
	if sig != con_sig:
		con_sig = sig
		for ch in con_box.get_children():
			ch.queue_free()
		con_labels.clear()
		for c2 in K.CONDUITS:
			var cd2: Dictionary = cons.get(c2, {})
			var row: VBoxContainer = UIK.vbox(4)
			var l: Label = UIK.wrapped(UIK.label("", 15))
			row.add_child(l)
			con_labels[c2] = l
			if cd2.get("cut", false):
				row.add_child(_task_button("con:" + c2, cd2.task))
			elif cd2.get("hidden_cut", false) and not cd2.get("trace", {}).is_empty():
				var tb: Button = _task_button("trc:" + c2, cd2.trace)
				tb.text = "Hold: trace the hidden break"
				row.add_child(tb)
			con_box.add_child(row)
	for c3 in K.CONDUITS:
		var cd3: Dictionary = cons.get(c3, {})
		var state: String = "ok"
		if cd3.get("cut", false):
			state = "CUT! %s  ·  splice %d%%" % ["isolated, safe" if cd3.iso else "LIVE: ask Power to isolate", int(float(cd3.work) * 100.0)]
		elif cd3.get("unknown", false):
			state = "??? something's wrong down this line"
		if con_labels.has(c3):
			con_labels[c3].text = "Cable %s: %s%s" % [c3.substr(2), state, "  ZZZAP!" if float(cd3.get("zap", 0.0)) > 1.5 else ""]
			con_labels[c3].add_theme_color_override("font_color", K.pal("red") if cd3.get("cut", false) or cd3.get("unknown", false) else K.pal("ink"))

func _set_tasks(id: String, task: Dictionary) -> void:
	var sig: String = id + str(task.get("kind", ""))
	if sig == task_sig:
		return
	task_sig = sig
	for c in task_box.get_children():
		c.queue_free()
	if id != "" and not task.is_empty():
		task_box.add_child(_task_button("mod:" + id, task))
	elif id != "":
		task_box.add_child(UIK.label("Nothing to fix here. Lovely.", 15, K.pal("green").darkened(0.3)))
