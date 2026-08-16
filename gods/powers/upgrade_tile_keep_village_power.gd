class_name UpgradeTileKeepVillagePower
extends GodPower

## Augia major power — upgrades an own village's tile a level using a tile
## picked from hand, without destroying the village. Awards 1 glory per
## augmentation (rules.md).

func _init():
	super("Élévation divine", "Augmenter la Tuile d'un de ses Bâtiments d'un niveau grâce à une Tuile de sa main", 4)


func needs_hand_tile() -> bool:
	return true


func extra_afford_check(player: Player) -> bool:
	return player.has_tile_in_hand()


func is_valid_target(board_manager: Node3D, q: int, r: int) -> bool:
	var hand_tile: TileDefinition = board_manager.get_picked_hand_tile()
	if hand_tile == null:
		return false
	var village = board_manager.village_manager.get_village_at(q, r)
	if village == null or village.player_owner != board_manager.current_player:
		return false
	var tile = board_manager.tile_manager.get_tile_at(q, r)
	return tile != null and hand_tile.tile_type == tile.tile_type + 1


func apply_effect(board_manager: Node3D, q: int, r: int) -> bool:
	var hand_tile: TileDefinition = board_manager.get_picked_hand_tile()
	if hand_tile == null:
		return false

	var success: bool = board_manager.tile_manager.upgrade_tile_with(q, r, hand_tile)
	if success:
		var new_height = board_manager.tile_manager.get_top_height(q, r)
		var world_pos = HexGridUtils.axial_to_world(q, r, new_height)
		var village = board_manager.village_manager.get_village_at(q, r)
		village.global_position = world_pos + Vector3(0, HexGridUtils.TILE_HEIGHT / 2, 0)

		board_manager.current_player.remove_from_hand(board_manager.power_hand_index)
		board_manager.current_player.glory += 1
		board_manager.show_resource_gain(q, r, new_height, {TileDefinition.ResourceType.GLORY: 1})
		if board_manager.ui:
			board_manager.ui.update_hand_display()

		Log.info("Upgraded tile at (%d, %d) with UpgradeTileKeepVillagePower using hand tile" % [q, r])
	return success
