class_name Missions
extends RefCounted
## The career: ten missions, each adding ONE new thing.

const ORDER: Array = ["lesson", "binday", "hot", "pet", "customs", "bigone", "pursuit", "brownout", "grabbers", "haven"]

const INFO: Dictionary = {
	"lesson": {"num": 1, "title": "Driving Lesson", "new": "The basics"},
	"binday": {"num": 2, "title": "Bin Day", "new": "Tractor beam"},
	"hot": {"num": 3, "title": "Running Hot", "new": "Heat (and fire)"},
	"pet": {"num": 4, "title": "Pet Sitting", "new": "Pudding's mood"},
	"customs": {"num": 5, "title": "Customs", "new": "The comms dial"},
	"bigone": {"num": 6, "title": "The Big One", "new": "Torpedoes and weak spots"},
	"pursuit": {"num": 7, "title": "Hot Pursuit", "new": "Boost and barrel roll"},
	"brownout": {"num": 8, "title": "Brownout", "new": "Power and overload"},
	"grabbers": {"num": 9, "title": "Grabbers", "new": "Grabber drones"},
	"haven": {"num": 10, "title": "Run to Haven", "new": "Everything"},
}

static func make(id: String) -> Mission:
	var m: Mission
	match id:
		"binday":
			m = BinDay.new()
		"hot":
			m = RunningHot.new()
		"pet":
			m = PetSitting.new()
		"customs":
			m = CustomsPost.new()
		"bigone":
			m = BigOne.new()
		"pursuit":
			m = HotPursuit.new()
		"brownout":
			m = Brownout.new()
		"grabbers":
			m = Grabbers.new()
		"haven":
			m = RunToHaven.new()
		_:
			m = DrivingLesson.new()
			id = "lesson"
	m.id = id
	m.num = int(INFO[id].num)
	m.title = str(INFO[id].title)
	return m

static func features_upto(n: int) -> Dictionary:
	## the mechanics every mission up to and including n has taught
	var f: Dictionary = {"damage": true}
	if n >= 2:
		f["tractor"] = true
	if n >= 3:
		f["heat"] = true
		f["fire"] = true
	if n >= 4:
		f["pudding"] = true
	if n >= 5:
		f["comms"] = true
	if n >= 6:
		f["torpedo"] = true
		f["weakspot"] = true
	if n >= 7:
		f["boost"] = true
		f["roll"] = true
	if n >= 8:
		f["power"] = true
	if n >= 9:
		f["grabbers"] = true
	return f

const QUIET: String = "Nothing for you yet. Watch the others, and listen to the captain."

# ================================================================ 1

