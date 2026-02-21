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
