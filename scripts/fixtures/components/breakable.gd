class_name Breakable
extends FixtureComponent
## Equipment that can break down (disaster events) and must be repaired by
## holding USE. While broken the fixture's machinery stops.

@export var repair_time := 3.5

var broken := false
var progress := 0.0
var _sound_t := 0.0
var _fx_t := 0.0
var _icon: Label3D


func blocks_function() -> bool:
	return broken


func query(_actor: Node, verb: int) -> Dictionary:
	if broken and verb == GameConst.Verb.USE:
		return {"label": "Repair", "hold": true, "anim": CharacterRig.Anim.REPAIR, "progress": progress / repair_time}
	return {}


func perform(actor: Node, verb: int, delta: float) -> bool:
	if not broken or verb != GameConst.Verb.USE:
		return false
	var speed: float = actor.get("work_speed") if actor.get("work_speed") != null else 1.0
	progress += delta * speed
	_sound_t -= delta
	if _sound_t <= 0.0:
		_sound_t = 0.45
		Audio.play_at(&"repair_loop", fixture.global_position, -6.0, randf_range(0.9, 1.1))
	if progress >= repair_time:
		fix()
	fixture.mark_dirty()
	return true


func break_down() -> void:
	if broken:
		return
	broken = true
	progress = 0.0
	Audio.play_at(&"breakdown", fixture.global_position)
	Events.notify("%s broke down!" % fixture.display_name(), &"warning")
	if world():
		world().fx.sparks(fixture.global_position + Vector3(0, 0.9, 0))
		world().camera.add_shake(0.4)
	fixture.mark_dirty()


func fix() -> void:
	broken = false
	progress = 0.0
	Audio.play_at(&"repair_done", fixture.global_position)
	if world():
		world().fx.sparkle(fixture.global_position + Vector3(0, 1.0, 0), Color("8fe39a"))
		world().stats_add(&"repairs", 1)
	fixture.mark_dirty()


func status_text() -> String:
	return "Broken — hold USE to repair" if broken else ""


func _process(delta: float) -> void:
	if fixture == null:
		return
	if broken:
		if _icon == null:
			_icon = Label3D.new()
			_icon.text = "!"
			_icon.font = load("res://art/fonts/AlfaSlabOne-Regular.ttf")
			_icon.font_size = 96
			_icon.pixel_size = 0.005
			_icon.modulate = Pal.WARNING
			_icon.outline_size = 18
			_icon.outline_modulate = Pal.UI_INK
			_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			_icon.no_depth_test = true
			_icon.position = Vector3(0, 1.7, 0)
			fixture.add_child(_icon)
		_icon.visible = true
		_icon.position.y = 1.7 + sin(Time.get_ticks_msec() * 0.008) * 0.06
		_fx_t -= delta
		if _fx_t <= 0.0 and fixture.world:
			_fx_t = 0.6
			fixture.world.fx.smoke(fixture.global_position + Vector3(0, 0.95, 0), 0.6, true)
	elif _icon:
		_icon.visible = false


func get_state() -> Dictionary:
	return {"b": broken, "p": snappedf(progress, 0.05)} if broken else {}


func set_state(d: Dictionary) -> void:
	broken = d.get("b", false)
	progress = d.get("p", 0.0)
