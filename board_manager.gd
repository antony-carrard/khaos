extends Node3D

# Hexagonal grid using axial coordinates
# Reference: https://www.redblobgames.com/grids/hexagons/

enum TileType {
	PLAINS,    # Height 0 - ground level
	HILLS,     # Height 1 - built on plains
	MOUNTAIN   # Height 2 - built on hills
}

# Map tile types to their required height level
const TILE_TYPE_TO_HEIGHT = {
	TileType.PLAINS: 0,
	TileType.HILLS: 1,
	TileType.MOUNTAIN: 2
}

# Visual colors for each tile type
const TILE_TYPE_COLORS = {
	TileType.PLAINS: Color(0.4, 0.7, 0.3),    # Green
	TileType.HILLS: Color(0.6, 0.5, 0.3),     # Brown
	TileType.MOUNTAIN: Color(0.5, 0.5, 0.5)   # Gray
}

@export var hex_tile_scene: PackedScene = preload("res://hex_tile.tscn")
@export var hex_size: float = 1.0  # Distance from center to corner
@export var tile_height: float = 0.3  # Height of each tile level
@export var max_stack_height: int = 3  # Maximum tiles that can be stacked

# Grid storage: Dictionary with Vector3i(q, r, height) as key
var placed_tiles: Dictionary = {}

# Village storage: Dictionary with Vector2i(q, r) as key (villages are placed on tiles, not heights)
# Value is the village Node3D instance
var placed_villages: Dictionary = {}

# Preview tile
var preview_tile: HexTile = null
var preview_position: Vector3i = Vector3i.ZERO  # (q, r, height)
var preview_village: Node3D = null

# Tile type selection
var current_tile_type: TileType = TileType.PLAINS
var placement_active: bool = false  # Toggle placement mode on/off (starts OFF)

# Village mode
enum PlacementMode {
	TILE,
	VILLAGE_PLACE,
	VILLAGE_REMOVE
}
var current_mode: PlacementMode = PlacementMode.TILE

# UI
var ui: Control = null

# Debug mode (true in editor, false in exported game)
var debug_mode: bool = OS.is_debug_build()

# Camera raycast
@onready var camera: Camera3D = get_viewport().get_camera_3d()


func _ready() -> void:
	# Place the first tile at origin to start (always PLAINS)
	place_tile(0, 0, TileType.PLAINS)

	# Create preview tile
	preview_tile = hex_tile_scene.instantiate() as HexTile
	preview_tile.original_color = Color(0.5, 0.5, 0.8, 0.6)
	add_child(preview_tile)
	preview_tile.visible = false

	# Create UI in a CanvasLayer so it positions correctly
	var canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)

	var ui_script = load("res://tile_selector_ui.gd")
	ui = ui_script.new()
	canvas_layer.add_child(ui)
	ui.initialize(TILE_TYPE_COLORS)
	ui.tile_type_selected.connect(_on_tile_type_selected)
	ui.village_place_selected.connect(_on_village_place_selected)
	ui.village_remove_selected.connect(_on_village_remove_selected)


func _process(_delta: float) -> void:
	update_preview()


func _input(event: InputEvent) -> void:
	# Mouse click to place tile or village
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if current_mode == PlacementMode.TILE:
			if preview_tile.visible and is_valid_placement(preview_position.x, preview_position.y, current_tile_type):
				place_tile(preview_position.x, preview_position.y, current_tile_type)
				# Exit placement mode after placing
				placement_active = false
				preview_tile.visible = false  # Immediate hide (saves 1 frame vs update_preview)
		elif current_mode == PlacementMode.VILLAGE_PLACE:
			if placement_active:
				var mouse_pos = get_viewport().get_mouse_position()
				var axial = get_axial_at_mouse(mouse_pos)
				if axial != Vector2i(-999, -999):  # Valid position
					if place_village(axial.x, axial.y):
						placement_active = false
		elif current_mode == PlacementMode.VILLAGE_REMOVE:
			if placement_active:
				var mouse_pos = get_viewport().get_mouse_position()
				var axial = get_axial_at_mouse(mouse_pos)
				if axial != Vector2i(-999, -999):  # Valid position
					if remove_village(axial.x, axial.y):
						placement_active = false

	# Keyboard shortcuts (DEBUG ONLY - disabled in exported game)
	if debug_mode and event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			current_tile_type = TileType.PLAINS
			placement_active = true
		elif event.keycode == KEY_2:
			current_tile_type = TileType.HILLS
			placement_active = true
		elif event.keycode == KEY_3:
			current_tile_type = TileType.MOUNTAIN
			placement_active = true

	# ESC to exit placement mode (always available)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			placement_active = false
			preview_tile.visible = false  # Immediate hide (saves 1 frame vs update_preview)


