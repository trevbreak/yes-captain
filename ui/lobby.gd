class_name LobbyUI
extends Control
## The Crew Room: choose a mission from the career (each one adds one new thing), pick your seats, go.

signal leave_pressed

var room_chip: PanelContainer
var mission_list: VBoxContainer
var mission_rows: Dictionary = {}
var seat_cards: Dictionary = {}
var cta: Button
var wait_lbl: Label
var who_lbl: Label
var _last: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIK.bg(self)
	var root: VBoxContainer = UIK.vbox(10)
	var m: MarginContainer = UIK.margin(root, 16)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(m)
	var top: HBoxContainer = UIK.hbox(14)
	root.add_child(top)
	top.add_child(UIK.title("CREW ROOM", 54))
	top.add_child(UIK.spacer(true))
	room_chip = UIK.chip("", "steel", "crew", 18)
	room_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(room_chip)
	var lb: Button = UIK.btn("Leave", "red", func(): leave_pressed.emit(), "back", 20)
	lb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(lb)
	var main: HBoxContainer = UIK.hbox(14)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main)
	# career
	var cw: Array = UIK.window("THE CAREER", "red", "flag")
	cw[0].custom_minimum_size = Vector2(380, 0)
	main.add_child(cw[0])
	var sc: ScrollContainer = ScrollContainer.new()
	sc.set_meta("scroll_ok", true)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(cw[1] as VBoxContainer).add_child(sc)
	mission_list = UIK.vbox(6)
	mission_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(mission_list)
	for id in Missions.ORDER:
		var b: Button = UIK.toggle("", "mustard", func(_on: bool): Net.send("opt", {"key": "mission", "val": id}), "", 20)
		b.custom_minimum_size = Vector2(0, 58)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mission_list.add_child(b)
		mission_rows[id] = b
	# crew
	var crw: Array = UIK.window("PICK YOUR SEATS", "blue", "crew")
	crw[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(crw[0])
	var cb: VBoxContainer = crw[1]
	cb.add_child(UIK.para("Click a seat to take it. Short on friends? Take several and switch with keys 1-7. IGOR's robot relatives fill empty seats.", 19))
	var g: GridContainer = UIK.grid(3, 10)
	g.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cb.add_child(g)
	for s in K.SEATS:
		var card: SeatCard = SeatCard.new(s)
		g.add_child(card)
		seat_cards[s] = card
	# footer
	var foot: HBoxContainer = UIK.hbox(12)
	root.add_child(foot)
	who_lbl = UIK.label("", 20, K.pal("ink_soft"))
	who_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(who_lbl)
	wait_lbl = UIK.label("", 20, K.pal("ink_soft"))
	foot.add_child(wait_lbl)
	cta = UIK.btn("TO THE BRIEFING", "green", func(): Net.send("start"), "play", 26)
	cta.custom_minimum_size = Vector2(320, 64)
	foot.add_child(cta)

func set_addresses(listening: bool, port: int) -> void:
	if not listening:
		UIK.set_chip(room_chip, "Solo: robots only", "steel")
		return
	var ips: Array = []
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254"):
			ips.append(a)
	UIK.set_chip(room_chip, "Friends join: %s:%d" % [ips[0] if not ips.is_empty() else "this computer", port], "blue")

func update_lobby(d: Dictionary) -> void:
	_last = d
	var me: int = Net.my_id
	var is_admin: bool = int(d.get("admin", 0)) == me
	var cur: String = str(d.get("mission", "lesson"))
	for mi in d.get("missions", []):
		var b: Button = mission_rows.get(str(mi.id))
		if b == null:
			continue
		var stars: String = "★".repeat(int(mi.stars)) + "☆".repeat(3 - int(mi.stars))
		if bool(mi.unlocked):
			b.text = "%d. %s   %s\n     new: %s" % [int(mi.num), str(mi.title).to_upper(), stars, str(mi.new)]
			b.icon = null
		else:
			b.text = "%d. ???   (locked)" % int(mi.num)
			b.icon = Art.tex("icon_lock", 20.0 / 64.0)
		b.add_theme_font_size_override("font_size", 17)
		b.disabled = not bool(mi.unlocked) or not is_admin
		b.set_pressed_no_signal(str(mi.id) == cur)
	var seats: Dictionary = d.get("seats", {})
	var names: Array = []
	for pid in d.get("peers", {}).keys():
		var p: Dictionary = d.peers[pid]
		if not bool(p.get("gone", false)):
			names.append(str(p.name) + (" (you)" if int(pid) == me else ""))
	who_lbl.text = "In the room: " + ", ".join(PackedStringArray(names))
	for s in seat_cards.keys():
		(seat_cards[s] as SeatCard).update(seats.get(s, {}), me, is_admin)
	cta.visible = is_admin
	wait_lbl.text = "" if is_admin else "Waiting for the host to start..."
	var info: Dictionary = Missions.INFO.get(cur, {})
	cta.text = "MISSION %d: TO THE BRIEFING" % int(info.get("num", 1))

class SeatCard extends PanelContainer:
	var seat: String
	var status: PanelContainer
	var action: Button
	var robot: Button
	var _state: String = ""

	func _init(s: String) -> void:
		seat = s

	func _ready() -> void:
		add_theme_stylebox_override("panel", Art.box("panel_small", Color.WHITE, [-8, -6, -8, -8]))
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h: HBoxContainer = UIK.hbox(6)
		add_child(h)
		var pr: TextureRect = UIK.portrait(seat, 76)
		pr.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		pr.tooltip_text = "%s\n\"%s\"\n%s" % [K.persona(seat), K.SEAT_INFO[seat].trait, K.SEAT_INFO[seat].job]
		pr.mouse_filter = Control.MOUSE_FILTER_PASS
		h.add_child(pr)
		var v: VBoxContainer = UIK.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		var top: HBoxContainer = UIK.hbox(4)
		v.add_child(top)
		var nm: Label = UIK.head(K.seat_name(seat).to_upper(), 20, K.seat_color(seat).darkened(0.25))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(nm)
		status = UIK.chip("Open", "cream", "", 14)
		top.add_child(status)
		var pn: Label = UIK.label(K.persona(seat), 16, K.pal("ink_soft"))
		pn.clip_text = true
		pn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		pn.custom_minimum_size = Vector2(150, 0)
		v.add_child(pn)
		var br: HBoxContainer = UIK.hbox(4)
		v.add_child(br)
		action = UIK.btn("Take", "green", _act, "", 17)
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		br.add_child(action)
		if seat != "captain":
			robot = UIK.toggle("", "steel", func(on: bool): Net.send("opt", {"key": "bot_on", "val": {"seat": seat, "on": on}}), "robot", 17)
			robot.tooltip_text = "Fill with a robot when nobody takes this seat"
			br.add_child(robot)

	func _act() -> void:
		Net.send("release" if _state == "mine" else "claim", {"seat": seat})

	func update(d: Dictionary, me: int, is_admin: bool) -> void:
		var owner: int = int(d.get("owner", 0))
		if owner == me:
			_state = "mine"
			UIK.set_chip(status, "YOU", "green")
		elif owner != 0:
			_state = "taken"
			var n: String = str(d.get("owner_name", "?"))
			UIK.set_chip(status, n if n.length() < 12 else n.left(11) + "…", "blue")
		elif bool(d.get("bot", false)):
			_state = "bot"
			UIK.set_chip(status, "ROBOT", "steel")
		else:
			_state = "open"
			UIK.set_chip(status, "EMPTY", "cream")
		action.visible = _state != "taken"
		action.text = "Leave" if _state == "mine" else "Take"
		UIK.style_btn(action, "cream" if _state == "mine" else "green")
		if robot != null:
			robot.set_pressed_no_signal(bool(d.get("bot_on", true)))
			robot.disabled = not is_admin
