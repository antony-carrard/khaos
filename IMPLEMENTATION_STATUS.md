# Implementation Status

**Last Updated:** 2026-01-04 (Village building and selling complete)

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

**Win Condition**
- Check glory threshold at turn end
- Show victory screen
- Glory target: TBD (30? 50?)

**UI Polish**
- Disable end turn during harvest phase
- Show "must harvest first" feedback
- Better card hover effects
- Show tile pool remaining count

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
3. Add glory win condition check

**Medium Tasks:**
4. Extract TurnManager class (marked in code)
5. Implement first divine power (as template for others)
6. Polish UI (disable end turn during harvest, better hover effects)

**Best Starting Point:**
Start with **glory win condition** - check at turn end if player reached threshold, follows established patterns.

---

## 📚 Context for New Sessions

**Current State Summary:**
You have a working turn-based hexagonal tile placement game with resource economy, villages, harvesting, tile selling, village building, and village removal. The player draws tiles from a shuffled 63-tile bag, spends resources to place them, sells unwanted tiles, builds villages (costing resources and actions), removes villages for refunds, and harvests resource types to generate more resources/fervor/glory.

**Code Quality:**
Architecture is clean with manager pattern. Signal-based reactive UI is working well. Turn system is in board_manager but marked for extraction. Fixed-size hand array (3 slots with null) prevents UI shifting.

**What Works Well:**
The core loop feels solid. Reactive signals prevent bugs. Tile validation is robust. Selling mechanics work smoothly with anchored hand positions. Village building/removal with costs, refunds, and preview validation follows clean patterns. Mouse-following tooltip provides great UX feedback.

**Next Focus:**
Add win condition check, then extract TurnManager and add divine powers.
