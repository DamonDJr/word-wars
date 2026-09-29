shader_type spatial;
// Things that are their own light: neon, lamp bulbs, head and tail lights,
// lit doorways, the moon. One flat colour (the material's, times the vertex
// colour when `use_vc` is on) and no shading.
//
// Vertex alpha is a seed, so each sign in a merged mesh keeps its own
// rhythm: `flicker` is the buzz of a failing tube (dark for a beat, now and
// then), `blink` an on-off beacon at that many cycles a second.

render_mode unshaded, cull_disabled;

uniform vec3 color : source_color = vec3(1.0);
uniform float intensity = 1.0;
uniform float use_vc = 1.0;
uniform float flicker = 0.0;
uniform float blink = 0.0;
uniform vec3 fog_color : source_color = vec3(0.06, 0.1, 0.3);
uniform float fog_near = 60.0;
uniform float fog_far = 520.0;
uniform float fog_max = 0.5;

float hash(float x) {
	return fract(sin(x * 91.3458) * 47453.5453);
}

void fragment() {
	vec3 c = color * mix(vec3(1.0), COLOR.rgb, use_vc) * intensity;
	float s = COLOR.a;
	if (flicker > 0.0) {
		float q = floor(mod(TIME, 600.0) * 9.0 + s * 311.0);
		c *= 1.0 - flicker * step(0.965, hash(q + s * 17.0)) * 0.85;
	}
	if (blink > 0.0) {
		c *= mix(0.08, 1.0, step(0.72, fract(TIME * blink + s)));
	}
	float f = smoothstep(fog_near, fog_far, length(VERTEX)) * fog_max;
	ALBEDO = mix(c, fog_color, f);
}
