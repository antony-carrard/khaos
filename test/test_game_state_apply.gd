extends GdUnitTestSuite

# GameState.apply() and the two reconcilers behind it. Unlike test_game_state.gd,
# this suite puts the managers in the scene tree: apply() instantiates real
# hex_tile.tscn/village.tscn nodes, and their @onready references only resolve
# once the node actually enters the tree.

const M := TileDefinition.ResourceType.MATERIALS
const F := TileDefinition.ResourceType.FERVOR
const G := TileDefinition.ResourceType.GLORY

const PLAINS := TileDefinition.TileType.PLAINS
const HILLS := TileDefinition.TileType.HILLS
const MOUNTAIN := TileDefinition.TileType.MOUNTAIN

var alice: Player
var bob: Player
var players: Array[Player]
var tile_manager: TileManager
var village_manager: VillageManager


func before_test() -> void:
	alice = auto_free(Player.new())
	alice.initialize("Alice", Color.BLUE)
	alice.initialize_game_start(AugiaGod.new(), false)

	bob = auto_free(Player.new())
	bob.initialize("Bob", Color.RED)
	bob.initialize_game_start(RakunGod.new(), false)

	players = [alice, bob] as Array[Player]

	tile_manager = TileManager.new()
	tile_manager.max_stack_height = 3
	tile_manager.initialize(preload("res://hex_tile.tscn"))
	village_manager = VillageManager.new()
	# add_child() in a GdUnitTestSuite does not register for auto-cleanup, so
	# after_test() frees these explicitly.
	add_child(tile_manager)
	add_child(village_manager)
	tile_manager.village_manager = village_manager
	village_manager.tile_manager = tile_manager


func after_test() -> void:
	village_manager.queue_free()
	tile_manager.queue_free()


func _tile(q: int, r: int, height: int, tile_type: int,
		tile_yields: Dictionary, cost: int = 2) -> Dictionary:
	return {
		"q": q, "r": r, "height": height,
		"tile_type": tile_type,
		"yields": tile_yields,
		"village_building_cost": cost,
	}


func _village(q: int, r: int, owner_index: int, doubled: bool = false) -> Dictionary:
	return {"q": q, "r": r, "owner_index": owner_index, "is_doubled": doubled}


# --- Tile reconciliation ---

func test_apply_creates_tiles_on_an_empty_board() -> void:
	tile_manager.apply([
		_tile(0, 0, 0, PLAINS, {M: 1}),
		_tile(0, 0, 1, HILLS, {G: 2}, 4),
		_tile(1, 0, 0, PLAINS, {F: 1}),
	])

	assert_int(tile_manager.placed_tiles.size()).is_equal(3)
	assert_int(tile_manager.get_top_height(0, 0)).is_equal(1)
	assert_int(tile_manager.get_tile_at(1, 0).tile_type).is_equal(PLAINS)
	assert_dict(tile_manager.get_tile_at(0, 0).yields).is_equal({G: 2})


func test_apply_removes_tiles_missing_from_the_snapshot() -> void:
	tile_manager.apply([_tile(0, 0, 0, PLAINS, {M: 1}), _tile(1, 0, 0, PLAINS, {M: 1})])
	tile_manager.apply([_tile(0, 0, 0, PLAINS, {M: 1})])

	assert_int(tile_manager.placed_tiles.size()).is_equal(1)
	assert_bool(tile_manager.has_tile_at(1, 0)).is_false()


func test_apply_keeps_the_same_node_for_an_unchanged_tile() -> void:
	# The whole point of reconciling: an untouched tile must not be recreated, or
	# every applied snapshot would restart its animations and drop its highlight.
	tile_manager.apply([_tile(0, 0, 0, PLAINS, {M: 1})])
	var original := tile_manager.get_tile_at(0, 0)

	tile_manager.apply([_tile(0, 0, 0, PLAINS, {M: 1}), _tile(1, 0, 0, PLAINS, {F: 1})])

	assert_object(tile_manager.get_tile_at(0, 0)).is_same(original)


func test_apply_updates_a_changed_tile_in_place() -> void:
	tile_manager.apply([_tile(0, 0, 0, PLAINS, {M: 1})])
	var original := tile_manager.get_tile_at(0, 0)

	tile_manager.apply([_tile(0, 0, 0, PLAINS, {F: 3})])

	assert_object(tile_manager.get_tile_at(0, 0)).is_same(original)
	assert_dict(tile_manager.get_tile_at(0, 0).yields).is_equal({F: 3})


func test_apply_restores_a_stack_hidden_under_a_village() -> void:
	# is_valid_placement() would reject rebuilding a stack under a village, but a
	# snapshot describes a state the game already reached legally.
	tile_manager.apply([
		_tile(0, 0, 0, PLAINS, {M: 1}),
		_tile(0, 0, 1, HILLS, {M: 2}, 4),
	])
	village_manager.apply([_village(0, 0, 0)], players)
	tile_manager.apply([
		_tile(0, 0, 0, PLAINS, {M: 1}),
		_tile(0, 0, 1, HILLS, {M: 2}, 4),
		_tile(0, 0, 2, MOUNTAIN, {G: 3}, 6),
	])

	assert_int(tile_manager.get_top_height(0, 0)).is_equal(2)


