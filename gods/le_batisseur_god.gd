class_name LeBatisseurGod
extends God

const FLAT_VILLAGE_COST: int = 4  # Rules.md passive: all villages cost 4

func _init():
	super("Le Bâtisseur", "res://gods/bâtisseur.jpg")

	powers.append(DestroyVillageFreePower.new())

	# Passive: display-only entry (behavior lives in get_village_cost() below).
	powers.append(GodPower.new(
		"Coût fixe",
		"Les constructions coûtent 4 ressources",
		0,
		true
	))


func get_village_cost(_base_cost: int) -> int:
	return FLAT_VILLAGE_COST