class DrivingLesson extends Mission:
	func _init() -> void:
		features = Missions.features_upto(1)
		place = "IGOR's practice yard"
		par = 240.0
		story = "Welcome, meat. IGOR is your ship's robot. Today IGOR teaches you to fly, so you do not embarrass IGOR in front of the other robots. The captain sees everything and touches nothing. Everyone else touches one thing and sees almost nothing. You must talk. Constantly. It is the only way."
		new_thing = {"title": "Everyone gets ONE control", "who": ["helm", "engines", "weapons", "sensors", "shields", "engineer"],
			"text": "Helm steers. Engines sets the speed. Weapons aims and fires. Sensors scans. Shields points the shield. The Engineer fixes things. The Captain tells everyone what to do."}

	func build() -> void:
		ring(Vector2(0, -460), "a")
		ring(Vector2(420, -820), "b")
		ring(Vector2(-160, 160), "home", "green")
		add("Fly through the first ring", {
			"captain": "Your chart shows the ring. Tell Engines to go and Helm which way to turn.",
			"helm": "Steer with the wheel. It stays where you leave it. Centre it to fly straight.",
			"engines": "Push the throttle up to get moving. It stays where you leave it.",
		}, func(): return passed("a"), Callable(), func(): return pos_of("a"))
		add("Fly through the second ring", {
			"helm": "The captain will tell you which way. Small turns!",
			"engines": "Not too fast, or Helm will miss the ring.",
		}, func(): return passed("b"), Callable(), func(): return pos_of("b"))
		add("Engineer: fix the sensor dish", {
			"engineer": "IGOR loosened the sensor dish for practice. Click SENSORS on the ship, then hold REPAIR.",
			"captain": "Your ship board shows what's broken. Tell the Engineer.",
			"sensors": "Your radar is broken until the Engineer fixes it.",
			"engines": "Slow down while we sort this out.",
		}, func(): return w.ship.ok("sensors"), func():
			w.spawn("target", Vector2(660, -1100), {"ai": "none"})
			w.spawn("buoy", Vector2(800, -960), {"name": "Bernard (IGOR's cousin)", "ai": "none"})
			w.spawn("target", Vector2(560, -900), {"ai": "none"})
			w.break_system("sensors", "was loosened by IGOR", false))
		add("Scan the three buoys to find the practice targets", {
			"sensors": "Click a blip on your radar, then hold SCAN. The captain's chart will show what it is.",
			"captain": "The ? marks are unknown. Ask Sensors to scan them.",
		}, func(): return all_scanned(["target", "buoy"]), Callable(), func(): return pos_of(""))
		add("Shoot the two practice targets (NOT Bernard!)", {
			"weapons": "Turn the turret where the captain says and hold FIRE. You only see down the barrel.",
			"captain": "Tell Weapons where the targets are: 'two o'clock', 'behind us'...",
			"engines": "Slow down so Weapons can aim.",
		}, func(): return none_left("target"))
		add("Incoming junk! Block it with the shield", {
			"shields": "Turn the shield dial towards the junk. The captain can see it coming; you can't.",
			"captain": "Watch the chart: junk flies in. Tell Shields where it's coming from.",
			"engineer": "Junk that gets through breaks things. Fix them.",
		}, func(): return count("junk_done") >= 5, func():
			counters["junk_done"] = 0
			counters["junk_thrown"] = 0)
		add("Fly home through the green ring", {
			"helm": "Long way round. The captain will guide you.",
		}, func(): return passed("home"), Callable(), func(): return pos_of("home"))

	func extra(_dt: float) -> void:
		if step == 5 and count("junk_thrown") < 5 and step_t > 2.0 + count("junk_thrown") * 4.0:
			counters["junk_thrown"] = count("junk_thrown") + 1
			throw_junk("junk", 90.0, 420.0)

# ================================================================ 2

class BinDay extends Mission:
	func _init() -> void:
		features = Missions.features_upto(2)
		place = "The Rubbish Belt"
		par = 220.0
		story = "Today is bin day. The Free Lanes pay us to collect a skip. A skip is a large bin. Humans fill it with things they do not want. IGOR understands this. IGOR has seen the crew. Fly to the skip, pull it aboard, and nobody asks what is inside."
		new_thing = {"title": "The tractor beam", "who": ["shields"],
			"text": "Shields can now hold TRACTOR to pull things in. It only reaches 150 metres, so the captain must get the ship close and slow."}

	func build() -> void:
		w.spawn("skip", Vector2(320, -900), {"tag": "skip", "scanned": true, "name": "The skip"})
		for p in [Vector2(-120, -420), Vector2(180, -520), Vector2(60, -700), Vector2(460, -640), Vector2(260, -1150)]:
			w.spawn("rock", p, {"scanned": true})
		add("Fly to the skip (mind the rocks)", {
			"captain": "Rocks hurt. Steer Helm around them.",
			"helm": "Around the rocks, as the captain says.",
			"engines": "Medium speed: rocks are hard.",
		}, func(): return w.ship.pos.distance_to(pos_of("skip") if pos_of("skip") != null else w.ship.pos) < 200.0, Callable(),
			func(): return pos_of("skip"))
		add("Slow down and pull the skip aboard with the tractor beam", {
			"shields": "Hold TRACTOR when your screen says the skip is in range.",
			"engines": "Slow right down near the skip.",
			"captain": "Get close, get slow, then tell Shields: 'TRACTOR!'",
		}, func(): return count("collected") >= 1, Callable(), func(): return pos_of("skip"))
		add("It's PUDDING! Scan the drones, then shoot them down", {
			"sensors": "Scan the new blips so the captain knows what they are.",
			"weapons": "Drones! Aim where the captain says and fire.",
			"shields": "Drones shoot back. Point the shield at them.",
		}, func(): return count("killed_drone") >= 2, func():
			w.spawn("drone", ahead(460, PI * 0.8), {"ai": "drone"})
			w.spawn("drone", ahead(480, -PI * 0.7), {"ai": "drone"})
			w.emit("story", {"who": "igor", "text": "IGOR has looked in the skip. It is Pudding. The Overlord's pet. The Overlord will want Pudding back. Here come the drones."}))
		add("Escape through the ring", {
			"helm": "To the ring!",
			"engines": "Full speed ahead.",
		}, func(): return passed("exit"), func(): ring(ahead(600, -0.6), "exit", "green"), func(): return pos_of("exit"))

