extends Node3D
# I moved the spawner to world space and spawn relative to the XR camera,
# so cubes show up at eye height instead of ankle height (lol).

@export var cube_scene: PackedScene
@export var origin_path: NodePath = ^"../XROrigin3D"

@export var min_interval: float = 0.5
@export var max_interval: float = 2.0

# spawn in front of the player by distance (recommended)
@export var spawn_use_camera_z: bool = true
@export var spawn_distance_m: float = 8.0
# fallback: fixed z plane if I want deterministic lane testing
@export var spawn_z: float = -12.0

@export var reach_x: float = 1.2
@export var reach_y: float = 1.2
@export var cube_size: float = 0.5
@export var cube_speed: float = 4.0
@export var center_dead_zone: float = 0.15

@export var arrow_texture: Texture2D

var _origin: XROrigin3D
var _timer: float = 0.0
var _next_spawn: float = 1.0
var _last_cube: Node3D = null

func _ready() -> void:
	randomize()
	_origin = get_node_or_null(origin_path) as XROrigin3D
	_schedule_next()

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= _next_spawn:
		_timer = 0.0
		_spawn_cube()
		_schedule_next()

func _schedule_next() -> void:
	_next_spawn = randf_range(min_interval, max_interval)

func _spawn_cube() -> void:
	if cube_scene == null:
		push_error("CubeSpawner: cube_scene not assigned.")
		return

	var cube := cube_scene.instantiate() as Area3D
	if cube == null:
		return

	# -- spawn at eye height in front of the player --
	var cam := _get_xr_camera()
	var eye_y: float = (cam.global_transform.origin.y if cam != null else 1.6)

	var center_xz := Vector3.ZERO
	if cam != null:
		center_xz.x = cam.global_transform.origin.x
		center_xz.z = (cam.global_transform.origin.z + spawn_distance_m) if spawn_use_camera_z else spawn_z
	else:
		center_xz.z = spawn_z

	# keep spawns away from the exact center so it’s not trivial
	var min_x: float = max(center_dead_zone, 0.05)
	var x: float = randf_range(-reach_x, reach_x)
	if absf(x) < min_x:
		x = sign(x if x != 0.0 else 1.0) * min_x
	var y_off: float = randf_range(-reach_y, reach_y)
	var pos := Vector3(center_xz.x + x, eye_y + y_off, center_xz.z)

	# add to the root scene so cubes don’t inherit XROrigin transforms
	get_tree().current_scene.add_child(cube)
	cube.global_transform = Transform3D(Basis.IDENTITY, pos)

	# rule assignment + speed + cleanup
	if cube.has_method("set_required"):
		var req_color: int = randi() % 2       # 0 red (left), 1 blue (right)
		var req_dir: int = randi() % 4         # 0 up, 1 right, 2 down, 3 left
		cube.call("set_required", req_color, req_dir)

	cube.set("speed_mps", cube_speed)
	cube.set("destroy_if_z_greater_than", 0.5)
	if arrow_texture:
		cube.set("arrow_texture", arrow_texture)

	# size the cube + collider
	var mesh := cube.get_node_or_null("Mesh") as MeshInstance3D
	if mesh and mesh.mesh is BoxMesh:
		(mesh.mesh as BoxMesh).size = Vector3.ONE * cube_size
	var col := cube.get_node_or_null("Collider") as CollisionShape3D
	if col and col.shape is BoxShape3D:
		(col.shape as BoxShape3D).size = Vector3.ONE * cube_size

	# arrow will be sized/placed by cube.gd; just make sure size looks right
	var arrow := cube.get_node_or_null("Arrow") as MeshInstance3D
	if arrow and arrow.mesh is QuadMesh:
		(arrow.mesh as QuadMesh).size = Vector2(cube_size * 0.65, cube_size * 0.65)

	
	_last_cube = cube
	cube.tree_exited.connect(func() -> void:
		if _last_cube == cube:
			_last_cube = null)


func _get_xr_camera() -> XRCamera3D:
	if _origin == null:
		return null
	for c in _origin.get_children():
		if c is XRCamera3D:
			return c
	return null

func get_last_cube() -> Node3D:
	return _last_cube
