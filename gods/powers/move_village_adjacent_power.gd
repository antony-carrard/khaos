class_name MoveVillageAdjacentPower
extends MoveVillagePower

## Le Nomade minor power — moves one of his own villages onto an adjacent
## tile, climbing at most 1 level (rules.md: "pouvant s'élever d'au maximum 1
## niveau"). Descending or staying level is unrestricted.

func _init():
	super("Nomadisme", "Déplacer un village sur une tuile adjacente, pouvant s'élever d'au maximum 1 niveau", 3)


func _is_destination_reachable(board_manager: Node3D, from: Vector2i, to_q: int, to_r: int) -> bool:
	if not HexGridUtils.get_axial_neighbors(from.x, from.y).has(Vector2i(to_q, to_r)):
		return false
	var from_tile: HexTile = board_manager.tile_manager.get_tile_at(from.x, from.y)
	var to_tile: HexTile = board_manager.tile_manager.get_tile_at(to_q, to_r)
	if from_tile == null or to_tile == null:
		return false
	return to_tile.height_level - from_tile.height_level <= 1
