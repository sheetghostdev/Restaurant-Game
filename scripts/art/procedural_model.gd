@tool
class_name ProceduralModel
extends MeshInstance3D
## Shows a mesh from the Models library. Works in the editor so fixture scenes
## can be previewed and their slots positioned visually.

@export var model_key: StringName = &"":
	set(v):
		model_key = v
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if model_key == &"":
		mesh = null
		return
	mesh = Models.mesh(model_key)
