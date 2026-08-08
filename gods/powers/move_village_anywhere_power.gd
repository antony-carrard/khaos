class_name MoveVillageAnywherePower
extends MoveVillagePower

## Le Nomade major power — moves one of his own villages onto any vacant
## tile on the board, no adjacency or height restriction (rules.md: "peut
## déplacer un de ses villages sur n'importe quelle tuile").

func _init():
	super("Grand voyage", "Déplacer un village sur n'importe quelle tuile", 5)
