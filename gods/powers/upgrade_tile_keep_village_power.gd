class_name UpgradeTileKeepVillagePower
extends GodPower

## Augia major power — upgrade an own tile a level without destroying its village.

func _init():
	super("Élévation divine", "Augmenter une Tuile d'un niveau sans détruire le Bâtiment", 5)


func is_valid_target(board_manager: Node3D, q: int, r: int) -> bool:
	var village = board_manager.village_manager.get_village_at(q, r)
	if village == null or village.player_owner != board_manager.current_player:
		return false
	var tile = board_manager.tile_manager.get_tile_at(q, r)
	if tile == null or tile.tile_type == TileDefinition.TileType.MOUNTAIN:
		return false
	var next_type = TileDefinition.TileType.HILLS if tile.tile_type == TileDefinition.TileType.PLAINS \
		else TileDefinition.TileType.MOUNTAIN
	return board_manager.tile_pool.has_tile_of_type(next_type)


func apply_effect(board_manager: Node3D, q: int, r: int) -> bool:
	var success: bool = board_manager.tile_manager.upgrade_tile(q, r)
	if success:
		var new_height = board_manager.tile_manager.get_top_height(q, r)
		var world_pos = HexGridUtils.axial_to_world(q, r, new_height)
		var village = board_manager.village_manager.get_village_at(q, r)
		village.global_position = world_pos + Vector3(0, HexGridUtils.TILE_HEIGHT / 2, 0)
		Log.info("Upgraded tile at (%d, %d) with UpgradeTileKeepVillagePower" % [q, r])
	return success
