extends StaticBody3D

class_name HexTile

# Resource badge geometry constants (icon + number overlaid at the same spot,
# clustered near tile center so they never sprawl out near a village model)
const ICON_HEIGHT_OFFSET: float = 0.16   # Above tile surface
const ICON_ALPHA_SCISSOR_THRESHOLD: float = 0.5
const LABEL_HEIGHT_OFFSET: float = 0.20  # Above icon, avoids z-fighting
const LABEL_OUTLINE_RATIO: float = 0.18  # Outline thickness as a fraction of font_size

# Label3D centers text using the font's full ascent/descent, but digits have no
# descender, so the reserved-but-empty descender space biases the visible glyph
# toward -Z (screen-up, given this project's camera tilt). Nudge back toward +Z
# (screen-down) by a fraction of the label's world-space text height to compensate.
const LABEL_VERTICAL_NUDGE_RATIO: float = 0.04
const LABEL_PIXEL_SIZE: float = 0.01  # Matches Label3D's default pixel_size

# A single resource type is shown bigger; 2-3 types share the cluster at a smaller scale.
const SINGLE_ICON_SIZE: Vector2 = Vector2(1.25, 1.25)
const SINGLE_FONT_SIZE: int = 160
const MULTI_ICON_SIZE: Vector2 = Vector2(0.8, 0.8)
const MULTI_FONT_SIZE: int = 85

const BADGE_SPACING_X: float = 0.32  # Half-distance between left/right badges
const BADGE_SPACING_Z: float = 0.32  # Half-distance between top row and bottom badge

# Badge (x, z) offsets from tile center, indexed by position within the sorted
# resource-type list. 2 types sit side by side; 3 form an upside-down triangle
# (2 up top, 1 centered below), so a tile always reads as a compact cluster.
const BADGE_OFFSETS_BY_COUNT = {
	1: [Vector2(0, 0)],
	2: [Vector2(-BADGE_SPACING_X, 0), Vector2(BADGE_SPACING_X, 0)],
	3: [
		Vector2(-BADGE_SPACING_X, -BADGE_SPACING_Z), Vector2(BADGE_SPACING_X, -BADGE_SPACING_Z),
		Vector2(0, BADGE_SPACING_Z)
	],
}

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
var resource_icons: Dictionary = {}   # ResourceType -> MeshInstance3D (badge icon quad)
var resource_labels: Dictionary = {}  # ResourceType -> Label3D (badge amount)


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


## Sets the resource properties of this tile and updates the visual display: a
## compact cluster of icon+number badges near tile center (1 centered, 2 side by
## side, 3 as an upside-down triangle), so it never sprawls into a village model.
func set_resource_properties(tile_yields: Dictionary, village_cost: int) -> void:
	yields = tile_yields
	village_building_cost = village_cost

	_clear_resource_visuals()

	var res_types = tile_yields.keys()
	res_types.sort()
	var offsets = BADGE_OFFSETS_BY_COUNT.get(res_types.size(), [])
	for i in res_types.size():
		var res_type = res_types[i]
		_create_badge(res_type, tile_yields[res_type], offsets[i], res_types.size() == 1)


func _clear_resource_visuals() -> void:
	for icon in resource_icons.values():
		icon.queue_free()
	for label in resource_labels.values():
		label.queue_free()
	resource_icons.clear()
	resource_labels.clear()


## Creates the icon quad + amount label (overlaid, number in front of icon) for
## one resource type at the given (x, z) offset from tile center.
func _create_badge(res_type: int, amount: int, offset: Vector2, is_single: bool) -> void:
	var icon_size = SINGLE_ICON_SIZE if is_single else MULTI_ICON_SIZE
	var font_size = SINGLE_FONT_SIZE if is_single else MULTI_FONT_SIZE

	var icon = MeshInstance3D.new()
	add_child(icon)
	var quad = QuadMesh.new()
	quad.size = icon_size
	icon.mesh = quad
	icon.position = Vector3(offset.x, ICON_HEIGHT_OFFSET, offset.y)
	icon.rotation_degrees = Vector3(-90, 0, 0)

	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = ICON_ALPHA_SCISSOR_THRESHOLD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS

	var icon_path = TileManager.RESOURCE_TYPE_ICONS[res_type]
	var texture = load(icon_path) as Texture2D
	if not texture:
		Log.error("HexTile: Failed to load icon texture: %s" % icon_path)
	else:
		material.albedo_texture = texture
	icon.material_override = material
	resource_icons[res_type] = icon

	var vertical_nudge = font_size * LABEL_PIXEL_SIZE * LABEL_VERTICAL_NUDGE_RATIO

	var label = Label3D.new()
	add_child(label)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.font_size = font_size
	label.outline_size = int(font_size * LABEL_OUTLINE_RATIO)
	label.outline_modulate = Color.BLACK
	label.modulate = Color.WHITE
	label.position = Vector3(offset.x, LABEL_HEIGHT_OFFSET, offset.y + vertical_nudge)
	label.rotation_degrees = Vector3(-90, 0, 0)
	label.render_priority = 1
	label.text = str(amount)
	resource_labels[res_type] = label
