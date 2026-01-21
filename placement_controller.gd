extends Node

class_name PlacementController

# Placement modes
enum PlacementMode {
	TILE,
	VILLAGE_PLACE,
	VILLAGE_REMOVE,
	STEAL_HARVEST,  # For Rakun's power - select enemy village to steal harvest
	DESTROY_VILLAGE_FREE,  # For Le Bâtisseur's power - destroy enemy village without compensation
	CHANGE_TILE_TYPE,  # For Augia's power - change resource type of own tiles
	UPGRADE_TILE_KEEP_VILLAGE,  # For Augia's power - upgrade tile without destroying village
	DOWNGRADE_TILE_KEEP_VILLAGE  # For Rakun's power - downgrade tile without destroying village
}

# State
var current_mode: PlacementMode = PlacementMode.TILE
var placement_active: bool = false
var current_tile_type: int = 0  # TileManager.TileType value
var selected_hand_index: int = -1  # Index of tile selected from hand (-1 = none)
var selected_tile_def = null  # TilePool.TileDefinition from hand

# Preview objects
var preview_tile: HexTile = null
var preview_village: Node3D = null
var preview_position: Vector3i = Vector3i.ZERO

# References (set by board_manager)
var tile_manager: TileManager = null
var village_manager: VillageManager = null
var camera: Camera3D = null
var board_manager = null  # For coordinate conversion helpers


# Initialization flag
var is_ready: bool = false


## Initializes the PlacementController with required manager references.
## Call this once after instantiation. Waits one frame before marking ready.
func initialize(_tile_manager: TileManager, _village_manager: VillageManager, _camera: Camera3D, _board_manager) -> void:
	tile_manager = _tile_manager
	village_manager = _village_manager
	camera = _camera
	board_manager = _board_manager

	# Create tile preview
	preview_tile = tile_manager.hex_tile_scene.instantiate() as HexTile
	preview_tile.original_color = Color(0.5, 0.5, 0.8, 0.6)
	board_manager.add_child(preview_tile)
	preview_tile.visible = false

	# Mark as ready after one frame
	await get_tree().process_frame
	is_ready = true


func _process(_delta: float) -> void:
	# Don't update preview if not properly initialized
	if not is_ready or not camera or not board_manager:
		return
	update_preview()


func _unhandled_input(event: InputEvent) -> void:
	handle_mouse_input(event)
	handle_keyboard_input(event)


func handle_mouse_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not placement_active:
			return

		match current_mode:
			PlacementMode.TILE:
				if preview_tile.visible and tile_manager.is_valid_placement(preview_position.x, preview_position.y, current_tile_type):
					# Place tile with specific properties if from hand
					var success = false
					if selected_tile_def:
						success = tile_manager.place_tile(
							preview_position.x, preview_position.y,
							selected_tile_def.tile_type,
							selected_tile_def.resource_type,
							selected_tile_def.yield_value,
							selected_tile_def.village_building_cost,
							selected_tile_def.sell_price
						)
					else:
						# Test mode - place generic tile
						success = tile_manager.place_tile(preview_position.x, preview_position.y, current_tile_type)

					if success:
						# Setup phase: auto-place village (free!) and notify turn manager
						if board_manager.turn_manager.is_setup_phase():
							village_manager.place_village(
								preview_position.x, preview_position.y,
								board_manager.current_player
							)
							print("Auto-placed village during setup at (%d, %d)" % [preview_position.x, preview_position.y])

							# Notify turn manager of setup tile placement
							board_manager.turn_manager.on_setup_tile_placed(selected_hand_index)
						else:
							# Normal game: notify board manager to consume tile from hand
							if selected_hand_index >= 0 and board_manager:
								board_manager.on_tile_placed_from_hand(selected_hand_index)

						placement_active = false
						preview_tile.visible = false
						selected_hand_index = -1
						selected_tile_def = null

			PlacementMode.VILLAGE_PLACE, PlacementMode.VILLAGE_REMOVE:
				var axial = get_axial_at_mouse()
				if axial != Vector2i(-999, -999):
					var success = false
					if current_mode == PlacementMode.VILLAGE_PLACE:
						success = board_manager.on_village_placed(axial.x, axial.y)
					else:
						success = board_manager.on_village_removed(axial.x, axial.y)

					if success:
						placement_active = false

			PlacementMode.STEAL_HARVEST:
				var axial = get_axial_at_mouse()
				if axial != Vector2i(-999, -999):
					var success = board_manager.on_steal_harvest(axial.x, axial.y)
					if success:
						placement_active = false

			PlacementMode.DESTROY_VILLAGE_FREE:
				var axial = get_axial_at_mouse()
				if axial != Vector2i(-999, -999):
					var success = board_manager.on_destroy_village_free(axial.x, axial.y)
					if success:
						placement_active = false

			PlacementMode.CHANGE_TILE_TYPE:
				var axial = get_axial_at_mouse()
				if axial != Vector2i(-999, -999):
					# Show resource type selection UI
					board_manager.show_resource_type_selection(axial.x, axial.y)
					# Keep placement_active = true until resource type is selected

			PlacementMode.UPGRADE_TILE_KEEP_VILLAGE:
				var axial = get_axial_at_mouse()
				if axial != Vector2i(-999, -999):
					var success = board_manager.on_upgrade_tile(axial.x, axial.y)
					if success:
						placement_active = false

			PlacementMode.DOWNGRADE_TILE_KEEP_VILLAGE:
				var axial = get_axial_at_mouse()
				if axial != Vector2i(-999, -999):
					var success = board_manager.on_downgrade_tile(axial.x, axial.y)
					if success:
						placement_active = false


