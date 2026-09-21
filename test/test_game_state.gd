extends GdUnitTestSuite

# Serialization of the whole game — the to_dict()/from_dict() pairs on
# TileDefinition, TilePool, Player and God, the capture-only snapshots of
# TileManager/VillageManager, and GameState.capture() composing all of it.
#
# board_manager.gd has no class_name and its _ready() wires up UI/scene nodes we
# don't want here, so it's instantiated via its script and driven without ever
# entering the scene tree — same pattern as test_board_manager_demolition.gd.

const BoardManagerScript := preload("res://managers/board_manager.gd")

const M := TileDefinition.ResourceType.MATERIALS
const F := TileDefinition.ResourceType.FERVOR
const G := TileDefinition.ResourceType.GLORY

var alice: Player
var bob: Player
var board: Node3D
var tile_manager: TileManager
var village_manager: VillageManager
var tile_pool: TilePool
var _bare_tiles: Array[HexTile] = []
var _bare_villages: Array[Village] = []
var _save_path: String


func before_test() -> void:
	alice = auto_free(Player.new())
	alice.initialize("Alice", Color.BLUE)
	alice.initialize_game_start(AugiaGod.new(), false)

	bob = auto_free(Player.new())
	bob.initialize("Bob", Color.RED)
	bob.initialize_game_start(RakunGod.new(), false)

	tile_manager = auto_free(TileManager.new())
	tile_manager.max_stack_height = 3
	village_manager = auto_free(VillageManager.new())
	village_manager.tile_manager = tile_manager
	tile_pool = auto_free(TilePool.new())
	tile_pool.initialize(12345)

	var typed_players: Array[Player] = [alice, bob]

	board = auto_free(BoardManagerScript.new())
	board.tile_manager = tile_manager
	board.village_manager = village_manager
	board.tile_pool = tile_pool
	board.players = typed_players
	board.current_player_index = 0
	board.current_player = alice

	_save_path = "user://test_game_state_%d.dat" % Time.get_ticks_usec()


func after_test() -> void:
	# HexTile is a StaticBody3D; freeing one directly on GdUnit's worker thread aborts.
	for tile in _bare_tiles:
		tile.call_deferred("free")
	_bare_tiles.clear()
	for village in _bare_villages:
		village.call_deferred("free")
	_bare_villages.clear()
	if FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path))


func _inject_tile(q: int, r: int, height: int, tile_type: int,
		tile_yields: Dictionary, cost: int) -> HexTile:
	var tile := HexTile.new()
	tile.q = q
	tile.r = r
	tile.height_level = height
	tile.tile_type = tile_type
	tile.yields = tile_yields
	tile.village_building_cost = cost
	tile_manager.placed_tiles[Vector3i(q, r, height)] = tile
	_bare_tiles.append(tile)
	return tile


func _inject_village(q: int, r: int, village_owner: Player) -> Village:
	var village := Village.new()
	village.set_grid_position(q, r)
	village.set_player_owner(village_owner)
	village_manager.placed_villages[Vector2i(q, r)] = village
	if not village_manager.player_villages.has(village_owner):
		village_manager.player_villages[village_owner] = [] as Array[Village]
	village_manager.player_villages[village_owner].append(village)
	_bare_villages.append(village)
	return village


# --- TileDefinition ---

func test_tile_definition_round_trips() -> void:
	var original := TileDefinition.new(TileDefinition.TileType.MOUNTAIN, {M: 2, F: 2, G: 2}, 6)
	var restored := TileDefinition.from_dict(original.to_dict())
	assert_int(restored.tile_type).is_equal(TileDefinition.TileType.MOUNTAIN)
	assert_int(restored.village_building_cost).is_equal(6)
	assert_dict(restored.yields).is_equal({M: 2, F: 2, G: 2})