# ================================================================ 3

class RunningHot extends Mission:
	func _init() -> void:
		features = Missions.features_upto(3)
		place = "The Soup Run"
		par = 200.0
		story = "Ma Gristle needs soup delivered to her diner, and she needs it hot. You will want to go full throttle. IGOR wants to watch."
		new_thing = {"title": "Heat", "who": ["engines", "weapons"],
			"text": "Full throttle heats the engines; non-stop firing heats the gun. Past the red line the part breaks, and sometimes catches FIRE. Fires spread: the Engineer puts them out first. The captain sees the heat on the ship board."}

	func build() -> void:
		ring(Vector2(0, -500), "c1")
		ring(Vector2(-450, -950), "c2")
		ring(Vector2(0, -1400), "c3")
		w.spawn("diner", Vector2(380, -1820), {"tag": "diner", "scanned": true})
		var go: Dictionary = {"engines": "Fast, but watch your heat gauge. Ease off before the red.", "helm": "Ring to ring!"}
		add("Through ring 1 (Ma wants it in under 90 seconds)", go, func(): return passed("c1"), Callable(), func(): return pos_of("c1"))
		add("Through ring 2", go, func(): return passed("c2"), Callable(), func(): return pos_of("c2"))
		add("Through ring 3", go, func(): return passed("c3"), Callable(), func(): return pos_of("c3"))
		add("Drones at the diner! Shoot all three (don't cook the gun)", {
			"weapons": "Short bursts! If the gun overheats it jams and the Engineer has to fix it.",
			"sensors": "Scan the new contacts.",
			"shields": "Shield towards the drones.",
		}, func(): return count("killed_drone") >= 3, func():
			for k in 3:
				var d: Vector2 = pos_of("diner") if pos_of("diner") != null else ahead(400)
				w.spawn("drone", d + Vector2.from_angle(k * TAU / 3.0) * 160.0, {"ai": "drone"}))
		add("Dock: stop right next to the diner", {
			"engines": "Gently does it. Stop next to the diner.",
			"helm": "Line up with the diner.",
		}, func():
			var d2: Variant = pos_of("diner")
			return d2 != null and w.ship.pos.distance_to(d2) < 170.0 and w.ship.speed() < 8.0, Callable(), func(): return pos_of("diner"))

# ================================================================ 4

class PetSitting extends Mission:
	func _init() -> void:
		features = Missions.features_upto(4)
		place = "Meteor Alley"
		par = 160.0
		narrator = "pudding"
		story = "Pudding lives on the ship now. Pudding is soft. Pudding is sensitive. Pudding does not like loud things. Today there are many loud things. A meteor shower. If Pudding is unhappy, Pudding escapes and chews the ship. IGOR is not jealous of Pudding."
		new_thing = {"title": "Pudding's mood", "who": ["shields"],
			"text": "Hits, fire and boosting upset Pudding. Shields can hold PET to cheer Pudding up, or give a SNACK. If Pudding's mood hits zero, Pudding escapes and chews things! Shields holds SHAKE TIN to call Pudding back."}

	func build() -> void:
		ring(Vector2(-300, -1000), "calm", "green")
		add("Ride out the meteor shower for 60 seconds", {
			"shields": "Block meteors, and PET Pudding when the sky is clear.",
			"captain": "Meteors come from all sides. Call them out, and watch Pudding's mood.",
			"engineer": "Fix whatever the meteors break.",
			"weapons": "You can shoot meteors too!",
		}, func(): return step_t >= 60.0)
		add("Fly to the quiet ring", {
			"helm": "To the green ring.",
			"engines": "Steady speed. Pudding hates boosting.",
		}, func(): return passed("calm"), Callable(), func(): return pos_of("calm"))

	func extra(_dt: float) -> void:
		if step == 0:
			var n: int = int(step_t / 3.0)
			if n > count("thrown") and step_t < 58.0:
				counters["thrown"] = n
				throw_junk("rock", 85.0 + step_t, 440.0)

# ================================================================ 5

