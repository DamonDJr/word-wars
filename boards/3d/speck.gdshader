shader_type spatial;
// Bubbles and drifting specks over a rendered board: soft round particles,
// added to the light, hidden by the plate's stone and lost in the water with
// distance. Particle colour is the tint, its alpha the strength.

render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://boards/3d/plate.gdshaderinc"

// 0 a speck (a soft dot), 1 a bubble (a bright rim and a highlight).
uniform int kind = 0;

void vertex() {
	// Face the camera.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2],
			MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float a;
	if (kind == 1) {
		a = smoothstep(1.0, 0.85, r) * (0.25 + 0.75 * smoothstep(0.5, 0.95, r));
		a += 0.8 * (1.0 - smoothstep(0.0, 0.18, length(UV - vec2(0.36, 0.34))));
	} else {
		a = pow(max(1.0 - r, 0.0), 2.0);
	}
	vec4 haze = plate_haze(VERTEX);
	ALBEDO = COLOR.rgb * COLOR.a * a * plate_cover(VERTEX, 0.5) * (1.0 - haze.a);
}
