class_name PlacementStrategy extends RefCounted

var uses_tile_preview: bool = false  # TilePlacementStrategy overrides to true


## Click handler. Returns true if action succeeded and placement should end.
func on_click(_controller: PlacementController, _q: int, _r: int) -> bool:
	return false


## Validity check for preview coloring.
func get_validity(_controller: PlacementController, _q: int, _r: int) -> bool:
	return false


## Update tooltip (default: hide).
func update_tooltip(controller: PlacementController, _q: int, _r: int, _is_valid: bool) -> void:
	if controller.board_manager and controller.board_manager.ui:
		controller.board_manager.ui.show_village_sell_tooltip(false)
