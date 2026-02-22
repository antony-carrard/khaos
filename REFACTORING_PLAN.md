# Refactoring Plan

**Created:** 2026-01-15
**Status:** TO DO (after divine powers are complete)

This document captures technical debt and refactoring priorities identified during the prototype phase. Address these before transitioning to "final state."

---

## 🎯 Development Plan

### Phase 1: Feature Complete (Current)
- ✅ Core gameplay mechanics
- ✅ Divine powers system (5/8 powers done)
- 🔲 Complete remaining powers:
  - CHANGE_TILE_TYPE ✅
  - UPGRADE_TILE_KEEP_VILLAGE
  - DOWNGRADE_TILE_KEEP_VILLAGE

### Phase 2: Refactoring (Next)
**Start this phase once all 8 god powers are implemented.**

Follow the priorities below to clean up technical debt while the codebase is still manageable.

### Phase 3: Polish & Production
- UI/UX improvements
- Asset refinement
- Performance optimization
- Testing & bug fixes

---

## 🔴 **Critical Priority** - Do These First

### 1. ✅ Split tile_selector_ui.gd (DONE - before 2026-02-19)

**What was done:**
- Extracted all UI components into `ui/` folder
- `tile_selector_ui.gd` reduced from 1647 → 516 lines (orchestrator only)

**Resulting structure:**
```
ui/
├── god_panel.gd
├── hand_display.gd
├── harvest_ui.gd
├── resource_panel.gd
├── resource_type_picker.gd
├── tooltip_manager.gd
└── victory_screen.gd
```

---

### 2. ✅ Logger Singleton + Error Handling (DONE - 2026-02-20)

**What was done:**
- Created `logger.gd` autoload registered as `Log` (not `Logger` — conflicts with Godot 4.5+ built-in)
- Four levels: DEBUG / INFO / WARN / ERROR; debug builds show all, release builds show WARN+ only
- Replaced every `print()`, `push_warning()`, `push_error()` in the codebase with the appropriate `Log.*` call
- Added `assert(tile_bag.size() == 63)` in `tile_pool.gd` to catch tile distribution bugs immediately
- Added `Log.error()` on texture load failure in `hex_tile.gd` (was silent)
- Classified all board_manager / power_executor calls by true severity (logic bugs → error, user-blocked actions → warn, progress → info, chatty trace → debug)

**Files modified:** `logger.gd` (new), `project.godot`, `hex_tile.gd`, `god_selection_ui.gd`, `tile_pool.gd`, `board_manager.gd`, `victory_manager.gd`, `tile_manager.gd`, `god_manager.gd`, `player.gd`, `turn_manager.gd`, `power_executor.gd`, `village_manager.gd`, `ui/god_panel.gd`, `ui/hand_display.gd`, `placement/strategies/tile_placement_strategy.gd`

**Note:** Godot's built-in `Logger` class (4.5+) is an output interceptor for file/crash sinks, not a call-site severity filter. Our `Log` autoload complements it rather than duplicating it.

---

## 🟡 **Medium Priority** - Do Before "Final State"

### 3. ✅ Refactor board_manager.gd (DONE - 2026-02-19)

**What was done:**
- Extracted `hex_grid_utils.gd` — static class with all 5 hex math methods
- Extracted `power_executor.gd` — Node with all 6 god power execution handlers
- `board_manager.gd` reduced from 758 → 449 lines (-41%)
- Thin delegation wrappers preserved on `board_manager` so `placement_controller`, `victory_manager`, and all strategies need zero changes

**Resulting structure:**
```
board_manager.gd      449 lines   orchestrator (init, hand/village interactions, signal wiring)
hex_grid_utils.gd      79 lines   static hex math (axial_to_world, world_to_axial, neighbors, raycast)
power_executor.gd     257 lines   god power handlers (steal, destroy, upgrade, downgrade, change type)
```

