class_name GodManager
extends Node

## Centralized god definitions and power implementation
## All god data and power logic lives here for easy modification

# ============================================================================
# GOD DEFINITIONS
# ============================================================================

static func create_all_gods() -> Array[God]:
	return [
		create_le_batisseur(),
		create_bicephalles(),
		create_augia(),
		create_rakun()
	]

static func create_le_batisseur() -> God:
	var god = God.new("Le Bâtisseur", "res://gods/bâtisseur.jpg")

	# Major power - costs fervor, destroys enemy village for free
	var major = GodPower.new(
		"Destruction gratuite",
		"Détruire le Bâtiment d'un adversaire sans remboursement",
		6,  # Cost from rules.md line 207
		GodPower.PowerType.DESTROY_VILLAGE_FREE,
		false
	)

	# Passive constraint - all villages cost 4 resources
	var passive = GodPower.new(
		"Coût fixe",
		"Les constructions coûtent 4 ressources",
		0,
		GodPower.PowerType.FLAT_VILLAGE_COST,
		true
	)

	god.powers.append(major)
	god.powers.append(passive)
	return god

static func create_bicephalles() -> God:
	var god = God.new("Bicéphallès", "res://gods/bicéphallès.jpg")

	# Minor power - 4 actions next turn
	var minor = GodPower.new(
		"Actions supplémentaires",
		"4 actions au prochain tour",
		3,  # Cost from rules.md line 195
		GodPower.PowerType.EXTRA_ACTION,
		false
	)

	# Major power - second harvest this turn
	var major = GodPower.new(
		"Double récolte",
		"Faire une 2e récolte au tour en cours",
		5,  # Cost from rules.md line 200
		GodPower.PowerType.SECOND_HARVEST,
		false
	)

	god.powers.append(minor)
	god.powers.append(major)
	return god

static func create_augia() -> God:
	var god = God.new("Augia", "res://gods/augia.jpg")

	# Minor power - change tile type
	var minor = GodPower.new(
		"Transformation",
		"Changer le type de ses propres Tuiles",
		2,  # Cost from rules.md line 220
		GodPower.PowerType.CHANGE_TILE_TYPE,
		false
	)

	# Major power - upgrade tile without destroying village
	var major = GodPower.new(
		"Élévation divine",
		"Augmenter une Tuile d'un niveau sans détruire le Bâtiment",
		5,  # Cost from rules.md line 225
		GodPower.PowerType.UPGRADE_TILE_KEEP_VILLAGE,
		false
	)

	god.powers.append(minor)
	god.powers.append(major)
	return god

static func create_rakun() -> God:
	var god = God.new("Rakun", "res://gods/rakun.jpg")

	# Minor power - steal harvest from enemy village
	var minor = GodPower.new(
		"Vol de récolte",
		"Choisir un bâtiment d'un autre dieu et récolter ses possessions",
		2,  # Cost from rules.md line 232
		GodPower.PowerType.STEAL_HARVEST,
		false
	)

	# Major power - downgrade tile without destroying village
	var major = GodPower.new(
		"Affaissement",
		"Diminuer une Tuile d'un niveau sans détruire le Bâtiment",
		4,  # Cost from rules.md line 238
		GodPower.PowerType.DOWNGRADE_TILE_KEEP_VILLAGE,
		false
	)

	god.powers.append(minor)
	god.powers.append(major)
	return god

# ============================================================================
# POWER ACTIVATION
# ============================================================================

