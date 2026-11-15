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
signal name_registered(id: int, name: String)  # host only: a client registered its name
signal rejoin_refused(reason: String)  # client only: the host's game in progress had no seat for us

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 4

var is_host: bool = false
# peer_id → player_index (populated by start_game RPC)
var peer_player_map: Dictionary = {}
# peer_id → player name (host authoritative, synced to all via _sync_peer_names)
var peer_names: Dictionary = {}
# Lobby resuming a saved game: the save's player names, one per seat, and
# peer_id → seat for the peers seated so far. Both empty in an ordinary lobby.
# Host authoritative, synced to all with peer_names.
var resume_names: Array[String] = []
var resume_seats: Dictionary = {}


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
	# Disconnect all multiplayer signals before clearing the peer.
	# These are connected in create_server() / join_server() and persist across
	# scene changes, so without explicit disconnects they accumulate each session.
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.multiplayer_peer:
		# Explicit, so the other side gets a disconnect packet rather than a timeout.
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_host = false
	peer_player_map.clear()
	peer_names.clear()
	resume_names.clear()
	resume_seats.clear()


## Closing the window: drop the connection now, while the game scene is still
## intact, so the other peers hear about it at once instead of after an ENet
## timeout, and nothing in the game reacts to a disconnect mid-teardown.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and multiplayer.multiplayer_peer:
		disconnect_network()


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


## Host: opens a lobby that resumes a saved game. The host takes the seat
## matching its name. Returns false, changing nothing, if there's none.
func open_resume_lobby(host_name: String, save_names: Array[String]) -> bool:
	var all_seats: Array[int] = []
	all_seats.assign(range(save_names.size()))
	var seat := NetworkSync.find_rejoin_seat(host_name, save_names, all_seats)
	if seat < 0:
		return false
	resume_names = save_names.duplicate()
	resume_seats = {1: seat}
	return true


## Host, resume lobby: the seat a joining peer named `player_name` takes — the
## lowest one with that name nobody holds yet — or -1.
func _free_resume_seat(player_name: String) -> int:
	var free_seats: Array[int] = []
	for seat in range(resume_names.size()):
		if not resume_seats.values().has(seat):
			free_seats.append(seat)
	return NetworkSync.find_rejoin_seat(player_name, resume_names, free_seats)


## Client → host: registers the caller's name. Host stores it and rebroadcasts lobby.
## In a resume lobby the name must match a free seat of the saved game.
@rpc("any_peer", "call_remote", "reliable")
func register_name(name: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not resume_names.is_empty():
		var seat := _free_resume_seat(name)
		if seat < 0:
			rpc_id(id, "refuse_rejoin", "Resuming a saved game — no free seat named %s" % name)
			return
		resume_seats[id] = seat
	peer_names[id] = name
	_broadcast_lobby()
	# A game in progress listens for this to seat a returning player (NetworkSync).
	name_registered.emit(id, name)


## Broadcasts current peer_names to all machines (including host via call_local).
func _broadcast_lobby() -> void:
	rpc("_sync_peer_names", peer_names.duplicate(), resume_names.duplicate(), resume_seats.duplicate())


## Received by all machines: updates local peer_names (and resume seats) and notifies UI.
@rpc("authority", "call_local", "reliable")
func _sync_peer_names(names: Dictionary, p_resume_names: Array, p_resume_seats: Dictionary) -> void:
	peer_names = names
	resume_names.assign(p_resume_names)
	resume_seats = p_resume_seats
	lobby_updated.emit()


## Called by host to restart the current game on all machines simultaneously.
@rpc("authority", "call_local", "reliable")
func restart_game() -> void:
	# A rematch is a fresh game for everyone, a rejoined client included.
	GameConfig.rejoining = false
	get_tree().reload_current_scene()


## Called by host to start the game on all machines simultaneously.
## p_peer_player_map: {peer_id (int) → player_index (int)}
@rpc("authority", "call_local", "reliable")
func start_game(player_count: int, p_peer_player_map: Dictionary) -> void:
	peer_player_map = p_peer_player_map
	GameConfig.mode = GameConfig.GameMode.NETWORK
	GameConfig.player_count = player_count
	GameConfig.local_player_index = peer_player_map.get(multiplayer.get_unique_id(), 0)
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
	GameConfig.rejoining = false
	GameConfig.initialized = true
	get_tree().change_scene_to_file("res://main.tscn")


## Host, resume lobby: starts the saved game. Seated clients go in as rejoining
## players (they take their state from the host's snapshot); seats nobody took
## start absent, and their players can rejoin by name later.
func start_resumed_game(snapshot: Dictionary) -> void:
	var names := resume_names.duplicate()
	peer_player_map = resume_seats.duplicate()
	for pid in peer_player_map:
		if pid != 1:
			rpc_id(pid, "rejoin_game", names, peer_player_map[pid])
	GameConfig.mode = GameConfig.GameMode.NETWORK
	GameConfig.player_count = names.size()
	GameConfig.local_player_index = peer_player_map[1]
	GameConfig.player_names = names
	GameConfig.rejoining = false
	GameConfig.resume_snapshot = snapshot
	GameConfig.initialized = true
	# Over now: in the game, a name registering is a player rejoining (NetworkSync).
	resume_names.clear()
	resume_seats.clear()
	get_tree().change_scene_to_file("res://main.tscn")


## Host → one client: seats the caller in the game already running on the host,
## in the seat it left. Skips god selection; the client takes its whole state,
## player names included, from the host's snapshot (see board_manager._ready()).
@rpc("authority", "call_remote", "reliable")
func rejoin_game(p_player_names: Array, local_index: int) -> void:
	GameConfig.mode = GameConfig.GameMode.NETWORK
	GameConfig.player_count = p_player_names.size()
	GameConfig.local_player_index = local_index
	GameConfig.player_names.assign(p_player_names)
	GameConfig.rejoining = true
	GameConfig.initialized = true
	get_tree().change_scene_to_file("res://main.tscn")


## Host → one client: a game is in progress and none of its seats is ours.
@rpc("authority", "call_remote", "reliable")
func refuse_rejoin(reason: String) -> void:
	disconnect_network()
	rejoin_refused.emit(reason)


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
	resume_seats.erase(id)
	if is_host:
		_broadcast_lobby()
	peer_disconnected.emit(id)
