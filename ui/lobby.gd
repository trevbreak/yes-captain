class_name LobbyUI
extends Control
## The Crew Room. Step 1: choose the mission. Step 2: pick your role (the persona cards).
## Then the host takes everyone to the mission briefing, where you ready up and launch.

signal leave_pressed

const KINDS: Array = ["binday", "casual", "mines", "checkpoint", "cake", "ducks", "bees", "drones", "pods", "bastion", "photo", "dock", "fin_haven", "fin_return", "fin_sell"]
const PERS: Array = ["random", "competent", "eager", "literal", "nervous", "sleepy", "knowitall"]
const MODS: Array = [
	["glass", "Glass Ship", "Modules break twice as fast."],
	["newton", "Dampers Broken", "Everything is Newtonian. Forever."],
	["pudding", "Pudding Mode", "Pudding is permanently anxious."],
	["emp", "EMP Storms", "Random stations get inverted controls."],
	["rotation", "Crew Rotation!", "Everyone shifts one seat every 80 seconds."],
	["jargon", "Jargon Mode", "Power calls everything by silly names."],
]
const FAMILY: Dictionary = {
	"Precision": ["helm", "helm"], "Stealth": ["purple", "clock"], "Hazard": ["orange", "warning"], "Bluff": ["blue", "crew"],
	"Odd Job": ["pink", "star"], "Combat": ["red", "weapons"], "Calm": ["green", "pudding"], "Finale": ["navy", "temper"],
}

var step: int = 0
var data: Dictionary = {}
var is_admin: bool = false
var tab_btns: Array = []
var pages: Array = []
var cards: Dictionary = {}
var ai_opts: Dictionary = {}
var run_btn: Button
var shift_btn: Button
var len_btns: Dictionary = {}
var kind_btns: Dictionary = {}
var mod_btns: Dictionary = {}
var pers_opt: OptionButton
var ship_edit: LineEdit
var cta: Button
var wait_lbl: Label
var room_chip: PanelContainer
var roster_box: HBoxContainer
var room_text: String = ""
var hint: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIK.space_bg(self)
	var root: VBoxContainer = UIK.vbox(12)
	var m: MarginContainer = UIK.margin(root, 18)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(m)
	# ---- top bar
	var top: HBoxContainer = UIK.hbox(12)
	root.add_child(top)
	top.add_child(UIK.title("CREW ROOM", 40))
	top.add_child(UIK.spacer(false, Vector2(12, 0)))
	var tabs: HBoxContainer = UIK.hbox(6)
	top.add_child(tabs)
	for i in 2:
		var b: Button = UIK.btn(["1   Choose a mission", "2   Pick your role"][i], "neutral", _set_step.bind(i), ["map", "crew"][i])
		tabs.add_child(b)
		tab_btns.append(b)
	top.add_child(UIK.spacer(true))
	room_chip = UIK.chip("", "purple", "crew", 15)
	room_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(room_chip)
	top.add_child(UIK.btn("Leave", "red", func(): leave_pressed.emit(), "back"))
	# ---- pages
	var pages_box: Control = Control.new()
	pages_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(pages_box)
	var mission: Control = _build_mission_page()
	var crew: Control = _build_crew_page()
	for pg in [mission, crew]:
		pg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pages_box.add_child(pg)
		pages.append(pg)
	# ---- footer
	var foot: PanelContainer = UIK.panel("card", 8, 18)
	root.add_child(foot)
	var fh: HBoxContainer = UIK.hbox(10)
	foot.add_child(fh)
	fh.add_child(UIK.heading("In the room:", 16))
	roster_box = UIK.hbox(6)
	roster_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fh.add_child(roster_box)
	wait_lbl = UIK.label("", 16, K.pal("ink_soft"))
	fh.add_child(wait_lbl)
	cta = UIK.btn("Next: pick your role", "green", _on_cta, "play")
	cta.custom_minimum_size = Vector2(300, 0)
	fh.add_child(cta)
	_set_step(0)

