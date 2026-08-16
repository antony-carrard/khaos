class_name DowngradeTileKeepVillagePower
extends GodPower

## Rakun major power — reduces an enemy village's tile a level (MOUNTAIN→HILLS,
## HILLS→PLAINS), stealing the removed tile into Rakun's hand, and repositions
## the village onto the tile now on top - it survives as a "lower" village.
## The one exception is a village already standing on a bare PLAINS tile with
## nothing below to downgrade into: there the tile is stolen outright and the
## village is demolished instead. Rakun gains 1 glory per reduction (rules.md).
## When that demolition happens, Rakun's passive also triggers a harvest steal
## if he already has a village adjacent to the demolished one (rules.md).

func _init():
	super("Affaissement", "Réduire la Tuile d'un Bâtiment adverse d'un niveau ; si c'est déjà une plaine, le Bâtiment est démoli", 5)


func is_valid_target(board_manager: Node3D, q: int, r: int) -> bool:
	var village = board_manager.village_manager.get_village_at(q, r)
	if village == null or village.player_owner == board_manager.current_player:
		return false
	var tile = board_manager.tile_manager.get_tile_at(q, r)
	return tile != null


func apply_effect(board_manager: Node3D, q: int, r: int) -> bool:
	var tile: HexTile = board_manager.tile_manager.get_tile_at(q, r)
	var was_plains: bool = tile != null and tile.tile_type == TileDefinition.TileType.PLAINS
	var has_nearby_village: bool = board_manager.get_best_adjacent_own_height(q, r) >= 0

	var stolen_tile: TileDefinition = board_manager.tile_manager.downgrade_tile(q, r)
	var success: bool = stolen_tile != null
	if success:
		var new_height = board_manager.tile_manager.get_top_height(q, r)
		var gained: Dictionary = {}
		if was_plains:
			board_manager.village_manager.remove_village(q, r)
			if has_nearby_village:
				StealHarvestPower.steal_yields(board_manager.current_player, stolen_tile.yields)
				gained = stolen_tile.yields.duplicate()
		else:
			var world_pos = HexGridUtils.axial_to_world(q, r, new_height)
			var village = board_manager.village_manager.get_village_at(q, r)
			village.global_position = world_pos + Vector3(0, HexGridUtils.TILE_HEIGHT / 2, 0)

		var actor: Player = board_manager.current_player
		if not actor.has_free_hand_slot():
			actor.grow_hand()
		actor.add_to_hand(stolen_tile)
		actor.glory += 1
		gained[TileDefinition.ResourceType.GLORY] = gained.get(TileDefinition.ResourceType.GLORY, 0) + 1
		board_manager.show_resource_gain(q, r, new_height, gained)
		if board_manager.ui:
			board_manager.ui.update_hand_display()

		if was_plains:
			Log.info("Demolished village at (%d, %d) with DowngradeTileKeepVillagePower, stolen PLAINS tile returned to hand" % [q, r])
		else:
			Log.info("Downgraded tile at (%d, %d) with DowngradeTileKeepVillagePower, stolen tile returned to hand" % [q, r])
	return success
