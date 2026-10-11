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
	side.visible = false
	var h: HBoxContainer = UIK.hbox(14)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(h)
	sch = Schematic.new()
	sch.picked.connect(func(id: String): selected = id)
	h.add_child(sch)
	var right: VBoxContainer = UIK.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	info = UIK.label("Pick a module on the left.", 18)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(info)
	task_box = UIK.vbox(6)
	right.add_child(task_box)
	right.add_child(HSeparator.new())
	right.add_child(UIK.label("CONDUITS: power runs through these. Cut ones darken everything downstream.", 15))
	con_box = UIK.vbox(6)
	right.add_child(con_box)
	var tip: Label = UIK.label("Fix the fire first, then the breach, then the module itself. Conduit splices zap you unless Power ISOLATES the conduit. Shout at Power.", 14, Color(K.pal("ink"), 0.75))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(tip)

func _task_button(target: String, task: Dictionary) -> Button:
	var b: Button
	if task.get("mash", false):
		b = UIK.btn("KICK IT!  (click fast)", "mustard")
		b.pressed.connect(func(): send("click", {"target": target}))
	else:
		b = UIK.btn("HOLD: %s" % task.label, "mint")
		b.button_down.connect(func(): send("hold", {"target": target, "on": true}))
		b.button_up.connect(func(): send("hold", {"target": target, "on": false}))
	b.disabled = readonly
	b.custom_minimum_size = Vector2(0, 54)
	return b

func refresh() -> void:
	title_lbl.text = "DAMAGE CONTROL"
	var mods: Array = view.get("mods", [])
	var cons: Dictionary = view.get("cons", {})
	sch.mods = mods
	sch.cons = cons
	sch.selected = selected
	sch.pud_at = str(view.get("pud_at", ""))
	mods_by_id.clear()
	for m in mods:
		mods_by_id[m.id] = m
	# selected module
	var sm: Dictionary = mods_by_id.get(selected, {})
	if sm.is_empty():
		info.text = "Pick a module on the left. Leaving your post to fix things means your own station drifts. Choose wisely."
		_set_tasks("", {})
	else:
		var st: String = ["healthy", "rattling", "faulted", "FAILED"][int(sm.state)]
		var extra: String = ""
		if sm.fire:
			extra += "  ON FIRE."
		if sm.breach:
			extra += "  BREACHED (vents like a thruster)."
		if sm.nopower:
			extra += "  No power: check its conduit (%s)." % sm.conduit
		if str(sm.fault) != "":
			extra += "  Fault: %s." % str(sm.fault).replace("_", " ")
		info.text = "%s: %s, %d%% hull.%s\nOwner: %s" % [sm.label, st, int(sm.hp), extra, K.seat_name(str(sm.owner)) if str(sm.owner) != "" else "nobody"]
		_set_tasks(selected, sm.task)
	# conduits
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
			var row: VBoxContainer = UIK.vbox(2)
			var l: Label = UIK.label("", 15)
			row.add_child(l)
			con_labels[c2] = l
			if cd2.get("cut", false):
				var bt: Button = _task_button("con:" + c2, cd2.task)
				row.add_child(bt)
			elif cd2.get("hidden_cut", false) and not cd2.get("trace", {}).is_empty():
				var tb: Button = _task_button("trc:" + c2, cd2.trace)
				tb.text = "HOLD: TRACE for a hidden break"
				row.add_child(tb)
			con_box.add_child(row)
	for c3 in K.CONDUITS:
		var cd3: Dictionary = cons.get(c3, {})
		var state: String = "OK"
		if cd3.get("cut", false):
			state = "CUT!  %s  Splice: %d%%" % ["(isolated, safe)" if cd3.iso else "NOT ISOLATED - ask Power!", int(float(cd3.work) * 100.0)]
		elif cd3.get("unknown", false):
			state = "??? something's wrong downstream (Sensors can run an internal scan)"
		if con_labels.has(c3):
			con_labels[c3].text = "%s: %s" % [c3, state]
			if float(cd3.get("zap", 0.0)) > 1.5:
				con_labels[c3].text += "  ZZZAP incoming!"

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
		task_box.add_child(UIK.label("Nothing to fix here. Lovely.", 16))
