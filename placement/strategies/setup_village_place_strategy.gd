class_name SetupVillagePlaceStrategy extends PlacementStrategy

## Placement strategy for setup Round 3: place a village on one of your own setup tiles.
## Valid positions are tiles the current player placed in setup rounds 1 and 2.


func on_click(controller: PlacementController, q: int, r: int) -> bool:
	var positions = controller.board_manager.current_player.setup_tile_positions
	if not Vector2i(q, r) in positions:
		return false
	if controller.village_manager.has_village_at(q, r):
		return false
	controller.village_manager.place_village(q, r, controller.board_manager.current_player)
	controller.board_manager.turn_manager.on_setup_village_placed()
	return true


func get_validity(controller: PlacementController, q: int, r: int) -> bool:
	var positions = controller.board_manager.current_player.setup_tile_positions
	return (Vector2i(q, r) in positions and
			not controller.village_manager.has_village_at(q, r))
