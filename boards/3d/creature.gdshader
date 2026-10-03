shader_type spatial;
// Fish, whales and rays swimming over a rendered board.
//
// Their bodies move here, from what `tools/blender/sealife.py` writes into
// each vertex: UV.x runs nose (0) to tail (1), UV.y across a wing (-1..1),
// COLOR.a is one animal's seed and COLOR.rgb its colour. Travel through the
// scene is the glTF's animation; this is only the swimming.
//
// The light is the plate's: from the surface straight down, cool, with the
// water's colour coming up from below and a bright edge where they catch
// it. Then the water in front of them, taken from the plate, and the plate's
// stone in front of that.

render_mode unshaded, cull_disabled, shadows_disabled;

#include "res://boards/3d/plate.gdshaderinc"

uniform vec3 base : source_color = vec3(1.0);
// 0 a fish's tail beat (side to side), 1 a whale's (up and down), 2 a ray's
// wings.
uniform int stroke = 0;
// How far the tail tip travels, in metres, and beats a second.
uniform float beat = 0.05;
uniform float rate = 2.4;
// A fish in a school wanders round its place in it by this much.
uniform float wander = 0.0;
uniform vec3 light_dir = vec3(0.05, 1.0, 0.25);
uniform vec3 light_color : source_color = vec3(0.85, 0.97, 1.0);
uniform vec3 under_color : source_color = vec3(0.05, 0.18, 0.32);
uniform float sheen = 0.5;
uniform float rim = 0.35;

void vertex() {
	float s = COLOR.a * 6.2832;
	float t = TIME * rate + s;
	float u = UV.x;
	if (stroke == 0) {
		// Side to side is local z after glTF's axes (Blender's y).
		VERTEX.z += sin(t - u * 3.0) * beat * u * u;
		VERTEX += vec3(sin(TIME * 0.31 + s * 3.0), sin(TIME * 0.47 + s * 5.0) * 0.6,
				sin(TIME * 0.23 + s * 7.0)) * wander;
	} else if (stroke == 1) {
		VERTEX.y += sin(t - u * 2.2) * beat * pow(u, 2.2);
	} else {
		VERTEX.y += sin(t - abs(UV.y) * 1.6) * beat * pow(abs(UV.y), 1.5);
		VERTEX.y += sin(t * 0.5 - u * 2.0) * beat * 0.2 * u * u;
	}
}

void fragment() {
	// Opaque, so the stone in front cuts it off rather than fading it.
	if (plate_cover(VERTEX, 0.6) < 0.5) {
		discard;
	}
	vec3 n = normalize(NORMAL);
	if (!FRONT_FACING) {
		n = -n;
	}
	vec3 l = normalize((VIEW_MATRIX * vec4(light_dir, 0.0)).xyz);
	float diff = clamp(dot(n, l) * 0.6 + 0.4, 0.0, 1.0);
	vec3 col = base * COLOR.rgb;
	vec3 c = mix(under_color * col * 2.0, light_color * col, diff);
	// Silver flanks flash as they turn; a bright edge against the murk.
	vec3 h = normalize(l + vec3(0.0, 0.0, 1.0));
	c += light_color * sheen * pow(max(dot(n, h), 0.0), 24.0);
	c += light_color * rim * pow(1.0 - abs(dot(n, vec3(0.0, 0.0, 1.0))), 3.0) * diff;
	vec4 haze = plate_haze(VERTEX);
	ALBEDO = mix(c, haze.rgb, haze.a);
}
