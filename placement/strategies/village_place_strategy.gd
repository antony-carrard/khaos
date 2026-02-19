class_name VillagePlaceStrategy extends PlacementStrategy


func on_click(controller: PlacementController, q: int, r: int) -> bool:
	return controller.board_manager.on_village_placed(q, r)


func get_validity(controller: PlacementController, q: int, r: int) -> bool:
	if controller.village_manager.has_village_at(q, r):
		return false

	var tile = controller.tile_manager.get_tile_at(q, r)
	if not tile:
		return false

	var player = controller.board_manager.current_player
	if not player:
		return false

	var cost = player.get_village_cost(tile.village_building_cost)
	if player.resources < cost:
		return false

	if not controller.board_manager.turn_manager.is_actions_phase():
		return false

	if player.actions_remaining <= 0:
		return false

	return true


func update_tooltip(controller: PlacementController, _q: int, _r: int, _is_valid: bool) -> void:
	if controller.board_manager and controller.board_manager.ui:
		controller.board_manager.ui.show_village_sell_tooltip(false)
