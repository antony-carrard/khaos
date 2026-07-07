extends GdUnitTestSuite

# InstantGodPower.activate(): can_afford gate, pay_cost, then apply().
# Uses the real ExtraActionPower/SecondHarvestPower against a fake board
# manager stub (avoids depending on the full board_manager scene graph).

class FakeBoardManager extends Node3D:
	var current_player: Player
	var harvest_called_for: Player = null

	func harvest_for_player(player: Player) -> void:
		harvest_called_for = player


var player: Player
var board: FakeBoardManager


func before_test() -> void:
	player = auto_free(Player.new())
	player.initialize("Test Player", Color.WHITE)
	player.materials = 0
	player.fervor = 5
	player.glory = 0
	player.actions_remaining = 3
	board = auto_free(FakeBoardManager.new())
	board.current_player = player


func test_activate_fails_and_changes_nothing_when_unaffordable() -> void:
	player.fervor = 0
	var power := ExtraActionPower.new()
	var success := power.activate(board)
	assert_bool(success).is_false()
	assert_int(player.fervor).is_equal(0)
	assert_int(player.actions_remaining).is_equal(3)


func test_extra_action_pays_fervor_and_action_and_is_a_noop() -> void:
	var power := ExtraActionPower.new()
	var success := power.activate(board)
	assert_bool(success).is_true()
	assert_int(player.fervor).is_equal(3)  # 5 - 2
	assert_int(player.actions_remaining).is_equal(2)  # stub still consumes an action


func test_second_harvest_does_not_consume_action() -> void:
	var power := SecondHarvestPower.new()
	var success := power.activate(board)
	assert_bool(success).is_true()
	assert_int(player.fervor).is_equal(0)  # 5 - 5
	assert_int(player.actions_remaining).is_equal(3)  # untouched — free action
	assert_object(board.harvest_called_for).is_same(player)
