shader_type spatial;
// Jellyfish over a rendered board.
//
// The bell is glass: almost clear where it faces you and bright along its
// edge, where the light crosses the most of it, with the thicker margin and
// faint canals in it, and through it the inside of the bell with the four
// gonads and the rings of muscle that swim it. It beats the way a jellyfish
// does, snapping shut and easing open, and the whole animal lifts on each
// stroke. The tentacles and frilled oral arms trail behind each stroke and
// drift in curls of their own.
//
// Premultiplied alpha, so it can both dim the water behind it a little and
// glow over it: ALBEDO is what it adds, ALPHA how much of the water it hides.
//
// What each vertex carries is listed in `tools/blender/sealife.py`
// (`jellyfish`): UV.x along the part, UV.y which part, UV2.x a random per
// strand, UV2.y the bell's radius, COLOR.r across an oral arm, COLOR.a the
// animal's seed.

render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, shadows_disabled;

#include "res://boards/3d/plate.gdshaderinc"

uniform vec3 body : source_color = vec3(0.78, 0.74, 1.0);
uniform vec3 rim_color : source_color = vec3(0.86, 0.97, 1.0);
uniform vec3 gonad : source_color = vec3(1.0, 0.52, 0.82);
uniform vec3 arm_color : source_color = vec3(1.0, 0.62, 0.86);
uniform vec3 thread : source_color = vec3(0.9, 0.86, 1.0);
uniform float intensity = 1.0;
// Strokes a second.
uniform float rate = 0.5;

// The animal's own coordinates, before it moves, for the patterns in it.
varying vec3 local;
varying float squeeze;

// How far through a stroke the bell is, 0 open to 1 shut: it snaps shut in
// the first fifth of a beat and eases open over the rest.
float stroke(float ph) {
	ph = fract(ph);
	return ph < 0.2 ? smoothstep(0.0, 0.2, ph) : 1.0 - smoothstep(0.2, 1.0, ph);
}

vec2 turn(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

void vertex() {
	local = VERTEX;
	float part = UV.y;
	float u = UV.x;
	float rnd = UV2.x * 6.2832;
	float r = UV2.y;
	float t = TIME * rate + COLOR.a * 7.0;
	float c = stroke(t);
	squeeze = c;
	float lift = 0.14 * r * stroke(t - 0.08);
	if (part < 0.5 || part > 2.5) {
		// The margin pulls in hardest and the crown hardly at all, and the
		// bell stands taller while it is shut.
		VERTEX.xz *= 1.0 - 0.24 * c * u * u;
		VERTEX.y *= 1.0 + 0.14 * c;
		VERTEX.y += lift;
	} else {
		// The stroke runs down a strand behind the bell, so each point
		// follows the margin a little later than the one above it.
		float lag = stroke(t - u * 0.7);
		float k = part < 1.5 ? 1.0 - 0.7 * u : 0.5 * (1.0 - u);
		VERTEX.xz *= 1.0 - 0.24 * lag * k;
		float w = r * u * u;
		float sway = part < 1.5 ? 0.3 : 0.16;
		VERTEX.x += sin(TIME * 0.8 + rnd - u * 5.0) * w * sway;
		VERTEX.z += cos(TIME * 0.6 + rnd * 1.3 - u * 4.0) * w * sway;
		// The tips are dragged: they rise less than the bell, so a strand
		// stretches on the stroke and slackens after.
		VERTEX.y += lift * (1.0 - u);
		if (part > 1.5) {
			// The arms twist slowly about the bell's axis, and their frilled
			// edges flutter.
			VERTEX.xz = turn(VERTEX.xz, 0.3 * sin(TIME * 0.35 + rnd) * u);
			vec2 out_dir = normalize(local.xz + vec2(0.0001));
			vec2 along_rim = vec2(-out_dir.y, out_dir.x);
			VERTEX.xz += along_rim * COLOR.r * COLOR.r * sin(u * 30.0 - TIME * 1.8 + rnd) * 0.06 * r;
		}
	}
}

void fragment() {
	float part = UV.y;
	float u = UV.x;
	float r = max(UV2.y, 0.001);
	vec3 n = normalize(NORMAL);
	float edge = 1.0 - abs(dot(n, normalize(-VERTEX)));
	float ang = atan(local.z, local.x);
	float a;
	vec3 c;
	if (part < 0.5) {
		float canals = pow(abs(cos(ang * 8.0)), 60.0) * smoothstep(0.15, 0.45, u);
		float margin = smoothstep(0.84, 0.97, u);
		// The sense organs: bright specks in the notches of the margin.
		float specks = pow(abs(sin(ang * 8.0)), 80.0) * smoothstep(0.93, 1.0, u);
		a = 0.035 + 0.5 * pow(edge, 3.0) + 0.22 * margin + 0.08 * canals + 0.6 * specks;
		c = mix(body, rim_color, clamp(edge * 1.2 + margin, 0.0, 1.0)) * (1.0 + 0.5 * margin + specks);
	} else if (part > 2.5) {
		// Four horseshoes round the middle, each open to the outside, and
		// rings of muscle toward the margin.
		vec2 p = local.xz / r;
		float g = 0.0;
		for (int i = 0; i < 4; i++) {
			float ga = 0.7854 + 1.5708 * float(i);
			vec2 cc = vec2(cos(ga), sin(ga)) * 0.33;
			vec2 d = p - cc;
			float ring = 1.0 - smoothstep(0.035, 0.07, abs(length(d) - 0.15));
			float closed = smoothstep(-0.75, -0.35, -dot(normalize(d + vec2(0.0001)), normalize(cc)));
			g = max(g, ring * closed);
		}
		float muscle = (0.5 + 0.5 * sin(u * 80.0)) * smoothstep(0.55, 0.9, u);
		a = 0.03 + 0.45 * g + 0.05 * muscle + 0.2 * pow(edge, 3.0);
		c = mix(body, gonad, g);
	} else if (part < 1.5) {
		a = 0.5 * (1.0 - 0.8 * u);
		c = thread * (1.3 - 0.6 * u);
	} else {
		// Mostly clear, the frilled edge catching the light; four of them
		// overlap down the middle, so each keeps to a little.
		float across = COLOR.r;
		a = (0.035 + 0.24 * across * across + 0.16 * pow(edge, 2.0)) * (1.0 - 0.6 * u);
		c = arm_color * (0.75 + 0.6 * across);
	}
	// A touch brighter while the bell is shut.
	c *= 1.0 + 0.2 * squeeze;
	vec4 haze = plate_haze(VERTEX);
	float keep = plate_cover(VERTEX, 1.0) * (1.0 - haze.a * 0.85);
	a = clamp(a, 0.0, 1.0);
	ALBEDO = c * a * intensity * keep;
	ALPHA = a * keep * 0.7;
}
