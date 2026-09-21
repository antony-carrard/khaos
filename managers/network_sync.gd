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
## Every method is a no-op in hot-seat, so board_manager calls them unguarded.

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


func _ready() -> void:
	# No-op in hot-seat: the signal never fires.
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)


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
## action, accepted or not.
func broadcast_state() -> void:
	if is_host and not game_over:
		rpc("_rpc_state", GameState.capture(board))


## Host side: pushes the final state to every client and has them show the
## victory screen. Clients never run the turn flow that would otherwise reach
## board._trigger_game_end(). Marks the game over on every peer.
func broadcast_game_over() -> void:
	if is_host and not game_over:
		rpc("_rpc_game_over", GameState.capture(board))
	game_over = true


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


## A remote peer dropped mid-game: everyone returns to the main menu. Rejoin is
## the next step of the state-replication plan.
func _on_peer_disconnected(_id: int) -> void:
	Log.warn("Network: A peer disconnected — returning to main menu")
	# Disconnect self first to prevent re-entrant calls: disconnect_network() nulls
	# the ENet peer which can flush pending events and re-fire peer_disconnected.
	NetworkManager.peer_disconnected.disconnect(_on_peer_disconnected)
	NetworkManager.disconnect_network()
	# Defer so the current frame finishes before the scene tree tears down this node.
	get_tree().call_deferred("change_scene_to_file", "res://main_menu.tscn")
