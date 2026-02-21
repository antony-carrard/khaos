class_name DestroyVillageFreeStrategy extends PlacementStrategy


func on_click(controller: PlacementController, q: int, r: int) -> bool:
	return controller.board_manager.power_executor.on_destroy_village_free(q, r)


func get_validity(controller: PlacementController, q: int, r: int) -> bool:
	var village = controller.village_manager.get_village_at(q, r)
	return village != null and village.player_owner != controller.board_manager.current_player
