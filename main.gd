extends Node
## Entry point: menu -> lobby -> game. Also handles a few command-line flags for tests and servers.

var layer: CanvasLayer
var root_ui: Control
var menu: MenuUI
var lobby: LobbyUI
var game: GameUI
var state: String = "menu"
var args: Dictionary = {}

func _ready() -> void:
	get_window().title = "Yes, Captain!"
	layer = CanvasLayer.new()
	add_child(layer)
	root_ui = Control.new()
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.theme = UIK.theme()
	layer.add_child(root_ui)
	menu = MenuUI.new()
	menu.host_pressed.connect(_on_host)
	menu.solo_pressed.connect(_on_solo)
	menu.join_pressed.connect(_on_join)
	menu.quit_pressed.connect(func(): get_tree().quit())
	root_ui.add_child(menu)
	lobby = LobbyUI.new()
	lobby.leave_pressed.connect(_leave)
	lobby.visible = false
	root_ui.add_child(lobby)
	game = GameUI.new()
	game.leave_pressed.connect(_leave)
	game.visible = false
	root_ui.add_child(game)
	Net.event.connect(_on_event)
	Net.connected.connect(func(): _show("lobby"))
	Net.join_failed.connect(func(r: String): menu.show_msg(r))
	Net.disconnected.connect(func(r: String): _leave(); menu.show_msg(r))
	_parse_args()
	if args.has("autotest"):
		RunState.persist = false

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("server"):
		var port: int = int(args.get("port", K.PORT_DEFAULT))
		var err: Error = Net.start_host("Server", port, true, false)
		print("Yes, Captain! dedicated host on port %d (err %d)" % [port, err])
		Net.host.default_personality = "random"
		_show("lobby")
		lobby.set_addresses(true, port)
	elif args.has("host"):
		_on_host("Captain")
	elif args.has("solo"):
		_on_solo("Captain")
	elif args.has("join"):
		_on_join("Crew", str(args.join), int(args.get("port", K.PORT_DEFAULT)))
	if args.has("autotest"):
		_autotest.call_deferred()
	if args.has("clienttest"):
		_clienttest.call_deferred()
	if args.has("menushot"):
		_menushot.call_deferred()

func _menushot() -> void:
	await get_tree().create_timer(0.8).timeout
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(str(args.menushot))
	get_tree().quit(0)

func _clienttest() -> void:
	## A remote player: joins a dedicated host, becomes admin, starts a game and flies for a bit.
	var t0: float = Time.get_ticks_msec() / 1000.0
	while not Net.is_connected_online and Time.get_ticks_msec() / 1000.0 - t0 < 6.0:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(0.8).timeout
	print("CLIENTTEST connected=", Net.is_connected_online, " id=", Net.my_id, " state=", state)
	Net.send("claim", {"seat": "captain"})
	Net.send("claim", {"seat": "helm"})
	Net.send("opt", {"key": "mode", "val": "shift"})
	Net.send("opt", {"key": "shift_kind", "val": "drones"})
	Net.send("opt", {"key": "personality", "val": "competent"})
	await get_tree().create_timer(0.8).timeout
	await _shot("client_lobby")
	Net.send("start", {})
	await get_tree().create_timer(2.0).timeout
	print("CLIENTTEST in-game state=", state, " active=", Net.last_snapshot.get("active", "?"), " phase=", Net.last_snapshot.get("phase", "?"))
	Net.send("active", {"seat": "helm"})
	await get_tree().create_timer(0.6).timeout
	var pokes: int = 0
	if game.stations.has("helm"):
		pokes = _poke_ui(game.stations["helm"])
	await get_tree().create_timer(1.5).timeout
	await _shot("client_helm")
	Net.send("active", {"seat": "captain"})
	await get_tree().create_timer(1.0).timeout
	await _shot("client_captain")
	print("CLIENTTEST done pokes=", pokes, " snapshot_has_view=", Net.last_snapshot.has("view"))
	get_tree().quit(0)

func _shot(name: String) -> void:
	var dir: String = str(args.get("shots", ""))
	if dir == "":
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [dir, name])

