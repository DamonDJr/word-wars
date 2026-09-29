shader_type spatial;
// The northern lights: tall curtains hung across the sky, green at the hem
// going to violet at the top, with folds that travel along them and fine
// rays running up. Added over the sky, and the curtain itself sways.
//
// From `tools/blender/aurora.py`: each curtain is a ribbon with UV.x along it
// in metres and UV2.x up it from the hem (0) to the top (1).

render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 low : source_color = vec3(0.25, 1.0, 0.55);
uniform vec3 middle : source_color = vec3(0.1, 0.9, 0.75);
uniform vec3 high : source_color = vec3(0.62, 0.3, 1.0);
uniform float intensity = 0.9;
uniform float wave = 18.0;

float hash(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash(i), hash(i + 1.0), f * f * (3.0 - 2.0 * f));
}

void vertex() {
	float t = mod(TIME, 2000.0);
	float u = UV.x;
	VERTEX.z += (sin(u * 0.004 + t * 0.12) + 0.5 * sin(u * 0.011 - t * 0.2)) * wave * (0.3 + UV2.x);
}

void fragment() {
	float v = UV2.x;
	float u = UV.x;
	float t = mod(TIME, 2000.0);
	float fold = 0.5 + 0.5 * sin(u * 0.012 + t * 0.35) * sin(u * 0.005 - t * 0.21);
	float rays = 0.45 + 0.55 * noise1(u * 0.08 + t * 0.6) * noise1(u * 0.21 - t * 0.4);
	float hem = smoothstep(0.0, 0.05, v) * (1.0 - smoothstep(0.08, 1.0, v));
	vec3 c = mix(low, middle, smoothstep(0.04, 0.3, v));
	c = mix(c, high, smoothstep(0.35, 0.95, v));
	// The ends of a curtain fade out rather than stopping.
	float ends = smoothstep(0.0, 0.08, UV2.y) * (1.0 - smoothstep(0.92, 1.0, UV2.y));
	ALBEDO = c * hem * rays * (0.35 + 0.65 * fold) * intensity * ends;
}
