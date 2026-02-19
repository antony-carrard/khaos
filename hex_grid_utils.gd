class_name HexGridUtils

## Pure hex grid math utilities. All methods are static — no instance needed.
## Reference: https://www.redblobgames.com/grids/hexagons/


## Converts axial hex coordinates (q, r) and height to 3D world position.
## Uses flat-top hexagon orientation.
static func axial_to_world(q: int, r: int, height: int, hex_size: float, tile_height: float) -> Vector3:
	var x = hex_size * (sqrt(3.0) * q + sqrt(3.0) / 2.0 * r)
	var z = hex_size * (3.0 / 2.0 * r)
	var y = height * tile_height
	return Vector3(x, y, z)


## Converts 3D world position to axial hex coordinates (q, r).
## Returns the hex grid cell containing the world position.
static func world_to_axial(world_pos: Vector3, hex_size: float) -> Vector2i:
	var q = (sqrt(3.0) / 3.0 * world_pos.x - 1.0 / 3.0 * world_pos.z) / hex_size
	var r = (2.0 / 3.0 * world_pos.z) / hex_size
	return axial_round(q, r)


static func axial_round(q: float, r: float) -> Vector2i:
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


## Returns the 6 adjacent hex positions around the given hex coordinate.
## Order: East, Northeast, Northwest, West, Southwest, Southeast.
static func get_axial_neighbors(q: int, r: int) -> Array[Vector2i]:
	var directions = [
		Vector2i(+1, 0), Vector2i(+1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, +1), Vector2i(0, +1)
	]
	var neighbors: Array[Vector2i] = []
	for dir in directions:
		neighbors.append(Vector2i(q + dir.x, r + dir.y))
	return neighbors


## Gets the hex coordinates at the mouse cursor position via raycast.
## Returns Vector2i(-999, -999) if no valid position found (no camera or raycast miss).
static func get_axial_at_mouse(mouse_pos: Vector2, camera: Camera3D, world_3d: World3D, hex_size: float) -> Vector2i:
	if not camera:
		return Vector2i(-999, -999)

	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000

	if not world_3d:
		return Vector2i(-999, -999)

	var space_state = world_3d.direct_space_state
	if not space_state:
		return Vector2i(-999, -999)

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 0b11  # Layers 1 and 2
	var result = space_state.intersect_ray(query)

	if result:
		return world_to_axial(result.position, hex_size)

	return Vector2i(-999, -999)
