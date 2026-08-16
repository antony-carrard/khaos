extends Node3D

class_name ResourcePopup3D

## Ephemeral floating "+N <icon>" effect shown wherever a player gains resources
## on the board — tile placement bounty, village construction/demolition glory,
## turn-start harvest, and power effects. One instance can show several resource
## types at once, stacked in a vertical column (one row per type) rather than
## side by side — a row's width only has to fit one icon+number pair, so rows
## never collide with each other the way side-by-side badges did.
## Built procedurally (no accompanying .tscn), like the project's other runtime-
## constructed nodes (managers, ActivePlayerView). Spawned and owned by
## ResourcePopupManager; frees itself once its animation finishes.

## Emitted right before this node frees itself, so the spawner can release any
## per-hex stacking slot it reserved for this popup.
signal finished

const ICON_SIZE: Vector2 = Vector2(0.5, 0.5)
const FONT_SIZE: int = 72
const ROW_WIDTH: float = 1.0      # Backdrop width — fixed, since every row is one icon+number pair
const ROW_HEIGHT: float = 0.58    # Vertical distance between stacked resource-type rows
const ICON_X: float = 0.16        # Icon offset right of row-center; the number extends left from it
const LABEL_GAP: float = 0.14     # Gap between the number's right edge and the icon's left edge
const BACKDROP_PADDING: Vector2 = Vector2(0.3, 0.24)
const BACKDROP_ALPHA: float = 0.62

const POP_TIME: float = 0.27     # Scale/fade in (TRANS_BACK overshoots and settles within this)
const HOLD_TIME: float = 0.55    # Fully visible, still rising
const FADE_TIME: float = 0.55    # Fade out, still rising
const RISE_DISTANCE: float = 1.15
const START_SCALE: float = 0.4

var _backdrop_material: StandardMaterial3D = null
var _icon_materials: Array[StandardMaterial3D] = []
var _labels: Array[Label3D] = []
# Every node that bounces in on spawn (icons + labels, not the backdrop). Scaled
# individually around each node's own origin — see _animate()'s docstring for why.
var _bounce_nodes: Array[Node3D] = []


## Builds the badge row for `yields` (TileDefinition.ResourceType -> amount,
## already filtered to positive entries by the spawner) and starts the
## rise/fade animation. Call once, right after adding this node to the tree.
func setup(yields: Dictionary) -> void:
	var res_types := yields.keys()
	res_types.sort()

	var total_height := (res_types.size() - 1) * ROW_HEIGHT
	var start_y := total_height / 2.0

	_create_backdrop(res_types.size())
	for i in res_types.size():
		var res_type = res_types[i]
		var y := start_y - i * ROW_HEIGHT
		_create_icon(res_type, y)
		_create_label(yields[res_type], y)

	_animate()


func _create_backdrop(item_count: int) -> void:
	var width := ROW_WIDTH
	var height: float = maxi(item_count - 1, 0) * ROW_HEIGHT + ICON_SIZE.y + BACKDROP_PADDING.y * 2

	var quad := MeshInstance3D.new()
	add_child(quad)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(width, height)
	quad.mesh = mesh

	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# White tint over a pre-baked radial gradient texture: the texture supplies a
	# soft elliptical falloff (opaque center -> transparent edge) stretched to the
	# quad's aspect ratio, so it reads as a blurred ellipse instead of a hard-edged
	# rectangle. albedo_color.a still drives the overall fade in/out.
	material.albedo_texture = _radial_glow_texture()
	material.albedo_color = Color(1, 1, 1, 0.0)
	material.render_priority = -1
	quad.material_override = material
	_backdrop_material = material


## Procedural soft-edged circle (opaque center fading to fully transparent at
## the radius), stretched onto the backdrop quad. No external asset or shader
## needed — Godot bakes the radial gradient into a texture once at spawn time.
func _radial_glow_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.05, 0.05, 0.08, 1.0), Color(0.05, 0.05, 0.08, 0.0)])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


func _create_icon(res_type: int, y: float) -> void:
	var icon := MeshInstance3D.new()
	add_child(icon)
	var quad := QuadMesh.new()
	quad.size = ICON_SIZE
	icon.mesh = quad
	icon.position = Vector3(ICON_X, y, 0)

	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var icon_path = TileManager.RESOURCE_TYPE_ICONS[res_type]
	var texture = load(icon_path) as Texture2D
	if not texture:
		Log.error("ResourcePopup3D: Failed to load icon texture: %s" % icon_path)
	else:
		material.albedo_texture = texture
	material.albedo_color = Color(1, 1, 1, 0.0)
	material.render_priority = 0
	icon.material_override = material
	_icon_materials.append(material)
	_bounce_nodes.append(icon)


func _create_label(amount: int, y: float) -> void:
	var label := Label3D.new()
	add_child(label)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = FONT_SIZE
	label.outline_size = int(FONT_SIZE * 0.2)
	label.outline_modulate = Color.BLACK  # Multiplied by modulate below, so the fade covers both fill and outline
	label.modulate = Color(0.6, 1.0, 0.6, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.position = Vector3(ICON_X - ICON_SIZE.x * 0.5 - LABEL_GAP, y, 0)
	label.text = "+%d" % amount
	label.render_priority = 1
	_labels.append(label)
	_bounce_nodes.append(label)


## Two tweens, each with one job: `rise` is a single continuous motion for the
## whole lifetime; `visibility` drives scale + every material/label's alpha
## together so the backdrop, icons and labels always move, pop in, and fade
## out as one unit rather than as separately-timed pieces.
##
## The pop-in bounce scales each icon/label individually around its OWN origin
## rather than scaling `self` (the shared parent): icon and label sit at
## different local x-offsets, so scaling the whole group around one shared
## pivot swings the off-center element through a wider arc than the centered
## one — same timing, but visibly different motion. Per-node scaling avoids that.
func _animate() -> void:
	for node in _bounce_nodes:
		node.scale = Vector3.ONE * START_SCALE

	var rise_tween := create_tween()
	rise_tween.tween_property(self, "position:y", position.y + RISE_DISTANCE, POP_TIME + HOLD_TIME + FADE_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var visibility_tween := create_tween()
	visibility_tween.set_parallel(true)
	for node in _bounce_nodes:
		visibility_tween.tween_property(node, "scale", Vector3.ONE, POP_TIME)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	visibility_tween.tween_property(_backdrop_material, "albedo_color:a", BACKDROP_ALPHA, POP_TIME)
	for material in _icon_materials:
		visibility_tween.tween_property(material, "albedo_color:a", 1.0, POP_TIME)
	for label in _labels:
		visibility_tween.tween_property(label, "modulate:a", 1.0, POP_TIME)

	visibility_tween.set_parallel(false)
	visibility_tween.tween_interval(HOLD_TIME)

	visibility_tween.set_parallel(true)
	visibility_tween.tween_property(_backdrop_material, "albedo_color:a", 0.0, FADE_TIME)
	for material in _icon_materials:
		visibility_tween.tween_property(material, "albedo_color:a", 0.0, FADE_TIME)
	for label in _labels:
		visibility_tween.tween_property(label, "modulate:a", 0.0, FADE_TIME)

	visibility_tween.finished.connect(_on_animation_finished)


func _on_animation_finished() -> void:
	finished.emit()
	queue_free()
