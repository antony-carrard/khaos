class_name PowerTargetStrategy extends PlacementStrategy

## Generic targeting strategy for any TargetedGodPower — replaces the 5
## near-identical per-power strategy files. The power instance itself is the
## "pending power" state; there's nothing else for a separate object to own.

var power: TargetedGodPower


func _init(p_power: TargetedGodPower) -> void:
	power = p_power


func on_click(controller: PlacementController, q: int, r: int) -> bool:
	if not power.is_valid_target(controller.board_manager, q, r):
		return false
	return power.on_target_selected(controller.board_manager, q, r)


func get_validity(controller: PlacementController, q: int, r: int) -> bool:
	return power.is_valid_target(controller.board_manager, q, r)


func update_tooltip(controller: PlacementController, q: int, r: int, is_valid: bool) -> void:
	power.update_tooltip(controller, q, r, is_valid)
