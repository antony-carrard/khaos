extends Node3D

class_name ResourcePopupManager

## Spawns ResourcePopup3D effects above hexes whenever a player's resources
## change. A single entry point (spawn()) lets every gain-granting code path —
## tile placement bounty, village construction/demolition glory, turn-start
## harvest, powers — trigger the same visual without duplicating layout logic.
##
## Concurrent popups at the same hex (e.g. a village harvesting on the turn it
## is also targeted by a power) are stacked vertically rather than overlapping,
## tracked per hex and released when each popup finishes its animation.

# Villages stand roughly 0.5 units tall above their own anchor (measured from
# village.glb's mesh bounds), so a popup anchored at the tile surface spawns at
# the village's feet and reads as buried in the model. Clear the rooftop instead.
const SPAWN_HEIGHT_OFFSET: float = 0.85
const STACK_HEIGHT_STEP: float = 0.6

var _active_at_hex: Dictionary[Vector2i, int] = {}


## Spawns a popup above the hex at (q, r, height_level) listing every positive
## entry in `yields` (TileDefinition.ResourceType -> amount). Non-positive
## entries are dropped and a call with nothing left to show is a no-op, so
## callers can pass a raw yields/totals dict without pre-filtering.
func spawn(q: int, r: int, height_level: int, yields: Dictionary) -> void:
	var positive_yields: Dictionary = {}
	for res_type in yields:
		if yields[res_type] > 0:
			positive_yields[res_type] = yields[res_type]
	if positive_yields.is_empty():
		return

	var hex_key := Vector2i(q, r)
	var stack_index: int = _active_at_hex.get(hex_key, 0)
	_active_at_hex[hex_key] = stack_index + 1

	var popup := ResourcePopup3D.new()
	add_child(popup)
	var base_pos := HexGridUtils.axial_to_world(q, r, height_level)
	base_pos.y += SPAWN_HEIGHT_OFFSET + stack_index * STACK_HEIGHT_STEP
	popup.global_position = base_pos
	popup.finished.connect(_on_popup_finished.bind(hex_key), CONNECT_ONE_SHOT)
	popup.setup(positive_yields)


func _on_popup_finished(hex_key: Vector2i) -> void:
	_active_at_hex[hex_key] = max(0, _active_at_hex.get(hex_key, 1) - 1)
