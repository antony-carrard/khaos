# Khaos - Hexagonal God-Themed Board Game

A Catan-like 3D hexagonal tile placement game built in Godot 4.5.

## Current State: Turn-Based Economy System Complete ✅

### What's Working

**Core Game Loop:**
- ✅ Turn phases (Harvest → Actions)
- ✅ Resource economy (Resources, Fervor, Glory)
- ✅ Player hand system (draw 3 tiles per turn)
- ✅ Action tracking (3 actions per turn)
- ✅ Tile placement with cost
- ✅ Village ownership and harvesting
- ✅ Reactive UI with signal-based updates

**Tile System:**
- 🟢 **PLAINS** (Green) - Ground level (height 0), yield=1, cost=2
- 🟤 **HILLS** (Brown) - Stack on PLAINS (height 1), yield=2, cost=4
- ⚪ **MOUNTAIN** (Gray) - Stack on HILLS (height 2), yield=4, cost=8
- Each tile produces Resources, Fervor, or Glory
- 63-tile bag with shuffled distribution (28 Plains, 21 Hills, 14 Mountains)

**Resource Types:**
- 🪵 **Resources** - Building materials (for buying tiles/villages)
- 🙏 **Fervor** - Divine energy (for future god powers)
- ⭐ **Glory** - Victory points (win condition)

**Game Flow:**
1. **Harvest Phase** - Choose one resource type, harvest all villages of that type
2. **Actions Phase** - Spend 3 actions (place tiles, build villages, etc.)
3. **End Turn** - Discard hand, draw 3 new tiles, gain +1 resource +1 fervor

**Controls:**
- Click tiles in hand to select and place them
- Click "Harvest X" button to harvest that resource type
- Click "End Turn" to finish your turn
- ESC to cancel placement mode
- Debug mode (test UI): Keys 1/2/3 select tile types for free placement

### Architecture

**Manager Pattern:**
```
board_manager.gd         # Game orchestrator, turn system
├── tile_manager.gd      # Hex grid, tile placement/validation
├── village_manager.gd   # Village placement/ownership
├── placement_controller # Mouse input, preview rendering
├── tile_pool.gd         # 63-tile bag management
├── player.gd            # Resources, hand, actions (with signals!)
└── tile_selector_ui.gd  # Game UI (hand, resources, turn controls)
```

**Signal-Based Reactive Updates:**
```gdscript
# Player emits signals when state changes
player.resources_changed.emit(new_amount)
player.actions_changed.emit(new_amount)

# UI connects to signals once
player.resources_changed.connect(ui.update_resources)

# Now state changes automatically update UI!
player.spend_resources(5)  # UI updates via signal
```

**Key Files:**
- `board_manager.gd` - Turn system (marked for extraction to TurnManager)
- `tile_manager.gd` - Tile type system, placement validation
- `village_manager.gd` - Village ownership, harvest calculations
- `player.gd` - Resource management with signals
- `tile_pool.gd` - Tile bag (TileDefinition class)
- `tile_selector_ui.gd` - Full game UI (hand cards, resources, phases)

### Technical Patterns Learned

**1. Godot Signals for Reactive State:**
- Define signals in data owner
- Emit on state changes
- Connect once during setup
- Never manually update UI

**2. Avoiding Node Conflicts:**
- `owner` is built-in in Node (scene root reference)
- `get_position()` is built-in in Node3D (world position)
- `set_owner()` is built-in in Node (scene owner)
- Use descriptive names: `player_owner`, `get_grid_position()`, `set_player_owner()`

**3. Starting Tile Must Be PLAINS:**
- Draw and return non-PLAINS tiles until we get PLAINS
- First tile placement requires height 0 (PLAINS only)

**4. UI Initialization Order:**
- Connect signals BEFORE emitting initial values
- Call `update_turn_phase()` to show/hide phase-specific UI
- Emit signals to trigger initial UI population

## Running the Project

1. Open in Godot 4.5
2. Press F5 or "Run Project"
3. Harvest phase: Click "Harvest X" button
4. Actions phase: Click cards in hand, then click board to place
5. Click "End Turn" when done

## Project Structure

```
khaos/
├── board_manager.gd          # Game orchestrator, turn system
├── tile_manager.gd           # Tile grid logic
├── village_manager.gd        # Village ownership
├── placement_controller.gd   # Input handling, previews
├── tile_pool.gd              # 63-tile bag
├── player.gd                 # Resources, hand, signals
├── tile_selector_ui.gd       # Game UI
├── hex_tile.tscn/gd          # Tile prefab (with icons)
├── village.tscn/gd           # Village prefab
├── main.tscn                 # Main scene
├── rules.md                  # Game design document
└── IMPLEMENTATION_STATUS.md  # Detailed status + next steps
```

## Resources

- Red Blob Games Hex Grids: https://www.redblobgames.com/grids/hexagons/
- Godot Signals: https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html

---

**See IMPLEMENTATION_STATUS.md for detailed progress and next steps.**
