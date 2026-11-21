extends SceneTree
## Measures how the game loop plays out, with robot crews flying dealt jobs.
##   godot --headless --path . --script tools/loop_probe.gd        (N=jobs per setting, default 18)
## For each setting (normal / hard pace; instant robots / a "talking" crew that takes ~3 s to react) it reports:
## job length against par, success, incidents and the gaps between them, how often the Captain has an urgent
## call to make, how busy each role is and its longest idle stretch, and where contacts are relative to the radar.

const ROLES: Dictionary = {"driver": ["helm", "shields"], "stoker": ["engines", "weapons"], "tech": ["sensors", "engineer"]}

func _init() -> void:
	Progress.persist = false
	var n: int = int(OS.get_environment("N")) if OS.get_environment("N") != "" else 18
	var only: String = OS.get_environment("ONLY")
	for setting in [["normal", false, 1.0], ["normal", false, 15.0], ["hard", true, 1.0], ["hard", true, 15.0]]:
		if only != "" and only != "%s-%s" % [setting[0], "instant" if float(setting[2]) <= 1.0 else "talking"]:
			continue
		_run(str(setting[0]), bool(setting[1]), float(setting[2]), n)
	quit(0)

func _run(label: String, hard: bool, think: float, n: int) -> void:
	Bot.think_scale = think
	var career: Progress = Progress.new()
	career.unlock_all()
	career.full_deck = true
	career.hard = hard
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 4242
	var agg: Dictionary = {"jobs": 0, "done": 0, "t": 0.0, "par": 0.0, "hull": 0.0, "incidents": 0, "gaps": [], "urgent": 0, "minutes": 0.0,
		"busy": {"driver": 0, "stoker": 0, "tech": 0}, "samples": 0, "idle_max": {"driver": [], "stoker": [], "tech": []},
		"contacts": 0, "beyond_radar": 0, "kinds": {}, "first_seen": [], "glitches": 0, "tasks": {}}
	var jobs: Array = []
	while jobs.size() < n:
		for o in Jobs.offers(rng, career):
			jobs.append(o)
	for spec in jobs.slice(0, n):
		_job(spec, career, agg)
	var mins: float = maxf(0.01, float(agg.minutes))
	var gaps: Array = agg.gaps
	gaps.sort()
	var gap_mean: float = 0.0
	for g in gaps:
		gap_mean += float(g)
	gap_mean = gap_mean / maxf(1.0, gaps.size())
	print("\n== %s pace, %s crew (%d jobs) ==" % [label, "instant" if think <= 1.0 else "talking (~3 s)", int(agg.jobs)])
	print("  finished %d/%d   time %.0f s vs par %.0f s (%.0f%%)   hull left %.0f%%" % [int(agg.done), int(agg.jobs),
		float(agg.t) / agg.jobs, float(agg.par) / agg.jobs, 100.0 * float(agg.t) / maxf(1.0, float(agg.par)), float(agg.hull) / agg.jobs])
	print("  incidents %.1f per job, %.2f per minute; gap between incidents: mean %.0f s, shortest %.0f s, median %.0f s" % [
		float(agg.incidents) / agg.jobs, float(agg.incidents) / mins, gap_mean, float(gaps[0]) if not gaps.is_empty() else -1.0,
		float(gaps[gaps.size() / 2]) if not gaps.is_empty() else -1.0])
	print("  glitches %.1f per job;  urgent captain calls (new level-2+ warnings) %.1f per minute" % [float(agg.glitches) / agg.jobs, float(agg.urgent) / mins])
	for r in ROLES:
		var im: Array = agg.idle_max[r]
		var mean_idle: float = 0.0
		for x in im:
			mean_idle += float(x)
		mean_idle /= maxf(1.0, im.size())
		print("  %-7s busy %3.0f%% of the time; longest idle stretch per job: mean %.0f s, worst %.0f s" % [r, 100.0 * float(agg.busy[r]) / maxf(1.0, agg.samples),
			mean_idle, float(im.max()) if not im.is_empty() else 0.0])
	var fs: Array = agg.first_seen
	fs.sort()
	print("  contacts: %d; first seen on radar at median %.0f m (radar reaches %.0f m); %d%% of contacts spent time beyond radar but on the Captain's chart" % [
		int(agg.contacts), float(fs[fs.size() / 2]) if not fs.is_empty() else -1.0, World.RADAR_RANGE, int(100.0 * float(agg.beyond_radar) / maxf(1.0, agg.contacts))])
	print("  tasks: %s" % str(agg.tasks))
	var ks: Array = (agg.kinds as Dictionary).keys()
	ks.sort_custom(func(a, b): return int(agg.kinds[a]) > int(agg.kinds[b]))
	var top: Array = []
	for k in ks.slice(0, 10):
		top.append("%s: %.1f/min" % [k, float(agg.kinds[k]) / mins])
	print("  urgent warnings by kind: " + ", ".join(PackedStringArray(top)))

