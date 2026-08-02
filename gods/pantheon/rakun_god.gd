class_name RakunGod
extends God

func _init():
	super("Rakun", "res://assets/gods/rakun.jpg",
		"Vol de récolte", "Rakun effectue un vol de récolte sur les villages qu'il démolit")

	minor = StealHarvestPower.new()
	major = DowngradeTileKeepVillagePower.new()


func on_village_demolished(board_manager: Node3D, tile: HexTile) -> void:
	StealHarvestPower.steal_yields(board_manager.current_player, tile.yields)
