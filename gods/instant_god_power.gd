class_name InstantGodPower
extends GodPower

## A power with no target selection — pays its cost and applies its effect
## immediately when activated.

## Effect implementation. Override in concrete powers.
func apply(_board_manager: Node3D) -> void:
	pass


## Checks affordability, pays cost, applies the effect. Returns false (and
## logs a warning) if the player can't afford it — no state is changed.
func activate(board_manager: Node3D) -> bool:
	var player: Player = board_manager.current_player
	if not can_afford(player):
		Log.warn("Cannot afford power: %s" % power_name)
		return false
	pay_cost(player)
	apply(board_manager)
	Log.info("Activated power: %s" % power_name)
	return true
