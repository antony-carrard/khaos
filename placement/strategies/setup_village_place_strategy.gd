class_name SetupVillagePlaceStrategy extends PlacementStrategy

## Placement strategy for setup Round 3: place a free village on any tile.
## No cost, no actions required — valid on any tile that doesn't already have a village.


func on_click(controller: PlacementController, q: int, r: int) -> bool:
	if not controller.tile_manager.has_tile_at(q, r):
		return false
	if controller.village_manager.has_village_at(q, r):
		return false
	controller.village_manager.place_village(q, r, controller.board_manager.current_player)
	# Route through board_manager so it can broadcast the RPC in network mode
	controller.board_manager.on_setup_village_placed(q, r)
	return true


func get_validity(controller: PlacementController, q: int, r: int) -> bool:
	return (controller.tile_manager.has_tile_at(q, r) and
			not controller.village_manager.has_village_at(q, r))
