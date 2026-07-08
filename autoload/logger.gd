extends Node

enum Level { DEBUG, INFO, WARN, ERROR }

# Debug builds: show everything. Release: only WARN and ERROR.
var current_level: Level = Level.DEBUG if OS.is_debug_build() else Level.WARN

func debug(msg: String) -> void:
	if current_level <= Level.DEBUG:
		print("[DEBUG] " + msg)

func info(msg: String) -> void:
	if current_level <= Level.INFO:
		print("[INFO] " + msg)

func warn(msg: String) -> void:
	push_warning(msg)   # always visible in editor; no-op in release logs

func error(msg: String) -> void:
	push_error(msg)     # always visible, surfaces in debugger
