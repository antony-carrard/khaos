# Implementation Status

**Last Updated:** 2026-02-19

This document tracks detailed implementation progress and serves as context for continuing development.

## Recent Changes (2026-02-19)

**Strategy Pattern Refactor + Godot 4.6 Upgrade:**
- **Upgraded to Godot 4.6** — project.godot, main.tscn node unique_ids, victory_manager.gd indentation
- **Replaced PlacementMode enum with Strategy pattern** — each of 8 placement modes is now a self-contained class
  - Eliminated `placement_active: bool` — `current_strategy == null` is the single source of truth
  - Removed two large `match current_mode` blocks (~200 lines)
  - `PlacementController` reduced to ~270 lines (orchestrator only)
- **Reorganised into `placement/` folder** — first step toward folder-based project structure
  - `placement/placement_controller.gd`
  - `placement/strategies/` (9 files: base class + 8 strategy implementations)
- **No behaviour changes** — all 8 modes work identically, just cleaner internals

## Recent Changes (2026-01-18)

**UPGRADE_TILE_KEEP_VILLAGE & DOWNGRADE_TILE_KEEP_VILLAGE Powers (Latest):**
- **Implemented Augia's UPGRADE_TILE_KEEP_VILLAGE power** (5 fervor + 1 action)
  - Upgrades tile from PLAINS→HILLS or HILLS→MOUNTAIN without destroying village
  - Added `tile_manager.upgrade_tile()` method that **stacks a new tile on top**
  - Added UPGRADE_TILE_KEEP_VILLAGE placement mode to placement_controller.gd
  - Preview shows green on own villages with upgradeable tiles (not MOUNTAIN)
  - Validates tile can be upgraded (not already at max level)
  - board_manager.on_upgrade_tile() executes the upgrade with deferred payment
  - **Updates village position** to match new tile height after upgrade
- **Implemented Rakun's DOWNGRADE_TILE_KEEP_VILLAGE power** (4 fervor + 1 action)
  - Downgrades tile from MOUNTAIN→HILLS or HILLS→PLAINS without destroying village
  - Added `tile_manager.downgrade_tile()` method that **removes the top tile**
  - Added DOWNGRADE_TILE_KEEP_VILLAGE placement mode to placement_controller.gd
  - Preview shows green on own villages with downgradeable tiles (not PLAINS)
  - Validates tile can be downgraded (not already at min level)
  - board_manager.on_downgrade_tile() executes the downgrade with deferred payment
  - **Updates village position** to match new tile height after downgrade
- **Both powers use deferred payment system** (pay when action completes, not on button click)
- **Key insight: Tiles stack vertically!**
  - MOUNTAIN position = PLAINS (h0) + HILLS (h1) + MOUNTAIN (h2)
  - HILLS position = PLAINS (h0) + HILLS (h1)
  - PLAINS position = PLAINS (h0)
  - **Upgrade = Add tile on top** (bypasses village blocking rule)
  - **Downgrade = Remove top tile** (reveals tile below)
  - Resource properties (type, yield, costs) are copied to new top tile
  - Villages automatically move up/down with terrain height changes
- **Files modified:** tile_manager.gd, placement_controller.gd, board_manager.gd, god_manager.gd
- **Result:** All 8 divine powers now fully functional! Complete power system ready for gameplay.

**CHANGE_TILE_TYPE Power Implementation:**
- **Implemented Augia's CHANGE_TILE_TYPE power** (2 fervor + 1 action)
  - Added CHANGE_TILE_TYPE placement mode to placement_controller.gd
  - Created resource type picker UI modal (tile_selector_ui.gd)
    - Shows 3 buttons: Resources, Fervor, Glory (or 2 if Plains tile)
	- Purple border matching Augia's theme color
	- Prevents multiple overlays from spawning
	- Consumes mouse input to prevent click-through
  - Validates Glory cannot be placed on Plains tiles
  - Design note: Does NOT check tile pool (digital convenience - see board_manager.gd:482-486)
  - Successfully changes tile icon and resource type in-place
