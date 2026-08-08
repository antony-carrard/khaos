extends GdUnitTestSuite

# Concrete GodPower subclasses: their is_valid_target()/apply_effect() overrides.
# Tiles/villages are injected directly into the managers' internal dictionaries
# (established repo test pattern) rather than placed through the full placement flow.
#
# NOTE: upgrade_tile_with() instantiates a real hex_tile_scene, and
# downgrade_tile() calls queue_free() on an existing HexTile node — both are
# StaticBody3D (see test_victory_scoring.gd on the free()-on-worker-thread
# crash) so per repo policy those scene-dependent effects aren't re-verified
# here; only validity is tested for the two tile-height powers, including
# DowngradeTileKeepVillagePower's plains-demolishes-the-village branch. The
# effect for those is covered by the Stage 2 manual playtest.

class FakePlacementController extends Node:
	func cancel_placement() -> void:
		pass


class FakeBoardManager extends Node3D:
	var current_player: Player
	var village_manager: VillageManager
	var tile_manager: TileManager
	var tile_pool: TilePool
	var placement_controller: Node = null
	var ui: Node = null
	var villages_built_this_turn: Dictionary[Vector2i, bool] = {}

	# Activation context — stands in for the real board_manager's, which is
	# where a power reads the hand tile the player picked for it and the board
	# picks a multi-step power has collected so far.
	var power_hand_index: int = -1
	var power_selected_villages: Array[Vector2i] = []

	func get_picked_hand_tile() -> TileDefinition:
		if power_hand_index < 0 or power_hand_index >= current_player.hand.size():
			return null
		return current_player.hand[power_hand_index]

	# Mirrors the real one minus the board highlighting, which needs live tiles.
	func toggle_power_selection(q: int, r: int) -> void:
		var key := Vector2i(q, r)
		var index := power_selected_villages.find(key)
		if index == -1:
			power_selected_villages.append(key)
		else:
			power_selected_villages.remove_at(index)


var actor: Player
var victim: Player
var board: FakeBoardManager
var village_manager: VillageManager
var tile_manager: TileManager
var tile_pool: TilePool
var _bare_tiles: Array[HexTile] = []


func before_test() -> void:
	actor = auto_free(Player.new())
	actor.initialize("Actor", Color.BLUE)
	actor.materials = 0
	actor.fervor = 20
	actor.glory = 0
	actor.actions_remaining = 5
	actor.hand.resize(3)

	victim = auto_free(Player.new())
	victim.initialize("Victim", Color.RED)

	village_manager = auto_free(VillageManager.new())
	tile_manager = auto_free(TileManager.new())
	tile_manager.max_stack_height = 3
	village_manager.tile_manager = tile_manager
	tile_pool = auto_free(TilePool.new())
	tile_pool.initialize()

	board = auto_free(FakeBoardManager.new())
	board.current_player = actor
	board.village_manager = village_manager
	board.tile_manager = tile_manager
	board.tile_pool = tile_pool
	board.placement_controller = auto_free(FakePlacementController.new())


func after_test() -> void:
	for tile in _bare_tiles:
		tile.call_deferred("free")
	_bare_tiles.clear()


func _inject_village(q: int, r: int, owner: Player) -> Village:
	var village := Village.new()
	village.set_grid_position(q, r)
	village.set_player_owner(owner)
	village_manager.placed_villages[Vector2i(q, r)] = village
	if not village_manager.player_villages.has(owner):
		village_manager.player_villages[owner] = [] as Array[Village]
	village_manager.player_villages[owner].append(village)
	return village


func _inject_tile(q: int, r: int, height: int, tile_type: int, yields: Dictionary) -> HexTile:
	var tile := HexTile.new()
	tile.q = q
	tile.r = r
	tile.height_level = height
	tile.tile_type = tile_type
	tile.yields = yields
	tile_manager.placed_tiles[Vector3i(q, r, height)] = tile
	_bare_tiles.append(tile)
	return tile


# --- DestroyVillageFreePower (Le Bâtisseur) ---

func test_destroy_village_free_valid_target_is_enemy_village() -> void:
	_inject_village(0, 0, victim)
	var power := DestroyVillageFreePower.new()
	assert_bool(power.is_valid_target(board, 0, 0)).is_true()


