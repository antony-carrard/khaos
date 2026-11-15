class_name NetworkSync extends Node

## The network transport for a running game — every RPC a game session sends or
## receives lives here, so board_manager only holds game logic.
##
## Model: host-authoritative state replication. A client never mutates its own
## game. Its action entry points call send_intent(), which asks peer 1 (the host)
## to perform the action; the host runs the same local code a hot-seat game runs,
## then broadcast_state() pushes the resulting GameState snapshot to every
## client, which applies it through board.restore_snapshot(). The rules therefore
## run exactly once, on the host.
##
## Must sit at the same scene path on every peer (a child of board_manager named
## "NetworkSync") before the first RPC is sent — god selection is the earliest.
## Every method is a no-op in hot-seat, so board_manager calls them unguarded —
## except the autosave in broadcast_state()/broadcast_game_over(), which a
## hot-seat game uses too, so it can be continued from the main menu.

## The board_manager this node serves. Set before it enters the tree.
var board: Node3D

## Clients only: true from the moment an action intent is sent until the host's
## snapshot answers it. Action entry points refuse input while set — the client's
## copy of the game is stale until the reply lands, so a second click could pass
## checks against numbers that no longer hold. The host answers every intent
## with a snapshot, even a rejected one, so the lock always releases.
var awaiting_host: bool = false

## Set by broadcast_game_over(). Stops the host broadcasting per-action snapshots
## on top of the game-over message, which would re-run _switch_to_player() on
## clients and put the turn overlay back over the victory screen.
var game_over: bool = false

## Indices of players whose peer has dropped out of a game in progress. Session
## state, not game state: it lives outside the snapshot, the host owns it and
## pushes it to clients through _rpc_presence.
var absent_players: Array[int] = []

## Where broadcast_state() autosaves: this mode's slot. Fixed at construction,
## which is fine since GameConfig is set before the game scene loads. A var so
## tests can point it away from the real autosave.
var autosave_path: String = GameState.autosave_path_for(GameConfig.mode)

## Set once this peer starts heading back to the main menu, so the several
## disconnect signals a dying connection can fire only act once.
var _leaving: bool = false

## Emitted on every peer whenever absent_players changes.
signal presence_changed


## True when running in NETWORK mode.
var is_network: bool:
	get: return GameConfig.initialized and GameConfig.mode == GameConfig.GameMode.NETWORK

## True on a NETWORK peer that isn't the host. The host is also a player and
## runs the same local code as hot-seat, so this — not is_network — is what the
## action entry points branch on.
var is_client: bool:
	get: return is_network and not NetworkManager.is_host

## True on the NETWORK host.
var is_host: bool:
	get: return is_network and NetworkManager.is_host

## True where this game is autosaved: the network host, or a hot-seat game.
## Never a client (the host owns the game), and never a game run straight
## from the editor — a test_mode session must not overwrite a real save.
var autosaves: bool:
	get: return GameConfig.initialized and not is_client


func _ready() -> void:
	# No-op in hot-seat: the signals never fire.
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	NetworkManager.name_registered.connect(_on_name_registered)
	multiplayer.server_disconnected.connect(func() -> void: _return_to_menu("Lost connection to the host"))


# ==================== OUTBOUND ====================

## Client side: sends an action intent to the host, or refuses if one is already
## in flight. Returns whether it was sent.
func send_intent(method: StringName, args: Array) -> bool:
	if awaiting_host:
		Log.debug("Ignoring input: still waiting for the host to answer the previous action")
		return false
	awaiting_host = true
	callv("rpc_id", [1, method] + args)
	return true


## Host side: pushes the current game to every client. Called after every
## action, accepted or not. Also autosaves it (host or hot-seat), so the game
## can be resumed from the main menu after a crash or a quit.
func broadcast_state() -> void:
	if game_over or not autosaves:
		return
	var snapshot := GameState.capture(board)
	if is_host:
		_rpc_seated("_rpc_state", [snapshot])
	GameState.write_to_file(snapshot, autosave_path)


## Host side: pushes the final state to every client and has them show the
## victory screen. Clients never run the turn flow that would otherwise reach
## board._trigger_game_end(). Marks the game over on every peer.
func broadcast_game_over() -> void:
	if is_host and not game_over:
		_rpc_seated("_rpc_game_over", [GameState.capture(board)])
	if autosaves and not game_over:
		# A finished game has nothing to resume.
		DirAccess.remove_absolute(autosave_path)
	game_over = true


