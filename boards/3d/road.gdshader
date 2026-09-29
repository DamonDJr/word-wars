shader_type spatial;
// A wet street: dark asphalt, lane paint, puddles, rain rings, and the whole
// city reflected in it, smeared downward the way lights run on wet tarmac.
//
// The reflection is a second camera's picture (see `board3d.gd`): the same
// scene filmed from below the road, the main camera mirrored in its plane.
// That picture comes out upside down relative to a mirror, so it is read at
// (x, 1 - y) of this fragment's place on screen, pushed about by the ripples
// and averaged over a few taps above, which is the streak.
//
// `sidewalk` 1 swaps the lanes for paving slabs and reflects less.

render_mode unshaded;

uniform sampler2D reflection : hint_default_black, filter_linear, repeat_disable;
uniform float reflect_amount = 0.85;
uniform float streak = 1.0;
uniform float flip_y = 1.0;
uniform vec3 base_a : source_color = vec3(0.03, 0.04, 0.085);
uniform vec3 base_b : source_color = vec3(0.06, 0.075, 0.14);
uniform vec3 paint : source_color = vec3(0.72, 0.76, 0.85);
uniform float sidewalk = 0.0;
// Off for water: a lake is this with no paint on it.
uniform float markings = 1.0;
// The cross streets, as (start, end) pairs along the street.
uniform vec4 crossings = vec4(100.0, 114.0, 262.0, 274.0);
uniform float ripples = 1.0;
uniform vec3 fog_color : source_color = vec3(0.06, 0.1, 0.3);
uniform float fog_near = 60.0;
uniform float fog_far = 520.0;
uniform float fog_max = 0.8;

varying vec3 w;

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

// Lane paint on the street, in the street's own coordinates (x across,
// y along).
float paint_lines(vec2 p) {
	float ax = abs(p.x);
	float m = 0.0;
	bool junction = (p.y > crossings.x && p.y < crossings.y)
			|| (p.y > crossings.z && p.y < crossings.w);
	if (!junction) {
		float dash = step(fract(p.y / 9.0), 0.36);
		m = max(m, (1.0 - smoothstep(0.06, 0.09, abs(ax - 3.0))) * dash);
		m = max(m, 1.0 - smoothstep(0.07, 0.1, abs(ax - 5.6)));
		m = max(m, 1.0 - smoothstep(0.05, 0.08, abs(ax - 0.14)));
	}
	for (int i = 0; i < 2; i++) {
		float a = i == 0 ? crossings.x : crossings.z;
		float b = i == 0 ? crossings.y : crossings.w;
		float zebra = step(a - 4.5, p.y) * step(p.y, a - 0.8) + step(b + 0.8, p.y) * step(p.y, b + 4.5);
		m = max(m, zebra * step(0.5, fract(p.x / 1.1)) * step(ax, 5.5));
	}
	return m;
}

void vertex() {
	w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float dist = length(VERTEX);
	vec2 g = vec2(w.x, -w.z);
	float t = mod(TIME, 600.0);
	float n = fbm(g * 0.18);
	float puddle = smoothstep(0.42, 0.62, n);
	vec3 base = mix(base_a, base_b, fbm(g * 1.7) * 0.6 + n * 0.4);
	float mk = 0.0;
	if (sidewalk > 0.5) {
		vec2 slab = abs(fract(g / 1.6) - 0.5);
		base *= mix(0.62, 1.0, 1.0 - smoothstep(0.46, 0.49, max(slab.x, slab.y)));
	} else if (markings > 0.5 && abs(g.x) < 6.0) {
		mk = paint_lines(g);
	}

	// Rain rings: one cell in each 80 cm has a drop landing, on its own
	// clock; only near enough to see.
	vec2 cg = g / 0.8;
	vec2 cell = floor(cg);
	vec2 f = fract(cg) - 0.5;
	float h1 = hash(cell);
	float life = fract(t * 0.9 + h1);
	vec2 o = vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5;
	float r = length(f - o * 0.5);
	float ring = (1.0 - smoothstep(0.0, 0.035, abs(r - life * 0.26))) * (1.0 - life) * step(0.5, h1);
	ring *= ripples * (1.0 - smoothstep(12.0, 45.0, dist));

	// Stretched along the street and wobbled across it, so the city breaks
	// up into the vertical runs of colour wet tarmac makes of it.
	vec2 wob = vec2(fbm(vec2(g.x * 2.2, g.y * 0.35) + vec2(0.0, t * 0.5)) - 0.5, 0.0) * 0.022;
	vec2 ruv = vec2(SCREEN_UV.x, mix(SCREEN_UV.y, 1.0 - SCREEN_UV.y, flip_y)) + wob + vec2(ring * 0.004);
	vec3 refl = vec3(0.0);
	float wsum = 0.0;
	for (int i = 0; i < 8; i++) {
		float k = float(i);
		float wt = 1.0 / (1.0 + k * 0.6);
		refl += texture(reflection, ruv + vec2(0.0, k * 0.011 * streak)).rgb * wt;
		wsum += wt;
	}
	refl /= wsum;
	float amount = reflect_amount * mix(0.5, 1.0, puddle);
	vec3 c = base + refl * amount;
	c = mix(c, paint * 0.5 + refl * 0.25, mk * (1.0 - puddle * 0.5));
	c += vec3(0.5, 0.6, 0.8) * ring * 0.12;
	float fo = smoothstep(fog_near, fog_far, dist) * fog_max;
	ALBEDO = mix(c, fog_color, fo);
}
