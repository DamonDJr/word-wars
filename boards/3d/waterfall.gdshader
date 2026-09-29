shader_type spatial;
// Falling and running water: streaks that travel down the ribbon, foam at the
// edges and over the lip, and a fade into the clouds at the bottom.
//
// The ribbons from `tools/blender/sky_islands.py` carry UV.x across, UV.y
// along in units of the fall's own width (so every island's streaks are the
// same size), and UV2.x 0..1 down the fall for the fade. glTF flips V on
// export, so UV.y *falls* as the water does, and the streaks run downhill by
// adding time, not subtracting it.

render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec3 deep : source_color = vec3(0.36, 0.74, 0.93);
uniform vec3 light : source_color = vec3(0.74, 0.94, 1.0);
uniform vec3 foam : source_color = vec3(1.0);
uniform float speed = 1.4;
// 1 for a fall (fades out at the bottom), 0 for a stream (runs full length).
uniform float fade = 1.0;
uniform float opacity = 0.95;
uniform vec3 fog_color : source_color = vec3(0.82, 0.92, 1.0);
uniform float fog_near = 30.0;
uniform float fog_far = 130.0;
uniform float fog_max = 0.7;

varying float v_dist;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	v_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	// Wrapped so a phone left on the board for an hour does not run the
	// hash out of float precision and start drawing blocks.
	float along = UV.y + mod(TIME * speed, 400.0);
	float n = vnoise(vec2(UV.x * 6.0, along * 1.2)) * 0.65
			+ vnoise(vec2(UV.x * 14.0, along * 2.6)) * 0.35;
	float streak = smoothstep(0.62, 0.68, n);
	float edge = smoothstep(0.3, 0.47, abs(UV.x - 0.5));
	vec3 c = mix(deep, light, smoothstep(0.35, 0.55, n));
	c = mix(c, foam, max(streak, edge * 0.85));
	float s = UV2.x;
	c = mix(c, foam, (1.0 - smoothstep(0.0, 0.06, s)) * fade);
	float a = mix(1.0, 1.0 - smoothstep(0.3, 0.92, s), fade);
	float f = smoothstep(fog_near, fog_far, v_dist) * fog_max;
	ALBEDO = mix(c, fog_color, f);
	ALPHA = a * opacity;
}
