class_name DestroyVillageFreePower
extends GodPower

## Le Bâtisseur major power — destroy an enemy village without compensation.

func _init():
	super("Destruction gratuite", "Détruire le Bâtiment d'un adversaire sans remboursement", 6)


func is_valid_target(board_manager: Node3D, q: int, r: int) -> bool:
	var village = board_manager.village_manager.get_village_at(q, r)
	return village != null and village.player_owner != board_manager.current_player


func apply_effect(board_manager: Node3D, q: int, r: int) -> bool:
	var tile = board_manager.tile_manager.get_tile_at(q, r)
	var success: bool = board_manager.village_manager.remove_village(q, r)
	if success:
		var glory: int = board_manager.apply_village_demolition(tile, board_manager.current_player, 0)
		Log.info("Destroyed enemy village at (%d, %d) with DestroyVillageFreePower, gained %d glory" % [q, r, glory])
	return success