func test_destroy_village_free_invalid_on_own_village() -> void:
	_inject_village(0, 0, actor)
	var power := DestroyVillageFreePower.new()
	assert_bool(power.is_valid_target(board, 0, 0)).is_false()


func test_destroy_village_free_invalid_when_no_village() -> void:
	var power := DestroyVillageFreePower.new()
	assert_bool(power.is_valid_target(board, 0, 0)).is_false()


func test_destroy_village_free_resolve_effect_removes_village() -> void:
	_inject_village(0, 0, victim)
	var power := DestroyVillageFreePower.new()
	var success := power.apply_effect(board, 0, 0)
	assert_bool(success).is_true()
	assert_object(village_manager.get_village_at(0, 0)).is_null()


# --- BuildAnywherePower (Le Bâtisseur major) ---

func test_build_anywhere_valid_target_is_vacant_tile() -> void:
	_inject_tile(0, 0, 0, TileDefinition.TileType.MOUNTAIN, {})
	var power := BuildAnywherePower.new()
	assert_bool(power.is_valid_target(board, 0, 0)).is_true()


func test_build_anywhere_invalid_when_village_already_present() -> void:
	_inject_tile(0, 0, 0, TileDefinition.TileType.PLAINS, {})
	_inject_village(0, 0, victim)
	var power := BuildAnywherePower.new()
	assert_bool(power.is_valid_target(board, 0, 0)).is_false()


func test_build_anywhere_invalid_when_no_tile() -> void:
	var power := BuildAnywherePower.new()
	assert_bool(power.is_valid_target(board, 0, 0)).is_false()

# apply_effect() is not re-verified here: place_village() sets global_position,
# which requires the node to be inside the scene tree (unlike this suite's
# detached managers) and otherwise only logs an engine error — same
# scene-dependent-effect carve-out as the tile-height powers above. Covered by
# manual playtest instead.


# --- MergeVillagesPower (Le Bâtisseur minor) ---
#
# Two-step targeting: is_selectable()/handle_selection_click() collect own
# plains villages, then is_valid_target() gates the receiving hex. apply_effect()
# is not re-verified here — it calls place_village(), same scene-dependent
# carve-out as BuildAnywherePower above.

# Own plains villages on the east and northeast neighbours of the receiving hex
# at (0, 0), which the caller then makes a vacant hills or mountain tile.
func _setup_two_mergeable_villages() -> void:
	for pos in [Vector2i(1, 0), Vector2i(1, -1)]:
		_inject_village(pos.x, pos.y, actor)
		_inject_tile(pos.x, pos.y, 0, TileDefinition.TileType.PLAINS, {})


func test_merge_selectable_on_own_plains_village() -> void:
	_inject_village(1, 0, actor)
	_inject_tile(1, 0, 0, TileDefinition.TileType.PLAINS, {})
	var power := MergeVillagesPower.new()
	assert_bool(power.is_selectable(board, 1, 0)).is_true()


func test_merge_not_selectable_on_enemy_village() -> void:
	_inject_village(1, 0, victim)
	_inject_tile(1, 0, 0, TileDefinition.TileType.PLAINS, {})
	var power := MergeVillagesPower.new()
	assert_bool(power.is_selectable(board, 1, 0)).is_false()


func test_merge_not_selectable_on_own_hills_village() -> void:
	_inject_village(1, 0, actor)
	_inject_tile(1, 0, 1, TileDefinition.TileType.HILLS, {})
	var power := MergeVillagesPower.new()
	assert_bool(power.is_selectable(board, 1, 0)).is_false()


func test_merge_selection_click_toggles_the_pick() -> void:
	_inject_village(1, 0, actor)
	_inject_tile(1, 0, 0, TileDefinition.TileType.PLAINS, {})
	var power := MergeVillagesPower.new()
	assert_bool(power.handle_selection_click(board, 1, 0)).is_true()
	assert_int(board.power_selected_villages.size()).is_equal(1)
	assert_bool(power.handle_selection_click(board, 1, 0)).is_true()
	assert_int(board.power_selected_villages.size()).is_equal(0)