# ---------------------------------------------------------------- page 1: mission

func _build_mission_page() -> Control:
	var h: HBoxContainer = UIK.hbox(14)
	# The Run
	var w: Array = UIK.window("THE RUN  (story)", "purple", "map", 14)
	(w[0] as Control).custom_minimum_size = Vector2(330, 0)
	h.add_child(w[0])
	var b: VBoxContainer = w[1]
	var faces: HBoxContainer = UIK.hbox(-10)
	faces.alignment = BoxContainer.ALIGNMENT_CENTER
	for pn in ["overlord", "pudding", "thrupp"]:
		faces.add_child(UIK.portrait(pn, 86))
	b.add_child(faces)
	b.add_child(UIK.wrapped(UIK.label("You collected a skip. The skip was warm. Inside: Pudding, the Overlord's beloved pet. Get Pudding to safety across the sector map, with the whole Hegemony fleet on your tail.", 15)))
	var lr: HBoxContainer = UIK.hbox(6)
	b.add_child(lr)
	for pair in [["short", "Quick (~15 min)"], ["full", "Full (~45 min)"]]:
		var lb: Button = UIK.toggle_btn(pair[1], "neutral", func(_on: bool): Net.send("opt", {"key": "length", "val": pair[0]}))
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lr.add_child(lb)
		len_btns[pair[0]] = lb
	b.add_child(UIK.spacer(true))
	run_btn = UIK.toggle_btn("Play The Run", "purple", func(_on: bool): Net.send("opt", {"key": "mode", "val": "run"}), "play")
	b.add_child(run_btn)
	# Shift Work
	var w2: Array = UIK.window("SHIFT WORK  (single missions)", "orange", "clock", 14)
	(w2[0] as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(w2[0])
	var b2: VBoxContainer = w2[1]
	b2.add_child(UIK.wrapped(UIK.label("Pick any mission and play it on its own. Instant retries. Great for learning a role.", 15)))
	var g: GridContainer = UIK.grid(3, 6, 6)
	b2.add_child(g)
	for k in KINDS:
		var info: Dictionary = Encounters.INFO[k]
		var fam: Array = FAMILY.get(str(info.family), ["blue", "star"])
		var kb: Button = UIK.toggle_btn(str(info.name), "neutral", func(_on: bool): _pick_kind(k), str(fam[1]))
		kb.tooltip_text = "%s: %s" % [info.family, info.blurb]
		kb.add_theme_font_size_override("font_size", 14)
		kb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		kb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kb.custom_minimum_size = Vector2(150, 44)
		g.add_child(kb)
		kind_btns[k] = kb
	b2.add_child(UIK.spacer(true))
	shift_btn = UIK.toggle_btn("Play Shift Work", "orange", func(_on: bool): Net.send("opt", {"key": "mode", "val": "shift"}), "play")
	b2.add_child(shift_btn)
	# Options
	var w3: Array = UIK.window("HOUSE RULES", "blue", "star", 14)
	(w3[0] as Control).custom_minimum_size = Vector2(300, 0)
	h.add_child(w3[0])
	var b3: VBoxContainer = w3[1]
	b3.add_child(UIK.heading("Party modifiers", 16))
	var mg: GridContainer = UIK.grid(2, 6, 6)
	b3.add_child(mg)
	for mk in MODS:
		var mid: String = mk[0]
		var mb: Button = UIK.toggle_btn(mk[1], "neutral", func(on: bool): _toggle_mod(mid, on))
		mb.tooltip_text = mk[2]
		mb.add_theme_font_size_override("font_size", 14)
		mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mg.add_child(mb)
		mod_btns[mid] = mb
	b3.add_child(UIK.heading("Robot crew personality", 16))
	pers_opt = OptionButton.new()
	for p in PERS:
		pers_opt.add_item("Random (funniest)" if p == "random" else str(Bot.PERSONALITIES[p].name))
	pers_opt.item_selected.connect(func(i: int): Net.send("opt", {"key": "personality", "val": PERS[i]}))
	b3.add_child(pers_opt)
	b3.add_child(UIK.heading("Ship name", 16))
	ship_edit = LineEdit.new()
	ship_edit.text = "Second Opinion"
	ship_edit.text_submitted.connect(func(tx: String): Net.send("opt", {"key": "ship_name", "val": tx}))
	ship_edit.focus_exited.connect(func(): Net.send("opt", {"key": "ship_name", "val": ship_edit.text}))
	b3.add_child(ship_edit)
	return h

func _pick_kind(k: String) -> void:
	Net.send("opt", {"key": "shift_kind", "val": k})
	Net.send("opt", {"key": "mode", "val": "shift"})

func _toggle_mod(id: String, on: bool) -> void:
	var cur: Array = data.get("mods", []).duplicate()
	if on and not (id in cur):
		cur.append(id)
	elif not on:
		cur.erase(id)
	Net.send("opt", {"key": "mods", "val": cur})

# ---------------------------------------------------------------- page 2: crew

func _build_crew_page() -> Control:
	var v: VBoxContainer = UIK.vbox(8)
	hint = UIK.wrapped(UIK.label("Click a role to take it. Short on friends? Take several roles and switch between them in-game with 1-7. Empty seats can be filled by IGOR's robot relatives.", 15, Color(1, 1, 1, 0.85)))
	v.add_child(hint)
	var row: HBoxContainer = UIK.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)
	for s in K.SEATS:
		var col: VBoxContainer = UIK.vbox(6)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var pc: PersonaCard = PersonaCard.new(s)
		pc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		pc.take_pressed.connect(func(seat: String): Net.send("claim", {"seat": seat}))
		pc.leave_pressed.connect(func(seat: String): Net.send("release", {"seat": seat}))
		col.add_child(pc)
		cards[s] = pc
		var opt: OptionButton = OptionButton.new()
		opt.fit_to_longest_item = false
		opt.clip_text = true
		opt.custom_minimum_size = Vector2(120, 0)
		if s == "captain":
			opt.add_item("Human captain")
			opt.add_item("AI captain")
			opt.item_selected.connect(func(i: int): Net.send("opt", {"key": "ai_captain", "val": i == 1}))
		else:
			opt.add_item("Empty if no human")
			opt.set_item_metadata(0, "")
			for k in Bot.PERSONALITIES.keys():
				if k == "grovelling" and not RunState.load_defected():
					continue
				opt.add_item("AI: " + str(Bot.PERSONALITIES[k].name))
				opt.set_item_metadata(opt.item_count - 1, k)
			opt.item_selected.connect(func(i: int): _set_ai(s, opt.get_item_metadata(i)))
		col.add_child(opt)
		ai_opts[s] = opt
	return v

