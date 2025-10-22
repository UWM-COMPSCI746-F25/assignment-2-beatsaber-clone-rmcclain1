extends XROrigin3D
# XR bootstrap. I do four things here:
# 1) enable XR on the viewport and let the headset drive refresh,
# 2) pick a sane refresh rate from what the runtime offers,
# 3) pause/unpause on focus changes (nice for headset up/down),
# 4) when the runtime emits pose_recentered, I rotate + slide the origin so my camera
#    ends up facing the target cube at a comfortable distance.

@export var maximum_refresh_rate: int = 90
@export var target_path: NodePath                      # drag Main/CubeSpawner or the cube here
@export var recenter_distance: float = 2.0             # camera→cube distance after recenter

var xr: OpenXRInterface
var focused: bool = false

func _ready() -> void:
	xr = XRServer.find_interface("OpenXR") as OpenXRInterface
	if xr and xr.is_initialized():
		var vp: Viewport = get_viewport()
		vp.use_xr = true
		# Let OpenXR own the frame pacing. Vsync off here avoids double-vsync.
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		# If the device supports VRS (Quest), enable the XR mode.
		if RenderingServer.get_rendering_device():
			vp.vrs_mode = Viewport.VRS_XR

		# Signal hookups (covering older misspelling “focussed” just in case).
		if xr.has_signal("session_begun"):
			xr.session_begun.connect(_on_session_begun)
		if xr.has_signal("session_visible"):
			xr.session_visible.connect(_on_visible)
		if xr.has_signal("session_focused"):
			xr.session_focused.connect(_on_focused)
		elif xr.has_signal("session_focussed"):
			xr.connect("session_focussed", Callable(self, "_on_focused"))
		if xr.has_signal("pose_recentered"):
			xr.pose_recentered.connect(_on_pose_recentered)
	else:
		# If XR did not initialize, I bail early so I do not run a broken scene.
		push_error("OpenXR not initialized")
		get_tree().quit()

func _on_session_begun() -> void:
	# I try to match the headset’s best supported refresh rate up to my max.
	var rate: float = xr.get_display_refresh_rate()
	var best: float = rate
	var avail: Array = xr.get_available_display_refresh_rates()
	for i in avail:
		var r: float = float(i)
		if r > best and r <= float(maximum_refresh_rate):
			best = r
	if best > 0.0 and best != rate:
		xr.set_display_refresh_rate(best)
	# Physics tied to display rate keeps interactions feeling stable.
	if best > 0.0:
		Engine.physics_ticks_per_second = int(best)

func _on_visible() -> void:
	# When we lose focus after the first visible state, I pause the game.
	if focused:
		focused = false
		get_tree().paused = true

func _on_focused() -> void:
	focused = true
	get_tree().paused = false

func _on_pose_recentered() -> void:
	# Runtime recentered tracking. I align the origin so the camera faces the active cube
	# and ends at a predictable distance. This keeps flow consistent even if the user
	# physically drifted.
	_face_and_slide_to_cube()

# --- helpers ---------------------------------------------------------------

func _face_and_slide_to_cube() -> void:
	var cube: Node3D = _resolve_target_node()
	if cube == null:
		return

	var cam: XRCamera3D = _get_xr_camera()
	if cam == null:
		return

	# Direction from current camera to cube, flattened on XZ so I avoid tilting.
	var from: Vector3 = cam.global_transform.origin
	var to: Vector3 = cube.global_transform.origin
	var dir: Vector3 = to - from
	dir.y = 0.0
	if dir.length() < 0.001:
		return

	# Yaw the origin so forward points toward the cube.
	var yaw: float = atan2(dir.x, dir.z)
	var t: Transform3D = global_transform
	t.basis = Basis(Vector3.UP, yaw)
	global_transform = t

	# Slide the origin so the XR camera ends recenter_distance in front of the cube.
	var forward: Vector3 = -global_transform.basis.z.normalized()
	var desired_cam_pos: Vector3 = to - forward * max(recenter_distance, 0.1)
	var delta: Vector3 = desired_cam_pos - cam.global_transform.origin
	global_translate(delta)

func _resolve_target_node() -> Node3D:
	# Re-fetch every time; targets may have been freed between frames.
	if target_path.is_empty():
		return null

	var n: Node = get_node_or_null(target_path)
	if n == null or not is_instance_valid(n):
		return null

	# If target_path points at the spawner, ask it for the active/last cube.
	if n.has_method("get_focus_cube"):
		var res_focus: Variant = n.call("get_focus_cube")
		var node_focus: Node3D = _safe_node_variant(res_focus)
		if node_focus != null:
			return node_focus

	if n.has_method("get_last_cube"):
		var res_last: Variant = n.call("get_last_cube")
		var node_last: Node3D = _safe_node_variant(res_last)
		if node_last != null:
			return node_last

	# Otherwise, target_path may be a cube directly.
	return _safe_node_variant(n)

func _safe_node_variant(val: Variant) -> Node3D:
	# Strict-safe unwrap: only cast after confirming it's a live Object/Node.
	if val is Object and is_instance_valid(val):
		return val as Node3D
	return null

func _get_xr_camera() -> XRCamera3D:
	# Normal XR rig has the camera as a direct child of the XROrigin3D.
	for c in get_children():
		if c is XRCamera3D:
			return c
	# Fallback if someone grouped cameras.
	for n in get_tree().get_nodes_in_group("cameras"):
		if n is XRCamera3D:
			return n
	return null
