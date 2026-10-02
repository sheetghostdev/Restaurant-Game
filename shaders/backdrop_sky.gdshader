shader_type sky;

// Soft studio-style gradient behind the diorama. Colours are driven by the
// lighting rig to follow the time of day.
uniform vec3 top_color : source_color = vec3(0.93, 0.88, 0.78);
uniform vec3 horizon_color : source_color = vec3(0.98, 0.93, 0.84);
uniform vec3 bottom_color : source_color = vec3(0.55, 0.62, 0.60);
uniform float energy = 1.0;

void sky() {
	float y = EYEDIR.y;
	vec3 c = mix(horizon_color, top_color, smoothstep(0.0, 0.8, y));
	c = mix(c, bottom_color, smoothstep(0.0, -0.6, y));
	COLOR = c * energy;
}
