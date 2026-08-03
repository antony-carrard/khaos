class_name LeBatisseurGod
extends God

## rules.md: village construction on a plains tile costs 1 material instead
## of 2. Hills and mountain keep the standard cost (4 and 6).
const PLAINS_VILLAGE_COST: int = 1

func _init():
	super("Le Bâtisseur", "res://assets/gods/bâtisseur.jpg",
		"Coût réduit", "Les constructions sur une plaine coûtent 1 ressource")

	# rules.md gives Le Bâtisseur a "fusion de villages" minor and a
	# "construction divine" major; this destroy power is the existing content,
	# slotted as major on cost. Both are due for the content pass.
	major = DestroyVillageFreePower.new()


func modify_village_cost(base_cost: int, tile: HexTile) -> int:
	if tile.tile_type == TileDefinition.TileType.PLAINS:
		return PLAINS_VILLAGE_COST
	return base_cost
