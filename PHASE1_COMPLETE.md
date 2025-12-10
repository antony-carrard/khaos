# Phase 1 Complete: Tile Type System

## What's New

### Three Tile Types
- **PLAINS** (Green) - Height 0, ground level tiles
- **HILLS** (Brown) - Height 1, must be placed on PLAINS
- **MOUNTAIN** (Gray) - Height 2, must be placed on HILLS

### How to Use

1. **Run the game** - A green PLAINS tile will be placed at the center
2. **Press keys to select tile type:**
   - `1` = PLAINS (green)
   - `2` = HILLS (brown)
   - `3` = MOUNTAIN (gray)
3. **Move mouse** to see preview of selected tile type
4. **Click** to place tile

### Placement Rules

**PLAINS tiles:**
- First tile can go anywhere
- Additional PLAINS must be adjacent to existing PLAINS tiles
- Preview shows at height 0

**HILLS tiles:**
- Must be placed directly on top of a PLAINS tile
- Cannot place on empty ground or on other tile types
- Preview shows at height 1

**MOUNTAIN tiles:**
- Must be placed directly on top of a HILLS tile
- Cannot place on PLAINS or empty ground
- Preview shows at height 2

### Visual Feedback

- **Green preview** = Valid placement
- **Red preview** = Invalid placement (violates rules)
- Preview color matches tile type

### Code Changes

1. Added `TileType` enum to board_manager.gd
2. Updated HexTile to store and display tile type
3. Validation now checks tile type compatibility
4. Each tile type has its own color
5. Removed old height-based placement system

## Next Steps (Phase 2)

- Add collision plane for better preview visibility
- Show highlighted valid placement slots
- Replace keyboard input with UI selection
- Enter/exit placement mode
