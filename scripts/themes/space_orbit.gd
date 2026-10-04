class_name SpaceOrbit
extends Node3D
## The Orbital Galley's surroundings: space lighting, a starfield and a
## planet turning far below. Supplies come from hydroponic planters and the
## food printer, which are ordinary fixtures.

var world: GameWorld
var _planet: Node3D
var _clouds: Node3D


func _ready() -> void:
	world.lighting.space = true
	world.lighting.set_hour(world.day.hour if world.day else 8.0, true)
	var c := Vector2(world.grid.lot.get_center())
	add_starfield(self, c)
	_planet = add_planet(self, c)


## Also used by the title screen's preview.
static func add_starfield(parent: Node3D, c: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var quad := BoxMesh.new()
	quad.size = Vector3(0.1, 0.1, 0.1)
	mm.mesh = quad
	mm.instance_count = 700
	for i in mm.instance_count:
		var p := Vector3(c.x + rng.randf_range(-110, 110), rng.randf_range(-70, -14), c.y + rng.randf_range(-90, 110))
		var s := rng.randf_range(0.6, 1.4) if rng.randf() < 0.92 else rng.randf_range(2.0, 2.8)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), p))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = Models.mat_unshaded(Color("e8ecff"))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


static func add_planet(parent: Node3D, c: Vector2) -> Node3D:
	var planet := Node3D.new()
	# Far below and behind the station, so its curve fills the top corner.
	planet.position = Vector3(c.x + 30.0, -78.0, c.y - 48.0)
	planet.scale = Vector3.ONE * 0.7
	parent.add_child(planet)
	var b := MeshBuilder.new()
	b.sphere(Vector3.ZERO, Vector3(48, 48, 48), Color("2d6fb3"), 4, Color(0, 0, 0, 0), 0.0, 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for k in 9:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 1), rng.randf_range(-1, 1)).normalized()
		b.sphere(dir * 44.0, Vector3(14, 6, 11) * rng.randf_range(0.6, 1.2), Color("5f9a4c").lerp(Color("c9b27a"), rng.randf() * 0.5), 1, Color(0, 0, 0, 0), 0.15, k)
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(Models.mat_main())
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	planet.add_child(mi)
	# Atmosphere glow.
	var atm := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 50.5
	sm.height = 101.0
	atm.mesh = sm
	var am := StandardMaterial3D.new()
	am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	am.albedo_color = Color(0.55, 0.8, 1.0, 0.18)
	am.cull_mode = BaseMaterial3D.CULL_FRONT
	atm.material_override = am
	atm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	planet.add_child(atm)
	return planet


func _process(delta: float) -> void:
	if _planet:
		_planet.rotation.y += delta * 0.01


func status_line() -> String:
	return ""
