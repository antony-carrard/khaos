extends GdUnitTestSuite

# board_manager.gd's demolition-cost consolidation (_compute_demolition_cost),
# the fresh-adjacent-village action surcharge, and the turn-scoped
# villages_built_this_turn / villages_demolished_this_turn tracking that feeds
# it and Le Démolisseur's Échafaudage passive.
#
# board_manager.gd has no class_name (it's the top-level scene script) and its
# _ready() wires up UI/scene nodes we don't want here, so it's instantiated
# directly via its script and driven without ever entering the scene tree —
# tiles/villages injected straight into the managers' dictionaries, same
# pattern as test_god_powers.gd.

const BoardManagerScript := preload("res://managers/board_manager.gd")

var actor: Player
var victim: Player
var board: Node3D
var tile_manager: TileManager
var village_manager: VillageManager
var _bare_tiles: Array[HexTile] = []


func before_test() -> void:
	actor = auto_free(Player.new())
	actor.initialize("Actor", Color.BLUE)
	actor.god = God.new("Test God")
	actor.materials = 999
	actor.fervor = 999
	actor.actions_remaining = 999
	actor.glory = 0

	victim = auto_free(Player.new())
	victim.initialize("Victim", Color.RED)

	tile_manager = auto_free(TileManager.new())
	tile_manager.max_stack_height = 3
	village_manager = auto_free(VillageManager.new())
	village_manager.tile_manager = tile_manager

	var typed_players: Array[Player] = [actor, victim]

	board = auto_free(BoardManagerScript.new())
	board.tile_manager = tile_manager
	board.village_manager = village_manager
	board.players = typed_players
	board.current_player_index = 0
	board.current_player = actor


func after_test() -> void:
	for tile in _bare_tiles:
		tile.call_deferred("free")
	_bare_tiles.clear()


func _inject_tile(q: int, r: int, height: int, cost: int = 2) -> HexTile:
	var tile := HexTile.new()
	tile.q = q
	tile.r = r
	tile.height_level = height
	tile.tile_type = TileDefinition.TileType.PLAINS
	tile.village_building_cost = cost
	tile.yields = {}
	tile_manager.placed_tiles[Vector3i(q, r, height)] = tile
	_bare_tiles.append(tile)
	return tile


func _inject_village(q: int, r: int, owner: Player) -> Village:
	var village := Village.new()
	village.set_grid_position(q, r)
	village.set_player_owner(owner)
	village_manager.placed_villages[Vector2i(q, r)] = village
	if not village_manager.player_villages.has(owner):
		village_manager.player_villages[owner] = [] as Array[Village]
	village_manager.player_villages[owner].append(village)
	return village


# --- Fresh-adjacent-village action surcharge ---

func test_no_surcharge_with_a_stale_adjacent_village() -> void:
	_inject_tile(0, 0, 0)
	_inject_village(0, 0, victim)
	_inject_tile(1, 0, 0)
	_inject_village(1, 0, actor)  # not in villages_built_this_turn -> "stale"

	var cost = board._compute_demolition_cost(0, 0)
	assert_int(cost["act_cost"]).is_equal(1)


func test_surcharge_when_only_a_freshly_built_village_is_adjacent() -> void:
	_inject_tile(0, 0, 0)
	_inject_village(0, 0, victim)
	_inject_tile(1, 0, 0)
	_inject_village(1, 0, actor)
	board.villages_built_this_turn[Vector2i(1, 0)] = true

	var cost = board._compute_demolition_cost(0, 0)
	assert_int(cost["act_cost"]).is_equal(2)


func test_no_surcharge_when_a_stale_village_is_also_adjacent() -> void:
	_inject_tile(0, 0, 0)
	_inject_village(0, 0, victim)
	_inject_tile(1, 0, 0)
	_inject_village(1, 0, actor)
	board.villages_built_this_turn[Vector2i(1, 0)] = true
	_inject_tile(-1, 0, 0)
	_inject_village(-1, 0, actor)  # stale, so the fresh village isn't the only option

	var cost = board._compute_demolition_cost(0, 0)
	assert_int(cost["act_cost"]).is_equal(1)


# --- Turn-scoped tracking populated by the real placement/demolition paths ---

func test_on_village_placed_marks_the_position_built_this_turn() -> void:
	_inject_tile(2, 0, 0)
	var success = board.on_village_placed(2, 0)
	assert_bool(success).is_true()
	assert_bool(board.villages_built_this_turn.get(Vector2i(2, 0), false)).is_true()


func test_on_village_removed_records_the_demolition_with_adjacent_village() -> void:
	_inject_tile(0, 0, 0)
	_inject_village(0, 0, victim)
	_inject_tile(1, 0, 0)
	_inject_village(1, 0, actor)

	var success = board.on_village_removed(0, 0)
	assert_bool(success).is_true()
	assert_bool(board.villages_demolished_this_turn.get(Vector2i(0, 0), false)).is_true()


func test_begin_turn_clears_the_turn_scoped_tracking() -> void:
	board.villages_built_this_turn[Vector2i(0, 0)] = true
	board.villages_demolished_this_turn[Vector2i(1, 1)] = true

	board._begin_turn(actor)

	assert_bool(board.villages_built_this_turn.is_empty()).is_true()
	assert_bool(board.villages_demolished_this_turn.is_empty()).is_true()


# --- Le Démolisseur's Échafaudage passive, wired through board_manager ---
# (modify_rebuild_cost()'s own halving logic is unit-tested in isolation in
# test_god.gd; these confirm board_manager feeds it the right turn-tracking fact.)

func test_compute_village_cost_halves_on_a_tile_demolished_this_turn_with_adjacency() -> void:
	actor.god = LeDemolisseurGod.new()
	var tile := _inject_tile(0, 0, 0, 2)
	board.villages_demolished_this_turn[Vector2i(0, 0)] = true

	assert_int(board._compute_village_cost(tile)).is_equal(1)


func test_compute_village_cost_charges_full_when_not_demolished_this_turn() -> void:
	actor.god = LeDemolisseurGod.new()
	var tile := _inject_tile(0, 0, 0, 2)

	assert_int(board._compute_village_cost(tile)).is_equal(2)


func test_compute_village_cost_charges_full_when_demolished_without_adjacency() -> void:
	actor.god = LeDemolisseurGod.new()
	var tile := _inject_tile(0, 0, 0, 2)
	board.villages_demolished_this_turn[Vector2i(0, 0)] = false

	assert_int(board._compute_village_cost(tile)).is_equal(2)