func handle_keyboard_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	# ESC to exit placement mode (always available)
	if event.keycode == KEY_ESCAPE:
		placement_active = false
		preview_tile.visible = false
		if preview_village:
			preview_village.visible = false
		return

	# Debug keyboard shortcuts (only in debug builds)
	if not OS.is_debug_build():
		return

	if event.keycode == KEY_1:
		select_tile_type(TileManager.TileType.PLAINS)
	elif event.keycode == KEY_2:
		select_tile_type(TileManager.TileType.HILLS)
	elif event.keycode == KEY_3:
		select_tile_type(TileManager.TileType.MOUNTAIN)


func update_preview() -> void:
	if not placement_active:
		preview_tile.visible = false
		if preview_village:
			preview_village.visible = false
		# Hide tooltip when exiting placement mode
		if board_manager and board_manager.ui:
			board_manager.ui.show_village_sell_tooltip(false)
		return

	match current_mode:
		PlacementMode.VILLAGE_PLACE, PlacementMode.VILLAGE_REMOVE, \
		PlacementMode.STEAL_HARVEST, PlacementMode.DESTROY_VILLAGE_FREE, \
		PlacementMode.CHANGE_TILE_TYPE, PlacementMode.UPGRADE_TILE_KEEP_VILLAGE, \
		PlacementMode.DOWNGRADE_TILE_KEEP_VILLAGE:
			update_village_preview()
		PlacementMode.TILE:
			update_tile_preview()


