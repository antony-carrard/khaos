extends GdUnitTestSuite

# Player extends Node with no physics — auto_free() works perfectly.

var player: Player


func before_test() -> void:
	player = auto_free(Player.new())
	player.initialize("Test Player", 0, 0)


# --- Resources ---

func test_initial_resources_zero() -> void:
	assert_int(player.resources).is_equal(0)


func test_add_resources() -> void:
	player.add_resources(5)
	assert_int(player.resources).is_equal(5)


func test_add_resources_cumulative() -> void:
	player.add_resources(3)
	player.add_resources(4)
	assert_int(player.resources).is_equal(7)


func test_spend_resources_success() -> void:
	player.add_resources(10)
	assert_bool(player.spend_resources(4)).is_true()
	assert_int(player.resources).is_equal(6)


func test_spend_resources_exact_balance() -> void:
	player.add_resources(5)
	assert_bool(player.spend_resources(5)).is_true()
	assert_int(player.resources).is_equal(0)


func test_spend_resources_insufficient_fails() -> void:
	assert_bool(player.spend_resources(1)).is_false()
	assert_int(player.resources).is_equal(0)


# --- Fervor ---

func test_initial_fervor_zero() -> void:
	assert_int(player.fervor).is_equal(0)


func test_add_fervor() -> void:
	player.add_fervor(3)
	assert_int(player.fervor).is_equal(3)


func test_spend_fervor_success() -> void:
	player.add_fervor(6)
	assert_bool(player.spend_fervor(2)).is_true()
	assert_int(player.fervor).is_equal(4)


func test_spend_fervor_insufficient_fails() -> void:
	assert_bool(player.spend_fervor(1)).is_false()


# --- Glory ---

func test_initial_glory_zero() -> void:
	assert_int(player.glory).is_equal(0)


func test_add_glory() -> void:
	player.add_glory(2)
	assert_int(player.glory).is_equal(2)


# --- Actions ---

func test_consume_action_decrements() -> void:
	player.set_actions(3)
	player.consume_action()
	assert_int(player.actions_remaining).is_equal(2)


func test_consume_action_at_zero_fails() -> void:
	player.set_actions(0)
	assert_bool(player.consume_action()).is_false()
	assert_int(player.actions_remaining).is_equal(0)


func test_can_place_tile_with_actions() -> void:
	player.set_actions(1)
	assert_bool(player.can_place_tile(true)).is_true()


func test_cannot_place_tile_without_actions() -> void:
	player.set_actions(0)
	assert_bool(player.can_place_tile(true)).is_false()


# --- Hand ---

func test_initial_hand_is_empty() -> void:
	for slot in player.hand:
		assert_object(slot).is_null()


func test_hand_size_is_three() -> void:
	assert_int(player.hand.size()).is_equal(Player.HAND_SIZE)
