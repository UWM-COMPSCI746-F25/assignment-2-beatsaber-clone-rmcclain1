extends Area3D
# This version makes the arrow actually matter. I rotate the whole cube
# to match the arrow rule, then check the sword swing in *cube local space*.

# Color rule (0 = left/red, 1 = right/blue)
@export var required_color: int = 0

# Arrow dir enum mapping: 0=UP,1=RIGHT,2=DOWN,3=LEFT
@export_enum("UP","RIGHT","DOWN","LEFT") var required_dir: int = 0

# Optional arrow texture
@export var arrow_texture: Texture2D

# Movement + cleanup
@export var speed_mps: float = 4.0
@export var destroy_if_z_greater_than: float = 0.5

# Debris settings
@export var debris_count: int = 6
@export var debris_life: float = 0.6
@export var debris_spread: float = 2.6

@onready var _mesh: MeshInstance3D = _find_cube_mesh()
@onready var _collider: CollisionShape3D = get_node_or_null("Collider") as CollisionShape3D
@onready var _arrow: MeshInstance3D = _find_arrow()
@onready var _sfx: AudioStreamPlayer3D = get_node_or_null("HitSfx") as AudioStreamPlayer3D

var _popped: bool = false

func _find_cube_mesh() -> MeshInstance3D:
	var m := get_node_or_null("Mesh") as MeshInstance3D
	if m: return m
	for c in get_children():
		if c is MeshInstance3D and c.name != "Arrow":
			return c
	return null

func _find_arrow() -> MeshInstance3D:
	var a := get_node_or_null("Arrow") as MeshInstance3D
	if a: return a
	for c in get_children():
		if c is MeshInstance3D and c.mesh is QuadMesh:
			return c
	return null

func _current_cube_edge() -> float:
	if _mesh and _mesh.mesh is BoxMesh:
		return float((_mesh.mesh as BoxMesh).size.x)
	return 0.35

func _ready() -> void:
	add_to_group("cubes")
	# layers/masks: cube on 2, sword on 1
	collision_layer = 2
	collision_mask = 1
	monitoring = true
	area_entered.connect(_on_area_entered)

	# make sure we always have visuals + collider
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		_mesh.name = "Mesh"
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE * 0.35
		_mesh.mesh = cube
		add_child(_mesh)

	if _collider == null:
		_collider = CollisionShape3D.new()
		_collider.name = "Collider"
		var bs := BoxShape3D.new()
		bs.size = Vector3.ONE * 0.35
		_collider.shape = bs
		add_child(_collider)

	_make_arrow_face()
	_apply_required_rotation()  # line up local axes with the visible arrow

func _physics_process(delta: float) -> void:
	# cubes march toward +Z (player is near z≈0)
	global_translate(Vector3(0, 0, speed_mps * delta))
	if global_transform.origin.z > destroy_if_z_greater_than:
		queue_free()

func set_required(rule_color: int, rule_dir: int) -> void:
	required_color = rule_color
	required_dir = rule_dir
	_colorize(rule_color)
	_apply_required_rotation()

func _colorize(rule_color: int) -> void:
	var col: Color = Color(1.0, 0.15, 0.15, 1.0) if rule_color == 0 else Color(0.15, 0.45, 1.0, 1.0)
	_apply_color_to_all_meshes(col)

func _play_hit_sfx_detached() -> void:
	# play SFX outside the cube so the sound isn’t killed by queue_free()
	if _sfx == null or _sfx.stream == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _sfx.stream
	p.global_transform = global_transform
	p.bus = _sfx.bus
	p.unit_size = _sfx.unit_size
	p.attenuation_filter_cutoff_hz = _sfx.attenuation_filter_cutoff_hz
	p.attenuation_model = _sfx.attenuation_model
	p.max_distance = _sfx.max_distance
	get_tree().current_scene.add_child(p)
	p.finished.connect(func(): p.queue_free())
	p.play()

