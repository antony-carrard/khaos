# Khaos - Hexagonal Board Game

A Catan-like 3D hexagonal tile placement game built in Godot 4.5.

## Current Status: Phase 1 Complete ✅

### What's Working

**Three Tile Types:**
- 🟢 **PLAINS** (Green) - Ground level tiles (height 0)
- 🟤 **HILLS** (Brown) - Stack on PLAINS (height 1)
- ⚪ **MOUNTAIN** (Gray) - Stack on HILLS (height 2)

**Tile Placement System:**
- Hexagonal grid using axial coordinates (q, r)
- Tiles snap to hex grid positions
- Visual preview follows mouse cursor
- Preview color brightens when valid, turns reddish when invalid
- Each tile type has distinct color that persists after placement

**Placement Rules:**
- PLAINS: First tile anywhere, then must be adjacent to existing PLAINS
- HILLS: Must be placed directly on top of a PLAINS tile
- MOUNTAIN: Must be placed directly on top of a HILLS tile

**Controls:**
- `1` - Select PLAINS and enter placement mode
- `2` - Select HILLS and enter placement mode
- `3` - Select MOUNTAIN and enter placement mode
- `ESC` - Exit placement mode (hide preview)
- `Left Click` - Place tile at preview position

### Architecture

**Core Files:**
- `main.tscn` - Main 3D scene with camera, lighting, ground plane
- `board_manager.gd` - Manages hex grid, placement logic, validation
- `hex_tile.tscn` / `hex_tile.gd` - Individual tile prefab with collision

**Key Systems:**

1. **Hexagonal Grid Math** (board_manager.gd:153-226)
   - `axial_to_world()` - Converts hex (q,r) → 3D world position
   - `world_to_axial()` - Converts world position → hex (q,r)
   - `axial_round()` - Rounds fractional hex coords to nearest valid hex
   - `get_axial_neighbors()` - Returns 6 adjacent hex positions

2. **Tile Type System** (board_manager.gd:6-24)
   - `TileType` enum: PLAINS, HILLS, MOUNTAIN
   - `TILE_TYPE_TO_HEIGHT` - Maps type → height level
   - `TILE_TYPE_COLORS` - Maps type → visual color

3. **Validation** (board_manager.gd:139-184)
   - `is_valid_placement(q, r, tile_type)` - Checks all placement rules
   - Verifies tile type compatibility (HILLS on PLAINS, etc.)
   - Ensures tiles connect properly

4. **Collision System**
   - Tiles: StaticBody3D on collision layer 1
   - Ground plane: StaticBody3D on collision layer 2 (infinite plane at y=0)
   - Raycast: Detects both layers for cursor preview

5. **Material Management** (hex_tile.gd:20-27)
   - Each tile duplicates its material in `_ready()`
   - Prevents shared material bug (all tiles changing color together)

### Technical Decisions Made

**Why axial coordinates?**
- Industry standard for hex grids (from Red Blob Games)
- Simpler math than cube coordinates for storage
- Easy neighbor calculations with fixed offsets

**Why tile types instead of free stacking?**
- Simplifies game rules (PLAINS→HILLS→MOUNTAIN progression)
- Each type locked to specific height
- Easier validation logic

**Why collision layers?**
- Layer 1 (tiles): For tile-to-tile interactions
- Layer 2 (ground plane): For cursor detection without affecting tiles
- Allows raycast to always hit something (smooth preview)

**Why duplicate materials?**
- Godot shares materials between instances by default
- Without duplication, changing one tile's color affects all tiles
- Each tile needs independent material for unique colors

## Next: Phase 2 Goals

### Placement Mode with Visual Feedback

**Goal:** Dorf Romantik-style tile placement with highlighted valid slots.

**Features to Implement:**
1. **Calculate Valid Slots** - When entering placement mode, compute all valid positions for current tile type
2. **Visual Slot Indicators** - Show glowing hex outlines/rings at each valid position
3. **Placement Mode State** - Proper enter/exit placement mode (not just hide preview)
4. **Improved Preview** - Preview snaps to valid slots, better visual feedback

**Implementation Approach:**

```gdscript
# New state variables
var placement_mode_active: bool = false  # ✅ Already added
var valid_placement_slots: Array[Vector3i] = []
var slot_indicators: Dictionary = {}  # Map slot position → indicator node

# New functions to add
func enter_placement_mode(tile_type: TileType) -> void
func exit_placement_mode() -> void
func calculate_valid_slots(tile_type: TileType) -> Array[Vector3i]
func show_slot_indicators() -> void
func clear_slot_indicators() -> void
func create_slot_indicator() -> Node3D
```

**Slot Indicator Visual (Option B - Lightweight):**
- Create simple torus/ring mesh (donut shape)
- Position at valid hex locations
- Animate/glow effect (optional)
- Remove when exiting placement mode

**Calculate Valid Slots Logic:**
- For PLAINS: Find all empty hexes adjacent to existing PLAINS
- For HILLS: Find all PLAINS tiles without HILLS on top
- For MOUNTAIN: Find all HILLS tiles without MOUNTAIN on top

### UI (Optional for Phase 2)
- Replace keyboard (1/2/3) with visual tile selection buttons
- Show current selected tile type
- Tile inventory/counts

## Project Structure

```
khaos/
├── project.godot
├── README.md (this file)
├── PHASE1_COMPLETE.md (Phase 1 summary)
├── main.tscn (main scene)
├── board_manager.gd (grid logic)
├── hex_tile.tscn (tile prefab)
├── hex_tile.gd (tile script)
└── icon.svg
```

## Running the Project

1. Open in Godot 4.5
2. Press F5 or click "Run Project"
3. Use keyboard keys 1/2/3 to select tile types
4. Move mouse to preview placement
5. Click to place tiles
6. ESC to exit placement mode

## Lessons Learned

1. **Shared Material Bug** - Always duplicate materials for instances
2. **Collision Layers** - Use different layers for different interaction types
3. **Raycast Missing** - Need collision plane for cursor detection in empty space
4. **Enum Conflicts** - Can't have same enum in multiple scripts (use int storage)
5. **_ready() Order** - Material duplication must happen before color setting

## Questions to Consider for Phase 2

1. Should slot indicators be persistent or only show in placement mode?
2. How much should slot indicators glow/animate?
3. Should invalid slots show at all, or only valid ones?
4. UI: Buttons vs keyboard vs both?

## Resources

- Red Blob Games Hex Grids: https://www.redblobgames.com/grids/hexagons/
- Godot Physics Layers: https://docs.godotengine.org/en/stable/tutorials/physics/physics_introduction.html#collision-layers-and-masks

---

**Ready for Phase 2!** 🚀
