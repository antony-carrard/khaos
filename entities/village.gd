extends Node3D

class_name Village

# Axial coordinates for hexagonal grid position
var q: int = 0  # column
var r: int = 0  # row

# Owner tracking
var player_owner: Player = null  # Reference to owning player

# Bicéphallès major power: doubles this village's harvest yield and its
# contribution to territory group size. No dedicated asset yet — placeholder
# visual is a scaled-up mesh (see set_doubled()).
var is_doubled: bool = false

# Visual reference
@onready var mesh_instance: MeshInstance3D = null

const DOUBLED_SCALE: float = 1.3

# Future expansion ideas:
# var population: int = 100
# var level: int = 1
# var resources_per_turn: Dictionary = {}


## Marks this village as doubled (Bicéphallès major power). Placeholder visual
## until a dedicated doubled-village asset exists: scales the whole node up.
func set_doubled(value: bool) -> void:
	is_doubled = value
	scale = scale_for(value)


## Scale a village node should use for a given doubled state. Shared so
## preview/ghost villages (which aren't Village.is_doubled themselves, just
## standing in for a real one) can match the real village's visual size.
static func scale_for(doubled: bool) -> Vector3:
	return Vector3.ONE * DOUBLED_SCALE if doubled else Vector3.ONE


## How much this village counts as: 2 if doubled, else 1. Single source of
## truth for the doubling effect — multiplied into harvest yield, added into
## territory group size.
func multiplier() -> int:
	return 2 if is_doubled else 1


## Sets the village's position on the hex grid.
func set_grid_position(new_q: int, new_r: int) -> void:
	q = new_q
	r = new_r


## Sets the owner of this village and optionally updates visual color.
func set_player_owner(player: Player) -> void:
	player_owner = player
	# Could tint mesh to player color in the future
	# update_color()


## Gets the position as Vector2i for easy comparison.
func get_grid_position() -> Vector2i:
	return Vector2i(q, r)
