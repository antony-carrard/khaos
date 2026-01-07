# TurnManager Extraction Plan

**Status:** ✅ COMPLETED (2026-01-07)
**Actual Time:** ~2 hours
**Objective:** Extract turn flow logic from board_manager.gd into dedicated TurnManager class

**Result:** Successfully extracted! See commit a09da5d
- board_manager.gd: 651 → 461 lines (29% reduction)
- Created turn_manager.gd (247 lines)
- Simplified action validation from 5 lines to 1 line
- See IMPLEMENTATION_STATUS.md for full details

---

**NOTE:** This plan is now archived. For the next feature (Setup Phase), see **SETUP_PHASE_PLAN.md**

---

## Why This Refactoring?

### Current Problems
1. **Verbose action validation** - This pattern repeats 4+ times:
```gdscript
if current_phase != TurnPhase.ACTIONS:
	print("Can only X during the actions phase!")
	return
if current_player.actions_remaining <= 0:
	print("No actions remaining!")
	return
if not consume_action():
	return
```

2. **board_manager is too big** - 550+ lines, doing orchestration + turn flow + UI setup
3. **Phase checks scattered** - Hard to add new phases or modify turn logic
4. **Upcoming needs:**
   - Starting phase (initial tile/village placement)
   - Divine powers ("4 actions next turn")
   - Multiplayer turn order

---

## Proposed Architecture

### TurnManager Responsibilities
- Phase management (SETUP, HARVEST, ACTIONS)
- Action validation and consumption
- Turn flow (harvest → actions → end turn)
- Harvest logic (determine types, collect yields)
- Turn counter / round tracking

### board_manager Keeps
- Manager orchestration (tile_manager, village_manager, etc.)
- Tile/village placement coordination
- UI setup and signal connections
- Scene initialization

---

## Implementation Plan

### Phase 1: Create TurnManager (30 min)

**Create `turn_manager.gd`:**
```gdscript
class_name TurnManager

enum Phase {
	SETUP,    # TODO: Initial tile/village placement (not implemented yet)
	HARVEST,
	ACTIONS
}

var current_phase: Phase = Phase.HARVEST
var current_player: Player

# References needed for harvest logic
var village_manager: VillageManager
var tile_manager: TileManager
var tile_pool: TilePool
var ui = null

# Signals
signal phase_changed(new_phase: Phase)
signal turn_started()
signal turn_ended()
signal game_ended()

# Validation helpers (KEY IMPROVEMENT!)
func can_perform_action(action_name: String = "action") -> bool:
	if current_phase != Phase.ACTIONS:
		print("Can only %s during actions phase!" % action_name)
		return false

	if current_player.actions_remaining <= 0:
		print("No actions remaining to %s!" % action_name)
		return false

	return true

func consume_action(action_name: String = "action") -> bool:
	if not can_perform_action(action_name):
		return false

	if not current_player.consume_action():
		print("ERROR: Failed to consume action for %s" % action_name)
		return false

	return true

# Phase query helpers
func is_setup_phase() -> bool:
	return current_phase == Phase.SETUP

func is_harvest_phase() -> bool:
	return current_phase == Phase.HARVEST

func is_actions_phase() -> bool:
	return current_phase == Phase.ACTIONS
```

### Phase 2: Move Turn Logic (45 min)

**Move FROM board_manager.gd TO turn_manager.gd:**

Lines to move:
- `28-35`: enum TurnPhase, current_phase, game_ended flags
- `402-415`: `start_harvest_phase()`
- `417-438`: `_get_available_harvest_types()`
- `440-478`: `harvest(resource_type)`
- `480-487`: Old `consume_action()` (merge into new helper)
- `489-551`: `end_turn()` and `_trigger_game_end()`

**Changes needed:**
- Rename `TurnPhase` → `Phase`
- Update all phase references to `Phase.HARVEST`, etc.
- Emit signals instead of directly calling UI methods
- Return values where board_manager needs to coordinate

### Phase 3: Update board_manager.gd (30 min)

**In `_ready()`:**
```gdscript
# Create turn manager
turn_manager = TurnManager.new()
add_child(turn_manager)
turn_manager.initialize(current_player, village_manager, tile_manager, tile_pool)

# Connect signals
turn_manager.phase_changed.connect(_on_phase_changed)
turn_manager.turn_ended.connect(_on_turn_ended)
```

