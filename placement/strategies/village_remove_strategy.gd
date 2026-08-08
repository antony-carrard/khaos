class_name VillageRemoveStrategy extends PlacementStrategy


func on_click(controller: PlacementController, q: int, r: int) -> bool:
	return controller.board_manager.on_village_removed(q, r)


func get_validity(controller: PlacementController, q: int, r: int) -> bool:
	var village = controller.village_manager.get_village_at(q, r)
	if not village:
		return false
	if village.player_owner == controller.board_manager.current_player:
		return true
	return controller.board_manager.can_destroy_enemy_village(q, r)


func update_tooltip(controller: PlacementController, q: int, r: int, is_valid: bool) -> void:
	if not (controller.board_manager and controller.board_manager.ui):
		return
	if not is_valid:
		controller.board_manager.ui.show_resource_gain_tooltip(false)
		return
	var village = controller.village_manager.get_village_at(q, r)
	var tile = controller.tile_manager.get_tile_at(q, r)
	if not village or not tile:
		controller.board_manager.ui.show_resource_gain_tooltip(false)
		return
	if village.player_owner == controller.board_manager.current_player:
		controller.board_manager.ui.show_resource_gain_tooltip(true, 0)
	else:
		var bm = controller.board_manager
		var cost: Dictionary = bm._compute_demolition_cost(q, r)
		controller.board_manager.ui.show_village_cost_tooltip(true, cost["res_cost"], cost["act_cost"])
