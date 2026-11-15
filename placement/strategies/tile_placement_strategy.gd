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
		# board_manager owns the placement itself (tile, action, yields, hand slot).
		success = controller.board_manager.on_tile_placed_from_hand(
			controller.selected_hand_index, pos.x, pos.y)
	else:
		# Debug-only path (F1–F3 keyboard shortcuts, see PlacementController.select_tile_type).
		success = controller.board_manager.debug_place_tile(
			controller.current_tile_type, pos.x, pos.y)

	if success:
		controller.preview_tile.visible = false
		controller.selected_hand_index = -1
		controller.selected_tile_def = null
		return true

	return false