**Remaining rough edges (low priority):**
- `get_axial_at_mouse` still uses `Vector2i(-999, -999)` sentinel — leave for dedicated raycast refactor
- `game_initializer.gd` not extracted — `_ready`, `show_god_selection`, `setup_ui` add children directly to board_manager, making extraction awkward for little gain at ~449 lines

---

### 4. ✅ Placement Strategy Pattern (DONE - 2026-02-19)

**What was done:**
- Replaced `PlacementMode` enum and two large `match` blocks with Strategy pattern
- Each of the 8 modes is now a self-contained class under `placement/strategies/`
- `placement_active: bool` eliminated — `current_strategy == null` is the single source of truth
- `PlacementController` reduced to ~270 lines (orchestrator only)
- File moved to `placement/placement_controller.gd` — first step toward folder-based organisation

**Structure:**
```
placement/
    placement_controller.gd
    strategies/
        placement_strategy.gd       # Base class
        tile_placement_strategy.gd
        village_place_strategy.gd
        village_remove_strategy.gd
        steal_harvest_strategy.gd
        destroy_village_free_strategy.gd
        change_tile_type_strategy.gd
        upgrade_tile_strategy.gd
        downgrade_tile_strategy.gd
```

**Remaining rough edges (low priority):**
- `Vector2i(-999, -999)` sentinel for "no hit" — no Option type in GDScript, acceptable for now
- `TilePlacementStrategy.on_click` still reads `controller.preview_tile`, `controller.selected_hand_index` etc. — mild reach into internals
- `cancel_placement()` clearing `pending_power` is a hidden coupling to player state

---

## 🔵 **Low Priority** - Polish for Later

### 5. ✅ Add Type Hints Throughout (DONE - 2026-02-22)

**What was done:**
- Added type hints to all class variables across all .gd files
- Typed function parameters and return types throughout
- `board_manager` typed as `Node3D` (no `class_name` on that file)
- `TilePool.TileDefinition` params left untyped — GDScript can't use inner-class types from other files as hints
- `Array[GodPower]`, `Array[God]` typed where applicable
- `var pending_power: GodPower = null` in player.gd
- `HexGridUtils.NO_HIT` constant added for the `Vector2i(-999, -999)` sentinel

**Files modified:** `hex_grid_utils.gd`, `hex_tile.gd`, `tile_manager.gd`, `village_manager.gd`, `camera_controller.gd`, `player.gd`, `turn_manager.gd`, `god_manager.gd`, `power_executor.gd`, `placement/placement_controller.gd`, all `ui/*.gd` files, `tile_selector_ui.gd`, `god_selection_ui.gd`

---

### 6. ✅ Extract Magic Numbers to Constants (DONE - 2026-02-22)

**What was done:**
- Added named `const` blocks at top of every file with UI layout values
- `HexGridUtils` got shared constants `RAY_DISTANCE` and `NO_HIT` (used by placement_controller)
- All `Vector2i(-999, -999)` sentinel literals replaced with `HexGridUtils.NO_HIT`
- `god_manager.gd` got `LE_BATISSEUR_FLAT_VILLAGE_COST: int = 4`
- All UI files have named constants for panel sizes, margins, font sizes, button sizes, corner radii

**Key constants added (examples):**
```gdscript
# hex_grid_utils.gd
const RAY_DISTANCE: float = 1000.0
const NO_HIT: Vector2i = Vector2i(-999, -999)

# tile_selector_ui.gd
const END_TURN_BUTTON_SIZE: Vector2 = Vector2(270, 40)
const VILLAGE_BUTTON_WIDTH: int = 130
const ACTIONS_FONT_SIZE: int = 16

# ui/victory_screen.gd
const VICTORY_PANEL_SIZE: Vector2 = Vector2(600, 500)
const VICTORY_TITLE_FONT_SIZE: int = 36
```

**Files modified:** All .gd files with UI layout or threshold values

---

### 7. ✅ Add Unit Tests (DONE - 2026-02-22, 39 tests across 4 suites)

