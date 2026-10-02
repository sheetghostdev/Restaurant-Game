shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

// Placement preview for build mode.
uniform vec4 color : source_color = vec4(0.3, 0.9, 0.5, 0.45);

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.5);
	float stripes = step(0.5, fract((VERTEX.y + TIME * 0.4) * 6.0));
	ALBEDO = color.rgb;
	ALPHA = color.a * (0.55 + 0.45 * fres) * (0.8 + 0.2 * stripes);
}