- **Fixed deferred payment system** for selection-based powers
  - Powers now split into "immediate" and "deferred" categories
  - Immediate powers (EXTRA_ACTION, SECOND_HARVEST): Pay when button clicked
  - Deferred powers (STEAL_HARVEST, DESTROY_VILLAGE_FREE, CHANGE_TILE_TYPE): Pay when action completes
  - Added `player.pending_power` to track powers awaiting payment
  - Added `god_manager.complete_deferred_power()` called on successful selection
  - Added `god_manager._power_requires_deferred_payment()` helper
  - Prevents "paid but failed" scenarios when player cancels (ESC key)
  - Clears pending_power on cancellation or validation failure
- **Fixed UI overlay bugs**
  - Overlay now hides immediately (visible=false before queue_free)
  - Added `_on_overlay_gui_input()` to consume mouse events
  - Cancel placement mode BEFORE hiding overlay (prevents re-triggering)
  - Added guard check to prevent multiple overlays
- **Files modified:** board_manager.gd, god_manager.gd, placement_controller.gd, player.gd, tile_selector_ui.gd
- **Files created:** REFACTORING_PLAN.md (technical debt documentation)
- **Result:** 6/8 divine powers fully functional, deferred payment prevents resource loss on cancellation

## Recent Changes (2026-01-14)

**Divine Powers System (Latest):**
- **Implemented data-driven god architecture** - god.gd, god_power.gd, god_manager.gd
  - PowerType enum for all power types (active + passive)
  - God class holds powers array
  - GodManager centralizes all power logic and god definitions
- **God selection UI at game start** - god_selection_ui.gd
  - Full-screen overlay with 4 clickable god cards (1×4 horizontal layout)
  - Shows god portraits, names, and power descriptions
  - Cards resized to 400×500 to fit 1920×1080 resolution
  - Fixed clickability with MOUSE_FILTER_IGNORE on all overlay elements
- **In-game god display** - tile_selector_ui.gd
  - God panel on left side of UI with horizontal layout (portrait+name left, powers right)
  - Compact 350×120 god panel with vertically centered content
  - Active powers (purple, clickable) vs passive (gray, disabled)
  - Power buttons show fervor cost with SVG pray icon (matching tile button style)
  - **Once-per-turn limitation** - powers can only be used once per turn
  - **Dynamic button states** - automatically gray out when:
	- Player can't afford fervor cost
    - Power already used this turn
    - Not in actions phase
    - No actions remaining
  - **Reactive UI updates** - connected to multiple signals:
    - fervor_changed, power_used, actions_changed, phase_changed
    - Buttons update immediately without "tick lag"
  - Power buttons wired to god_manager.activate_power()
