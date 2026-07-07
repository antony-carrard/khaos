extends GdUnitTestSuite

# God.create_all() catalog + virtual get_village_cost() override.


func test_create_all_returns_the_four_gods() -> void:
	var gods := God.create_all()
	var names: Array[String] = []
	for god in gods:
		names.append(god.god_name)
	assert_array(names).contains_exactly("Le Bâtisseur", "Bicéphallès", "Augia", "Rakun")


func test_create_all_returns_fresh_instances_each_call() -> void:
	var first_call := God.create_all()
	var second_call := God.create_all()
	assert_object(first_call[0]).is_not_same(second_call[0])


func test_base_god_village_cost_is_unchanged() -> void:
	var god := God.new("Test God")
	assert_int(god.get_village_cost(10)).is_equal(10)


func test_le_batisseur_flat_village_cost_overrides_base() -> void:
	var god := LeBatisseurGod.new()
	assert_int(god.get_village_cost(10)).is_equal(LeBatisseurGod.FLAT_VILLAGE_COST)


func test_le_batisseur_has_one_active_and_one_passive_power() -> void:
	var god := LeBatisseurGod.new()
	assert_int(god.get_active_powers().size()).is_equal(1)
	assert_int(god.get_passive_powers().size()).is_equal(1)


func test_bicephalles_has_two_active_powers() -> void:
	var god := BicephallesGod.new()
	assert_int(god.get_active_powers().size()).is_equal(2)
	assert_int(god.get_passive_powers().size()).is_equal(0)


func test_augia_powers_are_change_tile_type_and_upgrade() -> void:
	var god := AugiaGod.new()
	assert_bool(god.powers[0] is ChangeTileTypePower).is_true()
	assert_bool(god.powers[1] is UpgradeTileKeepVillagePower).is_true()


func test_rakun_powers_are_steal_harvest_and_downgrade() -> void:
	var god := RakunGod.new()
	assert_bool(god.powers[0] is StealHarvestPower).is_true()
	assert_bool(god.powers[1] is DowngradeTileKeepVillagePower).is_true()
