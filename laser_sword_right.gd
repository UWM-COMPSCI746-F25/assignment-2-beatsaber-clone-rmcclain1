extends Area3D
# right hand. mirrored from left; typed locals to satisfy strict mode.

const INPUT_ACTION: StringName = &"xr_right_primary"
const SWORD_COLOR: int = 1  # blue

@export var beam_length: float = 1.0
@export var beam_thickness: float = 0.03
@export var emissive_color: Color = Color(0.15, 0.45, 1.0, 1.0)
@export var smoothing_alpha: float = 0.35

@onready var _mesh: MeshInstance3D = get_node_or_null("Beam") as MeshInstance3D
@onready var _collider: CollisionShape3D = get_node_or_null("Collider") as CollisionShape3D

var _on: bool = true
var _last_tip: Vector3 = Vector3.ZERO
var _swing_v: Vector3 = Vector3.ZERO

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	monitorable = true
	monitoring = true
	set_meta("sword_color_meta", SWORD_COLOR)

	_setup_beam()
	_setup_collider()
	_update_enabled(true)

	_last_tip = _tip_world()

func _physics_process(delta: float) -> void:
	var tip: Vector3 = _tip_world()
	var raw_v: Vector3 = (tip - _last_tip) / max(delta, 0.0001)
	_swing_v = _swing_v * (1.0 - smoothing_alpha) + raw_v * smoothing_alpha
	_last_tip = tip

	if Input.is_action_just_pressed(INPUT_ACTION):
		_on = not _on
		_update_enabled(_on)

func _tip_world() -> Vector3:
	var forward_neg_z: Vector3 = -global_transform.basis.z.normalized()
	return global_transform.origin + forward_neg_z * beam_length

func _setup_beam() -> void:
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		_mesh.name = "Beam"
		add_child(_mesh)

	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.height = beam_length
	cyl.top_radius = beam_thickness
	cyl.bottom_radius = beam_thickness
	_mesh.mesh = cyl

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = emissive_color
	mat.albedo_color = emissive_color
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	_mesh.material_override = mat

	_mesh.transform = Transform3D(Basis().rotated(Vector3.RIGHT, PI / 2.0), Vector3(0, 0, -beam_length * 0.5))

func _setup_collider() -> void:
	if _collider == null:
		_collider = CollisionShape3D.new()
		_collider.name = "Collider"
		add_child(_collider)

	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(beam_thickness * 2.0, beam_thickness * 2.0, beam_length)
	_collider.shape = box
	_collider.transform = Transform3D(Basis.IDENTITY, Vector3(0, 0, -beam_length * 0.5))

func _update_enabled(enabled: bool) -> void:
	visible = enabled
	monitoring = enabled
	if _collider:
		_collider.disabled = not enabled

func get_swing_velocity() -> Vector3:
	return _swing_v
