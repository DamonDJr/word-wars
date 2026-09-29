shader_type spatial;
// The cartoon look for everything solid in a 3D board: two flat tones split by
// a sharp terminator, a thin highlight band, a rim, and distance haze.
//
// Unshaded, with its own light direction, on purpose. There is one sun in
// these scenes and it never moves, so a real light buys nothing but cost, and
// real lighting in the Compatibility renderer is not where a phone wants to
// spend its time. The shadow tone is a colour, not a darkening, because a
// cool shadow on a warm rock is most of what makes it read as painted.

render_mode unshaded, cull_back;

uniform vec3 lit_color : source_color = vec3(1.0);
uniform vec3 shade_color : source_color = vec3(0.5, 0.55, 0.75);
uniform vec3 rim_color : source_color = vec3(1.0, 0.98, 0.9);
uniform float rim_amount = 0.22;
// Width of the terminator, in N.L. Near zero is ink-sharp; clouds want more.
uniform float band_soft = 0.025;
// Where the terminator sits. Positive pushes more of the form into shadow.
uniform float band_bias = 0.08;
uniform float highlight = 0.08;
// How much of the mesh's vertex colour comes through.
uniform float vc_strength = 1.0;
// Wind, as sideways travel per unit of height squared. Zero is still.
uniform float sway = 0.0;
uniform vec3 light_dir = vec3(-0.5, 0.75, 0.45);
uniform vec3 fog_color : source_color = vec3(0.82, 0.92, 1.0);
uniform float fog_near = 30.0;
uniform float fog_far = 130.0;
uniform float fog_max = 0.7;
// Light thrown up by lava. Two masks: height above the ground (for rock that
// simply stands in it) and vertex alpha, 1 for none and 0 for full (painted
// in Blender where rock meets a flow or a crack). Both flicker a little.
uniform vec3 glow_color : source_color = vec3(1.0, 0.42, 0.1);
uniform float glow_amount = 0.0;
uniform float glow_height = 1.0;
uniform float glow_vc = 0.0;
uniform float glow_max = 0.9;

varying vec3 w_normal;
varying vec3 w_pos;

void vertex() {
	if (sway > 0.0) {
		vec3 o = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		float h = max(VERTEX.y, 0.0);
		float ph = TIME * 1.4 + o.x * 0.9 + o.z * 0.6 + VERTEX.x * 0.8 + VERTEX.z * 0.8;
		VERTEX.x += sin(ph) * sway * h * h;
		VERTEX.z += cos(ph * 0.83) * sway * 0.6 * h * h;
	}
	w_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(w_normal);
	float ndl = dot(n, normalize(light_dir));
	float lit = smoothstep(band_bias - band_soft, band_bias + band_soft, ndl);
	float hi = smoothstep(0.72 - band_soft, 0.72 + band_soft, ndl);
	vec3 c = mix(shade_color, lit_color, lit);
	c += lit_color * highlight * hi;
	c *= mix(vec3(1.0), COLOR.rgb, vc_strength);
	float fres = 1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0);
	float rim = smoothstep(0.6, 0.68, fres) * rim_amount;
	c = mix(c, rim_color, rim);
	if (glow_amount > 0.0 || glow_vc > 0.0) {
		float flick = 0.88 + 0.12 * sin(TIME * 2.3 + w_pos.x * 0.35 + w_pos.z * 0.2);
		float up = (1.0 - smoothstep(0.0, glow_height, w_pos.y)) * glow_amount
				* (1.0 - 0.6 * max(n.y, 0.0));
		float g = clamp((up + (1.0 - COLOR.a) * glow_vc) * flick, 0.0, glow_max);
		c = mix(c, glow_color, g);
	}
	// The distance is taken per fragment: interpolated from the vertices it is
	// wrong across a big triangle, and the lava plane is two of them.
	float f = smoothstep(fog_near, fog_far, length(VERTEX)) * fog_max;
	ALBEDO = mix(c, fog_color, f);
}
