extends GdUnitTestSuite

# +N popups in a network game: show_resource_gain() shows the host's own, queues
# a client's on NetworkSync, and broadcast_state() sends the queue on. Played as
# the host with no seated clients, so no RPC actually goes out.

const BoardManagerScript := preload("res://managers/board_manager.gd")
const GAIN := {TileDefinition.ResourceType.GLORY: 2}

var board: Node3D
var _saved_config: Array


func before_test() -> void:
	_saved_config = [GameConfig.initialized, GameConfig.mode, NetworkManager.is_host]
	GameConfig.initialized = true
	GameConfig.mode = GameConfig.GameMode.NETWORK
	NetworkManager.is_host = true

	var typed_players: Array[Player] = []
	for player_name in ["Alice", "Bob"]:
		var player: Player = auto_free(Player.new())
		player.initialize(player_name, Color.BLUE)
		player.initialize_game_start(AugiaGod.new(), false)
		typed_players.append(player)

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
	board.current_player = typed_players[0]
	board.local_player_index = 0
	board.ui_player = typed_players[0]
	board.network.board = board
	board.network.autosave_path = "user://test_popups_%d.dat" % Time.get_ticks_usec()


func after_test() -> void:
	DirAccess.remove_absolute(board.network.autosave_path)
	board.network.free()
	GameConfig.initialized = _saved_config[0]
	GameConfig.mode = _saved_config[1]
	NetworkManager.is_host = _saved_config[2]


func test_host_own_gain_is_not_queued() -> void:
	board.show_resource_gain(board.players[0], 1, 2, 0, GAIN)

	assert_array(board.network.pending_popups).is_empty()


func test_client_gain_is_queued_for_that_player() -> void:
	board.show_resource_gain(board.players[1], 1, 2, 0, GAIN)

	assert_array(board.network.pending_popups).is_equal([[1, 1, 2, 0, GAIN]])


func test_broadcast_sends_the_queue_on() -> void:
	board.show_resource_gain(board.players[1], 1, 2, 0, GAIN)
	board.network.broadcast_state()

	assert_array(board.network.pending_popups).is_empty()


func test_hot_seat_queues_nothing() -> void:
	GameConfig.mode = GameConfig.GameMode.HOT_SEAT
	board.show_resource_gain(board.players[1], 1, 2, 0, GAIN)

	assert_array(board.network.pending_popups).is_empty()
