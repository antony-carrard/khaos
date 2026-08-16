class_name MoveVillagePower
extends GodPower

## Shared base for Le Nomade's minor and major powers — both move one of his
## own villages to a vacant tile elsewhere on the board. Only the destination
## reach differs: the minor is limited to an adjacent tile climbing at most 1
## level, the major reaches anywhere (see MoveVillageAdjacentPower/
## MoveVillageAnywherePower). Subclasses override _is_destination_reachable().
##
## Two-step targeting, mirroring MergeVillagesPower: a click on the village to
## move is a selection step (capped at one pick), a click on the destination
## resolves it.
##
## Passive (rules.md): moving a village immediately harvests the destination
## tile's yield, and climbing height grants 1 glory per level climbed. Both
## powers are the only way a village ever moves, so the passive is applied
## right here rather than through a God hook.


func is_selectable(board_manager: Node3D, q: int, r: int) -> bool:
	if not _is_own_village(board_manager, q, r):
		return false
	if board_manager.power_selected_villages.has(Vector2i(q, r)):
		return true
	return board_manager.power_selected_villages.is_empty()


func handle_selection_click(board_manager: Node3D, q: int, r: int) -> bool:
	if not is_selectable(board_manager, q, r):
		return false
	board_manager.toggle_power_selection(q, r)
	return true


func is_valid_target(board_manager: Node3D, q: int, r: int) -> bool:
	var from_pos: Variant = _selected_village(board_manager)
	if from_pos == null:
		return false
	if Vector2i(q, r) == from_pos:
		return false
	if board_manager.village_manager.has_village_at(q, r):
		return false
	if not board_manager.tile_manager.has_tile_at(q, r):
		return false
	return _is_destination_reachable(board_manager, from_pos, q, r)


## Assumes is_valid_target() already passed (see GodPower docstring), so it
## trusts the selection/tiles it confirmed rather than re-checking them —
## the only outcome actually worth checking here is move_village()'s result.
func apply_effect(board_manager: Node3D, q: int, r: int) -> bool:
	var from_pos: Vector2i = board_manager.power_selected_villages[0]
	var from_tile: HexTile = board_manager.tile_manager.get_tile_at(from_pos.x, from_pos.y)
	var to_tile: HexTile = board_manager.tile_manager.get_tile_at(q, r)

	if not board_manager.village_manager.move_village(from_pos.x, from_pos.y, q, r):
		Log.error("MoveVillagePower: could not move village from (%d, %d) to (%d, %d)" % [
			from_pos.x, from_pos.y, q, r])
		return false

	board_manager.current_player.receive_yields(to_tile.yields)
	var gained: Dictionary = to_tile.yields.duplicate()
	var climbed: int = to_tile.height_level - from_tile.height_level
	if climbed > 0:
		board_manager.current_player.glory += climbed
		gained[TileDefinition.ResourceType.GLORY] = gained.get(TileDefinition.ResourceType.GLORY, 0) + climbed
	board_manager.show_resource_gain(q, r, to_tile.height_level, gained)

	Log.info("Moved village from (%d, %d) to (%d, %d) with %s, climbed %d level(s)" % [
		from_pos.x, from_pos.y, q, r, power_name, max(climbed, 0)])
	return true


func update_tooltip(controller: PlacementController, q: int, r: int, is_valid: bool) -> void:
	if not (controller.board_manager and controller.board_manager.ui):
		return
	if is_valid:
		var from_pos: Variant = _selected_village(controller.board_manager)
		var to_tile: HexTile = controller.tile_manager.get_tile_at(q, r)
		if from_pos != null and to_tile:
			var from_tile: HexTile = controller.tile_manager.get_tile_at(from_pos.x, from_pos.y)
			var preview: Dictionary = to_tile.yields.duplicate()
			var climbed: int = to_tile.height_level - from_tile.height_level if from_tile else 0
			if climbed > 0:
				preview[TileDefinition.ResourceType.GLORY] = preview.get(TileDefinition.ResourceType.GLORY, 0) + climbed
			controller.board_manager.ui.show_resource_gain_tooltip_text(true, TileDefinition.format_yields(preview))
			return
	controller.board_manager.ui.show_resource_gain_tooltip(false)


## Subclass hook: whether `to_q, to_r` is a legal destination for `from`, given
## this power's reach. Vacancy/tile-existence are already checked by the caller.
func _is_destination_reachable(_board_manager: Node3D, _from: Vector2i, _to_q: int, _to_r: int) -> bool:
	return true


func _is_own_village(board_manager: Node3D, q: int, r: int) -> bool:
	var village = board_manager.village_manager.get_village_at(q, r)
	return village != null and village.player_owner == board_manager.current_player


## The single village picked so far, or null if none has been picked yet.
## Used only where "nothing selected" is a real state to handle — is_valid_target()
## and update_tooltip() are both probed before/without a pick, e.g. for hover
## highlighting during step one. apply_effect() runs after resolve() already
## confirmed exactly one pick via is_valid_target(), so it doesn't need this.
func _selected_village(board_manager: Node3D) -> Variant:
	var selected: Array[Vector2i] = board_manager.power_selected_villages
	if selected.size() != 1:
		return null
	return selected[0]
