extends GdUnitTestSuite

# Player is a pure-data holder — validated setters + hand array ops.
# Player extends Node with no physics — auto_free() works perfectly.

var player: Player


func before_test() -> void:
	player = auto_free(Player.new())
	player.initialize("Test Player", Color.BLUE)


# --- initialize() ---

func test_initialize_sets_name_and_color() -> void:
	assert_str(player.player_name).is_equal("Test Player")
	assert_that(player.color).is_equal(Color.BLUE)


# --- Resource setters (materials/fervor/glory) ---

func test_initial_stats_zero() -> void:
	assert_int(player.materials).is_equal(0)
	assert_int(player.fervor).is_equal(0)
	assert_int(player.glory).is_equal(0)


func test_set_materials_updates_value() -> void:
	player.materials = 5
	assert_int(player.materials).is_equal(5)


func test_set_materials_emits_signal() -> void:
	# Array as a mutable box — GDScript lambdas capture plain locals by value,
	# so a plain int wouldn't observe the mutation from inside the callback.
	var received := [-1]
	player.materials_changed.connect(func(amount: int) -> void: received[0] = amount)
	player.materials = 7
	assert_int(received[0]).is_equal(7)


func test_set_fervor_updates_value() -> void:
	player.fervor = 3
	assert_int(player.fervor).is_equal(3)


func test_set_glory_updates_value() -> void:
	player.glory = 2
	assert_int(player.glory).is_equal(2)


# --- initialize_game_start() ---

func test_initialize_game_start_sets_hand_and_actions() -> void:
	var god := God.new("Test God")
	player.initialize_game_start(god, false)
	assert_int(player.hand_size).is_equal(god.hand_size)
	assert_int(player.total_actions).is_equal(god.total_actions)
	assert_int(player.hand.size()).is_equal(god.hand_size)
	assert_int(player.glory).is_equal(0)


func test_initialize_game_start_test_mode_grants_test_value() -> void:
	var god := God.new("Test God")
	player.initialize_game_start(god, true)
	assert_int(player.materials).is_equal(Player.TEST_VALUE)
	assert_int(player.fervor).is_equal(Player.TEST_VALUE)
	assert_int(player.total_actions).is_equal(Player.TEST_VALUE)


# --- start_turn() ---

func test_start_turn_resets_actions_to_total() -> void:
	var god := God.new("Test God")
	player.initialize_game_start(god, false)
	player.actions_remaining = 0
	player.start_turn()
	assert_int(player.actions_remaining).is_equal(player.total_actions)


# --- Hand management ---

func test_hand_starts_empty_after_game_start() -> void:
	var god := God.new("Test God")
	player.initialize_game_start(god, false)
	for slot in player.hand:
		assert_object(slot).is_null()


func test_add_to_hand_fills_first_empty_slot() -> void:
	var god := God.new("Test God")
	player.initialize_game_start(god, false)
	var tile := TileDefinition.new(TileDefinition.TileType.PLAINS, {}, 2)
	player.add_to_hand(tile)
	assert_object(player.hand[0]).is_same(tile)


func test_remove_from_hand_clears_slot() -> void:
	var god := God.new("Test God")
	player.initialize_game_start(god, false)
	var tile := TileDefinition.new(TileDefinition.TileType.PLAINS, {}, 2)
	player.add_to_hand(tile)
	player.remove_from_hand(0)
	assert_object(player.hand[0]).is_null()


func test_empty_hand_clears_all_slots() -> void:
	var god := God.new("Test God")
	player.initialize_game_start(god, false)
	player.add_to_hand(TileDefinition.new(TileDefinition.TileType.PLAINS, {}, 2))
	player.empty_hand()
	for slot in player.hand:
		assert_object(slot).is_null()
