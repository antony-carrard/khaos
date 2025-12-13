extends Node3D

class_name Village

# Axial coordinates for hexagonal grid position
var q: int = 0  # column
var r: int = 0  # row

# Future expansion ideas:
# var population: int = 100
# var level: int = 1
# var owner: String = ""
# var resources_per_turn: Dictionary = {}


## Sets the village's position on the hex grid.
func set_grid_position(new_q: int, new_r: int) -> void:
	q = new_q
	r = new_r
