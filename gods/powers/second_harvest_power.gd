class_name SecondHarvestPower
extends InstantGodPower

## Bicéphallès major power — harvest again this turn. Costs fervor only,
## does not consume an action.

func _init():
	super("Double récolte", "Faire une 2e récolte au tour en cours", 5, false, false)


func apply(board_manager: Node3D) -> void:
	board_manager.harvest_for_player(board_manager.current_player)
	Log.info("Second harvest triggered!")
