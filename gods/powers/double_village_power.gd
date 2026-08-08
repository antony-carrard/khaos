class_name DoubleVillagePower
extends GodPower

## Bicéphallès major power — doubles one of Bicéphallès's own villages, both
## for harvest yield and for territory group-size counting. Grants the same
## glory bounty as building a new village. No dedicated asset yet; the
## doubled state is shown with a placeholder scaled-up mesh (see
## Village.set_doubled()). Demolition cost/glory are unaffected by rules.md,
## so no changes were needed there.

func _init():
	super("Duplication", "Double un de ses villages, tant pour la récolte que pour le décompte de groupe", 6)


func is_valid_target(board_manager: Node3D, q: int, r: int) -> bool:
	var village = board_manager.village_manager.get_village_at(q, r)
	return village != null and village.player_owner == board_manager.current_player and not village.is_doubled


func apply_effect(board_manager: Node3D, q: int, r: int) -> bool:
	var tile: HexTile = board_manager.tile_manager.get_tile_at(q, r)
	var village = board_manager.village_manager.get_village_at(q, r)
	if not tile or not village:
		Log.error("DoubleVillagePower: missing village or tile at (%d,%d)" % [q, r])
		return false

	village.set_doubled(true)
	var glory: int = board_manager.apply_village_construction(tile, board_manager.current_player, 0)
	Log.info("Doubled village at (%d, %d), gained %d glory" % [q, r, glory])
	return true
