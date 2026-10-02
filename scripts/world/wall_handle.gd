class_name WallHandle
extends Node3D
## Build-mode handle on a wall or doorway between two rooms. Hold USE to knock
## a doorway through (or wall one up). Only exists during calm phases.

var manager: BuildManager
var a: Vector2i
var b: Vector2i
var _marker: MeshInstance3D
var _hold := 0.0
const HOLD := 1.0


func _ready() -> void:
	add_to_group(&"interactables")
	position = (GameConst.cell_center(a) + GameConst.cell_center(b)) * 0.5 + Vector3(0, 0.9, 0)
	_marker = MeshInstance3D.new()
	var mb := MeshBuilder.new()
	mb.box(Vector3.ZERO, Vector3(0.12, 0.12, 0.12), Color(1, 1, 1), 0.03)
	_marker.mesh = mb.commit()
	_marker.material_override = Models.mat_unshaded(Color(1, 0.95, 0.8, 0.35), true)
	_marker.rotation = Vector3(PI / 4, PI / 4, 0)
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)


func target_point() -> Vector3:
	return Vector3(global_position.x, 0, global_position.z)


func display_name() -> String:
	return "Doorway" if manager.world.grid.opening_type(a, b) != "" else "Wall"


func status_text() -> String:
	return "Build mode"


func interact_query(actor: Node, verb: int) -> Dictionary:
	if verb != GameConst.Verb.USE or actor.held() != null:
		return {}
	if manager.world.grid.opening_type(a, b) == "":
		return {"label": "Knock through (%s)" % GameConst.money(BuildManager.KNOCK_COST), "hold": true, "progress": _hold / HOLD, "anim": CharacterRig.Anim.REPAIR}
	return {"label": "Wall it up (%s)" % GameConst.money(BuildManager.BRICK_COST), "hold": true, "progress": _hold / HOLD, "anim": CharacterRig.Anim.REPAIR}


func interact_perform(_actor: Node, verb: int, delta: float) -> bool:
	if verb != GameConst.Verb.USE:
		return false
	_hold += delta
	if _hold >= HOLD:
		_hold = 0.0
		manager.toggle_opening(a, b)
	return true


func _process(delta: float) -> void:
	_marker.rotation.y += delta * 1.5
	_hold = maxf(_hold - delta * 0.3, 0.0)
