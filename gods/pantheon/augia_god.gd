class_name AugiaGod
extends God

func _init():
	super("Augia", "res://assets/gods/augia.jpg",
		"Tuile bonus", "Reçois une tuile bonus à chaque tour (4 tuiles au lieu de 3)")

	hand_size = 4

	minor = ChangeTileTypePower.new()
	major = UpgradeTileKeepVillagePower.new()
