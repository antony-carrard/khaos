extends Node

class_name PlacementController

# State
var current_tile_type: int = 0  # TileManager.TileType value
var selected_hand_index: int = -1  # Index of tile selected from hand (-1 = none)
var selected_tile_def = null  # TilePool.TileDefinition from hand

# Strategy — non-null means placement is active
var current_strategy: PlacementStrategy = null

# Preview objects
var preview_tile: HexTile = null
var preview_village: Node3D = null
var preview_position: Vector3i = Vector3i.ZERO

# References (set by board_manager)
var tile_manager: TileManager = null
var village_manager: VillageManager = null
var camera: Camera3D = null
var board_manager = null  # For coordinate conversion helpers

var is_ready: bool = false


## Initializes the PlacementController with required manager references.
## Call this once after instantiation. Waits one frame before marking ready.
func initialize(_tile_manager: TileManager, _village_manager: VillageManager, _camera: Camera3D, _board_manager) -> void:
	tile_manager = _tile_manager
	village_manager = _village_manager
	camera = _camera
	board_manager = _board_manager

	preview_tile = tile_manager.hex_tile_scene.instantiate() as HexTile
	preview_tile.original_color = Color(0.5, 0.5, 0.8, 0.6)
	board_manager.add_child(preview_tile)
	preview_tile.visible = false

	await get_tree().process_frame
	is_ready = true


func _process(_delta: float) -> void:
	if not is_ready or not camera or not board_manager:
		return
	update_preview()


func _unhandled_input(event: InputEvent) -> void:
	handle_mouse_input(event)
	handle_keyboard_input(event)


func handle_mouse_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if current_strategy == null:
			return

		if current_strategy.uses_tile_preview:
			if current_strategy.on_click(self, preview_position.x, preview_position.y):
				current_strategy = null
		else:
			var axial = get_axial_at_mouse()
			if axial != Vector2i(-999, -999):
				if current_strategy.on_click(self, axial.x, axial.y):
					current_strategy = null


func handle_keyboard_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	if event.keycode == KEY_ESCAPE:
		_deactivate()
		return

	if not OS.is_debug_build():
		return

	if event.keycode == KEY_1:
		select_tile_type(TileManager.TileType.PLAINS)
	elif event.keycode == KEY_2:
		select_tile_type(TileManager.TileType.HILLS)
	elif event.keycode == KEY_3:
		select_tile_type(TileManager.TileType.MOUNTAIN)


func update_preview() -> void:
	if current_strategy == null:
		preview_tile.visible = false
		if preview_village:
			preview_village.visible = false
		if board_manager and board_manager.ui:
			board_manager.ui.show_village_sell_tooltip(false)
		return

	if current_strategy.uses_tile_preview:
		update_tile_preview()
	else:
		update_village_preview()


func update_village_preview() -> void:
	preview_tile.visible = false

	if not preview_village:
		preview_village = village_manager.create_preview_village()
		board_manager.add_child(preview_village)

	var viewport = get_viewport()
	if not viewport:
		preview_village.visible = false
		if board_manager and board_manager.ui:
			board_manager.ui.show_village_sell_tooltip(false)
		return

	var mouse_pos = viewport.get_mouse_position()
	var axial = board_manager.get_axial_at_mouse(mouse_pos)
	if axial == Vector2i(-999, -999):
		preview_village.visible = false
		if board_manager and board_manager.ui:
			board_manager.ui.show_village_sell_tooltip(false)
		return

	var q = axial.x
	var r = axial.y

	if not tile_manager.has_tile_at(q, r):
		preview_village.visible = false
		if board_manager and board_manager.ui:
			board_manager.ui.show_village_sell_tooltip(false)
		return

	preview_village.visible = true
	var top_height = tile_manager.get_top_height(q, r)
	var world_pos = board_manager.axial_to_world(q, r, top_height)
	preview_village.global_position = world_pos + Vector3(0, tile_manager.tile_height / 2, 0)

	var is_valid = current_strategy.get_validity(self, q, r)
	current_strategy.update_tooltip(self, q, r, is_valid)
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

	if height >= tile_manager.max_stack_height:
		preview_tile.visible = false
		return

	preview_position = Vector3i(q, r, height)
	preview_tile.visible = true
	preview_tile.set_grid_position(q, r, height)
	preview_tile.set_tile_type(current_tile_type, TileManager.TILE_TYPE_COLORS[current_tile_type])
	preview_tile.global_position = board_manager.axial_to_world(q, r, height)

	var valid = tile_manager.is_valid_placement(q, r, current_tile_type)

	if valid and selected_tile_def:
		var player = board_manager.current_player
		if player:
			if board_manager.turn_manager.is_actions_phase() and player.actions_remaining <= 0:
				valid = false

	preview_tile.set_highlight(true, valid)


# Public API for mode switching

func select_tile_type(tile_type: int) -> void:
	current_tile_type = tile_type
	selected_hand_index = -1
	selected_tile_def = null
	current_strategy = TilePlacementStrategy.new()


func select_tile_from_hand(hand_index: int, tile_def) -> void:
	selected_hand_index = hand_index
	selected_tile_def = tile_def
	current_tile_type = tile_def.tile_type
	current_strategy = TilePlacementStrategy.new()


func select_village_place_mode() -> void:
	current_strategy = VillagePlaceStrategy.new()


func select_village_remove_mode() -> void:
	current_strategy = VillageRemoveStrategy.new()


func select_steal_harvest_mode() -> void:
	current_strategy = StealHarvestStrategy.new()


func select_destroy_village_free_mode() -> void:
	current_strategy = DestroyVillageFreeStrategy.new()


func select_change_tile_type_mode() -> void:
	current_strategy = ChangeTileTypeStrategy.new()


func select_upgrade_tile_mode() -> void:
	current_strategy = UpgradeTileStrategy.new()


func select_downgrade_tile_mode() -> void:
	current_strategy = DowngradeTileStrategy.new()


## Returns Vector2i(-999, -999) if no valid position found.
func get_axial_at_mouse() -> Vector2i:
	var viewport = get_viewport()
	if not viewport:
		return Vector2i(-999, -999)
	var mouse_pos = viewport.get_mouse_position()
	return board_manager.get_axial_at_mouse(mouse_pos)


## Cancels any active placement mode and clears the player's pending power.
func cancel_placement() -> void:
	_deactivate()
	if board_manager and board_manager.current_player:
		board_manager.current_player.pending_power = null


func _deactivate() -> void:
	current_strategy = null
	preview_tile.visible = false
	if preview_village:
		preview_village.visible = false
