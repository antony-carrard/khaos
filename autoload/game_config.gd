extends Node

## Global game configuration set from the main menu before loading the game scene.
## Board manager reads these values in _ready() when initialized == true.
## Falls back to @export values when running main.tscn directly from the editor.

enum GameMode { HOT_SEAT, NETWORK }

var mode: GameMode = GameMode.HOT_SEAT
var player_count: int = 2
var player_names: Array[String] = []  # indexed by player_index; empty = use "Player N" defaults
var local_player_index: int = 0  # which player index belongs to this machine (network mode only)
var initialized: bool = false  # true only when coming from the main menu
var network_rng_seed: int = 0   # shared RNG seed for deterministic tile bag across all machines
