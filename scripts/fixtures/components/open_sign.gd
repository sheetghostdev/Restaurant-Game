class_name OpenSign
extends FixtureComponent
## The big OPEN/CLOSED sign. Flipping it starts service (during morning prep)
## or ends the day (after closing, once the dining room is empty).

@export var board_path: NodePath

var _board: Node3D
var _hold := 0.0
const HOLD_TIME := 0.7


func _ready() -> void:
	if not board_path.is_empty():
		_board = get_node_or_null(board_path)


func query(_actor: Node, verb: int) -> Dictionary:
	if verb != GameConst.Verb.USE:
		return {}
	var w := world()
	if w == null:
		return {}
	match w.day.phase:
		GameConst.Phase.MORNING:
			return {"label": "OPEN THE RESTAURANT", "hold": true, "progress": _hold / HOLD_TIME, "anim": CharacterRig.Anim.WAVE}
		GameConst.Phase.CLOSING:
			if w.day.can_finish_day():
				return {"label": "End the day", "hold": true, "progress": _hold / HOLD_TIME}
			return {"label": "Wait for guests to leave", "blocked": true}
		GameConst.Phase.EVENING:
			return {"label": "Lights out → next day", "hold": true, "progress": _hold / HOLD_TIME}
	return {}


func perform(_actor: Node, verb: int, delta: float) -> bool:
	if verb != GameConst.Verb.USE:
		return false
	var w := world()
	_hold += delta
	if _hold < HOLD_TIME:
		return true
	_hold = 0.0
	match w.day.phase:
		GameConst.Phase.MORNING:
			w.day.open_restaurant()
		GameConst.Phase.CLOSING:
			if w.day.can_finish_day():
				w.day.finish_day()
		GameConst.Phase.EVENING:
			w.day.start_next_day()
	return true


func server_tick(delta: float) -> void:
	# Decay partial holds when nobody is holding.
	_hold = maxf(_hold - delta * 0.5, 0.0)


func _process(delta: float) -> void:
	if _board == null or fixture == null or fixture.world == null:
		return
	var open := fixture.world.day.phase == GameConst.Phase.SERVICE
	var target := 0.0 if open else PI
	_board.rotation.y = lerp_angle(_board.rotation.y, target, clampf(delta * 6.0, 0, 1))
	_board.rotation.z = sin(Time.get_ticks_msec() * 0.002) * 0.03


func status_text() -> String:
	var w := world()
	if w == null:
		return ""
	return "OPEN" if w.day.phase == GameConst.Phase.SERVICE else "CLOSED"
