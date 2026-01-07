# Setup Phase Implementation Plan

**Status:** Ready to implement
**Estimated Time:** 3-4 hours
**Objective:** Implement proper game setup phase per rules.md (lines 44-67)

---

## Current vs. Target Behavior

### Current (Wrong)
- Game auto-places 1 random PLAINS tile at (0,0)
- Draws 3 random tiles into hand
- Starts in HARVEST phase immediately

### Target (Per rules.md)
1. Each player gets **2 specific PLAINS tiles** (1 RESOURCES, 1 FERVOR) - not random!
2. Player places first tile + village (free, no resources cost)
3. Player places second tile + village (must be adjacent to first)
4. **Then** draw 3 tiles from bag
5. **Then** start normal game (harvest phase)

**Key difference:** Setup tiles are pre-determined, villages are auto-placed, no resource cost, must be adjacent.

---

## Architecture Design

### Data Model Changes

**Player.gd:**
```gdscript
# Add setup tiles (separate from hand)
var setup_tiles: Array = []  # 2 TileDefinition objects (PLAINS only)
var setup_tiles_placed: int = 0  # Track progress (0, 1, or 2)

func initialize_setup_tiles() -> void:
    # Create 2 specific PLAINS tiles (1 RESOURCES, 1 FERVOR)
    setup_tiles = [
        create_plains_tile(TileManager.ResourceType.RESOURCES),
        create_plains_tile(TileManager.ResourceType.FERVOR)
    ]
    setup_tiles_placed = 0
```

**TurnManager.gd:**
```gdscript
# Add to existing enums/vars
var setup_tiles_placed: int = 0  # Track across all players (for multiplayer)

func start_setup_phase() -> void:
    current_phase = Phase.SETUP
    phase_changed.emit(current_phase)

    # Initialize player setup tiles
    current_player.initialize_setup_tiles()

    # Show setup UI
    if ui:
        ui.show_setup_phase(current_player.setup_tiles)

    print("=== SETUP PHASE ===")
    print("Place your 2 starting tiles and villages")

func on_setup_tile_placed(hand_index: int) -> void:
    # Increment counter
    current_player.setup_tiles_placed += 1

    # Check if setup complete (2 tiles placed)
    if current_player.setup_tiles_placed >= 2:
        complete_setup_phase()

func complete_setup_phase() -> void:
    print("=== SETUP COMPLETE ===")

    # Draw 3 tiles from bag
    current_player.draw_tiles(tile_pool, 3)

    # Give starting resources
    current_player.start_turn()  # +1 resource, +1 fervor, 3 actions

    # Transition to harvest
    start_harvest_phase()
```

---

## UI Changes

### tile_selector_ui.gd

**Add Setup Display:**
```gdscript
var setup_tiles_container: VBoxContainer = null
var setup_title_label: Label = null

func show_setup_phase(setup_tiles: Array) -> void:
    # Hide normal hand display
    if hand_container:
        hand_container.visible = false

    # Show setup tiles
    if setup_tiles_container:
        setup_tiles_container.visible = true
        update_setup_tiles_display(setup_tiles)

    # Hide harvest/actions UI
    if harvest_buttons_container:
        harvest_buttons_container.visible = false
    if actions_label:
        actions_label.visible = false

func update_setup_tiles_display(setup_tiles: Array) -> void:
    # Clear existing
    for child in setup_tiles_container.get_children():
        if child != setup_title_label:
            child.queue_free()

    # Create cards for each setup tile (similar to hand cards)
    for i in range(setup_tiles.size()):
        if setup_tiles[i] != null:
            create_setup_tile_card(i, setup_tiles[i])

func create_setup_tile_card(index: int, tile_def) -> void:
    # Similar to create_hand_card but:
    # - Different signal (setup_tile_selected)
    # - No sell button
    # - Different styling (gold border for "special" tiles)
    # - Shows "FREE" instead of cost
```

**Update phase switching:**
```gdscript
func update_turn_phase(phase: int) -> void:
    match phase:
        TurnManager.Phase.SETUP:
            show_setup_phase(board_manager.current_player.setup_tiles)
        TurnManager.Phase.HARVEST:
            # ... existing harvest logic
        TurnManager.Phase.ACTIONS:
            # ... existing actions logic
```

