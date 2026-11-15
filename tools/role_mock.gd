extends "res://tools/pair_mock.gd"
## Mock-ups for a four-player game (the Captain plus three crew roles that can split for bigger groups),
## built from the real widgets and a live simulated ship. Render through the game:
##   godot --path . --resolution 1600x720 scenes/main.tscn -- --mock=res://tools/role_mock.gd --role=driver --out=x.png
## --role: driver | stoker | tech | crewroom

## each role is two of today's stations; a bigger crew splits it back into those two
const ROLES: Dictionary = {
	"driver": {"name": "Driver", "seats": ["helm", "shields"], "color": "blue",
		"blurb": "Steers the ship and swings the shield. Keeps Pudding calm."},
	"stoker": {"name": "Stoker", "seats": ["engines", "weapons"], "color": "orange",
		"blurb": "Sets the speed and works the gun. Both make heat."},
	"tech": {"name": "Tech", "seats": ["sensors", "engineer"], "color": "green",
		"blurb": "Scans what's out there, pulls cargo in, fixes what breaks."},
}

var role: String = "driver"

func _ready() -> void:
	var args: Dictionary = {}
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	role = str(args.get("role", "driver"))
	v = "role"
	_make_world()
	UIK.bg(self)
	var root: VBoxContainer = UIK.vbox(8)
	var m: MarginContainer = UIK.margin(root, 10)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(m)
	if role == "crewroom":
		root.add_child(_crewroom())
		return
	var r: Dictionary = ROLES[role]
	pair = {"id": role, "name": r.name, "seats": r.seats}
	root.add_child(_top())
	var col: VBoxContainer = UIK.vbox(8)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(col)
	col.add_child(_role_hint(r))
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", Art.box("desk_" + str(r.color), Color.WHITE, [0, -2, 0, -6]))
	var hero: HBoxContainer = UIK.hbox(22)
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(hero)
	call("_desk_" + role, hero)
	var fb: FitBox = _fit(p)
	fb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(fb)
	root.add_child(_dock())

func _top() -> Control:
	var top: Control = super._top()
	# the line under the role name: the player, and what the role covers
	for l in top.find_children("*", "Label", true, false):
		if (l as Label).text.begins_with("Trev:"):
			(l as Label).text = "Trev: %s" % str(ROLES[role].blurb)
	return top

func _role_hint(r: Dictionary) -> Control:
	## one "your job now" for the role (the mission writes one line per role, not per station)
	var p: PanelContainer = UIK.panel("panel_small", [4, 0, 4, 0])
	var h: HBoxContainer = UIK.hbox(8)
	p.add_child(h)
	h.add_child(UIK.chip("YOUR JOB NOW", str(r.color), "flag", 15))
	var text: String = {"driver": "Weave where the captain says, and swing the shield to wherever they shout.",
		"stoker": "Keep the speed where the captain wants it. Shoot what they point at. Watch both heat gauges.",
		"tech": "Scan every ? ahead so the captain can see it. When something breaks, fix it."}[role]
	var l: Label = UIK.para(text, 18)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return p

static func _label(t: String, sz: int = 18) -> Label:
	return UIK.head(t, sz, K.pal("ink"), HORIZONTAL_ALIGNMENT_CENTER)

func _vcol(sep: int = 6) -> VBoxContainer:
	var c: VBoxContainer = UIK.vbox(sep)
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c

# ---------------------------------------------------------------- Driver: left thumb steers, right thumb swings the shield