func _set_ai(seat: String, kind: Variant) -> void:
	if str(kind) == "":
		Net.send("opt", {"key": "bot_on", "val": {"seat": seat, "on": false}})
	else:
		Net.send("opt", {"key": "bot_on", "val": {"seat": seat, "on": true}})
		Net.send("opt", {"key": "bot_kind", "val": {"seat": seat, "kind": str(kind)}})

# ---------------------------------------------------------------- state

func _set_step(i: int) -> void:
	step = i
	for j in pages.size():
		pages[j].visible = j == i
	for j2 in tab_btns.size():
		UIK.style_btn(tab_btns[j2], "yellow" if j2 == i else "neutral")
	_update_cta()

func _on_cta() -> void:
	if step == 0:
		_set_step(1)
	elif is_admin:
		Net.send("start", {})

func _update_cta() -> void:
	if cta == null:
		return
	if step == 0:
		cta.text = "Next: pick your role"
		cta.disabled = false
		wait_lbl.text = ""
	else:
		cta.text = "Go to the mission briefing" if is_admin else "Waiting for the host"
		cta.disabled = not is_admin or not _captain_ok()
		wait_lbl.text = "" if _captain_ok() else "Someone needs to be captain (or pick 'AI captain')."

func _captain_ok() -> bool:
	var seats: Dictionary = data.get("seats", {})
	return int(seats.get("captain", {}).get("owner", 0)) != 0 or bool(data.get("ai_captain", false))

