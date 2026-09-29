shader_type spatial;
// Buildings: a wall, and every window on it, drawn from the face's own UVs so
// a whole skyline is one mesh and one draw call.
//
// From `tools/blender/city.py`, per face: UV is metres (across the face, and
// height above the street, which glTF's V flip turns into 1 - UV.y); UV2 is
// (share of windows lit, seed); vertex colour is (window width, how cold the
// light is, shopfront, wall brightness).
//
// A few windows change every so often, the way a city does at night: each
// window has its own clock, and on a small share of its ticks it flips.

render_mode unshaded;

uniform vec3 wall_lit : source_color = vec3(0.1, 0.13, 0.28);
uniform vec3 wall_shade : source_color = vec3(0.04, 0.05, 0.14);
uniform vec3 roof : source_color = vec3(0.03, 0.04, 0.1);
uniform vec3 warm_a : source_color = vec3(1.0, 0.84, 0.32);
uniform vec3 warm_b : source_color = vec3(1.0, 0.68, 0.26);
uniform vec3 cold : source_color = vec3(0.55, 0.78, 1.0);
uniform vec3 glass_low : source_color = vec3(0.03, 0.05, 0.14);
uniform vec3 glass_high : source_color = vec3(0.1, 0.15, 0.34);
uniform vec3 shop_light : source_color = vec3(1.0, 0.8, 0.5);
uniform vec3 light_dir = vec3(0.35, 0.75, 0.2);
uniform float floor_h = 3.5;
uniform float ground_h = 4.4;
uniform float change_every = 11.0;
uniform float change_share = 0.05;
uniform vec3 fog_color : source_color = vec3(0.06, 0.1, 0.3);
uniform float fog_near = 60.0;
uniform float fog_far = 520.0;
uniform float fog_max = 0.8;

varying vec3 wn;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 n = normalize(wn);
	float h = 1.0 - UV.y;
	float u = UV.x;
	float lit_share = UV2.x;
	float seed = UV2.y;
	vec3 c;
	float glow = 0.0;
	if (n.y > 0.5) {
		c = roof;
	} else {
		float ndl = dot(n, normalize(light_dir));
		vec3 wall = mix(wall_shade, wall_lit, smoothstep(-0.2, 0.3, ndl)) * mix(0.7, 1.0, COLOR.a);
		c = wall;
		// Narrow and tall, in rows, with the wall showing between: square
		// panes edge to edge read as a spreadsheet, not a building.
		float colw = mix(1.5, 2.5, COLOR.r);
		vec2 g = vec2(u / colw, (h - ground_h) / floor_h);
		vec2 cell = floor(g);
		vec2 lp = fract(g);
		float half_w = mix(0.2, 0.3, COLOR.r);
		float inwin = step(abs(lp.x - 0.5), half_w) * step(0.28, lp.y) * step(lp.y, 0.86)
				* step(ground_h, h);
		if (inwin > 0.5) {
			vec2 id = cell + vec2(seed * 131.0, seed * 71.0);
			bool on = hash(id) < lit_share;
			float epoch = floor(TIME / change_every + hash(id + 5.0) * 7.0);
			if (hash(id + epoch * 3.7) < change_share) {
				on = !on;
			}
			vec3 warm = mix(warm_a, warm_b, hash(id + 1.3));
			vec3 lc = mix(warm, cold, COLOR.g);
			// A room, not a panel: brighter toward the ceiling, and no two
			// rooms quite the same.
			lc *= (0.72 + 0.35 * lp.y) * (0.78 + 0.4 * hash(id + 9.1));
			vec3 dark = mix(glass_low, glass_high, lp.y * 0.8);
			c = on ? lc : dark;
			glow = on ? 1.0 : 0.0;
		}
		if (COLOR.b > 0.5 && h < ground_h - 0.1) {
			float mull = fract(u / 1.9);
			float pane = step(0.06, mull) * step(h, 3.4) * step(0.35, h);
			vec2 sid = vec2(floor(u / 7.0), seed * 53.0);
			bool open = hash(sid) < 0.8;
			vec3 shop = shop_light * (0.75 + 0.35 * hash(sid + 2.0)) * (0.8 + 0.25 * (1.0 - h / 3.4));
			c = pane > 0.5 ? (open ? shop : glass_high) : wall * 0.6;
			glow = pane > 0.5 && open ? 1.0 : 0.0;
		}
	}
	// Lit windows carry further through the haze than the walls around them.
	float f = smoothstep(fog_near, fog_far, length(VERTEX)) * fog_max * (1.0 - 0.45 * glow);
	ALBEDO = mix(c, fog_color, f);
}
