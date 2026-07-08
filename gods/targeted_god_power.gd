class_name TargetedGodPower
extends GodPower

## A power that requires clicking a target (tile/village) before it resolves.
## Cost is paid only once a valid target is clicked — not on activation.

const NO_EXTRA: int = -1

## Whether (q, r) is a legal target right now. Used for both hover-highlight
## coloring and the final click validation — single source of truth.
func is_valid_target(_board_manager: Node3D, _q: int, _r: int) -> bool:
	return false


## Effect implementation. Override in concrete powers. Returns true on success.
func resolve_effect(_board_manager: Node3D, _q: int, _r: int, _extra: int) -> bool:
	return false


## Hover tooltip while targeting. Default: hide. Override for powers that
## preview something (e.g. steal-harvest's yield amount).
func update_tooltip(controller: PlacementController, _q: int, _r: int, _is_valid: bool) -> void:
	if controller.board_manager and controller.board_manager.ui:
		controller.board_manager.ui.show_village_sell_tooltip(false)


## Called when a target has been clicked and validated. Default: resolve
## immediately via board_manager. Override for powers needing an extra step
## (e.g. change-tile-type's resource-type picker).
func on_target_selected(board_manager: Node3D, q: int, r: int) -> bool:
	return board_manager._resolve_power_target(self, q, r, NO_EXTRA)


## Pays cost and applies the effect. Assumes is_valid_target() already passed.
func resolve(board_manager: Node3D, q: int, r: int, extra: int) -> bool:
	if not is_valid_target(board_manager, q, r):
		return false
	pay_cost(board_manager.current_player)
	var success := resolve_effect(board_manager, q, r, extra)
	if success:
		Log.info("Activated power: %s" % power_name)
	return success