class CustomsPost extends Mission:
	var asks: Array = []
	var current: Dictionary = {}
	var ok_t: float = 0.0
	var strikes: int = 0
	var scans_before: int = 0

	func _init() -> void:
		features = Missions.features_upto(5)
		place = "Hegemony Customs"
		par = 210.0
		story = "A Hegemony customs post. The officer will give instructions over the radio. Only Sensors can tune in, so only Sensors will hear them. Do what the officer says, exactly. Do not mention the pink blob. IGOR will be doing all of the not mentioning."
		new_thing = {"title": "The comms dial", "who": ["sensors"],
			"text": "When someone hails us, Sensors turns the COMMS dial until the signal locks and the message appears, then reads it out to the captain."}

	func build() -> void:
		w.spawn("customs", Vector2(0, -760), {"tag": "customs", "scanned": true})
		ring(Vector2(0, -540), "line", "mustard")
		ring(Vector2(260, -1200), "out", "green")
		var pool: Array = [
			{"text": "Turn your ship to face heading 090. East, for the meat-brained.", "who": "helm", "test": "heading90"},
			{"text": "Point your shield at your BACK, please. We like to see your face.", "who": "shields", "test": "shield_back"},
			{"text": "Turn your gun to face our station. Do NOT fire it.", "who": "weapons", "test": "gun_at"},
			{"text": "Engines to zero. Full stop. Stay stopped.", "who": "engines", "test": "stop"},
			{"text": "Scan our station so we know your sensors work.", "who": "sensors", "test": "scan"},
		]
		pool.shuffle()
		asks = pool.slice(0, 4)
		add("Stop inside the yellow inspection ring", {
			"engines": "Slow, then stop inside the ring.",
			"helm": "Line up with the yellow ring.",
		}, func():
			var p: Variant = pos_of("line")
			return p != null and w.ship.pos.distance_to(p) < 60.0 and w.ship.speed() < 10.0, Callable(), func(): return pos_of("line"))
		for i in 4:
			add("Customs is hailing! Sensors: tune in, read it out, and do what it says (%d of 4)" % (i + 1), {
				"sensors": "Turn the COMMS dial until the signal locks. Then READ THE MESSAGE OUT LOUD.",
				"captain": "Only Sensors can hear customs. Make them read it out, then tell the right crew.",
				"*": "Customs might want something from you. Listen!",
			}, func(): return _check_ask(), func(): _next_ask())
		add("Cleared! Fly through the green ring", {"engines": "Away we go.", "helm": "To the green ring."},
			func(): return passed("out"), func():
				current = {}
				w.hail = {}, func(): return pos_of("out"))

	func _next_ask() -> void:
		current = asks.pop_front() if not asks.is_empty() else {}
		ok_t = 0.0
		scans_before = count("rescanned")
		if not current.is_empty():
			w.send_hail("Customs Officer", str(current.text))

	func _check_ask() -> bool:
		if current.is_empty() or w.hail.is_empty() or not bool(w.hail.get("heard", false)):
			return false
		var s: Ship = w.ship
		var good: bool = false
		match str(current.test):
			"heading90":
				good = absf(K.wrap_pi(s.heading - 0.0)) < deg_to_rad(15.0)
			"shield_back":
				good = absf(K.wrap_pi(s.shield_dir - PI)) < 0.45
			"gun_at":
				var cp: Variant = pos_of("customs")
				good = cp != null and absf(K.wrap_pi(s.turret_world() - (cp - s.pos).angle())) < 0.3
			"stop":
				good = s.throttle < 0.05 and s.speed() < 3.0
			"scan":
				good = count("rescanned") > scans_before
		ok_t = ok_t + 0.0333 if good else 0.0
		return ok_t > 1.5

	func extra(_dt: float) -> void:
		if not current.is_empty() and bool(w.hail.get("heard", false)) and w.t - float(w.hail.get("t", w.t)) > 45.0 and ok_t <= 0.0:
			strikes += 1
			w.emit("story", {"who": "thrupp", "text": "Too slow! The officer is writing you up. Strike %d." % strikes})
			w.hail["t"] = w.t
			if strikes >= 3:
				fail("Customs impounded the ship for being slow and weird.")

# ================================================================ 6

