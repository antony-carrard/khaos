extends StaticBody3D

class_name HexTile

# Icon geometry constants
const ICON_QUAD_SIZE: Vector2 = Vector2(1.5, 1.5)
const ICON_HEIGHT_OFFSET: float = 0.16   # Above tile surface
const ICON_ALPHA_SCISSOR_THRESHOLD: float = 0.5
const LABEL_HEIGHT_OFFSET: float = 0.20  # Above icon, avoids z-fighting
const LABEL_FONT_SIZE: int = 200
const LABEL_OUTLINE_SIZE: int = 40

# Axial coordinates for hexagonal grid
var q: int = 0  # column
var r: int = 0  # row
var height_level: int = 0  # 0, 1, or 2 (3 levels total)
var tile_type: int = 0  # TileDefinition.TileType value

# Resource properties
var yields: Dictionary = {}  # TileDefinition.ResourceType → amount
var village_building_cost: int = 0

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


## Returns the resource type with the highest yield amount.
func primary_resource_type() -> int:
	var best_type = TileDefinition.ResourceType.MATERIALS
	var best_val = 0
	for res in yields:
		if yields[res] > best_val:
			best_val = yields[res]
			best_type = res
	return best_type


## Sets the resource properties of this tile and updates the visual display.
## Creates icon mesh and value label if they don't exist.
func set_resource_properties(tile_yields: Dictionary, village_cost: int) -> void:
	yields = tile_yields
	village_building_cost = village_cost

	var icon_path = TileManager.RESOURCE_TYPE_ICONS[primary_resource_type()]

	# Create icon mesh if it doesn't exist (flat quad on top of tile)
	if not icon_mesh:
		icon_mesh = MeshInstance3D.new()
		add_child(icon_mesh)

		var quad = QuadMesh.new()
		quad.size = ICON_QUAD_SIZE
		icon_mesh.mesh = quad
		icon_mesh.position = Vector3(0, ICON_HEIGHT_OFFSET, 0)
		icon_mesh.rotation_degrees = Vector3(-90, 0, 0)

		var material = StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = ICON_ALPHA_SCISSOR_THRESHOLD
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		icon_mesh.material_override = material

	var texture = load(icon_path) as Texture2D
	if not texture:
		Log.error("HexTile: Failed to load icon texture: %s" % icon_path)
	else:
		var material = icon_mesh.material_override as StandardMaterial3D
		if material:
			material.albedo_texture = texture

	# Create value label if it doesn't exist (flat on tile surface)
	if not value_label:
		value_label = Label3D.new()
		add_child(value_label)
		value_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		value_label.font_size = LABEL_FONT_SIZE
		value_label.outline_size = LABEL_OUTLINE_SIZE
		value_label.outline_modulate = Color.BLACK
		value_label.modulate = Color.WHITE
		value_label.position = Vector3(0, LABEL_HEIGHT_OFFSET, 0)
		value_label.rotation_degrees = Vector3(-90, 0, 0)
		value_label.render_priority = 1

	value_label.text = TileDefinition.format_yields(tile_yields)
