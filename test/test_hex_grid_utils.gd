extends GdUnitTestSuite

# HexGridUtils is all static functions — no nodes, no physics, no cleanup needed.


# --- axial_to_world ---

func test_origin_maps_to_world_zero() -> void:
	var pos = HexGridUtils.axial_to_world(0, 0, 0)
	assert_float(pos.x).is_equal(0.0)
	assert_float(pos.z).is_equal(0.0)
	assert_float(pos.y).is_equal(0.0)


func test_height_level_sets_y() -> void:
	var plains = HexGridUtils.axial_to_world(0, 0, 0)
	var hills  = HexGridUtils.axial_to_world(0, 0, 1)
	var mountain = HexGridUtils.axial_to_world(0, 0, 2)
	assert_float(hills.y).is_greater(plains.y)
	assert_float(mountain.y).is_greater(hills.y)


func test_adjacent_q_offset_changes_x() -> void:
	var a = HexGridUtils.axial_to_world(0, 0, 0)
	var b = HexGridUtils.axial_to_world(1, 0, 0)
	assert_float(b.x).is_not_equal(a.x)


# --- get_axial_neighbors ---

func test_neighbors_returns_six() -> void:
	var neighbors = HexGridUtils.get_axial_neighbors(0, 0)
	assert_int(neighbors.size()).is_equal(6)


func test_neighbors_are_unique() -> void:
	var neighbors = HexGridUtils.get_axial_neighbors(0, 0)
	var unique: Array = []
	for n in neighbors:
		assert_bool(unique.has(n)).is_false()
		unique.append(n)


func test_known_neighbors_of_origin() -> void:
	var neighbors = HexGridUtils.get_axial_neighbors(0, 0)
	# All six axial hex directions
	for expected in [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, -1), Vector2i(-1, 1)
	]:
		assert_bool(neighbors.has(expected)).is_true()


func test_neighbor_of_nonzero_hex() -> void:
	var neighbors = HexGridUtils.get_axial_neighbors(2, 3)
	assert_bool(neighbors.has(Vector2i(3, 3))).is_true()
	assert_bool(neighbors.has(Vector2i(1, 3))).is_true()


func test_origin_is_not_its_own_neighbor() -> void:
	var neighbors = HexGridUtils.get_axial_neighbors(0, 0)
	assert_bool(neighbors.has(Vector2i(0, 0))).is_false()
