class_name God
extends Resource

## Data-driven god definition. Per rules.md every god has exactly three
## abilities — a passive, a minor power and a major power — so they are named
## slots rather than a list to be filtered at runtime.
##
## The passive is display text plus behaviour hooks overridden below: gods and
## passives are 1:1 forever, so a passive needs no type of its own.

enum PowerSlot { MINOR, MAJOR }

@export var god_name: String = ""
@export var image_path: String = ""

@export var passive_name: String = ""
@export var passive_description: String = ""

## Active powers. Null means "no power in this slot yet" — the UI renders an
## inert placeholder rather than a button.
@export var minor: GodPower = null
@export var major: GodPower = null

@export var hand_size: int = 3
@export var total_actions: int = 3


func _init(p_name: String = "", p_image_path: String = "",
		p_passive_name: String = "", p_passive_description: String = ""):
	god_name = p_name
	image_path = p_image_path
	passive_name = p_passive_name
	passive_description = p_passive_description


## Catalog of every god type, for the selection screen only. Rebuilt fresh
## each time it's needed (picker render, network index lookup) — the
## instance a player picks becomes their own, never shared with this catalog.
static func create_all() -> Array[God]:
	var all: Array[God] = [
		LeBatisseurGod.new(),
		BicephallesGod.new(),
		AugiaGod.new(),
		RakunGod.new(),
	]
	return all


## The power occupying `slot`, or null if this god has none there.
func get_power(slot: int) -> GodPower:
	match slot:
		PowerSlot.MINOR: return minor
		PowerSlot.MAJOR: return major
	return null


## Which slot `power` occupies, or -1 if it isn't one of this god's powers.
## Used to put a power on the wire in network mode — the slot is a stable
## identifier, unlike a position in a list.
func find_slot(power: GodPower) -> int:
	if power != null and power == minor:
		return PowerSlot.MINOR
	if power != null and power == major:
		return PowerSlot.MAJOR
	return -1


# --- Passive hooks. Defaults are no-ops; each god overrides what it needs. ---

## Materials cost for this god to build a village on `tile` — the placed board
## tile, so passives can key off its type (rules.md: Le Bâtisseur's discount
## applies to plains only).
func modify_village_cost(base_cost: int, _tile: HexTile) -> int:
	return base_cost


## Called after this god's owner demolishes an enemy village whose board tile
## was `tile` (still live, not yet mutated further). No-op by default; Rakun
## overrides it to steal the tile's yields (rules.md passive).
func on_village_demolished(_board_manager: Node3D, _tile: HexTile) -> void:
	pass
