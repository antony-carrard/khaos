extends Node3D

class_name VillageManager

# Signals
signal village_placed(q: int, r: int)
signal village_removed(q: int, r: int)

# Configuration
@export var village_scene: PackedScene = preload("res://village.tscn")

# Village storage: Dictionary with Vector2i(q, r) as key
var placed_villages: Dictionary[Vector2i, Village] = {}
# Per-player index: Player -> Array[Village]
var player_villages: Dictionary[Player,  Array] = {}

# Reference to tile manager (for validation)
var tile_manager: TileManager = null


## Places a village at the specified hex coordinates.
## Village will be positioned on top of the highest tile at that location.
## Returns true if placement succeeded, false if invalid (no tile, village exists).
## Emits village_placed signal on success.
func place_village(q: int, r: int, village_owner: Player) -> bool:
	var pos_key = Vector2i(q, r)

	# Check if village already exists at this position
	if placed_villages.has(pos_key):
		Log.warn("Village already exists at q=%d, r=%d" % [q, r])
		return false

	# Check if there's a tile at this position using tile_manager
	if not tile_manager or not tile_manager.has_tile_at(q, r):
		Log.warn("No tile exists at q=%d, r=%d" % [q, r])
		return false

	# Find the topmost tile at this position
	var top_height = tile_manager.get_top_height(q, r)

	# Create and place the village
	var village = village_scene.instantiate() as Village
	village.set_grid_position(q, r)
	village.set_player_owner(village_owner)
	add_child(village)

	# Apply player color so villages are visually distinct per player
	if village_owner and village_owner.color != Color.WHITE:
		_apply_color(village, village_owner.color)

	# Position it on top of the highest tile
	var world_pos = HexGridUtils.axial_to_world(q, r, top_height)
	village.global_position = world_pos + Vector3(0, HexGridUtils.TILE_HEIGHT / 2, 0)

	placed_villages[pos_key] = village
	if not player_villages.has(village_owner):
		player_villages[village_owner] = [] as Array[Village]
	player_villages[village_owner].append(village)
	Log.info("Placed village at q=%d, r=%d (Owner: %s)" % [q, r, village_owner.player_name])
	village_placed.emit(q, r)
	return true


## Removes a village from the specified hex coordinates.
## Returns true if removal succeeded, false if no village exists at that position.
## Emits village_removed signal on success.
func remove_village(q: int, r: int) -> bool:
	var pos_key = Vector2i(q, r)

	if not placed_villages.has(pos_key):
		Log.warn("No village at q=%d, r=%d" % [q, r])
		return false

	# Remove the village node
	var village = placed_villages[pos_key]
	var owner = village.player_owner
	village.queue_free()
	placed_villages.erase(pos_key)
	if player_villages.has(owner):
		player_villages[owner].erase(village)

	Log.info("Removed village at q=%d, r=%d" % [q, r])
	village_removed.emit(q, r)
	return true


## Moves an existing village to a currently vacant hex that has a tile.
## Keeps the same Village node (owner, color, doubled state survive intact)
## and repositions it onto the destination hex's topmost tile, exactly like a
## fresh placement. Returns false without changing anything if there is no
## village at the source, the destination is occupied, or it has no tile.
func move_village(from_q: int, from_r: int, to_q: int, to_r: int) -> bool:
	var from_key = Vector2i(from_q, from_r)
	var to_key = Vector2i(to_q, to_r)

	if not placed_villages.has(from_key):
		Log.warn("No village at q=%d, r=%d to move" % [from_q, from_r])
		return false
	if placed_villages.has(to_key):
		Log.warn("Village already exists at q=%d, r=%d" % [to_q, to_r])
		return false
	if not tile_manager or not tile_manager.has_tile_at(to_q, to_r):
		Log.warn("No tile exists at q=%d, r=%d" % [to_q, to_r])
		return false

	var village = placed_villages[from_key]
	placed_villages.erase(from_key)
	village.set_grid_position(to_q, to_r)
	placed_villages[to_key] = village

	var top_height = tile_manager.get_top_height(to_q, to_r)
	var world_pos = HexGridUtils.axial_to_world(to_q, to_r, top_height)
	village.global_position = world_pos + Vector3(0, HexGridUtils.TILE_HEIGHT / 2, 0)

	Log.info("Moved village from q=%d, r=%d to q=%d, r=%d" % [from_q, from_r, to_q, to_r])
	village_removed.emit(from_q, from_r)
	village_placed.emit(to_q, to_r)
	return true


## Checks if a village exists at the given hex position.
## Returns true if a village is present, false otherwise.
func has_village_at(q: int, r: int) -> bool:
	return placed_villages.has(Vector2i(q, r))


## Gets all villages owned by a specific player.
## Returns an array of Village objects.
func get_villages_for_player(player: Player) -> Array[Village]:
	return player_villages.get(player, [] as Array[Village])


## Sums tile yields across all of a player's villages, grouped by resource type.
func harvest_totals_for_player(player: Player) -> Dictionary:
	var totals: Dictionary = {
		TileDefinition.ResourceType.MATERIALS: 0,
		TileDefinition.ResourceType.FERVOR: 0,
		TileDefinition.ResourceType.GLORY: 0
	}

	for village in get_villages_for_player(player):
		var tile = tile_manager.get_tile_at(village.q, village.r)
		if tile:
			var multiplier := village.multiplier()
			for res_type in tile.yields:
				totals[res_type] = totals.get(res_type, 0) + tile.yields[res_type] * multiplier

	return totals


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
	var color = Color(0.15, 0.92, 0.15, 0.72) if is_valid else Color(0.92, 0.15, 0.15, 0.72)
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


