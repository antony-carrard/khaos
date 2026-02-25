extends Node

## Manages ENet multiplayer connections and the authoritative start_game RPC.
## Host generates the RNG seed and peer→player map, then broadcasts to all peers.
## All machines load main.tscn simultaneously with identical GameConfig state.

signal server_created
signal connection_succeeded
signal connection_failed
signal peer_connected(id: int)
signal peer_disconnected(id: int)

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 4

var is_host: bool = false
# peer_id → player_index (populated by start_game RPC)
var peer_player_map: Dictionary = {}


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


func get_connected_peers() -> Array[int]:
	if not multiplayer.multiplayer_peer:
		return []
	var result: Array[int] = []
	result.assign(multiplayer.get_peers())
	return result


## Called by host to start the game on all machines simultaneously.
## p_peer_player_map: {peer_id (int) → player_index (int)}
@rpc("authority", "call_local", "reliable")
func start_game(player_count: int, p_peer_player_map: Dictionary, rng_seed: int) -> void:
	peer_player_map = p_peer_player_map
	GameConfig.mode = GameConfig.GameMode.NETWORK
	GameConfig.player_count = player_count
	GameConfig.local_player_index = peer_player_map.get(multiplayer.get_unique_id(), 0)
	GameConfig.network_rng_seed = rng_seed
	GameConfig.initialized = true
	get_tree().change_scene_to_file("res://main.tscn")


func _on_connected_to_server() -> void:
	connection_succeeded.emit()


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	connection_failed.emit()


func _on_peer_connected(id: int) -> void:
	peer_connected.emit(id)


func _on_peer_disconnected(id: int) -> void:
	peer_disconnected.emit(id)
