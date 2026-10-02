shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;

// Drawn on top of an interaction target (material_overlay). A soft fill plus a
// pulsing rim in the targeting player's colour.

uniform vec4 color : source_color = vec4(1.0, 0.85, 0.4, 1.0);
uniform float fill = 0.07;
uniform float rim = 0.75;
uniform float pulse_speed = 5.0;

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float p = 0.75 + 0.25 * sin(TIME * pulse_speed);
	ALBEDO = color.rgb * (fill + fres * rim) * p;
	ALPHA = 1.0;
}
