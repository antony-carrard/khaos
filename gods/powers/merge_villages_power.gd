class_name MergeVillagesPower
extends GodPower

## Le Bâtisseur minor power — fuses several of his own plains villages into a
## single higher one (rules.md: "2 villages plaine -> 1 village colline, 3
## villages plaine -> 1 village montagne").
##
## Two-step targeting: clicks on own plains villages toggle them in and out of
## board_manager's selection, then a click on the vacant hex that receives the
## new village resolves the power. Nothing is created — the receiving hex must
## already be a vacant tile of the level the merge produces, so a 2-merge needs
## a vacant hills tile and a 3-merge a vacant mountain tile. All the merged
## villages must be adjacent to it ("à proximité d'une tuile vacante").
##
## No glory: the merge is a conversion, not a construction, and demolishing
## one's own villages never pays glory either.

## Selection size -> tile type the receiving hex must be.
const MERGE_RESULTS := {
	2: TileDefinition.TileType.HILLS,
	3: TileDefinition.TileType.MOUNTAIN,
}
const MAX_MERGED: int = 3


func _init():
	super("Fusion", "Fusionner 2 villages plaine en un village colline, ou 3 en un village montagne", 2)


func is_selectable(board_manager: Node3D, q: int, r: int) -> bool:
	if not _is_own_plains_village(board_manager, q, r):
		return false
	# Already picked hexes stay clickable so the player can deselect them.
	if board_manager.power_selected_villages.has(Vector2i(q, r)):
		return true
	return board_manager.power_selected_villages.size() < MAX_MERGED


func handle_selection_click(board_manager: Node3D, q: int, r: int) -> bool:
	if not is_selectable(board_manager, q, r):
		return false
	board_manager.toggle_power_selection(q, r)
	return true


func is_valid_target(board_manager: Node3D, q: int, r: int) -> bool:
	var selected: Array[Vector2i] = board_manager.power_selected_villages
	if not MERGE_RESULTS.has(selected.size()):
		return false
	if board_manager.village_manager.has_village_at(q, r):
		return false
	var tile = board_manager.tile_manager.get_tile_at(q, r)
	if tile == null or tile.tile_type != MERGE_RESULTS[selected.size()]:
		return false
	var neighbors := HexGridUtils.get_axial_neighbors(q, r)
	for village_pos in selected:
		if not neighbors.has(village_pos):
			return false
	return true


func apply_effect(board_manager: Node3D, q: int, r: int) -> bool:
	var merged: Array[Vector2i] = board_manager.power_selected_villages.duplicate()
	# Build before demolishing. place_village() is the only fallible step here,
	# and neither of its failure modes (no tile, hex already occupied) depends
	# on the merged villages still standing — so running it first means a
	# failure leaves the board untouched rather than having already eaten them.
	if not board_manager.village_manager.place_village(q, r, board_manager.current_player):
		Log.error("MergeVillagesPower: could not build at (%d, %d), %d villages left standing" % [
			q, r, merged.size()])
		return false

	for village_pos in merged:
		board_manager.village_manager.remove_village(village_pos.x, village_pos.y)

	# The merged village is fresh this turn, same as any other build — the
	# demolition surcharge rules key off this.
	board_manager.villages_built_this_turn[Vector2i(q, r)] = true
	Log.info("Merged %d plains villages into a %s village at (%d, %d)" % [
		merged.size(),
		TileDefinition.TileType.keys()[MERGE_RESULTS[merged.size()]],
		q, r])
	return true


## An own village standing on a bare plains tile — the only legal merge fodder.
func _is_own_plains_village(board_manager: Node3D, q: int, r: int) -> bool:
	var village = board_manager.village_manager.get_village_at(q, r)
	if village == null or village.player_owner != board_manager.current_player:
		return false
	var tile = board_manager.tile_manager.get_tile_at(q, r)
	return tile != null and tile.tile_type == TileDefinition.TileType.PLAINS
