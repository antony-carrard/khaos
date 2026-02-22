class_name VillageRemoveStrategy extends PlacementStrategy


func on_click(controller: PlacementController, q: int, r: int) -> bool:
	return controller.board_manager.on_village_removed(q, r)


func get_validity(controller: PlacementController, q: int, r: int) -> bool:
	var village = controller.village_manager.get_village_at(q, r)
	return village != null and village.player_owner == controller.board_manager.current_player


func update_tooltip(controller: PlacementController, q: int, r: int, is_valid: bool) -> void:
	if not (controller.board_manager and controller.board_manager.ui):
		return
	if is_valid:
		var tile = controller.tile_manager.get_tile_at(q, r)
		if tile:
			var player = controller.board_manager.current_player
			if player:
				var building_cost = player.get_village_cost(tile.village_building_cost)
				var sell_refund: int = building_cost / 2
				controller.board_manager.ui.show_village_sell_tooltip(true, sell_refund)
				return
	controller.board_manager.ui.show_village_sell_tooltip(false)
