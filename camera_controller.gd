extends Camera3D

## Camera Controller for isometric tile-based game
## Handles panning and zooming while maintaining fixed isometric angle

# Zoom settings
@export var min_zoom: float = 8.0
@export var max_zoom: float = 25.0
@export var zoom_speed: float = 1.0
@export var zoom_smoothing: float = 10.0

# Pan settings
@export var keyboard_pan_speed: float = 15.0
@export var edge_pan_threshold: float = 20.0  # Pixels from edge to trigger panning
@export var edge_pan_speed: float = 15.0
@export var max_pan_distance: float = 20.0

# Internal state
var target_zoom: float
var target_position: Vector3
var is_panning: bool = false
var panning_anchor: Vector3  # World position when panning started

func _ready() -> void:
	# Initialize targets to current values
	target_zoom = size
	target_position = global_position

func _unhandled_input(event: InputEvent) -> void:
	# Handle mouse wheel zooming
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				start_panning(event.position)
			else:
				stop_panning()
			get_viewport().set_input_as_handled()

	# Handle mouse motion for panning
	elif event is InputEventMouseMotion and is_panning:
		update_panning(event.position)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	# Smooth zoom interpolation
	size = lerp(size, target_zoom, zoom_smoothing * delta)

	# Handle keyboard panning
	handle_keyboard_panning(delta)

	# Handle edge panning (only if not actively mouse-dragging)
	if not is_panning:
		handle_edge_panning(delta)

	# Direct pan movement (no smoothing needed)
	global_position = target_position

func zoom_in() -> void:
	target_zoom = clamp(target_zoom - zoom_speed, min_zoom, max_zoom)

func zoom_out() -> void:
	target_zoom = clamp(target_zoom + zoom_speed, min_zoom, max_zoom)

func start_panning(mouse_pos: Vector2) -> void:
	is_panning = true
	# Remember the world position under the mouse when panning starts
	panning_anchor = get_world_position_at_mouse(mouse_pos)

func stop_panning() -> void:
	is_panning = false

func update_panning(mouse_pos: Vector2) -> void:
	# Get what world position is currently under the mouse
	var current_world_pos: Vector3 = get_world_position_at_mouse(mouse_pos)

	# Calculate offset to keep the anchor point under the mouse
	var offset: Vector3 = panning_anchor - current_world_pos

	# Move camera to maintain the anchor position
	var new_position: Vector3 = target_position + offset

	# Apply boundary constraints (keep camera within reasonable bounds)
	new_position.x = clamp(new_position.x, -max_pan_distance, max_pan_distance)
	new_position.z = clamp(new_position.z, -max_pan_distance, max_pan_distance)

	target_position = new_position

func handle_keyboard_panning(delta: float) -> void:
	var move_direction := Vector3.ZERO

	# Check WASD keys
	if Input.is_key_pressed(KEY_W):
		move_direction.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		move_direction.z += 1.0
	if Input.is_key_pressed(KEY_A):
		move_direction.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		move_direction.x += 1.0

	# Check Arrow keys
	if Input.is_key_pressed(KEY_UP):
		move_direction.z -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		move_direction.z += 1.0
	if Input.is_key_pressed(KEY_LEFT):
		move_direction.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		move_direction.x += 1.0

	# Apply movement if any keys are pressed
	if move_direction.length_squared() > 0:
		move_direction = move_direction.normalized()
		var new_position := target_position + move_direction * keyboard_pan_speed * delta

		# Apply boundary constraints
		new_position.x = clamp(new_position.x, -max_pan_distance, max_pan_distance)
		new_position.z = clamp(new_position.z, -max_pan_distance, max_pan_distance)

		target_position = new_position

func handle_edge_panning(delta: float) -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	var viewport_size := get_viewport().get_visible_rect().size
	var move_direction := Vector3.ZERO

	# Check if mouse is near edges
	if mouse_pos.x < edge_pan_threshold:
		move_direction.x -= 1.0
	elif mouse_pos.x > viewport_size.x - edge_pan_threshold:
		move_direction.x += 1.0

	if mouse_pos.y < edge_pan_threshold:
		move_direction.z -= 1.0
	elif mouse_pos.y > viewport_size.y - edge_pan_threshold:
		move_direction.z += 1.0

	# Apply movement if near any edge
	if move_direction.length_squared() > 0:
		move_direction = move_direction.normalized()
		var new_position := target_position + move_direction * edge_pan_speed * delta

		# Apply boundary constraints
		new_position.x = clamp(new_position.x, -max_pan_distance, max_pan_distance)
		new_position.z = clamp(new_position.z, -max_pan_distance, max_pan_distance)

		target_position = new_position

func get_world_position_at_mouse(mouse_pos: Vector2) -> Vector3:
	# Cast a ray from the camera through the mouse position
	var ray_origin: Vector3 = project_ray_origin(mouse_pos)
	var ray_dir: Vector3 = project_ray_normal(mouse_pos)

	# Intersect ray with the ground plane (y = 0)
	# Ray equation: P = origin + t * direction
	# Plane equation: y = 0
	# Solving: origin.y + t * direction.y = 0
	# Therefore: t = -origin.y / direction.y

	if abs(ray_dir.y) < 0.0001:
		# Ray is nearly parallel to plane (shouldn't happen with this camera angle)
		return Vector3.ZERO

	var t: float = -ray_origin.y / ray_dir.y
	return ray_origin + ray_dir * t
