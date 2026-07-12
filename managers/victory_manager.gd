extends Node

class_name VictoryManager

## Victory point calculation and endgame scoring system.
## Implements territory calculation using flood-fill algorithm.

const TERRITORY_CEILING = 5


## Calculate complete score breakdown for a player.
## Returns dictionary with all scoring categories and total.
func calculate_player_score(player: Player, village_manager: VillageManager) -> Dictionary:
	# Glory (1:1 ratio) — includes glory earned during the game from village placement/demolition
	var glory_pts = player.glory

	# Territory bonus using flood-fill (bonus glory points per villages in largest cluster)
	var territory_data = _calculate_territory_points(player, village_manager)

	# Calculate total
	var total = glory_pts + territory_data.points

	return {
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

		var formula = _format_territory_formula(largest_size)
		breakdown = "  Largest cluster: %d villages\n  %s = %d pts" % [largest_size, formula, total_points]

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

# The subsequent bonus glory is equal to the capped ceiling
func _calculate_territory_score(nb_villages: int) -> int:
	var n = min(nb_villages, TERRITORY_CEILING)
	var base = n * (n + 1) / 2      # 1, 3, 6, 10, 15
	var bonus = max(0, nb_villages - TERRITORY_CEILING) * TERRITORY_CEILING		# Then + 5 for each bonus village
	return base + bonus


## Builds a human-readable formula matching _calculate_territory_score, e.g.
## 7 villages -> "1 + 2 + 3 + 4 + (3 × 5)". Villages beyond the ceiling all
## score a flat TERRITORY_CEILING each, so they collapse into one term —
## the string never grows past TERRITORY_CEILING terms no matter the village count.
func _format_territory_formula(nb_villages: int) -> String:
	if nb_villages <= 0:
		return ""

	var terms: Array[String] = []
	var individual_count = min(nb_villages, TERRITORY_CEILING - 1)
	for i in range(1, individual_count + 1):
		terms.append(str(i))

	var remaining = nb_villages - individual_count
	if remaining == 1:
		terms.append(str(TERRITORY_CEILING))
	elif remaining > 1:
		terms.append("(%d × %d)" % [remaining, TERRITORY_CEILING])

	return " + ".join(terms)
