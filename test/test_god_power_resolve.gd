extends GdUnitTestSuite

# GodPower.resolve(): is_valid_target() gate -> pay_cost -> apply_effect().
# Uses a throwaway fake power (not one of the real ones) to test the generic
# contract in isolation from any specific power's business logic.

class FakeBoardManager extends Node3D:
	var current_player: Player


class FakePower extends GodPower:
	var valid: bool = true
	var apply_effect_called: bool = false

	func _init() -> void:
		super("Fake Power", "for testing", 3)

	func is_valid_target(_board_manager: Node3D, _q: int, _r: int) -> bool:
		return valid

	func apply_effect(_board_manager: Node3D, _q: int, _r: int) -> bool:
		apply_effect_called = true
		return true


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


func test_resolve_fails_and_pays_nothing_when_target_invalid() -> void:
	var power := FakePower.new()
	power.valid = false
	var success := power.resolve(board, 0, 0)
	assert_bool(success).is_false()
	assert_bool(power.apply_effect_called).is_false()
	assert_int(player.fervor).is_equal(5)
	assert_int(player.actions_remaining).is_equal(3)


func test_resolve_pays_cost_and_calls_apply_effect_when_valid() -> void:
	var power := FakePower.new()
	var success := power.resolve(board, 0, 0)
	assert_bool(success).is_true()
	assert_bool(power.apply_effect_called).is_true()
	assert_int(player.fervor).is_equal(2)  # 5 - 3
	assert_int(player.actions_remaining).is_equal(2)
