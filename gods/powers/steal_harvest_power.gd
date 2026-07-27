class_name StealHarvestPower
extends GodPower

## Rakun minor power — harvest an enemy village's tile yield directly.

func _init():
	super("Vol de récolte", "Choisir un bâtiment d'un autre dieu et récolter ses possessions", 2)


func is_valid_target(board_manager: Node3D, q: int, r: int) -> bool:
	var village = board_manager.village_manager.get_village_at(q, r)
	return village != null and village.player_owner != board_manager.current_player


func apply_effect(board_manager: Node3D, q: int, r: int) -> bool:
	var tile = board_manager.tile_manager.get_tile_at(q, r)
	if not tile:
		Log.error("StealHarvestPower: village at (%d,%d) has no tile" % [q, r])
		return false

	var player: Player = board_manager.current_player
	for res_type in tile.yields:
		var amount: int = tile.yields[res_type]
		match res_type:
			TileDefinition.ResourceType.MATERIALS:
				player.materials += amount
				Log.info("Stole %d materials from enemy village" % amount)
			TileDefinition.ResourceType.FERVOR:
				player.fervor += amount
				Log.info("Stole %d fervor from enemy village" % amount)
			TileDefinition.ResourceType.GLORY:
				player.glory += amount
				Log.info("Stole %d glory from enemy village" % amount)
	return true


func update_tooltip(controller: PlacementController, q: int, r: int, is_valid: bool) -> void:
	if not (controller.board_manager and controller.board_manager.ui):
		return
	if is_valid:
		var tile = controller.tile_manager.get_tile_at(q, r)
		if tile:
			var total_yield = 0
			for v in tile.yields.values(): total_yield += v
			controller.board_manager.ui.show_village_sell_tooltip(true, total_yield)
			return
	controller.board_manager.ui.show_village_sell_tooltip(false)
