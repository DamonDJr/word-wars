shader_type spatial;
// A tiled wall: glazed tiles in a grid with dark grout between, each tile a
// touch different from its neighbours, and bands of coloured tiles at set
// heights (the red stripes of a subway station). Drawn from the wall's own
// UVs, so a whole station is one mesh.
//
// From `tools/blender/subway.py`: UV is metres (along the wall, and height,
// which glTF's V flip turns into 1 - UV.y). Vertex colour dims a wall.

// Two-sided: the walls face every which way and a tile has no back.
render_mode unshaded, cull_disabled;

uniform vec3 tile : source_color = vec3(0.86, 0.88, 0.92);
uniform vec3 band : source_color = vec3(0.78, 0.08, 0.1);
uniform vec3 grout : source_color = vec3(0.2, 0.22, 0.28);
uniform float size = 0.2;
// Two bands, as (bottom, top) heights in metres.
uniform vec4 bands = vec4(0.9, 1.05, 2.55, 2.95);
uniform vec3 light_dir = vec3(0.2, 0.8, 0.3);
uniform vec3 fog_color : source_color = vec3(0.02, 0.03, 0.06);
uniform float fog_near = 20.0;
uniform float fog_far = 200.0;
uniform float fog_max = 0.9;

varying vec3 wn;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	float h = 1.0 - UV.y;
	vec2 g = vec2(UV.x, h) / size;
	vec2 cell = floor(g);
	vec2 f = fract(g);
	bool in_band = (h > bands.x && h < bands.y) || (h > bands.z && h < bands.w);
	vec3 c = in_band ? band : tile;
	c *= 0.9 + 0.12 * hash(cell);
	// A little lighter across the top of each tile, where the glaze bulges.
	c *= 0.94 + 0.1 * smoothstep(0.2, 0.9, f.y);
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	c = mix(grout, c, smoothstep(0.02, 0.06, edge));
	float ndl = dot(normalize(wn), normalize(light_dir));
	c *= mix(0.72, 1.0, smoothstep(-0.3, 0.3, ndl)) * COLOR.rgb;
	float fo = smoothstep(fog_near, fog_far, length(VERTEX)) * fog_max;
	ALBEDO = mix(c, fog_color, fo);
}
