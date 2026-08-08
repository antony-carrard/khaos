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


# --- return_tile ---

func test_return_tile_increases_count() -> void:
	var tile = pool.draw_tile()
	pool.return_tile(tile)
	assert_int(pool.get_remaining_count()).is_equal(64)


func test_return_tile_can_be_drawn_again() -> void:
	for i in range(63):
		pool.draw_tile()
	var last_in_bag = pool.draw_tile()
	assert_bool(pool.is_empty()).is_true()

	pool.return_tile(last_in_bag)
	assert_bool(pool.is_empty()).is_false()
	assert_object(pool.draw_tile()).is_same(last_in_bag)
