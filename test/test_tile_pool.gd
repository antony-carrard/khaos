extends GdUnitTestSuite


var pool: TilePool


func before_test() -> void:
	pool = auto_free(TilePool.new())
	pool.initialize()


func test_bag_starts_with_64_tiles() -> void:
	assert_int(pool.get_remaining_count()).is_equal(64)


func test_draw_reduces_count() -> void:
	pool.draw_tile()
	assert_int(pool.get_remaining_count()).is_equal(63)


func test_draw_multiple_reduces_count() -> void:
	pool.draw_tiles(3)
	assert_int(pool.get_remaining_count()).is_equal(61)


func test_is_empty_after_drawing_all() -> void:
	for i in range(64):
		pool.draw_tile()
	assert_bool(pool.is_empty()).is_true()


func test_draw_returns_null_when_empty() -> void:
	for i in range(64):
		pool.draw_tile()
	assert_object(pool.draw_tile()).is_null()


func test_drawn_tile_has_valid_type() -> void:
	var tile = pool.draw_tile()
	assert_int(tile.tile_type).is_in([
		TileDefinition.TileType.PLAINS,
		TileDefinition.TileType.HILLS,
		TileDefinition.TileType.MOUNTAIN
	])


func test_drawn_tile_has_non_empty_yields() -> void:
	var tile = pool.draw_tile()
	assert_bool(tile.yields.is_empty()).is_false()


func test_glory_only_on_hills_and_mountains() -> void:
	var all_tiles = pool.draw_tiles(64)
	for tile in all_tiles:
		if tile.yields.has(TileDefinition.ResourceType.GLORY) and tile.yields.size() == 1:
			assert_int(tile.tile_type).is_not_equal(TileDefinition.TileType.PLAINS)


# --- has_tile_of_type ---

func test_has_tile_of_type_true_when_present() -> void:
	assert_bool(pool.has_tile_of_type(TileDefinition.TileType.HILLS)).is_true()


func test_has_tile_of_type_false_when_exhausted() -> void:
	# Draw all 20 HILLS tiles
	for i in range(20):
		pool.draw_tile_of_type(TileDefinition.TileType.HILLS)
	assert_bool(pool.has_tile_of_type(TileDefinition.TileType.HILLS)).is_false()


# --- draw_tile_of_type ---

func test_draw_tile_of_type_returns_correct_type() -> void:
	var tile = pool.draw_tile_of_type(TileDefinition.TileType.HILLS)
	assert_object(tile).is_not_null()
	assert_int(tile.tile_type).is_equal(TileDefinition.TileType.HILLS)


func test_draw_tile_of_type_reduces_count() -> void:
	pool.draw_tile_of_type(TileDefinition.TileType.MOUNTAIN)
	assert_int(pool.get_remaining_count()).is_equal(63)


func test_draw_tile_of_type_returns_null_when_exhausted() -> void:
	# Draw all 12 MOUNTAIN tiles
	for i in range(12):
		pool.draw_tile_of_type(TileDefinition.TileType.MOUNTAIN)
	var tile = pool.draw_tile_of_type(TileDefinition.TileType.MOUNTAIN)
	assert_object(tile).is_null()


# --- has_tile_of_type_and_resource ---

func test_has_tile_of_type_and_resource_true_when_present() -> void:
	assert_bool(pool.has_tile_of_type_and_resource(TileDefinition.TileType.HILLS, TileDefinition.ResourceType.MATERIALS)).is_true()


func test_has_tile_of_type_and_resource_false_for_invalid_combo() -> void:
	# PLAINS + GLORY does not exist in the bag
	assert_bool(pool.has_tile_of_type_and_resource(TileDefinition.TileType.PLAINS, TileDefinition.ResourceType.GLORY)).is_false()


func test_has_tile_of_type_and_resource_false_when_exhausted() -> void:
	# Draw all 8 HILLS tiles that include MATERIALS (6x yield=2, 2x yield=3)
	for i in range(8):
		pool.draw_tile_of_type_and_resource(TileDefinition.TileType.HILLS, TileDefinition.ResourceType.MATERIALS)
	assert_bool(pool.has_tile_of_type_and_resource(TileDefinition.TileType.HILLS, TileDefinition.ResourceType.MATERIALS)).is_false()


# --- draw_tile_of_type_and_resource ---

func test_draw_tile_of_type_and_resource_returns_correct_type() -> void:
	var tile = pool.draw_tile_of_type_and_resource(TileDefinition.TileType.HILLS, TileDefinition.ResourceType.FERVOR)
	assert_object(tile).is_not_null()
	assert_int(tile.tile_type).is_equal(TileDefinition.TileType.HILLS)
	assert_bool(tile.yields.has(TileDefinition.ResourceType.FERVOR)).is_true()


func test_draw_tile_of_type_and_resource_reduces_count() -> void:
	pool.draw_tile_of_type_and_resource(TileDefinition.TileType.MOUNTAIN, TileDefinition.ResourceType.GLORY)
	assert_int(pool.get_remaining_count()).is_equal(63)


func test_draw_tile_of_type_and_resource_returns_null_when_exhausted() -> void:
	# Draw all 8 HILLS tiles that include FERVOR (6x yield=2, 2x yield=3)
	for i in range(8):
		pool.draw_tile_of_type_and_resource(TileDefinition.TileType.HILLS, TileDefinition.ResourceType.FERVOR)
	var tile = pool.draw_tile_of_type_and_resource(TileDefinition.TileType.HILLS, TileDefinition.ResourceType.FERVOR)
	assert_object(tile).is_null()


func test_draw_tile_of_type_and_resource_returns_null_for_invalid_combo() -> void:
	# PLAINS + GLORY does not exist in the bag
	var tile = pool.draw_tile_of_type_and_resource(TileDefinition.TileType.PLAINS, TileDefinition.ResourceType.GLORY)
	assert_object(tile).is_null()
