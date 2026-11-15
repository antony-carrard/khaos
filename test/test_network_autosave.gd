extends GdUnitTestSuite

# NetworkSync's autosave: written by broadcast_state() after every action,
# removed by broadcast_game_over(). Played as the host of a network game with no
# seated clients, so no RPC actually goes out — and, at the end, as a hot-seat
# game, which autosaves through the same calls.

const BoardManagerScript := preload("res://managers/board_manager.gd")

var board: Node3D
var sync: NetworkSync
var _saved_config: Array


func before_test() -> void:
	_saved_config = [GameConfig.initialized, GameConfig.mode, NetworkManager.is_host]
	GameConfig.initialized = true
	GameConfig.mode = GameConfig.GameMode.NETWORK
	NetworkManager.is_host = true

	var alice: Player = auto_free(Player.new())
	alice.initialize("Alice", Color.BLUE)
	alice.initialize_game_start(AugiaGod.new(), false)
	var typed_players: Array[Player] = [alice]

	var tile_manager: TileManager = auto_free(TileManager.new())
	var village_manager: VillageManager = auto_free(VillageManager.new())
	village_manager.tile_manager = tile_manager
	var tile_pool: TilePool = auto_free(TilePool.new())
	tile_pool.initialize(12345)

	board = auto_free(BoardManagerScript.new())
	board.tile_manager = tile_manager
	board.village_manager = village_manager
	board.tile_pool = tile_pool
	board.players = typed_players
	board.current_player_index = 0
	board.current_player = alice

	sync = auto_free(NetworkSync.new())
	sync.board = board
	sync.autosave_path = "user://test_autosave_%d.dat" % Time.get_ticks_usec()


func after_test() -> void:
	DirAccess.remove_absolute(sync.autosave_path)
	GameConfig.initialized = _saved_config[0]
	GameConfig.mode = _saved_config[1]
	NetworkManager.is_host = _saved_config[2]


func test_host_broadcast_autosaves_the_current_game() -> void:
	sync.broadcast_state()

	assert_dict(GameState.load_from_file(sync.autosave_path)).is_equal(GameState.capture(board))


func test_autosave_follows_the_latest_action() -> void:
	sync.broadcast_state()
	board.players[0].materials = 7
	sync.broadcast_state()

	assert_int(GameState.load_from_file(sync.autosave_path)["players"][0]["materials"]).is_equal(7)


func test_game_over_removes_the_autosave() -> void:
	sync.broadcast_state()
	sync.broadcast_game_over()

	assert_bool(FileAccess.file_exists(sync.autosave_path)).is_false()


func test_client_never_autosaves() -> void:
	NetworkManager.is_host = false
	sync.broadcast_state()

	assert_bool(FileAccess.file_exists(sync.autosave_path)).is_false()


func test_hot_seat_autosaves_the_current_game() -> void:
	GameConfig.mode = GameConfig.GameMode.HOT_SEAT
	sync.broadcast_state()

	assert_dict(GameState.load_from_file(sync.autosave_path)).is_equal(GameState.capture(board))


func test_hot_seat_game_over_removes_the_autosave() -> void:
	GameConfig.mode = GameConfig.GameMode.HOT_SEAT
	sync.broadcast_state()
	sync.broadcast_game_over()

	assert_bool(FileAccess.file_exists(sync.autosave_path)).is_false()


func test_game_run_from_the_editor_never_autosaves() -> void:
	GameConfig.mode = GameConfig.GameMode.HOT_SEAT
	GameConfig.initialized = false
	sync.broadcast_state()

	assert_bool(FileAccess.file_exists(sync.autosave_path)).is_false()


func test_each_mode_autosaves_to_its_own_slot() -> void:
	assert_str(GameState.autosave_path_for(GameConfig.GameMode.NETWORK)).is_equal(GameState.NETWORK_AUTOSAVE_PATH)
	assert_str(GameState.autosave_path_for(GameConfig.GameMode.HOT_SEAT)).is_equal(GameState.LOCAL_AUTOSAVE_PATH)