func update_village_preview() -> void:
	preview_tile.visible = false

	# Create preview village if it doesn't exist
	if not preview_village:
		preview_village = village_manager.create_preview_village()
		board_manager.add_child(preview_village)

	# Guard clause: no viewport
	var viewport = get_viewport()
	if not viewport:
		if preview_village:
			preview_village.visible = false
		if board_manager and board_manager.ui:
			board_manager.ui.show_village_sell_tooltip(false)
		return

	# Guard clause: invalid mouse position
	var mouse_pos = viewport.get_mouse_position()
	var axial = board_manager.get_axial_at_mouse(mouse_pos)
	if axial == Vector2i(-999, -999):
		preview_village.visible = false
		if board_manager and board_manager.ui:
			board_manager.ui.show_village_sell_tooltip(false)
		return

	var q = axial.x
	var r = axial.y

	# Guard clause: no tile at position
	if not tile_manager.has_tile_at(q, r):
		preview_village.visible = false
		if board_manager and board_manager.ui:
			board_manager.ui.show_village_sell_tooltip(false)
		return

	# Show preview
	preview_village.visible = true
	var top_height = tile_manager.get_top_height(q, r)
	var world_pos = board_manager.axial_to_world(q, r, top_height)
	preview_village.global_position = world_pos + Vector3(0, tile_manager.tile_height / 2, 0)

	# Update color based on validity
	var is_valid = false

	match current_mode:
		PlacementMode.VILLAGE_PLACE:
			# Check basic placement validity
			is_valid = not village_manager.has_village_at(q, r)

			# Also check affordability and actions
			if is_valid and board_manager:
				var tile = tile_manager.get_tile_at(q, r)
				if tile:
					var player = board_manager.current_player
					if player:
						var cost = player.get_village_cost(tile.village_building_cost)
						# Check if player can afford it
						if player.resources < cost:
							is_valid = false

					# Check actions
					if player:
						if not board_manager.turn_manager.is_actions_phase():
							is_valid = false
						elif player.actions_remaining <= 0:
							is_valid = false

			# Hide tooltip in place mode
			if board_manager and board_manager.ui:
				board_manager.ui.show_village_sell_tooltip(false)

		PlacementMode.VILLAGE_REMOVE:
			# Check if village exists and belongs to current player
			var village = village_manager.get_village_at(q, r)
			is_valid = village != null and village.player_owner == board_manager.current_player

			# Show sell value tooltip when hovering your own village
			if board_manager and board_manager.ui:
				if is_valid:
					var tile = tile_manager.get_tile_at(q, r)
					if tile:
						var player = board_manager.current_player
						if player:
							var building_cost = player.get_village_cost(tile.village_building_cost)
							var sell_refund = building_cost / 2  # Half price refund
							board_manager.ui.show_village_sell_tooltip(true, sell_refund)
				else:
					board_manager.ui.show_village_sell_tooltip(false)

		PlacementMode.STEAL_HARVEST:
			# Check if village exists and belongs to ENEMY player (not current player)
			var village = village_manager.get_village_at(q, r)
			is_valid = village != null and village.player_owner != board_manager.current_player

			# Show harvest value tooltip when hovering enemy village
			if board_manager and board_manager.ui:
				if is_valid:
					var tile = tile_manager.get_tile_at(q, r)
					if tile:
						var harvest_value = tile.yield_value
						# Reuse tooltip to show harvest value
						board_manager.ui.show_village_sell_tooltip(true, harvest_value)
				else:
					board_manager.ui.show_village_sell_tooltip(false)

		PlacementMode.DESTROY_VILLAGE_FREE:
			# Check if village exists and belongs to ENEMY player
			var village = village_manager.get_village_at(q, r)
			is_valid = village != null and village.player_owner != board_manager.current_player

			# No tooltip needed - destruction is free!
			if board_manager and board_manager.ui:
				board_manager.ui.show_village_sell_tooltip(false)

		PlacementMode.CHANGE_TILE_TYPE:
			# Check if tile exists and optionally has player's village on it
			# Player can change any tile on the board that they own (has their village)
			var village = village_manager.get_village_at(q, r)
			is_valid = village != null and village.player_owner == board_manager.current_player

			# No tooltip needed
			if board_manager and board_manager.ui:
				board_manager.ui.show_village_sell_tooltip(false)

		PlacementMode.UPGRADE_TILE_KEEP_VILLAGE:
			# Check if tile exists and has player's village on it
			var village = village_manager.get_village_at(q, r)
			if village != null and village.player_owner == board_manager.current_player:
				# Check if tile can be upgraded (not already at max level)
				var tile = tile_manager.get_tile_at(q, r)
				is_valid = tile != null and tile.tile_type != TileManager.TileType.MOUNTAIN
			else:
				is_valid = false

			# No tooltip needed
			if board_manager and board_manager.ui:
				board_manager.ui.show_village_sell_tooltip(false)

		PlacementMode.DOWNGRADE_TILE_KEEP_VILLAGE:
			# Check if tile exists and has player's village on it
			var village = village_manager.get_village_at(q, r)
			if village != null and village.player_owner == board_manager.current_player:
				# Check if tile can be downgraded (not already at min level)
				var tile = tile_manager.get_tile_at(q, r)
				is_valid = tile != null and tile.tile_type != TileManager.TileType.PLAINS
			else:
				is_valid = false

			# No tooltip needed
			if board_manager and board_manager.ui:
				board_manager.ui.show_village_sell_tooltip(false)

	village_manager.update_preview_color(preview_village, is_valid)


