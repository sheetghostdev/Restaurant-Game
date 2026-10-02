class_name Flammable
extends FixtureComponent
## Grease fires. A fire blocks the station, slowly spreads to neighbouring
## flammable fixtures and eventually wrecks the equipment unless someone grabs
## the extinguisher.

const SPREAD_TIME := 10.0
const DAMAGE_TIME := 28.0

var burning := false
var intensity := 0.0
var _spread_t := 0.0
var _burn_t := 0.0
var _fire: FireFX


func blocks_interaction() -> bool:
	return burning


func blocks_function() -> bool:
	return burning


func query(actor: Node, _verb: int) -> Dictionary:
	if burning:
		var held: Item = actor.held()
		if held is ToolItem and held.def_id == &"extinguisher":
			return {"label": "", "blocked": true}
		return {"label": "On fire! Grab an extinguisher", "blocked": true}
	return {}


func perform(actor: Node, _verb: int, _delta: float) -> bool:
	Audio.play_at(&"error", actor.global_position, -6.0)
	return false


func ignite() -> void:
	if burning:
		return
	burning = true
	intensity = 0.6
	_spread_t = 0.0
	_burn_t = 0.0
	Audio.play_at(&"glass_break", fixture.global_position, -6.0, 1.3)
	if world():
		world().disasters.on_fire_started(fixture)
	fixture.mark_dirty()


## Returns true if the fire went out.
func extinguish(amount: float) -> bool:
	if not burning:
		return false
	intensity -= amount
	if intensity <= 0.0:
		burning = false
		intensity = 0.0
		Audio.play_at(&"repair_done", fixture.global_position, -4.0, 0.8)
		if world():
			world().fx.smoke(fixture.global_position + Vector3(0, 0.9, 0), 1.6)
			world().disasters.on_fire_out(fixture)
		fixture.mark_dirty()
		return true
	fixture.mark_dirty()
	return false


func server_tick(delta: float) -> void:
	if not burning:
		return
	intensity = minf(intensity + delta * 0.035, 1.0)
	_spread_t += delta
	_burn_t += delta
	# Food in the fire keeps burning.
	for s in fixture.slots:
		if s.item is FoodItem:
			(s.item as FoodItem).cook += delta * 0.2
	if _spread_t >= SPREAD_TIME:
		_spread_t = 0.0
		_spread()
	if _burn_t >= DAMAGE_TIME:
		_burn_t = 0.0
		var br := fixture.get_component("Breakable") as Breakable
		if br and not br.broken:
			br.break_down()


func _spread() -> void:
	var w := world()
	if w == null:
		return
	var options := []
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var f := w.grid.fixture_at(fixture.cell + d)
		if f and f.def and f.def.flammable:
			var fl := f.get_component("Flammable") as Flammable
			if fl and not fl.burning:
				options.push_back(fl)
	if not options.is_empty():
		(options[randi() % options.size()] as Flammable).ignite()


func status_text() -> String:
	return "ON FIRE!" if burning else ""


func _process(_delta: float) -> void:
	if fixture == null:
		return
	if burning and _fire == null:
		_fire = FireFX.new()
		_fire.position = Vector3(0, 0.85, 0)
		fixture.add_child(_fire)
	if _fire:
		_fire.intensity = intensity if burning else 0.0
		if not burning and _fire.is_finished():
			_fire.queue_free()
			_fire = null
	Audio.loop(fixture, &"fire_loop", burning)


func get_state() -> Dictionary:
	return {"on": true, "i": snappedf(intensity, 0.02)} if burning else {}


func set_state(d: Dictionary) -> void:
	burning = d.get("on", false)
	intensity = d.get("i", 0.0)
