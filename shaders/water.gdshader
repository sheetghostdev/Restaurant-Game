shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

// Puddles and spills: glossy, slightly animated.
uniform vec4 color : source_color = vec4(0.55, 0.75, 0.85, 0.75);

void fragment() {
	float w = sin(UV.x * 18.0 + TIME * 2.0) * sin(UV.y * 16.0 - TIME * 1.7);
	ALBEDO = color.rgb + vec3(w * 0.03);
	ALPHA = color.a;
	ROUGHNESS = 0.08;
	SPECULAR = 0.8;
	METALLIC = 0.0;
}
