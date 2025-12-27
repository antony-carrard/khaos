extends Node3D

class_name VillageManager

# Signals
signal village_placed(q: int, r: int)
signal village_removed(q: int, r: int)

# Configuration
@export var village_scene: PackedScene = preload("res://village.tscn")
var tile_height: float = 0.3

# Village storage: Dictionary with Vector2i(q, r) as key
var placed_villages: Dictionary = {}

# Reference to tile manager (for validation)
var tile_manager = null


## Initializes the VillageManager with required configuration.
## Call this once after instantiation before using other methods.
func initialize(_tile_height: float) -> void:
	tile_height = _tile_height


## Places a village at the specified hex coordinates.
## Village will be positioned on top of the highest tile at that location.
## Returns true if placement succeeded, false if invalid (no tile, village exists).
## Emits village_placed signal on success.
func place_village(q: int, r: int, owner: Player) -> bool:
	var pos_key = Vector2i(q, r)

	# Check if village already exists at this position
	if placed_villages.has(pos_key):
		print("Village already exists at q=%d, r=%d" % [q, r])
		return false

	# Check if there's a tile at this position using tile_manager
	if not tile_manager or not tile_manager.has_tile_at(q, r):
		print("No tile exists at q=%d, r=%d" % [q, r])
		return false

	# Find the topmost tile at this position
	var top_height = tile_manager.get_top_height(q, r)

	# Create and place the village
	var village = village_scene.instantiate() as Village
	village.set_grid_position(q, r)
	village.set_player_owner(owner)  # Set the owning player
	add_child(village)

	# Position it on top of the highest tile
	var world_pos = get_parent().axial_to_world(q, r, top_height)
	village.global_position = world_pos + Vector3(0, tile_height / 2, 0)

	placed_villages[pos_key] = village
	print("Placed village at q=%d, r=%d (Owner: %s)" % [q, r, owner.player_name])
	village_placed.emit(q, r)
	return true


## Removes a village from the specified hex coordinates.
## Returns true if removal succeeded, false if no village exists at that position.
## Emits village_removed signal on success.
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
	village_removed.emit(q, r)
	return true


## Checks if a village exists at the given hex position.
## Returns true if a village is present, false otherwise.
func has_village_at(q: int, r: int) -> bool:
	return placed_villages.has(Vector2i(q, r))


## Gets all villages owned by a specific player.
## Returns an array of Village objects.
func get_villages_for_player(player: Player) -> Array[Village]:
	var player_villages: Array[Village] = []
	for village in placed_villages.values():
		if village.player_owner == player:
			player_villages.append(village)
	return player_villages


## Gets the village at a specific position, or null if none exists.
func get_village_at(q: int, r: int) -> Village:
	var pos_key = Vector2i(q, r)
	return placed_villages.get(pos_key, null)


## Creates a semi-transparent preview village for placement mode.
func create_preview_village() -> Node3D:
	var preview = village_scene.instantiate() as Village

	# Make it semi-transparent for preview
	# Recursively find all MeshInstance3D nodes and set transparency
	_make_transparent_recursive(preview, 0.6)

	return preview


## Updates the preview village color based on placement validity.
func update_preview_color(preview: Node3D, is_valid: bool) -> void:
	var color = Color(0.3, 0.8, 0.3, 0.6) if is_valid else Color(0.8, 0.3, 0.3, 0.6)
	_set_color_recursive(preview, color)


# Helper function to recursively make all meshes transparent
func _make_transparent_recursive(node: Node, alpha: float) -> void:
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		# Get or create material for each surface
		for i in range(mesh_instance.get_surface_override_material_count()):
			var mat = mesh_instance.get_surface_override_material(i)
			if mat and mat is StandardMaterial3D:
				var preview_mat = mat.duplicate() as StandardMaterial3D
				preview_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				preview_mat.albedo_color.a = alpha
				mesh_instance.set_surface_override_material(i, preview_mat)
			elif mat == null and mesh_instance.mesh:
				# No override material, get from mesh
				var mesh_mat = mesh_instance.mesh.surface_get_material(i)
				if mesh_mat and mesh_mat is StandardMaterial3D:
					var preview_mat = mesh_mat.duplicate() as StandardMaterial3D
					preview_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					preview_mat.albedo_color.a = alpha
					mesh_instance.set_surface_override_material(i, preview_mat)

	# Recurse to children
	for child in node.get_children():
		_make_transparent_recursive(child, alpha)


# Helper function to recursively set color on all meshes
func _set_color_recursive(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		for i in range(mesh_instance.get_surface_override_material_count()):
			var mat = mesh_instance.get_surface_override_material(i) as StandardMaterial3D
			if mat:
				mat.albedo_color = color

	# Recurse to children
	for child in node.get_children():
		_set_color_recursive(child, color)
