extends Node

class_name PlacementController

# Placement modes
enum PlacementMode {
	TILE,
	VILLAGE_PLACE,
	VILLAGE_REMOVE
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

# Debug mode
var debug_mode: bool = OS.is_debug_build()

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


func _input(event: InputEvent) -> void:
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
							selected_tile_def.buy_price,
							selected_tile_def.sell_price
						)
					else:
						# Test mode - place generic tile
						success = tile_manager.place_tile(preview_position.x, preview_position.y, current_tile_type)

					if success:
						# Notify board manager to consume tile from hand
						if selected_hand_index >= 0 and board_manager:
							board_manager.on_tile_placed_from_hand(selected_hand_index)

						placement_active = false
						preview_tile.visible = false
						selected_hand_index = -1
						selected_tile_def = null

			PlacementMode.VILLAGE_PLACE, PlacementMode.VILLAGE_REMOVE:
				var viewport = get_viewport()
				if not viewport:
					return
				var mouse_pos = viewport.get_mouse_position()
				var axial = board_manager.get_axial_at_mouse(mouse_pos)
				if axial != Vector2i(-999, -999):
					var success = false
					if current_mode == PlacementMode.VILLAGE_PLACE:
						# Use board_manager to handle costs and actions
						success = board_manager.on_village_placed(axial.x, axial.y)
					else:
						# Use board_manager to handle refund and actions
						success = board_manager.on_village_removed(axial.x, axial.y)

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

	# Keyboard shortcuts (DEBUG ONLY - disabled in exported game)
	if not debug_mode:
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
		PlacementMode.VILLAGE_PLACE, PlacementMode.VILLAGE_REMOVE:
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
	if current_mode == PlacementMode.VILLAGE_PLACE:
		# Check basic placement validity
		is_valid = not village_manager.has_village_at(q, r)

		# Also check affordability and actions
		if is_valid and board_manager:
			var tile = tile_manager.get_tile_at(q, r)
			if tile:
				var cost = TileManager.VILLAGE_BUILDING_COSTS[tile.tile_type]
				var player = board_manager.current_player

				# Check if player can afford it
				if player and player.resources < cost:
					is_valid = false

				# In game mode, check actions
				if player and board_manager.ui_mode == "game":
					if board_manager.current_phase != board_manager.TurnPhase.ACTIONS:
						is_valid = false
					elif player.actions_remaining <= 0:
						is_valid = false

		# Hide tooltip in place mode
		if board_manager and board_manager.ui:
			board_manager.ui.show_village_sell_tooltip(false)

	else:  # VILLAGE_REMOVE
		# Check if village exists and belongs to current player
		var village = village_manager.get_village_at(q, r)
		is_valid = village != null and village.player_owner == board_manager.current_player

		# Show sell value tooltip when hovering your own village
		if board_manager and board_manager.ui:
			if is_valid:
				var tile = tile_manager.get_tile_at(q, r)
				if tile:
					var building_cost = TileManager.VILLAGE_BUILDING_COSTS[tile.tile_type]
					var sell_refund = building_cost / 2  # Half price refund
					board_manager.ui.show_village_sell_tooltip(true, sell_refund)
			else:
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

	# Also check if player can afford and has actions (in game mode)
	if valid and board_manager.ui_mode == "game" and selected_tile_def:
		var player = board_manager.current_player
		if player:
			var in_actions_phase = (board_manager.current_phase == board_manager.TurnPhase.ACTIONS)
			if not player.can_place_tile(selected_tile_def, true, in_actions_phase):
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


## Cancels any active placement mode.
## Hides previews and returns to idle state.
func cancel_placement() -> void:
	placement_active = false
	preview_tile.visible = false
	if preview_village:
		preview_village.visible = false
