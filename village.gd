extends Node3D

class_name Village

# Axial coordinates for hexagonal grid position
var q: int = 0  # column
var r: int = 0  # row

# Owner tracking
var player_owner: Player = null  # Reference to owning player

# Visual reference
@onready var mesh_instance: MeshInstance3D = null

# Future expansion ideas:
# var population: int = 100
# var level: int = 1
# var resources_per_turn: Dictionary = {}


## Sets the village's position on the hex grid.
func set_grid_position(new_q: int, new_r: int) -> void:
	q = new_q
	r = new_r


## Sets the owner of this village and optionally updates visual color.
func set_player_owner(player: Player) -> void:
	player_owner = player
	# Could tint mesh to player color in the future
	# update_player_color()


## Gets the position as Vector2i for easy comparison.
func get_grid_position() -> Vector2i:
	return Vector2i(q, r)
