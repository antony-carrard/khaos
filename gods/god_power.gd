class_name GodPower
extends Resource

## A god's minor or major power: cost data, the targeting rule, and the effect.
## Concrete powers extend this and override is_valid_target() / apply_effect().
##
## Powers are immutable definitions. Per-activation state — notably which hand
## tile the player picked — lives in board_manager's activation context, never
## on the power itself.

@export var power_name: String = ""
@export var description: String = ""
@export var fervor_cost: int = 0


func _init(p_name: String = "", p_description: String = "", p_cost: int = 0):
	power_name = p_name
	description = p_description
	fervor_cost = p_cost


## Whether (q, r) is a legal target right now. Drives both the hover-highlight
## colouring and the click-time gate — single source of truth.
func is_valid_target(_board_manager: Node3D, _q: int, _r: int) -> bool:
	return false


## Applies the effect. Assumes is_valid_target() already passed.
func apply_effect(_board_manager: Node3D, _q: int, _r: int) -> bool:
	return false


## True if the player must pick a tile from hand before target selection
## starts. board_manager stores the pick; see its get_picked_hand_tile().
func needs_hand_tile() -> bool:
	return false


## Hover tooltip while targeting. Default: hide. Override to preview something
## (e.g. steal-harvest's yield amount).
func update_tooltip(controller: PlacementController, _q: int, _r: int, _is_valid: bool) -> void:
	if controller.board_manager and controller.board_manager.ui:
		controller.board_manager.ui.show_village_sell_tooltip(false)


## Extra requirement beyond fervor and actions (e.g. needing a tile in hand).
func extra_afford_check(_player: Player) -> bool:
	return true


## True if the player can currently pay this power's cost. Using a power always
## costs one action (rules.md: "L'utilisation d'un pouvoir mineur ou majeur se
## fait au coût d'une action").
func can_afford(player: Player) -> bool:
	if player.fervor < fervor_cost:
		return false
	if player.actions_remaining <= 0:
		return false
	return extra_afford_check(player)


## Deducts the power's cost. Caller must have already checked can_afford() —
## this does not re-validate.
func pay_cost(player: Player) -> void:
	player.fervor -= fervor_cost
	player.actions_remaining -= 1


## Pays the cost and applies the effect. Re-checks the target since this is
## also the click-time gate, not just the hover preview.
func resolve(board_manager: Node3D, q: int, r: int) -> bool:
	if not is_valid_target(board_manager, q, r):
		return false
	pay_cost(board_manager.current_player)
	var success: bool = apply_effect(board_manager, q, r)
	if success:
		Log.info("Activated power: %s" % power_name)
	return success