func _tour() -> void:
	## AI crew plays the whole run while we screenshot every phase change as the captain.
	var seen: Dictionary = {}
	var t0: float = Time.get_ticks_msec() / 1000.0
	var limit: float = float(args.get("limit", 120.0))
	var shots: int = 0
	var last_key: String = ""
	if args.has("stress") and Net.host != null and Net.host.world != null:
		Net.host.world.director.intensity = 5.0
		Net.host.world.director.cooldown = 2.0
		if args.has("nobots"):
			Net.host.bots.clear()
		else:
			Net.host.bots.erase("ops")
			Net.host.bots.erase("helm")
	if args.has("seat"):
		Net.send("active", {"seat": str(args.seat)})
		var every: float = float(args.get("every", 4.0))
		var n: int = 0
		while Time.get_ticks_msec() / 1000.0 - t0 < limit:
			await get_tree().create_timer(every).timeout
			await _shot("seat_%s_%02d" % [str(args.seat), n])
			n += 1
		get_tree().quit(0)
		return
	if args.has("manual"):
		Net.host.bot_captain.auto_continue = false
	while Time.get_ticks_msec() / 1000.0 - t0 < limit:
		await get_tree().create_timer(0.5).timeout
		if Net.host == null:
			break
		var h: GameHost = Net.host
		var key: String = h.phase + (":" + h.world.enc.id if h.phase == "encounter" and h.world.enc != null else "")
		if key != last_key:
			last_key = key
			await get_tree().create_timer(float(args.get("settle", 2.0))).timeout
			await _shot("tour_%02d_%s" % [shots, key.replace(":", "_")])
			shots += 1
			if args.has("manual") and (h.phase == "debrief" or h.phase == "gameover"):
				h.captain_continue()
				last_key = ""
		if h.phase == "ending" or h.phase == "lobby":
			await get_tree().create_timer(1.0).timeout
			await _shot("tour_%02d_%s" % [shots, h.phase])
			break
	print("TOUR DONE phase=", Net.host.phase if Net.host != null else "-", " shots=", shots)
	get_tree().quit(0)

func _force_phase(ph: String) -> void:
	var h: GameHost = Net.host
	h.bot_captain.auto_continue = false
	h.world.enc.finish(true)
	await get_tree().create_timer(0.3).timeout
	if ph == "debrief":
		return
	if ph == "gameover":
		h.world.ship.hull = -1.0
		h.phase = "encounter"
		h.world.enc.done = false
		return
	h.captain_continue()
	await get_tree().create_timer(0.3).timeout
	if ph == "staging":
		h._helm_code(str(h.run.options()[0].code))
		h.world.ship.alloc["ops"] = 4
		h.world.ship.jump_charge = 0.5
		return
	if ph == "pitstop":
		h.run.scrap = 80
		h._begin_pitstop()
		h.pit["requests"]["turbo"] = "engines"
		h.pit["requests"]["beacon"] = "sensors"
		return
	if ph == "ending":
		h.run.finished = true
		h._finish_run("fin_haven")
		h.phase = "ending"
		return

func _poke_ui(root: Node) -> int:
	## Presses every enabled button, drags every lever, clicks every pip: smoke-tests all UI -> intent paths.
	var n: int = 0
	for b in root.find_children("*", "Button", true, false):
		var bt: Button = b
		if not bt.is_visible_in_tree() or bt.disabled or bt is OptionButton:
			continue
		if bt is SafetyBtn:
			bt.pressed.emit()
			bt.pressed.emit()
			n += 2
			continue
		bt.button_down.emit()
		if bt.toggle_mode:
			bt.button_pressed = not bt.button_pressed
		else:
			bt.pressed.emit()
		bt.button_up.emit()
		n += 1
	for l in root.find_children("*", "Lever", true, false):
		var lv: Lever = l
		if lv.is_visible_in_tree() and not lv.disabled:
			lv.value = lv.vmin + (lv.vmax - lv.vmin) * 0.3
			lv.changed.emit(lv.value)
			n += 1
	for p in root.find_children("*", "PipRow", true, false):
		var pr: PipRow = p
		if pr.is_visible_in_tree():
			pr.changed.emit(3)
			n += 1
	for le in root.find_children("*", "LineEdit", true, false):
		var ed: LineEdit = le
		if ed.is_visible_in_tree() and ed.editable and ed.placeholder_text.begins_with("e.g."):
			ed.text = "123-45"
			ed.text_submitted.emit(ed.text)
			n += 1
	return n