func test_merge_selection_stops_at_three_villages() -> void:
	var power := MergeVillagesPower.new()
	for pos in [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0)]:
		_inject_village(pos.x, pos.y, actor)
		_inject_tile(pos.x, pos.y, 0, TileDefinition.TileType.PLAINS, {})
		power.handle_selection_click(board, pos.x, pos.y)
	assert_int(board.power_selected_villages.size()).is_equal(MergeVillagesPower.MAX_MERGED)
	assert_bool(board.power_selected_villages.has(Vector2i(-1, 0))).is_false()


func test_merge_two_villages_target_vacant_hills_is_valid() -> void:
	_setup_two_mergeable_villages()
	_inject_tile(0, 0, 1, TileDefinition.TileType.HILLS, {})
	board.power_selected_villages = [Vector2i(1, 0), Vector2i(1, -1)]
	var power := MergeVillagesPower.new()
	assert_bool(power.is_valid_target(board, 0, 0)).is_true()


func test_merge_two_villages_target_vacant_mountain_is_invalid() -> void:
	_setup_two_mergeable_villages()
	_inject_tile(0, 0, 2, TileDefinition.TileType.MOUNTAIN, {})
	board.power_selected_villages = [Vector2i(1, 0), Vector2i(1, -1)]
	var power := MergeVillagesPower.new()
	assert_bool(power.is_valid_target(board, 0, 0)).is_false()


func test_merge_three_villages_target_vacant_mountain_is_valid() -> void:
	_setup_two_mergeable_villages()
	_inject_village(0, -1, actor)
	_inject_tile(0, -1, 0, TileDefinition.TileType.PLAINS, {})
	_inject_tile(0, 0, 2, TileDefinition.TileType.MOUNTAIN, {})
	board.power_selected_villages = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1)]
	var power := MergeVillagesPower.new()
	assert_bool(power.is_valid_target(board, 0, 0)).is_true()


func test_merge_target_invalid_when_only_one_village_selected() -> void:
	_setup_two_mergeable_villages()
	_inject_tile(0, 0, 1, TileDefinition.TileType.HILLS, {})
	board.power_selected_villages = [Vector2i(1, 0)]
	var power := MergeVillagesPower.new()
	assert_bool(power.is_valid_target(board, 0, 0)).is_false()


func test_merge_target_invalid_when_a_village_is_not_adjacent() -> void:
	_setup_two_mergeable_villages()
	_inject_village(3, 0, actor)
	_inject_tile(3, 0, 0, TileDefinition.TileType.PLAINS, {})
	_inject_tile(0, 0, 1, TileDefinition.TileType.HILLS, {})
	board.power_selected_villages = [Vector2i(1, 0), Vector2i(3, 0)]
	var power := MergeVillagesPower.new()
	assert_bool(power.is_valid_target(board, 0, 0)).is_false()


func test_merge_target_invalid_when_receiving_hex_is_occupied() -> void:
	_setup_two_mergeable_villages()
	_inject_tile(0, 0, 1, TileDefinition.TileType.HILLS, {})
	_inject_village(0, 0, victim)
	board.power_selected_villages = [Vector2i(1, 0), Vector2i(1, -1)]
	var power := MergeVillagesPower.new()
	assert_bool(power.is_valid_target(board, 0, 0)).is_false()


func test_merge_target_invalid_when_receiving_hex_has_no_tile() -> void:
	_setup_two_mergeable_villages()
	board.power_selected_villages = [Vector2i(1, 0), Vector2i(1, -1)]
	var power := MergeVillagesPower.new()
	assert_bool(power.is_valid_target(board, 0, 0)).is_false()


# --- StealHarvestPower (Rakun minor) ---

func test_steal_harvest_valid_target_is_enemy_village() -> void:
	_inject_village(1, 1, victim)
	var power := StealHarvestPower.new()
	assert_bool(power.is_valid_target(board, 1, 1)).is_true()


func test_steal_harvest_invalid_on_own_village() -> void:
	_inject_village(1, 1, actor)
	var power := StealHarvestPower.new()
	assert_bool(power.is_valid_target(board, 1, 1)).is_false()