func _apply_color_to_all_meshes(col: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col

	if _mesh:
		_mesh.material_override = mat
		if _mesh.mesh:
			var surf_count := _mesh.mesh.get_surface_count()
			for i in range(surf_count):
				_mesh.set_surface_override_material(i, mat)

	for child in get_children():
		if child is MeshInstance3D and child != _arrow:
			var mi := child as MeshInstance3D
			mi.material_override = mat
			if mi.mesh:
				var sc := mi.mesh.get_surface_count()
				for i in range(sc):
					mi.set_surface_override_material(i, mat)

func _on_area_entered(a: Area3D) -> void:
	if _popped:
		return
	# 1) must be a sword
	if not a.has_meta("sword_color_meta"):
		return
	# 2) color rule first (red cube needs red sword, etc.)
	var sword_color := int(a.get_meta("sword_color_meta"))
	if sword_color != required_color:
		return
	# 3) direction rule from arrow (uses sword tip velocity)
	var swing := Vector3.ZERO
	if a.has_method("get_swing_velocity"):
		swing = a.call("get_swing_velocity")
	if not _swing_matches(swing):
		return

	_popped = true
	_play_hit_sfx_detached()
	_spawn_debris()
	queue_free()

func _swing_matches(world_swing: Vector3) -> bool:
	# convert world vector into this cube’s local space (since I rotate cube to match arrow)
	var inv: Transform3D = global_transform.affine_inverse()
	var s: Vector3 = inv.basis * world_swing
	var t: float = 0.2  # quick-and-dirty threshold; smaller is stricter
	match int(required_dir):
		0: return s.y >  t   # UP
		2: return s.y < -t   # DOWN
		1: return s.x >  t   # RIGHT
		3: return s.x < -t   # LEFT
		_: return false

func _make_arrow_face() -> void:
	if _arrow == null:
		_arrow = MeshInstance3D.new()
		_arrow.name = "Arrow"
		_arrow.mesh = QuadMesh.new()
		add_child(_arrow)

	var edge := _current_cube_edge()
	var plane := _arrow.mesh as QuadMesh
	plane.size = Vector2(edge * 0.65, edge * 0.65)

	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if arrow_texture:
		m.albedo_texture = arrow_texture
	else:
		m.albedo_color = Color(1, 1, 1)
	_arrow.material_override = m

	# put the arrow slightly off the +Z face; avoids z-fighting and guarantees visibility
	_arrow.transform = Transform3D(Basis.IDENTITY, Vector3(0, 0, edge * 0.5 + 0.01))

func _apply_required_rotation() -> void:
	# rotate the whole cube around +Z to match the arrow enum
	var steps := [0.0, PI * 0.5, PI, PI * 1.5]
	var idx := posmod(int(required_dir), 4)
	var yaw := float(steps[idx])
	# keep position, reset basis, then apply yaw
	var t := global_transform
	t.basis = Basis.IDENTITY
	global_transform = t
	rotate_object_local(Vector3.UP, yaw)

func _spawn_debris() -> void:
	# tiny breakup effect so hits feel responsive
	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene

	var base_color := Color(1, 1, 1, 1)
	if _mesh and _mesh.material_override is StandardMaterial3D:
		base_color = (_mesh.material_override as StandardMaterial3D).albedo_color

	for i in range(max(5, debris_count)):
		var n := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * 0.08
		n.mesh = bm

		var m := StandardMaterial3D.new()
		m.albedo_color = base_color
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		n.material_override = m

		n.global_transform = global_transform
		parent.add_child(n)

		var dir := Vector3(
			randf_range(-1, 1),
			randf_range( 0, 1),
			randf_range(-1, 1)
		).normalized() * debris_spread

		var tw := create_tween()
		tw.tween_property(n, "global_position", n.global_position + dir, debris_life).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(n, "scale", Vector3(0.01, 0.01, 0.01), debris_life)
		tw.parallel().tween_method(Callable(self, "_set_material_alpha").bind(n), 1.0, 0.0, debris_life * 0.5)
		tw.tween_callback(Callable(n, "queue_free"))

func _set_material_alpha(n: MeshInstance3D, a: float) -> void:
	if n == null:
		return
	var sm := n.material_override as StandardMaterial3D
	if sm == null:
		return
	var c := sm.albedo_color
	c.a = a
	sm.albedo_color = c
