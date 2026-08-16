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
	var village = board_manager.village_manager.get_village_at(q, r)
	if not tile or not village:
		Log.error("BonusHarvestPower: village at (%d,%d) has no tile" % [q, r])
		return false

	var scaled_yields := _scaled_yields(tile.yields, village.multiplier())
	board_manager.current_player.receive_yields(scaled_yields)
	board_manager.show_resource_gain(q, r, tile.height_level, scaled_yields)
	return true


func update_tooltip(controller: PlacementController, q: int, r: int, is_valid: bool) -> void:
	if not (controller.board_manager and controller.board_manager.ui):
		return
	if is_valid:
		var tile = controller.tile_manager.get_tile_at(q, r)
		var village = controller.board_manager.village_manager.get_village_at(q, r)
		if tile and village:
			var text := TileDefinition.format_yields(_scaled_yields(tile.yields, village.multiplier()))
			controller.board_manager.ui.show_resource_gain_tooltip_text(true, text)
			return
	controller.board_manager.ui.show_resource_gain_tooltip_text(false)


## Multiplies a tile's yields dict by a village's multiplier (2 for a
## doubled village, 1 otherwise) — see rules.md: the minor power harvests a
## "village normal ou doublé".
static func _scaled_yields(tile_yields: Dictionary, multiplier: int) -> Dictionary:
	var scaled: Dictionary = {}
	for res_type in tile_yields:
		scaled[res_type] = tile_yields[res_type] * multiplier
	return scaled