- **Village cost refactoring** - player.gd
  - Added `player.get_village_cost(base_cost)` helper method
  - Encapsulates god ability modifications (e.g., Le Bâtisseur's flat cost)
  - Applied in board_manager.gd and placement_controller.gd
- **Bonus action tracking** - player.gd
  - Added `max_actions_this_turn` field to track total actions including bonuses
  - Actions display now shows correct max (e.g., "4/4" not "4/3" with Bicéphallès power)
- **Resolution fix** - project.godot updated to 1920×1080
- **Powers implemented:**
  - ✅ **Le Bâtisseur passive** (FLAT_VILLAGE_COST) - All villages cost 4 resources
  - ✅ **Bicéphallès EXTRA_ACTION** - Grant +1 action next turn (4 actions total)
  - ✅ **Bicéphallès SECOND_HARVEST** - Trigger harvest UI again (doesn't consume action)
  - ✅ **Rakun STEAL_HARVEST** - Click enemy village to steal its harvest
	- Added STEAL_HARVEST placement mode to placement_controller.gd
	- Preview shows green on enemy villages, shows yield in tooltip
	- board_manager.on_steal_harvest() adds tile yield to player resources
  - ✅ **Le Bâtisseur DESTROY_VILLAGE_FREE** - Destroy enemy village without paying
	- Added DESTROY_VILLAGE_FREE placement mode to placement_controller.gd
	- Preview shows green on enemy villages (no adjacency/level restrictions)
	- board_manager.on_destroy_village_free() removes village without compensation
  - ✅ **Augia CHANGE_TILE_TYPE** - Change resource type of own tiles (2 fervor + 1 action)
	- Added CHANGE_TILE_TYPE placement mode to placement_controller.gd
	- Resource type picker modal UI with dynamic buttons (no Glory on Plains)
	- board_manager.on_change_tile_type() changes tile icon and resource type in-place
  - ✅ **Augia UPGRADE_TILE_KEEP_VILLAGE** - Upgrade tile without destroying village (5 fervor + 1 action)
	- Added UPGRADE_TILE_KEEP_VILLAGE placement mode to placement_controller.gd
	- tile_manager.upgrade_tile() preserves resource properties
	- Preview validates tile can be upgraded (not MOUNTAIN)
  - ✅ **Rakun DOWNGRADE_TILE_KEEP_VILLAGE** - Downgrade tile without destroying village (4 fervor + 1 action)
	- Added DOWNGRADE_TILE_KEEP_VILLAGE placement mode to placement_controller.gd
	- tile_manager.downgrade_tile() preserves resource properties
	- Preview validates tile can be downgraded (not PLAINS)
- **All 8 divine powers now complete!**
- **Files modified:** board_manager.gd, player.gd, placement_controller.gd, turn_manager.gd, tile_selector_ui.gd, tile_manager.gd, god_manager.gd, project.godot
- **Files created:** god.gd, god_power.gd, god_manager.gd, god_selection_ui.gd, gods/ (images)
- **Result:** Complete god selection system with all 8 divine powers fully functional
- **TODO:** Test multi-target powers once multiplayer is implemented (DESTROY_VILLAGE_FREE, STEAL_HARVEST need enemy villages)

## Recent Changes (2026-01-07)

**Setup Phase Implementation (Latest):**
- **Implemented complete setup phase per rules.md (lines 44-67)**
- **Players now start in SETUP phase** instead of having tiles auto-placed
- **Draw 2 PLAINS tiles from pool** - player.gd `initialize_setup_tiles()` draws from tile_pool
- **Place 2 tiles + free villages** - placement_controller auto-places villages during setup (no cost)
- **Setup UI with gold borders** - tile_selector_ui.gd shows special setup cards, centered layout
- **Proper phase transition** - after 2 tiles placed → draw 3 tiles into hand → HARVEST phase
- **UI updates correctly** - setup tiles disappear, normal hand appears with newly drawn tiles
- **Files modified:** player.gd (setup_tiles array), turn_manager.gd (setup phase logic), tile_selector_ui.gd (setup UI), placement_controller.gd (auto-villages), board_manager.gd (removed auto-placement)
- **Result:** Game now follows rules.md setup sequence correctly

**TurnManager Extraction (Earlier):**
- **Extracted turn logic to dedicated TurnManager class** - moved ~170 lines from board_manager.gd
- **board_manager.gd reduced** from 651 → 461 lines (29% reduction)
- **Created turn_manager.gd** (247 lines) with clean Phase enum (SETUP/HARVEST/ACTIONS)
- **Simplified action validation** - reduced 5-line checks to 1-line helper calls:
  - `turn_manager.consume_action("action name")` handles phase + action validation
  - Applied to: sell_tile, place_village, remove_village, place_tile
- **Added validation helpers:** `can_perform_action()`, `is_harvest_phase()`, `is_actions_phase()`
- **Signal-based architecture:** `phase_changed`, `turn_started`, `turn_ended`, `game_ended`
- **Updated all references:** placement_controller.gd, tile_selector_ui.gd use turn_manager
- **Result:** Cleaner separation of concerns, easier to extend for multiplayer/divine powers

## Earlier Changes (2026-01-07)

**Simplified Tile Economics:**
- **Tiles are now FREE to place** - removed buy_price entirely, only consumes 1 action
- **Unified sell price** - all non-Glory tiles sell for 1 resource (was varied 1-4)
- **Per-tile village costs** - each tile stores its own village_building_cost instead of using per-type defaults
  - Allows future design flexibility (e.g., high-yield mountains costing more to build on)
  - Current defaults remain: Plains=2, Hills=4, Mountains=8
- **UI simplified** - removed cost display and red "unaffordable" borders from hand cards

**Cleaned Up Test Mode:**
- **Removed `ui_mode` checks from game logic** - game rules are now consistent
- **Added `@export var test_mode`** in board_manager - toggle in editor Inspector
- **Test mode now affects ONLY starting conditions:**
  - Normal: Start with 0 resources, 0 fervor, 3 actions per turn
  - Test: Start with 999 resources, 999 fervor, 999 actions (for design/testing)
- **Debug keyboard shortcuts (1/2/3 for quick tile placement)** guarded by `OS.is_debug_build()`
- **Result:** Removed ~50 lines of scattered conditionals, much cleaner architecture

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
- ✅ TileDefinition class with per-tile properties:
  - tile_type, resource_type, yield_value
  - village_building_cost (per-tile, allows design flexibility)
  - sell_price (resources gained when sold from hand)
- ✅ Draw/shuffle mechanics
- ✅ Return tile to bag (for starting tile selection)
- ✅ Remaining count tracking

**Turn System** (turn_manager.gd - extracted and complete!)
- ✅ Turn phases (SETUP, HARVEST, ACTIONS) with Phase enum
- ✅ **Setup phase** - player places 2 PLAINS tiles with free villages
  - `start_setup_phase()` - draws 2 PLAINS from pool, shows setup UI
  - `on_setup_tile_placed()` - tracks progress, removes placed tiles, updates UI
  - `complete_setup_phase()` - draws 3 tiles into hand, transitions to harvest
- ✅ Harvest phase with smart type detection
  - Auto-harvest if only one resource type available
  - Show choice UI if multiple types
- ✅ Actions phase (3 actions per turn)
- ✅ Action validation helpers: `can_perform_action()`, `consume_action()`
- ✅ Phase query helpers: `is_setup_phase()`, `is_harvest_phase()`, `is_actions_phase()`
- ✅ End turn flow (discard → draw 3 → reset actions → harvest)
- ✅ Turn start bonus (+1 resource, +1 fervor)
- ✅ Signal-based phase changes and turn events

**User Interface** (tile_selector_ui.gd)
- ✅ **Setup phase UI**
  - Gold-bordered tile cards with "FREE" label
  - "Setup Phase - Place Your Starting Tiles" title
  - Center-aligned layout (prevents shifting when tiles placed)
  - Compact "✓ Placed" placeholders (same width as tiles)
  - Automatically transitions to normal hand display after setup
- ✅ Hand display with visual tile cards
  - Color-coded by tile type
  - Shows resource icon and yield value
  - Dims tiles when no actions available (gray border)
- ✅ Resource panel (wood/pray/star icons with counts)
- ✅ Turn phase UI
  - Harvest buttons (shows only available types)
  - Actions counter (visible only during actions phase)
  - End turn button
- ✅ Signal-connected reactive updates (no manual UI calls needed!)

**Placement Controller** (placement/placement_controller.gd)
- ✅ Mouse-based placement with preview
- ✅ 8 modes via Strategy pattern (TILE, VILLAGE_PLACE, VILLAGE_REMOVE, STEAL_HARVEST, DESTROY_VILLAGE_FREE, CHANGE_TILE_TYPE, UPGRADE_TILE_KEEP_VILLAGE, DOWNGRADE_TILE_KEEP_VILLAGE)
- ✅ Valid/invalid preview coloring
- ✅ Hand tile placement integration
- ✅ **Setup phase support** - auto-places villages for free during setup
- ✅ ESC to cancel placement

**Starting Conditions**
- ✅ **Setup phase** - players place 2 PLAINS tiles with villages (per rules.md lines 53-63)
  - 2 PLAINS tiles drawn from tile pool (random RESOURCES/FERVOR mix)
  - Villages auto-placed for free (no resource cost during setup)
  - After setup complete: draw 3 tiles into hand
- ✅ Starting resources: +1 resource, +1 fervor from `start_turn()` after setup
- ✅ Test mode: 999 resources/fervor/actions for design testing

**Tile Economics**
- ✅ **Placing tiles is FREE** - no resource cost, only consumes 1 action
- ✅ **Selling tiles** (board_manager.gd, tile_selector_ui.gd):
  - Sell button on each hand card (green for sellable, gray disabled for Glory)
  - All non-Glory tiles sell for 1 resource (unified pricing)
  - Glory tiles cannot be sold (sell_price = 0)
  - Costs 1 action during actions phase
  - Fixed-size hand array (3 slots) with null for empty slots
  - Tiles stay anchored to position when sold (no UI shifting)
  - Empty slot placeholders with disabled sell button

**Village Building** (board_manager.gd, placement_controller.gd, hex_tile.gd)
- ✅ **Per-tile village costs** stored in each tile (not per-type)
  - Current defaults: Plains=2, Hills=4, Mountains=8
  - Allows future design flexibility (e.g., high-yield tiles cost more)
- ✅ Costs 1 action during actions phase
- ✅ Preview shows red when player can't afford or has no actions
- ✅ Preview shows red during harvest phase (can only build during actions)
- ✅ Validation prevents placement without sufficient resources or actions

**Village Selling/Removal** (board_manager.gd, placement_controller.gd, tile_selector_ui.gd)
- ✅ Remove your own villages for half the building cost refund
  - Refund calculated from tile's village_building_cost / 2
  - Typical refunds: Plains=1, Hills=2, Mountains=4
- ✅ Costs 1 action during actions phase
- ✅ Mouse-following tooltip shows refund amount when hovering villages
- ✅ Tooltip only appears in remove mode when hovering your own villages
- ✅ Preview shows red for villages you don't own (ownership validation)
- ✅ Guard clause pattern for clean early returns in preview code

**Action Validation & UI Polish** (player.gd, board_manager.gd, placement_controller.gd, tile_selector_ui.gd)
- ✅ `can_place_tile()` validates actions only (tiles are free to place)
- ✅ Prevents tile placement when actions exhausted
- ✅ Preview shows red when no actions available
- ✅ Black text outlines for better visibility (actions, resources, tile count)
- ✅ Auto-disable village/tile buttons when out of actions
- ✅ Consistent dimming for disabled tiles (text, icons, borders)
- ✅ Visual feedback: gray/dimmed when no actions available
- ✅ Can sell tiles when you have actions available
- ✅ No focus indicators on disabled buttons
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
├── Owns: tile_manager, village_manager, placement_controller, tile_pool, turn_manager, player
├── Handles: tile/village placement coordination, UI setup, scene initialization
└── Delegates: turn flow to turn_manager

turn_manager (turn flow)
├── Owns: references to player, village_manager, tile_manager, tile_pool
├── Handles: phase management, harvest logic, action validation, game end detection
└── Emits: phase_changed, turn_started, turn_ended, game_ended signals
```

### UI Initialization Order
1. Create UI components
2. Connect player signals to UI callbacks
3. Call `ui.update_turn_phase()` to show correct phase UI
4. Emit initial signal values to populate UI

---

## 🚧 Partially Implemented

**Debug Features**
- ✅ Keys 1/2/3 for quick tile placement (guarded by `OS.is_debug_build()`)
- ✅ Test mode toggle (`@export var test_mode`) for unlimited resources
- No remaining test/debug issues

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

**Completed Extractions:**
- ✅ **TurnManager extracted** (2026-01-07) - Turn system now in dedicated turn_manager.gd class

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
5. ✅ ~~Implement setup phase~~ (DONE)
6. ✅ ~~Implement divine powers system~~ (DONE - 4/8 powers implemented)

**Divine Powers - ALL COMPLETE! ✅**
1. ✅ **DESTROY_VILLAGE_FREE** (Le Bâtisseur) - DONE
2. ✅ **CHANGE_TILE_TYPE** (Augia) - DONE (2026-01-18)
3. ✅ **UPGRADE_TILE_KEEP_VILLAGE** (Augia) - DONE (2026-01-18)
4. ✅ **DOWNGRADE_TILE_KEEP_VILLAGE** (Rakun) - DONE (2026-01-18)

**Medium Tasks:**
1. Polish UI (disable end turn during harvest, better hover effects)
2. Add multiplayer player switching (see MULTIPLAYER_PLAN.md)
3. Test divine powers thoroughly for balance

**Best Starting Point:**
All divine powers are now complete! Next focus areas:
1. **Multiplayer implementation** - Add player switching and turn order (see MULTIPLAYER_PLAN.md)
2. **UI polish** - Disable end turn during harvest, better hover effects
3. **Playtesting** - Test all powers thoroughly for balance and edge cases

---

## 📚 Context for New Sessions

**Current State Summary:**
You have a **fully playable** turn-based hexagonal tile placement game with **complete divine powers system**. Game starts with god selection (4 clickable cards), then proper setup phase (place 2 PLAINS tiles with free villages), then normal gameplay. Players harvest resources/fervor/glory from villages, place tiles (free, 1 action), build villages (costs resources + 1 action, modified by god abilities), and use divine powers (spend fervor for special abilities). The game ends when the tile bag empties, triggering final scoring. **All 8 divine powers are fully functional** - Le Bâtisseur (flat village cost passive + destroy enemy village free), Bicéphallès (extra action + second harvest), Rakun (steal harvest + downgrade tile), and Augia (change tile type + upgrade tile). **Deferred payment system** prevents resource loss when canceling selection-based powers.

**Code Quality:**
Architecture is clean with **data-driven god system**. god_power.gd defines power types (enum), god.gd holds power collections, god_manager.gd centralizes all power logic. **Deferred payment system** prevents resource loss on cancellation - immediate powers (EXTRA_ACTION, SECOND_HARVEST) pay upfront, deferred powers (STEAL_HARVEST, DESTROY_VILLAGE_FREE, CHANGE_TILE_TYPE, UPGRADE_TILE_KEEP_VILLAGE, DOWNGRADE_TILE_KEEP_VILLAGE) only pay when action completes. Player has god reference, `get_village_cost()` helper for god ability modifications, and `pending_power` for deferred payments. Placement controller supports 8 modes (TILE, VILLAGE_PLACE, VILLAGE_REMOVE, STEAL_HARVEST, DESTROY_VILLAGE_FREE, CHANGE_TILE_TYPE, UPGRADE_TILE_KEEP_VILLAGE, DOWNGRADE_TILE_KEEP_VILLAGE) with `get_axial_at_mouse()` helper to reduce duplication. TileManager has `upgrade_tile()` and `downgrade_tile()` methods that preserve resource properties during level changes. God selection UI uses MOUSE_FILTER_IGNORE pattern for proper clickability. In-game UI shows god portrait and clickable power buttons with dynamic states. Signal-based reactive UI working well. All managers properly separated (TileManager, VillageManager, TurnManager, GodManager, VictoryManager).

**What Works Well:**
God selection is intuitive and visual. Power buttons provide clear feedback (purple=active, gray=passive, shows cost). Selection-based powers (STEAL_HARVEST, DESTROY_VILLAGE_FREE, CHANGE_TILE_TYPE, UPGRADE_TILE_KEEP_VILLAGE, DOWNGRADE_TILE_KEEP_VILLAGE) use consistent pattern - preview colors show validity, click to execute. SECOND_HARVEST reuses existing harvest UI seamlessly. Le Bâtisseur's passive applies transparently everywhere costs are checked. CHANGE_TILE_TYPE shows elegant modal UI with dynamic button visibility (no Glory on Plains). UPGRADE/DOWNGRADE preserve all tile properties while changing height level. Deferred payment system prevents frustrating "paid but failed" scenarios. Resolution fixed to 1920×1080 with proper UI scaling.

**Next Focus:**
All divine powers complete! Next priority is **multiplayer implementation** - add player switching, turn order, and test multi-target powers (DESTROY_VILLAGE_FREE, STEAL_HARVEST) with real enemy villages.
