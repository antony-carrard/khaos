class_name UpgradeTileStrategy extends PlacementStrategy


func on_click(controller: PlacementController, q: int, r: int) -> bool:
	return controller.board_manager.on_upgrade_tile(q, r)


func get_validity(controller: PlacementController, q: int, r: int) -> bool:
	var village = controller.village_manager.get_village_at(q, r)
	if village == null or village.player_owner != controller.board_manager.current_player:
		return false
	var tile = controller.tile_manager.get_tile_at(q, r)
	return tile != null and tile.tile_type != TileManager.TileType.MOUNTAIN