---

## PlacementController Changes

### placement_controller.gd

**Handle Setup Mode:**
```gdscript
# Add to _process_tile_placement
func _process_tile_placement(delta: float) -> void:
    # ... existing mouse handling ...

    # Validate placement (adjacency requirement in setup)
    var valid = true

    if board_manager.turn_manager.is_setup_phase():
        # First tile: can place anywhere
        # Second tile: MUST be adjacent to first tile
        if board_manager.current_player.setup_tiles_placed >= 1:
            # Check adjacency
            var neighbors = board_manager.get_axial_neighbors(axial_coords.x, axial_coords.y)
            var has_neighbor = false
            for neighbor in neighbors:
                if tile_manager.has_tile_at(neighbor.x, neighbor.y):
                    has_neighbor = true
                    break

            if not has_neighbor:
                valid = false  # Must be adjacent during setup
    else:
        # Normal placement rules (existing code)
        valid = tile_manager.can_place_tile(...)

    preview_tile.set_highlight(true, valid)

# On successful tile placement in setup
func _on_input_event(camera, event, position, normal, shape_idx):
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if board_manager.turn_manager.is_setup_phase():
            # Place tile
            var success = tile_manager.place_tile(...)

            if success:
                # AUTO-PLACE VILLAGE (key difference!)
                village_manager.place_village(axial_coords.x, axial_coords.y,
                                               board_manager.current_player)

                # Notify turn manager
                board_manager.turn_manager.on_setup_tile_placed(selected_hand_index)

                # Clear selection
                cancel_placement()
```

---

## board_manager.gd Changes

**Remove auto-placement, start in SETUP:**
```gdscript
func _ready() -> void:
    # ... existing manager setup ...

    # REMOVE THIS BLOCK (lines 87-110):
    # var first_tile = null
    # while first_tile == null or first_tile.tile_type != TileManager.TileType.PLAINS:
    #     ...
    # tile_manager.place_tile(0, 0, first_tile.tile_type, ...)

    # REPLACE WITH:
    # Don't place any tiles automatically
    # Don't draw tiles yet (happens after setup)

    # Give player starting turn bonus (for actions tracking)
    current_player.start_turn()
    # Test mode: unlimited actions
    if test_mode:
        current_player.set_actions(999)

    # START IN SETUP PHASE (not harvest!)
    turn_manager.start_setup_phase()

    # Create UI
    setup_ui()
```

---

## Implementation Steps

### Phase 1: Data Model (30 min)
1. Add `setup_tiles` and `setup_tiles_placed` to Player.gd
2. Add `initialize_setup_tiles()` method (creates 2 specific PLAINS)
3. Add helper to create specific tile: `create_plains_tile(resource_type)`

### Phase 2: TurnManager Logic (45 min)
1. Add `start_setup_phase()` - initialize setup, show UI
2. Add `on_setup_tile_placed()` - track progress
3. Add `complete_setup_phase()` - draw tiles, transition to harvest
4. Update `is_setup_phase()` (already exists!)

### Phase 3: UI Display (60 min)
1. Create `setup_tiles_container` in tile_selector_ui.gd
2. Add `show_setup_phase()` - show setup tiles, hide normal UI
3. Add `create_setup_tile_card()` - similar to hand cards
4. Update `update_turn_phase()` to handle SETUP case
5. Add signal: `setup_tile_selected(index: int)`

### Phase 4: Placement Logic (45 min)
1. Update PlacementController to handle setup mode
2. Add adjacency validation for second setup tile
3. Auto-place village after tile placement (no cost!)
4. Call `turn_manager.on_setup_tile_placed()`

### Phase 5: board_manager Integration (30 min)
1. Remove auto-placement of first tile
2. Don't draw tiles in `_ready()` (happens after setup)
3. Call `turn_manager.start_setup_phase()` instead of `start_harvest_phase()`
4. Connect UI signal: `setup_tile_selected` → `_on_setup_tile_selected()`

