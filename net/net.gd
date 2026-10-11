extends Node
## Network glue (autoload "Net"). The host is authoritative: clients send intents, the host sends
## filtered snapshots. The host's own player is a local client (no network hop).

signal snapshot(data: Dictionary)
signal event(data: Dictionary)
signal connected
signal disconnected(reason: String)
signal join_failed(reason: String)

var host: GameHost = null
var is_host: bool = false
var is_connected_online: bool = false
var my_id: int = 1
var player_name: String = "Captain"
var peer: WebSocketMultiplayerPeer = null
var last_snapshot: Dictionary = {}
var last_lobby: Dictionary = {}
var dedicated: bool = false

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
	if peer != null:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = null
	is_host = false
	is_connected_online = false
	last_snapshot = {}
	last_lobby = {}

func start_host(pname: String, port: int = K.PORT_DEFAULT, listen: bool = true, local_player: bool = true) -> Error:
	shutdown()
	player_name = pname
	is_host = true
	my_id = 1
	if listen:
		peer = WebSocketMultiplayerPeer.new()
		var err: Error = peer.create_server(port)
		if err != OK:
			peer = null
			is_host = false
			return err
		multiplayer.multiplayer_peer = peer
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

func join(ip: String, port: int, pname: String) -> Error:
	shutdown()
	player_name = pname
	peer = WebSocketMultiplayerPeer.new()
	var url: String = "ws://%s:%d" % [ip, port]
	var err: Error = peer.create_client(url)
	if err != OK:
		peer = null
		return err
	multiplayer.multiplayer_peer = peer
	is_host = false
	return OK

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
	if not is_host or host == null:
		return
	host.handle_msg(multiplayer.get_remote_sender_id(), kind, data)

@rpc("authority", "call_remote", "unreliable_ordered")
func cl_snap(data: Dictionary) -> void:
	last_snapshot = data
	snapshot.emit(data)

@rpc("authority", "call_remote", "reliable")
func cl_event(data: Dictionary) -> void:
	if data.get("t", "") == "lobby":
		last_lobby = data
	event.emit(data)

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
			if data.get("t", "") == "lobby":
				last_lobby = data
			event.emit(data)
		if multiplayer.multiplayer_peer != null:
			for rp in multiplayer.get_peers():
				cl_event.rpc_id(rp, data)
	elif pid == 1:
		if not dedicated:
			event.emit(data)
	elif multiplayer.multiplayer_peer != null:
		cl_event.rpc_id(pid, data)

# ---------------------------------------------------------------- connection callbacks

func _on_peer_connected(id: int) -> void:
	if is_host and host != null:
		# the client will say hello with its name; send the lobby right away
		cl_event.rpc_id(id, host.lobby_dict())

func _on_peer_disconnected(id: int) -> void:
	if is_host and host != null:
		host.remove_peer(id)

func _on_connected_to_server() -> void:
	my_id = multiplayer.get_unique_id()
	is_connected_online = true
	send("hello", {"name": player_name})
	connected.emit()

func _on_connection_failed() -> void:
	is_connected_online = false
	join_failed.emit("Could not reach the host. Check the address, port and firewall.")

func _on_server_disconnected() -> void:
	is_connected_online = false
	last_snapshot = {}
	disconnected.emit("The host went away.")
