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
## This class only captures and persists. Rebuilding a live game from a snapshot
## is the next step, and lands in the managers that own the scene nodes.

const SAVE_PATH := "user://savegame.dat"

## Bumped whenever the snapshot layout changes incompatibly. load_from_file()
## refuses anything it doesn't recognise rather than half-restoring it.
const FORMAT_VERSION := 1


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
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		Log.error("GameState: cannot write %s (error %d)" % [path, FileAccess.get_open_error()])
		return false
	file.store_var(capture(board_manager))
	Log.info("GameState: saved to %s" % path)
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
