class_name RakunGod
extends God

func _init():
	super("Rakun", "res://assets/gods/rakun.jpg")

	powers.append(StealHarvestPower.new())
	powers.append(DowngradeTileKeepVillagePower.new())
