class_name LeBatisseurGod
extends God

## NOTE: the passive below is the current behaviour (flat 4 for every village),
## which does not yet match rules.md — that says a village on a *plains* tile
## costs 1 material instead of 2. Left as-is for the content pass; the hook
## already receives the tile it needs for the fix.
const FLAT_VILLAGE_COST: int = 4

func _init():
	super("Le Bâtisseur", "res://assets/gods/bâtisseur.jpg",
		"Coût fixe", "Les constructions coûtent 4 ressources")

	# rules.md gives Le Bâtisseur a "fusion de villages" minor and a
	# "construction divine" major; this destroy power is the existing content,
	# slotted as major on cost. Both are due for the content pass.
	major = DestroyVillageFreePower.new()


func modify_village_cost(_base_cost: int, _tile: HexTile) -> int:
	return FLAT_VILLAGE_COST
