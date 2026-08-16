class_name StealHarvestPower
extends GodPower

## Rakun minor power — harvest an enemy village's tile yield directly.

func _init():
	super("Vol de récolte", "Choisir un bâtiment d'un autre dieu et récolter ses possessions", 2)


func is_valid_target(board_manager: Node3D, q: int, r: int) -> bool:
	var village = board_manager.village_manager.get_village_at(q, r)
	return village != null and village.player_owner != board_manager.current_player


func apply_effect(board_manager: Node3D, q: int, r: int) -> bool:
	var tile = board_manager.tile_manager.get_tile_at(q, r)
	if not tile:
		Log.error("StealHarvestPower: village at (%d,%d) has no tile" % [q, r])
		return false

	steal_yields(board_manager.current_player, tile.yields)
	board_manager.show_resource_gain(q, r, tile.height_level, tile.yields)
	return true


## Grants `player` the resources listed in `tile_yields` (a tile's `yields`
## dict). Shared by this minor power's direct steal, Rakun's demolish-triggered
## passive (God.on_village_demolished), and DowngradeTileKeepVillagePower's
## stolen-tile branch. Purely a resource grant — callers show their own popup
## so a single player action that grants more than one thing (e.g. downgrade's
## steal + glory) can merge them into one instead of stacking two.
static func steal_yields(player: Player, tile_yields: Dictionary) -> void:
	player.receive_yields(tile_yields)
	Log.info("Stole yields from enemy village: %s" % TileDefinition.format_yields(tile_yields))


func update_tooltip(controller: PlacementController, q: int, r: int, is_valid: bool) -> void:
	if not (controller.board_manager and controller.board_manager.ui):
		return
	if is_valid:
		var tile = controller.tile_manager.get_tile_at(q, r)
		if tile:
			var total_yield = 0
			for v in tile.yields.values(): total_yield += v
			controller.board_manager.ui.show_resource_gain_tooltip(true, total_yield)
			return
	controller.board_manager.ui.show_resource_gain_tooltip(false)