func test_steal_harvest_resolve_effect_adds_yields_to_actor() -> void:
	_inject_village(1, 1, victim)
	_inject_tile(1, 1, 0, TileDefinition.TileType.PLAINS, {
		TileDefinition.ResourceType.MATERIALS: 3,
		TileDefinition.ResourceType.GLORY: 1,
	})
	var power := StealHarvestPower.new()
	var success := power.apply_effect(board, 1, 1)
	assert_bool(success).is_true()
	assert_int(actor.materials).is_equal(3)
	assert_int(actor.glory).is_equal(1)


func test_steal_harvest_resolve_effect_fails_without_tile() -> void:
	_inject_village(1, 1, victim)
	var power := StealHarvestPower.new()
	var success := power.apply_effect(board, 1, 1)
	assert_bool(success).is_false()


# --- BonusHarvestPower (Bicéphallès minor) ---

func test_bonus_harvest_valid_target_is_own_village() -> void:
	_inject_village(1, 1, actor)
	var power := BonusHarvestPower.new()
	assert_bool(power.is_valid_target(board, 1, 1)).is_true()


func test_bonus_harvest_invalid_on_enemy_village() -> void:
	_inject_village(1, 1, victim)
	var power := BonusHarvestPower.new()
	assert_bool(power.is_valid_target(board, 1, 1)).is_false()


func test_bonus_harvest_invalid_when_no_village() -> void:
	var power := BonusHarvestPower.new()
	assert_bool(power.is_valid_target(board, 1, 1)).is_false()


func test_bonus_harvest_resolve_effect_adds_yields_to_actor() -> void:
	_inject_village(1, 1, actor)
	_inject_tile(1, 1, 0, TileDefinition.TileType.PLAINS, {
		TileDefinition.ResourceType.MATERIALS: 3,
		TileDefinition.ResourceType.GLORY: 1,
	})
	var power := BonusHarvestPower.new()
	var success := power.apply_effect(board, 1, 1)
	assert_bool(success).is_true()
	assert_int(actor.materials).is_equal(3)
	assert_int(actor.glory).is_equal(1)


func test_bonus_harvest_resolve_effect_fails_without_tile() -> void:
	_inject_village(1, 1, actor)
	var power := BonusHarvestPower.new()
	var success := power.apply_effect(board, 1, 1)
	assert_bool(success).is_false()


# --- UpgradeTileKeepVillagePower (Augia major) — sourced from hand; validity
# only, see note above (apply_effect stacks a real HexTile scene node) ---

func test_upgrade_needs_a_hand_tile() -> void:
	assert_bool(UpgradeTileKeepVillagePower.new().needs_hand_tile()).is_true()


func test_upgrade_valid_target_own_village_one_level_below_hand_tile() -> void:
	_inject_village(2, 2, actor)
	_inject_tile(2, 2, 0, TileDefinition.TileType.PLAINS, {})
	actor.hand[0] = TileDefinition.new(TileDefinition.TileType.HILLS, {TileDefinition.ResourceType.MATERIALS: 2}, 4)
	board.power_hand_index = 0
	var power := UpgradeTileKeepVillagePower.new()
	assert_bool(power.is_valid_target(board, 2, 2)).is_true()


func test_upgrade_invalid_on_enemy_village() -> void:
	_inject_village(2, 2, victim)
	_inject_tile(2, 2, 0, TileDefinition.TileType.PLAINS, {})
	actor.hand[0] = TileDefinition.new(TileDefinition.TileType.HILLS, {TileDefinition.ResourceType.MATERIALS: 2}, 4)
	board.power_hand_index = 0
	var power := UpgradeTileKeepVillagePower.new()
	assert_bool(power.is_valid_target(board, 2, 2)).is_false()


func test_upgrade_invalid_when_hand_tile_same_level() -> void:
	_inject_village(2, 2, actor)
	_inject_tile(2, 2, 0, TileDefinition.TileType.PLAINS, {})
	actor.hand[0] = TileDefinition.new(TileDefinition.TileType.PLAINS, {TileDefinition.ResourceType.FERVOR: 1}, 2)
	board.power_hand_index = 0
	var power := UpgradeTileKeepVillagePower.new()
	assert_bool(power.is_valid_target(board, 2, 2)).is_false()


