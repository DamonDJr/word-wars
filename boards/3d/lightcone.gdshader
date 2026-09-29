shader_type spatial;
// The cone of light under a street lamp, with the rain showing up in it.
//
// Added, not blended, and never writing depth. Brightest at the lamp and
// through the cone's middle (where you look through the most light), fading
// to nothing at its edges and toward the ground. The cones in
// `tools/blender/city.py` are merged into one mesh at the origin, so a
// vertex's height is its height above the street.

render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float intensity = 0.14;
uniform float apex = 7.25;
uniform float rain = 1.0;
uniform float fog_near = 60.0;
uniform float fog_far = 520.0;
uniform float fog_max = 0.7;

varying vec3 w;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float hgt = clamp(w.y / apex, 0.0, 1.0);
	float along = pow(hgt, 0.6) * smoothstep(0.0, 0.1, hgt);
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float body = pow(facing, 1.6);
	// Drops falling through the light: columns round the cone, each with its
	// own speed, a short bright streak in some of its cells.
	float t = mod(TIME, 600.0);
	vec2 rp = vec2((w.x - w.z) * 7.0, w.y * 0.8 + t * 6.5);
	vec2 cell = floor(rp);
	vec2 f = fract(rp);
	float drop = step(0.62, hash(cell)) * (1.0 - smoothstep(0.08, 0.28, abs(f.x - 0.5)))
			* smoothstep(0.0, 0.06, f.y) * (1.0 - smoothstep(0.06, 0.4, f.y));
	vec3 c = COLOR.rgb * intensity * along * body * (1.0 + rain * drop * 3.0);
	ALBEDO = c * (1.0 - smoothstep(fog_near, fog_far, length(VERTEX)) * fog_max);
}
