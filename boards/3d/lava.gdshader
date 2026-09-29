shader_type spatial;
// Lava, in flat cartoon bands: crust, dull red, orange, and a hot yellow core,
// churning slowly (domain-warped noise) and drifting the way it flows.
//
// Two ways to know which way that is. On the ground plane (`use_uv` 0) the
// pattern is laid in world space and slides along `flow`, so the cracks
// between every slab of basalt show one continuous sheet moving under them.
// On a ribbon (`use_uv` 1: the flows down the volcano) it runs along the
// ribbon, downhill; glTF flips V on export, so UV.y falls as the lava does
// and time is added, not subtracted.

render_mode unshaded, cull_disabled;

uniform vec3 hot : source_color = vec3(1.0, 0.93, 0.5);
uniform vec3 warm : source_color = vec3(1.0, 0.6, 0.12);
uniform vec3 cool : source_color = vec3(0.86, 0.24, 0.07);
uniform vec3 crust : source_color = vec3(0.28, 0.08, 0.06);
// How much of the surface is crusted over, 0..1.
uniform float crust_amount = 0.3;
uniform float speed = 0.25;
// Noise frequency: per metre on the ground, per ribbon width on a ribbon.
uniform float scale = 0.3;
uniform float use_uv = 0.0;
uniform vec2 flow = vec2(0.0, 1.0);
// How hard the whole surface breathes.
uniform float pulse = 0.08;
uniform vec3 fog_color : source_color = vec3(0.4, 0.12, 0.08);
uniform float fog_near = 40.0;
uniform float fog_far = 170.0;
uniform float fog_max = 0.5;

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

float fbm(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.03 + 7.1) * 0.3 + vnoise(p * 4.1 - 3.7) * 0.15;
}

void fragment() {
	// Wrapped, as in the waterfall, to keep the hash inside float precision.
	float t = mod(TIME, 600.0);
	vec3 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p;
	if (use_uv > 0.5) {
		p = vec2(UV.x * 1.6, (UV.y + t * speed) * 0.7) * scale * 3.0;
	} else {
		p = w.xz * scale - flow * t * speed;
	}
	vec2 q = vec2(fbm(p + vec2(0.0, t * 0.05)), fbm(p + vec2(5.2, 1.3) - t * 0.04));
	float n = fbm(p + q * 1.4);
	n += sin(t * 1.3 + w.x * 0.2 + w.z * 0.15) * pulse;
	float c0 = 0.28 + crust_amount * 0.2;
	vec3 c = crust;
	c = mix(c, cool, smoothstep(c0, c0 + 0.03, n));
	c = mix(c, warm, smoothstep(0.5, 0.53, n));
	c = mix(c, hot, smoothstep(0.67, 0.7, n));
	float f = smoothstep(fog_near, fog_far, length(VERTEX)) * fog_max;
	ALBEDO = mix(c, fog_color, f);
}
