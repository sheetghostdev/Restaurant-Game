class_name Sprinkler
extends FixtureComponent
## Ceiling fire sprinkler: a few seconds after something nearby catches fire
## it soaks it out (leaving a puddle to mop). Works in a power cut.

const RANGE := 3.6
const DELAY := 2.5

var _seen := {}       ## Flammable -> seconds burning in range


func server_tick(delta: float) -> void:
	var w := world()
	if w == null:
		return
	for f in w.grid.all_fixtures():
		var fl := f.get_component("Flammable") as Flammable
		if fl == null or not fl.burning:
			_seen.erase(fl)
			continue
		if f.global_position.distance_to(fixture.global_position) > RANGE:
			continue
		_seen[fl] = float(_seen.get(fl, 0.0)) + delta
		if _seen[fl] >= DELAY:
			_seen.erase(fl)
			fl.extinguish(2.0)
			Audio.play_at(&"splash", f.global_position)
			w.fx.steam(f.global_position + Vector3(0, 1.2, 0), 2.0, Color(0.8, 0.9, 1.0, 0.7))
			w.disasters.spawn_mess(&"spill", f.global_position + f.front_vec() * 0.8)
			Events.notify("The sprinkler put out the %s fire" % f.def.display_name.to_lower(), &"info")


func status_text() -> String:
	return "Puts out fires within %d m" % int(RANGE)
