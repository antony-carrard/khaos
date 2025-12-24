extends StaticBody3D

class_name HexTile

# Axial coordinates for hexagonal grid
var q: int = 0  # column
var r: int = 0  # row
var height_level: int = 0  # 0, 1, or 2 (3 levels total)
var tile_type: int = 0  # Stores TileManager.TileType value

# Resource properties
var resource_type: int = 0  # TileManager.ResourceType (RESOURCES/FERVOR/GLORY)
var yield_value: int = 0    # How much this tile produces when harvested
var buy_price: int = 0      # Cost in resources to place this tile
var sell_price: int = 0     # Value when sold (0 if not sellable)

# Visual feedback
var is_highlighted: bool = false
var original_color: Color = Color(0.8, 0.6, 0.4, 1)
var highlight_color: Color = Color(0.3, 0.8, 0.3, 1)
var invalid_color: Color = Color(0.8, 0.3, 0.3, 1)

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var icon_mesh: MeshInstance3D = null  # Flat quad on top of tile
@onready var value_label: Label3D = null       # Will be created dynamically


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


## Sets the resource properties of this tile and updates the visual display.
## Creates icon mesh and value label if they don't exist.
func set_resource_properties(res_type: int, yield_val: int, buy_val: int, sell_val: int, icon_path: String) -> void:
	resource_type = res_type
	yield_value = yield_val
	buy_price = buy_val
	sell_price = sell_val

	# Create icon mesh if it doesn't exist (flat quad on top of tile)
	if not icon_mesh:
		icon_mesh = MeshInstance3D.new()
		add_child(icon_mesh)

		# Create a flat quad mesh
		var quad = QuadMesh.new()
		quad.size = Vector2(1.5, 1.5)  # Size of the icon quad
		icon_mesh.mesh = quad

		# Position it on top of the hex tile
		icon_mesh.position = Vector3(0, 0.16, 0)  # Just above tile surface

		# Rotate to lay flat (face upward)
		icon_mesh.rotation_degrees = Vector3(-90, 0, 0)

		# Create material for the icon
		var material = StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR  # Hard cutoff, no blend issues
		material.alpha_scissor_threshold = 0.5  # Pixels > 50% alpha are visible
		material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Show both sides
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # No lighting, pure texture
		material.depth_draw_opaque_only = false  # Ensure depth is written
		icon_mesh.material_override = material

	# Load and set the icon texture
	var texture = load(icon_path) as Texture2D
	if texture:
		var material = icon_mesh.material_override as StandardMaterial3D
		if material:
			material.albedo_texture = texture

	# Create value label if it doesn't exist (flat on tile surface)
	if not value_label:
		value_label = Label3D.new()
		add_child(value_label)
		value_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED  # No billboard, lay flat
		value_label.font_size = 200
		value_label.outline_size = 40
		value_label.outline_modulate = Color.BLACK
		value_label.modulate = Color.WHITE
		value_label.position = Vector3(0, 0.20, 0)  # Higher above icon to avoid z-fighting
		value_label.rotation_degrees = Vector3(-90, 0, 0)  # Rotate to lay flat
		value_label.render_priority = 1  # Draw on top of icon

	# Set the yield value text
	value_label.text = str(yield_value)
