shader_type spatial;
// A piece of the plate that moves in place: cut out of the render with the
// thing in it, laid over the plate rendered without it, and warped. The
// warp moves the cut-out's own pixels, so what shows round the edges as it
// moves is the plate's real background, never a hole.
//
// Coordinates are the layer's own pixels (`size` across and down), so a
// direction means the same thing whatever shape the layer is.

render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D tex : source_color, filter_linear, repeat_disable;
uniform vec2 size = vec2(256.0, 256.0);
// 0 still, 1 kelp (sways from the bottom), 2 the merman.
uniform int mode = 0;
uniform float speed = 1.0;
uniform float amount = 1.0;
// The merman: hip, where the tail meets the fin, the shoulder and hand of
// the reaching arm, all in layer pixels.
uniform vec2 hip;
uniform vec2 fin;
uniform vec2 shoulder;
uniform vec2 hand;

vec2 perp(vec2 v) {
	return vec2(-v.y, v.x);
}

vec2 warp(vec2 p) {
	float t = TIME * speed;
	if (mode == 1) {
		// Height above the bottom of the layer, squared: the holdfasts stay
		// put and the tips travel. Two waves so it never looks mechanical.
		float h = 1.0 - p.y / size.y;
		float s = h * h;
		return vec2(sin(t * 0.8 + p.x * 0.012) * 0.6 + sin(t * 1.9 + p.y * 0.02) * 0.25, 0.0)
				* s * size.x * 0.035 * amount;
	}
	if (mode == 2) {
		vec2 d = vec2(0.0, sin(t * 0.9) * size.y * 0.006);
		// The tail beats: a wave running from the hips out through the fin,
		// growing as it goes.
		vec2 axis = fin - hip;
		float len = length(axis);
		vec2 a = axis / len;
		float s = dot(p - hip, a) / len;
		if (s > 0.0) {
			float grow = clamp(s, 0.0, 1.6);
			d += perp(a) * sin(6.2832 * (s * 0.45) - t * 1.7) * grow * grow * len * 0.05 * amount;
		}
		// The reaching hand drifts, as a hand held up in water does.
		vec2 arm = hand - shoulder;
		float u = clamp(dot(p - shoulder, arm) / dot(arm, arm), 0.0, 1.0);
		float near = 1.0 - smoothstep(0.0, length(arm) * 0.25, length(p - (shoulder + arm * u)));
		d += perp(normalize(arm)) * sin(t * 1.1 + 0.8) * u * u * near * length(arm) * 0.05 * amount;
		return d;
	}
	return vec2(0.0);
}

void fragment() {
	vec2 p = UV * size;
	vec4 c = texture(tex, (p - warp(p)) / size);
	if (c.a < 0.01) {
		discard;
	}
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