class BigOne extends Mission:
	func _init() -> void:
		features = Missions.features_upto(6)
		place = "Thrupp's Flagship"
		narrator = "thrupp"
		par = 240.0
		story = "This is Admiral Thrupp of the Hegemony. Hand over the Overlord's pet, or my cruiser will make you hand it over. My cruiser is very large. I am also very large. (IGOR: The cruiser has a weak spot. All big things do. IGOR has no weak spot.)"
		new_thing = {"title": "Torpedoes and weak spots", "who": ["weapons", "sensors"],
			"text": "Sensors scans the cruiser TWICE: the second scan shows its weak spot. Weapons holds LOAD to load a torpedo, then fires it. Torpedoes only hurt the weak spot, so the captain must get Helm round behind the cruiser."}

	func build() -> void:
		var c: Dictionary = w.spawn("cruiser", Vector2(0, -680), {"tag": "cruiser", "ai": "cruiser", "heading": PI / 2.0})
		ring(Vector2(-500, -1300), "out", "green")
		add("Scan the cruiser twice to find its weak spot", {
			"sensors": "Click the big blip and hold SCAN. Then scan it AGAIN for the weak spot.",
			"shields": "It fires big broadsides. Watch for the red glow and shield towards it.",
			"captain": "When the cruiser glows red it's about to fire. Call it!",
		}, func():
			var cr: Dictionary = tagged("cruiser")
			return cr.is_empty() or bool(cr.weak_known))
		add("Get behind the cruiser and torpedo its back vent (2 hits)", {
			"weapons": "Hold LOAD, then FIRE TORPEDO when the captain says you're lined up behind it.",
			"helm": "Swing round BEHIND the cruiser.",
			"captain": "Your chart shows the weak spot. Get Helm behind it and Weapons lined up.",
		}, func(): return none_left("cruiser"))
		add("Escape through the green ring", {"engines": "Full speed!"}, func(): return passed("out"), Callable(), func(): return pos_of("out"))

# ================================================================ 7

class HotPursuit extends Mission:
	func _init() -> void:
		features = Missions.features_upto(7)
		place = "The Long Straight"
		par = 150.0
		story = "A Hegemony patrol has found us. It cannot be shot; it is armoured, like IGOR's opinions. It is a little slower than us. It fires in threes. Run for the far ring. Do not be caught. IGOR does not want to be melted down into a toaster."
		new_thing = {"title": "Boost and barrel roll", "who": ["engines", "helm"],
			"text": "Engines can hold BOOST to go much faster, but it gets HOT fast and upsets Pudding. Helm can press ROLL to dodge sideways: shots miss while you roll. The captain sees shots coming and shouts ROLL!"}

	func build() -> void:
		ring(Vector2(200, -2600), "far", "green")
		for p in [Vector2(-160, -900), Vector2(220, -1200), Vector2(-60, -1600), Vector2(300, -1900), Vector2(80, -2200)]:
			w.spawn("mine", p, {"ai": "mine"})
		add("Outrun the patrol to the far ring", {
			"engines": "BOOST when the captain says, but don't cook the engines.",
			"helm": "ROLL to dodge when the captain shouts! Steer around mines.",
			"sensors": "Scan the ? ahead: some of them are mines.",
			"captain": "The patrol fires in threes: when it glows, shout ROLL. Keep away from mines.",
		}, func(): return passed("far"), func():
			w.spawn("patrol", ahead(-420), {"ai": "patrol", "speed": 62.0, "tag": "patrol"}), func(): return pos_of("far"))

# ================================================================ 8

class Brownout extends Mission:
	func _init() -> void:
		features = Missions.features_upto(8)
		place = "The Junkyard Run"
		par = 220.0
		story = "The reactor has been repaired by a human. It now makes less power than a toaster. It cannot run everything at full at once. IGOR suggests nobody does anything. Nobody listens to IGOR."
		new_thing = {"title": "Power and overload", "who": ["engineer"],
			"text": "The Engineer shares out 6 bars of power between Engines, Weapons and Shields. More bars means stronger. But full throttle, firing and the tractor all DRAW power: draw more than 6 and the reactor overloads. Overload means BLACKOUT. The captain sees the overload meter: tell people to ease off!"}

	func build() -> void:
		ring(Vector2(0, -900), "r1")
		for p in [Vector2(-260, -420), Vector2(240, -560)]:
			w.spawn("pod", p, {"tag": "pod", "scanned": true})
		ring(Vector2(-200, -1500), "out", "green")
		add("Engineer: try moving the power bars around", {
			"engineer": "Your power board: 6 bars to share between Engines, Weapons and Shields.",
			"captain": "Watch the reactor meter on your ship board.",
		}, func(): return step_t > 10.0)
		add("Pull in both cargo pods (the tractor uses power too)", {
			"shields": "TRACTOR the pods when they're in range.",
			"engineer": "Tractor + throttle might overload. Shuffle power when the captain says.",
		}, func(): return count("collected") >= 2, Callable(), func(): return pos_of("pod"))
		add("Drones! Fight them off while flying through the ring", {
			"weapons": "Fire! (Firing draws power.)",
			"engineer": "Fighting needs Weapons power. Flying needs Engines. Choose!",
		}, func(): return count("killed_drone") >= 3 and passed("r1"), func():
			for k in 3:
				w.spawn("drone", ahead(450, -1.0 + k * 1.0), {"ai": "drone"}), func(): return pos_of("r1"))
		add("Out through the green ring", {}, func(): return passed("out"), Callable(), func(): return pos_of("out"))

