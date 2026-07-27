class_name ChangeTileTypePower
extends GodPower

## Augia minor power — swaps the tile under an own village for a tile from
## hand (same level required, per rules.md). The tile that was on the board
## returns to the same hand slot the picked tile came from.

func _init():
	super("Transformation", "Échanger la Tuile d'un de ses Bâtiments contre une Tuile de sa main (même niveau)", 2)


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
	return tile != null and tile.tile_type == hand_tile.tile_type


func apply_effect(board_manager: Node3D, q: int, r: int) -> bool:
	var hand_tile: TileDefinition = board_manager.get_picked_hand_tile()
	if hand_tile == null:
		return false
	var tile = board_manager.tile_manager.get_tile_at(q, r)
	var returned_tile := TileDefinition.new(tile.tile_type, tile.yields.duplicate(), tile.village_building_cost)
	tile.set_resource_properties(hand_tile.yields, hand_tile.village_building_cost)
	board_manager.current_player.replace_hand_tile(board_manager.power_hand_index, returned_tile)
	if board_manager.ui:
		board_manager.ui.update_hand_display()

	Log.info("Swapped tile at (%d, %d): gave %s from hand, returned %s to hand" % [
		q, r,
		TileDefinition.format_yields(hand_tile.yields),
		TileDefinition.format_yields(returned_tile.yields)
	])
	return true
