class_name RakunGod
extends God

func _init():
	super("Rakun", "res://assets/gods/rakun.jpg",
		"Vol de récolte", "Rakun effectue un vol de récolte sur les villages qu'il démolit")

	# The passive above is display-only for now — the steal-on-demolish hook
	# is content-pass work, as is affaissement returning the tile to hand.
	minor = StealHarvestPower.new()
	major = DowngradeTileKeepVillagePower.new()
