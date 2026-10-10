class_name OpenSign
extends FixtureComponent
## The big OPEN/CLOSED sign. The doors open by themselves when prep time runs
## out, but holding USE here during prep opens them right away. Closing
## happens by itself; in the evening, holding USE turns the lights out and
## starts the next morning.

@export var board_path: NodePath

var _board: Node3D
var _hold := 0.0
var _cooldown := 0.0   ## after it fires: keeping the button held doesn't fire again
const HOLD_TIME := 0.7
const COOLDOWN := 2.0


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
			return {"label": "Open now (or by itself in %s)" % GameConst.countdown(w.day.prep_left), "hold": true, "progress": _hold / HOLD_TIME}
		GameConst.Phase.CLOSING:
			return {"label": "Closing up once the last guests leave", "blocked": true}
		GameConst.Phase.EVENING:
			return {"label": "Lights out → next day", "hold": true, "progress": _hold / HOLD_TIME}
	return {}


func perform(_actor: Node, verb: int, delta: float) -> bool:
	var w := world()
	if verb != GameConst.Verb.USE or not (w.day.phase in [GameConst.Phase.MORNING, GameConst.Phase.EVENING]):
		return false
	if _cooldown > 0.0:
		# Still holding from "lights out": don't skip straight past the prep.
		_cooldown = COOLDOWN
		return true
	_hold += delta
	if _hold < HOLD_TIME:
		return true
	_hold = 0.0
	_cooldown = COOLDOWN
	if w.day.phase == GameConst.Phase.MORNING:
		w.day.open_early()
	else:
		w.day.start_next_day()
	return true


func server_tick(delta: float) -> void:
	# Decay partial holds when nobody is holding.
	_hold = maxf(_hold - delta * 0.5, 0.0)
	_cooldown = maxf(_cooldown - delta, 0.0)


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