func _desk_driver(hero: HBoxContainer) -> void:
	var hv: Dictionary = _view("helm")
	var sv: Dictionary = _view("shields")
	var arrows: VBoxContainer = _vcol(4)
	hero.add_child(arrows)
	var ar: HBoxContainer = UIK.hbox(4)
	arrows.add_child(ar)
	for d in [-1, 1]:
		var b: BigButton = BigButton.new("LEFT" if d < 0 else "RIGHT", "blue", true, 104)
		b.arrow = d
		ar.add_child(b)
	var wheel: ShipWheel = ShipWheel.new()
	wheel.custom_minimum_size = Vector2(212, 212)
	wheel.set_value(-0.7)
	arrows.add_child(UIK.center(wheel))
	var mid: VBoxContainer = _vcol(6)
	hero.add_child(mid)
	var comp: HelmUI.CompassDial = HelmUI.CompassDial.new()
	comp.custom_minimum_size = Vector2(170, 170)
	comp.heading = 300.0
	mid.add_child(UIK.center(comp))
	mid.add_child(UIK.title("300°", 40, UIK.c("cream"), HORIZONTAL_ALIGNMENT_CENTER))
	var roll: BigButton = BigButton.new("ROLL!", "blue", false, 80)
	mid.add_child(UIK.center(roll))
	# Pudding: a tap-and-hold chore in the middle, between the two thumbs
	var pud: PanelContainer = UIK.panel("panel_small", [2, 2, 2, 2])
	var ph: HBoxContainer = UIK.hbox(6)
	pud.add_child(ph)
	ph.add_child(UIK.portrait("pudding", 44))
	var mood: Gauges.Bar = Gauges.Bar.new("pink", 24)
	mood.custom_minimum_size = Vector2(90, 24)
	mood.set_value(0.62, "CALM-ISH")
	mood.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(mood)
	ph.add_child(BigButton.new("PET", "purple", true, 54))
	mid.add_child(pud)
	var right: VBoxContainer = _vcol(4)
	hero.add_child(right)
	var dial: ClockDial = ClockDial.new()
	dial.mode = ClockDial.Mode.SHIELD
	dial.accent = UIK.c("purple")
	dial.custom_minimum_size = Vector2(390, 390)
	dial.set_value(float(sv.get("dir", 1.2)) if sv.has("dir") else 1.2)
	right.add_child(dial)
	right.add_child(_label("SHIELD: DRAG TO WHERE THEY SHOUT", 16))

# ---------------------------------------------------------------- Stoker: left thumb on the throttle, right thumb on FIRE

func _desk_stoker(hero: HBoxContainer) -> void:
	var wv: Dictionary = _view("weapons")
	var lever: ThrottleLever = ThrottleLever.new()
	lever.custom_minimum_size = Vector2(200, 400)
	lever.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lever.set_value(w.ship.throttle)
	lever.red_from = 0.72
	hero.add_child(lever)
	var sp: Gauges.Needle = Gauges.Needle.new("SPEED", 120)
	sp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sp.set_value(w.ship.speed() / Ship.MAX_SPEED, "%d m/s" % int(w.ship.speed()))
	hero.add_child(sp)
	var heat: HBoxContainer = UIK.hbox(6)
	heat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hero.add_child(heat)
	var et: Gauges.Thermo = Gauges.Thermo.new("ENGINE", 330)
	et.set_value(0.55)
	heat.add_child(et)
	var gt: Gauges.Thermo = Gauges.Thermo.new("GUN", 330)
	gt.set_value(0.8)
	heat.add_child(gt)
	var mid: VBoxContainer = _vcol(4)
	hero.add_child(mid)
	var scope: Scope = Scope.new()
	scope.custom_minimum_size = Vector2(360, 360)
	scope.view = wv
	scope.aim = float(wv.get("aim", 0.0))
	mid.add_child(scope)
	var right: VBoxContainer = _vcol(8)
	hero.add_child(right)
	var dial: ClockDial = ClockDial.new()
	dial.mode = ClockDial.Mode.TURRET
	dial.accent = UIK.c("red")
	dial.custom_minimum_size = Vector2(190, 190)
	right.add_child(UIK.center(dial))
	var fr: HBoxContainer = UIK.hbox(10)
	fr.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_child(fr)
	fr.add_child(BigButton.new("BOOST", "mustard", true, 76))
	fr.add_child(BigButton.new("FIRE", "red", true, 120))

# ---------------------------------------------------------------- Tech: pick a blip or a room, hold the button for it

func _desk_tech(hero: HBoxContainer) -> void:
	var sv: Dictionary = _view("sensors")
	var ev: Dictionary = _view("engineer")
	var radar: Radar = Radar.new()
	radar.custom_minimum_size = Vector2(360, 360)
	radar.view = sv
	radar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hero.add_child(radar)
	var sc: VBoxContainer = _vcol(8)
	hero.add_child(sc)
	var card: PanelContainer = UIK.panel("panel_small", [4, 2, 4, 2])
	var cv: VBoxContainer = UIK.vbox(0)
	card.add_child(cv)
	cv.add_child(UIK.head("SELECTED", 14, K.pal("ink_soft")))
	cv.add_child(UIK.head("STRAY POD", 20))
	sc.add_child(card)
	var sr: HBoxContainer = UIK.hbox(8)
	sc.add_child(sr)
	sr.add_child(BigButton.new("SCAN", "green", true, 90))
	sr.add_child(BigButton.new("PULL", "purple", true, 90))
	var rc: VBoxContainer = _vcol(6)
	hero.add_child(rc)
	var cut: Cutaway = Cutaway.new()
	cut.custom_minimum_size = Vector2(420, 220)
	cut.systems = ev.get("systems", {})
	cut.selected = "tractor"
	cut.features = w.features
	rc.add_child(cut)
	var rr: HBoxContainer = UIK.hbox(10)
	rr.alignment = BoxContainer.ALIGNMENT_CENTER
	rc.add_child(rr)
	var l: Label = UIK.para("Tractor beam is broken.\nHold REPAIR.", 20)
	l.custom_minimum_size = Vector2(230, 0)
	rr.add_child(l)
	rr.add_child(BigButton.new("REPAIR", "green", true, 110))