func _exercise() -> void:
	await get_tree().create_timer(0.6).timeout
	var kind: String = str(args.get("autotest", "drones"))
	Net.send("opt", {"key": "mode", "val": "shift"})
	Net.send("opt", {"key": "shift_kind", "val": kind})
	for seat in K.SEATS:
		Net.send("claim", {"seat": seat})
	await get_tree().create_timer(0.3).timeout
	Net.send("start", {})
	await get_tree().create_timer(1.0).timeout
	var total: int = 0
	for round in 2:
		for seat in ["helm", "engines", "power", "weapons", "sensors", "ops", "dc"]:
			Net.send("active", {"seat": seat})
			await get_tree().create_timer(0.35).timeout
			var ui: Node = game.stations.get(seat)
			if seat == "dc" and ui != null and Net.host != null and Net.host.world != null:
				var sh: Ship = Net.host.world.ship
				sh.set_fire("ENG_P")
				sh.set_breach("RCS_FP")
				sh.modules["TUR_A"].hp = 5.0
				sh.modules["SENS"].hp = 5.0
				sh.modules["SENS"].fault = "mirror"
				sh.cut_conduit("C_UTIL", false)
				sh.cut_conduit("C_CORE", true)
				await get_tree().create_timer(0.4).timeout
				for mid in sh.mod_order:
					(ui as DamageControlUI).selected = mid
					await get_tree().create_timer(0.1).timeout
					total += _poke_ui(ui)
			if ui != null:
				total += _poke_ui(ui)
			await get_tree().create_timer(0.2).timeout
	Net.send("active", {"seat": "captain"})
	await get_tree().create_timer(0.5).timeout
	if game.cap_ui != null:
		total += _poke_ui(game.cap_ui)
		game.cap_ui.orders_panel.visible = true
		total += _poke_ui(game.cap_ui.orders_panel)
	await get_tree().create_timer(1.0).timeout
	var st: Dictionary = Net.host.world.stats.inputs if Net.host != null and Net.host.world != null else {}
	print("EXERCISE DONE pokes=", total, " inputs=", st, " phase=", Net.host.phase)
	get_tree().quit(0)

func _sharetest() -> void:
	## Two players: the captain (us) and a fake crew member on Sensors who shares their screen.
	await get_tree().create_timer(0.6).timeout
	Net.send("opt", {"key": "mode", "val": "shift"})
	Net.send("opt", {"key": "shift_kind", "val": "bastion"})
	Net.send("opt", {"key": "personality", "val": "competent"})
	var h: GameHost = Net.host
	h.add_peer(2, "Sensors Sam")
	h.claim(2, "sensors")
	Net.send("start", {})
	await get_tree().create_timer(1.0).timeout
	h.handle_msg(2, "active", {"seat": "sensors"})
	h.handle_msg(2, "share", {"on": true})
	await get_tree().create_timer(0.8).timeout
	await _shot("share_offer")
	for b in game.cap_ui.find_children("*", "Button", true, false):
		if (b as Button).text == "Show me" and (b as Button).is_visible_in_tree():
			(b as Button).pressed.emit()
	await get_tree().create_timer(1.2).timeout
	await _shot("share_shown")
	print("SHARETEST shared=", game.cap_ui.shared_holder.visible, " ui=", game.cap_ui.shared_ui != null)
	for b2 in game.cap_ui.find_children("*", "Button", true, false):
		if (b2 as Button).text == "BACK TO WINDOW" and (b2 as Button).is_visible_in_tree():
			(b2 as Button).pressed.emit()
	await get_tree().create_timer(0.6).timeout
	print("SHARETEST after back: visible=", game.cap_ui.shared_holder.visible)
	get_tree().quit(0)

