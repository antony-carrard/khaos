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

### 1. Split tile_selector_ui.gd (1647 lines → ~200 lines + components)

**Problem:**
- Single 1647-line file handles everything UI-related
- Hard to navigate, modify, and maintain
- High risk of merge conflicts
- Violates Single Responsibility Principle

**Solution - Extract into components:**

```
ui/
├── tile_selector_ui.gd          # Orchestrator (~200 lines)
│   └── Manages layout, coordinates between components
├── hand_display.gd              # Hand card display (~150 lines)
│   └── Tile cards, sell buttons, placement selection
├── resource_panel.gd            # Resources/fervor/glory display (~100 lines)
│   └── Icon + count labels, reactive updates
├── god_panel.gd                 # God portrait & powers (~200 lines)
│   └── Portrait, name, power buttons, dynamic states
├── harvest_ui.gd                # Harvest phase buttons (~150 lines)
│   └── Resource type selection, phase-specific UI
├── victory_screen.gd            # Endgame overlay (~300 lines)
│   └── Score breakdown, winner announcement, new game
├── resource_type_picker.gd      # CHANGE_TILE_TYPE modal (~150 lines)
│   └── Overlay, resource buttons, cancel handling
└── tooltip_manager.gd           # Mouse-following tooltips (~100 lines)
    └── Village sell tooltip, centralized tooltip system
```

**Benefits:**
- Each file has single responsibility
- Easy to find and modify specific UI elements
- Parallel work possible (e.g., one person does victory screen, another does god panel)
- Faster iteration on UI changes

**Migration Strategy:**
1. Create `ui/` folder
2. Extract victory_screen.gd first (most self-contained, ~300 lines)
3. Extract resource_type_picker.gd (newest, fresh in mind)
4. Extract god_panel.gd (clean interface with signals)
5. Extract hand_display.gd
6. Extract harvest_ui.gd
7. Extract resource_panel.gd
8. Extract tooltip_manager.gd
9. Slim down tile_selector_ui.gd to orchestrator only

**Estimated Time:** 2-3 days

---

### 2. Improve Error Handling

**Problem:**
- Too optimistic about resources loading
- Silent failures can cause hard-to-debug issues
- No distinction between "expected" failures and "should never happen" bugs

**Examples of Missing Validation:**

```gdscript
# hex_tile.gd:110 - What if texture fails to load?
var texture = load(icon_path) as Texture2D
if texture:
    material.albedo_texture = texture
# No else branch - tile shows no icon, no error message

# board_manager.gd - Inconsistent error handling
var tile = tile_manager.get_tile_at(q, r)
if not tile:
    print("ERROR: No tile at position!")  # Good
    return false
# But then we don't validate texture loading
```

**Solution - Add Proper Error Handling:**

```gdscript
# For "should never happen" cases
assert(tile != null, "Tile must exist at this position")

# For expected failures
if not texture:
    push_error("Failed to load texture: %s" % icon_path)
    return false

# For resource loading
var texture = load(icon_path) as Texture2D
if not texture:
    push_error("Failed to load icon: %s" % icon_path)
    # Fallback: use default icon or show error indicator
    texture = load("res://icons/error.svg")
```

**Areas to Fix:**
1. **hex_tile.gd** - Validate icon texture loading
2. **god_selection_ui.gd** - Validate god image loading
3. **board_manager.gd** - Add assertions for "impossible" states
4. **tile_pool.gd** - Validate tile definitions on initialization
5. **victory_manager.gd** - Validate scoring calculations

**Optional: Logging System**

Consider creating `logger.gd` singleton:

```gdscript
# logger.gd
extends Node

enum Level { DEBUG, INFO, WARN, ERROR }

var current_level: Level = Level.INFO

func debug(message: String) -> void:
    if current_level <= Level.DEBUG:
        print("[DEBUG] ", message)

func error(message: String, context: Dictionary = {}) -> void:
    push_error("[ERROR] %s | Context: %s" % [message, context])
```

