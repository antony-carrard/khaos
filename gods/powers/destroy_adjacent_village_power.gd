class_name DestroyAdjacentVillagePower
extends GodPower

## Le Démolisseur minor power — destroy an enemy village adjacent to one of
## his own, without resource refund and without glory (rules.md: "Il ne
## récolte pas de gloire pour la démolition").

func _init():
	super("Démolition rapprochée", "Détruire le village d'un adversaire à proximité, sans récolter de gloire", 3)


func is_valid_target(board_manager: Node3D, q: int, r: int) -> bool:
	var village = board_manager.village_manager.get_village_at(q, r)
	if village == null or village.player_owner == board_manager.current_player:
		return false
	return board_manager.get_best_adjacent_own_height(q, r) >= 0


func apply_effect(board_manager: Node3D, q: int, r: int) -> bool:
	var tile = board_manager.tile_manager.get_tile_at(q, r)
	var success: bool = board_manager.village_manager.remove_village(q, r)
	if success:
		board_manager.record_village_demolition(q, r, tile)
		Log.info("Destroyed adjacent enemy village at (%d, %d) with DestroyAdjacentVillagePower" % [q, r])
	return success