**Replace verbose checks with helpers:**
```gdscript
# Before (5 lines):
if current_phase != TurnPhase.ACTIONS:
	print("Can only sell tiles during the actions phase!")
	return
if current_player.actions_remaining <= 0:
	print("No actions remaining to sell tile!")
	return
if not consume_action():
	return

# After (1 line):
if not turn_manager.consume_action("sell tile"):
	return
```

**Update these functions:**
- `_on_tile_selected_from_hand()` - use `is_actions_phase()` and `consume_action()`
- `on_tile_placed_from_hand()` - use `consume_action("place tile")`
- `sell_tile()` - use `consume_action("sell tile")`
- `on_village_placed()` - use `consume_action("place village")`
- `on_village_removed()` - use `consume_action("remove village")`
- `start_harvest_phase()` - delegate to `turn_manager.start_harvest_phase()`

### Phase 4: Update Other Files (15 min)

**placement_controller.gd:**
- Replace `board_manager.current_phase` with `board_manager.turn_manager.current_phase`
- Or add getter: `board_manager.get_current_phase()`

**tile_selector_ui.gd:**
- Update phase checks if needed
- Should mostly work via signals

---

## Expected Results

### Code Reduction
- board_manager.gd: ~550 lines → ~380 lines (30% reduction)
- turn_manager.gd: ~170 lines (new, focused)
- Total: Cleaner separation, same functionality

### Cleaner Action Validation
**Before:** 5 lines repeated 4+ times = 20+ lines
```gdscript
if current_phase != TurnPhase.ACTIONS: return
if current_player.actions_remaining <= 0: return
if not consume_action(): return
```

**After:** 1 line × 4 places = 4 lines
```gdscript
if not turn_manager.consume_action("action name"): return
```

### Easier to Extend
- **Starting phase:** Add `start_setup_phase()` method
- **Divine powers:** Add `set_next_turn_actions(4)` method
- **Multiplayer:** Add `next_player()` method

---

## Testing Checklist

After extraction, verify:
- [ ] Game starts correctly (harvest phase)
- [ ] Can place tiles from hand (consumes action)
- [ ] Can sell tiles (consumes action, only in actions phase)
- [ ] Can place villages (consumes action + resources)
- [ ] Can remove villages (consumes action, gives refund)
- [ ] Harvest phase works (auto-harvest or show buttons)
- [ ] End turn works (discard, draw, reset actions, new harvest)
- [ ] Actions counter updates correctly
- [ ] Phase UI updates correctly (harvest buttons ↔ actions counter)
- [ ] Game ends when tile bag empties

---

## Files to Read in Next Conversation

**Critical:**
- `board_manager.gd` - Main refactor target (~550 lines)
- `player.gd` - Action management methods
- `IMPLEMENTATION_STATUS.md` - Full context

**Reference if needed:**
- `tile_selector_ui.gd` - Phase UI updates
- `placement_controller.gd` - Phase validation checks
- `REFACTORING_PLAN.md` - This document

---

## Prompt for Next Conversation

```
I want to extract TurnManager from board_manager.gd to clean up turn flow logic.

Current Problems:
1. Action validation is verbose (5 lines repeated 4+ times)
2. board_manager is doing too much (~550 lines)
3. Phase checks are scattered everywhere

Goal:
- Create turn_manager.gd with Phase enum (SETUP/HARVEST/ACTIONS)
- Add validation helpers: can_perform_action(), consume_action()
- Move turn logic: start_harvest_phase, harvest, end_turn
- Reduce 5-line validation checks to 1-line helper calls
- Keep board_manager as thin orchestrator

Please read:
- @board_manager.gd (main refactor target)
- @player.gd (action management)
- @IMPLEMENTATION_STATUS.md (context)
- @REFACTORING_PLAN.md (detailed plan)

Follow the plan in REFACTORING_PLAN.md. Clean code, proper separation.
```

---

## Notes

- **Don't implement SETUP phase yet** - just add enum value with TODO comment
- **Keep game_ended logic** - will be useful for multiplayer
- **Emit signals** instead of direct UI calls for better decoupling
- **Test thoroughly** - turn system is critical, don't break it!
