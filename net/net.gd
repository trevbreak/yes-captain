extends Node
## Network glue (autoload "Net"). The host is authoritative: clients send intents, the host sends
## filtered snapshots. Three ways to run:
##   local   a GameHost in this process (solo play, or a LAN host whose own player has no network hop)
##   server  a Hub with many rooms (the Docker container)
##   client  a browser or desktop player connected to either of the above

signal snapshot(data: Dictionary)
signal event(data: Dictionary)
signal connected
signal disconnected(reason: String)
signal join_failed(reason: String)

var host: GameHost = null
var hub: Hub = null
var is_host: bool = false
var is_connected_online: bool = false
var my_id: int = 1
var player_name: String = "Captain"
var peer: WebSocketMultiplayerPeer = null
var last_snapshot: Dictionary = {}
var last_lobby: Dictionary = {}
var last_rooms: Dictionary = {}
var dedicated: bool = false
var room_code: String = ""        # the room we're in on a server ("" = none, or a direct LAN host)
var want_room: String = ""        # join this room as soon as the server says hello back
var _connecting_t: float = -1.0

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func shutdown() -> void:
	if host != null:
		host.queue_free()
		host = null
	if hub != null:
		hub.queue_free()
		hub = null
	if peer != null:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = null
	is_host = false
	is_connected_online = false
	dedicated = false
	last_snapshot = {}
	last_lobby = {}
	last_rooms = {}
	room_code = ""
	_connecting_t = -1.0

func _listen(port: int) -> Error:
	peer = WebSocketMultiplayerPeer.new()
	peer.inbound_buffer_size = 256 * 1024
	peer.outbound_buffer_size = 2 * 1024 * 1024
	peer.max_queued_packets = 8192
	var err: Error = peer.create_server(port)
	if err != OK:
		peer = null
		return err
	multiplayer.multiplayer_peer = peer
	return OK

func start_host(pname: String, port: int = K.PORT_DEFAULT, listen: bool = true, local_player: bool = true) -> Error:
	## one game in this process; friends on the LAN can join it directly
	shutdown()
	player_name = pname
	if listen:
		var err: Error = _listen(port)
		if err != OK:
			return err
	is_host = true
	my_id = 1
	host = GameHost.new()
	add_child(host)
	host.snap_ready.connect(_on_snap_ready)
	host.event_ready.connect(_on_event_ready)
	dedicated = not local_player
	if local_player:
		host.add_peer(1, pname)
		host.claim(1, "captain")
		# the host player is the admin
		host.admin = 1
	else:
		host.admin = 0
	is_connected_online = true
	return OK

func start_server(port: int = K.PORT_DEFAULT, max_rooms: int = 20) -> Error:
	## the public server: a hub of rooms and no player of its own
	shutdown()
	var err: Error = _listen(port)
	if err != OK:
		return err
	dedicated = true
	hub = Hub.new()
	hub.max_rooms = max_rooms
	add_child(hub)
	hub.send_event.connect(_hub_event)
	hub.send_snap.connect(_hub_snap)
	return OK

func join(ip: String, port: int, pname: String) -> Error:
	return join_url("ws://%s:%d" % [ip, port], pname)

func join_url(url: String, pname: String) -> Error:
	shutdown()
	player_name = pname
	peer = WebSocketMultiplayerPeer.new()
	# a browser tab in the background runs slowly and snapshots pile up: give them room rather than lose any
	peer.inbound_buffer_size = 4 * 1024 * 1024
	peer.max_queued_packets = 8192
	var err: Error = peer.create_client(url)
	if err != OK:
		peer = null
		return err
	multiplayer.multiplayer_peer = peer
	is_host = false
	_connecting_t = 0.0
	return OK

func _process(delta: float) -> void:
	if _connecting_t >= 0.0:
		_connecting_t += delta
		if _connecting_t > 10.0:
			_connecting_t = -1.0
			shutdown()
			join_failed.emit("Nobody answered. Is the server running?")

