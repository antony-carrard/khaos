extends PanelContainer
class_name ResourcePanel

## Resource panel component - displays resources, fervor, and glory
## Extracted from tile_selector_ui.gd for better code organization

# Layout constants
const PANEL_SIZE: Vector2 = Vector2(120, 100)
const PANEL_MARGIN: int = 10
const ICON_SIZE: Vector2 = Vector2(20, 20)
const FONT_SIZE: int = 16

# "+N" flash timing beside a value label when it increases — rise a few
# pixels while held fully visible, then fade. Mirrors the on-board
# ResourcePopup3D's rise+fade shape (effects/resource_popup_3d.gd) so both
# gain indicators read as the same visual language.
const GAIN_RISE_PX: float = -10.0
const GAIN_HOLD_TIME: float = 0.5
const GAIN_FADE_TIME: float = 0.5

var resource_label: Label = null
var fervor_label: Label = null
var glory_label: Label = null

var _materials_gain_label: Label = null
var _fervor_gain_label: Label = null
var _glory_gain_label: Label = null

# Last value seen per stat, so update_*() can compute a delta. -1 means "not
# yet seen" (either the panel just spawned, or reset_gain_tracking() just ran
# because the displayed player changed) — never a real value, since materials/
# fervor/glory are always >= 0, and it suppresses the animation until the next
# real update so a player switch never flashes the new player's stats as a gain.
var _last_materials: int = -1
var _last_fervor: int = -1
var _last_glory: int = -1

# Tweens currently animating a gain label's rise/fade, keyed by that label —
# killed and replaced if another gain lands before the previous one finishes.
var _gain_tweens: Dictionary[Label, Array] = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS  # Allow camera input to pass through
	_create_panel()


## Creates the resource panel UI
func _create_panel() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = PANEL_SIZE

	# Inner margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", PANEL_MARGIN)
	margin.add_theme_constant_override("margin_right", PANEL_MARGIN)
	margin.add_theme_constant_override("margin_top", PANEL_MARGIN)
	margin.add_theme_constant_override("margin_bottom", PANEL_MARGIN)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Resources row
	var materials_row := _create_resource_row(vbox, TileManager.RESOURCE_TYPE_ICONS[TileDefinition.ResourceType.MATERIALS], "0")
	resource_label = materials_row[0]
	_materials_gain_label = materials_row[1]

	# Fervor row
	var fervor_row := _create_resource_row(vbox, TileManager.RESOURCE_TYPE_ICONS[TileDefinition.ResourceType.FERVOR], "0")
	fervor_label = fervor_row[0]
	_fervor_gain_label = fervor_row[1]

	# Glory row
	var glory_row := _create_resource_row(vbox, TileManager.RESOURCE_TYPE_ICONS[TileDefinition.ResourceType.GLORY], "0")
	glory_label = glory_row[0]
	_glory_gain_label = glory_row[1]


## Create a row with icon + value label + a hidden "+N" gain label right after
## it. Returns [value_label, gain_label].
func _create_resource_row(parent: VBoxContainer, icon_path: String, initial_value: String) -> Array:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	# Icon
	var icon = TextureRect.new()
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var texture = load(icon_path) as Texture2D
	if texture:
		icon.texture = texture
	hbox.add_child(icon)

	# Label
	var label = Label.new()
	label.text = initial_value
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	hbox.add_child(label)

	# Gain flash — sits right after the value label, invisible until a gain lands.
	var gain_label = Label.new()
	gain_label.text = ""
	gain_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	gain_label.add_theme_color_override("font_outline_color", Color.BLACK)
	gain_label.add_theme_constant_override("outline_size", 3)
	gain_label.add_theme_font_size_override("font_size", FONT_SIZE)
	gain_label.modulate.a = 0.0
	hbox.add_child(gain_label)

	return [label, gain_label]


## Update resource display
func update_resources(amount: int) -> void:
	if resource_label:
		resource_label.text = str(amount)
	_show_gain(_materials_gain_label, amount, _last_materials)
	_last_materials = amount


## Update fervor display
func update_fervor(amount: int) -> void:
	if fervor_label:
		fervor_label.text = str(amount)
	_show_gain(_fervor_gain_label, amount, _last_fervor)
	_last_fervor = amount


## Update glory display
func update_glory(amount: int) -> void:
	if glory_label:
		glory_label.text = str(amount)
	_show_gain(_glory_gain_label, amount, _last_glory)
	_last_glory = amount


## Forgets last-seen values so the next update_*() call is treated as a fresh
## baseline instead of a gain. Call this whenever the player whose stats this
## panel displays changes (e.g. a hot-seat turn switch) — otherwise the first
## update after the switch would diff the new player's value against the
## previous player's and flash a bogus "+N".
func reset_gain_tracking() -> void:
	_last_materials = -1
	_last_fervor = -1
	_last_glory = -1
	for gain_label in [_materials_gain_label, _fervor_gain_label, _glory_gain_label]:
		_kill_gain_tween(gain_label)
		if gain_label:
			gain_label.modulate.a = 0.0


## Shows a brief "+N" beside `gain_label` when `new_value` is higher than
## `last_value`, then fades it. No-ops on the first observation of a stat
## (last_value == -1) and on decreases (cost payments).
func _show_gain(gain_label: Label, new_value: int, last_value: int) -> void:
	if not gain_label or last_value < 0:
		return
	var delta := new_value - last_value
	if delta <= 0:
		return

	_kill_gain_tween(gain_label)

	gain_label.text = "+%d" % delta
	gain_label.modulate.a = 1.0
	gain_label.position.y = 0.0

	var rise_tween := create_tween()
	rise_tween.tween_property(gain_label, "position:y", GAIN_RISE_PX, GAIN_HOLD_TIME + GAIN_FADE_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var fade_tween := create_tween()
	fade_tween.tween_interval(GAIN_HOLD_TIME)
	fade_tween.tween_property(gain_label, "modulate:a", 0.0, GAIN_FADE_TIME)

	_gain_tweens[gain_label] = [rise_tween, fade_tween]


func _kill_gain_tween(gain_label: Label) -> void:
	if not _gain_tweens.has(gain_label):
		return
	for tween in _gain_tweens[gain_label]:
		if tween and tween.is_valid():
			tween.kill()
	_gain_tweens.erase(gain_label)
