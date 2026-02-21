extends GdUnitTestSuite


var victory_manager: VictoryManager
var tile_manager: TileManager
var village_manager: VillageManager
var player: Player


func before_test() -> void:
	# Nodes must be added to the scene tree so physics bodies (StaticBody3D)
	# can be properly queue_free'd. GdUnit4's add_child override registers
	# them for auto-cleanup at the end of each test.
	victory_manager = VictoryManager.new()
	add_child(victory_manager)

	tile_manager = TileManager.new()
	tile_manager.max_stack_height = 3
	add_child(tile_manager)

	village_manager = VillageManager.new()
	village_manager.tile_manager = tile_manager
	add_child(village_manager)

	player = Player.new()
	add_child(player)
	player.initialize("Test Player", 0, 0)


# --- Helpers ---

func _place_tile(q: int, r: int, tile_type: int, resource_type: int = TileManager.ResourceType.RESOURCES, yield_val: int = 1) -> HexTile:
	var height = TileManager.TILE_TYPE_TO_HEIGHT[tile_type]
	var tile = HexTile.new()
	tile.tile_type = tile_type
	tile.resource_type = resource_type
	tile.yield_value = yield_val
	tile_manager.add_child(tile)  # Parent under tile_manager so it's freed with it
	tile_manager.placed_tiles[Vector3i(q, r, height)] = tile
	return tile


func _place_village(q: int, r: int) -> Village:
	var village = Village.new()
	village.q = q
	village.r = r
	village.player_owner = player
	village_manager.add_child(village)  # Parent under village_manager
	village_manager.placed_villages[Vector2i(q, r)] = village
	return village


# --- Village point tests ---

func test_village_on_plains_scores_1() -> void:
	_place_tile(0, 0, TileManager.TileType.PLAINS)
	_place_village(0, 0)
	var score = victory_manager.calculate_player_score(player, village_manager, tile_manager)
	assert_int(score.village_points).is_equal(1)


func test_village_on_hills_scores_2() -> void:
	_place_tile(0, 0, TileManager.TileType.PLAINS)
	_place_tile(0, 0, TileManager.TileType.HILLS)
	_place_village(0, 0)
	var score = victory_manager.calculate_player_score(player, village_manager, tile_manager)
	assert_int(score.village_points).is_equal(2)


func test_village_on_mountain_scores_3() -> void:
	_place_tile(0, 0, TileManager.TileType.PLAINS)
	_place_tile(0, 0, TileManager.TileType.HILLS)
	_place_tile(0, 0, TileManager.TileType.MOUNTAIN)
	_place_village(0, 0)
	var score = victory_manager.calculate_player_score(player, village_manager, tile_manager)
	assert_int(score.village_points).is_equal(3)


func test_multiple_villages_sum_correctly() -> void:
	_place_tile(0, 0, TileManager.TileType.PLAINS)
	_place_tile(1, 0, TileManager.TileType.PLAINS)
	_place_tile(1, 0, TileManager.TileType.HILLS)
	_place_village(0, 0)  # 1 pt
	_place_village(1, 0)  # 2 pts
	var score = victory_manager.calculate_player_score(player, village_manager, tile_manager)
	assert_int(score.village_points).is_equal(3)


func test_no_villages_scores_0() -> void:
	var score = victory_manager.calculate_player_score(player, village_manager, tile_manager)
	assert_int(score.village_points).is_equal(0)
	assert_int(score.total).is_equal(0)


# --- Resource/fervor pair tests ---

func test_resources_score_floor_division() -> void:
	player.add_resources(7)  # floor(7/2) = 3
	var score = victory_manager.calculate_player_score(player, village_manager, tile_manager)
	assert_int(score.resource_points).is_equal(3)


func test_odd_resources_floor_rounds_down() -> void:
	player.add_resources(5)  # floor(5/2) = 2
	var score = victory_manager.calculate_player_score(player, village_manager, tile_manager)
	assert_int(score.resource_points).is_equal(2)


# --- Territory tests ---

func test_two_adjacent_villages_score_territory() -> void:
	_place_tile(0, 0, TileManager.TileType.PLAINS)
	_place_tile(1, 0, TileManager.TileType.PLAINS)
	_place_village(0, 0)
	_place_village(1, 0)
	var score = victory_manager.calculate_player_score(player, village_manager, tile_manager)
	# SIMPLE formula: group of 2 = 2 territory points
	assert_int(score.territory_points).is_equal(2)


func test_isolated_village_scores_1_territory() -> void:
	_place_tile(0, 0, TileManager.TileType.PLAINS)
	_place_village(0, 0)
	var score = victory_manager.calculate_player_score(player, village_manager, tile_manager)
	assert_int(score.territory_points).is_equal(1)


func test_total_is_sum_of_all_categories() -> void:
	_place_tile(0, 0, TileManager.TileType.HILLS)
	_place_village(0, 0)  # 2 village pts, 1 territory pt
	player.add_resources(4)  # 2 resource pts
	var score = victory_manager.calculate_player_score(player, village_manager, tile_manager)
	assert_int(score.total).is_equal(score.village_points + score.resource_points + score.fervor_points + score.glory_points + score.territory_points)
