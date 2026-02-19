class_name StealHarvestStrategy extends PlacementStrategy


func on_click(controller: PlacementController, q: int, r: int) -> bool:
	return controller.board_manager.on_steal_harvest(q, r)


func get_validity(controller: PlacementController, q: int, r: int) -> bool:
	var village = controller.village_manager.get_village_at(q, r)
	return village != null and village.player_owner != controller.board_manager.current_player


func update_tooltip(controller: PlacementController, q: int, r: int, is_valid: bool) -> void:
	if not (controller.board_manager and controller.board_manager.ui):
		return
	if is_valid:
		var tile = controller.tile_manager.get_tile_at(q, r)
		if tile:
			controller.board_manager.ui.show_village_sell_tooltip(true, tile.yield_value)
			return
	controller.board_manager.ui.show_village_sell_tooltip(false)
