class_name Grabber
extends FixtureComponent
## A robotic arm: takes one item from the fixture behind it and places it on
## the fixture in front. Pulls single units out of crates, so a grabber in
## front of a shelf becomes an ingredient dispenser.

@export var interval := 1.4
@export var arm_path: NodePath

var t := 0.0
var _arm: Node3D
var _swing := 0.0


func _ready() -> void:
	if not arm_path.is_empty():
		_arm = get_node_or_null(arm_path)


func server_tick(delta: float) -> void:
	if not fixture.is_working():
		return
	var s := fixture.primary_slot()
	t += delta
	if t < interval:
		return
	var w := world()
	var front := w.grid.fixture_at(fixture.front_cell())
	if s.item:
		if front:
			var it := s.item
			it.detach()
			if Automation.try_insert(front, it):
				t = 0.0
				_swing = 1.0
				Audio.play_at(&"grabber", fixture.global_position, -6.0)
				fixture.mark_dirty()
				return
			s.put(it)
		return
	var back := w.grid.fixture_at(fixture.back_cell())
	if back == null or front == null:
		return
	# Only pull if the front can plausibly accept something.
	var got := Automation.try_extract(back)
	if got:
		s.put(got)
		got.mark_dirty()
		t = interval * 0.5
		_swing = -1.0
		Audio.play_at(&"grabber", fixture.global_position, -8.0, 1.2)
		fixture.mark_dirty()


func _process(delta: float) -> void:
	if _arm == null or fixture == null:
		return
	var s := fixture.primary_slot()
	# The arm reaches toward -Z (the back) at yaw 0 and swings to the front
	# (yaw PI) while carrying something.
	var target := PI if s.item else 0.0
	_arm.rotation.y = lerp_angle(_arm.rotation.y, target, clampf(delta * 7.0, 0, 1))
	s.position = Vector3(0, 0.5, 0) + Vector3(0, 0, -0.6).rotated(Vector3.UP, _arm.rotation.y)


func status_text() -> String:
	return "Moves items front ←→ back"
