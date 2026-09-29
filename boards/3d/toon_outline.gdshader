shader_type spatial;
// Ink lines, as an inverted hull: the mesh again, back faces only, pushed out
// along its normals in screen space so the line is the same number of pixels
// wide at any distance. Distant things get a thinner line and fade into the
// haze with everything else, or the far islands turn into black scribbles.
//
// `sway` must match the toon pass on the same mesh, or the line and the
// leaves it outlines drift apart in the wind.

render_mode unshaded, cull_front;

uniform vec3 line_color : source_color = vec3(0.15, 0.15, 0.25);
// At a 1600 px tall frame; scaled with the frame.
uniform float width_px = 2.4;
uniform float sway = 0.0;
uniform vec3 fog_color : source_color = vec3(0.82, 0.92, 1.0);
uniform float fog_near = 30.0;
uniform float fog_far = 130.0;
uniform float fog_max = 0.7;

varying float v_dist;

void vertex() {
	if (sway > 0.0) {
		vec3 o = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		float h = max(VERTEX.y, 0.0);
		float ph = TIME * 1.4 + o.x * 0.9 + o.z * 0.6 + VERTEX.x * 0.8 + VERTEX.z * 0.8;
		VERTEX.x += sin(ph) * sway * h * h;
		VERTEX.z += cos(ph * 0.83) * sway * 0.6 * h * h;
	}
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	v_dist = length(view_pos.xyz);
	vec4 clip = PROJECTION_MATRIX * view_pos;
	vec3 vn = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	vec2 dir = (PROJECTION_MATRIX * vec4(vn, 0.0)).xy * VIEWPORT_SIZE;
	float len = length(dir);
	dir = len > 1e-5 ? dir / len : vec2(0.0);
	float w = width_px * (VIEWPORT_SIZE.y / 1600.0) * clamp(22.0 / clip.w, 0.35, 1.0);
	clip.xy += dir * w * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}

void fragment() {
	float f = smoothstep(fog_near, fog_far, v_dist) * fog_max;
	ALBEDO = mix(line_color, fog_color, f);
}
