class_name GameState

## Serializable snapshot of a whole game — everything needed to rebuild the board,
## the players and the bag from nothing.
##
## Only durable game state is captured. The transient context of an action in
## progress (the power being aimed, its hand pick, its collected board picks) and
## everything visual (UI, camera, placement previews) are deliberately left out:
## a snapshot is only ever taken between actions, when none of that is live.
##
## The snapshot is a plain Dictionary of Variants, and is persisted with
## store_var() rather than as JSON. Tile yields are keyed by
## TileDefinition.ResourceType — that is, by integer — and JSON stringifies
## integer dictionary keys on every round-trip. Godot's own Variant encoding
## preserves them exactly and is what RPC already speaks, so save files and
## network snapshots share one format with no conversion layer between them.
##
## capture()/apply() are a matched pair and stay pure data: apply() restores the
## players, the bag and the board, but does no UI or scene re-wiring. That part
## belongs to whoever owns those references — see board_manager.restore_snapshot(),
## which is the entry point gameplay should actually call.

const SAVE_PATH := "user://savegame.dat"
## Written after every action — by the host of a network game, or by a hot-seat
## game — so it can be resumed from the main menu. Removed when the game ends.
## One slot per mode, so a local game never overwrites a network one.
const NETWORK_AUTOSAVE_PATH := "user://network_autosave.dat"
const LOCAL_AUTOSAVE_PATH := "user://local_autosave.dat"

## Bumped whenever the snapshot layout changes incompatibly. load_from_file()
## refuses anything it doesn't recognise rather than half-restoring it.
const FORMAT_VERSION := 1


## The autosave slot for a game played in `mode`.
static func autosave_path_for(mode: int) -> String:
	return NETWORK_AUTOSAVE_PATH if mode == GameConfig.GameMode.NETWORK else LOCAL_AUTOSAVE_PATH


## Captures the full state of a running game.
static func capture(board_manager: Node3D) -> Dictionary:
	var players_data: Array = []
	for player in board_manager.players:
		players_data.append(player.to_dict())

	return {
		"version": FORMAT_VERSION,
		"players": players_data,
		"current_player_index": board_manager.current_player_index,
		"tiles": board_manager.tile_manager.to_dict(),
		"villages": board_manager.village_manager.to_dict(board_manager.players),
		"tile_pool": board_manager.tile_pool.to_dict(),
		"final_round_triggered": board_manager.final_round_triggered,
		# -1 when the final round hasn't been triggered (players.find(null)).
		"triggering_player_index": board_manager.players.find(board_manager.triggering_player),
		"villages_built_this_turn": _plain_copy(board_manager.villages_built_this_turn),
		"villages_demolished_this_turn": _plain_copy(board_manager.villages_demolished_this_turn),
	}


## Copies a typed Dictionary into an untyped one. A typed container carries its
## type through store_var() and RPC, but comes back untyped on the far side and
## then won't assign straight back into the typed field it came from — so the
## snapshot holds plain dictionaries throughout and the restore rebuilds the
## typing element by element.
static func _plain_copy(typed: Dictionary) -> Dictionary:
	var plain := {}
	for key in typed:
		plain[key] = typed[key]
	return plain


## Writes a snapshot of the running game to `path`. Returns false on I/O failure.
static func save_to_file(board_manager: Node3D, path: String = SAVE_PATH) -> bool:
	if not write_to_file(capture(board_manager), path):
		return false
	Log.info("GameState: saved to %s" % path)
	return true


## Writes an already-captured snapshot to `path`, for callers that need the
## snapshot for something else too. Returns false on I/O failure.
static func write_to_file(snapshot: Dictionary, path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		Log.error("GameState: cannot write %s (error %d)" % [path, FileAccess.get_open_error()])
		return false
	file.store_var(snapshot)
	return true


## Reads a snapshot back from `path`. Returns an empty Dictionary if the file is
## missing, unreadable, or written by an incompatible format version.
static func load_from_file(path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		Log.warn("GameState: no save file at %s" % path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		Log.error("GameState: cannot read %s (error %d)" % [path, FileAccess.get_open_error()])
		return {}

	var data = file.get_var()
	if typeof(data) != TYPE_DICTIONARY:
		Log.error("GameState: %s does not contain a snapshot" % path)
		return {}

	var version = data.get("version", 0)
	if version != FORMAT_VERSION:
		Log.error("GameState: %s is format version %s, expected %d" % [path, version, FORMAT_VERSION])
		return {}

	Log.info("GameState: loaded from %s" % path)
	return data


## Restores a running game to the state described by `snapshot`.
##
## Reconciles rather than rebuilds — see TileManager.apply() for why — so calling
## this on a board that already nearly matches only touches what actually differs.
## Returns false without changing anything if the snapshot can't be applied.
static func apply(board_manager: Node3D, snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return false

	var players_data: Array = snapshot["players"]
	if players_data.size() != board_manager.players.size():
		# Refused rather than partially applied: a half-restored game is far
		# harder to diagnose than a load that plainly didn't happen. The caller
		# is responsible for standing up the right number of players first.
		Log.error("GameState: snapshot has %d players, game has %d" % [
			players_data.size(), board_manager.players.size()])
		return false

	for i in range(players_data.size()):
		board_manager.players[i].from_dict(players_data[i])

	board_manager.tile_pool.from_dict(snapshot["tile_pool"])

	# Tiles before villages: a village sits on top of the stack beneath it, so
	# its height isn't known until the tiles have settled.
	board_manager.tile_manager.apply(snapshot["tiles"])
	board_manager.village_manager.apply(snapshot["villages"], board_manager.players)

	# Restored as plain data, keeping current_player's documented invariant.
	# board_manager.restore_snapshot() then re-runs the same switch through
	# _switch_to_player() to rebind the UI — idempotent, and it keeps this
	# function free of scene concerns.
	board_manager.current_player_index = snapshot["current_player_index"]
	board_manager.current_player = board_manager.players[board_manager.current_player_index]

	board_manager.final_round_triggered = snapshot["final_round_triggered"]
	var trigger_index: int = snapshot["triggering_player_index"]
	board_manager.triggering_player = board_manager.players[trigger_index] if trigger_index >= 0 else null

	_restore_typed(board_manager.villages_built_this_turn, snapshot["villages_built_this_turn"])
	_restore_typed(board_manager.villages_demolished_this_turn, snapshot["villages_demolished_this_turn"])

	return true


## Refills a typed Dictionary from a plain one, element by element. A typed
## container survives store_var() and RPC but arrives untyped on the far side,
## and an untyped Dictionary won't assign straight into a typed field.
static func _restore_typed(target: Dictionary, source: Dictionary) -> void:
	target.clear()
	for key in source:
		target[key] = source[key]
