shader_type spatial;
// Falling rain: a quad in front of the camera covered in thin streaks that
// fall down it, each column at its own speed. Three of these at different
// depths (`board3d.gd` makes them) give near drops that are big and fast and
// far ones that are fine and slow.

render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 color : source_color = vec3(0.55, 0.68, 1.0);
uniform float density = 0.35;
uniform float speed = 2.0;
uniform float columns = 60.0;
uniform float rows = 3.0;
uniform float drop_len = 0.3;
uniform float strength = 0.3;
uniform float slant = 0.06;
// Snow instead of rain: round flakes that wander as they fall.
uniform float flakes = 0.0;
uniform float flake_size = 0.16;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	uv.x += uv.y * slant;
	float t = mod(TIME, 600.0);
	float cx = floor(uv.x * columns);
	float r1 = hash(vec2(cx, 1.0));
	float r2 = hash(vec2(cx, 2.0));
	float y = uv.y * rows - t * speed * (0.75 + 0.5 * r1) + r2 * 10.0;
	float cell = floor(y);
	float f = fract(y);
	float on = step(1.0 - density, hash(vec2(cx, cell)));
	if (flakes > 0.5) {
		float fx = fract(uv.x * columns) - 0.5 + (hash(vec2(cx, cell * 1.3)) - 0.5) * 0.5
				+ sin(t * 1.1 + cell * 2.1 + cx) * 0.22;
		float fy = f - 0.5;
		// Round in the quad's own proportions (2.6 times as tall as wide).
		float d = length(vec2(fx, fy * 2.6 * columns / rows));
		float sz = flake_size * (0.6 + 0.8 * hash(vec2(cell, cx)));
		ALBEDO = color * on * (1.0 - smoothstep(sz * 0.5, sz, d)) * strength;
	} else {
		float xw = 1.0 - smoothstep(0.05, 0.3, abs(fract(uv.x * columns) - 0.5));
		float streak = smoothstep(0.0, 0.04, f) * (1.0 - smoothstep(0.04, drop_len, f));
		ALBEDO = color * on * xw * streak * strength;
	}
}
