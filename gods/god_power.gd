class_name GodPower
extends Resource

## Base god-power definition: shared cost data + the one place cost logic lives.
## Concrete behavior lives on InstantGodPower/TargetedGodPower subclasses.

@export var power_name: String = ""
@export var description: String = ""
@export var fervor_cost: int = 0
@export var is_passive: bool = false
@export var consumes_action: bool = true

func _init(p_name: String = "", p_description: String = "", p_cost: int = 0,
		   p_passive: bool = false, p_consumes_action: bool = true):
	power_name = p_name
	description = p_description
	fervor_cost = p_cost
	is_passive = p_passive
	consumes_action = p_consumes_action


## True if the player can currently pay this power's cost.
func can_afford(player: Player) -> bool:
	if fervor_cost > 0 and player.fervor < fervor_cost:
		return false
	if consumes_action and player.actions_remaining <= 0:
		return false
	return true


## Deducts the power's cost from the player. Caller must have already
## checked can_afford() — this does not re-validate.
func pay_cost(player: Player) -> void:
	if fervor_cost > 0:
		player.fervor -= fervor_cost
	if consumes_action:
		player.actions_remaining -= 1
