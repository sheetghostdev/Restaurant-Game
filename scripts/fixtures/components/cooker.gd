class_name Cooker
extends FixtureComponent
## Passively cooks the item in a slot when it matches this heat source.
## Feedback: colour shift (via the item's cook profile), a ding when perfect,
## steam, smoke and crackle when burning, and eventually a grease fire.
##
## Loose food cooks itself (patties, fries, croissants). A plate in an oven
## bakes the content that cooks on this heat (the dough under a pizza).

@export var heat: StringName = &"grill"
@export var speed := 1.0
@export var slot_index := 0
@export var loop_sound: StringName = &"sizzle_loop"
@export var glow_path: NodePath
## Safety appliances hold food at "perfect" instead of burning it (and never
## catch fire).
@export var safe := false

var _last_stage := -1
var _sync_t := 0.0
var _fx_t := 0.0
var _glow: Node3D


func _ready() -> void:
	if not glow_path.is_empty():
		_glow = get_node_or_null(glow_path)


## Loose food cooking here, or null (a baking dish is not returned).
func cooking_item() -> FoodItem:
	var s := fixture.slot(slot_index) if fixture else null
	if s and s.item is FoodItem and (s.item as FoodItem).can_cook_on(heat):
		return s.item
	return null


## What is cooking: {"item", "profile"} plus "c" (the content record) when a
## dish is baking. Empty when nothing here cooks on this heat.
func cooking() -> Dictionary:
	var s := fixture.slot(slot_index) if fixture else null
	if s == null or s.item == null:
		return {}
	if s.item is FoodItem and (s.item as FoodItem).can_cook_on(heat):
		return {"item": s.item, "profile": (s.item as FoodItem).def.cook_profile}
	if s.item is DishItem:
		var c := (s.item as DishItem).content_on(heat)
		if not c.is_empty():
			return {"item": s.item, "profile": Content.item(c["id"]).cook_profile, "c": c}
	return {}


static func cook_of(k: Dictionary) -> float:
	if k.has("c"):
		return float(k["c"].get("ck", 0.0))
	return (k["item"] as FoodItem).cook


func server_tick(delta: float) -> void:
	var k := cooking()
	if k.is_empty() or not fixture.is_working():
		_last_stage = -1
		return
	var it: Item = k["item"]
	var p: CookProfile = k["profile"]
	var r := p.rate * speed
	var ck := cook_of(k)
	var before := ck
	if p.stage_index(ck) >= p.perfect_stage:
		# Past perfect: the difficulty decides how long until it overcooks.
		r *= Difficulty.factor("overcook")
	ck += r * delta
	if safe:
		# Stops at the end of "perfect" (food that arrived overcooked stays as
		# it is: a safety grill never un-burns anything).
		ck = maxf(before, minf(ck, p.stage_ends[p.perfect_stage] - 0.01))
	if k.has("c"):
		k["c"]["ck"] = ck
	else:
		(it as FoodItem).cook = ck
	var st := p.stage_index(ck)
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
	if p.fire_at > 0.0 and ck >= p.fire_at and not safe:
		var fl := fixture.get_component("Flammable") as Flammable
		if fl and not fl.burning:
			fl.ignite()


func _process(delta: float) -> void:
	if fixture == null:
		return
	var k := cooking()
	var active := not k.is_empty() and fixture.is_working()
	if _glow:
		_glow.visible = active
	Audio.loop(fixture, loop_sound, active)
	if not active:
		return
	_fx_t -= delta
	if _fx_t <= 0.0 and fixture.world:
		_fx_t = 0.35
		var p: CookProfile = k["profile"]
		var ck := cook_of(k)
		var pos: Vector3 = (k["item"] as Item).global_position + Vector3(0, 0.12, 0)
		if ck >= p.smoke_from:
			fixture.world.fx.smoke(pos, 0.8, true)
		elif p.stage_index(ck) == p.perfect_stage:
			fixture.world.fx.steam(pos, 1.0, Color(1, 1, 1, 0.55), true)
		else:
			fixture.world.fx.steam(pos, 0.5, Color(1, 1, 1, 0.55), true)


func status_text() -> String:
	var k := cooking()
	if not k.is_empty():
		return (k["profile"] as CookProfile).stage_name(cook_of(k))
	return ""


## For the HUD progress ring above the slot.
func cook_progress() -> float:
	var k := cooking()
	if k.is_empty():
		return -1.0
	return cook_of(k)