## Material name (set in Blender) that receives the full player color.
## All other surfaces are left untouched.
const COLOR_MATERIAL: String = "village_walls"

## Applies the player color to surfaces using the village_walls material.
## Creates per-instance material duplicates so villages don't share materials.
func _apply_color(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in range(mi.get_surface_override_material_count()):
			var mat = mi.get_surface_override_material(i)
			if mat == null and mi.mesh:
				mat = mi.mesh.surface_get_material(i)
			if mat and mat is StandardMaterial3D and mat.resource_name == COLOR_MATERIAL:
				var colored := mat.duplicate() as StandardMaterial3D
				colored.albedo_color = colored.albedo_color.lerp(color, 0.6)
				mi.set_surface_override_material(i, colored)
	for child in node.get_children():
		_apply_color(child, color)


# ==================== SERIALIZATION ====================

## Flat snapshot of every placed village, sorted into a canonical (q, r) order so
## two snapshots of the same board compare equal.
##
## Ownership is recorded as an index into `players` rather than as the object
## reference held in Village.player_owner — an index is what survives a save file
## or the wire. An owner missing from `players` is a bug, and is recorded as -1
## rather than silently reassigned.
func to_dict(players: Array[Player]) -> Array:
	var villages: Array = []
	for pos in placed_villages:
		var village: Village = placed_villages[pos]
		var owner_index := players.find(village.player_owner)
		if owner_index == -1:
			Log.error("VillageManager: village at (%d,%d) has an owner outside the player list" % [village.q, village.r])
		villages.append({
			"q": village.q,
			"r": village.r,
			"owner_index": owner_index,
			"is_doubled": village.is_doubled,
		})
	villages.sort_custom(func(a, b):
		if a["q"] != b["q"]: return a["q"] < b["q"]
		return a["r"] < b["r"])
	return villages


## Reconciles the board against a snapshot's village list (see GameState).
## Call after TileManager.apply(): a village's world position is derived from the
## height of the tile stack beneath it, so the tiles have to be settled first.
func apply(villages: Array, players: Array[Player]) -> void:
	var wanted: Dictionary = {}
	for entry in villages:
		wanted[Vector2i(entry["q"], entry["r"])] = entry

	# Drop villages the snapshot doesn't have — and also any whose owner changed,
	# which can't be repainted in place: _apply_color() lerps towards the player
	# colour from whatever material it finds, so calling it a second time
	# compounds the first colour instead of replacing it.
	for pos in placed_villages.keys():
		var entry = wanted.get(pos, null)
		if entry == null or placed_villages[pos].player_owner != _owner_from(entry, players):
			_discard_village(pos)

	for pos in wanted:
		var entry: Dictionary = wanted[pos]
		var village: Village = placed_villages.get(pos, null)
		if village == null:
			village = _restore_village(entry, _owner_from(entry, players))
		if village.is_doubled != entry["is_doubled"]:
			village.set_doubled(entry["is_doubled"])
		# Unconditional: the stack under an otherwise untouched village may have
		# grown or shrunk, which changes the height it sits at.
		_settle_on_stack(village)

	_reindex_by_player()


## The Player a snapshot entry belongs to, or null for the -1 written when a
## village was captured with an owner outside the player list.
func _owner_from(entry: Dictionary, players: Array[Player]) -> Player:
	var index: int = entry["owner_index"]
	if index < 0 or index >= players.size():
		Log.error("VillageManager: village at (%d,%d) has no valid owner index (%d)" % [entry["q"], entry["r"], index])
		return null
	return players[index]


func _restore_village(entry: Dictionary, village_owner: Player) -> Village:
	var village = village_scene.instantiate() as Village
	village.set_grid_position(entry["q"], entry["r"])
	village.set_player_owner(village_owner)
	add_child(village)
	if village_owner and village_owner.color != Color.WHITE:
		_apply_color(village, village_owner.color)
	placed_villages[Vector2i(entry["q"], entry["r"])] = village
	return village


## Detached before being queued for deletion, so it stops rendering immediately
## rather than lingering a frame over whatever replaces it.
func _discard_village(pos: Vector2i) -> void:
	var village: Village = placed_villages[pos]
	placed_villages.erase(pos)
	if village.get_parent() == self:
		remove_child(village)
	village.queue_free()


## Puts a village back on top of the current tile stack at its own coordinates.
func _settle_on_stack(village: Village) -> void:
	if not tile_manager:
		return
	var top_height := tile_manager.get_top_height(village.q, village.r)
	if top_height < 0:
		Log.error("VillageManager: village at (%d,%d) has no tile under it" % [village.q, village.r])
		return
	village.global_position = HexGridUtils.axial_to_world(village.q, village.r, top_height) \
		+ Vector3(0, HexGridUtils.TILE_HEIGHT / 2, 0)


## Rebuilds the per-player index wholesale rather than patching it. It's a pure
## view over placed_villages, so deriving it fresh can't drift out of sync.
func _reindex_by_player() -> void:
	player_villages.clear()
	for pos in placed_villages:
		var village: Village = placed_villages[pos]
		if not player_villages.has(village.player_owner):
			player_villages[village.player_owner] = [] as Array[Village]
		player_villages[village.player_owner].append(village)
