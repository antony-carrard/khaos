class_name UpgradeTileStrategy extends PlacementStrategy


func on_click(controller: PlacementController, q: int, r: int) -> bool:
	return controller.board_manager.power_executor.on_upgrade_tile(q, r)


func get_validity(controller: PlacementController, q: int, r: int) -> bool:
	var village = controller.village_manager.get_village_at(q, r)
	if village == null or village.player_owner != controller.board_manager.current_player:
		return false
	var tile = controller.tile_manager.get_tile_at(q, r)
	if tile == null or tile.tile_type == TileManager.TileType.MOUNTAIN:
		return false
	var next_type = TileManager.TileType.HILLS if tile.tile_type == TileManager.TileType.PLAINS \
		else TileManager.TileType.MOUNTAIN
	return controller.board_manager.tile_pool.has_tile_of_type(next_type)