func _on_tile_type_selected(tile_type: int) -> void:
	current_tile_type = tile_type as TileType
	current_mode = PlacementMode.TILE
	placement_active = true


func _on_village_place_selected() -> void:
	current_mode = PlacementMode.VILLAGE_PLACE
	placement_active = true


func _on_village_remove_selected() -> void:
	current_mode = PlacementMode.VILLAGE_REMOVE
	placement_active = true


func update_preview() -> void:
	# Don't show preview if placement mode is off
	if not placement_active:
		preview_tile.visible = false
		if preview_village:
			preview_village.visible = false
		return

	var mouse_pos = get_viewport().get_mouse_position()

	if not camera:
		return

	# Village placement/removal modes
	if current_mode == PlacementMode.VILLAGE_PLACE or current_mode == PlacementMode.VILLAGE_REMOVE:
		preview_tile.visible = false

		# Create preview village if it doesn't exist
		if not preview_village:
			preview_village = create_village_mesh()
			add_child(preview_village)
			# Make it semi-transparent for preview
			for child in preview_village.get_children():
				if child is MeshInstance3D:
					var mat = child.get_surface_override_material(0) as StandardMaterial3D
					if mat:
						var preview_mat = mat.duplicate()
						preview_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						preview_mat.albedo_color.a = 0.6
						child.set_surface_override_material(0, preview_mat)

		var axial = get_axial_at_mouse(mouse_pos)
		if axial != Vector2i(-999, -999):
			var q = axial.x
			var r = axial.y

			# Find the topmost tile at this position
			var has_tile = false
			var top_height = 0
			for height in range(max_stack_height):
				if placed_tiles.has(Vector3i(q, r, height)):
					has_tile = true
					top_height = height

			if has_tile:
				preview_village.visible = true
				var world_pos = axial_to_world(q, r, top_height)
				preview_village.global_position = world_pos + Vector3(0, tile_height / 2, 0)

				# Color the preview based on validity
				var is_valid = false
				if current_mode == PlacementMode.VILLAGE_PLACE:
					is_valid = not placed_villages.has(Vector2i(q, r))
				else:  # VILLAGE_REMOVE
					is_valid = placed_villages.has(Vector2i(q, r))

				# Update preview color based on validity
				for child in preview_village.get_children():
					if child is MeshInstance3D:
						var mat = child.get_surface_override_material(0) as StandardMaterial3D
						if mat:
							if is_valid:
								mat.albedo_color = Color(0.3, 0.8, 0.3, 0.6)  # Green for valid
							else:
								mat.albedo_color = Color(0.8, 0.3, 0.3, 0.6)  # Red for invalid
			else:
				preview_village.visible = false
		else:
			preview_village.visible = false
		return

	# Tile placement mode
	if preview_village:
		preview_village.visible = false

	# Raycast from camera
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	# Hit both tiles (layer 1) and ground plane (layer 2)
	query.collision_mask = 0b11  # Binary: layers 1 and 2
	var result = space_state.intersect_ray(query)

	if result:
		var hit_position = result.position

		# Convert world position to axial coordinates
		var axial = world_to_axial(hit_position)
		var q = axial.x
		var r = axial.y

		# Get height for current tile type
		var height = TILE_TYPE_TO_HEIGHT[current_tile_type]

		# Only show preview if height matches current tile type
		if height < max_stack_height:
			preview_position = Vector3i(q, r, height)
			preview_tile.visible = true
			preview_tile.set_grid_position(q, r, height)
			preview_tile.set_tile_type(current_tile_type, TILE_TYPE_COLORS[current_tile_type])
			preview_tile.global_position = axial_to_world(q, r, height)

			# Check if placement is valid
			var valid = is_valid_placement(q, r, current_tile_type)
			preview_tile.set_highlight(true, valid)
		else:
			preview_tile.visible = false
	else:
		preview_tile.visible = false


