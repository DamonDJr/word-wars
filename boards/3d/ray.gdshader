shader_type spatial;
// Shafts of light: sun through leaves, daylight down through water. Added
// over the scene, brightest where the shaft begins and fading along it and
// toward its edges, with a slow shimmer so the light seems to move.
//
// From `toonkit.ray_quads`: UV.x runs across the shaft, UV2.x along it from
// its source (0) to its end (1). Vertex colour is the light's colour, its
// alpha a seed for the shimmer.

render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float intensity = 0.22;
uniform float shimmer = 1.0;
uniform float fog_near = 60.0;
uniform float fog_far = 400.0;
uniform float fog_max = 0.5;

void fragment() {
	float along = UV2.x;
	float across = abs(UV.x - 0.5) * 2.0;
	float a = (1.0 - smoothstep(0.25, 1.0, across)) * pow(1.0 - along, 1.3)
			* smoothstep(0.0, 0.06, along);
	a *= 1.0 - shimmer * 0.35 * (0.5 + 0.5 * sin(TIME * 0.6 + COLOR.a * 25.0 + UV.x * 2.0));
	ALBEDO = COLOR.rgb * a * intensity * (1.0 - smoothstep(fog_near, fog_far, length(VERTEX)) * fog_max);
}
