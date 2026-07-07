class_name AugiaGod
extends God

func _init():
	super("Augia", "res://gods/augia.jpg")

	powers.append(ChangeTileTypePower.new())
	powers.append(UpgradeTileKeepVillagePower.new())
