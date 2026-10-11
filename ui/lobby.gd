class_name LobbyUI
extends Control
## The pre-flight lobby: claim seats, fill the rest with IGOR's relatives, pick a mode, launch.

signal leave_pressed

var seat_rows: Dictionary = {}
var info_lbl: Label
var mode_opt: OptionButton
var length_opt: OptionButton
var kind_opt: OptionButton
var aicap_btn: Button
var pers_opt: OptionButton
var ship_edit: LineEdit
var start_btn: Button
var roster: Label
var addr_lbl: Label
var is_admin: bool = false
var data: Dictionary = {}
var building: bool = false

const KINDS: Array = ["binday", "casual", "mines", "checkpoint", "cake", "ducks", "bees", "drones", "pods", "bastion", "photo", "dock", "fin_haven", "fin_return", "fin_sell"]
const MODS: Array = [
	["glass", "Glass Ship", "Modules break twice as fast."],
	["newton", "Dampers Broken", "Everything is Newtonian. Forever."],
	["pudding", "Pudding Mode", "Pudding is permanently anxious."],
	["emp", "EMP Storms", "Random stations get inverted controls."],
	["rotation", "Crew Rotation!", "Everyone shifts one seat every 80 seconds."],
	["jargon", "Jargon Mode", "Power calls everything by silly names."],
]
var mod_btns: Dictionary = {}
const PERS: Array = ["random", "competent", "eager", "literal", "nervous", "sleepy", "knowitall"]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIK.bg_color(self, K.pal("plum"))
	var m: MarginContainer = MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 24)
	add_child(m)
	var root: VBoxContainer = UIK.vbox(10)
	m.add_child(root)
	var hr: HBoxContainer = UIK.hbox(10)
	root.add_child(hr)
	hr.add_child(UIK.label("PRE-FLIGHT LOBBY", 34, K.pal("butter")))
	hr.add_child(UIK.spacer(true))
	hr.add_child(UIK.btn("Leave", "coral", func(): leave_pressed.emit()))
	var body: HBoxContainer = UIK.hbox(14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	# seats
	var left: PanelContainer = UIK.panel("cream", 12, 22)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	var lv: VBoxContainer = UIK.vbox(6)
	left.add_child(lv)
	lv.add_child(UIK.label("SEATS  (take several if you're short on friends: tab between them with 1-7)", 17))
	for seat in K.SEATS:
		var row: PanelContainer = UIK.panel(K.SEAT_INFO[seat].color, 6, 14)
		var h: HBoxContainer = UIK.hbox(8)
		row.add_child(h)
		var nv: VBoxContainer = UIK.vbox(0)
		nv.custom_minimum_size = Vector2(290, 0)
		h.add_child(nv)
		nv.add_child(UIK.label(K.seat_name(seat).to_upper(), 20))
		var bl: Label = UIK.label(str(K.SEAT_INFO[seat].blurb), 13)
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nv.add_child(bl)
		var who: Label = UIK.label("", 17)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(who)
		var claim: Button = UIK.btn("Take seat", "cream", func(): _claim(seat))
		h.add_child(claim)
		var bot_t: Button = UIK.toggle_btn("AI fills", "mint", func(on: bool): Net.send("opt", {"key": "bot_on", "val": {"seat": seat, "on": on}}))
		if seat == "captain":
			bot_t.visible = false
		h.add_child(bot_t)
		var kind: OptionButton = OptionButton.new()
		for k in Bot.PERSONALITIES.keys():
			if k == "grovelling" and not RunState.load_defected():
				continue
			kind.add_item(Bot.PERSONALITIES[k].name)
			kind.set_item_metadata(kind.item_count - 1, k)
		kind.item_selected.connect(func(i: int): Net.send("opt", {"key": "bot_kind", "val": {"seat": seat, "kind": kind.get_item_metadata(i)}}))
		_fit(kind)
		kind.size_flags_horizontal = Control.SIZE_SHRINK_END
		kind.custom_minimum_size = Vector2(150, 0)
		if seat == "captain":
			kind.visible = false
		h.add_child(kind)
		lv.add_child(row)
		seat_rows[seat] = {"who": who, "claim": claim, "bot": bot_t, "kind": kind}
	# settings
	var right: VBoxContainer = UIK.vbox(10)
	right.custom_minimum_size = Vector2(350, 0)
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	body.add_child(right)
	var sp: PanelContainer = UIK.panel("cream", 12, 22)
	right.add_child(sp)
	var sv: VBoxContainer = UIK.vbox(6)
	sp.add_child(sv)
	sv.add_child(UIK.label("MISSION", 20))
	mode_opt = OptionButton.new()
	mode_opt.add_item("The Run: save Pudding (story)")
	mode_opt.add_item("Shift Work: single encounters")
	mode_opt.item_selected.connect(func(i: int): Net.send("opt", {"key": "mode", "val": "run" if i == 0 else "shift"}))
	sv.add_child(_fit(mode_opt))
	length_opt = OptionButton.new()
	length_opt.add_item("Quick run (~15 min)")
	length_opt.add_item("Full run (~45 min)")
	length_opt.item_selected.connect(func(i: int): Net.send("opt", {"key": "length", "val": "short" if i == 0 else "full"}))
	sv.add_child(_fit(length_opt))
	kind_opt = OptionButton.new()
	for k2 in KINDS:
		kind_opt.add_item(str(Encounters.INFO[k2].name))
	kind_opt.item_selected.connect(func(i: int): Net.send("opt", {"key": "shift_kind", "val": KINDS[i]}))
	sv.add_child(_fit(kind_opt))
	aicap_btn = UIK.toggle_btn("AI Captain (orders as text cards)", "mint", func(on: bool): Net.send("opt", {"key": "ai_captain", "val": on}))
	sv.add_child(aicap_btn)
	sv.add_child(UIK.label("Party modifiers:", 15))
	var mg: GridContainer = UIK.grid(2, 4, 4)
	sv.add_child(mg)
	for mk in MODS:
		var mid: String = mk[0]
		var mb: Button = UIK.toggle_btn(mk[1], "butter", func(on: bool): _toggle_mod(mid, on))
		mb.tooltip_text = mk[2]
		mb.add_theme_font_size_override("font_size", 14)
		mg.add_child(mb)
		mod_btns[mid] = mb
	sv.add_child(UIK.label("AI crew personalities:", 15))
	pers_opt = OptionButton.new()
	for p in PERS:
		pers_opt.add_item(p.capitalize() if p != "random" else "Random (funnier)")
	pers_opt.item_selected.connect(func(i: int): Net.send("opt", {"key": "personality", "val": PERS[i]}))
	sv.add_child(_fit(pers_opt))
	sv.add_child(UIK.label("Ship name:", 15))
	ship_edit = LineEdit.new()
	ship_edit.text = "Second Opinion"
	ship_edit.text_submitted.connect(func(t: String): Net.send("opt", {"key": "ship_name", "val": t}))
	ship_edit.focus_exited.connect(func(): Net.send("opt", {"key": "ship_name", "val": ship_edit.text}))
	sv.add_child(ship_edit)
	start_btn = UIK.btn("LAUNCH!", "green", func(): Net.send("start", {}))
	start_btn.custom_minimum_size = Vector2(0, 64)
	right.add_child(start_btn)
	var ip: PanelContainer = UIK.panel("cream2", 10, 16)
	right.add_child(ip)
	var iv: VBoxContainer = UIK.vbox(4)
	ip.add_child(iv)
	addr_lbl = UIK.label("", 15)
	addr_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	iv.add_child(addr_lbl)
	roster = UIK.label("", 15)
	roster.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	iv.add_child(roster)
	info_lbl = UIK.label("", 15, K.pal("butter"))
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(info_lbl)

func _fit(o: OptionButton) -> OptionButton:
	o.fit_to_longest_item = false
	o.clip_text = true
	o.custom_minimum_size = Vector2(0, 0)
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return o

func _toggle_mod(id: String, on: bool) -> void:
	var cur: Array = data.get("mods", []).duplicate()
	if on and not (id in cur):
		cur.append(id)
	elif not on:
		cur.erase(id)
	Net.send("opt", {"key": "mods", "val": cur})

func _claim(seat: String) -> void:
	var d: Dictionary = data.get("seats", {}).get(seat, {})
	if int(d.get("owner", 0)) == Net.my_id:
		Net.send("release", {"seat": seat})
	else:
		Net.send("claim", {"seat": seat})

func set_addresses(listening: bool, port: int) -> void:
	if not listening:
		addr_lbl.text = "Solo mode: nobody can join this game."
		return
	var ips: Array = []
	for a in IP.get_local_addresses():
		var s: String = str(a)
		if s.count(".") == 3 and not s.begins_with("127.") and not s.begins_with("169.254"):
			ips.append(s)
	addr_lbl.text = "Friends join with:  %s   port %d" % [", ".join(ips) if not ips.is_empty() else "your IP", port]

func update_lobby(d: Dictionary) -> void:
	data = d
	is_admin = (Net.is_host and not Net.dedicated) or int(Net.my_id) == int(d.get("admin", -1))
	var seats: Dictionary = d.get("seats", {})
	for seat in K.SEATS:
		var s: Dictionary = seats.get(seat, {})
		var r: Dictionary = seat_rows[seat]
		var owner: int = int(s.get("owner", 0))
		var who: Label = r.who
		var claim: Button = r.claim
		if owner == Net.my_id:
			who.text = "YOU  (%s)" % Net.player_name
			claim.text = "Give up seat"
			claim.disabled = false
		elif owner != 0:
			who.text = "%s" % s.get("owner_name", "someone")
			claim.text = "Taken"
			claim.disabled = true
		elif s.get("bot", false):
			who.text = "AI: %s" % str(Bot.PERSONALITIES.get(s.get("kind", "competent"), {}).get("name", "?"))
			claim.text = "Take seat"
			claim.disabled = false
		else:
			who.text = "EMPTY"
			claim.text = "Take seat"
			claim.disabled = false
		var bt: Button = r.bot
		bt.set_pressed_no_signal(bool(s.get("bot_on", true)))
		bt.disabled = not is_admin
		var ko: OptionButton = r.kind
		ko.disabled = not is_admin
		var keys: Array = []
		for ik in ko.item_count:
			keys.append(ko.get_item_metadata(ik))
		var idx: int = keys.find(s.get("kind", "competent"))
		if idx >= 0 and ko.selected != idx:
			ko.select(idx)
	mode_opt.disabled = not is_admin
	length_opt.disabled = not is_admin
	kind_opt.disabled = not is_admin
	aicap_btn.disabled = not is_admin
	pers_opt.disabled = not is_admin
	ship_edit.editable = is_admin
	mode_opt.select(0 if d.get("mode", "run") == "run" else 1)
	length_opt.select(0 if d.get("length", "full") == "short" else 1)
	length_opt.visible = d.get("mode", "run") == "run"
	kind_opt.visible = d.get("mode", "run") != "run"
	var ki: int = KINDS.find(d.get("shift_kind", "casual"))
	if ki >= 0:
		kind_opt.select(ki)
	aicap_btn.set_pressed_no_signal(bool(d.get("ai_captain", false)))
	for mid2 in mod_btns.keys():
		mod_btns[mid2].set_pressed_no_signal(mid2 in d.get("mods", []))
		mod_btns[mid2].disabled = not is_admin
	pers_opt.select(maxi(0, PERS.find(d.get("personality", "random"))))
	if not ship_edit.has_focus():
		ship_edit.text = str(d.get("ship_name", "Second Opinion"))
	start_btn.disabled = not is_admin
	start_btn.text = "LAUNCH!" if is_admin else "Waiting for the host to launch..."
	var lines: Array = []
	for pid in d.get("peers", {}).keys():
		var pl: Dictionary = d.peers[pid]
		lines.append("• %s%s" % [pl.name, " (you)" if int(pid) == Net.my_id else ""])
	roster.text = "In the room:\n" + "\n".join(lines)
	var has_cap: bool = int(seats.get("captain", {}).get("owner", 0)) != 0
	var captain_ok: bool = has_cap or bool(d.get("ai_captain", false))
	info_lbl.text = "" if captain_ok else "Nobody is captain yet! Take the captain seat, or enable the AI captain."
	if is_admin:
		start_btn.disabled = not captain_ok
