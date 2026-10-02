class_name FridgeDoor
extends FixtureComponent
## Visual: the glass door swings open when someone stands in front of it.

@export var door_path: NodePath

var _door: Node3D
var _open := 0.0
var _was_open := false


func _ready() -> void:
	if not door_path.is_empty():
		_door = get_node_or_null(door_path)
	if _door:
		var glass := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.78, 1.36, 0.02)
		glass.mesh = bm
		glass.material_override = Models.mat_glass()
		glass.position = Vector3(0.46, 0.16 + 0.75, 0.0)
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_door.add_child(glass)


func _process(delta: float) -> void:
	if _door == null or fixture == null:
		return
	var want := false
	var front := fixture.global_position + fixture.front_vec() * 0.8
	for a in get_tree().get_nodes_in_group(&"players"):
		if (a as Node3D).global_position.distance_to(front) < 0.75:
			want = true
			break
	for a in get_tree().get_nodes_in_group(&"staff"):
		if (a as Node3D).global_position.distance_to(front) < 0.75:
			want = true
			break
	if want != _was_open:
		_was_open = want
		Audio.play_at(&"fridge_open" if want else &"fridge_close", fixture.global_position, -6.0)
	_open = lerpf(_open, 1.0 if want else 0.0, clampf(delta * 9.0, 0, 1))
	_door.rotation.y = -_open * deg_to_rad(105.0)


func status_text() -> String:
	if not fixture.is_cooling():
		return "NOT COOLING!"
	return "Keeps stock fresh"