# ================================================================ 9

class Grabbers extends Mission:
	func _init() -> void:
		features = Missions.features_upto(9)
		place = "The Drone Nest"
		par = 200.0
		story = "Grabber drones. They grab. They latch on to the hull and chew. They are attracted to Pudding, which is fair. To get them off: spin the ship hard, point the shield at them, or shoot them where they sit."
		new_thing = {"title": "Grabber drones", "who": ["helm", "shields", "weapons"],
			"text": "Grabbers latch on and chew whatever they're next to. The captain sees where they're stuck. Shake them off: Helm spins HARD, Shields points at them, or Weapons aims the turret at them and fires."}

	func build() -> void:
		ring(Vector2(0, -1500), "out", "green")
		add("Grabbers! Get rid of four of them", {
			"helm": "When the captain says SPIN, turn the wheel all the way and hold it.",
			"shields": "Point the shield at a stuck grabber for 2 seconds to knock it off.",
			"weapons": "Aim the turret at a stuck grabber and fire.",
			"captain": "The ship board shows where grabbers are stuck. Pick a plan and call it.",
		}, func(): return count("killed_grabber") >= 4, func():
			for k in 3:
				w.spawn("grabber", around(420), {"ai": "grabber"}))
		add("Out through the ring", {"engines": "Go go go."}, func(): return passed("out"), Callable(), func(): return pos_of("out"))

	func extra(_dt: float) -> void:
		if step == 0 and step_t > 20.0 and count("wave2") == 0:
			counters["wave2"] = 1
			for k in 3:
				w.spawn("grabber", around(450), {"ai": "grabber"})

# ================================================================ 10

class RunToHaven extends Mission:
	func _init() -> void:
		features = Missions.features_upto(10)
		place = "The Last Stretch"
		par = 300.0
		story = "Haven. A free station where nobody asks about pink blobs. Between us and Haven: mines, drones, grabbers, and one very cross admiral. IGOR has calculated our chances. IGOR will not say them out loud. Good luck, meat. IGOR means it. A little."
		new_thing = {"title": "Everything at once", "who": ["helm", "engines", "weapons", "sensors", "shields", "engineer"],
			"text": "No new tricks today: just every trick you have learned. Captain: you've got this."}

	func build() -> void:
		for p in [Vector2(-200, -500), Vector2(120, -620), Vector2(-60, -820), Vector2(260, -900), Vector2(-280, -1000), Vector2(60, -1080)]:
			w.spawn("mine", p, {"ai": "mine"})
		ring(Vector2(0, -1250), "field")
		w.spawn("haven", Vector2(500, -2500), {"tag": "haven", "scanned": true})
		add("Cross the minefield (scan the ?s, steer round the mines)", {
			"sensors": "Scan every ? ahead. The captain needs to see the mines.",
			"helm": "Weave where the captain says.",
		}, func(): return passed("field"), Callable(), func(): return pos_of("field"))
		add("Drones and grabbers! Fight them off", {
			"*": "Everybody's busy now. Listen to the captain!",
		}, func(): return count("killed_drone") + count("killed_grabber") >= 4, func():
			w.spawn("drone", ahead(440, 1.0), {"ai": "drone"})
			w.spawn("drone", ahead(460, -1.0), {"ai": "drone"})
			w.spawn("grabber", ahead(-420), {"ai": "grabber"})
			w.spawn("grabber", ahead(430, 2.2), {"ai": "grabber"}))
		add("Reach Haven and stop next to it, with Thrupp on your tail", {
			"engines": "Boost if you must, but don't cook it.",
			"helm": "To Haven!",
			"captain": "Thrupp's patrol fires in threes. Get everyone home.",
		}, func():
			var hp: Variant = pos_of("haven")
			return hp != null and w.ship.pos.distance_to(hp) < 180.0 and w.ship.speed() < 10.0, func():
				w.spawn("patrol", ahead(-460), {"ai": "patrol", "speed": 60.0, "tag": "patrol"}), func(): return pos_of("haven"))
