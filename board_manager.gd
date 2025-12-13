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

# Preview tile
var preview_tile: HexTile = null
var preview_position: Vector3i = Vector3i.ZERO  # (q, r, height)

# Tile type selection
var current_tile_type: TileType = TileType.PLAINS
var placement_active: bool = false  # Toggle placement mode on/off (starts OFF)

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


func _process(_delta: float) -> void:
	update_preview()


func _input(event: InputEvent) -> void:
	# Mouse click to place tile
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if preview_tile.visible and is_valid_placement(preview_position.x, preview_position.y, current_tile_type):
			place_tile(preview_position.x, preview_position.y, current_tile_type)
			# Exit placement mode after placing
			placement_active = false
			preview_tile.visible = false  # Immediate hide (saves 1 frame vs update_preview)

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
	placement_active = true


func update_preview() -> void:
	# Don't show preview if placement mode is off
	if not placement_active:
		preview_tile.visible = false
		return

	var mouse_pos = get_viewport().get_mouse_position()

	if not camera:
		return

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


func is_valid_placement(q: int, r: int, tile_type: TileType) -> bool:
	var height = TILE_TYPE_TO_HEIGHT[tile_type]
	var key = Vector3i(q, r, height)

	# Check if position is already occupied
	if placed_tiles.has(key):
		return false

	# Check if height is within limits
	if height < 0 or height >= max_stack_height:
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
