class_name LeDemolisseurGod
extends God

func _init():
	super("Le Démolisseur", "res://assets/gods/démolisseur.jpg",
		"Échafaudage", "La construction d'un village sur l'emplacement d'un village adverse démoli durant le même tour est moitié prix, si le Démolisseur possédait un village à proximité lors de la démolition")

	minor = DestroyAdjacentVillagePower.new()
	major = DestroyVillageFreePower.new()


func modify_rebuild_cost(cost: int, was_demolished_this_turn: bool) -> int:
	return cost / 2 if was_demolished_this_turn else cost