func update_tile_preview() -> void:
	if preview_village:
		preview_village.visible = false

	if not camera:
		preview_tile.visible = false
		return

	var viewport = get_viewport()
	if not viewport:
		preview_tile.visible = false
		return

	var mouse_pos = viewport.get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000

	var world_3d = board_manager.get_world_3d()
	if not world_3d:
		preview_tile.visible = false
		return

	var space_state = world_3d.direct_space_state
	if not space_state:
		preview_tile.visible = false
		return

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 0b11  # Layers 1 and 2
	var result = space_state.intersect_ray(query)

	if not result:
		preview_tile.visible = false
		return

	var hit_position = result.position
	var axial = board_manager.world_to_axial(hit_position)
	var q = axial.x
	var r = axial.y
	var height = TileManager.TILE_TYPE_TO_HEIGHT[current_tile_type]

	# Only show preview if height is valid
	if height >= tile_manager.max_stack_height:
		preview_tile.visible = false
		return

	preview_position = Vector3i(q, r, height)
	preview_tile.visible = true
	preview_tile.set_grid_position(q, r, height)
	preview_tile.set_tile_type(current_tile_type, TileManager.TILE_TYPE_COLORS[current_tile_type])
	preview_tile.global_position = board_manager.axial_to_world(q, r, height)

	# Check if placement is valid (grid rules)
	var valid = tile_manager.is_valid_placement(q, r, current_tile_type)

	# Also check if player has actions
	if valid and selected_tile_def:
		var player = board_manager.current_player
		if player:
			var in_actions_phase = board_manager.turn_manager.is_actions_phase()
			if in_actions_phase and player.actions_remaining <= 0:
				valid = false

	preview_tile.set_highlight(true, valid)


# Public API for mode switching

## Enters tile placement mode with the specified tile type.
## Activates preview and waits for player to click to place.
func select_tile_type(tile_type: int) -> void:
	current_tile_type = tile_type
	current_mode = PlacementMode.TILE
	placement_active = true
	selected_hand_index = -1  # Clear hand selection
	selected_tile_def = null


## Enters tile placement mode with a specific tile from hand.
## Activates preview and waits for player to click to place.
func select_tile_from_hand(hand_index: int, tile_def) -> void:
	selected_hand_index = hand_index
	selected_tile_def = tile_def
	current_tile_type = tile_def.tile_type
	current_mode = PlacementMode.TILE
	placement_active = true


## Enters village placement mode.
## Shows village preview and waits for player to click to place.
func select_village_place_mode() -> void:
	current_mode = PlacementMode.VILLAGE_PLACE
	placement_active = true


## Enters village removal mode.
## Shows village preview and waits for player to click to remove.
func select_village_remove_mode() -> void:
	current_mode = PlacementMode.VILLAGE_REMOVE
	placement_active = true


## Enters steal harvest mode (Rakun's power).
## Shows village preview and waits for player to click enemy village.
func select_steal_harvest_mode() -> void:
	current_mode = PlacementMode.STEAL_HARVEST
	placement_active = true


## Enters destroy village free mode (Le Bâtisseur's power).
## Shows village preview and waits for player to click enemy village to destroy.
func select_destroy_village_free_mode() -> void:
	current_mode = PlacementMode.DESTROY_VILLAGE_FREE
	placement_active = true


## Enters change tile type mode (Augia's power).
## Shows village preview and waits for player to click their own village to change tile type.
func select_change_tile_type_mode() -> void:
	current_mode = PlacementMode.CHANGE_TILE_TYPE
	placement_active = true


## Enters upgrade tile mode (Augia's power).
## Shows village preview and waits for player to click their own village to upgrade tile.
func select_upgrade_tile_mode() -> void:
	current_mode = PlacementMode.UPGRADE_TILE_KEEP_VILLAGE
	placement_active = true


## Enters downgrade tile mode (Rakun's power).
## Shows village preview and waits for player to click their own village to downgrade tile.
func select_downgrade_tile_mode() -> void:
	current_mode = PlacementMode.DOWNGRADE_TILE_KEEP_VILLAGE
	placement_active = true


## Helper to get axial coordinates at current mouse position
## Returns Vector2i(-999, -999) if no valid position found
func get_axial_at_mouse() -> Vector2i:
	var viewport = get_viewport()
	if not viewport:
		return Vector2i(-999, -999)
	var mouse_pos = viewport.get_mouse_position()
	return board_manager.get_axial_at_mouse(mouse_pos)


## Cancels any active placement mode.
## Hides previews and returns to idle state.
func cancel_placement() -> void:
	placement_active = false
	preview_tile.visible = false
	if preview_village:
		preview_village.visible = false

	# Clear pending power if player cancels selection-based power
	if board_manager and board_manager.current_player:
		board_manager.current_player.pending_power = null
