// What every live thing on a rendered (plate) board shares: where it falls
// on the plate, whether the plate's stone is in front of it, and the water
// between it and the camera.
//
// The plate is the scene rendered in Blender (tools/blender/realkit.py);
// `plate_depth` is that render's camera depth in metres, 0 where it saw only
// water. `frame` is the plate's half-extent as tangents: x across, y up.

uniform sampler2D plate_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D plate_depth : filter_nearest, repeat_disable;
uniform vec2 frame = vec2(0.4, 0.76);
// How fast the water swallows things, per metre, and how far down the
// plate's mipmaps to read the colour it swallows them into.
uniform float murk = 0.016;
uniform float haze_lod = 5.0;

// A view-space point -> its place on the plate (0,0 top left).
vec2 plate_uv(vec3 view) {
	float z = max(-view.z, 0.001);
	return vec2(0.5 + 0.5 * view.x / (z * frame.x), 0.5 - 0.5 * view.y / (z * frame.y));
}

// How much of a point at view-space `view` is visible past the plate's
// stone: 1 in front, 0 behind, soft across `soft` metres.
float plate_cover(vec3 view, float soft) {
	float d = textureLod(plate_depth, plate_uv(view), 0.0).r;
	if (d <= 0.0) {
		return 1.0;
	}
	return 1.0 - smoothstep(d - soft, d + soft, -view.z);
}

// The colour of the water in front of `view`, read from the plate itself
// (blurred), and how much of it there is.
vec4 plate_haze(vec3 view) {
	vec3 water = textureLod(plate_tex, plate_uv(view), haze_lod).rgb;
	return vec4(water, 1.0 - exp(-murk * -view.z));
}
