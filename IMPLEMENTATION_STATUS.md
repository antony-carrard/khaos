# Implementation Status

**Last Updated:** 2024 (Turn system complete)

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

**Village Placement Cost**
- Currently villages are free in test mode
- Need to add resource cost + action consumption
- Village removal also needs implementation

**Test Mode Shortcuts**
- Keys 1/2/3 still work for free tile placement (debug only)
- Should disable in production builds

---

## ❌ Not Yet Implemented (From rules.md)

### High Priority (Next Session)

**Selling Tiles**
- Infrastructure ready (`sell_price` on tiles)
- Need: UI button + logic to sell tile from hand
- Action: Discard tile, gain `sell_price` resources
- Costs 1 action

**Village Building Cost**
- Villages should cost resources (amount TBD)
- Should consume 1 action
- Currently: Free placement in test mode

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

**Quick Wins (1-2 hours):**
1. Implement tile selling (easy, infrastructure ready)
2. Add village building cost (just validation + resource spend)
3. Add glory win condition check

**Medium Tasks (2-4 hours):**
4. Extract TurnManager class (marked in code)
5. Implement first divine power (as template for others)
6. Polish UI (disable harvest during actions phase, etc.)

**Best Starting Point:**
Start with **selling tiles** - it's a small feature that exercises the existing systems and gives immediate gameplay value.

---

## 📚 Context for New Sessions

**Current State Summary:**
You have a working turn-based hexagonal tile placement game with resource economy, villages, and harvesting. The player draws tiles from a shuffled 63-tile bag, spends resources to place them, builds villages, and harvests resource types to generate more resources/fervor/glory.

**Code Quality:**
Architecture is clean with manager pattern. Signal-based reactive UI is working well. Turn system is in board_manager but marked for extraction.

**What Works Well:**
The core loop feels solid. Reactive signals prevent bugs. Tile validation is robust.

**Next Focus:**
Add selling mechanics, village costs, and win condition. Then extract TurnManager and add divine powers.
