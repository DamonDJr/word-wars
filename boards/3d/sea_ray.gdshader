shader_type spatial;
// Shafts of light over a rendered board, shimmering over the ones the render
// already has, and hidden by the plate's stone where it stands in front.
// The same quads as `ray.gdshader`: UV.x across the shaft, UV2.x along it
// from the top (0) to the end (1), vertex colour the light, its alpha a seed.

render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://boards/3d/plate.gdshaderinc"

uniform float intensity = 0.1;

void fragment() {
	float along = UV2.x;
	float across = abs(UV.x - 0.5) * 2.0;
	float a = (1.0 - smoothstep(0.2, 1.0, across)) * pow(1.0 - along, 1.4) * smoothstep(0.0, 0.1, along);
	// Each shaft breathes on its own, and a slow ripple runs down it.
	float s = COLOR.a * 40.0;
	a *= 0.55 + 0.45 * sin(TIME * 0.5 + s) * sin(TIME * 0.23 + s * 1.7);
	a *= 0.8 + 0.2 * sin(along * 12.0 - TIME * 1.2 + s);
	ALBEDO = COLOR.rgb * a * intensity * plate_cover(VERTEX, 2.0);
}
