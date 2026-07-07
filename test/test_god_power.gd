extends GdUnitTestSuite

# GodPower is pure data + the one place cost logic lives (can_afford/pay_cost).

var player: Player


func before_test() -> void:
	player = auto_free(Player.new())
	player.initialize("Test Player", Color.WHITE)
	player.materials = 0
	player.fervor = 5
	player.glory = 0
	player.actions_remaining = 3


func test_can_afford_true_when_fervor_and_action_available() -> void:
	var power := GodPower.new("Test", "desc", 3)
	assert_bool(power.can_afford(player)).is_true()


func test_can_afford_false_when_fervor_insufficient() -> void:
	var power := GodPower.new("Test", "desc", 10)
	assert_bool(power.can_afford(player)).is_false()


func test_can_afford_false_when_no_actions_remaining() -> void:
	player.actions_remaining = 0
	var power := GodPower.new("Test", "desc", 3)
	assert_bool(power.can_afford(player)).is_false()


func test_can_afford_ignores_actions_when_consumes_action_false() -> void:
	player.actions_remaining = 0
	var power := GodPower.new("Test", "desc", 3, false, false)
	assert_bool(power.can_afford(player)).is_true()


func test_pay_cost_deducts_fervor_and_action() -> void:
	var power := GodPower.new("Test", "desc", 3)
	power.pay_cost(player)
	assert_int(player.fervor).is_equal(2)
	assert_int(player.actions_remaining).is_equal(2)


func test_pay_cost_does_not_deduct_action_when_consumes_action_false() -> void:
	var power := GodPower.new("Test", "desc", 3, false, false)
	power.pay_cost(player)
	assert_int(player.fervor).is_equal(2)
	assert_int(player.actions_remaining).is_equal(3)


func test_pay_cost_skips_fervor_deduction_when_free() -> void:
	var power := GodPower.new("Test", "desc", 0)
	power.pay_cost(player)
	assert_int(player.fervor).is_equal(5)
	assert_int(player.actions_remaining).is_equal(2)