**GdUnit4 v6.1.1** installed at `addons/gdUnit4/`. Test folder: `test/`.

**Test suites written:**

| File | Tests | Covers |
|------|-------|--------|
| `test/test_tile_pool.gd` | 8 | TilePool init, draw, empty bag, return tile |
| `test/test_victory_scoring.gd` | 6 | Resource/fervor/glory scoring, floor division |
| `test/test_hex_grid_utils.gd` | 8 | Axial neighbors, world positions, coordinate math |
| `test/test_player.gd` | 17 | Resources, fervor, glory, actions, hand management |

**Known issue — GdUnit4 crash on exit:**
GdUnit4 v6.1.1 has a SIGABRT crash during subprocess shutdown with Godot 4.6. All 39 tests pass; the crash is cosmetic (happens after results are sent to editor). **Fix: update GdUnit4** to a version that targets Godot 4.6 (Asset Library or GitHub releases).

**Still to add (low priority):**
- `test_tile_placement.gd` — placement validation, glory-on-plains rule, village-blocks-stacking
- `test_victory_territory.gd` — contiguous village group scoring (needs HexTile data separation first)
- `test_god_powers.gd` — le_batisseur flat cost, once-per-turn enforcement

---

## 📊 **Refactoring Checklist**

Use this checklist when ready to refactor:

### Must Do (Before "Final State"):
- [x] Split tile_selector_ui.gd into components ✅ (done before 2026-02-19)
- [x] Add error handling for resource loading ✅ (done 2026-02-20)
- [x] Add assertions for "impossible" states ✅ (done 2026-02-20)
- [x] Extract hex coordinate utilities from board_manager.gd ✅ (done 2026-02-19)
- [ ] Add tests for tile placement validation
- [ ] Add tests for victory scoring logic

### Should Do (Quality of Life):
- [ ] Refactor board_manager.gd if >800 lines
- [x] Extract magic numbers to constants ✅ (done 2026-02-22)
- [x] Add type hints to all class variables ✅ (done 2026-02-22)
- [x] Add type hints to function signatures ✅ (done 2026-02-22)
- [x] Consider logging system ✅ (done 2026-02-20 — Log autoload with 4 levels)

### Could Do (If Needed):
- [x] Implement placement strategy pattern ✅ (done 2026-02-19)
- [x] Extract power execution from board_manager ✅ (done 2026-02-19)
- [ ] Add comprehensive test coverage (>70%) — 39 tests exist, placement/territory/powers still needed
- [ ] Create game_initializer for setup flow

---

## 📝 **Notes**

### Why These Priorities?

**Critical First:**
- `tile_selector_ui.gd` is already painful to work with
- Missing error handling could cause mysterious bugs

**Medium Priority:**
- `board_manager.gd` is trending toward problems but not there yet
- Placement strategy pattern is only needed if complexity explodes

**Low Priority:**
- Type hints are nice-to-have (Godot's dynamic typing works fine)
- Magic numbers are cosmetic (don't affect functionality)
- Tests are important but prototype works without them

### Technical Debt is Normal

The issues identified here are **expected and normal** for rapid prototyping. You made the right trade-offs to move quickly. Now that the design is proven, it's the right time to clean up.

**Current State:** 8/10 for a prototype ⭐⭐⭐⭐⭐⭐⭐⭐☆☆
**After Refactoring:** Should easily hit 9/10 for production-quality code

---

## 🎯 **Getting Started**

When you're ready to refactor:

1. **Create a branch:** `git checkout -b refactor/ui-components`
2. **Start with victory_screen.gd** (easiest extraction, self-contained)
3. **Test thoroughly** after each extraction
4. **Commit frequently** (one component per commit)
5. **Update IMPLEMENTATION_STATUS.md** as you go

Remember: **Refactoring is not rewriting.** Keep the same behavior, just reorganize the code.

Good luck! 🚀
