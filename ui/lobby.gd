class_name LobbyUI
extends Control
## The Crew Room: the host chooses what to fly, everyone takes a seat (or a pair of seats), readies up, and
## the host says go.

signal leave_pressed

var title_lbl: Label
var room_chip: PanelContainer
var invite_btn: Button
var voice_btn: Button
var mission_list: VBoxContainer
var train_tab: Button
var shift_tab: Button
var train_box: Control
var shift_box: VBoxContainer
var shift_info: Label
var shift_cards: Label
var shift_blurb: Label
var shift_lock: Label
var skip_btn: Button
var igor_lbl: Label
var mission_rows: Dictionary = {}
var seat_cards: Dictionary = {}
var pair_btns: Dictionary = {}
var people: HBoxContainer
var ready_btn: Button
var cta: Button
var wait_lbl: Label
var _last: Dictionary = {}
var _people_sig: String = ""
var _addr: String = ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIK.bg(self)
	var root: VBoxContainer = UIK.vbox(8)
	var m: MarginContainer = UIK.margin(root, 14)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(m)
	# ---- top
	var top: HBoxContainer = UIK.hbox(10)
	root.add_child(top)
	title_lbl = UIK.title("CREW ROOM", 46)
	top.add_child(title_lbl)
	top.add_child(UIK.spacer(true))
	room_chip = UIK.chip("", "steel", "crew", 18)
	room_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(room_chip)
	invite_btn = UIK.btn("Copy invite", "mustard", _copy_invite, "flag", 18)
	invite_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	invite_btn.tooltip_text = "Copy a link your friends can open to land in this crew room"
	top.add_child(invite_btn)
	voice_btn = UIK.toggle("Voice chat", "purple", func(on: bool): Net.send("opt", {"key": "voice", "val": on}), "speaker", 18)
	voice_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	voice_btn.tooltip_text = "On: everyone's microphone is live, for crews in different places.\nOff: you're all in the same room. Just shout."
	top.add_child(voice_btn)
	top.add_child(Voice.Bar.new())
	var lb: Button = UIK.btn("Leave", "red", func(): leave_pressed.emit(), "back", 18)
	lb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(lb)
	# ---- main
	var main: HBoxContainer = UIK.hbox(12)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main)
	var cw: Array = UIK.window("WHAT ARE WE FLYING?", "red", "flag")
	cw[0].custom_minimum_size = Vector2(340, 0)
	main.add_child(cw[0])
	var cwb: VBoxContainer = cw[1]
	cwb.add_theme_constant_override("separation", 6)
	var tabs: HBoxContainer = UIK.hbox(6)
	cwb.add_child(tabs)
	train_tab = UIK.toggle("Training", "mustard", func(_on: bool): Net.send("opt", {"key": "mode", "val": "career"}), "", 18)
	train_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	train_tab.tooltip_text = "Ten missions. Each one teaches ONE new thing."
	tabs.add_child(train_tab)
	shift_tab = UIK.toggle("The Shift", "purple", func(_on: bool): Net.send("opt", {"key": "mode", "val": "shift"}), "", 18)
	shift_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shift_tab.tooltip_text = "Three jobs dealt from your deck, and rent to make. Never the same twice."
	tabs.add_child(shift_tab)
	var sc: ScrollContainer = ScrollContainer.new()
	sc.set_meta("scroll_ok", true)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cwb.add_child(sc)
	train_box = sc
	mission_list = UIK.vbox(4)
	mission_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(mission_list)
	for id in Missions.ORDER:
		var row: MissionRow = MissionRow.new(id)
		mission_list.add_child(row)
		mission_rows[id] = row
	skip_btn = UIK.btn("Skip training: open everything", "cream", func(): Net.send("opt", {"key": "unlock_all"}), "lock", 14)
	skip_btn.tooltip_text = "For crews who already know the ropes. Opens all ten missions and the Shift."
	mission_list.add_child(skip_btn)
	shift_box = UIK.vbox(8)
	shift_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shift_box.visible = false
	cwb.add_child(shift_box)
	shift_box.add_child(UIK.head("THREE JOBS. MAKE THE RENT.", 22, UIK.c("purple").darkened(0.2)))
	shift_blurb = UIK.para("", 18)
	shift_box.add_child(shift_blurb)
	shift_info = UIK.para("", 20)
	shift_box.add_child(shift_info)
	shift_cards = UIK.para("", 17, K.pal("ink_soft"))
	shift_box.add_child(shift_cards)
	shift_lock = UIK.para("", 20, UIK.c("red"))
	shift_box.add_child(shift_lock)
	# ---- seats
	var crw: Array = UIK.window("TAKE A SEAT", "blue", "crew")
	crw[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(crw[0])
	var cb: VBoxContainer = crw[1]
	cb.add_theme_constant_override("separation", 8)
	var caprow: HBoxContainer = UIK.hbox(12)
	cb.add_child(caprow)
	var cap: SeatCard = SeatCard.new("captain")
	cap.custom_minimum_size = Vector2(300, 0)
	cap.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	caprow.add_child(cap)
	seat_cards["captain"] = cap
	var tip: Label = UIK.para("The Captain sees everything and touches nothing. Everyone else gets one station. Small crew? Take a PAIR and flip between its two screens. Robots fill whatever is left.", 18, K.pal("ink_soft"))
	tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	caprow.add_child(tip)
	var cols: HBoxContainer = UIK.hbox(10)
	cb.add_child(cols)
	for pair in K.PAIRS:
		var col: VBoxContainer = UIK.vbox(6)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(col)
		var pb: Button = UIK.btn("%s: take both" % str(pair.name), "cream", func(): _take_pair(pair), "", 17)
		pb.tooltip_text = "%s: one player, two screens. Press F in the game to flip." % str(pair.blurb)
		col.add_child(pb)
		pair_btns[pair.id] = pb
		for s in pair.seats:
			var card: SeatCard = SeatCard.new(str(s))
			col.add_child(card)
			seat_cards[s] = card
	cb.add_child(UIK.spacer(true))
	var sp: HBoxContainer = UIK.speech("", "igor", "IGOR", 62, 19)
	igor_lbl = sp.find_child("text", true, false)
	cb.add_child(sp)
	# ---- footer
	var foot: HBoxContainer = UIK.hbox(10)
	foot.custom_minimum_size = Vector2(0, 60)
	root.add_child(foot)
	people = UIK.hbox(6)
	people.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	people.clip_contents = true
	foot.add_child(people)
	wait_lbl = UIK.label("", 19, K.pal("ink_soft"), HORIZONTAL_ALIGNMENT_RIGHT)
	wait_lbl.clip_text = true
	wait_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	wait_lbl.custom_minimum_size = Vector2(240, 0)
	foot.add_child(wait_lbl)
	ready_btn = UIK.toggle("I'm ready", "green", func(on: bool): Net.send("lobby_ready", {"on": on}), "check", 24)
	ready_btn.custom_minimum_size = Vector2(190, 56)
	foot.add_child(ready_btn)
	cta = UIK.btn("START", "green", func(): Net.send("start"), "play", 24)
	cta.custom_minimum_size = Vector2(300, 56)
	foot.add_child(cta)

func set_addresses(listening: bool, port: int) -> void:
	## a game hosted on this computer (not a server room)
	_addr = ""
	if not listening:
		return
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254"):
			_addr = "%s:%d" % [a, port]
			break

func _copy_invite() -> void:
	var code: String = str(_last.get("room", {}).get("code", ""))
	Web.copy(Web.invite_link(code) if code != "" else _addr)
	wait_lbl.text = "Copied! Paste it to your friends."

func _take_pair(pair: Dictionary) -> void:
	var me: int = Net.my_id
	var seats: Dictionary = _last.get("seats", {})
	var mine: bool = true
	for s in pair.seats:
		if int(seats.get(s, {}).get("owner", 0)) != me:
			mine = false
	if mine:
		for s2 in pair.seats:
			Net.send("release", {"seat": s2})
	else:
		Net.send("claim", {"seats": pair.seats})

func update_lobby(d: Dictionary) -> void:
	_last = d
	var me: int = Net.my_id
	var is_admin: bool = int(d.get("admin", 0)) == me
	var cur: String = str(d.get("mission", "lesson"))
	var room: Dictionary = d.get("room", {})
	var code: String = str(room.get("code", ""))
	if code != "":
		title_lbl.text = str(room.get("name", "CREW ROOM"))
		UIK.set_chip(room_chip, "CODE " + code, "navy")
	elif _addr != "":
		title_lbl.text = "CREW ROOM"
		UIK.set_chip(room_chip, "JOIN AT " + _addr, "blue")
	else:
		title_lbl.text = "CREW ROOM"
		UIK.set_chip(room_chip, "ROBOT CREW", "steel")
	invite_btn.visible = code != "" or _addr != ""
	invite_btn.text = "COPY INVITE" if code != "" else "COPY ADDRESS"
	voice_btn.visible = code != ""
	voice_btn.mouse_filter = Control.MOUSE_FILTER_STOP if is_admin else Control.MOUSE_FILTER_IGNORE
	voice_btn.set_pressed_no_signal(bool(d.get("voice", false)))
	voice_btn.text = "VOICE CHAT: ON" if bool(d.get("voice", false)) else "VOICE CHAT: OFF"
	var mode: String = str(d.get("mode", "career"))
	var sh: Dictionary = d.get("shift", {})
	var all_open: bool = true
	for mi in d.get("missions", []):
		var row: MissionRow = mission_rows.get(str(mi.id))
		if row != null:
			row.update(mi, str(mi.id) == cur and mode == "career", is_admin)
		if not bool(mi.unlocked):
			all_open = false
	skip_btn.visible = is_admin and not all_open
	train_tab.set_pressed_no_signal(mode == "career")
	shift_tab.set_pressed_no_signal(mode == "shift")
	train_tab.mouse_filter = Control.MOUSE_FILTER_STOP if is_admin else Control.MOUSE_FILTER_IGNORE
	shift_tab.mouse_filter = Control.MOUSE_FILTER_STOP if is_admin else Control.MOUSE_FILTER_IGNORE
	shift_tab.disabled = not bool(sh.get("open", false))
	shift_tab.text = "THE SHIFT" if bool(sh.get("open", false)) else "THE SHIFT (LOCKED)"
	train_box.visible = mode != "shift"
	shift_box.visible = mode == "shift"
	shift_info.text = "Rent due: £%d\nShifts flown: %d     Best takings: £%d" % [int(sh.get("rent", 0)), int(sh.get("shifts", 0)), int(sh.get("best", 0))]
	var latest: Array = sh.get("latest", [])
	if bool(sh.get("full", false)):
		shift_blurb.text = "Every job is dealt at random: a task, a place and a snag or two, from everything in the game. The ship glitches as you go. Pick from the job board, fly it, get paid. The board has an easy job, a middling one and a spicy one."
		shift_cards.text = "The whole deck: %d glitches, %d places, %d snags. No two shifts alike." % [Glitches.DEFS.size(), Deck.PLACES.size(), Deck.TWISTS.size()]
	else:
		shift_blurb.text = "Jobs are dealt from your deck: a task, a place and a snag or two. The ship glitches as you go. Pick from the job board, fly it, get paid. Every finished shift adds one new card."
		shift_cards.text = "Your deck: %d of %d cards.\nNewest: %s" % [int(sh.get("cards", 0)), int(sh.get("of", 0)), ", ".join(PackedStringArray(latest))]
	shift_lock.text = "" if bool(sh.get("open", false)) else "Fly %d training missions to open the Shift." % int(sh.get("needs", 2))
	igor_lbl.text = str(d.get("igor", ""))
	var seats: Dictionary = d.get("seats", {})
	for s in seat_cards.keys():
		(seat_cards[s] as SeatCard).update(seats.get(s, {}), me, is_admin)
	for pair in K.PAIRS:
		var pb: Button = pair_btns[pair.id]
		var mine: int = 0
		var free: int = 0
		for s2 in pair.seats:
			var o: int = int(seats.get(s2, {}).get("owner", 0))
			mine += int(o == me)
			free += int(o == 0 or o == me)
		pb.text = ("%s: LEAVE BOTH" if mine == 2 else "%s: TAKE BOTH") % str(pair.name).to_upper()
		pb.disabled = free < 2
		UIK.style_btn(pb, "mustard" if mine == 2 else "cream")
	# who's here
	var peers: Dictionary = d.get("peers", {})
	var sig: String = JSON.stringify(peers) + str(is_admin) + str(d.get("admin", 0))
	if sig != _people_sig:
		_people_sig = sig
		for c in people.get_children():
			c.queue_free()
		for pid in peers.keys():
			var p: Dictionary = peers[pid]
			if bool(p.get("gone", false)):
				continue
			var boss: bool = int(pid) == int(d.get("admin", 0))
			var okay: bool = boss or bool(p.get("ready", false))
			var nm: String = str(p.name) + (" (you)" if int(pid) == me else "")
			var chip: PanelContainer = UIK.chip(nm, "green" if okay else "cream", "captain" if boss else ("check" if okay else "clock"), 16)
			chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			chip.tooltip_text = "The host" if boss else ("Ready" if okay else "Not ready yet")
			chip.mouse_filter = Control.MOUSE_FILTER_PASS
			people.add_child(chip)
			if is_admin and int(pid) != me:
				var kb: Button = UIK.btn("", "red", func(): Net.send("kick", {"peer": int(pid)}), "x", 12)
				kb.tooltip_text = "Send %s home" % str(p.name)
				kb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				people.add_child(kb)
	# ready / start
	var my_seats: Array = peers.get(me, {}).get("seats", [])
	var prob: String = str(d.get("problem", ""))
	var info: Dictionary = Missions.INFO.get(cur, {})
	cta.visible = is_admin
	ready_btn.visible = not is_admin
	ready_btn.disabled = my_seats.is_empty()
	var am_ready: bool = bool(peers.get(me, {}).get("ready", false))
	ready_btn.set_pressed_no_signal(am_ready)
	ready_btn.text = "READY!" if am_ready else "I'M READY"
	cta.text = "START THE SHIFT" if mode == "shift" else "START MISSION %d" % int(info.get("num", 1))
	cta.disabled = prob != ""
	if is_admin:
		wait_lbl.text = prob
	elif my_seats.is_empty():
		wait_lbl.text = "Take a seat (or just watch)."
	elif not am_ready:
		wait_lbl.text = "Press ready when you are."
	else:
		wait_lbl.text = "Waiting for the host to start..."

class MissionRow extends Button:
	## one mission in the training list: number, title, what's new, and the stars earned
	var id: String
	var stars_box: HBoxContainer
	var _sig: String = ""

	func _init(mid: String) -> void:
		id = mid

	func _ready() -> void:
		toggle_mode = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(0, 54)
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_theme_font_override("font", UIK.font("head"))
		add_theme_font_size_override("font_size", 16)
		UIK.style_btn(self, "cream")
		var on_n: InkBox = Art.box("btn_mustard_pressed")
		add_theme_stylebox_override("pressed", on_n)
		add_theme_stylebox_override("hover_pressed", on_n)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		stars_box = UIK.hbox(0)
		stars_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stars_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		stars_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		stars_box.grow_vertical = Control.GROW_DIRECTION_BOTH
		stars_box.offset_right = -16
		add_child(stars_box)
		pressed.connect(func(): Net.send("opt", {"key": "mission", "val": id}))

	func update(mi: Dictionary, current: bool, is_admin: bool) -> void:
		var open: bool = bool(mi.unlocked)
		var sig: String = "%s/%d/%s" % [open, int(mi.stars), is_admin]
		set_pressed_no_signal(current)
		if sig == _sig:
			return
		_sig = sig
		# guests see the host's choice lit up, they just can't change it
		disabled = not open
		mouse_filter = Control.MOUSE_FILTER_STOP if is_admin else Control.MOUSE_FILTER_IGNORE
		if open:
			text = "%d. %s\nNEW: %s" % [int(mi.num), str(mi.title).to_upper(), str(mi.new).to_upper()]
			icon = null
		else:
			text = "%d. LOCKED" % int(mi.num)
			icon = Art.tex("icon_lock", 20.0 / 64.0)
		for c in stars_box.get_children():
			c.queue_free()
		if open:
			for i in 3:
				stars_box.add_child(UIK.icon("star", 20, UIK.c("red") if i < int(mi.stars) else Color(UIK.ink(), 0.2)))

class SeatCard extends PanelContainer:
	var seat: String
	var status: PanelContainer
	var action: Button
	var robot: Button
	var _state: String = ""

	func _init(s: String) -> void:
		seat = s

	func _ready() -> void:
		add_theme_stylebox_override("panel", Art.box("panel_small", Color.WHITE, [-8, -8, -8, -10]))
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h: HBoxContainer = UIK.hbox(6)
		add_child(h)
		var pr: TextureRect = UIK.portrait(seat, 64)
		pr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pr.tooltip_text = "%s\n\"%s\"\n%s" % [K.persona(seat), K.SEAT_INFO[seat].trait, K.SEAT_INFO[seat].job]
		pr.mouse_filter = Control.MOUSE_FILTER_PASS
		h.add_child(pr)
		var v: VBoxContainer = UIK.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		var top: HBoxContainer = UIK.hbox(4)
		v.add_child(top)
		var nm: Label = UIK.head(K.seat_name(seat), 19, K.seat_color(seat).darkened(0.25))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(nm)
		status = UIK.chip("Open", "cream", "", 13)
		top.add_child(status)
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
		var owner_id: int = int(d.get("owner", 0))
		if owner_id == me:
			_state = "mine"
			UIK.set_chip(status, "YOU", "green")
		elif owner_id != 0:
			_state = "taken"
			var n: String = str(d.get("owner_name", "?"))
			UIK.set_chip(status, n if n.length() < 11 else n.left(10) + "…", "blue")
		elif bool(d.get("bot", false)):
			_state = "bot"
			UIK.set_chip(status, "ROBOT", "steel")
		else:
			_state = "open"
			UIK.set_chip(status, "NOBODY" if seat == "captain" else "EMPTY", "red" if seat == "captain" else "cream")
		action.disabled = _state == "taken"
		action.text = "LEAVE" if _state == "mine" else ("TAKEN" if _state == "taken" else "TAKE")
		UIK.style_btn(action, "cream" if _state != "open" and _state != "bot" else "green")
		if robot != null:
			robot.set_pressed_no_signal(bool(d.get("bot_on", true)))
			robot.disabled = not is_admin