func set_addresses(listening: bool, port: int) -> void:
	if not listening:
		room_text = "Solo: robots only"
	else:
		var ips: Array = []
		for a in IP.get_local_addresses():
			var s: String = str(a)
			if s.count(".") == 3 and not s.begins_with("127.") and not s.begins_with("169.254"):
				ips.append(s)
		room_text = "Join: %s : %d" % [ips[0] if not ips.is_empty() else "this computer", port]
	for l in room_chip.find_children("*", "Label", true, false):
		(l as Label).text = room_text

func update_lobby(d: Dictionary) -> void:
	data = d
	is_admin = (Net.is_host and not Net.dedicated) or int(Net.my_id) == int(d.get("admin", -1))
	if room_text == "" and not Net.is_host:
		for l in room_chip.find_children("*", "Label", true, false):
			(l as Label).text = "Connected"
	var seats: Dictionary = d.get("seats", {})
	for s in K.SEATS:
		var sd: Dictionary = seats.get(s, {})
		var owner: int = int(sd.get("owner", 0))
		var pc: PersonaCard = cards[s]
		if owner == Net.my_id:
			pc.set_state("mine")
		elif owner != 0:
			pc.set_state("taken", str(sd.get("owner_name", "someone")))
		elif s == "captain" and bool(d.get("ai_captain", false)):
			pc.set_state("bot", "Captain")
		elif bool(sd.get("bot", false)):
			pc.set_state("bot", str(Bot.PERSONALITIES.get(sd.get("kind", "competent"), {}).get("name", "Robot")))
		else:
			pc.set_state("open")
		var opt: OptionButton = ai_opts[s]
		opt.disabled = not is_admin
		if s == "captain":
			opt.select(1 if bool(d.get("ai_captain", false)) else 0)
		else:
			var want: String = str(sd.get("kind", "competent")) if bool(sd.get("bot_on", true)) else ""
			for i in opt.item_count:
				if str(opt.get_item_metadata(i)) == want:
					if opt.selected != i:
						opt.select(i)
	var mode: String = str(d.get("mode", "run"))
	run_btn.set_pressed_no_signal(mode == "run")
	shift_btn.set_pressed_no_signal(mode == "shift")
	for k in len_btns.keys():
		len_btns[k].set_pressed_no_signal(str(d.get("length", "full")) == k)
	for k2 in kind_btns.keys():
		kind_btns[k2].set_pressed_no_signal(mode == "shift" and str(d.get("shift_kind", "")) == k2)
	for mid in mod_btns.keys():
		mod_btns[mid].set_pressed_no_signal(mid in d.get("mods", []))
	pers_opt.select(maxi(0, PERS.find(d.get("personality", "random"))))
	if not ship_edit.has_focus():
		ship_edit.text = str(d.get("ship_name", "Second Opinion"))
	for c in [run_btn, shift_btn, pers_opt, ship_edit] + len_btns.values() + kind_btns.values() + mod_btns.values():
		if c is BaseButton:
			(c as BaseButton).disabled = not is_admin
		elif c is LineEdit:
			(c as LineEdit).editable = is_admin
	for ch in roster_box.get_children():
		ch.queue_free()
	for pid in d.get("peers", {}).keys():
		var pl: Dictionary = d.peers[pid]
		roster_box.add_child(UIK.chip(str(pl.name) + (" (you)" if int(pid) == Net.my_id else ""), "blue" if int(pid) != Net.my_id else "green", "crew", 14))
	_update_cta()
