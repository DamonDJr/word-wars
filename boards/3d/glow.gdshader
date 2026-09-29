shader_type spatial;
// Halos, added over whatever is behind them: around lamps and headlights (as
// billboards, turned to face the camera) and pooled on the road under the
// lamps (flat, `billboard` 0).
//
// A billboard quad comes from `tools/blender/vehicles.py:glow_quads`: built
// flat in its local XZ (Blender), which is XY here, with UV marking the
// corner and UV2.x the size. From a corner and the size the vertex finds the
// quad's centre and opens the quad around it, facing the camera. Object
// scale carries through, so a car shrunk to nothing takes its lamps with it.

render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 color : source_color = vec3(1.0);
uniform float intensity = 0.6;
uniform float billboard = 1.0;
uniform float falloff = 2.2;
uniform float fog_near = 60.0;
uniform float fog_far = 520.0;
uniform float fog_max = 0.6;

varying float v_dist;

void vertex() {
	if (billboard > 0.5) {
		float s = UV2.x;
		vec2 corner = vec2(UV.x - 0.5, (1.0 - UV.y) - 0.5);
		vec3 centre = VERTEX - vec3(corner * s, 0.0);
		vec4 vc = MODELVIEW_MATRIX * vec4(centre, 1.0);
		vc.xy += corner * s * length(MODEL_MATRIX[0].xyz);
		POSITION = PROJECTION_MATRIX * vc;
		v_dist = length(vc.xyz);
	} else {
		v_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	}
}

void fragment() {
	float r = length((UV - 0.5) * 2.0);
	float a = pow(max(0.0, 1.0 - r), falloff);
	vec3 c = color * COLOR.rgb * intensity * a;
	ALBEDO = c * (1.0 - smoothstep(fog_near, fog_far, v_dist) * fog_max);
}