func test_upgrade_invalid_when_hand_tile_two_levels_above() -> void:
	_inject_village(2, 2, actor)
	_inject_tile(2, 2, 0, TileDefinition.TileType.PLAINS, {})
	actor.hand[0] = TileDefinition.new(TileDefinition.TileType.MOUNTAIN, {TileDefinition.ResourceType.MATERIALS: 3}, 6)
	board.power_hand_index = 0
	var power := UpgradeTileKeepVillagePower.new()
	assert_bool(power.is_valid_target(board, 2, 2)).is_false()


func test_upgrade_invalid_when_no_hand_tile_picked() -> void:
	_inject_village(2, 2, actor)
	_inject_tile(2, 2, 0, TileDefinition.TileType.PLAINS, {})
	var power := UpgradeTileKeepVillagePower.new()
	assert_bool(power.is_valid_target(board, 2, 2)).is_false()


func test_upgrade_can_afford_false_when_hand_empty() -> void:
	var power := UpgradeTileKeepVillagePower.new()
	assert_bool(power.can_afford(actor)).is_false()


func test_upgrade_can_afford_true_when_hand_has_tile() -> void:
	actor.hand[0] = TileDefinition.new(TileDefinition.TileType.HILLS, {TileDefinition.ResourceType.MATERIALS: 1}, 4)
	var power := UpgradeTileKeepVillagePower.new()
	assert_bool(power.can_afford(actor)).is_true()


# --- DowngradeTileKeepVillagePower (Rakun major) — validity only, see note above ---

func test_downgrade_valid_target_enemy_village_downgradable_tile() -> void:
	_inject_village(3, 3, victim)
	_inject_tile(3, 3, 1, TileDefinition.TileType.HILLS, {})
	var power := DowngradeTileKeepVillagePower.new()
	assert_bool(power.is_valid_target(board, 3, 3)).is_true()


func test_downgrade_invalid_on_own_village() -> void:
	_inject_village(3, 3, actor)
	_inject_tile(3, 3, 1, TileDefinition.TileType.HILLS, {})
	var power := DowngradeTileKeepVillagePower.new()
	assert_bool(power.is_valid_target(board, 3, 3)).is_false()


func test_downgrade_valid_target_enemy_village_on_plains() -> void:
	_inject_village(3, 3, victim)
	_inject_tile(3, 3, 0, TileDefinition.TileType.PLAINS, {})
	var power := DowngradeTileKeepVillagePower.new()
	assert_bool(power.is_valid_target(board, 3, 3)).is_true()


# --- ChangeTileTypePower (Augia minor) — sourced from hand, swaps tile back into hand ---

func test_change_tile_type_needs_a_hand_tile() -> void:
	assert_bool(ChangeTileTypePower.new().needs_hand_tile()).is_true()


func test_change_tile_type_valid_target_is_own_village_matching_level() -> void:
	_inject_village(4, 4, actor)
	_inject_tile(4, 4, 0, TileDefinition.TileType.PLAINS, {})
	actor.hand[0] = TileDefinition.new(TileDefinition.TileType.PLAINS, {TileDefinition.ResourceType.FERVOR: 1}, 2)
	board.power_hand_index = 0
	var power := ChangeTileTypePower.new()
	assert_bool(power.is_valid_target(board, 4, 4)).is_true()


func test_change_tile_type_invalid_target_on_enemy_village() -> void:
	_inject_village(4, 4, victim)
	_inject_tile(4, 4, 0, TileDefinition.TileType.PLAINS, {})
	actor.hand[0] = TileDefinition.new(TileDefinition.TileType.PLAINS, {TileDefinition.ResourceType.FERVOR: 1}, 2)
	board.power_hand_index = 0
	var power := ChangeTileTypePower.new()
	assert_bool(power.is_valid_target(board, 4, 4)).is_false()


func test_change_tile_type_invalid_target_when_level_differs() -> void:
	_inject_village(4, 4, actor)
	_inject_tile(4, 4, 0, TileDefinition.TileType.PLAINS, {})
	actor.hand[0] = TileDefinition.new(TileDefinition.TileType.HILLS, {TileDefinition.ResourceType.MATERIALS: 2}, 4)
	board.power_hand_index = 0
	var power := ChangeTileTypePower.new()
	assert_bool(power.is_valid_target(board, 4, 4)).is_false()


