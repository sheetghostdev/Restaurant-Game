shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

// Inverted-hull outline for the targeted object, in the player's colour.
// The shell is grown away from a point just above the model's base, which
// keeps it continuous on flat-shaded geometry.

uniform vec4 color : source_color = vec4(1.0, 0.85, 0.4, 1.0);
uniform float width = 0.03;

void vertex() {
	vec3 dir = VERTEX - vec3(0.0, 0.3, 0.0);
	float len = max(length(dir), 0.0001);
	VERTEX += dir / len * width;
}

void fragment() {
	float pulse = 0.85 + 0.15 * sin(TIME * 6.0);
	ALBEDO = color.rgb * pulse;
}
