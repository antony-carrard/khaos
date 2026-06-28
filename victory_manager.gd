extends Node

class_name VictoryManager

## Victory point calculation and endgame scoring system.
## Implements territory calculation using flood-fill algorithm.


## Calculate complete score breakdown for a player.
## Returns dictionary with all scoring categories and total.
func calculate_player_score(player: Player, village_manager: VillageManager) -> Dictionary:
	# Resource/Fervor pairs (floor division)
	var resource_pts: int = int(player.resources / 2.0)
	var fervor_pts: int = int(player.fervor / 2.0)

	# Glory (1:1 ratio) — includes glory earned during the game from village placement/demolition
	var glory_pts = player.glory

	# Territory bonus using flood-fill (2 pts per village in largest cluster)
	var territory_data = _calculate_territory_points(player, village_manager)

	# Calculate total
	var total = resource_pts + fervor_pts + glory_pts + territory_data.points

	return {
		"resource_points": resource_pts,
		"fervor_points": fervor_pts,
		"glory_points": glory_pts,
		"territory_points": territory_data.points,
		"territory_breakdown": territory_data.breakdown,
		"total": total
	}



## Calculate territory bonus points from contiguous village groups.
## Uses flood-fill algorithm to find connected components.
## Only the LARGEST group scores points (encourages consolidation strategy).
func _calculate_territory_points(player: Player, village_manager: VillageManager) -> Dictionary:
	var groups = _find_contiguous_groups(player, village_manager)
	var total_points = 0
	var breakdown = ""

	# Sort groups by size (largest first)
	groups.sort_custom(func(a, b): return a.size() > b.size())

	# Only score the largest group
	if groups.size() > 0:
		var largest_size = groups[0].size()
		total_points = _calculate_territory_score(largest_size)

		breakdown = "  Largest cluster: %d villages × 2 = %d pts" % [largest_size, total_points]

		# Debug: Print all groups to console for balancing
		if groups.size() > 1:
			var all_sizes = []
			for group in groups:
				all_sizes.append(group.size())
			Log.debug("VictoryManager: Territory groups: %s (largest scores: %d pts)" % [all_sizes, total_points])
	else:
		breakdown = "  No territory bonuses"

	return {
		"points": total_points,
		"breakdown": breakdown.strip_edges()
	}


## Find all contiguous groups of villages using flood-fill algorithm.
## Returns array of groups, where each group is an array of Vector2i positions.
func _find_contiguous_groups(player: Player, village_manager: VillageManager) -> Array[Array]:
	var player_villages = village_manager.get_villages_for_player(player)
	var visited = {}  # Dictionary of Vector2i -> bool
	var groups: Array[Array] = []

	# Start flood-fill from each unvisited village
	for village in player_villages:
		var pos = Vector2i(village.q, village.r)
		if visited.has(pos):
			continue

		# Find all villages connected to this one
		var group = _flood_fill_group(pos, player, village_manager, visited)
		if group.size() > 0:
			groups.append(group)

	return groups


## Flood-fill from starting position to find all connected villages.
## Uses BFS (breadth-first search) to explore adjacent hexes.
func _flood_fill_group(start_pos: Vector2i, player: Player,
					  village_manager: VillageManager,
					  visited: Dictionary) -> Array[Vector2i]:
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
		var neighbors = HexGridUtils.get_axial_neighbors(pos.x, pos.y)
		for neighbor in neighbors:
			if not visited.has(neighbor):
				queue.append(neighbor)

	return group


func _calculate_territory_score(group_size: int) -> int:
	return group_size * 2
