extends GdUnitTestSuite

# TargetedGodPower.resolve(): is_valid_target gate -> pay_cost -> resolve_effect.
# Uses a throwaway fake power (not one of the real 7) to test the generic
# contract in isolation from any specific power's business logic.

class FakeBoardManager extends Node3D:
	var current_player: Player


class FakePower extends TargetedGodPower:
	var valid: bool = true
	var resolve_effect_called: bool = false

	func _init():
		super("Fake Power", "for testing", 3)

	func is_valid_target(_board_manager: Node3D, _q: int, _r: int) -> bool:
		return valid

	func resolve_effect(_board_manager: Node3D, _q: int, _r: int, _extra: int) -> bool:
		resolve_effect_called = true
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
	var success := power.resolve(board, 0, 0, TargetedGodPower.NO_EXTRA)
	assert_bool(success).is_false()
	assert_bool(power.resolve_effect_called).is_false()
	assert_int(player.fervor).is_equal(5)
	assert_int(player.actions_remaining).is_equal(3)


func test_resolve_pays_cost_and_calls_resolve_effect_when_valid() -> void:
	var power := FakePower.new()
	var success := power.resolve(board, 0, 0, TargetedGodPower.NO_EXTRA)
	assert_bool(success).is_true()
	assert_bool(power.resolve_effect_called).is_true()
	assert_int(player.fervor).is_equal(2)  # 5 - 3
	assert_int(player.actions_remaining).is_equal(2)


func test_on_target_selected_default_delegates_to_resolve_power_target() -> void:
	var power := FakePower.new()
	var recorder: RecorderBoard = auto_free(RecorderBoard.new())
	var success: bool = power.on_target_selected(recorder, 5, 6)
	assert_bool(success).is_true()
	assert_int(recorder.last_q).is_equal(5)
	assert_int(recorder.last_r).is_equal(6)
	assert_int(recorder.last_extra).is_equal(TargetedGodPower.NO_EXTRA)


class RecorderBoard extends Node3D:
	var last_q: int = -1
	var last_r: int = -1
	var last_extra: int = -99

	func _resolve_power_target(_power: TargetedGodPower, q: int, r: int, extra: int) -> bool:
		last_q = q
		last_r = r
		last_extra = extra
		return true
