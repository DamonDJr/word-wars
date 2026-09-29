shader_type sky;
// A painted day sky: pale at the horizon, deep blue overhead, and a warm glow
// in the upper left where the light comes from.

uniform vec3 top_color : source_color = vec3(0.22, 0.52, 0.93);
uniform vec3 mid_color : source_color = vec3(0.47, 0.74, 0.98);
uniform vec3 horizon_color : source_color = vec3(0.84, 0.94, 1.0);
uniform vec3 glow_dir = vec3(-0.45, 0.55, -0.7);
uniform vec3 glow_color : source_color = vec3(1.0, 0.97, 0.88);
uniform float glow_amount = 0.35;
// Where the horizon colour has given way to the middle one, and the middle to
// the top, in EYEDIR.y.
uniform vec2 mid_at = vec2(-0.35, 0.1);
uniform vec2 top_at = vec2(0.1, 0.65);
// Drifting cloud, darker than the sky behind it, lit at the edges by the glow.
uniform float clouds = 0.0;
uniform vec3 cloud_color : source_color = vec3(0.05, 0.07, 0.2);
// Stars, twinkling, above the horizon; and a nebula, two colours of glowing
// gas round a bright core in the direction `nebula_dir`.
uniform float stars = 0.0;
uniform float nebula = 0.0;
uniform vec3 nebula_a : source_color = vec3(0.4, 0.12, 0.7);
uniform vec3 nebula_b : source_color = vec3(0.95, 0.35, 0.8);
uniform vec3 nebula_dir = vec3(0.2, 0.25, -1.0);

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
	return vnoise(p) * 0.5 + vnoise(p * 2.1 + 3.3) * 0.3 + vnoise(p * 4.3 - 1.7) * 0.2;
}

void sky() {
	float y = EYEDIR.y;
	vec3 c = mix(horizon_color, mid_color, smoothstep(mid_at.x, mid_at.y, y));
	c = mix(c, top_color, smoothstep(top_at.x, top_at.y, y));
	float g = max(dot(EYEDIR, normalize(glow_dir)), 0.0);
	c = mix(c, glow_color, pow(g, 8.0) * glow_amount + pow(g, 60.0) * 0.4);
	if (clouds > 0.0 && y > -0.1) {
		vec2 p = EYEDIR.xz / max(y + 0.3, 0.05) * 1.4 + vec2(mod(TIME, 2000.0) * 0.012, 0.0);
		float n = fbm(p);
		float m = smoothstep(0.42, 0.72, n) * clouds * smoothstep(-0.1, 0.15, y);
		vec3 cc = mix(cloud_color, glow_color * 0.5, pow(g, 6.0) * smoothstep(0.42, 0.55, n) * 0.6);
		c = mix(c, cc, m);
	}
	if (nebula > 0.0) {
		vec2 np = vec2(atan(EYEDIR.x, -EYEDIR.z), EYEDIR.y) * 2.2;
		float t2 = mod(TIME, 4000.0) * 0.004;
		float n1 = fbm(np + vec2(t2, 0.0));
		float n2 = fbm(np * 1.9 + vec2(4.1, -t2));
		float core = max(dot(EYEDIR, normalize(nebula_dir)), 0.0);
		float gas = smoothstep(0.38, 0.78, n1 + core * 0.35) * nebula;
		vec3 nc = mix(nebula_a, nebula_b, smoothstep(0.3, 0.8, n2 + core * 0.3));
		c = mix(c, nc, gas * 0.85);
		c += nebula_b * (pow(core, 20.0) * 0.45 + pow(core, 140.0) * 1.1) * nebula;
	}
	if (stars > 0.0) {
		vec2 sp = vec2(atan(EYEDIR.x, -EYEDIR.z), asin(clamp(EYEDIR.y, -1.0, 1.0)));
		float fade = smoothstep(-0.04, 0.12, EYEDIR.y);
		for (int layer = 0; layer < 2; layer++) {
			float k = layer == 0 ? 190.0 : 60.0;
			vec2 g = sp * k;
			vec2 cell = floor(g);
			vec2 f = fract(g) - 0.5;
			float h = hash(cell + float(layer) * 17.0);
			float on = step(1.0 - (layer == 0 ? 0.07 : 0.035) * stars, h);
			vec2 o = vec2(hash(cell + 1.7), hash(cell + 4.3)) - 0.5;
			float r = length(f - o * 0.6);
			float size = layer == 0 ? 0.1 + 0.1 * hash(cell + 9.1) : 0.07 + 0.05 * hash(cell + 9.1);
			float tw = 0.55 + 0.45 * sin(TIME * (1.0 + 3.0 * hash(cell + 2.2)) + h * 50.0);
			c += vec3(1.0, 0.96, 0.9) * on * (1.0 - smoothstep(size * 0.3, size, r)) * tw * fade
					* (layer == 0 ? 0.8 : 1.3);
		}
	}
	COLOR = c;
}
