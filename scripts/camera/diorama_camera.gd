class_name DioramaCamera
extends Camera3D
## Semi-fixed overhead camera that looks down on the restaurant like a
## miniature model. It frames the whole building, eases in slightly when the
## players are clustered, and never rotates during play, so players never have
## to fight it. A gentle tilt-shift blur sells the miniature look.

@export var pitch_deg := 54.0
@export var min_distance := 16.0
@export var margin := 1.6

var building_rect := Rect2(0, 0, 20, 10)
var targets: Array[Node3D] = []
var zoom_bias := 0.0           ## Player controlled (-0.35 .. 0.35)
var overview := false          ## Force the full-building framing.
var tilt_shift := true

var _focus := Vector3.ZERO
var _dist := 20.0
var _shake := 0.0
var _attrs: CameraAttributesPractical
var _initialized := false


func _ready() -> void:
	fov = 34.0
	near = 0.5
	far = 200.0
	_attrs = CameraAttributesPractical.new()
	attributes = _attrs
	current = true


func set_building_rect(r: Rect2) -> void:
	building_rect = r


func snap() -> void:
	_initialized = false


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _required_distance(r: Rect2) -> float:
	var vfov := deg_to_rad(fov)
	var aspect := 16.0 / 9.0
	var vp := get_viewport()
	if vp:
		var sz := vp.get_visible_rect().size
		if sz.y > 0:
			aspect = sz.x / sz.y
	var pitch := deg_to_rad(pitch_deg)
	var half_v := tan(vfov * 0.5)
	var d_depth := (r.size.y * sin(pitch) * 0.5) / half_v + r.size.y * cos(pitch) * 0.25
	var d_width := (r.size.x * 0.5) / (half_v * aspect)
	return maxf(d_depth, d_width)


func _process(delta: float) -> void:
	var full := building_rect.grow(margin)
	var d_full := _required_distance(full)
	var target_focus := Vector3(full.get_center().x, 0, full.get_center().y)
	var target_dist := d_full
	var live: Array[Node3D] = []
	for t in targets:
		if is_instance_valid(t):
			live.push_back(t)
	if not live.is_empty() and not overview:
		var pr := Rect2(Vector2(live[0].global_position.x, live[0].global_position.z), Vector2.ZERO)
		for t in live:
			pr = pr.expand(Vector2(t.global_position.x, t.global_position.z))
		pr = pr.grow(4.2)
		var d_players := maxf(_required_distance(pr), min_distance)
		# Stay mostly zoomed out: ease only partway toward the players.
		target_dist = clampf(lerpf(d_full, d_players, 0.12), min_distance, d_full)
		var t_amt := 1.0 - (target_dist - min_distance) / maxf(d_full - min_distance, 0.001)
		var pc := Vector3(pr.get_center().x, 0, pr.get_center().y)
		target_focus = target_focus.lerp(pc, clampf(t_amt * 1.6, 0.0, 0.35))
	target_dist *= 1.0 + zoom_bias
	target_dist = maxf(target_dist, min_distance * 0.8)
	# Keep the focus inside the building framing.
	target_focus.x = clampf(target_focus.x, full.position.x + 3.0, full.end.x - 3.0) if full.size.x > 6.0 else full.get_center().x
	target_focus.z = clampf(target_focus.z, full.position.y + 2.0, full.end.y - 2.0) if full.size.y > 4.0 else full.get_center().y
	if not _initialized:
		_focus = target_focus
		_dist = target_dist
		_initialized = true
	else:
		_focus = _focus.lerp(target_focus, clampf(delta * 2.2, 0, 1))
		_dist = lerpf(_dist, target_dist, clampf(delta * 1.8, 0, 1))
	var pitch := deg_to_rad(pitch_deg)
	var offset := Vector3(0, sin(pitch), cos(pitch)) * _dist
	var shake_off := Vector3.ZERO
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 2.5, 0.0)
		shake_off = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.12
	global_position = _focus + offset + shake_off
	look_at(_focus + shake_off, Vector3.UP)
	_update_dof()


func _update_dof() -> void:
	if _attrs == null:
		return
	_attrs.dof_blur_far_enabled = tilt_shift
	_attrs.dof_blur_near_enabled = tilt_shift
	_attrs.dof_blur_far_distance = _dist + 9.0
	_attrs.dof_blur_far_transition = 10.0
	_attrs.dof_blur_near_distance = maxf(_dist - 9.0, 1.0)
	_attrs.dof_blur_near_transition = 4.0
	_attrs.dof_blur_amount = 0.05


func focus_point() -> Vector3:
	return _focus


## Projects a world position to screen (for UI anchoring).
func screen_pos(p: Vector3) -> Vector2:
	return unproject_position(p)
