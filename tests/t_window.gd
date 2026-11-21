extends SceneTree
## The Captain's bridge window and the Tech's radar: the Captain sees far ahead but nothing behind (bar the close
## ring), the Tech sees all round and further, and only a Tech's pin puts something behind us on the Captain's window.
## Also: drones charge up and fire their shots together.

func _init() -> void:
	var fails: Array = []
	var w: World = World.new(5)
	Missions.make("lesson").setup(w)
	w.ents.clear()
	w.ship.pos = Vector2.ZERO
	w.ship.heading = -PI / 2.0      # nose up (north)
	var ahead: Dictionary = w.spawn("drone", Vector2(0, -1100), {"ai": "none"})
	var wide: Dictionary = w.spawn("rock", Vector2.from_angle(-PI / 2.0 + deg_to_rad(80.0)) * 400.0)
	var behind: Dictionary = w.spawn("drone", Vector2(0, 600), {"ai": "none"})
	var close: Dictionary = w.spawn("mine", Vector2(0, 100))
	var far: Dictionary = w.spawn("rock", Vector2(0, -1500))
	var cap: Dictionary = Snapshots.captain(w)
	var ids: Array = []
	for e in cap.ents:
		ids.append(int(e.id))
	_check(fails, int(ahead.id) in ids, "a drone 1,100 m dead ahead is in the window")
	_check(fails, not (int(wide.id) in ids), "a rock 80 degrees off the nose is not")
	_check(fails, not (int(behind.id) in ids), "a drone behind us is not")
	_check(fails, int(close.id) in ids, "a mine 100 m behind is (the close ring)")
	_check(fails, not (int(far.id) in ids), "a rock 1,500 m ahead is too far for the window")
	var sen: Dictionary = Snapshots.sensors(w)
	var blips: Array = []
	for b in sen.blips:
		blips.append(int(b.id))
	_check(fails, int(behind.id) in blips and int(wide.id) in blips and int(ahead.id) in blips, "the Tech's radar sees all round")
	_check(fails, float(sen.range) > Snapshots.WINDOW_RANGE * 0.9, "and nearly as far as the window, all the way round")
	# a shot from behind: no shout until it's in the close ring
	w.shots.append({"pos": Vector2(0, 300), "vel": Vector2(0, -140), "from": "them", "dmg": 1.0, "life": 9.0, "kind": "blob"})
	w.ship.shield_dir = 0.0
	var shouted: bool = false
	for wn in Snapshots.forecasts(w):
		shouted = shouted or str(wn.text).begins_with("Incoming")
	_check(fails, not shouted, "a shot from behind isn't called out to the Captain (the Tech has to)")
	_check(fails, Snapshots.captain(w).shots.is_empty(), "nor drawn on the window")
	w.shots.clear()
	# the Tech pins the drone behind: it shows as a marker on the window's edge, for a while
	Intents.apply(w, "sensors", "pin", int(behind.id), true)
	cap = Snapshots.captain(w)
	var mark: Dictionary = {}
	for pm in cap.pins:
		if int(pm.id) == int(behind.id):
			mark = pm
	_check(fails, not mark.is_empty() and not bool(mark.seen) and absf(absf(float(mark.rel)) - PI) < 0.05, "a pinned drone behind us gets an edge marker at 6 o'clock")
	var w3: World = World.new(5)
	Missions.make("lesson").setup(w3)
	Intents.apply(w3, "sensors", "pin", -1, true)
	var gpin: Array = Snapshots.captain(w3).pins
	_check(fails, w3.mission.goal_pos() != null and gpin.size() == 1 and str(gpin[0].kind) == "goal", "the goal can be pinned too")
	w.t += World.PIN_TIME + 0.5
	_check(fails, Snapshots.captain(w).pins.is_empty(), "pins fall off after %d s" % int(World.PIN_TIME))
	Intents.apply(w, "sensors", "pin", int(behind.id), true)
	Intents.apply(w, "sensors", "pin", int(behind.id), true)
	_check(fails, Snapshots.captain(w).pins.is_empty(), "pinning again takes it down")
	var steps: Array = cap.steps
	var leak: bool = false
	for st in steps:
		leak = leak or st.has("pos")
	_check(fails, not leak, "the mission's steps don't leak where things are")
	# drones: glow first, then three shots together
	var w2: World = World.new(3)
	Missions.make("lesson").setup(w2)
	w2.ents.clear()
	w2.ship.pos = Vector2.ZERO
	var d: Dictionary = w2.spawn("drone", Vector2(0, -300), {"ai": "drone"})
	d.cd = 0.0
	var charged: bool = false
	var volley: int = 0
	for i in int(6.0 / K.DT):
		w2.step(K.DT)
		charged = charged or float(d.charge) > 0.0
		var n: int = 0
		for sh in w2.shots:
			if sh.from == "them":
				n += 1
		volley = maxi(volley, n)
		if n > 0:
			break
	_check(fails, charged and volley == 3, "a drone charges up, then fires three at once (saw %d)" % volley)
	print("WINDOW ", "PASS" if fails.is_empty() else "FAIL: %s" % str(fails))
	quit(0 if fails.is_empty() else 1)

func _check(fails: Array, ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails.append(what)