**Estimated Time:** 1-2 days

---

## 🟡 **Medium Priority** - Do Before "Final State"

### 3. Refactor board_manager.gd (663 lines, trending upward)

**Problem:**
- Growing toward "God object" anti-pattern
- Handles too many responsibilities:
  - Scene initialization
  - God selection flow
  - UI setup and signal wiring
  - Tile/village placement
  - Power execution
  - Coordinate conversion utilities

**Solution - Extract Responsibilities:**

**Option A: Extract utilities and executors**
```
board_manager.gd          # Main orchestrator (~400 lines)
hex_grid_utils.gd         # Static coordinate functions (~100 lines)
power_executor.gd         # Power execution handlers (~150 lines)
```

**Option B: Extract initialization**
```
board_manager.gd          # Main orchestrator (~400 lines)
game_initializer.gd       # Setup flow, god selection (~150 lines)
hex_grid_utils.gd         # Coordinate utilities (~100 lines)
```

**Recommendation:** Start with extracting hex_grid_utils.gd (easy win), then decide between A or B based on what feels cleaner.

**Functions to Extract:**
```gdscript
# To hex_grid_utils.gd (static methods)
static func axial_to_world(q, r, height, hex_size, tile_height) -> Vector3
static func world_to_axial(world_pos, hex_size) -> Vector2i
static func axial_round(q, r) -> Vector2i
static func get_axial_neighbors(q, r) -> Array[Vector2i]
static func get_axial_at_mouse(mouse_pos, camera, ...) -> Vector2i
```

**When to Do This:**
- When board_manager.gd hits 800+ lines, OR
- When you find yourself getting lost in the file

**Estimated Time:** 1 day

---

### 4. Consider Placement Strategy Pattern (if you add 5+ more modes)

**Problem:**
- `PlacementController` has 6 modes already
- Each new power might add a mode
- `update_village_preview()` has massive match statement (90 lines)
- Duplication across modes

**Current Approach (works fine for now):**
```gdscript
enum PlacementMode {
    TILE, VILLAGE_PLACE, VILLAGE_REMOVE,
    STEAL_HARVEST, DESTROY_VILLAGE_FREE, CHANGE_TILE_TYPE
}

match current_mode:
    PlacementMode.VILLAGE_PLACE:
        # 20 lines of preview logic
    PlacementMode.STEAL_HARVEST:
        # 15 lines of preview logic
    # ... etc
```

**Alternative - Strategy Pattern:**

```gdscript
# placement_strategy.gd (base class)
class_name PlacementStrategy
extends RefCounted

func update_preview(controller: PlacementController) -> void:
    pass

func handle_click(controller: PlacementController, q: int, r: int) -> bool:
    return false

func get_validity_color() -> Color:
    return Color.GREEN

# tile_placement_strategy.gd
class_name TilePlacementStrategy
extends PlacementStrategy

func update_preview(controller):
    # Tile-specific preview logic
    pass

# steal_harvest_strategy.gd
class_name StealHarvestStrategy
extends PlacementStrategy

func update_preview(controller):
    # Show green on enemy villages
    # Show harvest value in tooltip
    pass

func handle_click(controller, q, r):
    return controller.board_manager.on_steal_harvest(q, r)
```

**Usage:**
```gdscript
# In PlacementController
var current_strategy: PlacementStrategy = null

func select_steal_harvest_mode():
    current_strategy = StealHarvestStrategy.new()
    placement_active = true

func update_preview():
    if current_strategy:
        current_strategy.update_preview(self)
```

**Benefits:**
- Each mode is self-contained
- Easy to add new modes without modifying PlacementController
- Reduced complexity in main file
- Better testability

**When to Do This:**
- If you add 5+ more placement modes, OR
- If modes start having complex shared behavior

**Estimated Time:** 1-2 days (if needed)

---

## 🔵 **Low Priority** - Polish for Later

### 5. Add Type Hints Throughout

