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
	player.initialize("Test Player", Color.WHITE)


func test_glory_scores_one_to_one() -> void:
	player.glory = 5
	var score = victory_manager.calculate_player_score(player, village_manager)
	assert_int(score.glory_points).is_equal(5)


func test_no_villages_scores_0() -> void:
	var score = victory_manager.calculate_player_score(player, village_manager)
	assert_int(score.territory_points).is_equal(0)
	assert_int(score.total).is_equal(0)


func test_total_equals_sum_of_categories() -> void:
	player.glory = 1
	var score = victory_manager.calculate_player_score(player, village_manager)
	assert_int(score.total).is_equal(score.glory_points + score.territory_points)


func _inject_village(q: int, r: int, owner: Player) -> Village:
	var village := Village.new()
	village.set_grid_position(q, r)
	village.set_player_owner(owner)
	village_manager.placed_villages[Vector2i(q, r)] = village
	if not village_manager.player_villages.has(owner):
		village_manager.player_villages[owner] = [] as Array[Village]
	village_manager.player_villages[owner].append(village)
	return village


# A doubled village (Bicéphallès major) counts as 2 toward its group's size
# for territory scoring — a single doubled village scores like a 2-village
# group (1 + 2 = 3), not a 1-village group (1).
func test_doubled_village_counts_double_for_territory() -> void:
	var village := _inject_village(0, 0, player)
	village.is_doubled = true
	var score = victory_manager.calculate_player_score(player, village_manager)
	assert_int(score.territory_points).is_equal(3)