func test_tile_definition_yield_keys_stay_integers() -> void:
	# The reason the snapshot is a Variant dict rather than JSON: yields are keyed
	# by ResourceType, and stringified keys would break every lookup after a load.
	var restored := TileDefinition.from_dict(
		TileDefinition.new(TileDefinition.TileType.PLAINS, {F: 1}, 2).to_dict())
	assert_int(typeof(restored.yields.keys()[0])).is_equal(TYPE_INT)


func test_tile_definition_snapshot_does_not_alias_yields() -> void:
	var original := TileDefinition.new(TileDefinition.TileType.PLAINS, {M: 1}, 2)
	var snapshot := original.to_dict()
	original.yields[M] = 99
	assert_int(TileDefinition.from_dict(snapshot).yields[M]).is_equal(1)


# --- God ---

func test_every_god_round_trips_by_id() -> void:
	for god in God.create_all():
		var restored := God.from_id(god.get_id())
		assert_object(restored).is_not_null()
		assert_str(restored.god_name).is_equal(god.god_name)


func test_god_id_is_the_class_name() -> void:
	assert_str(LeBatisseurGod.new().get_id()).is_equal("LeBatisseurGod")


func test_unknown_god_id_returns_null() -> void:
	assert_object(God.from_id("NoSuchGod")).is_null()


# --- TilePool ---

func test_tile_pool_round_trips_bag_contents() -> void:
	tile_pool.draw_tiles(5)
	var snapshot := tile_pool.to_dict()

	var restored: TilePool = auto_free(TilePool.new())
	restored.from_dict(snapshot)

	assert_int(restored.get_remaining_count()).is_equal(59)
	assert_int(restored.removed_tiles.size()).is_equal(5)
	for i in range(tile_pool.tile_bag.size()):
		assert_int(restored.tile_bag[i].tile_type).is_equal(tile_pool.tile_bag[i].tile_type)
		assert_dict(restored.tile_bag[i].yields).is_equal(tile_pool.tile_bag[i].yields)


func test_tile_pool_restores_rng_position() -> void:
	# return_tile() consumes the bag's RNG, so a restore that reset the stream
	# would silently fork the bag order from that point on.
	tile_pool.draw_tiles(10)
	var restored: TilePool = auto_free(TilePool.new())
	restored.from_dict(tile_pool.to_dict())

	var returned := tile_pool.removed_tiles[0]
	tile_pool.return_tile(returned)
	restored.return_tile(restored.removed_tiles[0])

	for i in range(tile_pool.tile_bag.size()):
		assert_int(restored.tile_bag[i].tile_type).is_equal(tile_pool.tile_bag[i].tile_type)


# --- Player ---

func test_player_round_trips() -> void:
	alice.materials = 7
	alice.fervor = 3
	alice.glory = 5
	alice.actions_remaining = 2
	alice.add_to_hand(TileDefinition.new(TileDefinition.TileType.HILLS, {G: 2}, 4))

	var restored: Player = auto_free(Player.new())
	restored.from_dict(alice.to_dict())

	assert_str(restored.player_name).is_equal("Alice")
	assert_int(restored.materials).is_equal(7)
	assert_int(restored.fervor).is_equal(3)
	assert_int(restored.glory).is_equal(5)
	assert_int(restored.actions_remaining).is_equal(2)
	assert_int(restored.total_actions).is_equal(alice.total_actions)
	assert_str(restored.god.god_name).is_equal("Augia")


func test_player_hand_keeps_empty_slots_in_place() -> void:
	# Slot positions are what the hand UI renders, so a compacting restore would
	# shuffle the player's cards under them.
	alice.hand[2] = TileDefinition.new(TileDefinition.TileType.PLAINS, {M: 1}, 2)

	var restored: Player = auto_free(Player.new())
	restored.from_dict(alice.to_dict())

	assert_int(restored.hand.size()).is_equal(alice.base_hand_size)
	assert_object(restored.hand[0]).is_null()
	assert_object(restored.hand[1]).is_null()
	assert_object(restored.hand[2]).is_not_null()


