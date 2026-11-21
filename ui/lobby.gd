class_name LobbyUI
extends Control
## The Crew Room: the host chooses what to fly, everyone takes one of the four seats, readies up, and
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
var hard_btn: Button
var igor_lbl: Label
var mission_rows: Dictionary = {}
var seat_cards: Dictionary = {}
var people: HBoxContainer
var cta: Button
var wait_lbl: Label
var _last: Dictionary = {}
var _people_sig: String = ""
var _addr: String = ""
var main_box: BoxContainer
var seat_grid: GridContainer
var foot_box: BoxContainer
var flying_win: Control
var seats_win: Control
var join_box: PanelContainer
var qr_pic: TextureRect
var join_url_lbl: Label
var join_code_lbl: Label
var join_how: Label
var _qr_sig: String = ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIK.bg(self)
	var root: VBoxContainer = UIK.vbox(8)
	var m: MarginContainer = UIK.margin(root, 14)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(m)
	# ---- top
	var top: HFlowContainer = HFlowContainer.new()
	top.add_theme_constant_override("h_separation", 10)
	top.add_theme_constant_override("v_separation", 6)
	root.add_child(top)
	title_lbl = UIK.title("CREW ROOM", 46)
	top.add_child(title_lbl)
	room_chip = UIK.chip("", "steel", "crew", 18)
	room_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(room_chip)
	voice_btn = UIK.toggle("Voice chat", "purple", func(on: bool): Net.send("opt", {"key": "voice", "val": on}), "speaker", 18)
	voice_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	voice_btn.tooltip_text = "On: everyone's microphone is live, for crews in different places.\nOff: you're all in the same room. Just shout."
	top.add_child(voice_btn)
	top.add_child(Voice.Bar.new())
	var lb: Button = UIK.btn("Leave", "red", func():
		UIK.confirm(self, "LEAVE THE CREW?", "Your seat goes to a robot. You can come back with the invite link.", "Leave", func(): leave_pressed.emit()), "back", 18)
	lb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(lb)
	# ---- main
	var main: BoxContainer = BoxContainer.new()
	main.add_theme_constant_override("separation", 12)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main)
	main_box = main
	var cw: Array = UIK.window("WHAT ARE WE FLYING?", "red", "flag")
	cw[0].custom_minimum_size = Vector2(340, 0)
	main.add_child(cw[0])
	flying_win = cw[0]
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
	hard_btn = UIK.toggle("Hard mode", "red", func(on: bool): Net.send("opt", {"key": "hard", "val": on}), "fire", 18)
	hard_btn.tooltip_text = "Off: a steady pace with time to talk, and no comms dial or torpedoes on the Shift.\nOn: the comms dial, torpedoes and weak spots, and trouble arrives twice as fast."
	cwb.add_child(hard_btn)
	# ---- seats
	var crw: Array = UIK.window("TAKE A SEAT", "blue", "crew")
	crw[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(crw[0])
	seats_win = crw[0]
	var cb: VBoxContainer = crw[1]
	cb.add_theme_constant_override("separation", 8)
	var tip: Label = UIK.para("Four seats: the Captain and three crew. The Captain looks ahead and touches nothing, the Tech sees all round; each crew role works two stations on one screen. Fewer than four of you? Robots take the empty roles.", 18, K.pal("ink_soft"))
	cb.add_child(tip)
	var cards: GridContainer = GridContainer.new()
	cards.columns = 4
	cards.add_theme_constant_override("h_separation", 10)
	cards.add_theme_constant_override("v_separation", 10)
	cb.add_child(cards)
	seat_grid = cards
	for r in K.CREW:
		var card: SeatCard = SeatCard.new(str(r))
		cards.add_child(card)
		seat_cards[r] = card
	# ---- how to get in: big enough to read from the sofa, and a code to scan
	join_box = UIK.panel("panel_small", [6, 4, 6, 4])
	join_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cb.add_child(join_box)
	var jr: HBoxContainer = UIK.hbox(18)
	jr.alignment = BoxContainer.ALIGNMENT_CENTER
	join_box.add_child(jr)
	qr_pic = TextureRect.new()
	qr_pic.custom_minimum_size = Vector2(170, 170)
	qr_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	qr_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	qr_pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	qr_pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	jr.add_child(qr_pic)
	var jv: VBoxContainer = UIK.vbox(2)
	jv.alignment = BoxContainer.ALIGNMENT_CENTER
	jr.add_child(jv)
	join_how = UIK.head("SCAN TO JOIN, OR GO TO", 17, K.pal("ink_soft"))
	jv.add_child(join_how)
	join_url_lbl = UIK.head("", 22)
	jv.add_child(join_url_lbl)
	jv.add_child(UIK.head("AND TYPE THE CODE", 17, K.pal("ink_soft")))
	join_code_lbl = UIK.title("", 72, UIK.c("red"))
	jv.add_child(join_code_lbl)
	invite_btn = UIK.btn("Copy invite link", "mustard", _copy_invite, "flag", 18)
	invite_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	invite_btn.tooltip_text = "Copy a link your friends can open to land in this crew room"
	jv.add_child(invite_btn)
	var sp: HBoxContainer = UIK.speech("", "igor", "IGOR", 62, 19)
	igor_lbl = sp.find_child("text", true, false)
	cb.add_child(sp)
	# ---- footer
	var foot: BoxContainer = BoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	foot.custom_minimum_size = Vector2(0, 60)
	root.add_child(foot)
	foot_box = foot
	people = UIK.hbox(6)
	people.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	people.clip_contents = true
	foot.add_child(people)
	wait_lbl = UIK.label("", 19, K.pal("ink_soft"), HORIZONTAL_ALIGNMENT_RIGHT)
	wait_lbl.clip_text = true
	wait_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	wait_lbl.custom_minimum_size = Vector2(240, 0)
	foot.add_child(wait_lbl)
	cta = UIK.btn("START", "green", func(): Net.send("start"), "play", 24)
	cta.custom_minimum_size = Vector2(300, 56)
	foot.add_child(cta)

func set_portrait(p: bool) -> void:
	## a phone held upright: seats first (that's what a guest is here for), then the mission, all in one column
	main_box.vertical = p
	foot_box.vertical = p
	seat_grid.columns = 2 if p else 4
	main_box.move_child(seats_win, 0 if p else 1)
	flying_win.custom_minimum_size = Vector2(0, 420) if p else Vector2(340, 0)
	qr_pic.custom_minimum_size = Vector2(130, 130) if p else Vector2(170, 170)

func _update_join(code: String) -> void:
	## the big code and the QR code of the invite link
	var url: String = Web.invite_link(code) if code != "" else ""
	join_box.visible = code != "" or _addr != ""
	if code != "":
		join_url_lbl.text = Web.site_name() if Web.site_name() != "" else "this server's address"
		join_code_lbl.text = code
		join_how.text = "SCAN TO JOIN, OR GO TO"
		qr_pic.visible = true
	else:
		join_url_lbl.text = _addr
		join_code_lbl.text = ""
		join_how.text = "ON THIS NETWORK, JOIN A SERVER AT"
		qr_pic.visible = false
	if url != _qr_sig:
		_qr_sig = url
		var q: Qr = Qr.make(url) if url != "" else null
		qr_pic.texture = ImageTexture.create_from_image(q.to_image(4, 3)) if q != null else null

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
	invite_btn.text = "COPY INVITE LINK" if code != "" else "COPY ADDRESS"
	_update_join(code)
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
	var hard: bool = bool(d.get("hard", false))
	hard_btn.set_pressed_no_signal(hard)
	hard_btn.text = "HARD MODE: ON" if hard else "HARD MODE: OFF"
	hard_btn.mouse_filter = Control.MOUSE_FILTER_STOP if is_admin else Control.MOUSE_FILTER_IGNORE
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
		shift_blurb.text = "Every job is dealt at random: a task, a place and a snag or two, from everything in the game. The ship glitches as you go. Pick from the job board, fly it, get paid. The board has an easy job, a middling one and a spicy one." \
			+ (" HARD MODE: radio calls, torpedoes, and no time to breathe." if hard else "")
		shift_cards.text = "The whole deck: %d glitches, %d places, %d snags. No two shifts alike." % [Glitches.DEFS.size(), Deck.PLACES.size(), Deck.TWISTS.size()]
	else:
		shift_blurb.text = "Jobs are dealt from your deck: a task, a place and a snag or two. The ship glitches as you go. Pick from the job board, fly it, get paid. Every finished shift adds one new card."
		shift_cards.text = "Your deck: %d of %d cards.\nNewest: %s" % [int(sh.get("cards", 0)), int(sh.get("of", 0)), ", ".join(PackedStringArray(latest))]
	shift_lock.text = "" if bool(sh.get("open", false)) else "Fly %d training missions to open the Shift." % int(sh.get("needs", 2))
	igor_lbl.text = str(d.get("igor", ""))
	var seats: Dictionary = d.get("seats", {})
	for r in seat_cards.keys():
		# a role's two stations always go together, so its first station speaks for it
		(seat_cards[r] as SeatCard).update(seats.get(str(K.role_seats(str(r))[0]), {}), me, is_admin)
	# practice on your own: IGOR takes the Captain's chair if you don't
	if bool(d.get("robot_captain", false)):
		var cc: SeatCard = seat_cards["captain"]
		if cc._state == "open":
			UIK.set_chip(cc.status, "IGOR", "steel")
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
	cta.text = "START THE SHIFT" if mode == "shift" else "START MISSION %d" % int(info.get("num", 1))
	cta.disabled = prob != ""
	if is_admin:
		wait_lbl.text = prob
	elif my_seats.is_empty():
		wait_lbl.text = "Take a seat (or just watch)."
	else:
		wait_lbl.text = "You're in. Waiting for the host to start..."

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
	## one of the four seats: the Captain, or a crew role (two stations, one player)
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
		var v: VBoxContainer = UIK.vbox(4)
		add_child(v)
		var faces: HBoxContainer = UIK.hbox(-12)
		faces.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(faces)
		var pr: TextureRect = UIK.portrait(K.role_face(seat), 64)
		pr.tooltip_text = K.role_persona(seat)
		pr.mouse_filter = Control.MOUSE_FILTER_PASS
		faces.add_child(pr)
		var nm: Label = UIK.head(K.role_name(seat).to_upper(), 21, UIK.c(K.role_color(seat)).darkened(0.25), HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(nm)
		var sub: String = "Sees ahead. Touches nothing." if seat == "captain" else \
			"%s + %s" % [K.seat_name(str(K.role_seats(seat)[0])), K.seat_name(str(K.role_seats(seat)[1]))]
		v.add_child(UIK.label(sub, 15, K.pal("ink_soft"), HORIZONTAL_ALIGNMENT_CENTER))
		status = UIK.chip("Open", "cream", "", 13)
		status.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(status)
		v.add_child(UIK.spacer(false))
		var br: HBoxContainer = UIK.hbox(4)
		v.add_child(br)
		action = UIK.btn("Take", "green", _act, "", 17)
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		br.add_child(action)
		if seat != "captain":
			robot = UIK.toggle("", "steel", func(on: bool): Net.send("opt", {"key": "bot_on", "val": {"seat": seat, "on": on}}), "robot", 17)
			robot.tooltip_text = "Fill with a robot when nobody takes this role"
			robot.custom_minimum_size = Vector2(64, 0)
			br.add_child(robot)
		var tip: String = str(K.SEAT_INFO["captain"].job) if seat == "captain" else "%s\n%s" % [K.role_persona(seat), str(K.ROLES[seat].blurb)]
		tooltip_text = tip

	func _act() -> void:
		if _state == "mine":
			Net.send("release", {"seat": seat})
		else:
			# one seat each: taking this one gives up whatever you had
			Net.send("release_all")
			Net.send("claim", {"seat": seat})

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
