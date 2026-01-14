# Architecture Refactoring Summary

## Overview
Refactored from a monolithic `board_manager.gd` to a clean component-based architecture using Godot's node system.

## New Architecture

```
board_manager.gd (Orchestrator - 138 lines)
├── TileManager (Node3D)
├── VillageManager (Node3D)
└── PlacementController (Node)
```

## Components

### 1. **TileManager** (`tile_manager.gd`)
**Responsibility**: All tile-related logic

- Tile storage (`placed_tiles` dictionary)
- Tile placement and validation
- Tile type definitions and constants
- Tile mesh instantiation
- Signals: `tile_placed(q, r, height, tile_type)`

**Key Methods**:
- `place_tile(q, r, tile_type)` - Places a tile
- `is_valid_placement(q, r, tile_type)` - Validates placement rules
- `has_tile_at(q, r)` - Checks for tile existence
- `get_top_height(q, r)` - Returns topmost tile height

### 2. **VillageManager** (`village_manager.gd`)
**Responsibility**: All village-related logic

- Village storage (`placed_villages` dictionary)
- Village placement and removal
- Village mesh creation
- Preview village creation and coloring
- Signals: `village_placed(q, r)`, `village_removed(q, r)`

**Key Methods**:
- `place_village(q, r)` - Places a village
- `remove_village(q, r)` - Removes a village
- `has_village_at(q, r)` - Checks for village existence
- `create_village_mesh()` - Creates 3D village placeholder
- `create_preview_village()` - Creates semi-transparent preview
- `update_preview_color(preview, is_valid)` - Updates preview feedback

### 3. **PlacementController** (`placement_controller.gd`)
**Responsibility**: Input handling and preview management

- Manages placement modes (TILE, VILLAGE_PLACE, VILLAGE_REMOVE)
- Handles mouse and keyboard input
- Manages tile and village previews
- Coordinates with managers for validation

**Key Methods**:
- `select_tile_type(tile_type)` - Enters tile placement mode
- `select_village_place_mode()` - Enters village placement mode
- `select_village_remove_mode()` - Enters village removal mode
- `update_preview()` - Updates preview based on current mode
- Input handlers for mouse clicks and keyboard shortcuts

### 4. **BoardManager** (`board_manager.gd`)
**Responsibility**: Orchestration and utilities

- Creates and initializes all manager components
- Connects UI signals to PlacementController
- Provides hexagonal coordinate conversion utilities
- Manages camera reference

**Utility Methods** (used by all managers):
- `axial_to_world(q, r, height)` - Converts hex coords to 3D position
- `world_to_axial(world_pos)` - Converts 3D position to hex coords
- `get_axial_neighbors(q, r)` - Returns 6 adjacent hex positions
- `get_axial_at_mouse(mouse_pos)` - Gets hex coords from mouse position

### 5. **UI Refactoring** (`tile_selector_ui.gd`)
**Improvements**:
- Eliminated duplicate button creation code
- Single generic `create_button()` function
- Single `create_button_style()` helper
- Uses callbacks for flexibility

**Before**: 161 lines with duplicated `create_tile_button` and `create_village_button`
**After**: 101 lines with single `create_button` function

## Benefits

### 1. **Separation of Concerns**
- Each manager has a single, clear responsibility
- No mixing of tile logic with village logic
- Input handling separated from game logic

### 2. **Extensibility**
Adding new features is straightforward:
- New building type? → Create `BuildingManager`
- Resource system? → Create `ResourceManager`
- Just add as a new child node to BoardManager

### 3. **Testability**
- Each manager can be tested independently
- Clear interfaces between components
- Minimal coupling through references

### 4. **Godot Idiomatic**
- Uses Node composition (the "Godot way")
- Signal-based communication
- Easy to inspect in scene tree (future)
- Follows Godot best practices

### 5. **Maintainability**
- Easy to find code (tile bugs → TileManager)
- Clear boundaries prevent "god object"
- Smaller files are easier to understand

## Communication Flow

```
UI Button Click
    ↓
PlacementController (receives signal)
    ↓
Asks Manager: "Is this valid?"
    ↓
Manager validates and executes
    ↓
Emits success signal
    ↓
PlacementController updates state
```

## Cross-References
Managers reference each other only for validation:
- `TileManager.village_manager` - to check if village blocks stacking
- `VillageManager.tile_manager` - to check if tile exists for village

This is set up once in `board_manager._ready()`.

## File Summary

| File | Lines | Role |
|------|-------|------|
| `board_manager.gd` | 138 | Orchestrator + utilities |
| `tile_manager.gd` | 139 | Tile logic |
| `village_manager.gd` | 124 | Village logic |
| `placement_controller.gd` | 188 | Input + preview |
| `tile_selector_ui.gd` | 101 | UI buttons |

**Total**: ~690 lines (was ~420 in monolithic version, but with clear organization)

## Migration Notes

No `.tscn` file changes needed! All managers are instantiated in code:

```gdscript
func _ready() -> void:
    tile_manager = TileManager.new()
    add_child(tile_manager)
    # etc.
```

Could be added to scene tree later for inspector tweaking if desired.

## Future Improvements

1. **Optional**: Add managers to `main.tscn` scene for inspector configuration
2. **Optional**: Extract hex coordinate math to `HexGrid` utility class
3. **Ready for**: ResourceManager, BuildingManager, AIManager, etc.

---

**Refactoring Complete** ✅

The codebase is now well-organized, maintainable, and ready for future expansion!
