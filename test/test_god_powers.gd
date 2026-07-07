extends GdUnitTestSuite

# Concrete TargetedGodPower subclasses: is_valid_target + resolve_effect,
# migrated verbatim from the old PlacementStrategy.get_validity() /
# PowerExecutor.on_*() methods. Tiles/villages are injected directly into
# the managers' internal dictionaries (established repo test pattern) rather
# than placed through the full placement flow.
#
# NOTE: upgrade_tile()/downgrade_tile() themselves instantiate a real
# hex_tile_scene (StaticBody3D) — per repo policy (see test_victory_scoring.gd)
# those scene-dependent effects aren't re-verified here; only is_valid_target
# is tested for the two tile-height powers. resolve_effect for those is
# covered by the Stage 2 manual playtest.

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
	var success := power.resolve_effect(board, 0, 0, TargetedGodPower.NO_EXTRA)
	assert_bool(success).is_true()
	assert_object(village_manager.get_village_at(0, 0)).is_null()


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
	var success := power.resolve_effect(board, 1, 1, TargetedGodPower.NO_EXTRA)
	assert_bool(success).is_true()
	assert_int(actor.materials).is_equal(3)
	assert_int(actor.glory).is_equal(1)


func test_steal_harvest_resolve_effect_fails_without_tile() -> void:
	_inject_village(1, 1, victim)
	var power := StealHarvestPower.new()
	var success := power.resolve_effect(board, 1, 1, TargetedGodPower.NO_EXTRA)
	assert_bool(success).is_false()


# --- UpgradeTileKeepVillagePower (Augia major) — validity only, see note above ---

func test_upgrade_valid_target_own_village_upgradable_tile_in_bag() -> void:
	_inject_village(2, 2, actor)
	_inject_tile(2, 2, 0, TileDefinition.TileType.PLAINS, {})
	var power := UpgradeTileKeepVillagePower.new()
	assert_bool(power.is_valid_target(board, 2, 2)).is_true()


func test_upgrade_invalid_on_enemy_village() -> void:
	_inject_village(2, 2, victim)
	_inject_tile(2, 2, 0, TileDefinition.TileType.PLAINS, {})
	var power := UpgradeTileKeepVillagePower.new()
	assert_bool(power.is_valid_target(board, 2, 2)).is_false()


func test_upgrade_invalid_when_already_mountain() -> void:
	_inject_village(2, 2, actor)
	_inject_tile(2, 2, 2, TileDefinition.TileType.MOUNTAIN, {})
	var power := UpgradeTileKeepVillagePower.new()
	assert_bool(power.is_valid_target(board, 2, 2)).is_false()


func test_upgrade_invalid_when_bag_has_no_next_type() -> void:
	_inject_village(2, 2, actor)
	_inject_tile(2, 2, 0, TileDefinition.TileType.PLAINS, {})
	for i in tile_pool.get_remaining_count():
		tile_pool.draw_tile()
	var power := UpgradeTileKeepVillagePower.new()
	assert_bool(power.is_valid_target(board, 2, 2)).is_false()


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


func test_downgrade_invalid_when_already_plains() -> void:
	_inject_village(3, 3, victim)
	_inject_tile(3, 3, 0, TileDefinition.TileType.PLAINS, {})
	var power := DowngradeTileKeepVillagePower.new()
	assert_bool(power.is_valid_target(board, 3, 3)).is_false()


# --- ChangeTileTypePower (Augia minor) ---

func test_change_tile_type_valid_target_is_own_village() -> void:
	_inject_village(4, 4, actor)
	var power := ChangeTileTypePower.new()
	assert_bool(power.is_valid_target(board, 4, 4)).is_true()


func test_change_tile_type_invalid_on_enemy_village() -> void:
	_inject_village(4, 4, victim)
	var power := ChangeTileTypePower.new()
	assert_bool(power.is_valid_target(board, 4, 4)).is_false()


func test_change_tile_type_resolve_effect_swaps_yields_and_draws_from_bag() -> void:
	_inject_village(4, 4, actor)
	var tile := _inject_tile(4, 4, 0, TileDefinition.TileType.PLAINS, {
		TileDefinition.ResourceType.MATERIALS: 2,
	})
	var before_count := tile_pool.get_remaining_count()
	var power := ChangeTileTypePower.new()
	var success := power.resolve_effect(board, 4, 4, TileDefinition.ResourceType.FERVOR)
	assert_bool(success).is_true()
	assert_bool(tile.yields.has(TileDefinition.ResourceType.FERVOR)).is_true()
	assert_int(tile_pool.get_remaining_count()).is_equal(before_count - 1)


func test_change_tile_type_resolve_effect_rejects_glory_on_plains() -> void:
	_inject_village(4, 4, actor)
	_inject_tile(4, 4, 0, TileDefinition.TileType.PLAINS, {
		TileDefinition.ResourceType.MATERIALS: 2,
	})
	var power := ChangeTileTypePower.new()
	var success := power.resolve_effect(board, 4, 4, TileDefinition.ResourceType.GLORY)
	assert_bool(success).is_false()


func test_change_tile_type_resolve_only_pays_cost_on_success() -> void:
	_inject_village(4, 4, actor)
	_inject_tile(4, 4, 0, TileDefinition.TileType.PLAINS, {
		TileDefinition.ResourceType.MATERIALS: 2,
	})
	var power := ChangeTileTypePower.new()
	# GLORY on PLAINS is invalid -> resolve_effect fails -> cost must not be paid.
	var success := power.resolve(board, 4, 4, TileDefinition.ResourceType.GLORY)
	assert_bool(success).is_false()
	assert_int(actor.fervor).is_equal(20)
	assert_int(actor.actions_remaining).is_equal(5)


func test_change_tile_type_resolve_pays_cost_when_valid() -> void:
	_inject_village(4, 4, actor)
	_inject_tile(4, 4, 0, TileDefinition.TileType.PLAINS, {
		TileDefinition.ResourceType.MATERIALS: 2,
	})
	var power := ChangeTileTypePower.new()
	var success := power.resolve(board, 4, 4, TileDefinition.ResourceType.FERVOR)
	assert_bool(success).is_true()
	assert_int(actor.fervor).is_equal(18)  # 20 - 2
	assert_int(actor.actions_remaining).is_equal(4)
