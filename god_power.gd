class_name GodPower
extends Resource

## Data-driven power definition
## Powers are just data - implementation logic is in GodManager

enum PowerType {
	# Active powers
	DESTROY_VILLAGE_FREE,       # Le Bâtisseur - destroy enemy village without paying
	EXTRA_ACTION,               # Bicéphallès - 4 actions next turn
	SECOND_HARVEST,             # Bicéphallès - harvest again this turn
	CHANGE_TILE_TYPE,           # Augia - change resource type of own tiles
	UPGRADE_TILE_KEEP_VILLAGE,  # Augia - upgrade tile without destroying village
	STEAL_HARVEST,              # Rakun - harvest from enemy village
	DOWNGRADE_TILE_KEEP_VILLAGE, # Rakun - downgrade tile without destroying village

	# Passive abilities
	FLAT_VILLAGE_COST           # Le Bâtisseur - all villages cost 4 resources
}

@export var power_name: String = ""
@export var description: String = ""
@export var fervor_cost: int = 0
@export var is_passive: bool = false
@export var power_type: PowerType = PowerType.EXTRA_ACTION

func _init(p_name: String = "", p_description: String = "", p_cost: int = 0,
		   p_type: PowerType = PowerType.EXTRA_ACTION, p_passive: bool = false):
	power_name = p_name
	description = p_description
	fervor_cost = p_cost
	power_type = p_type
	is_passive = p_passive