**Current:**
```gdscript
var board_manager = null
var tile_def = null
var god_manager_ref = null
```

**Better:**
```gdscript
var board_manager: BoardManager = null
var tile_def: TilePool.TileDefinition = null
var god_manager_ref: GodManager = null
```

**Benefits:**
- Autocomplete in Godot editor
- Catch type errors at parse time
- Self-documenting code
- Better IDE support

**Areas to Add Types:**
1. All class variables
2. Function parameters
3. Function return types
4. Array types: `Array[GodPower]` instead of `Array`

**Estimated Time:** 1 day (gradual, can do file-by-file)

---

### 6. Extract Magic Numbers to Constants

**Current:**
```gdscript
god_panel.custom_minimum_size = Vector2(350, 120)
button.custom_minimum_size = Vector2(220, 40)
tile_count_label.add_theme_font_size_override("font_size", 14)
```

**Better:**
```gdscript
# At top of file
const GOD_PANEL_SIZE := Vector2(350, 120)
const POWER_BUTTON_SIZE := Vector2(220, 40)
const TILE_COUNT_FONT_SIZE := 14
const UI_PADDING := 20

# Usage
god_panel.custom_minimum_size = GOD_PANEL_SIZE
```

**Benefits:**
- Easy to adjust layout globally
- Self-documenting (names explain purpose)
- Consistency across UI

**When to Do This:**
- During UI component extraction
- When tweaking UI layout

**Estimated Time:** 1 day (part of UI refactor)

---

### 7. Add Unit Tests

**Why Test a Prototype?**
- Core logic (tile placement, scoring) is already production-quality
- Tests catch regressions when refactoring
- Some logic is complex enough to benefit from tests now

**What to Test:**

**Critical (test before "final state"):**
```gdscript
# test_tile_placement.gd
func test_cannot_place_glory_on_plains():
    assert_false(board_manager._is_valid_resource_type_for_tile(
        TileManager.TileType.PLAINS,
        TileManager.ResourceType.GLORY
    ))

func test_village_blocks_stacking():
    # Place tile, place village, try to stack
    assert_false(tile_manager.is_valid_placement(...))

# test_victory_conditions.gd
func test_village_scoring():
    # 1 village on plains = 1pt
    # 1 village on hills = 2pts
    # 1 village on mountain = 3pts
    assert_equal(score, expected)

func test_territory_calculation():
    # Test contiguous village groups
    assert_equal(territory_points, expected)

# test_god_powers.gd
func test_le_batisseur_flat_cost():
    # All villages cost 4 regardless of terrain
    assert_equal(player.get_village_cost(2), 4)
    assert_equal(player.get_village_cost(8), 4)

func test_power_cannot_be_used_twice():
    god_manager.activate_power(power, player, board)
    assert_false(player.has_used_power(power.power_type))
```

**Nice to Have:**
- Power validation edge cases
- Deferred payment system
- Resource spending logic

**Testing Framework:**
- GdUnit4 (recommended) or Gut
- Run tests in CI/CD pipeline

**Estimated Time:** Ongoing (add as you refactor)

---

## 📊 **Refactoring Checklist**

Use this checklist when ready to refactor:

### Must Do (Before "Final State"):
- [ ] Split tile_selector_ui.gd into components
- [ ] Add error handling for resource loading
- [ ] Add assertions for "impossible" states
- [ ] Extract hex coordinate utilities from board_manager.gd
- [ ] Add tests for tile placement validation
- [ ] Add tests for victory scoring logic

### Should Do (Quality of Life):
- [ ] Refactor board_manager.gd if >800 lines
- [ ] Extract magic numbers to constants (during UI refactor)
- [ ] Add type hints to all class variables
- [ ] Add type hints to function signatures
- [ ] Consider logging system (if debugging is painful)

### Could Do (If Needed):
- [ ] Implement placement strategy pattern (if 10+ modes)
- [ ] Add comprehensive test coverage (>70%)
- [ ] Extract power execution from board_manager
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