func test_player_restores_a_grown_hand() -> void:
	# grow_hand() pushes capacity past the god-granted size (Rakun's stolen tile);
	# restoring from base_hand_size instead of the snapshot would drop the tile.
	alice.grow_hand()
	alice.hand[alice.hand.size() - 1] = TileDefinition.new(
		TileDefinition.TileType.MOUNTAIN, {G: 3}, 6)

	var restored: Player = auto_free(Player.new())
	restored.from_dict(alice.to_dict())

	assert_int(restored.hand.size()).is_equal(alice.base_hand_size + 1)
	assert_int(restored.base_hand_size).is_equal(alice.base_hand_size)
	assert_object(restored.hand[restored.hand.size() - 1]).is_not_null()


# --- TileManager ---

func test_tile_manager_captures_stacked_tiles_in_canonical_order() -> void:
	_inject_tile(2, 0, 0, TileDefinition.TileType.PLAINS, {M: 1}, 2)
	_inject_tile(0, 0, 0, TileDefinition.TileType.PLAINS, {F: 1}, 2)
	_inject_tile(0, 0, 1, TileDefinition.TileType.HILLS, {M: 2}, 4)

	var tiles := tile_manager.to_dict()
	assert_int(tiles.size()).is_equal(3)
	assert_array([tiles[0]["q"], tiles[0]["r"], tiles[0]["height"]]).is_equal([0, 0, 0])
	assert_array([tiles[1]["q"], tiles[1]["r"], tiles[1]["height"]]).is_equal([0, 0, 1])
	assert_array([tiles[2]["q"], tiles[2]["r"], tiles[2]["height"]]).is_equal([2, 0, 0])


func test_tile_manager_captures_per_tile_yields_not_just_type() -> void:
	# Two plains tiles with different yields — the bag holds several variants of
	# each type, so type alone can't reconstruct a tile.
	_inject_tile(0, 0, 0, TileDefinition.TileType.PLAINS, {M: 2}, 2)
	_inject_tile(1, 0, 0, TileDefinition.TileType.PLAINS, {F: 1}, 2)

	var tiles := tile_manager.to_dict()
	assert_dict(tiles[0]["yields"]).is_equal({M: 2})
	assert_dict(tiles[1]["yields"]).is_equal({F: 1})


# --- VillageManager ---

func test_village_manager_captures_owner_as_index() -> void:
	_inject_tile(0, 0, 0, TileDefinition.TileType.PLAINS, {M: 1}, 2)
	_inject_village(0, 0, bob)

	var villages := village_manager.to_dict(board.players)
	assert_int(villages.size()).is_equal(1)
	assert_int(villages[0]["owner_index"]).is_equal(1)
	assert_bool(villages[0]["is_doubled"]).is_false()


func test_village_manager_captures_doubled_state() -> void:
	_inject_tile(0, 0, 0, TileDefinition.TileType.PLAINS, {M: 1}, 2)
	_inject_village(0, 0, alice).set_doubled(true)

	assert_bool(village_manager.to_dict(board.players)[0]["is_doubled"]).is_true()


# --- GameState ---

func test_capture_includes_turn_and_final_round_state() -> void:
	board.current_player_index = 1
	board.final_round_triggered = true
	board.triggering_player = bob
	board.villages_built_this_turn[Vector2i(1, 2)] = true
	board.villages_demolished_this_turn[Vector2i(3, 4)] = true

	var snapshot := GameState.capture(board)
	assert_int(snapshot["version"]).is_equal(GameState.FORMAT_VERSION)
	assert_int(snapshot["current_player_index"]).is_equal(1)
	assert_bool(snapshot["final_round_triggered"]).is_true()
	assert_int(snapshot["triggering_player_index"]).is_equal(1)
	assert_dict(snapshot["villages_built_this_turn"]).is_equal({Vector2i(1, 2): true})
	assert_dict(snapshot["villages_demolished_this_turn"]).is_equal({Vector2i(3, 4): true})


