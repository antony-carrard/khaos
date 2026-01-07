# Implementation Status

**Last Updated:** 2026-01-04 (Endgame and victory system complete)

This document tracks detailed implementation progress and serves as context for continuing development.

---

## ✅ Completed Features

### Core Game Systems

**Tile Management** (tile_manager.gd)
- ✅ Three tile types (PLAINS/HILLS/MOUNTAIN) with height system
- ✅ Hexagonal grid with axial coordinates (q, r)
- ✅ Placement validation (adjacency, stacking rules)
- ✅ Tile properties (resource_type, yield_value, buy_price, sell_price)
- ✅ Icon rendering (flat quad meshes with SVG textures)
- ✅ Village blocking (can't stack tiles on villages)

**Village System** (village_manager.gd, village.gd)
- ✅ Village placement on tiles
- ✅ Village ownership tracking (`player_owner` property)
- ✅ Preview system with validity coloring
- ✅ Get villages by player for harvest calculation
- ⚠️ Note: Avoided Node conflicts (`owner`, `get_position()`, `set_owner()`)

**Resource Economy** (player.gd)
- ✅ Three resource types: Resources, Fervor, Glory
- ✅ Add/spend methods with validation
- ✅ Signal-based reactive updates (`resources_changed`, `fervor_changed`, etc.)
- ✅ Hand management (draw, remove, affordability check)
- ✅ Action tracking (`actions_remaining` with signal)

**Tile Pool** (tile_pool.gd)
- ✅ 63-tile bag with rules.md distribution
  - 28 Plains (14 Resources, 14 Fervor)
  - 21 Hills (9 Resources, 9 Fervor, 3 Glory)
  - 14 Mountains (4 Resources, 4 Fervor, 6 Glory)
- ✅ TileDefinition class (blueprint pattern)
- ✅ Draw/shuffle mechanics
- ✅ Return tile to bag (for starting tile selection)
- ✅ Remaining count tracking

**Turn System** (board_manager.gd - marked for extraction)
- ✅ Turn phases (HARVEST, ACTIONS)
- ✅ Harvest phase with smart type detection
  - Auto-harvest if only one resource type available
  - Show choice UI if multiple types
- ✅ Actions phase (3 actions per turn)
- ✅ Action consumption on tile placement
- ✅ End turn flow (discard → draw 3 → reset actions → harvest)
- ✅ Turn start bonus (+1 resource, +1 fervor)

**User Interface** (tile_selector_ui.gd)
- ✅ Hand display with visual tile cards
  - Color-coded by tile type
  - Shows resource icon, yield, cost
  - Grays out unaffordable tiles (red border)
- ✅ Resource panel (wood/pray/star icons with counts)
- ✅ Turn phase UI
  - Harvest buttons (shows only available types)
  - Actions counter (visible only during actions phase)
  - End turn button
- ✅ Test mode vs Game mode (ui_mode toggle)
- ✅ Signal-connected reactive updates (no manual UI calls needed!)

**Placement Controller** (placement_controller.gd)
- ✅ Mouse-based placement with preview
- ✅ Three modes: TILE, VILLAGE_PLACE, VILLAGE_REMOVE
- ✅ Valid/invalid preview coloring
- ✅ Hand tile placement integration
- ✅ ESC to cancel placement

**Starting Conditions**
- ✅ Starting tile always PLAINS (draw/return loop until PLAINS found)
- ✅ Initial hand of 3 tiles
- ✅ Starting resources: 10 resources, 10 fervor (configurable)

**Tile Selling** (board_manager.gd, tile_selector_ui.gd, player.gd)
- ✅ Sell button on each hand card (green for sellable, gray disabled for Glory)
- ✅ Sell tile from hand for resources (Plains=1, Hills=2, Mountains=4)
- ✅ Glory tiles cannot be sold (sell_price = 0)
- ✅ Costs 1 action during actions phase
- ✅ Fixed-size hand array (3 slots) with null for empty slots
- ✅ Tiles stay anchored to position when sold (no UI shifting)
- ✅ Empty slot placeholders with disabled sell button

**Village Building Costs** (board_manager.gd, placement_controller.gd, tile_manager.gd)
- ✅ Village building costs resources based on tile type (Plains=2, Hills=4, Mountains=8)
- ✅ Costs 1 action during actions phase
- ✅ Preview shows red when player can't afford or has no actions
- ✅ Preview shows red during harvest phase (can only build during actions)
- ✅ Validation prevents placement without sufficient resources or actions

**Village Selling/Removal** (board_manager.gd, placement_controller.gd, tile_selector_ui.gd)
- ✅ Remove your own villages for half the building cost refund (Plains=1, Hills=2, Mountains=4)
- ✅ Costs 1 action during actions phase
- ✅ Mouse-following tooltip shows refund amount when hovering villages
- ✅ Tooltip only appears in remove mode when hovering your own villages
- ✅ Preview shows red for villages you don't own (ownership validation)
- ✅ Guard clause pattern for clean early returns in preview code

**Action Validation & UI Polish** (player.gd, board_manager.gd, placement_controller.gd, tile_selector_ui.gd)
- ✅ `can_place_tile()` validates both resources AND actions
- ✅ Prevents tile placement when actions exhausted
- ✅ Preview shows red when no actions available
- ✅ Black text outlines for better visibility (actions, resources, tile count)
- ✅ Auto-disable village/tile buttons when out of actions
- ✅ Consistent dimming for disabled tiles (text, icons, borders)
- ✅ Visual feedback separation: red border = unaffordable, gray = no actions
- ✅ Can sell tiles regardless of placement affordability (only requires actions)
- ✅ No focus indicators on disabled/unaffordable buttons
- ✅ Placement mode auto-cancels when phase changes

**Endgame & Victory System** (victory_manager.gd, board_manager.gd, tile_selector_ui.gd)
- ✅ Game end detection when tile bag empties (board_manager.gd:520-526)
- ✅ Final round notification with fade-out animation (tile_selector_ui.gd:755-778)
- ✅ All players complete current round before game ends (fair multiplayer)
- ✅ Territory calculation using flood-fill algorithm (victory_manager.gd:121-157)
- ✅ Configurable scoring formula (SIMPLE: n, LINEAR: n-1, PROGRESSIVE: (n-1)×n)
- ✅ Complete score breakdown (villages, resources/fervor pairs, glory, territory)
- ✅ Victory screen with detailed scoring display (tile_selector_ui.gd:781-1010)
- ✅ Winner determination with tie handling
- ✅ New Game button to restart (reloads scene)
- ✅ Scoring per rules.md: 1pt/village on plains, 2pts hills, 3pts mountains
- ✅ Resource/fervor pairs (floor division: 7 resources = 3 points)
- ✅ Territory groups scored based on contiguous villages (BFS graph traversal)
- ✅ Multiplayer-ready design (array-based score format)

---

## 🔧 Technical Decisions & Patterns

### Signal-Based Reactive State
**Pattern:**
```gdscript
# In player.gd
signal actions_changed(new_amount: int)

func consume_action() -> bool:
	actions_remaining -= 1
	actions_changed.emit(actions_remaining)  # Always emit on change

# In board_manager.gd (setup)
current_player.actions_changed.connect(ui.update_actions)

# Now UI updates automatically!
current_player.consume_action()  # No manual ui.update_actions() needed
```

**Why:** Prevents forgetting manual UI updates, similar to React state management.

### Node Built-In Conflicts Avoided
- `owner` → `player_owner` (Node.owner is scene root)
- `get_position()` → `get_grid_position()` (Node3D.get_position() is world position)
- `set_owner()` → `set_player_owner()` (Node.set_owner() is scene owner)

### Fixed-Size Hand Array Pattern
**Pattern:**
```gdscript
# In player.gd
const HAND_SIZE: int = 3
var hand: Array = [null, null, null]

func remove_from_hand(index: int):
	hand[index] = null  # Set to null instead of removing

func draw_tiles(tile_pool, count: int):
	# Fill first available null slot
	for tile_def in drawn:
		for i in range(HAND_SIZE):
			if hand[i] == null:
				hand[i] = tile_def
				break
```

**Why:** Keeps tiles anchored to their UI positions when sold. Prevents UI shifting/jumping. Empty slots show "Empty" placeholder.

### Mouse-Following Tooltip Pattern
**Pattern:**
```gdscript
# In tile_selector_ui.gd - Declare class variables
var village_sell_tooltip: Label = null
var village_sell_tooltip_panel: PanelContainer = null

# Create tooltip once
func create_village_sell_tooltip() -> void:
	village_sell_tooltip_panel = PanelContainer.new()
	# ... styling ...
	village_sell_tooltip = Label.new()
	village_sell_tooltip_panel.add_child(village_sell_tooltip)

# Update position every frame in _process()
func _process(_delta: float) -> void:
	if village_sell_tooltip_panel and village_sell_tooltip_panel.visible:
		var mouse_pos = get_viewport().get_mouse_position()
		village_sell_tooltip_panel.position = mouse_pos + Vector2(20, 20)  # Offset from cursor

# Show/hide from game logic
func show_village_sell_tooltip(visible: bool, amount: int = 0) -> void:
	if visible and amount > 0:
		village_sell_tooltip.text = "+%d Resources" % amount
		village_sell_tooltip_panel.visible = true
	else:
		village_sell_tooltip_panel.visible = false
```

**Why:** Provides immediate visual feedback near the cursor. Non-intrusive and works regardless of camera angle. Uses class variables (cleaner than set_meta approach) and guard clause pattern.

### Manager Organization
```
board_manager (orchestrator)
├── Owns: tile_manager, village_manager, placement_controller, tile_pool, player
├── Handles: turn flow, harvest logic, action consumption
└── TODO: Extract turn system to TurnManager class
```

### UI Initialization Order
1. Create UI components
2. Connect player signals to UI callbacks
3. Call `ui.update_turn_phase()` to show correct phase UI
4. Emit initial signal values to populate UI

---

## 🚧 Partially Implemented

**Test Mode Shortcuts**
- Keys 1/2/3 still work for free tile placement (debug only)
- Should disable in production builds

---

## ❌ Not Yet Implemented (From rules.md)

### High Priority (Next Session)

**UI Polish**
- ✅ ~~Show tile pool remaining count~~ (DONE - shows above hand with color coding)
- ✅ ~~Win condition & victory screen~~ (DONE - complete endgame system implemented)
- Better card hover effects
- Disable end turn during harvest phase
- Show "must harvest first" feedback

### Medium Priority

**Divine Powers (Fervor Spending)**
- Define power list from rules.md
- Create power selection UI
- Implement power effects
- Most powers cost fervor + 1 action

**God-Specific Abilities**
- Bicéphales: Dual resource harvest
- Augia: Resource generation
- Rakun: Glory multiplier
- Le Bâtisseur: Building discount
- Need god selection at game start

**Multiplayer Structure**
- Currently single player only
- Player class ready for multiple instances
- Need: Turn order, player switching, victory conditions
- **See detailed plan:** `MULTIPLAYER_PLAN.md`

### Low Priority

**Advanced Features**
- Tile selling (rules.md mentions this)
- Village levels/upgrades
- Special tile effects
- Animation polish
- Sound effects
- Camera controls (pan, zoom, rotate)

---

## 📝 Code Quality TODOs

**Extraction Candidates:**
```gdscript
# board_manager.gd lines 181-312
# ========== TURN SYSTEM (Extract to TurnManager later) ==========
# ... turn phase logic ...
# ========== END TURN SYSTEM ==========
```
This is already marked and ready to extract to `turn_manager.gd`

**Debug Logging:**
- Consider creating Logger singleton (see README.md for pattern)
- Current prints are useful, keep for now
- Can add log levels later

**UI Mode:**
- `ui_mode` ("test" vs "game") works well
- Consider renaming to `debug_mode` for clarity

---

## 🐛 Known Issues

**Resolved:**
- ✅ Village ownership conflicts (renamed to `player_owner`)
- ✅ Actions UI not updating (added signal)
- ✅ Starting tile sometimes missing (ensured PLAINS)
- ✅ Manual UI updates (switched to signals)

**Active:**
- None currently!

---

## 💡 Next Session Recommendations

**Quick Wins:**
1. ✅ ~~Implement tile selling~~ (DONE)
2. ✅ ~~Add village building cost~~ (DONE)
3. ✅ ~~Fix action validation~~ (DONE)
4. ✅ ~~Implement end game detection and point counting~~ (DONE)

**Medium Tasks:**
1. Implement first divine power (as template for others)
2. Polish UI (disable end turn during harvest, better hover effects)
3. Extract TurnManager class (marked in code)
4. Add multiplayer player switching (see MULTIPLAYER_PLAN.md)

**Best Starting Point:**
Start with **divine powers** - implement one god's powers as a template (e.g., Bicéphales minor power: 4 actions next turn for 3 fervor). Then add god selection at game start.

---

## 📚 Context for New Sessions

**Current State Summary:**
You have a **fully playable** turn-based hexagonal tile placement game with complete victory conditions. Players draw tiles from a 63-tile bag, place them on a hex grid, build villages, harvest resources/fervor/glory, and compete for the highest score. The game ends when the tile bag empties, triggering final scoring with detailed breakdowns including village points (by terrain), resource/fervor pairs, raw glory, and territory bonuses from contiguous village groups. VictoryManager uses flood-fill algorithm to find connected village clusters.

**Code Quality:**
Architecture is clean with manager pattern. Signal-based reactive UI is working well. New VictoryManager handles all scoring logic. Turn system is in board_manager but marked for extraction. Fixed-size hand array (3 slots with null) prevents UI shifting. Endgame system is multiplayer-ready (uses array format for scores).

**What Works Well:**
The game is now fully playable from start to finish! Core gameplay loop is solid. Victory screen provides comprehensive score breakdown. Territory calculation using BFS graph traversal works efficiently. Reactive signals prevent bugs. Action validation prevents confusing errors. Visual feedback is consistent and clear. Endgame notification keeps players informed.

**Next Focus:**
Add divine powers (fervor spending for special abilities), then implement multiplayer player switching, then add god-specific abilities.