func is_server() -> bool:
	return hub != null

func in_hub() -> bool:
	## connected to a server with rooms (as opposed to one LAN game)
	return not is_host and is_connected_online and not last_rooms.is_empty()

# ---------------------------------------------------------------- sending (from UI)

func send(kind: String, data: Dictionary = {}) -> void:
	if is_host:
		if host != null:
			host.handle_msg(1, kind, data)
	elif multiplayer.multiplayer_peer != null and is_connected_online:
		srv_msg.rpc_id(1, kind, data)

func intent(station: String, key: String, val: Variant) -> void:
	send("intent", {"station": station, "key": key, "val": val})

@rpc("any_peer", "call_remote", "reliable")
func srv_msg(kind: String, data: Dictionary) -> void:
	var from: int = multiplayer.get_remote_sender_id()
	if hub != null:
		hub.handle(from, kind, data)
	elif is_host and host != null:
		host.handle_msg(from, kind, Hub.clean(data, 240))

@rpc("authority", "call_remote", "unreliable_ordered")
func cl_snap(data: Dictionary) -> void:
	last_snapshot = data
	snapshot.emit(data)

@rpc("authority", "call_remote", "reliable")
func cl_event(data: Dictionary) -> void:
	_note_event(data)
	event.emit(data)

func _note_event(data: Dictionary) -> void:
	match str(data.get("t", "")):
		"lobby":
			last_lobby = data
		"rooms":
			last_rooms = data
			if want_room != "":
				var code: String = want_room
				want_room = ""
				send("join", {"code": code})
		"joined":
			room_code = str(data.get("code", ""))
		"left", "kicked":
			room_code = ""
			last_lobby = {}
			last_snapshot = {}
		"career":
			# our crew's career, sent back by the server so it survives in this browser
			if not is_host:
				Progress.local().apply_dict(data.get("data"))
				Progress.local().save()

# ---------------------------------------------------------------- host-side delivery

func _on_snap_ready(pid: int, data: Dictionary) -> void:
	if pid == 1 and not dedicated:
		last_snapshot = data
		snapshot.emit(data)
	elif pid != 1 and multiplayer.multiplayer_peer != null:
		cl_snap.rpc_id(pid, data)

func _on_event_ready(pid: int, data: Dictionary) -> void:
	if pid == 0:
		if not dedicated:
			_note_event(data)
			event.emit(data)
		if multiplayer.multiplayer_peer != null:
			for rp in multiplayer.get_peers():
				cl_event.rpc_id(rp, data)
	elif pid == 1:
		if not dedicated:
			event.emit(data)
	elif multiplayer.multiplayer_peer != null:
		cl_event.rpc_id(pid, data)

func _hub_event(pid: int, data: Dictionary) -> void:
	if multiplayer.multiplayer_peer != null and pid in multiplayer.get_peers():
		cl_event.rpc_id(pid, data)

func _hub_snap(pid: int, data: Dictionary) -> void:
	if multiplayer.multiplayer_peer != null and pid in multiplayer.get_peers():
		cl_snap.rpc_id(pid, data)

# ---------------------------------------------------------------- connection callbacks

func _on_peer_connected(id: int) -> void:
	if is_host and host != null:
		# the client will say hello with its name; send the lobby right away
		cl_event.rpc_id(id, host.lobby_dict())

func _on_peer_disconnected(id: int) -> void:
	if hub != null:
		hub.drop(id)
	elif is_host and host != null:
		host.remove_peer(id)

func _on_connected_to_server() -> void:
	my_id = multiplayer.get_unique_id()
	is_connected_online = true
	_connecting_t = -1.0
	send("hello", {"name": player_name})
	connected.emit()

func _on_connection_failed() -> void:
	is_connected_online = false
	_connecting_t = -1.0
	join_failed.emit("Could not reach the server. Check the address.")

func _on_server_disconnected() -> void:
	is_connected_online = false
	last_snapshot = {}
	disconnected.emit("Lost the connection to the server.")
