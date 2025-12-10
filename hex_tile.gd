extends StaticBody3D

class_name HexTile

# Axial coordinates for hexagonal grid
var q: int = 0  # column
var r: int = 0  # row
var height_level: int = 0  # 0, 1, or 2 (3 levels total)
var tile_type: int = 0  # Stores BoardManager.TileType value

# Visual feedback
var is_highlighted: bool = false
var original_color: Color = Color(0.8, 0.6, 0.4, 1)
var highlight_color: Color = Color(0.3, 0.8, 0.3, 1)
var invalid_color: Color = Color(0.8, 0.3, 0.3, 1)

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	# Duplicate the material so each tile has its own unique material
	if mesh_instance:
		var material = mesh_instance.get_surface_override_material(0) as StandardMaterial3D
		if material:
			# Create a unique copy of the material for this tile
			var unique_material = material.duplicate()
			mesh_instance.set_surface_override_material(0, unique_material)


func set_grid_position(new_q: int, new_r: int, new_height: int = 0) -> void:
	q = new_q
	r = new_r
	height_level = new_height


func set_tile_type(type: int, type_color: Color) -> void:
	tile_type = type
	original_color = type_color
	update_visual()


func set_highlight(enabled: bool, valid: bool = true) -> void:
	is_highlighted = enabled
	if enabled:
		if valid:
			# Brighten the original color slightly for valid placement
			var highlighted = original_color.lightened(0.3)
			set_color(highlighted)
		else:
			# Mix with red for invalid placement
			var invalid = original_color.lerp(invalid_color, 0.6)
			set_color(invalid)
	else:
		set_color(original_color)


func set_color(color: Color) -> void:
	if mesh_instance and mesh_instance.get_surface_override_material_count() > 0:
		var material = mesh_instance.get_surface_override_material(0) as StandardMaterial3D
		if material:
			material.albedo_color = color


func update_visual() -> void:
	set_color(original_color)
