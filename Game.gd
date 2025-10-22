extends Node3D
# Project note: I keep "game glue" super small. This script just:
# 1) tags the swords with color so cubes can validate hits,
# 2) listens for OpenXR's pose_recentered and nudges the player to face the active cube,
# 3) provides a tiny helper to pick the target cube (last spawned or nearest to player).

# Scene expectations (names matter for onready paths):
# - XROrigin3D
#     - LeftController/LaserSwordLeft (Area3D)
#     - RightController/LaserSwordRight (Area3D)
# - CubeSpawner (Node3D with cube_spawner.gd)

@onready var origin: XROrigin3D = $XROrigin3D
@onready var left_sword: Area3D = $XROrigin3D/LeftController/LaserSwordLeft
@onready var right_sword: Area3D = $XROrigin3D/RightController/LaserSwordRight
@onready var spawner: Node3D = $CubeSpawner

var _openxr: OpenXRInterface

func _ready() -> void:
	# I tag swords here so cube.gd does not need to hard-code scene paths.
	# 0 = left/red, 1 = right/blue (matches the color rule in cube.gd).
	left_sword.set_meta("sword_color_meta", 0)
	right_sword.set_meta("sword_color_meta", 1)

	# Lightweight OpenXR hook. When the user recenters via the Oculus button,
	# I rotate and slide the origin to face the active cube so the flow stays comfy.
	_openxr = XRServer.find_interface("OpenXR") as OpenXRInterface
	if _openxr and _openxr.has_signal("pose_recentered"):
		_openxr.pose_recentered.connect(_on_pose_recentered)

func _on_pose_recentered() -> void:
	# Align the player toward the current cube. I only yaw on the horizontal plane
	# so I do not mess with the user’s height.
	var target: Node3D = _get_target_cube()
	if target == null:
		return

	var user_xform: Transform3D = origin.global_transform
	var user_pos: Vector3 = user_xform.origin
	var cube_pos: Vector3 = target.global_transform.origin

	# Center X on the cube but keep user Y/Z. This makes it feel like recenter “snaps”
	# you nicely into a lane in front of the action.
	var desired_pos: Vector3 = Vector3(cube_pos.x, user_pos.y, user_pos.z)
	var new_xform: Transform3D = Transform3D(user_xform.basis, desired_pos)

	# Face the cube with a pure yaw so the player ends up looking right at it.
	var flat: Vector3 = cube_pos - desired_pos
	flat.y = 0.0
	if flat.length() > 0.0001:
		var yaw: float = atan2(flat.x, flat.z)
		new_xform.basis = Basis(Vector3.UP, yaw)

	origin.global_transform = new_xform

func _get_target_cube() -> Node3D:
	# Priority: use the spawner’s “last cube” if it exposes it (cheap and good enough).
	# Fallback: scan the cubes group and pick the one with the largest Z (closest to user).
	if spawner and spawner.has_method("get_last_cube"):
		var c: Node3D = spawner.call("get_last_cube")
		if is_instance_valid(c):
			return c

	var best: Node3D = null
	var best_z: float = -INF
	for n in get_tree().get_nodes_in_group("cubes"):
		if n is Node3D:
			var nn: Node3D = n
			var z: float = nn.global_transform.origin.z
			if z > best_z:
				best_z = z
				best = nn
	return best
