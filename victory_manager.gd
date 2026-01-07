extends Node

class_name VictoryManager

## Victory point calculation and endgame scoring system.
## Implements territory calculation using flood-fill algorithm.

# Configurable territory scoring formula
enum TerritoryFormula {
	SIMPLE,       # n (group size)
	LINEAR,       # n - 1 (penalizes isolation)
	PROGRESSIVE   # (n-1) × n (strong clustering reward)
}

# Current formula (can be changed easily)
const TERRITORY_FORMULA = TerritoryFormula.SIMPLE


## Calculate complete score breakdown for a player.
## Returns dictionary with all scoring categories and total.
func calculate_player_score(player: Player, village_manager: VillageManager,
                           tile_manager: TileManager, board_manager) -> Dictionary:
	# Village points by terrain type
	var village_data = _calculate_village_points(player, village_manager, tile_manager)

	# Resource/Fervor pairs (floor division)
	var resource_pts = player.resources / 2
	var fervor_pts = player.fervor / 2

	# Glory (1:1 ratio)
	var glory_pts = player.glory

	# Territory bonus using flood-fill
	var territory_data = _calculate_territory_points(player, village_manager, board_manager)

	# Calculate total
	var total = (village_data.total + resource_pts + fervor_pts +
	            glory_pts + territory_data.points)

	return {
		"village_points": village_data.total,
		"village_breakdown": village_data.breakdown,
		"resource_points": resource_pts,
		"fervor_points": fervor_pts,
		"glory_points": glory_pts,
		"territory_points": territory_data.points,
		"territory_breakdown": territory_data.breakdown,
		"total": total
	}


## Calculate points from villages based on terrain type.
## PLAINS = 1pt, HILLS = 2pts, MOUNTAIN = 3pts (rules.md line 175-176)
func _calculate_village_points(player: Player, village_manager: VillageManager,
                               tile_manager: TileManager) -> Dictionary:
	var villages = village_manager.get_villages_for_player(player)
	var counts = {
		TileManager.TileType.PLAINS: 0,
		TileManager.TileType.HILLS: 0,
		TileManager.TileType.MOUNTAIN: 0
	}

	# Count villages by terrain type
	for village in villages:
		var tile = tile_manager.get_tile_at(village.q, village.r)
		if tile:
			counts[tile.tile_type] += 1

	# Calculate points (1 for PLAINS, 2 for HILLS, 3 for MOUNTAIN)
	var plains_pts = counts[TileManager.TileType.PLAINS] * 1
	var hills_pts = counts[TileManager.TileType.HILLS] * 2
	var mountain_pts = counts[TileManager.TileType.MOUNTAIN] * 3

	var total = plains_pts + hills_pts + mountain_pts

	# Format breakdown string
	var breakdown = ""
	if counts[TileManager.TileType.PLAINS] > 0:
		breakdown += "  %d on PLAINS: %d pts\n" % [counts[TileManager.TileType.PLAINS], plains_pts]
	if counts[TileManager.TileType.HILLS] > 0:
		breakdown += "  %d on HILLS: %d pts\n" % [counts[TileManager.TileType.HILLS], hills_pts]
	if counts[TileManager.TileType.MOUNTAIN] > 0:
		breakdown += "  %d on MOUNTAINS: %d pts" % [counts[TileManager.TileType.MOUNTAIN], mountain_pts]

	if breakdown == "":
		breakdown = "  No villages"

	return {
		"total": total,
		"breakdown": breakdown.strip_edges()
	}


## Calculate territory bonus points from contiguous village groups.
## Uses flood-fill algorithm to find connected components.
## Only the LARGEST group scores points (encourages consolidation strategy).
func _calculate_territory_points(player: Player, village_manager: VillageManager,
                                 board_manager) -> Dictionary:
	var groups = _find_contiguous_groups(player, village_manager, board_manager)
	var total_points = 0
	var breakdown = ""

	# Sort groups by size (largest first)
	groups.sort_custom(func(a, b): return a.size() > b.size())

	# Only score the largest group
	if groups.size() > 0:
		var largest_size = groups[0].size()
		total_points = _calculate_territory_score(largest_size)

		# Only show the largest cluster (the one that scores)
		breakdown = "  Largest cluster: %d villages" % largest_size

		# Debug: Print all groups to console for balancing
		if groups.size() > 1:
			var all_sizes = []
			for group in groups:
				all_sizes.append(group.size())
			print("Territory groups: %s (largest scores: %d pts)" % [all_sizes, total_points])
	else:
		breakdown = "  No territory bonuses"

	return {
		"points": total_points,
		"breakdown": breakdown.strip_edges()
	}


## Find all contiguous groups of villages using flood-fill algorithm.
## Returns array of groups, where each group is an array of Vector2i positions.
func _find_contiguous_groups(player: Player, village_manager: VillageManager,
                             board_manager) -> Array[Array]:
	var player_villages = village_manager.get_villages_for_player(player)
	var visited = {}  # Dictionary of Vector2i -> bool
	var groups: Array[Array] = []

	# Start flood-fill from each unvisited village
	for village in player_villages:
		var pos = Vector2i(village.q, village.r)
		if visited.has(pos):
			continue

		# Find all villages connected to this one
		var group = _flood_fill_group(pos, player, village_manager, board_manager, visited)
		if group.size() > 0:
			groups.append(group)

	return groups


## Flood-fill from starting position to find all connected villages.
## Uses BFS (breadth-first search) to explore adjacent hexes.
func _flood_fill_group(start_pos: Vector2i, player: Player,
                      village_manager: VillageManager,
                      board_manager, visited: Dictionary) -> Array[Vector2i]:
	var group: Array[Vector2i] = []
	var queue: Array[Vector2i] = [start_pos]

	while queue.size() > 0:
		var pos = queue.pop_front()

		# Skip if already visited
		if visited.has(pos):
			continue

		# Check if this position has player's village
		var village = village_manager.get_village_at(pos.x, pos.y)
		if not village or village.player_owner != player:
			continue

		# Mark as visited and add to group
		visited[pos] = true
		group.append(pos)

		# Check all 6 adjacent hexes (hexagonal grid)
		var neighbors = board_manager.get_axial_neighbors(pos.x, pos.y)
		for neighbor in neighbors:
			if not visited.has(neighbor):
				queue.append(neighbor)

	return group


## Calculate score for a single territory group based on formula.
func _calculate_territory_score(group_size: int) -> int:
	match TERRITORY_FORMULA:
		TerritoryFormula.SIMPLE:
			return group_size
		TerritoryFormula.LINEAR:
			return max(0, group_size - 1)
		TerritoryFormula.PROGRESSIVE:
			return (group_size - 1) * group_size
		_:
			return 0
