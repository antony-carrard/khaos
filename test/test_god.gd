extends GdUnitTestSuite

# God.create_all() catalog, the minor/major power slots, and the passive hooks.

class FakeBoardManager extends Node3D:
	var current_player: Player
	func _init(p: Player) -> void:
		current_player = p


var _bare_tiles: Array[HexTile] = []


func after_test() -> void:
	# HexTile is a StaticBody3D — free()ing it on GdUnit's worker thread aborts.
	for tile in _bare_tiles:
		tile.call_deferred("free")
	_bare_tiles.clear()


## A real placed board tile — modify_village_cost() takes the HexTile node, not
## a TileDefinition, and passing null here would hide that.
func _board_tile(tile_type: int = TileDefinition.TileType.PLAINS) -> HexTile:
	var tile := HexTile.new()
	tile.tile_type = tile_type
	tile.village_building_cost = 2
	_bare_tiles.append(tile)
	return tile



func test_create_all_returns_all_gods() -> void:
	var gods := God.create_all()
	var names: Array[String] = []
	for god in gods:
		names.append(god.god_name)
	assert_array(names).contains_exactly("Le Bâtisseur", "Bicéphallès", "Augia", "Rakun", "Le Démolisseur")


func test_create_all_returns_fresh_instances_each_call() -> void:
	var first_call := God.create_all()
	var second_call := God.create_all()
	assert_object(first_call[0]).is_not_same(second_call[0])


func test_base_god_village_cost_is_unchanged() -> void:
	var god := God.new("Test God")
	assert_int(god.modify_village_cost(10, _board_tile())).is_equal(10)


func test_le_batisseur_plains_village_cost_overrides_base() -> void:
	var god := LeBatisseurGod.new()
	var tile := _board_tile(TileDefinition.TileType.PLAINS)
	assert_int(god.modify_village_cost(10, tile)).is_equal(LeBatisseurGod.PLAINS_VILLAGE_COST)


func test_le_batisseur_non_plains_village_cost_is_unchanged() -> void:
	var god := LeBatisseurGod.new()
	var hills_tile := _board_tile(TileDefinition.TileType.HILLS)
	assert_int(god.modify_village_cost(4, hills_tile)).is_equal(4)
	var mountain_tile := _board_tile(TileDefinition.TileType.MOUNTAIN)
	assert_int(god.modify_village_cost(6, mountain_tile)).is_equal(6)


func test_base_god_rebuild_cost_is_unchanged() -> void:
	var god := God.new("Test God")
	assert_int(god.modify_rebuild_cost(10, true)).is_equal(10)


func test_demolisseur_rebuild_cost_halves_when_demolished_this_turn() -> void:
	var god := LeDemolisseurGod.new()
	assert_int(god.modify_rebuild_cost(10, true)).is_equal(5)


func test_demolisseur_rebuild_cost_unchanged_when_not_demolished_this_turn() -> void:
	var god := LeDemolisseurGod.new()
	assert_int(god.modify_rebuild_cost(10, false)).is_equal(10)


# --- Power slots ---

func test_le_batisseur_has_both_powers() -> void:
	var god := LeBatisseurGod.new()
	assert_bool(god.minor is MergeVillagesPower).is_true()
	assert_bool(god.major is BuildAnywherePower).is_true()


func test_le_demolisseur_has_a_major_and_no_minor() -> void:
	var god := LeDemolisseurGod.new()
	assert_object(god.minor).is_null()
	assert_bool(god.major is DestroyVillageFreePower).is_true()


func test_bicephalles_powers_are_bonus_harvest_and_double_village() -> void:
	var god := BicephallesGod.new()
	assert_bool(god.minor is BonusHarvestPower).is_true()
	assert_bool(god.major is DoubleVillagePower).is_true()


func test_augia_powers_are_change_tile_type_and_upgrade() -> void:
	var god := AugiaGod.new()
	assert_bool(god.minor is ChangeTileTypePower).is_true()
	assert_bool(god.major is UpgradeTileKeepVillagePower).is_true()


func test_rakun_powers_are_steal_harvest_and_downgrade() -> void:
	var god := RakunGod.new()
	assert_bool(god.minor is StealHarvestPower).is_true()
	assert_bool(god.major is DowngradeTileKeepVillagePower).is_true()


# --- Slot lookup, the network wire identifier ---

func test_get_power_returns_the_slot_occupant() -> void:
	var god := AugiaGod.new()
	assert_object(god.get_power(God.PowerSlot.MINOR)).is_same(god.minor)
	assert_object(god.get_power(God.PowerSlot.MAJOR)).is_same(god.major)


func test_get_power_returns_null_for_an_empty_slot() -> void:
	var god := LeDemolisseurGod.new()
	assert_object(god.get_power(God.PowerSlot.MINOR)).is_null()


func test_find_slot_round_trips_through_get_power() -> void:
	var god := RakunGod.new()
	var slot := god.find_slot(god.major)
	assert_int(slot).is_equal(God.PowerSlot.MAJOR)
	assert_object(god.get_power(slot)).is_same(god.major)


func test_find_slot_returns_minus_one_for_a_foreign_power() -> void:
	var god := RakunGod.new()
	assert_int(god.find_slot(GodPower.new("Foreign", "not this god's", 1))).is_equal(-1)


func test_find_slot_returns_minus_one_for_null() -> void:
	# Bicéphallès has two null slots — a null lookup must not match them.
	var god := BicephallesGod.new()
	assert_int(god.find_slot(null)).is_equal(-1)


# --- Passives that are plain stat changes ---

func test_bicephalles_passive_grants_a_fourth_action() -> void:
	assert_int(BicephallesGod.new().total_actions).is_equal(4)


func test_augia_passive_grants_a_fourth_hand_tile() -> void:
	assert_int(AugiaGod.new().hand_size).is_equal(4)


func test_gods_without_a_stat_passive_use_the_defaults() -> void:
	var god := RakunGod.new()
	assert_int(god.total_actions).is_equal(3)
	assert_int(god.hand_size).is_equal(3)


# --- Demolish-triggered passive hook ---

func test_base_god_on_village_demolished_is_a_noop() -> void:
	var god := God.new("Test God")
	var player: Player = auto_free(Player.new())
	player.initialize("P", Color.BLUE)
	var tile := _board_tile()
	tile.yields = {TileDefinition.ResourceType.MATERIALS: 3}
	god.on_village_demolished(auto_free(FakeBoardManager.new(player)), tile)
	assert_int(player.materials).is_equal(0)


func test_rakun_on_village_demolished_steals_the_tiles_yields() -> void:
	var god := RakunGod.new()
	var player: Player = auto_free(Player.new())
	player.initialize("P", Color.BLUE)
	var tile := _board_tile()
	tile.yields = {
		TileDefinition.ResourceType.MATERIALS: 3,
		TileDefinition.ResourceType.GLORY: 1,
	}
	god.on_village_demolished(auto_free(FakeBoardManager.new(player)), tile)
	assert_int(player.materials).is_equal(3)
	assert_int(player.glory).is_equal(1)
