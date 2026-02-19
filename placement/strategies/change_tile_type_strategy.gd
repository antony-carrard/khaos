class_name ChangeTileTypeStrategy extends PlacementStrategy


# Returns false — placement stays active until resource type is selected
func on_click(controller: PlacementController, q: int, r: int) -> bool:
	controller.board_manager.show_resource_type_selection(q, r)
	return false


func get_validity(controller: PlacementController, q: int, r: int) -> bool:
	var village = controller.village_manager.get_village_at(q, r)
	return village != null and village.player_owner == controller.board_manager.current_player
