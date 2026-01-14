class_name God
extends Resource

## Data-driven god definition
## Each god has a name, portrait, and a list of powers (usually 2-3)

@export var god_name: String = ""
@export var image_path: String = ""
@export var powers: Array[GodPower] = []

func _init(p_name: String = "", p_image_path: String = ""):
	god_name = p_name
	image_path = p_image_path
	powers = []

## Get all active powers (can be activated with fervor)
func get_active_powers() -> Array[GodPower]:
	var active: Array[GodPower] = []
	for power in powers:
		if not power.is_passive:
			active.append(power)
	return active

## Get all passive powers (always active)
func get_passive_powers() -> Array[GodPower]:
	var passive: Array[GodPower] = []
	for power in powers:
		if power.is_passive:
			passive.append(power)
	return passive

## Check if god has a specific power type
func has_power_type(power_type: GodPower.PowerType) -> bool:
	for power in powers:
		if power.power_type == power_type:
			return true
	return false