func test_capture_reports_no_triggering_player_as_minus_one() -> void:
	assert_int(GameState.capture(board)["triggering_player_index"]).is_equal(-1)


func test_capture_covers_every_player() -> void:
	var snapshot := GameState.capture(board)
	assert_int(snapshot["players"].size()).is_equal(2)
	assert_str(snapshot["players"][0]["player_name"]).is_equal("Alice")
	assert_str(snapshot["players"][1]["god_id"]).is_equal("RakunGod")


func test_snapshot_survives_a_file_round_trip() -> void:
	_inject_tile(0, 0, 0, TileDefinition.TileType.PLAINS, {M: 2}, 2)
	_inject_tile(0, 0, 1, TileDefinition.TileType.HILLS, {G: 2}, 4)
	_inject_village(0, 0, alice).set_doubled(true)
	alice.materials = 4
	tile_pool.draw_tiles(6)

	assert_bool(GameState.save_to_file(board, _save_path)).is_true()
	var loaded := GameState.load_from_file(_save_path)

	assert_dict(loaded).is_equal(GameState.capture(board))
	# Spot-check the pieces most likely to be mangled by an encoding change.
	assert_dict(loaded["tiles"][1]["yields"]).is_equal({G: 2})
	assert_bool(loaded["villages"][0]["is_doubled"]).is_true()
	assert_int(loaded["tile_pool"]["tile_bag"].size()).is_equal(58)


func test_loading_a_missing_file_returns_empty() -> void:
	assert_dict(GameState.load_from_file("user://definitely_not_here.dat")).is_empty()


func test_loading_a_foreign_format_version_is_refused() -> void:
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	file.store_var({"version": GameState.FORMAT_VERSION + 1})
	file.close()
	assert_dict(GameState.load_from_file(_save_path)).is_empty()


# --- Wire size ---

# Step 3 of the state-replication plan broadcasts a full snapshot after every
# action. Sized against a deliberately impossible upper bound: all 64 bag tiles
# on the board AND still in the bag, a village on every hex, four players.
# If this ceiling ever trips, it's the signal to switch to state deltas.
func test_full_snapshot_stays_small_enough_to_broadcast_per_action() -> void:
	var carol: Player = auto_free(Player.new())
	carol.initialize("Carol", Color.GREEN)
	carol.initialize_game_start(LeBatisseurGod.new(), false)
	var dave: Player = auto_free(Player.new())
	dave.initialize("Dave", Color.YELLOW)
	dave.initialize_game_start(BicephallesGod.new(), false)
	var four: Array[Player] = [alice, bob, carol, dave]
	board.players = four
	for player in four:
		player.hand = tile_pool.draw_tiles(player.base_hand_size)
		player.materials = 12
		player.fervor = 9
		player.glory = 31

	# 64 tiles over 22 hexes: 21 full stacks of 3 + one single. Every hex gets a village.
	var placed := 0
	var hex := 0
	while placed < 64:
		var q := hex % 6
		var r := hex / 6
		var stack := mini(3, 64 - placed)
		for h in stack:
			var tile_type: int = [TileDefinition.TileType.PLAINS,
				TileDefinition.TileType.HILLS, TileDefinition.TileType.MOUNTAIN][h]
			_inject_tile(q, r, h, tile_type, {M: 2, F: 1, G: 3}, 2 * (h + 1))
		_inject_village(q, r, four[hex % 4])
		board.villages_built_this_turn[Vector2i(q, r)] = true
		placed += stack
		hex += 1

	var snapshot := GameState.capture(board)
	var size := var_to_bytes(snapshot).size()
	print("Full snapshot: %d bytes (%d tiles, %d villages, %d players)" % [
		size, snapshot["tiles"].size(), snapshot["villages"].size(), snapshot["players"].size()])

	assert_int(snapshot["tiles"].size()).is_equal(64)
	assert_int(snapshot["villages"].size()).is_equal(22)
	assert_int(size).is_less(32 * 1024)
