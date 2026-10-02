class_name UIArt
## Procedurally generated textures used by billboards and the HUD (speech
## bubbles, soft circles, rounded panels). Cached on first use.

static var _cache := {}


static func bubble() -> Texture2D:
	if _cache.has("bubble"):
		return _cache["bubble"]
	var w := 160
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ink := Pal.UI_INK
	var paper := Color("fffaf0")
	var r := 34.0
	var body := Rect2(6, 6, w - 12, h - 34)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := _rounded_rect_sd(p, body, r)
			# Tail
			var tail := _tri_sd(p, Vector2(w * 0.42, body.end.y - 4), Vector2(w * 0.58, body.end.y - 4), Vector2(w * 0.47, h - 4))
			d = minf(d, tail)
			if d < -5.0:
				img.set_pixel(x, y, paper)
			elif d < 0.0:
				img.set_pixel(x, y, ink)
			elif d < 1.0:
				img.set_pixel(x, y, Color(ink.r, ink.g, ink.b, 1.0 - d))
	var tex := ImageTexture.create_from_image(img)
	_cache["bubble"] = tex
	return tex


static func circle(color: Color, size := 64, outline := 0.0, outline_color := Color.BLACK) -> Texture2D:
	var key := "circle_%s_%d_%f_%s" % [color.to_html(), size, outline, outline_color.to_html()]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	var rad := size * 0.5 - 1.0
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) - rad
			var col := color
			if outline > 0.0 and d > -outline:
				col = outline_color
			var a := clampf(-d, 0.0, 1.0)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, col.a * a))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func soft_dot(size := 64) -> Texture2D:
	var key := "soft_%d" % size
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var t := clampf(1.0 - Vector2(x + 0.5, y + 0.5).distance_to(c) / (size * 0.5), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, t * t))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _rounded_rect_sd(p: Vector2, r: Rect2, rad: float) -> float:
	var c := r.get_center()
	var hs := r.size * 0.5 - Vector2(rad, rad)
	var q := (p - c).abs() - hs
	return Vector2(maxf(q.x, 0), maxf(q.y, 0)).length() + minf(maxf(q.x, q.y), 0.0) - rad


static func _tri_sd(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> float:
	# Approximate signed distance: negative inside the triangle.
	var e := [[a, b], [b, c], [c, a]]
	var inside := true
	var dmin := INF
	for pair in e:
		var p0: Vector2 = pair[0]
		var p1: Vector2 = pair[1]
		var edge := p1 - p0
		var t := clampf((p - p0).dot(edge) / edge.length_squared(), 0.0, 1.0)
		dmin = minf(dmin, p.distance_to(p0 + edge * t))
		if edge.cross(p - p0) < 0.0:
			inside = false
	return -dmin if inside else dmin
