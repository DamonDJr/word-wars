shader_type spatial;
// The rendered scene, on a quad that hangs behind everything at the far end
// of the camera, sized so the plate's frame fills the view exactly.
//
// Over it, sunlight rippling on whatever the plate shows close enough to
// catch it: the plate's depth puts each pixel back where it was in the world,
// so the ripples lie on the stone instead of sliding over the screen.

render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

#include "res://boards/3d/plate.gdshaderinc"

uniform float caustics = 0.0;
uniform vec3 caustic_color : source_color = vec3(0.7, 0.95, 1.0);
// Ripples fade out between these depths.
uniform vec2 caustic_range = vec2(6.0, 70.0);
uniform float caustic_scale = 0.55;

// Thin bright lines where two slowly moving wave fields cross, and nothing
// in between: what sunlight through a rippled surface lays on the bottom.
// Mostly zero on purpose, so it adds sparkle rather than a wash.
float ripples(vec2 p, float t) {
	float a = sin(p.x * 1.31 + sin(p.y * 0.87 + t * 0.9) * 1.4 + t * 0.35);
	float b = sin(p.y * 1.17 + sin(p.x * 1.03 - t * 0.7) * 1.4 - t * 0.28);
	float c = sin((p.x + p.y) * 0.71 + sin(p.x * 0.6 - p.y * 0.5 + t * 0.5) - t * 0.2);
	float l1 = max(0.0, 1.0 - abs(a - b) * 2.8);
	float l2 = max(0.0, 1.0 - abs(b - c) * 2.8);
	return pow(l1, 6.0) + pow(l2, 6.0) * 0.7;
}

void fragment() {
	vec3 c = texture(plate_tex, UV).rgb;
	if (caustics > 0.0) {
		float d = textureLod(plate_depth, UV, 0.0).r;
		if (d > 0.0 && d < caustic_range.y) {
			vec2 t = vec2((UV.x * 2.0 - 1.0) * frame.x, (1.0 - UV.y * 2.0) * frame.y);
			vec3 world = (INV_VIEW_MATRIX * vec4(t * d, -d, 1.0)).xyz;
			float k = ripples(world.xz * caustic_scale + world.y * 0.15, TIME);
			// Light lands on lit stone, not in the shadows between it.
			float lum = dot(c, vec3(0.3, 0.55, 0.15));
			float fade = smoothstep(caustic_range.x * 0.5, caustic_range.x, d)
					* (1.0 - smoothstep(caustic_range.x, caustic_range.y, d));
			c += caustic_color * k * caustics * smoothstep(0.08, 0.45, lum) * fade;
		}
	}
	ALBEDO = c;
}