# --- Village reconciliation ---

func test_apply_creates_villages_with_the_right_owner() -> void:
	tile_manager.apply([_tile(0, 0, 0, PLAINS, {M: 1}), _tile(1, 0, 0, PLAINS, {M: 1})])
	village_manager.apply([_village(0, 0, 0), _village(1, 0, 1)], players)

	assert_int(village_manager.placed_villages.size()).is_equal(2)
	assert_object(village_manager.get_village_at(0, 0).player_owner).is_same(alice)
	assert_object(village_manager.get_village_at(1, 0).player_owner).is_same(bob)


func test_apply_rebuilds_the_per_player_index() -> void:
	tile_manager.apply([_tile(0, 0, 0, PLAINS, {M: 1}), _tile(1, 0, 0, PLAINS, {M: 1})])
	village_manager.apply([_village(0, 0, 0), _village(1, 0, 0)], players)
	village_manager.apply([_village(1, 0, 0)], players)

	assert_int(village_manager.get_villages_for_player(alice).size()).is_equal(1)
	assert_int(village_manager.get_villages_for_player(bob).size()).is_equal(0)


func test_apply_keeps_the_same_node_for_an_unchanged_village() -> void:
	tile_manager.apply([_tile(0, 0, 0, PLAINS, {M: 1})])
	village_manager.apply([_village(0, 0, 0)], players)
	var original := village_manager.get_village_at(0, 0)

	village_manager.apply([_village(0, 0, 0)], players)

	assert_object(village_manager.get_village_at(0, 0)).is_same(original)


func test_apply_recreates_a_village_whose_owner_changed() -> void:
	# _apply_color() lerps towards the player colour from whatever material it
	# finds, so repainting in place would compound the previous owner's colour.
	tile_manager.apply([_tile(0, 0, 0, PLAINS, {M: 1})])
	village_manager.apply([_village(0, 0, 0)], players)
	var original := village_manager.get_village_at(0, 0)

	village_manager.apply([_village(0, 0, 1)], players)

	assert_object(village_manager.get_village_at(0, 0)).is_not_same(original)
	assert_object(village_manager.get_village_at(0, 0).player_owner).is_same(bob)


func test_apply_restores_doubled_state() -> void:
	tile_manager.apply([_tile(0, 0, 0, PLAINS, {M: 1})])
	village_manager.apply([_village(0, 0, 0, true)], players)

	assert_bool(village_manager.get_village_at(0, 0).is_doubled).is_true()
	assert_int(village_manager.get_village_at(0, 0).multiplier()).is_equal(2)


func test_apply_settles_a_village_onto_a_grown_stack() -> void:
	# A village whose own entry didn't change still moves when the stack under it
	# does — the reason tiles are applied before villages.
	tile_manager.apply([_tile(0, 0, 0, PLAINS, {M: 1})])
	village_manager.apply([_village(0, 0, 0)], players)
	var ground_y := village_manager.get_village_at(0, 0).global_position.y

	tile_manager.apply([_tile(0, 0, 0, PLAINS, {M: 1}), _tile(0, 0, 1, HILLS, {M: 2}, 4)])
	village_manager.apply([_village(0, 0, 0)], players)

	assert_float(village_manager.get_village_at(0, 0).global_position.y).is_greater(ground_y)


# --- GameState.apply end to end ---

const BoardManagerScript := preload("res://managers/board_manager.gd")


## A board_manager driven by its script alone, without _ready()'s UI/scene wiring.
## Enough for GameState.apply(), which is pure data — board_manager.restore_snapshot()
## is the one that additionally rebinds the UI.
func _make_board() -> Node3D:
	var tile_pool: TilePool = auto_free(TilePool.new())
	tile_pool.initialize(4242)

	var board: Node3D = auto_free(BoardManagerScript.new())
	board.tile_manager = tile_manager
	board.village_manager = village_manager
	board.tile_pool = tile_pool
	board.players = players
	board.current_player_index = 0
	board.current_player = alice
	return board


