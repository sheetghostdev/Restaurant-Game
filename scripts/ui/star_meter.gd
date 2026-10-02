class_name StarMeter
extends Control
## Five chunky stars with partial fill for the restaurant's reputation.

var value := 0.0:
	set(v):
		value = clampf(v, 0.0, 5.0)
		queue_redraw()
var star_size := 22.0


func _init() -> void:
	custom_minimum_size = Vector2(star_size * 5.6, star_size * 1.15)


func _draw() -> void:
	for i in 5:
		var c := Vector2(star_size * 0.55 + i * star_size * 1.1, size.y * 0.5)
		var pts := _star(c, star_size * 0.55, star_size * 0.25)
		draw_colored_polygon(pts, Color(0, 0, 0, 0.12))
		var fill := clampf(value - i, 0.0, 1.0)
		if fill > 0.0:
			var clipped := Geometry2D.intersect_polygons(pts, PackedVector2Array([
				Vector2(c.x - star_size, c.y - star_size), Vector2(c.x - star_size * 0.55 + star_size * 1.1 * fill, c.y - star_size),
				Vector2(c.x - star_size * 0.55 + star_size * 1.1 * fill, c.y + star_size), Vector2(c.x - star_size, c.y + star_size)]))
			for poly in clipped:
				draw_colored_polygon(poly, Pal.UI_STAR)
		var outline := pts.duplicate()
		outline.push_back(pts[0])
		draw_polyline(outline, Pal.UI_INK, 2.5, true)


func _star(c: Vector2, r_out: float, r_in: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + k * PI / 5.0
		var r := r_out if k % 2 == 0 else r_in
		out.push_back(c + Vector2(cos(a), sin(a)) * r)
	return out