# ---------------------------------------------------------------- the Crew Room: four seats, roles that split

func _crewroom() -> Control:
	var col: VBoxContainer = UIK.vbox(12)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var top: HBoxContainer = UIK.hbox(10)
	col.add_child(top)
	top.add_child(UIK.title("CREW ROOM", 46))
	top.add_child(UIK.spacer(true))
	var cnt: PanelContainer = UIK.chip("6 ABOARD", "navy", "crew", 20)
	cnt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(cnt)
	var tip: Label = UIK.para("Four seats: the Captain and three crew. Got more than four? Split a role and two people share it, one screen each. Fewer? A robot takes a role.", 19, K.pal("ink_soft"))
	col.add_child(tip)
	var row: HBoxContainer = UIK.hbox(14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	row.add_child(_seat_card("captain", "Captain", "navy", "Sees everything. Touches nothing. Talks.", [["captain", "Trev"]], false))
	row.add_child(_seat_card("driver", "Driver", "blue", str(ROLES.driver.blurb), [["helm", "Sam"]], false))
	row.add_child(_seat_card("stoker", "Stoker", "orange", str(ROLES.stoker.blurb), [["engines", "Alex"], ["weapons", "Jo"]], true))
	row.add_child(_seat_card("tech", "Tech", "green", str(ROLES.tech.blurb), [["sensors", "Mel"], ["engineer", "Robin"]], true))
	var foot: HBoxContainer = UIK.hbox(10)
	foot.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(foot)
	foot.add_child(UIK.label("Splitting gives each half its own screen: today's stations.", 18, K.pal("ink_soft")))
	var go: Button = UIK.btn("START THE SHIFT", "green", func(): pass, "play", 24)
	go.custom_minimum_size = Vector2(300, 56)
	foot.add_child(go)
	return col

func _seat_card(_id: String, title: String, colr: String, blurb: String, who: Array, split: bool) -> Control:
	var w2: Array = UIK.window(title.to_upper(), colr, "crew" if _id == "captain" else "")
	(w2[0] as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b: VBoxContainer = w2[1]
	b.add_theme_constant_override("separation", 8)
	var faces: HBoxContainer = UIK.hbox(-10)
	faces.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(faces)
	var seats: Array = [_id] if _id == "captain" else ROLES[_id].seats
	for s in seats:
		faces.add_child(UIK.portrait(str(s), 72))
	var bl: Label = UIK.para(blurb, 17)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(bl)
	var kit: String = {"captain": "The chart · the crew's instruments · IGOR", "driver": "Wheel · compass · shield · roll · Pudding",
		"stoker": "Throttle · boost · gun · turret · two heat gauges", "tech": "Radar · scan · tractor · ship plan · repair"}[_id]
	var kl: Label = UIK.para(kit, 16, K.pal("ink_soft"))
	kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(kl)
	if split:
		var ch: Label = UIK.head("SPLIT: TWO PLAYERS", 15, UIK.c("red").darkened(0.1), HORIZONTAL_ALIGNMENT_CENTER)
		b.add_child(ch)
	for pr in who:
		var r: HBoxContainer = UIK.hbox(6)
		b.add_child(r)
		var c: PanelContainer = UIK.chip(K.seat_name(str(pr[0])).to_upper() if split else ("CAPTAIN" if _id == "captain" else "WHOLE ROLE"), "cream", str(K.SEAT_INFO[pr[0]].icon), 14)
		r.add_child(c)
		var n: Label = UIK.head(str(pr[1]), 19)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(n)
	b.add_child(UIK.spacer(true))
	if _id != "captain":
		b.add_child(UIK.btn("Join as one" if split else "Split for a bigger crew", "cream", func(): pass, "", 15))
	return w2[0]
