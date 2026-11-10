class_name SessionsUI
extends Control
## The Depot: every crew that's open on this server. Join one, or start your own.

signal leave_pressed

var list: VBoxContainer
var empty_lbl: Control
var name_edit: LineEdit
var code_edit: LineEdit
var msg: Label
var who_lbl: Label
var host_btn: Button
var _sig: String = ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIK.bg(self)
	var root: VBoxContainer = UIK.vbox(10)
	var m: MarginContainer = UIK.margin(root, 16)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(m)
	var top: HBoxContainer = UIK.hbox(14)
	root.add_child(top)
	top.add_child(UIK.title("THE DEPOT", 54))
	who_lbl = UIK.label("", 20, K.pal("ink_soft"))
	who_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who_lbl.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(who_lbl)
	var lb: Button = UIK.btn("Back", "red", func(): leave_pressed.emit(), "back", 20)
	lb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(lb)
	var main: HBoxContainer = UIK.hbox(14)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main)
	# open crews
	var ow: Array = UIK.window("CREWS LOOKING FOR HANDS", "blue", "crew")
	ow[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ow[0].size_flags_stretch_ratio = 1.7
	main.add_child(ow[0])
	var sc: ScrollContainer = ScrollContainer.new()
	sc.set_meta("scroll_ok", true)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(ow[1] as VBoxContainer).add_child(sc)
	list = UIK.vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	# start your own
	var right: VBoxContainer = UIK.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(right)
	var hw: Array = UIK.window("START YOUR OWN CREW", "green", "flag")
	right.add_child(hw[0])
	var hb: VBoxContainer = hw[1]
	hb.add_child(UIK.head("CREW NAME", 16, K.pal("ink_soft")))
	name_edit = LineEdit.new()
	name_edit.max_length = 16
	name_edit.placeholder_text = "e.g. The Bin Lids"
	name_edit.text_submitted.connect(func(_t: String): _host())
	hb.add_child(name_edit)
	host_btn = UIK.btn("Open a crew room", "green", _host, "play", 24)
	host_btn.custom_minimum_size = Vector2(0, 58)
	hb.add_child(host_btn)
	hb.add_child(UIK.para("You'll be the host. Friends see your crew here, or you can send them a link.", 17, K.pal("ink_soft")))
	var cw: Array = UIK.window("GOT A CODE?", "mustard", "lock")
	right.add_child(cw[0])
	var cr: HBoxContainer = UIK.hbox(8)
	(cw[1] as VBoxContainer).add_child(cr)
	code_edit = LineEdit.new()
	code_edit.max_length = 4
	code_edit.placeholder_text = "Four letters"
	code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_edit.text_submitted.connect(func(_t2: String): _join_code())
	cr.add_child(code_edit)
	cr.add_child(UIK.btn("Join", "orange", _join_code, "play", 22))
	msg = UIK.para("", 20, UIK.c("red"))
	right.add_child(msg)
	right.add_child(UIK.spacer(true))
	right.add_child(UIK.speech("Pick a crew. Any crew. They are all equally doomed.", "igor", "", 60, 19))

func _host() -> void:
	msg.text = ""
	Net.send("create", {"name": name_edit.text, "career": Progress.local().to_dict()})

func _join_code() -> void:
	var c: String = code_edit.text.strip_edges().to_upper()
	if c.length() != 4:
		msg.text = "A crew code is four letters."
		return
	msg.text = ""
	Net.send("join", {"code": c})

func show_msg(t: String) -> void:
	msg.text = t

func update_rooms(d: Dictionary) -> void:
	who_lbl.text = "Signed in as %s" % str(d.get("you", ""))
	host_btn.disabled = bool(d.get("full", false))
	var rooms: Array = d.get("rooms", [])
	var sig: String = JSON.stringify(rooms)
	if sig == _sig and list.get_child_count() > 0:
		return
	_sig = sig
	for c in list.get_children():
		c.queue_free()
	if rooms.is_empty():
		var e: VBoxContainer = UIK.vbox(8)
		e.add_child(UIK.spacer(false, Vector2(0, 30)))
		var pr: TextureRect = UIK.portrait("igor", 110)
		pr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		e.add_child(pr)
		e.add_child(UIK.head("NOBODY HERE YET", 26, K.pal("ink_soft"), HORIZONTAL_ALIGNMENT_CENTER))
		var p: Label = UIK.para("The depot is empty. IGOR prefers it this way.\nOpen a crew room and spoil it.", 21, K.pal("ink_soft"))
		p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.add_child(p)
		list.add_child(e)
		return
	for r in rooms:
		list.add_child(_row(r))

func _row(r: Dictionary) -> Control:
	var p: PanelContainer = UIK.panel("panel_small", [2, -4, 2, -4])
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h: HBoxContainer = UIK.hbox(10)
	p.add_child(h)
	var code: String = str(r.get("code", ""))
	var badge: PanelContainer = UIK.chip(code, "navy", "", 22)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(badge)
	var v: VBoxContainer = UIK.vbox(-4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var nm: Label = UIK.head(str(r.get("name", "")), 22)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(nm)
	var sub: Label = UIK.label("Host: %s  ·  %s" % [str(r.get("host", "")), str(r.get("doing", ""))], 18, K.pal("ink_soft"))
	sub.clip_text = true
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(sub)
	# who they still need: faces of the empty seats
	var need: HBoxContainer = UIK.hbox(-8)
	need.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for s in (r.get("open", []) as Array).slice(0, 7):
		var f: TextureRect = UIK.portrait(str(s), 34)
		f.modulate = Color(1, 1, 1, 0.55)
		f.tooltip_text = "%s is free" % K.seat_name(str(s))
		f.mouse_filter = Control.MOUSE_FILTER_PASS
		need.add_child(f)
	h.add_child(need)
	var n: int = int(r.get("players", 0))
	var cnt: PanelContainer = UIK.chip("%d / %d" % [n, int(r.get("max", 7))], "green" if n < int(r.get("max", 7)) else "steel", "crew", 18)
	cnt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(cnt)
	var jb: Button = UIK.btn("Join", "green", func(): Net.send("join", {"code": code}), "play", 22)
	jb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(jb)
	return p
