extends GdUnitTestSuite

# NOTE: Tests requiring HexTile (StaticBody3D) are excluded.
# HexTile creates physics bodies that cannot be safely freed from GdUnit4's
# worker thread — PhysicsServer3D::free(body_rid) is not thread-safe → SIGABRT.
# Village-height scoring and territory tests require tiles; see REFACTORING_PLAN
# for the architectural fix (separate tile data from the physics node).

var victory_manager: VictoryManager
var tile_manager: TileManager
var village_manager: VillageManager
var player: Player


func before_test() -> void:
	victory_manager = auto_free(VictoryManager.new())
	tile_manager = auto_free(TileManager.new())
	tile_manager.max_stack_height = 3
	village_manager = auto_free(VillageManager.new())
	village_manager.tile_manager = tile_manager
	player = auto_free(Player.new())
	player.initialize("Test Player", 0, 0)


# --- Resource/fervor pair tests ---

func test_resources_score_floor_division() -> void:
	player.add_resources(7)  # floor(7/2) = 3
	var score = victory_manager.calculate_player_score(player, village_manager, tile_manager)
	assert_int(score.resource_points).is_equal(3)


func test_odd_resources_floor_rounds_down() -> void:
	player.add_resources(5)  # floor(5/2) = 2
	var score = victory_manager.calculate_player_score(player, village_manager, tile_manager)
	assert_int(score.resource_points).is_equal(2)


func test_fervor_score_floor_division() -> void:
	player.add_fervor(6)  # floor(6/2) = 3
	var score = victory_manager.calculate_player_score(player, village_manager, tile_manager)
	assert_int(score.fervor_points).is_equal(3)


func test_glory_scores_one_to_one() -> void:
	player.add_glory(5)
	var score = victory_manager.calculate_player_score(player, village_manager, tile_manager)
	assert_int(score.glory_points).is_equal(5)


func test_no_villages_scores_0() -> void:
	var score = victory_manager.calculate_player_score(player, village_manager, tile_manager)
	assert_int(score.village_points).is_equal(0)
	assert_int(score.territory_points).is_equal(0)
	assert_int(score.total).is_equal(0)


func test_total_equals_sum_of_categories() -> void:
	player.add_resources(4)
	player.add_fervor(2)
	player.add_glory(1)
	var score = victory_manager.calculate_player_score(player, village_manager, tile_manager)
	assert_int(score.total).is_equal(
		score.village_points + score.resource_points + score.fervor_points +
		score.glory_points + score.territory_points
	)
