# Implementation Status

**Last Updated:** 2026-02-24

This document tracks detailed implementation progress and serves as context for continuing development.

## Recent Changes (2026-02-24) — Main Menu + Game Mode Architecture

**`GameConfig` autoload (`game_config.gd`):**
- Lightweight singleton holding `mode: GameMode` (HOT_SEAT / NETWORK), `player_count: int = 2`, `initialized: bool`
- Set by the main menu before loading `main.tscn`; `initialized = false` means board_manager falls back to its `@export player_count` (preserves direct editor testing)
- Foundation for network multiplayer: `GameConfig.mode` will drive Option-B local-player-index behavior in the next phase

**`main_menu.tscn` + `ui/main_menu.gd` (new):**
- Programmatic UI matching project style (dark bg, styled cards, outline fonts)
- CHAOS title with purple outline + tagline
- Two mode cards: **Hot-Seat** (enabled) → player count picker (1–4, default 2) → Start Game; **Network** (grayed out, "Coming Soon")
- Back button returns from count picker to mode cards
- `project.godot`: main scene changed from `main.tscn` → `main_menu.tscn`

**`board_manager.gd`:**
- `_ready()` now reads `GameConfig.player_count if GameConfig.initialized else player_count`; `@export player_count` still used when running `main.tscn` directly in the editor

**`ui/victory_screen.gd`:**
- "Return to Menu" button enabled and wired to `change_scene_to_file("res://main_menu.tscn")`
- "New Game" resets `GameConfig.initialized = false` before reload so export defaults apply

**Project rename Khaos → Chaos:**
- `project.godot` config name, `ui/main_menu.gd` title text, `README.md` — display text only
- Folder name (`/home/antony/code/khaos`) left unchanged; rename independently when editor is closed

---

## Recent Changes (2026-02-24) — Persistent Player Status Header

**New `ui/player_status_header.gd`:**
- Persistent top-of-screen strip showing all players' god portrait, name, and live stats (glory / resources / fervor) throughout both setup and gameplay
- Cards use each player's color: dark tinted card at rest, full player color floods in on active turn; name switches from player-colored to white simultaneously
- Small `▶` triangle indicator left of name on active card (replaces a "YOUR TURN" label)
- No background bar — cards float directly over the game world; `MOUSE_FILTER_IGNORE` on root so game clicks pass through
- Signal wiring: `player_changed` → full refresh of all cards; `resources/fervor/glory_changed` → lightweight single-card update mid-turn

**Lifecycle in `board_manager.gd`:**
- Created on its own `CanvasLayer` in `_ready()` after god selection (portraits available), before `_switch_to_player(0)` — that `bind()` call auto-seeds the header via signals
- Survives the setup→gameplay transition (no recreate needed); signals stay live
- `status_header.visible = false` in `_trigger_game_end()` — hides before victory overlay appears
- Files modified: `board_manager.gd` (new `var status_header`), `ui/player_status_header.gd` (new)

**Victory screen player color (`ui/victory_screen.gd`):**
- Each player's breakdown card now uses `player.player_color.darkened(0.55)` as background — consistent visual language with the header
- Non-winner name uses `player_color.lightened(0.3)`; winner name and border stay gold

---

## Recent Changes (2026-02-24) — Setup Phase UI Polish

**GodPanel integrated into SetupPhaseUI:**
- `SetupPhaseUI` now uses `CenterContainer → HBoxContainer → [GodPanel | setup panel | balancing spacer]`, mirroring the regular game's bottom bar layout
- `GodPanel` reused directly (same class, no duplication); power buttons appear naturally disabled during setup (wrong phase / no actions)
- `initialize()` now accepts `god_manager` and `board_manager` so `GodPanel.update_god_display()` can wire its signals; `board_manager.gd` updated accordingly
- Balancing `Control` spacer (width = `GodPanel.PANEL_SIZE.x`) on the right keeps the setup info panel visually centered regardless of round
- `GodPanel.PORTRAIT_SIZE` bumped `80 → 105`, `PANEL_SIZE` height `120 → 140` so the portrait fills most of the panel height
- Files modified: `ui/setup_phase_ui.gd`, `ui/god_panel.gd`, `board_manager.gd`

---

## Recent Changes (2026-02-24) — Tile Bag as Source of Truth for Upgrade & Transform

**Removed TILE_TYPE_YIELDS constant; tile values now come from the bag:**
- `upgrade_tile()` in `tile_manager.gd` draws a matching tile from the bag via `tile_pool.draw_tile_of_type()`; upgrade blocked if bag has no tile of that level
- `UpgradeTileStrategy.get_validity()` checks `tile_pool.has_tile_of_type(next_type)` — upgrade hexes go red when the bag is exhausted for that level
- `tile_manager.tile_pool` wired by `board_manager` after both are initialised
- Augia's CHANGE_TILE_TYPE power now also draws from the bag via `tile_pool.draw_tile_of_type_and_resource()`; transformation blocked (and picker button greyed out) when bag has no matching tile
- `show_resource_type_selection()` in `power_executor.gd` computes `available_types` from the bag and passes it to the picker; picker buttons show "(bag empty)" and are disabled for unavailable types
- Bug fix: `on_change_tile_type()` now uses the drawn tile's `sell_price`, `yield_value`, and `village_building_cost` instead of copying the old tile's values (previously Glory→Resources would keep sell_price=0)
- Removed "intentional digital convenience" design note from `power_executor.gd`
- NOTE comments mark exact insertion points for future return-to-bag logic in `tile_pool.gd`, `upgrade_tile()`, and `on_change_tile_type()`
- `TilePool` gains four helpers: `has_tile_of_type()`, `draw_tile_of_type()`, `has_tile_of_type_and_resource()`, `draw_tile_of_type_and_resource()`
- Files modified: `tile_pool.gd`, `tile_manager.gd`, `board_manager.gd`, `placement/strategies/upgrade_tile_strategy.gd`, `power_executor.gd`, `ui/resource_type_picker.gd`, `tile_selector_ui.gd`

