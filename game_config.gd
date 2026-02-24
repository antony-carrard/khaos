extends Node

## Global game configuration set from the main menu before loading the game scene.
## Board manager reads these values in _ready() when initialized == true.
## Falls back to @export values when running main.tscn directly from the editor.

enum GameMode { HOT_SEAT, NETWORK }

var mode: GameMode = GameMode.HOT_SEAT
var player_count: int = 2
var initialized: bool = false  # true only when coming from the main menu