## Host side: sends an RPC to every client holding a seat. Not rpc(): that also
## reaches peers that have connected but aren't in the game — a returning player
## still on the main menu — whose tree has no NetworkSync to receive it.
func _rpc_seated(method: StringName, args: Array) -> void:
	for peer_id in NetworkManager.peer_player_map:
		if peer_id != multiplayer.get_unique_id():
			callv("rpc_id", [peer_id, method] + args)


## Client side: asks the host for a snapshot. Sent once startup completes (and,
## later, on rejoin).
func request_state() -> void:
	rpc_id(1, "_rpc_request_state")


## Tells every other peer which god the local player picked.
func send_god_selected(player_index: int, god_id: String) -> void:
	rpc("_rpc_god_selected", player_index, god_id)


# ==================== INBOUND ====================

## Host side: whether an incoming intent should be acted on. A rejected intent
## still gets a snapshot in reply (see the handlers) so the sender's lock clears.
func _accept_intent() -> bool:
	if not NetworkManager.is_host:
		push_warning("Intent received by a non-host peer — ignored")
		return false
	return _validate_sender()


## Validates that an incoming RPC comes from the peer whose turn it currently is.
func _validate_sender() -> bool:
	var sender_id := multiplayer.get_remote_sender_id()
	var sender_player := NetworkManager.get_player_index(sender_id)
	if sender_player != board.current_player_index:
		push_warning("RPC from wrong player (got player %d, expected player %d)" % [sender_player, board.current_player_index])
		return false
	return true


