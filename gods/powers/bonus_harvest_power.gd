class_name BonusHarvestPower
extends GodPower

## Bicéphallès minor power — grants an extra harvest of one of Bicéphallès's
## own villages, on top of the normal per-turn harvest.

func _init():
	super("Récolte bonus", "Récolter une seconde fois le rendement d'un de ses villages", 3)


func is_valid_target(board_manager: Node3D, q: int, r: int) -> bool:
	var village = board_manager.village_manager.get_village_at(q, r)
	return village != null and village.player_owner == board_manager.current_player


func apply_effect(board_manager: Node3D, q: int, r: int) -> bool:
	var tile = board_manager.tile_manager.get_tile_at(q, r)
	if not tile:
		Log.error("BonusHarvestPower: village at (%d,%d) has no tile" % [q, r])
		return false

	board_manager.current_player.receive_yields(tile.yields)
	return true


func update_tooltip(controller: PlacementController, q: int, r: int, is_valid: bool) -> void:
	if not (controller.board_manager and controller.board_manager.ui):
		return
	if is_valid:
		var tile = controller.tile_manager.get_tile_at(q, r)
		if tile:
			var total_yield = 0
			for v in tile.yields.values(): total_yield += v
			controller.board_manager.ui.show_resource_gain_tooltip(true, total_yield)
			return
	controller.board_manager.ui.show_resource_gain_tooltip(false)
