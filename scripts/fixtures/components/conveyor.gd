class_name Conveyor
extends FixtureComponent
## Moves whatever sits on it toward the fixture in front, which receives it
## using the normal interaction rules. Chain them into lines.

@export var travel_time := 1.1
@export var cleats_path: NodePath

var t := 0.0
var _jammed := false
var _vis_t := 0.0
var _cleats: Node3D


func _ready() -> void:
	if not cleats_path.is_empty():
		_cleats = get_node_or_null(cleats_path)


func ready_to_pass() -> bool:
	return t >= travel_time


func server_tick(delta: float) -> void:
	var s := fixture.primary_slot()
	if s.item == null or not fixture.is_working():
		t = 0.0
		return
	t = minf(t + delta, travel_time)
	if t >= travel_time:
		var front := world().grid.fixture_at(fixture.front_cell())
		if front and front != fixture:
			var it := s.item
			it.detach()
			if Automation.try_insert(front, it):
				t = 0.0
				Audio.play_at(&"putdown", front.global_position, -10.0)
				fixture.mark_dirty()
			else:
				s.put(it)


func _process(delta: float) -> void:
	if fixture == null:
		return
	var s := fixture.primary_slot()
	var moving := s.item != null and fixture.is_working()
	if moving:
		_vis_t = minf(_vis_t + delta, travel_time)
	else:
		_vis_t = 0.0
	s.position.z = lerpf(-0.38, 0.38, _vis_t / travel_time) if moving else 0.0
	if _cleats and moving:
		for c in _cleats.get_children():
			var n := c as Node3D
			n.position.z = fposmod(n.position.z + delta * 0.7 + 0.5, 1.0) - 0.5
	Audio.loop(fixture, &"conveyor_loop", moving, -12.0)


func blocks_function() -> bool:
	return _jammed


func query(_actor: Node, verb: int) -> Dictionary:
	if _jammed and verb == GameConst.Verb.USE:
		return {"label": "Clear jam", "hold": true, "anim": CharacterRig.Anim.REPAIR}
	return {}


func perform(_actor: Node, verb: int, _delta: float) -> bool:
	if _jammed and verb == GameConst.Verb.USE:
		_jammed = false
		Audio.play_at(&"repair_done", fixture.global_position)
		fixture.mark_dirty()
		return true
	return false


func jam() -> void:
	_jammed = true
	Audio.play_at(&"breakdown", fixture.global_position, -4.0)
	fixture.mark_dirty()


func status_text() -> String:
	return "JAMMED — hold USE" if _jammed else ""


func get_state() -> Dictionary:
	return {"j": true} if _jammed else {}


func set_state(d: Dictionary) -> void:
	_jammed = d.get("j", false)