func _job(spec: Dictionary, career: Progress, agg: Dictionary) -> void:
	var w: World = World.new(int(spec.seed))
	var m: Mission = Jobs.make(spec, career)
	m.setup(w)
	var bots: Array = []
	for st in K.STATIONS:
		bots.append(Bot.new(st))
	var limit: float = m.par * 3.0 + 120.0
	var sample_t: float = 0.0
	var idle: Dictionary = {"driver": 0.0, "stoker": 0.0, "tech": 0.0}
	var idle_max: Dictionary = {"driver": 0.0, "stoker": 0.0, "tech": 0.0}
	var last_inc: float = -1.0
	var seen_warn: Dictionary = {}
	var seen_ent: Dictionary = {}
	var beyond: Dictionary = {}
	var last_thr: float = 0.0
	var last_dir: float = 0.0
	agg.tasks[str(spec.task)] = int(agg.tasks.get(str(spec.task), 0)) + 1
	while w.t < limit and not m.done and not m.failed:
		for b in bots:
			b.tick(w, K.DT)
		w.step(K.DT)
		for ev in w.events:
			m.on_event(str(ev[0]), ev[1])
			if str(ev[0]) in ["incident", "glitch"]:
				agg.incidents = int(agg.incidents) + 1
				if str(ev[0]) == "glitch":
					agg.glitches = int(agg.glitches) + 1
				if last_inc >= 0.0:
					(agg.gaps as Array).append(w.t - last_inc)
				last_inc = w.t
		w.events.clear()
		sample_t += K.DT
		if sample_t < 0.5:
			continue
		sample_t = 0.0
		var s: Ship = w.ship
		var warns: Array = Snapshots.forecasts(w)
		var who: Dictionary = {}
		for f in warns:
			var key: String = str(f.text).left(18)
			if int(f.level) >= 2 and not seen_warn.has(key):
				agg.urgent = int(agg.urgent) + 1
				var kind: String = " ".join(PackedStringArray(str(f.text).split(" ").slice(0, 2)))
				for d in "0123456789%!":
					kind = kind.replace(d, "")
				agg.kinds[kind] = int(agg.kinds.get(kind, 0)) + 1
			seen_warn[key] = true
			who[K.role_of(str(f.get("who", "")))] = true
		# drop warnings that have gone, so a repeat counts again
		for k in seen_warn.keys():
			var still: bool = false
			for f2 in warns:
				if str(f2.text).left(18) == k:
					still = true
			if not still:
				seen_warn.erase(k)
		var busy: Dictionary = {
			"driver": who.has("driver") or absf(s.wheel) > 0.05 or absf(K.wrap_pi(s.shield_dir - last_dir)) > 0.05,
			"stoker": who.has("stoker") or s.firing or absf(s.throttle - last_thr) > 0.02 or s.boost,
			"tech": who.has("tech") or w.scanning or s.repairing or s.tractor_on,
		}
		last_thr = s.throttle
		last_dir = s.shield_dir
		agg.samples = int(agg.samples) + 1
		for r in busy:
			if busy[r]:
				agg.busy[r] = int(agg.busy[r]) + 1
				idle[r] = 0.0
			else:
				idle[r] = float(idle[r]) + 0.5
				idle_max[r] = maxf(float(idle_max[r]), float(idle[r]))
		for e in w.ents:
			if not e.alive or e.kind == "ring" or e.ai == "thrown":
				continue
			var d: float = e.pos.distance_to(s.pos)
			if not seen_ent.has(e.id):
				seen_ent[e.id] = -1.0
				agg.contacts = int(agg.contacts) + 1
			if d <= w.radar_range and float(seen_ent[e.id]) < 0.0:
				seen_ent[e.id] = d
				(agg.first_seen as Array).append(d)
			if d > w.radar_range and d < 1000.0 and not beyond.has(e.id):
				beyond[e.id] = true
				agg.beyond_radar = int(agg.beyond_radar) + 1
	agg.jobs = int(agg.jobs) + 1
	agg.done = int(agg.done) + (1 if m.done else 0)
	agg.t = float(agg.t) + w.t
	agg.par = float(agg.par) + m.par
	agg.hull = float(agg.hull) + w.ship.hull
	agg.minutes = float(agg.minutes) + w.t / 60.0
	for r2 in idle_max:
		(agg.idle_max[r2] as Array).append(idle_max[r2])
