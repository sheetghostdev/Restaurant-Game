class_name Cooker
extends FixtureComponent
## Passively cooks the item in a slot when it matches this heat source.
## Feedback: colour shift (via the item's cook profile), a ding when perfect,
## steam, smoke and crackle when burning, and eventually a grease fire.

@export var heat: StringName = &"grill"
@export var speed := 1.0
@export var slot_index := 0
@export var loop_sound: StringName = &"sizzle_loop"
@export var glow_path: NodePath

var _last_stage := -1
var _sync_t := 0.0
var _fx_t := 0.0
var _glow: Node3D


func _ready() -> void:
	if not glow_path.is_empty():
		_glow = get_node_or_null(glow_path)


func cooking_item() -> FoodItem:
	var s := fixture.slot(slot_index) if fixture else null
	if s and s.item is FoodItem and (s.item as FoodItem).can_cook_on(heat):
		return s.item
	return null


func server_tick(delta: float) -> void:
	var it := cooking_item()
	if it == null or not fixture.is_working():
		_last_stage = -1
		return
	var p := it.def.cook_profile
	var r := p.rate * speed
	if p.stage_index(it.cook) >= p.perfect_stage:
		# Past perfect: the difficulty decides how long until it overcooks.
		r *= Difficulty.factor("overcook")
	it.cook += r * delta
	var st := p.stage_index(it.cook)
	if st != _last_stage:
		if _last_stage >= 0:
			if st == p.perfect_stage:
				Audio.play_at(&"ding", fixture.global_position)
				if world():
					world().fx.sparkle(it.global_position + Vector3(0, 0.15, 0), Color("ffe08a"))
			elif st > p.perfect_stage and p.stage_quality[st] < 0.5:
				Audio.play_at(&"burn_warning", fixture.global_position)
		_last_stage = st
		it.refresh_visual()
		it.mark_dirty()
	_sync_t += delta
	if _sync_t > 0.3:
		_sync_t = 0.0
		it.refresh_visual()
		it.mark_dirty()
	if p.fire_at > 0.0 and it.cook >= p.fire_at:
		var fl := fixture.get_component("Flammable") as Flammable
		if fl and not fl.burning:
			fl.ignite()


func _process(delta: float) -> void:
	if fixture == null:
		return
	var it := cooking_item()
	var active := it != null and fixture.is_working()
	if _glow:
		_glow.visible = active
	Audio.loop(fixture, loop_sound, active)
	if not active:
		return
	_fx_t -= delta
	if _fx_t <= 0.0 and fixture.world:
		_fx_t = 0.35
		var p := it.def.cook_profile
		var pos := it.global_position + Vector3(0, 0.12, 0)
		if it.cook >= p.smoke_from:
			fixture.world.fx.smoke(pos, 0.8, true)
		elif p.stage_index(it.cook) == p.perfect_stage:
			fixture.world.fx.steam(pos, 1.0, Color(1, 1, 1, 0.55), true)
		else:
			fixture.world.fx.steam(pos, 0.5, Color(1, 1, 1, 0.55), true)


func status_text() -> String:
	var it := cooking_item()
	if it:
		return it.def.cook_profile.stage_name(it.cook)
	return ""


## For the HUD progress ring above the slot.
func cook_progress() -> float:
	var it := cooking_item()
	if it == null:
		return -1.0
	return it.cook
