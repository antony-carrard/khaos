class_name BuildAnywherePower
extends GodPower

## Le Bâtisseur major power — builds a village on any vacant tile, paying only
## the power's fervor cost instead of the tile's usual material cost. Routes
## through board_manager's normal construction bounty (apply_village_construction,
## cost 0) so the glory formula stays in one place, shared with a regular build.

func _init():
	super("Construction divine", "Construire un village sur n'importe quelle tuile vacante", 6)


func is_valid_target(board_manager: Node3D, q: int, r: int) -> bool:
	if board_manager.village_manager.has_village_at(q, r):
		return false
	return board_manager.tile_manager.get_tile_at(q, r) != null


func apply_effect(board_manager: Node3D, q: int, r: int) -> bool:
	var tile: HexTile = board_manager.tile_manager.get_tile_at(q, r)
	var success: bool = board_manager.village_manager.place_village(q, r, board_manager.current_player)
	if success:
		board_manager.villages_built_this_turn[Vector2i(q, r)] = true
		var glory: int = board_manager.apply_village_construction(tile, board_manager.current_player, 0)
		Log.info("Built village at (%d, %d) with BuildAnywherePower, gained %d glory" % [q, r, glory])
	return success