func test_capture_and_apply_are_exact_inverses() -> void:
	# The load-bearing test for the whole feature: take a snapshot, wreck the
	# game, restore it, and require the new snapshot to be byte-identical.
	var board := _make_board()
	tile_manager.apply([
		_tile(0, 0, 0, PLAINS, {M: 1}),
		_tile(0, 0, 1, HILLS, {G: 2}, 4),
		_tile(1, 0, 0, PLAINS, {F: 1}),
	])
	village_manager.apply([_village(0, 0, 0, true), _village(1, 0, 1)], players)
	alice.materials = 6
	alice.add_to_hand(TileDefinition.new(MOUNTAIN, {M: 3, G: 1}, 6))
	bob.fervor = 2
	board.tile_pool.draw_tiles(7)
	board.villages_built_this_turn[Vector2i(1, 0)] = true

	var original := GameState.capture(board)

	# Wreck it: different board, different owners, different resources, different turn.
	tile_manager.apply([_tile(5, 5, 0, PLAINS, {M: 2})])
	village_manager.apply([_village(5, 5, 1)], players)
	alice.materials = 0
	alice.empty_hand()
	bob.fervor = 99
	board.tile_pool.draw_tiles(3)
	board.current_player_index = 1
	board.current_player = bob
	board.final_round_triggered = true
	board.triggering_player = bob
	board.villages_built_this_turn.clear()

	assert_bool(GameState.apply(board, original)).is_true()
	assert_dict(GameState.capture(board)).is_equal(original)


func test_apply_restores_players_and_turn() -> void:
	var board := _make_board()
	alice.materials = 5
	alice.glory = 3
	var snapshot := GameState.capture(board)

	alice.materials = 0
	alice.glory = 0
	board.current_player_index = 1
	board.current_player = bob

	GameState.apply(board, snapshot)

	assert_int(alice.materials).is_equal(5)
	assert_int(alice.glory).is_equal(3)
	assert_int(board.current_player_index).is_equal(0)
	assert_object(board.current_player).is_same(alice)


func test_apply_refuses_a_snapshot_with_a_different_player_count() -> void:
	# Refusing beats half-applying: a partially restored game is much harder to
	# diagnose than a load that plainly didn't happen.
	var board := _make_board()
	var snapshot := GameState.capture(board)
	snapshot["players"] = [snapshot["players"][0]]

	assert_bool(GameState.apply(board, snapshot)).is_false()
	assert_int(board.players.size()).is_equal(2)


func test_apply_refuses_an_empty_snapshot() -> void:
	assert_bool(GameState.apply(_make_board(), {})).is_false()


func test_a_saved_game_survives_a_file_round_trip_and_restores() -> void:
	var board := _make_board()
	var path := "user://test_apply_%d.dat" % Time.get_ticks_usec()
	tile_manager.apply([_tile(0, 0, 0, PLAINS, {M: 1}), _tile(0, 0, 1, HILLS, {G: 2}, 4)])
	village_manager.apply([_village(0, 0, 1, true)], players)
	alice.materials = 8
	board.tile_pool.draw_tiles(5)

	var original := GameState.capture(board)
	assert_bool(GameState.save_to_file(board, path)).is_true()

	tile_manager.apply([])
	village_manager.apply([], players)
	alice.materials = 0

	assert_bool(GameState.apply(board, GameState.load_from_file(path))).is_true()
	assert_dict(GameState.capture(board)).is_equal(original)
	assert_int(alice.materials).is_equal(8)
	assert_object(village_manager.get_village_at(0, 0).player_owner).is_same(bob)
	assert_bool(village_manager.get_village_at(0, 0).is_doubled).is_true()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_restore_is_refused_before_the_game_has_started() -> void:
	# placement_controller is live from early in board_manager._ready(), so a load
	# can be triggered while _ready() is still suspended on god selection. The rest
	# of _ready() would then overwrite whatever was restored — a free harvest and a
	# redeal on top of the loaded state. Step 4 (rejoin) applies a snapshot during
	# startup, so this precondition has to hold rather than be avoided by the UI.
	var board := _make_board()
	var snapshot := GameState.capture(board)

	assert_bool(board.game_started).is_false()
	assert_bool(board.restore_snapshot(snapshot)).is_false()


func test_apply_brings_up_players_that_skipped_god_selection() -> void:
	# A rejoining client skips god selection, so its players reach their first
	# snapshot with only a name and colour — no god, no hand capacity. The
	# snapshot alone has to make them whole.
	var source := _make_board()
	alice.add_to_hand(TileDefinition.new(HILLS, {G: 2}, 4))
	bob.fervor = 3
	var snapshot := GameState.capture(source)

	var fresh_alice: Player = auto_free(Player.new())
	fresh_alice.initialize("Alice", Color.BLUE)
	var fresh_bob: Player = auto_free(Player.new())
	fresh_bob.initialize("Bob", Color.RED)
	var rejoiner: Node3D = auto_free(BoardManagerScript.new())
	rejoiner.tile_manager = tile_manager
	rejoiner.village_manager = village_manager
	rejoiner.tile_pool = auto_free(TilePool.new())
	rejoiner.players = [fresh_alice, fresh_bob] as Array[Player]
	assert_object(fresh_alice.god).is_null()

	assert_bool(GameState.apply(rejoiner, snapshot)).is_true()
	assert_object(fresh_alice.god).is_instanceof(AugiaGod)
	assert_object(fresh_bob.god).is_instanceof(RakunGod)
	assert_int(fresh_alice.base_hand_size).is_equal(alice.base_hand_size)
	assert_dict(GameState.capture(rejoiner)).is_equal(snapshot)
