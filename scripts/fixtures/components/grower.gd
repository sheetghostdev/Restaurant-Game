class_name Grower
extends FixtureComponent
## A hydroponic planter: grows one crop for free, a unit at a time, up to a
## few ready to pick. USE switches the crop (what's growing is lost), GRAB
## with empty hands harvests one.

const MAX_READY := 4

var crop: StringName
var stock := 0
var progress := 0.0
var _plants: Node3D
var _shown := ""


## Crops worth growing here: raw ingredients the menu uses that can grow.
func crops() -> Array[StringName]:
	var out: Array[StringName] = []
	var w := world()
	if w == null or w.format == null:
		return out
	for id in Content.menu_ingredients(w.format):
		var d := Content.item(id)
		if d and d.grow_seconds > 0.0:
			out.push_back(id)
	return out


func _ensure_crop() -> void:
	if crop == &"" or not crops().has(crop):
		var c := crops()
		crop = c[0] if not c.is_empty() else &""


func query(actor: Node, verb: int) -> Dictionary:
	if actor.held() != null:
		return {}
	_ensure_crop()
	if verb == GameConst.Verb.GRAB:
		if crop == &"":
			return {}
		if stock > 0:
			return {"label": "Harvest %s" % Content.display_name(crop).to_lower()}
		return {"label": "Still growing", "blocked": true}
	if verb == GameConst.Verb.USE:
		var c := crops()
		if c.size() > 1:
			var nxt := c[(c.find(crop) + 1) % c.size()]
			return {"label": "Grow %s instead" % Content.display_name(nxt).to_lower()}
	return {}


func perform(actor: Node, verb: int, _delta: float) -> bool:
	var q := query(actor, verb)
	if q.is_empty() or q.get("blocked", false):
		return false
	if verb == GameConst.Verb.GRAB:
		stock -= 1
		actor.hold(world().spawn_item(crop))
		Audio.play_at(&"crate_take", fixture.global_position, -2.0, 1.3)
	else:
		var c := crops()
		crop = c[(c.find(crop) + 1) % c.size()]
		stock = 0
		progress = 0.0
		Audio.play_at(&"ui_confirm", fixture.global_position, -4.0)
	fixture.mark_dirty()
	return true


func server_tick(delta: float) -> void:
	_ensure_crop()
	if crop == &"" or stock >= MAX_READY or not fixture.is_working():
		return
	var d := Content.item(crop)
	progress += delta / maxf(d.grow_seconds, 1.0)
	if progress >= 1.0:
		progress = 0.0
		stock += 1
		fixture.mark_dirty()
		if world():
			world().fx.sparkle(fixture.global_position + Vector3(0, 0.9, 0), Color("b8f28a"))
	elif int(progress * 10.0) != int((progress - delta / maxf(d.grow_seconds, 1.0)) * 10.0):
		fixture.mark_dirty()   # clients see the plants grow in steps


func status_text() -> String:
	_ensure_crop()
	if crop == &"":
		return "Nothing on the menu grows here"
	var d := Content.item(crop)
	if stock >= MAX_READY:
		return "%s · %d ready (full)" % [d.display_name, stock]
	var left := int(ceil((1.0 - progress) * d.grow_seconds))
	return "%s · %d ready · next in %d s" % [d.display_name, stock, left]


func _process(_delta: float) -> void:
	if fixture == null or not fixture.is_inside_tree():
		return
	var key := "%s|%d|%d" % [crop, stock, int(progress * 5.0)]
	if key == _shown:
		return
	_shown = key
	if _plants:
		_plants.queue_free()
	_plants = Node3D.new()
	fixture.add_child(_plants)
	if crop == &"":
		return
	# Sprouts that grow with progress, then the harvest sitting on top.
	var g := 0.35 + 0.65 * progress if stock < MAX_READY else 1.0
	for i in 3:
		var sp := Models.instance(&"sprout")
		sp.position = Vector3(-0.26 + i * 0.26, 0.74, 0.0)
		sp.scale = Vector3(1, g, 1)
		sp.rotation.y = i * 2.1
		_plants.add_child(sp)
	var d := Content.item(crop)
	for i in stock:
		var m := Models.instance(d.model)
		m.position = Vector3(-0.27 + (i % 2) * 0.54, 0.82, -0.12 + (i / 2) * 0.24)
		m.scale = Vector3.ONE * 0.8
		_plants.add_child(m)


func get_state() -> Dictionary:
	return {"c": String(crop), "r": stock, "g": snappedf(progress, 0.01)}


func set_state(d: Dictionary) -> void:
	crop = StringName(d.get("c", String(crop)))
	stock = int(d.get("r", stock))
	progress = float(d.get("g", progress))