---

## Recent Changes (2026-02-24) — Hand Refresh Refactor

**Single source of truth for hand size:**
- Added `Player.refresh_hand(tile_pool)` — clears all hand slots to null, then draws `HAND_SIZE` tiles. Encapsulates the discard+draw pair that was previously duplicated across two files.
- `turn_manager.gd:end_turn()` — replaced 3-line clear+draw with `current_player.refresh_hand(tile_pool)` (was also using hardcoded `3` instead of the constant).
- `board_manager.gd:_complete_setup()` — replaced `player.draw_tiles(tile_pool, HAND_SIZE)` with `player.refresh_hand(tile_pool)`.
- Removed duplicate `const HAND_SIZE: int = 3` from `board_manager.gd`; `Player.HAND_SIZE` is now the single source of truth.
- Files modified: `player.gd`, `turn_manager.gd`, `board_manager.gd`

---

## Recent Changes (2026-02-24) — Setup Tile Drawing Rule Change

**Deterministic setup tile draw:**
- Setup tiles are now always exactly one PLAINS/Resources + one PLAINS/Fervor tile (previously 2 random PLAINS tiles drawn by fishing-with-return loop)
- Added `TilePool.draw_plains_tile(resource_type)` — directly searches bag for the first matching tile, removes it, returns it. No reshuffling.
- Rewrote `Player.initialize_setup_tiles()` — two explicit calls to `draw_plains_tile`; removed the `MAX_SETUP_DRAW_ATTEMPTS` constant and the while-loop entirely.
- Files modified: `tile_pool.gd`, `player.gd`

---

## Recent Changes (2026-02-22) — Hot-Seat Multiplayer + Bug Fixes

**Hot-Seat Multiplayer (1–4 players):**
- **`ActivePlayerView` signal bridge** (`active_player_view.gd`) — UI connects to this once; `bind(player)` rewires all signals on each player switch. Eliminates stale-signal bugs.
- **`SetupPhaseUI` overlay** (`ui/setup_phase_ui.gd`) — standalone CanvasLayer created in `_ready()`, freed in `_complete_setup()`. `board_manager.ui` is **null during setup**; `setup_phase_ui` is **null during normal gameplay**. Completely replaces old setup hacks in `tile_selector_ui.gd`/`hand_display.gd`.
- **God selection per player** — `god_selection_ui.gd` now shows player name in their color as a header, greys out taken gods (shows "TAKEN" overlay on cards). `board_manager` loops through all players sequentially: `await show_god_selection(player, selected_so_far)`.
- **Player colors** — `PLAYER_COLORS` array in `board_manager.gd` (Blue P1, Red P2, Green P3, Yellow P4). Villages receive `_apply_player_color()` treatment in `village_manager.gd`.
- **3-round setup flow**: Round 1 (each player draws+places 1 PLAINS tile) → Round 2 (each player draws+places 1 PLAINS tile) → Round 3 (each player places free village on any tile). Replaced old single-player auto-village logic.
  - `player.setup_tile_positions: Array[Vector2i]` records placed tile coordinates (for reference; village placement no longer restricted to own tiles)
  - New `SetupVillagePlaceStrategy` — valid on any tile that exists and has no village
- **`_switch_to_player(index)`** — single function in `board_manager.gd` that updates `current_player`, `turn_manager.current_player`, `power_executor.current_player`, and calls `active_player_view.bind()`. No rewiring elsewhere.
- **Final round** — triggers when tile pool empties; game ends when the next player would be the triggering player again.
- **Victory screen** updated to accept multi-player `results` array; basic display works but layout tuning may be needed with 4 players.
- **`player_changed` connected in `_ready()`** — routes to `setup_phase_ui.update_for_player()` during setup, or `ui.update_current_player()` + `ui.update_hand_display()` during gameplay.
- **Files created:** `active_player_view.gd`, `ui/setup_phase_ui.gd`, `placement/strategies/setup_village_place_strategy.gd`
- **Files heavily modified:** `board_manager.gd`, `turn_manager.gd`, `player.gd`, `placement/placement_controller.gd`, `god_selection_ui.gd`, `village_manager.gd`, `ui/god_panel.gd`, `tile_selector_ui.gd`, `ui/hand_display.gd`