@rpc("any_peer", "call_remote", "reliable")
func _rpc_god_selected(player_index: int, god_id: String) -> void:
	board.on_remote_god_selected(player_index, god_id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_intent_place_tile(hand_index: int, q: int, r: int) -> void:
	if _accept_intent():
		board.on_tile_placed_from_hand(hand_index, q, r)
	else:
		broadcast_state()


## Refused outside debug builds, so a release host can't be fed free tiles.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_intent_debug_place_tile(tile_type: int, q: int, r: int) -> void:
	if OS.is_debug_build() and _accept_intent():
		board.debug_place_tile(tile_type, q, r)
	else:
		broadcast_state()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_intent_place_village(q: int, r: int) -> void:
	if _accept_intent():
		board.on_village_placed(q, r)
	else:
		broadcast_state()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_intent_remove_village(q: int, r: int) -> void:
	if _accept_intent():
		board.on_village_removed(q, r)
	else:
		broadcast_state()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_intent_end_turn() -> void:
	if _accept_intent():
		board.on_end_turn_requested()
	else:
		broadcast_state()


## The activation context (hand pick and collected board picks) travels with the
## intent because the host has no local UI events to derive it from; it's
## installed on the board before resolving, exactly where a local click would
## have left it.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_intent_power_resolve(slot: int, q: int, r: int, hand_index: int, selection: Array) -> void:
	var power: GodPower = board.current_player.god.get_power(slot) if _accept_intent() else null
	if power == null:
		push_warning("_rpc_intent_power_resolve: no usable power in slot %d" % slot)
		broadcast_state()
		return
	board.power_hand_index = hand_index
	# Rebuilt element by element rather than assigned: the wire hands back a
	# plain Array, which won't assign straight into a typed one.
	board.power_selected_villages.clear()
	for village_pos in selection:
		board.power_selected_villages.append(village_pos)
	board._resolve_power_target(power, q, r)


## Client → host once the client has finished starting up (and, later, when it
## rejoins). Answered with a direct _rpc_state. Ignored until the host itself
## has finished _ready(), because before that the snapshot would be pre-deal —
## the host's own end-of-_ready() broadcast reaches that client instead.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_state() -> void:
	if not NetworkManager.is_host or not board.game_started:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if NetworkManager.get_player_index(sender_id) < 0:
		push_warning("_rpc_request_state from unknown peer %d" % sender_id)
		return
	rpc_id(sender_id, "_rpc_state", GameState.capture(board))
	rpc_id(sender_id, "_rpc_presence", absent_players)


## Host → clients after every action. "authority" means only peer 1 may send it.
@rpc("authority", "call_remote", "reliable")
func _rpc_state(snapshot: Dictionary) -> void:
	awaiting_host = false
	board.restore_snapshot(snapshot)


## Host → clients when the game ends, carrying the final state.
@rpc("authority", "call_remote", "reliable")
func _rpc_game_over(snapshot: Dictionary) -> void:
	awaiting_host = false
	board.restore_snapshot(snapshot)
	board._trigger_game_end()


## Host → clients whenever a seat empties. The host keeps its own copy current
## through _set_absent_players() instead of receiving this.
@rpc("authority", "call_remote", "reliable")
func _rpc_presence(absent: Array) -> void:
	_set_absent_players(absent)


func _set_absent_players(absent: Array) -> void:
	absent_players.assign(absent)
	presence_changed.emit()


## A peer dropped. Once the game is running the host carries on without it: the
## seat is marked absent and its turns are skipped from the host (see
## board.skip_absent_turn()). Only losing the host, or a drop during god
## selection, still sends everyone back to the menu.
func _on_peer_disconnected(id: int) -> void:
	if not is_host:
		# Other seats come and go through _rpc_presence; only the host matters here.
		if id == 1:
			_return_to_menu("Lost connection to the host")
		return
	var index := NetworkManager.get_player_index(id)
	if index < 0:
		# Never seated — e.g. a peer turned away by _on_name_registered().
		return
	if not board.game_started:
		# God selection waits on each seat's pick in turn and can't continue one short.
		_return_to_menu("A player disconnected during god selection")
		return
	Log.warn("Network: %s disconnected — their turns will need skipping" % board.players[index].player_name)
	NetworkManager.peer_player_map.erase(id)
	var absent := absent_players.duplicate()
	absent.append(index)
	_set_absent_players(absent)
	_rpc_seated("_rpc_presence", [absent_players])


## Host side, resuming a saved game: seats nobody took in the lobby start
## absent, so their turns can be skipped and their players can rejoin by name.
## Clients learn it in reply to their _rpc_request_state.
func mark_unseated_absent() -> void:
	if not is_host:
		return
	var seated := NetworkManager.peer_player_map.values()
	var absent: Array[int] = []
	for index in range(board.players.size()):
		if not seated.has(index):
			absent.append(index)
	_set_absent_players(absent)


## Host side: a peer registered its name while this game is running, so it's a
## player coming back — seat it in the absent seat with that name, or turn it
## away. The name is the key because the peer id changes on every connection.
func _on_name_registered(id: int, player_name: String) -> void:
	if not is_host:
		return
	var names: Array[String] = []
	for player in board.players:
		names.append(player.player_name)
	var index := find_rejoin_seat(player_name, names, absent_players)
	var reason := ""
	if not board.game_started:
		reason = "The game is still in god selection"
	elif game_over:
		reason = "The game has ended"
	elif index < 0:
		reason = "Game in progress — no disconnected player named %s" % player_name
	if not reason.is_empty():
		Log.info("Network: turned away %s — %s" % [player_name, reason])
		NetworkManager.rpc_id(id, "refuse_rejoin", reason)
		return
	Log.info("Network: %s rejoined" % player_name)
	var absent := absent_players.duplicate()
	absent.erase(index)
	_set_absent_players(absent)
	# Before seating it: the returning peer is still on the main menu and gets
	# presence in reply to its own _rpc_request_state.
	_rpc_seated("_rpc_presence", [absent_players])
	NetworkManager.peer_player_map[id] = index
	NetworkManager.rpc_id(id, "rejoin_game", names, index)


## The seat a returning player named `player_name` takes back: the lowest-index
## absent seat with that name, or -1. Only absent seats count — a connected
## player's seat is never handed over, even if the names match.
static func find_rejoin_seat(player_name: String, player_names: Array[String], absent: Array[int]) -> int:
	for index in range(player_names.size()):
		if absent.has(index) and player_names[index] == player_name:
			return index
	return -1


## The local player chose to quit (Esc menu).
func leave_game() -> void:
	_return_to_menu("Left the game")


func _return_to_menu(reason: String) -> void:
	# disconnect_network() nulls the ENet peer, which can flush pending events and
	# re-fire the disconnect signals that brought us here.
	if _leaving:
		return
	_leaving = true
	Log.warn("Network: %s — returning to main menu" % reason)
	# Both deferred: this usually runs inside the ENet peer's own disconnect
	# signal, and freeing the peer while it's still emitting crashes the engine.
	# The scene change also waits for the current frame to finish.
	NetworkManager.call_deferred("disconnect_network")
	get_tree().call_deferred("change_scene_to_file", "res://main_menu.tscn")
