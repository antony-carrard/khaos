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
			td.yields,
			td.village_building_cost
		)
	else:
		# Debug-only path (1/2/3 keyboard shortcuts, see PlacementController.select_tile_type):
		# no hand TileDefinition exists, so supply the rules.md base village cost directly.
		success = controller.tile_manager.place_tile(
			pos.x, pos.y,
			controller.current_tile_type,
			{},
			TileDefinition.VILLAGE_COST_BY_TYPE[controller.current_tile_type]
		)

	if success:
		if controller.selected_hand_index >= 0 and controller.board_manager:
			controller.board_manager.on_tile_placed_from_hand(controller.selected_hand_index, pos.x, pos.y)

		controller.preview_tile.visible = false
		controller.selected_hand_index = -1
		controller.selected_tile_def = null
		return true

	return false