## Attempt to activate a power
## Returns true if successful, false if player can't afford or action fails
func activate_power(power: GodPower, player, board_manager) -> bool:
	# Check if power has already been used this turn
	if player.has_used_power(power.power_type):
		print("Power already used this turn!")
		return false

	# Check if player can afford fervor cost
	if power.fervor_cost > 0 and player.fervor < power.fervor_cost:
		print("Not enough fervor! Need %d, have %d" % [power.fervor_cost, player.fervor])
		return false

	# Check if we're in the actions phase (most powers require this)
	if not board_manager.turn_manager.is_actions_phase():
		print("Can only use powers during actions phase")
		return false

	# Check if player has actions remaining (most powers consume 1 action)
	if not _power_is_free_action(power) and player.actions_remaining <= 0:
		print("No actions remaining")
		return false

	# Spend fervor
	if power.fervor_cost > 0:
		player.spend_fervor(power.fervor_cost)

	# Consume action (unless it's a free action like SECOND_HARVEST)
	if not _power_is_free_action(power):
		player.consume_action()

	# Execute power effect
	match power.power_type:
		GodPower.PowerType.DESTROY_VILLAGE_FREE:
			_activate_destroy_village_free(player, board_manager)

		GodPower.PowerType.EXTRA_ACTION:
			_activate_extra_action(player)

		GodPower.PowerType.SECOND_HARVEST:
			_activate_second_harvest(player, board_manager)

		GodPower.PowerType.CHANGE_TILE_TYPE:
			_activate_change_tile_type(player, board_manager)

		GodPower.PowerType.UPGRADE_TILE_KEEP_VILLAGE:
			_activate_upgrade_tile_keep_village(player, board_manager)

		GodPower.PowerType.STEAL_HARVEST:
			_activate_steal_harvest(player, board_manager)

		GodPower.PowerType.DOWNGRADE_TILE_KEEP_VILLAGE:
			_activate_downgrade_tile_keep_village(player, board_manager)

		_:
			print("Power type not implemented: ", power.power_type)
			return false

	# Mark power as used this turn
	player.mark_power_used(power.power_type)

	print("Activated power: ", power.power_name)
	return true

## Check if power doesn't consume an action
func _power_is_free_action(power: GodPower) -> bool:
	# Second harvest doesn't consume action (it's already in harvest phase logic)
	return power.power_type == GodPower.PowerType.SECOND_HARVEST


## Check if a power can be activated (for UI updates)
## Returns true if all requirements are met
func can_activate_power(power: GodPower, player, turn_manager) -> bool:
	# Passive powers can't be activated
	if power.is_passive:
		return false

	# Check if already used this turn
	if player.has_used_power(power.power_type):
		return false

	# Check fervor cost
	if power.fervor_cost > 0 and player.fervor < power.fervor_cost:
		return false

	# Check phase
	if not turn_manager.is_actions_phase():
		return false

	# Check actions
	if not _power_is_free_action(power) and player.actions_remaining <= 0:
		return false

	return true

# ============================================================================
# POWER IMPLEMENTATIONS
# ============================================================================

func _activate_destroy_village_free(player, board_manager) -> void:
	# Enter destroy village selection mode
	if board_manager.placement_controller:
		board_manager.placement_controller.select_destroy_village_free_mode()
		print("Destroy village mode activated - click an enemy village")

func _activate_extra_action(player) -> void:
	# Grant +1 action for next turn
	player.next_turn_bonus_actions = 1
	print("Next turn will have 4 actions!")

func _activate_second_harvest(player, board_manager) -> void:
	# Trigger harvest UI again (doesn't consume action, costs fervor only)
	if board_manager.turn_manager:
		board_manager.turn_manager.trigger_second_harvest()
		print("Second harvest triggered!")
	else:
		push_error("Cannot trigger second harvest: turn_manager not found")

func _activate_change_tile_type(player, board_manager) -> void:
	# TODO: Enter mode to select own tile and change its resource type
	print("TODO: Implement CHANGE_TILE_TYPE")

func _activate_upgrade_tile_keep_village(player, board_manager) -> void:
	# TODO: Enter mode to upgrade tile (like normal upgrade but keeps village)
	print("TODO: Implement UPGRADE_TILE_KEEP_VILLAGE")

func _activate_steal_harvest(player, board_manager) -> void:
	# Enter steal harvest selection mode
	if board_manager.placement_controller:
		board_manager.placement_controller.select_steal_harvest_mode()
		print("Steal harvest mode activated - click an enemy village")

func _activate_downgrade_tile_keep_village(player, board_manager) -> void:
	# TODO: Enter mode to downgrade tile (opposite of upgrade, keeps village)
	print("TODO: Implement DOWNGRADE_TILE_KEEP_VILLAGE")

# ============================================================================
# PASSIVE POWER QUERIES
# ============================================================================

## Get the actual village building cost for a tile, accounting for god abilities
static func get_village_cost(god: God, base_cost: int) -> int:
	if god and god.has_power_type(GodPower.PowerType.FLAT_VILLAGE_COST):
		return 4  # Le Bâtisseur's passive
	return base_cost
