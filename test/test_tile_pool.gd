extends GdUnitTestSuite


var pool: TilePool


func before_test() -> void:
	pool = auto_free(TilePool.new())
	pool.initialize()


func test_bag_starts_with_63_tiles() -> void:
	assert_int(pool.get_remaining_count()).is_equal(63)


func test_draw_reduces_count() -> void:
	pool.draw_tile()
	assert_int(pool.get_remaining_count()).is_equal(62)


func test_draw_multiple_reduces_count() -> void:
	pool.draw_tiles(3)
	assert_int(pool.get_remaining_count()).is_equal(60)


func test_is_empty_after_drawing_all() -> void:
	for i in range(63):
		pool.draw_tile()
	assert_bool(pool.is_empty()).is_true()


func test_draw_returns_null_when_empty() -> void:
	for i in range(63):
		pool.draw_tile()
	assert_object(pool.draw_tile()).is_null()


func test_drawn_tile_has_valid_type() -> void:
	var tile = pool.draw_tile()
	assert_int(tile.tile_type).is_in([
		TileManager.TileType.PLAINS,
		TileManager.TileType.HILLS,
		TileManager.TileType.MOUNTAIN
	])


func test_drawn_tile_has_valid_resource_type() -> void:
	var tile = pool.draw_tile()
	assert_int(tile.resource_type).is_in([
		TileManager.ResourceType.RESOURCES,
		TileManager.ResourceType.FERVOR,
		TileManager.ResourceType.GLORY
	])


func test_glory_only_on_hills_and_mountains() -> void:
	# Draw all tiles and check the constraint
	var all_tiles = pool.draw_tiles(63)
	for tile in all_tiles:
		if tile.resource_type == TileManager.ResourceType.GLORY:
			assert_int(tile.tile_type).is_not_equal(TileManager.TileType.PLAINS)


func test_draw_plains_tile_returns_correct_type() -> void:
	var tile = pool.draw_plains_tile(TileManager.ResourceType.RESOURCES)
	assert_object(tile).is_not_null()
	assert_int(tile.tile_type).is_equal(TileManager.TileType.PLAINS)
	assert_int(tile.resource_type).is_equal(TileManager.ResourceType.RESOURCES)


func test_draw_plains_tile_fervor_returns_correct_type() -> void:
	var tile = pool.draw_plains_tile(TileManager.ResourceType.FERVOR)
	assert_object(tile).is_not_null()
	assert_int(tile.tile_type).is_equal(TileManager.TileType.PLAINS)
	assert_int(tile.resource_type).is_equal(TileManager.ResourceType.FERVOR)


func test_draw_plains_tile_reduces_count() -> void:
	pool.draw_plains_tile(TileManager.ResourceType.RESOURCES)
	assert_int(pool.get_remaining_count()).is_equal(62)


func test_draw_plains_tile_returns_null_when_exhausted() -> void:
	# Draw all 14 PLAINS/Resources tiles
	for i in range(14):
		pool.draw_plains_tile(TileManager.ResourceType.RESOURCES)
	var tile = pool.draw_plains_tile(TileManager.ResourceType.RESOURCES)
	assert_object(tile).is_null()


func test_draw_plains_tile_does_not_return_glory() -> void:
	var tile = pool.draw_plains_tile(TileManager.ResourceType.GLORY)
	assert_object(tile).is_null()


# --- has_tile_of_type ---

func test_has_tile_of_type_true_when_present() -> void:
	assert_bool(pool.has_tile_of_type(TileManager.TileType.HILLS)).is_true()


func test_has_tile_of_type_false_when_exhausted() -> void:
	# Draw all 21 HILLS tiles
	for i in range(21):
		pool.draw_tile_of_type(TileManager.TileType.HILLS)
	assert_bool(pool.has_tile_of_type(TileManager.TileType.HILLS)).is_false()


# --- draw_tile_of_type ---

func test_draw_tile_of_type_returns_correct_type() -> void:
	var tile = pool.draw_tile_of_type(TileManager.TileType.HILLS)
	assert_object(tile).is_not_null()
	assert_int(tile.tile_type).is_equal(TileManager.TileType.HILLS)


func test_draw_tile_of_type_reduces_count() -> void:
	pool.draw_tile_of_type(TileManager.TileType.MOUNTAIN)
	assert_int(pool.get_remaining_count()).is_equal(62)


func test_draw_tile_of_type_returns_null_when_exhausted() -> void:
	# Draw all 14 MOUNTAIN tiles
	for i in range(14):
		pool.draw_tile_of_type(TileManager.TileType.MOUNTAIN)
	var tile = pool.draw_tile_of_type(TileManager.TileType.MOUNTAIN)
	assert_object(tile).is_null()


# --- has_tile_of_type_and_resource ---

func test_has_tile_of_type_and_resource_true_when_present() -> void:
	assert_bool(pool.has_tile_of_type_and_resource(TileManager.TileType.HILLS, TileManager.ResourceType.RESOURCES)).is_true()


func test_has_tile_of_type_and_resource_false_for_invalid_combo() -> void:
	# PLAINS + GLORY does not exist in the bag
	assert_bool(pool.has_tile_of_type_and_resource(TileManager.TileType.PLAINS, TileManager.ResourceType.GLORY)).is_false()


func test_has_tile_of_type_and_resource_false_when_exhausted() -> void:
	# Draw all 9 HILLS/Resources tiles
	for i in range(9):
		pool.draw_tile_of_type_and_resource(TileManager.TileType.HILLS, TileManager.ResourceType.RESOURCES)
	assert_bool(pool.has_tile_of_type_and_resource(TileManager.TileType.HILLS, TileManager.ResourceType.RESOURCES)).is_false()


# --- draw_tile_of_type_and_resource ---

func test_draw_tile_of_type_and_resource_returns_correct_type() -> void:
	var tile = pool.draw_tile_of_type_and_resource(TileManager.TileType.HILLS, TileManager.ResourceType.FERVOR)
	assert_object(tile).is_not_null()
	assert_int(tile.tile_type).is_equal(TileManager.TileType.HILLS)
	assert_int(tile.resource_type).is_equal(TileManager.ResourceType.FERVOR)


func test_draw_tile_of_type_and_resource_reduces_count() -> void:
	pool.draw_tile_of_type_and_resource(TileManager.TileType.MOUNTAIN, TileManager.ResourceType.GLORY)
	assert_int(pool.get_remaining_count()).is_equal(62)


func test_draw_tile_of_type_and_resource_returns_null_when_exhausted() -> void:
	# Draw all 9 HILLS/Fervor tiles
	for i in range(9):
		pool.draw_tile_of_type_and_resource(TileManager.TileType.HILLS, TileManager.ResourceType.FERVOR)
	var tile = pool.draw_tile_of_type_and_resource(TileManager.TileType.HILLS, TileManager.ResourceType.FERVOR)
	assert_object(tile).is_null()


func test_draw_tile_of_type_and_resource_returns_null_for_invalid_combo() -> void:
	# PLAINS + GLORY does not exist in the bag
	var tile = pool.draw_tile_of_type_and_resource(TileManager.TileType.PLAINS, TileManager.ResourceType.GLORY)
	assert_object(tile).is_null()