func test_change_tile_type_invalid_target_when_hand_slot_empty() -> void:
	_inject_village(4, 4, actor)
	_inject_tile(4, 4, 0, TileDefinition.TileType.PLAINS, {})
	board.power_hand_index = 0
	var power := ChangeTileTypePower.new()
	assert_bool(power.is_valid_target(board, 4, 4)).is_false()


func test_change_tile_type_invalid_target_when_no_hand_tile_picked() -> void:
	_inject_village(4, 4, actor)
	_inject_tile(4, 4, 0, TileDefinition.TileType.PLAINS, {})
	actor.hand[0] = TileDefinition.new(TileDefinition.TileType.PLAINS, {TileDefinition.ResourceType.FERVOR: 1}, 2)
	var power := ChangeTileTypePower.new()
	assert_bool(power.is_valid_target(board, 4, 4)).is_false()


func test_change_tile_type_apply_effect_swaps_board_and_hand_tiles() -> void:
	_inject_village(4, 4, actor)
	var tile := _inject_tile(4, 4, 0, TileDefinition.TileType.PLAINS, {
		TileDefinition.ResourceType.MATERIALS: 2,
	})
	actor.hand[0] = TileDefinition.new(TileDefinition.TileType.PLAINS, {TileDefinition.ResourceType.FERVOR: 1}, 2)
	board.power_hand_index = 0
	var power := ChangeTileTypePower.new()
	var success := power.apply_effect(board, 4, 4)
	assert_bool(success).is_true()
	assert_bool(tile.yields.has(TileDefinition.ResourceType.FERVOR)).is_true()
	assert_object(actor.hand[0]).is_not_null()
	assert_int(actor.hand[0].tile_type).is_equal(TileDefinition.TileType.PLAINS)
	assert_bool(actor.hand[0].yields.has(TileDefinition.ResourceType.MATERIALS)).is_true()


func test_change_tile_type_resolve_fails_and_pays_nothing_when_level_mismatch() -> void:
	_inject_village(4, 4, actor)
	_inject_tile(4, 4, 0, TileDefinition.TileType.PLAINS, {})
	actor.hand[0] = TileDefinition.new(TileDefinition.TileType.HILLS, {TileDefinition.ResourceType.MATERIALS: 2}, 4)
	board.power_hand_index = 0
	var power := ChangeTileTypePower.new()
	var success := power.resolve(board, 4, 4)
	assert_bool(success).is_false()
	assert_int(actor.fervor).is_equal(20)
	assert_int(actor.actions_remaining).is_equal(5)


func test_change_tile_type_resolve_pays_cost_and_swaps_when_valid() -> void:
	_inject_village(4, 4, actor)
	_inject_tile(4, 4, 0, TileDefinition.TileType.PLAINS, {
		TileDefinition.ResourceType.MATERIALS: 2,
	})
	actor.hand[0] = TileDefinition.new(TileDefinition.TileType.PLAINS, {TileDefinition.ResourceType.FERVOR: 1}, 2)
	board.power_hand_index = 0
	var power := ChangeTileTypePower.new()
	var success := power.resolve(board, 4, 4)
	assert_bool(success).is_true()
	assert_int(actor.fervor).is_equal(18)  # 20 - 2
	assert_int(actor.actions_remaining).is_equal(4)
	assert_object(actor.hand[0]).is_not_null()
	assert_int(actor.hand[0].tile_type).is_equal(TileDefinition.TileType.PLAINS)
	assert_bool(actor.hand[0].yields.has(TileDefinition.ResourceType.MATERIALS)).is_true()


# --- ChangeTileTypePower.can_afford — its extra_afford_check override ---

func test_change_tile_type_can_afford_false_when_hand_empty() -> void:
	var power := ChangeTileTypePower.new()
	assert_bool(power.can_afford(actor)).is_false()


func test_change_tile_type_can_afford_true_when_hand_has_tile() -> void:
	actor.hand[0] = TileDefinition.new(TileDefinition.TileType.PLAINS, {TileDefinition.ResourceType.MATERIALS: 1}, 2)
	var power := ChangeTileTypePower.new()
	assert_bool(power.can_afford(actor)).is_true()
