shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Shared material for nearly every model in the game.
// Vertex COLOR.rgb  = authored sRGB colour
// Vertex COLOR.a    = baked ambient occlusion (see MeshBuilder)
// Per-instance uniforms let cooking, spoilage and feedback recolour a mesh
// without breaking material sharing.

uniform float roughness_value : hint_range(0.0, 1.0) = 0.82;
uniform float specular_value : hint_range(0.0, 1.0) = 0.28;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.06;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;

instance uniform vec4 tint = vec4(1.0, 1.0, 1.0, 0.0);   // mix toward rgb by a
instance uniform vec3 mult = vec3(1.0, 1.0, 1.0);        // multiply (cooking)
instance uniform float flash = 0.0;                       // white feedback flash

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	vec3 col = mix(COLOR.rgb, tint.rgb, tint.a) * mult;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, saturation);
	col = to_linear(clamp(col, 0.0, 1.0)) * COLOR.a;
	ALBEDO = col;
	ROUGHNESS = roughness_value;
	SPECULAR = specular_value;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = col * fres * rim_strength + vec3(flash) * 0.6;
}
