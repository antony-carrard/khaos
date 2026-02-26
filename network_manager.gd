extends Node

## Manages ENet multiplayer connections and the authoritative start_game RPC.
## Host generates the RNG seed and peer→player map, then broadcasts to all peers.
## All machines load main.tscn simultaneously with identical GameConfig state.

signal server_created
signal connection_succeeded
signal connection_failed
signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal lobby_updated  # emitted on all machines when peer_names changes

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 4

var is_host: bool = false
# peer_id → player_index (populated by start_game RPC)
var peer_player_map: Dictionary = {}
# peer_id → player name (host authoritative, synced to all via _sync_peer_names)
var peer_names: Dictionary = {}


func get_player_index(peer_id: int) -> int:
	return peer_player_map.get(peer_id, -1)


func create_server(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	server_created.emit()
	return OK


func join_server(ip: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	return OK


func disconnect_network() -> void:
	multiplayer.multiplayer_peer = null
	is_host = false
	peer_player_map.clear()
	peer_names.clear()


func get_connected_peers() -> Array[int]:
	if not multiplayer.multiplayer_peer:
		return []
	var result: Array[int] = []
	result.assign(multiplayer.get_peers())
	return result


## Host registers their own name (peer 1 — no RPC needed).
func register_host_name(name: String) -> void:
	peer_names[1] = name
	_broadcast_lobby()


## Client → host: registers the caller's name. Host stores it and rebroadcasts lobby.
@rpc("any_peer", "call_remote", "reliable")
func register_name(name: String) -> void:
	peer_names[multiplayer.get_remote_sender_id()] = name
	_broadcast_lobby()


## Broadcasts current peer_names to all machines (including host via call_local).
func _broadcast_lobby() -> void:
	rpc("_sync_peer_names", peer_names.duplicate())


## Received by all machines: updates local peer_names and notifies UI.
@rpc("authority", "call_local", "reliable")
func _sync_peer_names(names: Dictionary) -> void:
	peer_names = names
	lobby_updated.emit()


## Called by host to restart the current game on all machines simultaneously.
## Generates a fresh RNG seed so the rematch has a different tile order.
@rpc("authority", "call_local", "reliable")
func restart_game(rng_seed: int) -> void:
	GameConfig.network_rng_seed = rng_seed
	get_tree().reload_current_scene()


## Called by host to start the game on all machines simultaneously.
## p_peer_player_map: {peer_id (int) → player_index (int)}
@rpc("authority", "call_local", "reliable")
func start_game(player_count: int, p_peer_player_map: Dictionary, rng_seed: int) -> void:
	peer_player_map = p_peer_player_map
	GameConfig.mode = GameConfig.GameMode.NETWORK
	GameConfig.player_count = player_count
	GameConfig.local_player_index = peer_player_map.get(multiplayer.get_unique_id(), 0)
	GameConfig.network_rng_seed = rng_seed
	# Build player_names array ordered by player_index, falling back to "Player N"
	var names: Array[String] = []
	names.resize(player_count)
	for i in range(player_count):
		names[i] = "Player %d" % (i + 1)
	for pid in peer_player_map:
		var idx: int = peer_player_map[pid]
		if idx < player_count and peer_names.has(pid):
			names[idx] = peer_names[pid]
	GameConfig.player_names = names
	GameConfig.initialized = true
	get_tree().change_scene_to_file("res://main.tscn")


func _on_connected_to_server() -> void:
	connection_succeeded.emit()


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	connection_failed.emit()


func _on_peer_connected(id: int) -> void:
	if is_host:
		_broadcast_lobby()  # Shows "…" for new peer until they register their name
	peer_connected.emit(id)


func _on_peer_disconnected(id: int) -> void:
	peer_names.erase(id)
	if is_host:
		_broadcast_lobby()
	peer_disconnected.emit(id)