### Phase 6: Testing (30 min)
- [ ] Game starts in SETUP phase
- [ ] Shows 2 specific tiles (1 RESOURCES, 1 FERVOR PLAINS)
- [ ] Can place first tile anywhere
- [ ] First tile auto-gets village (no resource cost)
- [ ] Second tile must be adjacent to first
- [ ] Second tile auto-gets village
- [ ] After 2 tiles → draws 3 tiles → harvest phase
- [ ] Normal game proceeds correctly

---

## Key Design Decisions

### Why separate `setup_tiles` from `hand`?
- Different lifecycle (pre-determined vs. drawn from bag)
- Different UI (can't sell, different display)
- Cleaner separation of concerns

### Why auto-place villages?
- Rules.md says "place 1 tuile et une ville dessus" (tile AND village)
- Setup is streamlined - no resource management yet
- Prevents players from forgetting village placement

### Why adjacency validation?
- Rules.md line 63: "doivent toujours être posées à côté d'au moins une autre tuile"
- Ensures connected board from start
- First tile exempt (nothing to be adjacent to!)

---

## Multiplayer Considerations (Future)

For multiplayer, setup becomes:
1. Player 1 places tile 1 + village
2. Player 2 places tile 1 + village (adjacent)
3. Player 3 places tile 1 + village (adjacent)
4. ...back to Player 1 for tile 2
5. Each player places tile 2 + village
6. All players draw 3 tiles
7. Game starts (Player 1 harvest phase)

**Changes needed:**
- Track `setup_round` (1 or 2)
- After each placement, switch to next player
- After all players place round 2, start game

**Not implementing yet** - focus on single player first!

---

## Files to Modify

**Critical (must modify):**
- `player.gd` - Add setup_tiles array and methods
- `turn_manager.gd` - Add setup phase logic
- `tile_selector_ui.gd` - Add setup UI display
- `placement_controller.gd` - Handle setup placement mode
- `board_manager.gd` - Remove auto-placement, start in setup

**Reference (may need to read):**
- `tile_pool.gd` - Understand TileDefinition structure
- `tile_manager.gd` - Placement validation
- `village_manager.gd` - Village placement

---

## Testing Strategy

1. **Visual test:** Does UI show 2 PLAINS tiles correctly?
2. **Placement test:** Can place first tile anywhere?
3. **Adjacency test:** Does second tile reject non-adjacent positions?
4. **Village test:** Do villages auto-appear after tile placement?
5. **Transition test:** After 2 tiles, do we draw 3 and start harvest?
6. **Game flow test:** Does normal gameplay work after setup?

---

## Potential Issues & Solutions

**Issue:** How to create specific PLAINS tiles?
**Solution:** Add helper method to TilePool or Player that creates TileDefinition with specific properties

**Issue:** How to prevent selling/removing setup tiles?
**Solution:** Don't add sell buttons to setup tile cards, check phase in sell_tile()

**Issue:** What if player places tile but not village?
**Solution:** Auto-place village in PlacementController after successful tile placement

**Issue:** UI transition feels abrupt?
**Solution:** Add message "Setup complete! Draw your starting hand..." before transition

---

## Next Session Prompt

```
Implement the setup phase per rules.md requirements.

Current behavior: Game auto-places 1 tile and starts in harvest phase.
Target: Player manually places 2 specific PLAINS tiles (1 RESOURCES, 1 FERVOR)
with auto-placed villages, then draws 3 tiles and starts harvest.

Please read:
- @SETUP_PHASE_PLAN.md (this file - detailed implementation plan)
- @player.gd (will add setup_tiles array)
- @turn_manager.gd (will add start_setup_phase logic)
- @board_manager.gd (will remove auto-placement)
- @rules.md (lines 44-67 for setup requirements)

Follow SETUP_PHASE_PLAN.md phases in order. Test after each phase.
```

---

## Success Criteria

✅ Game starts in SETUP phase, not HARVEST
✅ Player sees 2 PLAINS tiles (1 RESOURCES, 1 FERVOR) in setup UI
✅ First tile can be placed anywhere
✅ Village auto-appears on first tile (no resource cost)
✅ Second tile MUST be adjacent to first
✅ Village auto-appears on second tile
✅ After placing 2 tiles: draws 3 tiles from bag
✅ Transitions to HARVEST phase automatically
✅ Normal game flow works correctly after setup
