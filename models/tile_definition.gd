class_name TileDefinition

enum TileType {
	PLAINS,
	HILLS,
	MOUNTAIN
}

enum ResourceType {
	MATERIALS,
	FERVOR,
	GLORY
}

## Base village build/demolition cost by tile type (rules.md: 2/4/6 for plains/hills/mountain).
const VILLAGE_COST_BY_TYPE = {
	TileType.PLAINS: 2,
	TileType.HILLS: 4,
	TileType.MOUNTAIN: 6,
}

## Standard (most common) yields per tile type, mirroring TilePool's base tiles. Used by
## debug tile placement (1/2/3 keyboard shortcuts), which has no hand TileDefinition to draw from.
const STANDARD_YIELDS_BY_TYPE = {
	TileType.PLAINS: {ResourceType.MATERIALS: 1},
	TileType.HILLS: {ResourceType.MATERIALS: 2},
	TileType.MOUNTAIN: {ResourceType.MATERIALS: 3, ResourceType.GLORY: 1},
}

var tile_type: int               # TileType
var yields: Dictionary           # ResourceType → amount, e.g. {MATERIALS: 3, GLORY: 1}
var village_building_cost: int

func _init(t: int, y: Dictionary, cost: int) -> void:
	tile_type = t
	yields = y
	village_building_cost = cost


## Returns the resource type with the highest yield amount.
## Used as the "primary" type for icon display and single-value contexts.
func primary_resource_type() -> int:
	var best_type = ResourceType.MATERIALS
	var best_val = 0
	for res in yields:
		if yields[res] > best_val:
			best_val = yields[res]
			best_type = res
	return best_type


## Human-readable yield summary, e.g. "3M+1G" or "2F"
static func format_yields(tile_yields: Dictionary) -> String:
	var prefixes = {
		ResourceType.MATERIALS: "M",
		ResourceType.FERVOR: "F",
		ResourceType.GLORY: "G"
	}
	var parts: Array[String] = []
	for res_type in tile_yields:
		parts.append("%d%s" % [tile_yields[res_type], prefixes.get(res_type, "?")])
	return "+".join(parts)
