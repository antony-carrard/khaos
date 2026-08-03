class_name PowerTargetStrategy extends PlacementStrategy

## Targeting strategy for any GodPower — the power itself owns the validity
## rule, the effect and the tooltip, so this just forwards. Powers needing a
## pre-picked hand tile read it from board_manager's activation context; this
## strategy doesn't need to know about it.

var power: GodPower


func _init(p_power: GodPower) -> void:
	power = p_power


func on_click(controller: PlacementController, q: int, r: int) -> bool:
	if power.is_valid_target(controller.board_manager, q, r):
		return controller.board_manager._resolve_power_target(power, q, r)
	# Multi-step powers absorb clicks on their intermediate targets. Returning
	# false keeps this strategy installed so collecting can continue.
	if power.handle_selection_click(controller.board_manager, q, r):
		controller.board_manager.refresh_power_candidates(power)
	return false


func get_validity(controller: PlacementController, q: int, r: int) -> bool:
	return power.is_valid_target(controller.board_manager, q, r) \
		or power.is_selectable(controller.board_manager, q, r)


func update_tooltip(controller: PlacementController, q: int, r: int, is_valid: bool) -> void:
	power.update_tooltip(controller, q, r, is_valid)
