class_name LeNomadeGod
extends God

func _init():
	super("Le Nomade", "res://assets/gods/nomade.jpg",
		"Transhumance", "Récolte immédiatement la ressource de la tuile sur laquelle il déplace un village ; chaque niveau gravi lors d'un déplacement rapporte un point de gloire")

	minor = MoveVillageAdjacentPower.new()
	major = MoveVillageAnywherePower.new()