func place_tile(q: int, r: int, tile_type: TileType) -> void:
	var height = TILE_TYPE_TO_HEIGHT[tile_type]

	if not is_valid_placement(q, r, tile_type):
		return

	var tile = hex_tile_scene.instantiate() as HexTile
	add_child(tile)
	tile.set_grid_position(q, r, height)
	tile.set_tile_type(tile_type, TILE_TYPE_COLORS[tile_type])
	tile.global_position = axial_to_world(q, r, height)

	var key = Vector3i(q, r, height)
	placed_tiles[key] = tile

	print("Placed %s tile at q=%d, r=%d, height=%d" % [TileType.keys()[tile_type], q, r, height])


func create_village_mesh() -> Node3D:
	# Create a simple placeholder village using basic 3D shapes
	var village = Node3D.new()

	# Main building - a simple box
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.4, 0.3, 0.4)
	mesh_instance.mesh = box_mesh

	# Create material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.3, 0.2)  # Reddish brown for the building
	mesh_instance.set_surface_override_material(0, material)

	# Position it slightly above the tile surface
	mesh_instance.position = Vector3(0, 0.15, 0)
	village.add_child(mesh_instance)

	# Add a simple roof - a cone
	var roof_instance = MeshInstance3D.new()
	var cone_mesh = CylinderMesh.new()
	cone_mesh.top_radius = 0.0
	cone_mesh.bottom_radius = 0.35
	cone_mesh.height = 0.25
	roof_instance.mesh = cone_mesh

	var roof_material = StandardMaterial3D.new()
	roof_material.albedo_color = Color(0.4, 0.3, 0.2)  # Dark brown roof
	roof_instance.set_surface_override_material(0, roof_material)

	roof_instance.position = Vector3(0, 0.425, 0)  # On top of the building
	village.add_child(roof_instance)

	return village


func place_village(q: int, r: int) -> bool:
	var pos_key = Vector2i(q, r)

	# Check if village already exists at this position
	if placed_villages.has(pos_key):
		print("Village already exists at q=%d, r=%d" % [q, r])
		return false

	# Check if there's a tile at this position (any height)
	var has_tile = false
	for height in range(max_stack_height):
		if placed_tiles.has(Vector3i(q, r, height)):
			has_tile = true
			break

	if not has_tile:
		print("No tile exists at q=%d, r=%d" % [q, r])
		return false

	# Find the topmost tile at this position
	var top_height = 0
	for height in range(max_stack_height):
		if placed_tiles.has(Vector3i(q, r, height)):
			top_height = height

	# Create and place the village
	var village = create_village_mesh()
	add_child(village)

	# Position it on top of the highest tile
	var world_pos = axial_to_world(q, r, top_height)
	village.global_position = world_pos + Vector3(0, tile_height / 2, 0)

	placed_villages[pos_key] = village
	print("Placed village at q=%d, r=%d" % [q, r])
	return true


func remove_village(q: int, r: int) -> bool:
	var pos_key = Vector2i(q, r)

	if not placed_villages.has(pos_key):
		print("No village at q=%d, r=%d" % [q, r])
		return false

	# Remove the village node
	var village = placed_villages[pos_key]
	village.queue_free()
	placed_villages.erase(pos_key)

	print("Removed village at q=%d, r=%d" % [q, r])
	return true


