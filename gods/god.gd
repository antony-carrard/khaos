class_name God
extends Resource

## Data-driven god definition
## Each god has a name, portrait, and a list of powers (usually 2-3)

@export var god_name: String = ""
@export var image_path: String = ""
@export var powers: Array[GodPower] = []
@export var hand_size: int = 3
@export var total_actions: int = 3

func _init(p_name: String = "", p_image_path: String = ""):
	god_name = p_name
	image_path = p_image_path
	powers = []


## Catalog of every god type, for the selection screen only. Rebuilt fresh
## each time it's needed (picker render, network index lookup) — the
## instance a player picks becomes their own, never shared with this catalog.
static func create_all() -> Array[God]:
	var all: Array[God] = [
		LeBatisseurGod.new(),
		BicephallesGod.new(),
		AugiaGod.new(),
		RakunGod.new(),
	]
	return all


## Building cost for this god's players, accounting for passive abilities.
## Overridden by gods with a flat/modified cost (e.g. Le Bâtisseur).
func get_village_cost(base_cost: int) -> int:
	return base_cost


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