func _autotest() -> void:
	if args.has("sharetest"):
		_sharetest()
		return
	if args.has("exercise"):
		_exercise()
		return
	## Drives the real UI against the real host: claims every seat, flips through every screen.
	await get_tree().create_timer(0.6).timeout
	var kind: String = str(args.get("autotest", "casual"))
	var mode: String = str(args.get("mode", "shift"))
	Net.send("opt", {"key": "mode", "val": mode})
	Net.send("opt", {"key": "shift_kind", "val": kind})
	Net.send("opt", {"key": "length", "val": "short"})
	Net.send("opt", {"key": "personality", "val": "competent"})
	if Net.host != null:
		Net.host.time_scale = float(args.get("speed", 1.0))
	if args.has("aicrew"):
		Net.send("opt", {"key": "ai_captain", "val": true})
	await get_tree().create_timer(0.3).timeout
	await _shot("00_lobby")
	if args.has("aicrew"):
		Net.send("claim", {"seat": "captain"})
		if args.has("seat"):
			Net.send("claim", {"seat": str(args.seat)})
		await get_tree().create_timer(0.3).timeout
		await _shot("01_lobby_claimed")
		Net.send("start", {})
		await _tour()
		return
	for seat in K.SEATS:
		Net.send("claim", {"seat": seat})
	await get_tree().create_timer(0.3).timeout
	await _shot("01_lobby_claimed")
	Net.send("start", {})
	await get_tree().create_timer(1.5).timeout
	var order: Array = ["captain", "helm", "engines", "power", "weapons", "sensors", "ops", "dc"]
	var wait: float = float(args.get("wait", 1.5))
	if args.has("phase"):
		await _force_phase(str(args.phase))
	for seat in order:
		Net.send("active", {"seat": seat})
		await get_tree().create_timer(wait).timeout
		await _shot("02_" + seat)
	# poke some intents so the sim has something to chew on
	Net.send("active", {"seat": "engines"})
	await get_tree().create_timer(0.3).timeout
	Net.intent("engines", "thr", 0.6)
	Net.send("active", {"seat": "captain"})
	await get_tree().create_timer(float(args.get("tail", 3.0))).timeout
	await _shot("03_captain_late")
	print("DBG root_ui size=", root_ui.size, " game size=", game.size, " shell=", game.shell.size, " vp=", get_viewport().get_visible_rect(), " menu=", menu.size, " lobby=", lobby.size)
	if game.cap_ui != null:
		var cu: CaptainUI = game.cap_ui
		print("DBG cap_ui pos=", cu.position, " size=", cu.size, " frame size=", cu.frame.size, " svc pos=", cu.svc.position, " size=", cu.svc.size, " sv size=", cu.sv.size, " c3d ents=", cu.c3d.nodes.size(), " cam pos=", cu.c3d.cam.global_position)
	print("AUTOTEST DONE phase=", Net.host.phase if Net.host != null else "-")
	get_tree().quit(0)

func _show(which: String) -> void:
	state = which
	menu.visible = which == "menu"
	lobby.visible = which == "lobby"
	game.visible = which == "game"
	if which == "lobby" and Net.last_lobby.has("seats"):
		lobby.update_lobby(Net.last_lobby)

func _on_host(pname: String) -> void:
	var port: int = K.PORT_DEFAULT
	var err: Error = Net.start_host(pname if pname.strip_edges() != "" else "Captain", port, true, true)
	if err != OK:
		menu.show_msg("Couldn't open port %d (is another game running?)" % port)
		return
	_show("lobby")
	lobby.set_addresses(true, port)

func _on_solo(pname: String) -> void:
	var err: Error = Net.start_host(pname if pname.strip_edges() != "" else "Captain", K.PORT_DEFAULT, false, true)
	if err != OK:
		menu.show_msg("Couldn't start solo mode.")
		return
	_show("lobby")
	lobby.set_addresses(false, 0)

func _on_join(pname: String, ip: String, port: int) -> void:
	if ip == "":
		menu.show_msg("Type the host's address first.")
		return
	var err: Error = Net.join(ip, port, pname if pname.strip_edges() != "" else "Crew")
	if err != OK:
		menu.show_msg("Couldn't connect to that address.")
		return
	menu.show_msg("Connecting...")

func _leave() -> void:
	Net.shutdown()
	game.reset()
	_show("menu")
	menu.show_msg("")

func _on_event(d: Dictionary) -> void:
	match str(d.get("t", "")):
		"lobby":
			if state == "lobby":
				lobby.update_lobby(d)
		"started":
			game.reset()
			_show("game")
		"to_lobby":
			game.reset()
			_show("lobby")
			if Net.last_lobby.has("seats"):
				lobby.update_lobby(Net.last_lobby)