func is_valid_placement(q: int, r: int, tile_type: TileType) -> bool:
	var height = TILE_TYPE_TO_HEIGHT[tile_type]
	var key = Vector3i(q, r, height)

	# Check if position is already occupied
	if placed_tiles.has(key):
		return false

	# Check if height is within limits
	if height < 0 or height >= max_stack_height:
		return false

	# Check if there's a village on this tile position (blocks stacking)
	var village_key = Vector2i(q, r)
	if placed_villages.has(village_key) and height > 0:
		# Village exists and we're trying to stack - not allowed
		return false

	# PLAINS (height 0) rules
	if tile_type == TileType.PLAINS:
		# First tile can be placed anywhere
		if placed_tiles.is_empty():
			return true
		# Otherwise must be adjacent to at least one existing PLAINS tile
		var neighbors = get_axial_neighbors(q, r)
		for neighbor in neighbors:
			var neighbor_key = Vector3i(neighbor.x, neighbor.y, 0)
			if placed_tiles.has(neighbor_key):
				return true
		return false

	# HILLS (height 1) rules
	elif tile_type == TileType.HILLS:
		# Must have a PLAINS tile directly below
		var below_key = Vector3i(q, r, 0)
		if not placed_tiles.has(below_key):
			return false
		# Verify it's a PLAINS tile
		var below_tile = placed_tiles[below_key] as HexTile
		return below_tile.tile_type == TileType.PLAINS

	# MOUNTAIN (height 2) rules
	elif tile_type == TileType.MOUNTAIN:
		# Must have a HILLS tile directly below
		var below_key = Vector3i(q, r, 1)
		if not placed_tiles.has(below_key):
			return false
		# Verify it's a HILLS tile
		var below_tile = placed_tiles[below_key] as HexTile
		return below_tile.tile_type == TileType.HILLS

	return false


func get_axial_neighbors(q: int, r: int) -> Array[Vector2i]:
	# Six directions in axial coordinates
	var directions = [
		Vector2i(+1, 0), Vector2i(+1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, +1), Vector2i(0, +1)
	]

	var neighbors: Array[Vector2i] = []
	for dir in directions:
		neighbors.append(Vector2i(q + dir.x, r + dir.y))

	return neighbors


func axial_to_world(q: int, r: int, height: int = 0) -> Vector3:
	# Convert axial coordinates to world position
	# Using flat-top hexagon orientation
	var x = hex_size * (sqrt(3.0) * q + sqrt(3.0) / 2.0 * r)
	var z = hex_size * (3.0 / 2.0 * r)
	var y = height * tile_height

	return Vector3(x, y, z)


func world_to_axial(world_pos: Vector3) -> Vector2i:
	# Convert world position to axial coordinates
	# Using flat-top hexagon orientation
	var q = (sqrt(3.0) / 3.0 * world_pos.x - 1.0 / 3.0 * world_pos.z) / hex_size
	var r = (2.0 / 3.0 * world_pos.z) / hex_size

	# Round to nearest hex using cube coordinates
	return axial_round(q, r)


func axial_round(q: float, r: float) -> Vector2i:
	# Convert to cube coordinates for rounding
	var s = -q - r

	var rq = round(q)
	var rr = round(r)
	var rs = round(s)

	var q_diff = abs(rq - q)
	var r_diff = abs(rr - r)
	var s_diff = abs(rs - s)

	if q_diff > r_diff and q_diff > s_diff:
		rq = -rr - rs
	elif r_diff > s_diff:
		rr = -rq - rs

	return Vector2i(int(rq), int(rr))


func get_axial_at_mouse(mouse_pos: Vector2) -> Vector2i:
	# Helper function to get axial coordinates from mouse position
	if not camera:
		return Vector2i(-999, -999)

	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 0b11  # Layers 1 and 2
	var result = space_state.intersect_ray(query)

	if result:
		var hit_position = result.position
		return world_to_axial(hit_position)

	return Vector2i(-999, -999)