**Bug Fixes (same session):**
- **`placement_controller.gd` — strategy-replace-in-callback**: `handle_mouse_input` saves `var strategy = current_strategy` before `on_click`. Only sets `current_strategy = null` if `current_strategy == strategy` (i.e., the callback didn't install a new strategy). Previously, Round 3 village placement mode was immediately wiped after setup tile placed.
- **`hex_tile.gd` — Godot 4 API**: `depth_draw_opaque_only = false` → `depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS` (removes deprecation warning on every tile placement)
- **`power_executor.gd` + `downgrade_tile_strategy.gd` — Rakun affaissement**: Was targeting own villages instead of enemy. Fixed: `==` / `!=` direction corrected in both files.
- **`tile_manager.gd` — upgrade yield**: `upgrade_tile()` was copying `current_tile.yield_value` (Plains yield 1 onto a Hills tile). Fixed: upgrade now draws a tile from the bag and uses the drawn tile's `yield_value` (TILE_TYPE_YIELDS constant removed).
- **`god_selection_ui.gd` — double text**: Player header label said `"%s, choose your god"` while a separate `"Choisissez votre Dieu"` title existed. Fixed: header now shows only the player name.
- **`board_manager.gd` — sell tile resource type**: `sell_tile()` always called `add_resources()`. Fixed: matches on `tile.resource_type` — fervor tiles call `add_fervor()`.

---

## Recent Changes (2026-02-22) — Type Hints + Tests

**Type Hints + Magic Numbers (§5 and §6 of Refactoring Plan):**
- **Added type hints throughout** all .gd files:
  - Class variables, function parameters, and return types typed across all 30+ files
  - `board_manager` typed as `Node3D` (no `class_name` on board_manager.gd)
  - `TilePool.TileDefinition` params intentionally left untyped — GDScript 4 can't use inner-class types from other files as hints
  - `var pending_power: GodPower = null` in player.gd
  - `Array[GodPower]`, `Array[God]` typed where applicable
- **Extracted all magic numbers to named constants** in every file:
  - `HexGridUtils` got `RAY_DISTANCE: float = 1000.0` and `NO_HIT: Vector2i = Vector2i(-999, -999)`
  - All `Vector2i(-999, -999)` sentinel literals replaced with `HexGridUtils.NO_HIT`
  - `god_manager.gd` got `LE_BATISSEUR_FLAT_VILLAGE_COST: int = 4`
  - All UI files now have named `const` blocks for sizes, margins, font sizes, corner radii
  - Camera: `NEAR_PARALLEL_THRESHOLD: float = 0.0001` (was inline literal)
  - Player: `BASE_ACTIONS = 3`, `SETUP_TILE_COUNT = 2`, `MAX_SETUP_DRAW_ATTEMPTS = 100`

---

**Unit Tests — GdUnit4 v6.1.1 (§7 of Refactoring Plan):**
- **Installed GdUnit4 v6.1.1** at `addons/gdUnit4/`, test folder `test/`
- **39 tests across 4 suites** — all pass:
  - `test/test_tile_pool.gd` (8 tests): pool init, draw, empty-bag guard, return tile
  - `test/test_victory_scoring.gd` (6 tests): resource/fervor/glory point formulas, floor division, totals
  - `test/test_hex_grid_utils.gd` (8 tests): neighbor count, known neighbors of origin, world positions, uniqueness
  - `test/test_player.gd` (17 tests): add/spend resources & fervor, glory, action consumption, hand size
- **Patterns established** (see MEMORY.md):
  - `auto_free()` for all manager instances — no `add_child()` needed for pure-logic tests
  - Inject state directly into `placed_tiles[Vector3i]` / `placed_villages[Vector2i]` to skip PackedScene
  - HexTile (StaticBody3D) excluded from tests — physics RID creation on GdUnit4's worker thread causes SIGABRT; separate tile data from scene node first
- **Known issue — GdUnit4 exit crash:** SIGABRT occurs after all tests complete during subprocess shutdown. Root cause: GdUnit4 v6.1.1 + Godot 4.6 compatibility bug (missing `GdUnitTools.dispose_all()` in editor runner + `--no-window` Vulkan init). Tests pass correctly; crash is cosmetic. **Fix: update GdUnit4** from Asset Library or GitHub.

---

## Recent Changes (2026-02-20)

**Logger Singleton + Error Handling (§2 of Refactoring Plan):**
- **Created `logger.gd`** autoload registered as `Log` (name avoids Godot 4.5+ built-in `Logger` conflict)
  - Four severity levels: DEBUG / INFO / WARN / ERROR
  - Debug builds: all levels visible. Release builds: WARN+ only (suppresses chatty draw/placement trace)
  - Routes: `Log.debug/info` → `print()`, `Log.warn` → `push_warning()`, `Log.error` → `push_error()`
- **Replaced every raw `print()` / `push_error()` / `push_warning()` in the codebase** — zero remain outside `logger.gd`
  - True bugs (logic errors that shouldn't happen) → `Log.error`
  - User-blocked actions (wrong phase, can't afford, empty slot) → `Log.warn`
  - Game events (tile placed, village built, turn started) → `Log.info`
  - High-frequency trace (every draw, every resource change) → `Log.debug`
- **Added `assert(tile_bag.size() == 63)`** in `tile_pool.gd` — fires immediately if tile distribution is edited wrongly
- **Added `Log.error` on texture load failure** in `hex_tile.gd` — was previously silent
- **Files modified:** `logger.gd` (new), `project.godot`, and 15 existing `.gd` files

## Recent Changes (2026-02-19)

**board_manager.gd Split (Latest):**
- **Extracted `hex_grid_utils.gd`** — static class with all hex math (no instance needed)
  - `axial_to_world`, `world_to_axial`, `axial_round`, `get_axial_neighbors`, `get_axial_at_mouse`
  - Thin wrappers kept on `board_manager` so all existing callers are unchanged
- **Extracted `power_executor.gd`** — Node with all 6 god power execution handlers
  - `on_steal_harvest`, `on_destroy_village_free`, `on_upgrade_tile`, `on_downgrade_tile`
  - `show_resource_type_selection`, `on_change_tile_type`, `_is_valid_resource_type_for_tile`
  - Initialized at end of `setup_ui()` once all references (incl. UI) are available
- **`board_manager.gd` reduced from 758 → 449 lines (-41%)**
- **No behaviour changes** — strategies, placement_controller, and victory_manager untouched

**Strategy Pattern Refactor + Godot 4.6 Upgrade:**
- **Upgraded to Godot 4.6** — project.godot, main.tscn node unique_ids, victory_manager.gd indentation
- **Replaced PlacementMode enum with Strategy pattern** — each of 8 placement modes is now a self-contained class
  - Eliminated `placement_active: bool` — `current_strategy == null` is the single source of truth
  - Removed two large `match current_mode` blocks (~200 lines)
  - `PlacementController` reduced to ~270 lines (orchestrator only)
- **Reorganised into `placement/` folder** — first step toward folder-based project structure
  - `placement/placement_controller.gd`
  - `placement/strategies/` (9 files: base class + 8 strategy implementations)
- **No behaviour changes** — all 8 modes work identically, just cleaner internals

## Recent Changes (2026-01-18)

**UPGRADE_TILE_KEEP_VILLAGE & DOWNGRADE_TILE_KEEP_VILLAGE Powers (Latest):**
- **Implemented Augia's UPGRADE_TILE_KEEP_VILLAGE power** (5 fervor + 1 action)
  - Upgrades tile from PLAINS→HILLS or HILLS→MOUNTAIN without destroying village
  - Added `tile_manager.upgrade_tile()` method that **stacks a new tile on top**
  - Added UPGRADE_TILE_KEEP_VILLAGE placement mode to placement_controller.gd
  - Preview shows green on own villages with upgradeable tiles (not MOUNTAIN)
  - Validates tile can be upgraded (not already at max level)
  - board_manager.on_upgrade_tile() executes the upgrade with deferred payment
  - **Updates village position** to match new tile height after upgrade
- **Implemented Rakun's DOWNGRADE_TILE_KEEP_VILLAGE power** (4 fervor + 1 action)
  - Downgrades tile from MOUNTAIN→HILLS or HILLS→PLAINS without destroying village
  - Added `tile_manager.downgrade_tile()` method that **removes the top tile**
  - Added DOWNGRADE_TILE_KEEP_VILLAGE placement mode to placement_controller.gd
  - Preview shows green on own villages with downgradeable tiles (not PLAINS)
  - Validates tile can be downgraded (not already at min level)
  - board_manager.on_downgrade_tile() executes the downgrade with deferred payment
  - **Updates village position** to match new tile height after downgrade
- **Both powers use deferred payment system** (pay when action completes, not on button click)
- **Key insight: Tiles stack vertically!**
  - MOUNTAIN position = PLAINS (h0) + HILLS (h1) + MOUNTAIN (h2)
  - HILLS position = PLAINS (h0) + HILLS (h1)
  - PLAINS position = PLAINS (h0)
  - **Upgrade = Add tile on top** (bypasses village blocking rule)
  - **Downgrade = Remove top tile** (reveals tile below)
  - Resource properties (type, yield, costs) are copied to new top tile
  - Villages automatically move up/down with terrain height changes
- **Files modified:** tile_manager.gd, placement_controller.gd, board_manager.gd, god_manager.gd
- **Result:** All 8 divine powers now fully functional! Complete power system ready for gameplay.

**CHANGE_TILE_TYPE Power Implementation:**
- **Implemented Augia's CHANGE_TILE_TYPE power** (2 fervor + 1 action)
  - Added CHANGE_TILE_TYPE placement mode to placement_controller.gd
  - Created resource type picker UI modal (tile_selector_ui.gd)
	- Shows 3 buttons: Resources, Fervor, Glory (or 2 if Plains tile)
	- Purple border matching Augia's theme color
	- Prevents multiple overlays from spawning
	- Consumes mouse input to prevent click-through
  - Validates Glory cannot be placed on Plains tiles
  - Design note: Does NOT check tile pool (digital convenience - see board_manager.gd:482-486)
  - Successfully changes tile icon and resource type in-place
- **Fixed deferred payment system** for selection-based powers
  - Powers now split into "immediate" and "deferred" categories
  - Immediate powers (EXTRA_ACTION, SECOND_HARVEST): Pay when button clicked
  - Deferred powers (STEAL_HARVEST, DESTROY_VILLAGE_FREE, CHANGE_TILE_TYPE): Pay when action completes
  - Added `player.pending_power` to track powers awaiting payment
  - Added `god_manager.complete_deferred_power()` called on successful selection
  - Added `god_manager._power_requires_deferred_payment()` helper
  - Prevents "paid but failed" scenarios when player cancels (ESC key)
  - Clears pending_power on cancellation or validation failure
- **Fixed UI overlay bugs**
  - Overlay now hides immediately (visible=false before queue_free)
  - Added `_on_overlay_gui_input()` to consume mouse events
  - Cancel placement mode BEFORE hiding overlay (prevents re-triggering)
  - Added guard check to prevent multiple overlays
- **Files modified:** board_manager.gd, god_manager.gd, placement_controller.gd, player.gd, tile_selector_ui.gd
- **Files created:** REFACTORING_PLAN.md (technical debt documentation)
- **Result:** 6/8 divine powers fully functional, deferred payment prevents resource loss on cancellation

## Recent Changes (2026-01-14)

**Divine Powers System (Latest):**
- **Implemented data-driven god architecture** - god.gd, god_power.gd, god_manager.gd
  - PowerType enum for all power types (active + passive)
  - God class holds powers array
  - GodManager centralizes all power logic and god definitions
- **God selection UI at game start** - god_selection_ui.gd
  - Full-screen overlay with 4 clickable god cards (1×4 horizontal layout)
  - Shows god portraits, names, and power descriptions
  - Cards resized to 400×500 to fit 1920×1080 resolution
  - Fixed clickability with MOUSE_FILTER_IGNORE on all overlay elements
- **In-game god display** - tile_selector_ui.gd
  - God panel on left side of UI with horizontal layout (portrait+name left, powers right)
  - Compact 350×120 god panel with vertically centered content
  - Active powers (purple, clickable) vs passive (gray, disabled)
  - Power buttons show fervor cost with SVG pray icon (matching tile button style)
  - **Once-per-turn limitation** - powers can only be used once per turn
  - **Dynamic button states** - automatically gray out when:
	- Player can't afford fervor cost
	- Power already used this turn
	- Not in actions phase
	- No actions remaining
  - **Reactive UI updates** - connected to multiple signals:
	- fervor_changed, power_used, actions_changed, phase_changed
	- Buttons update immediately without "tick lag"
  - Power buttons wired to god_manager.activate_power()
- **Village cost refactoring** - player.gd
  - Added `player.get_village_cost(base_cost)` helper method
  - Encapsulates god ability modifications (e.g., Le Bâtisseur's flat cost)
  - Applied in board_manager.gd and placement_controller.gd
- **Bonus action tracking** - player.gd
  - Added `max_actions_this_turn` field to track total actions including bonuses
  - Actions display now shows correct max (e.g., "4/4" not "4/3" with Bicéphallès power)
- **Resolution fix** - project.godot updated to 1920×1080
- **Powers implemented:**
  - ✅ **Le Bâtisseur passive** (FLAT_VILLAGE_COST) - All villages cost 4 resources
  - ✅ **Bicéphallès EXTRA_ACTION** - Grant +1 action next turn (4 actions total)
  - ✅ **Bicéphallès SECOND_HARVEST** - Trigger harvest UI again (doesn't consume action)
  - ✅ **Rakun STEAL_HARVEST** - Click enemy village to steal its harvest
	- Added STEAL_HARVEST placement mode to placement_controller.gd
	- Preview shows green on enemy villages, shows yield in tooltip
	- board_manager.on_steal_harvest() adds tile yield to player resources
  - ✅ **Le Bâtisseur DESTROY_VILLAGE_FREE** - Destroy enemy village without paying
	- Added DESTROY_VILLAGE_FREE placement mode to placement_controller.gd
	- Preview shows green on enemy villages (no adjacency/level restrictions)
	- board_manager.on_destroy_village_free() removes village without compensation
  - ✅ **Augia CHANGE_TILE_TYPE** - Change resource type of own tiles (2 fervor + 1 action)
	- Added CHANGE_TILE_TYPE placement mode to placement_controller.gd
	- Resource type picker modal UI with dynamic buttons (no Glory on Plains)
	- board_manager.on_change_tile_type() changes tile icon and resource type in-place
  - ✅ **Augia UPGRADE_TILE_KEEP_VILLAGE** - Upgrade tile without destroying village (5 fervor + 1 action)
	- Added UPGRADE_TILE_KEEP_VILLAGE placement mode to placement_controller.gd
	- tile_manager.upgrade_tile() preserves resource properties
	- Preview validates tile can be upgraded (not MOUNTAIN)
  - ✅ **Rakun DOWNGRADE_TILE_KEEP_VILLAGE** - Downgrade tile without destroying village (4 fervor + 1 action)
	- Added DOWNGRADE_TILE_KEEP_VILLAGE placement mode to placement_controller.gd
	- tile_manager.downgrade_tile() preserves resource properties
	- Preview validates tile can be downgraded (not PLAINS)
- **All 8 divine powers now complete!**
- **Files modified:** board_manager.gd, player.gd, placement_controller.gd, turn_manager.gd, tile_selector_ui.gd, tile_manager.gd, god_manager.gd, project.godot
- **Files created:** god.gd, god_power.gd, god_manager.gd, god_selection_ui.gd, gods/ (images)
- **Result:** Complete god selection system with all 8 divine powers fully functional
- **TODO:** Test multi-target powers once multiplayer is implemented (DESTROY_VILLAGE_FREE, STEAL_HARVEST need enemy villages)

## Recent Changes (2026-01-07)

**Setup Phase Implementation (Latest):**
- **Implemented complete setup phase per rules.md (lines 44-67)**
- **Players now start in SETUP phase** instead of having tiles auto-placed
- **Draw 2 PLAINS tiles from pool** - player.gd `initialize_setup_tiles()` draws from tile_pool
- **Place 2 tiles + free villages** - placement_controller auto-places villages during setup (no cost)
- **Setup UI with gold borders** - tile_selector_ui.gd shows special setup cards, centered layout
- **Proper phase transition** - after 2 tiles placed → draw 3 tiles into hand → HARVEST phase
- **UI updates correctly** - setup tiles disappear, normal hand appears with newly drawn tiles
- **Files modified:** player.gd (setup_tiles array), turn_manager.gd (setup phase logic), tile_selector_ui.gd (setup UI), placement_controller.gd (auto-villages), board_manager.gd (removed auto-placement)
- **Result:** Game now follows rules.md setup sequence correctly

**TurnManager Extraction (Earlier):**
- **Extracted turn logic to dedicated TurnManager class** - moved ~170 lines from board_manager.gd
- **board_manager.gd reduced** from 651 → 461 lines (29% reduction)
- **Created turn_manager.gd** (247 lines) with clean Phase enum (SETUP/HARVEST/ACTIONS)
- **Simplified action validation** - reduced 5-line checks to 1-line helper calls:
  - `turn_manager.consume_action("action name")` handles phase + action validation
  - Applied to: sell_tile, place_village, remove_village, place_tile
- **Added validation helpers:** `can_perform_action()`, `is_harvest_phase()`, `is_actions_phase()`
- **Signal-based architecture:** `phase_changed`, `turn_started`, `turn_ended`, `game_ended`
- **Updated all references:** placement_controller.gd, tile_selector_ui.gd use turn_manager
- **Result:** Cleaner separation of concerns, easier to extend for multiplayer/divine powers

## Earlier Changes (2026-01-07)

**Simplified Tile Economics:**
- **Tiles are now FREE to place** - removed buy_price entirely, only consumes 1 action
- **Unified sell price** - all non-Glory tiles sell for 1 resource (was varied 1-4)
- **Per-tile village costs** - each tile stores its own village_building_cost instead of using per-type defaults
  - Allows future design flexibility (e.g., high-yield mountains costing more to build on)
  - Current defaults remain: Plains=2, Hills=4, Mountains=8
- **UI simplified** - removed cost display and red "unaffordable" borders from hand cards

**Cleaned Up Test Mode:**
- **Removed `ui_mode` checks from game logic** - game rules are now consistent
- **Added `@export var test_mode`** in board_manager - toggle in editor Inspector
- **Test mode now affects ONLY starting conditions:**
  - Normal: Start with 0 resources, 0 fervor, 3 actions per turn
  - Test: Start with 999 resources, 999 fervor, 999 actions (for design/testing)
- **Debug keyboard shortcuts (1/2/3 for quick tile placement)** guarded by `OS.is_debug_build()`
- **Result:** Removed ~50 lines of scattered conditionals, much cleaner architecture

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
- ✅ TileDefinition class with per-tile properties:
  - tile_type, resource_type, yield_value
  - village_building_cost (per-tile, allows design flexibility)
  - sell_price (resources gained when sold from hand)
- ✅ Draw/shuffle mechanics
- ✅ Return tile to bag (for starting tile selection)
- ✅ Remaining count tracking

**Turn System** (turn_manager.gd - extracted and complete!)
- ✅ Turn phases (SETUP, HARVEST, ACTIONS) with Phase enum
- ✅ **3-round setup phase** (hot-seat multiplayer)
  - Round 1 & 2: each player draws 1 PLAINS tile and places it (`on_setup_tile_placed`)
  - Round 3: each player places 1 free village on any existing tile (`on_setup_village_placed`)
  - `setup_action_done` signal drives board_manager's per-player sequencing
  - `_complete_setup()` — draws 3 tiles for all players, switches to Player 0, begins normal gameplay
  - `SetupPhaseUI` (CanvasLayer) displays current player's setup state; freed after setup
- ✅ Harvest phase with smart type detection
  - Auto-harvest if only one resource type available
  - Show choice UI if multiple types
- ✅ Actions phase (3 actions per turn)
- ✅ Action validation helpers: `can_perform_action()`, `consume_action()`
- ✅ Phase query helpers: `is_setup_phase()`, `is_harvest_phase()`, `is_actions_phase()`
- ✅ End turn flow (discard → draw 3 → reset actions → harvest)
- ✅ Turn start bonus (+1 resource, +1 fervor)
- ✅ Signal-based phase changes and turn events

**User Interface** (tile_selector_ui.gd)
- ✅ **Setup phase UI**
  - Gold-bordered tile cards with "FREE" label
  - "Setup Phase - Place Your Starting Tiles" title
  - Center-aligned layout (prevents shifting when tiles placed)
  - Compact "✓ Placed" placeholders (same width as tiles)
  - Automatically transitions to normal hand display after setup
- ✅ Hand display with visual tile cards
  - Color-coded by tile type
  - Shows resource icon and yield value
  - Dims tiles when no actions available (gray border)
- ✅ Resource panel (wood/pray/star icons with counts)
- ✅ Turn phase UI
  - Harvest buttons (shows only available types)
  - Actions counter (visible only during actions phase)
  - End turn button
- ✅ Signal-connected reactive updates (no manual UI calls needed!)

**Placement Controller** (placement/placement_controller.gd)
- ✅ Mouse-based placement with preview
- ✅ 9 strategies (TILE, VILLAGE_PLACE, VILLAGE_REMOVE, STEAL_HARVEST, DESTROY_VILLAGE_FREE, CHANGE_TILE_TYPE, UPGRADE_TILE_KEEP_VILLAGE, DOWNGRADE_TILE_KEEP_VILLAGE, SETUP_VILLAGE_PLACE)
- ✅ Valid/invalid preview coloring
- ✅ Hand tile placement integration
- ✅ **Setup phase support** — `SetupVillagePlaceStrategy` for Round 3 free village placement on any tile
- ✅ Strategy-in-callback safety: saves `current_strategy` before `on_click`, only nulls if unchanged
- ✅ ESC to cancel placement

**Starting Conditions**
- ✅ **3-round setup phase** — hot-seat, each player participates in each round
  - Round 1: each player draws 1 PLAINS tile, places it on board
  - Round 2: each player draws 1 PLAINS tile, places it on board
  - Round 3: each player places 1 free village on any tile
  - After all rounds: each player draws 3 tiles into hand
  - `player.setup_tile_positions: Array[Vector2i]` records where tiles were placed
- ✅ God selection per player before setup — taken gods greyed out for later players
- ✅ Player colors (Blue/Red/Green/Yellow) assigned at start; villages rendered in player color
- ✅ Starting resources: +1 resource, +1 fervor from `start_turn()` after setup
- ✅ Test mode: 999 resources/fervor/actions for design testing

**Tile Economics**
- ✅ **Placing tiles is FREE** - no resource cost, only consumes 1 action
- ✅ **Selling tiles** (board_manager.gd, tile_selector_ui.gd):
  - Sell button on each hand card (green for sellable, gray disabled for Glory)
  - All non-Glory tiles sell for 1 resource (unified pricing)
  - Glory tiles cannot be sold (sell_price = 0)
  - Costs 1 action during actions phase
  - Fixed-size hand array (3 slots) with null for empty slots
  - Tiles stay anchored to position when sold (no UI shifting)
  - Empty slot placeholders with disabled sell button

**Village Building** (board_manager.gd, placement_controller.gd, hex_tile.gd)
- ✅ **Per-tile village costs** stored in each tile (not per-type)
  - Current defaults: Plains=2, Hills=4, Mountains=8
  - Allows future design flexibility (e.g., high-yield tiles cost more)
- ✅ Costs 1 action during actions phase
- ✅ Preview shows red when player can't afford or has no actions
- ✅ Preview shows red during harvest phase (can only build during actions)
- ✅ Validation prevents placement without sufficient resources or actions

**Village Selling/Removal** (board_manager.gd, placement_controller.gd, tile_selector_ui.gd)
- ✅ Remove your own villages for half the building cost refund
  - Refund calculated from tile's village_building_cost / 2
  - Typical refunds: Plains=1, Hills=2, Mountains=4
- ✅ Costs 1 action during actions phase
- ✅ Mouse-following tooltip shows refund amount when hovering villages
- ✅ Tooltip only appears in remove mode when hovering your own villages
- ✅ Preview shows red for villages you don't own (ownership validation)
- ✅ Guard clause pattern for clean early returns in preview code

**Action Validation & UI Polish** (player.gd, board_manager.gd, placement_controller.gd, tile_selector_ui.gd)
- ✅ `can_place_tile()` validates actions only (tiles are free to place)
- ✅ Prevents tile placement when actions exhausted
- ✅ Preview shows red when no actions available
- ✅ Black text outlines for better visibility (actions, resources, tile count)
- ✅ Auto-disable village/tile buttons when out of actions
- ✅ Consistent dimming for disabled tiles (text, icons, borders)
- ✅ Visual feedback: gray/dimmed when no actions available
- ✅ Can sell tiles when you have actions available
- ✅ No focus indicators on disabled buttons
- ✅ Placement mode auto-cancels when phase changes

**Endgame & Victory System** (victory_manager.gd, board_manager.gd, tile_selector_ui.gd)
- ✅ Game end detection when tile bag empties (board_manager.gd:520-526)
- ✅ Final round notification with fade-out animation (tile_selector_ui.gd:755-778)
- ✅ All players complete current round before game ends (fair multiplayer)
- ✅ Territory calculation using flood-fill algorithm (victory_manager.gd:121-157)
- ✅ Configurable scoring formula (SIMPLE: n, LINEAR: n-1, PROGRESSIVE: (n-1)×n)
- ✅ Complete score breakdown (villages, resources/fervor pairs, glory, territory)
- ✅ Victory screen with detailed scoring display (tile_selector_ui.gd:781-1010)
- ✅ Winner determination with tie handling
- ✅ New Game button to restart (reloads scene)
- ✅ Scoring per rules.md: 1pt/village on plains, 2pts hills, 3pts mountains
- ✅ Resource/fervor pairs (floor division: 7 resources = 3 points)
- ✅ Territory groups scored based on contiguous villages (BFS graph traversal)
- ✅ Multiplayer-ready design (array-based score format)

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
├── Owns: players[] array, tile_manager, village_manager, placement_controller,
│         tile_pool, turn_manager, god_manager, power_executor, active_player_view
├── During setup: setup_phase_ui (CanvasLayer), ui = null
├── During gameplay: ui (TileSelectorUI), setup_phase_ui = null
├── Handles: player switching, setup rounds, final round, god selection loop
├── Delegates: turn flow → turn_manager, god power execution → power_executor
└── Uses: HexGridUtils (static, no instance)

active_player_view (signal bridge)
├── Mirrors player signals so UI connects once, never rewires
├── bind(player) disconnects old player, connects new, emits current values
└── Emits: resources_changed, fervor_changed, glory_changed, actions_changed,
		  power_used, player_changed

turn_manager (turn flow)
├── Owns: reference to current_player, village_manager, tile_manager, tile_pool
├── Handles: phase management, harvest logic, action validation
└── Emits: phase_changed, turn_started, turn_ended, setup_action_done

power_executor (god power effects)
├── Owns: references to current_player, tile_manager, village_manager, god_manager,
│         placement_controller, ui, board_manager
└── Handles: all on_* callbacks triggered by placement strategies

HexGridUtils (static hex math)
└── Pure functions: axial_to_world, world_to_axial, axial_round, get_axial_neighbors, get_axial_at_mouse
```

### UI Initialization Order
1. Create UI components
2. Connect player signals to UI callbacks
3. Call `ui.update_turn_phase()` to show correct phase UI
4. Emit initial signal values to populate UI

---

## 🚧 Partially Implemented

**Debug Features**
- ✅ Keys 1/2/3 for quick tile placement (guarded by `OS.is_debug_build()`)
- ✅ Test mode toggle (`@export var test_mode`) for unlimited resources
- No remaining test/debug issues

---

## ❌ Not Yet Implemented (From rules.md)

### High Priority (Next Session)

**UI Polish**
- ✅ ~~Show tile pool remaining count~~ (DONE - shows above hand with color coding)
- ✅ ~~Win condition & victory screen~~ (DONE - complete endgame system implemented)
- Better card hover effects
- Disable end turn during harvest phase
- Show "must harvest first" feedback

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

**Completed Extractions:**
- ✅ **TurnManager extracted** (2026-01-07) - Turn system now in dedicated turn_manager.gd class
- ✅ **HexGridUtils extracted** (2026-02-19) - Static hex math class, no instance needed
- ✅ **PowerExecutor extracted** (2026-02-19) - All god power execution handlers in dedicated Node

**Debug Logging:**
- ✅ `Log` autoload singleton with DEBUG/INFO/WARN/ERROR levels (done 2026-02-20)
- File-based logging not needed yet; add a `Logger` subclass + `OS.add_logger()` if crash reporting becomes necessary

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
- GdUnit4 v6.1.1 crashes on exit with Godot 4.6 (cosmetic — tests pass before crash). Update GdUnit4 to fix.
- Victory screen layout may need tuning with 3–4 players (designed for 1 player originally).
- No unit tests yet for multiplayer switching, setup rounds, or `ActivePlayerView.bind()`.

---

## 💡 Next Session Recommendations

**Quick Wins:**
1. ✅ ~~Implement tile selling~~ (DONE)
2. ✅ ~~Add village building cost~~ (DONE)
3. ✅ ~~Fix action validation~~ (DONE)
4. ✅ ~~Implement end game detection and point counting~~ (DONE)
5. ✅ ~~Implement setup phase~~ (DONE — 3-round hot-seat multiplayer setup)
6. ✅ ~~Implement divine powers system~~ (DONE — all 8 powers)
7. ✅ ~~Add multiplayer player switching~~ (DONE — hot-seat 1–4 players, ActivePlayerView bridge)

**What's Left (Recommended Order):**
1. **Playtesting** — Play a full 2-player game end-to-end. Look for: village color visibility, SetupPhaseUI layout on 1080p, final round trigger edge cases, god power interactions.
2. **Victory screen multi-player layout** — Currently fragile with 4 players; may need scrollable or grid layout.
3. **UI polish** — "Disable end turn during harvest" feedback, better card hover effects.
4. **Unit tests for new systems** — `ActivePlayerView.bind()`, setup round transitions, `_switch_to_player()`.
5. **Camera controls** — Pan, zoom, rotate for larger boards.

---

## 📚 Context for New Sessions

**Current State Summary (2026-02-22):**
You have a **fully playable hot-seat multiplayer** (1–4 players) turn-based hexagonal tile placement game. Game flow: god selection per player (taken gods greyed out) → 3-round setup (each player places 1 PLAINS tile × 2 rounds, then 1 free village) → normal gameplay → final round on tile bag empty → victory screen with per-player scoring.

**Multiplayer architecture:** `ActivePlayerView` node acts as a permanent signal bridge — UI connects to it once. `_switch_to_player(index)` in `board_manager` is the single player-switching function; `active_player_view.bind(player)` handles all rewiring. Villages are color-coded by player. `SetupPhaseUI` (CanvasLayer) owns setup display; it is freed when setup ends, and `board_manager.ui` (TileSelectorUI) is null until then.

**God system:** Data-driven (god.gd, god_power.gd, god_manager.gd). All 8 divine powers fully functional. Deferred payment prevents resource loss on cancellation. Power buttons dynamically grey out based on fervor, phase, and once-per-turn tracking.

**Code patterns to remember:**
- Strategy-in-callback: save `var strategy = current_strategy` before `on_click`, only null if unchanged
- Tile yield values come from the drawn `TileDefinition` (bag), not a constant
- Rakun downgrade = enemy villages; Augia upgrade/transform = own villages
- `depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS` (Godot 4, not `depth_draw_opaque_only`)
- Sell tile: match `tile.resource_type` to call correct `add_*()` method

**Next Focus:**
Playtesting and polish — full 2-player game to surface edge cases. Victory screen layout with multiple players. Unit tests for multiplayer switching and setup rounds.

---

## 🌐 Network Multiplayer Roadmap (Future)

Hot-seat (Phase 1) is complete. Network play is not started — implement only after the game is polished and playtested.

### Phase 2 — LAN / VPN Testing
**Architecture:** Host is authoritative (runs full game logic). Clients send actions, receive state updates — display only.

**Quickest path to test with a friend:**
- Add a lobby scene with Host/Join buttons using `ENetMultiplayerPeer`
- For NAT traversal during testing: **Radmin VPN** (both install, no code changes) or **ngrok** (`ngrok tcp 7777`, share the URL)

**Key code changes needed:**
- `board_manager.gd`: `is_multiplayer`, `is_host`, `local_player_id` flags
- Tile/village placement: clients call `rpc_id(1, "_host_action", ...)` → host validates → broadcasts `_sync_game_state()`
- Player actions during opponent's turn must be blocked client-side

### Phase 3 — Production NAT
Pick one based on distribution target:
- **Steam** (`GodotSteam` plugin) — automatic NAT traversal, $100 fee, players need Steam
- **Relay server** (Python WebSockets on Railway/Render free tier) — simple 6-char game codes, works everywhere, ~$0–5/mo
- **WebRTC** — fully peer-to-peer, most complex
