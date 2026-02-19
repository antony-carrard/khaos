class_name TilePlacementStrategy extends PlacementStrategy

func _init() -> void:
	uses_tile_preview = true


func on_click(controller: PlacementController, _q: int, _r: int) -> bool:
	if not controller.preview_tile.visible:
		return false
	var pos = controller.preview_position
	if not controller.tile_manager.is_valid_placement(pos.x, pos.y, controller.current_tile_type):
		return false

	var success = false
	if controller.selected_tile_def:
		var td = controller.selected_tile_def
		success = controller.tile_manager.place_tile(
			pos.x, pos.y,
			td.tile_type,
			td.resource_type,
			td.yield_value,
			td.village_building_cost,
			td.sell_price
		)
	else:
		success = controller.tile_manager.place_tile(pos.x, pos.y, controller.current_tile_type)

	if success:
		if controller.board_manager.turn_manager.is_setup_phase():
			controller.village_manager.place_village(
				pos.x, pos.y,
				controller.board_manager.current_player
			)
			Log.info("Auto-placed village during setup at (%d, %d)" % [pos.x, pos.y])
			controller.board_manager.turn_manager.on_setup_tile_placed(controller.selected_hand_index)
		else:
			if controller.selected_hand_index >= 0 and controller.board_manager:
				controller.board_manager.on_tile_placed_from_hand(controller.selected_hand_index)

		controller.preview_tile.visible = false
		controller.selected_hand_index = -1
		controller.selected_tile_def = null
		return true

	return false
