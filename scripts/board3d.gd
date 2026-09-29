extends Node3D
## A board backdrop that is a 3D scene rather than a picture.
##
## Loads a glTF built in Blender (see `tools/blender/`), swaps every material
## in it for the toon shaders in `boards/3d/` by material name, adds the sky,
## and plays the scene's one animation on a loop. `game.gd` puts this in a
## SubViewport and draws that viewport's texture where the painted picture
## would go, so the wash, the dim and the crop all treat it the same.
##
## Clouds, Volcano and Cyber use it; `godot -- --board2d` turns it off.

const TOON := preload("res://boards/3d/toon.gdshader")
const OUTLINE := preload("res://boards/3d/toon_outline.gdshader")
const WATER := preload("res://boards/3d/waterfall.gdshader")
const LAVA := preload("res://boards/3d/lava.gdshader")
const SKY := preload("res://boards/3d/sky.gdshader")
const BUILDING := preload("res://boards/3d/building.gdshader")
const ROAD := preload("res://boards/3d/road.gdshader")
const EMISSIVE := preload("res://boards/3d/emissive.gdshader")
const GLOW := preload("res://boards/3d/glow.gdshader")
const CONE := preload("res://boards/3d/lightcone.gdshader")
const RAIN := preload("res://boards/3d/rain.gdshader")

## The render layer for things only the main camera should see (the rain,
## which hangs in front of it). The reflection camera leaves it out.
const LAYER_EYE_ONLY := 1 << 19
const RAY := preload("res://boards/3d/ray.gdshader")
const AURORA := preload("res://boards/3d/aurora.gdshader")
const TILES := preload("res://boards/3d/tiles.gdshader")

## Which shader a look asks for, by the flag it sets. A look with none of
## these is something solid, and gets the toon shader.
const KINDS := {
	"water": WATER, "building": BUILDING, "road": ROAD, "emissive": EMISSIVE,
	"glow": GLOW, "cone": CONE, "lava": LAVA, "ray": RAY, "aurora": AURORA,
	"tiles": TILES,
}
## Keys in a look that describe the look rather than naming a uniform.
const META := ["flat", "shade", "line", "width", "soft", "bias", "rim", "rim_color",
	"light", "fog_max", "eye_only"]

## The frame the scenes are composed in, in Blender (1080x1920). The camera
## keeps this frame's width on every screen, so what is at the sides stays in
## view and a taller phone gets more sky and ground instead of less scene.
const DESIGN_ASPECT := 1080.0 / 1920.0

## Each scene's sun, haze and sky, and the look of each of its materials,
## keyed by the glTF's file name.
##
## `light` is where the sun is, in Godot's axes (x right, y up, z toward the
## camera). The lit tone of a material comes from the glTF, so recolouring it
## in Blender carries through; a material missing from `look` gets a shadow
## and a line derived from that lit colour. `motion` keeps the painted board's
## own 2D effect drawn over the scene.
const SCENES := {
	"sky_islands": {
		"light": Vector3(-0.5, 0.75, 0.45),
		"fog": "#cfe6ff", "fog_near": 30.0, "fog_far": 130.0, "fog_max": 0.7,
		"sky": {},
		"look": {
			"Grass": {"shade": "#3f9a6a", "line": "#24503c"},
			"Rock": {"shade": "#a26f82", "line": "#4a2d48"},
			"Leaves": {"shade": "#2f8a5e", "line": "#1b4a36", "sway": 0.03},
			"Pine": {"shade": "#1f6a5c", "line": "#113c34", "sway": 0.03},
			"Trunk": {"shade": "#5e3b4a", "line": "#382230", "sway": 0.03},
			"Cloud": {"shade": "#b4c3f2", "line": "#93a8e0", "soft": 0.09,
				"bias": 0.0, "rim": 0.0, "width": 1.6, "highlight": 0.0},
			"Foam": {"shade": "#cfe6ff", "line": "#8fb4dc", "width": 1.2},
			"Pebble": {"shade": "#7b7599", "line": "#443d5e"},
			"Flower": {"shade": "#e0b4cf", "width": 0.0, "highlight": 0.0},
			"Bird": {"flat": true, "fog_max": 0.35},
			"Water": {"water": true, "speed": 1.5},
			"Stream": {"water": true, "speed": 0.6, "fade": 0.0},
		},
	},
	"volcano": {
		# From the right, so the cone and the spires have a lit side and a dark
		# one; the lava's own light comes up from below through the glow
		# masks, and the rim is the sky behind glowing through.
		"light": Vector3(0.75, 0.5, 0.4),
		"fog": "#581a10", "fog_near": 45.0, "fog_far": 190.0, "fog_max": 0.6,
		"motion": true,
		"sky": {
			"top_color": Color("#0b0203"), "mid_color": Color("#2e0907"),
			"horizon_color": Color("#a8321a"), "glow_dir": Vector3(0.02, 0.32, -1.0),
			"glow_color": Color("#ff8a3c"), "glow_amount": 0.22,
			"mid_at": Vector2(-0.02, 0.12), "top_at": Vector2(0.12, 0.4),
		},
		"look": {
			"Basalt": {"shade": "#14080e", "line": "#080305", "width": 1.3,
				"rim": 0.18, "rim_color": "#ff7a3a", "glow_vc": 1.0, "glow_max": 0.95},
			"Cone": {"shade": "#190a11", "line": "#0a0406", "rim": 0.3,
				"rim_color": "#ff8a4a", "glow_vc": 0.9, "glow_amount": 0.6,
				"glow_height": 3.0},
			"Spire": {"shade": "#160910", "line": "#080305", "rim": 0.36,
				"rim_color": "#ff7a3a", "glow_vc": 1.0, "glow_amount": 0.8,
				"glow_height": 2.5},
			"Ridge": {"shade": "#240c0e", "width": 0.0, "rim": 0.0, "highlight": 0.0},
			"Smoke": {"light": Vector3(0.15, -1.0, 0.35), "shade": "#2a1a1e",
				"line": "#120a0e", "soft": 0.15, "bias": 0.25, "rim": 0.0,
				"highlight": 0.0, "width": 1.5, "fog_max": 0.35},
			"Ash": {"light": Vector3(0.0, -1.0, 0.2), "shade": "#1a0e12",
				"soft": 0.18, "bias": 0.4, "rim": 0.0, "highlight": 0.0,
				"width": 0.0, "fog_max": 0.3},
			"Lava": {"lava": true, "crust_amount": 0.35, "speed": 0.25, "scale": 0.28},
			"LavaFlow": {"lava": true, "use_uv": 1.0, "crust_amount": 0.2,
				"speed": 0.5, "scale": 0.5},
			"CraterLava": {"lava": true, "crust_amount": 0.05, "speed": 0.4,
				"scale": 0.6, "flow": Vector2(0.3, 0.2)},
			"Burst": {"flat": true, "fog_max": 0.1},
			"Bomb": {"flat": true, "line": "#5a140a", "width": 1.6, "fog_max": 0.1},
		},
	},
	"forest": {
		"light": Vector3(-0.5, 0.75, 0.45),
		"fog": "#c4dcee", "fog_near": 40.0, "fog_far": 320.0, "fog_max": 0.72,
		# The painted board's falling leaves still drift over it.
		"motion": true,
		"sky": {
			"top_color": Color("#3f86dc"), "mid_color": Color("#86c0f0"),
			"horizon_color": Color("#dcefff"), "glow_dir": Vector3(-0.5, 0.5, -0.7),
			"glow_color": Color("#fff4d8"), "glow_amount": 0.3,
			"mid_at": Vector2(-0.2, 0.15), "top_at": Vector2(0.15, 0.6),
		},
		"look": {
			# Terrain gets its colour from its vertices (grass, sand, bare
			# rock by slope); no ink, or every hill wears a line round it.
			"Ground": {"shade": "#5c6f9a", "width": 0.0, "rim": 0.0, "highlight": 0.04,
				"bias": 0.0},
			"Stone": {"shade": "#5d5a78", "line": "#2e2c3c"},
			"Mountain": {"shade": "#5a74a8", "width": 0.0, "rim": 0.0, "highlight": 0.0},
			"River": {"lava": true, "crust": "#1b6a86", "cool": "#2d9fb6", "warm": "#63d0d6",
				"hot": "#e6fbff", "crust_amount": 0.1, "speed": 0.5, "scale": 0.3,
				"flow": Vector2(0.0, 1.0), "pulse": 0.02},
			"Mist": {"shade": "#c8d8f0", "soft": 0.12, "bias": 0.0, "rim": 0.0,
				"width": 0.0, "highlight": 0.0},
			"Shaft": {"ray": true, "intensity": 0.16},
			"Leaves": {"shade": "#2f8a5e", "line": "#1b4a36", "sway": 0.02, "sway_alpha": 1.0},
			"Pine": {"shade": "#1f6a5c", "line": "#113c34", "sway": 0.012, "sway_alpha": 1.0},
			"Trunk": {"shade": "#5e3b4a", "line": "#382230", "sway": 0.012, "sway_alpha": 1.0},
			"Flower": {"shade": "#e0b4cf", "width": 0.0, "highlight": 0.0},
			"Cloud": {"shade": "#b4c3f2", "line": "#93a8e0", "soft": 0.09,
				"bias": 0.0, "rim": 0.0, "width": 1.4, "highlight": 0.0},
			"Bird": {"flat": true, "fog_max": 0.35},
			"Water": {"water": true, "speed": 1.6},
		},
	},
	"aurora": {
		# Moonlight from high on the right; the snow facing the camera takes it.
		"light": Vector3(0.35, 0.7, 0.4),
		"fog": "#15294e", "fog_near": 80.0, "fog_far": 700.0, "fog_max": 0.5,
		# The lake mirrors the sky, the peaks and the lights.
		"reflection": 0.5,
		"rain": "snow",
		"sky": {
			"top_color": Color("#040a22"), "mid_color": Color("#0b1c46"),
			"horizon_color": Color("#1d3d6c"), "glow_dir": Vector3(0.0, 0.25, -1.0),
			"glow_color": Color("#2aa88f"), "glow_amount": 0.22,
			"mid_at": Vector2(-0.05, 0.12), "top_at": Vector2(0.12, 0.55), "stars": 1.0,
		},
		"look": {
			"Snow": {"shade": "#7486c4", "width": 0.0, "rim": 0.0, "highlight": 0.04,
				"bias": -0.1},
			"Lake": {"road": true, "markings": 0.0, "ripples": 0.0, "streak": 0.45,
				"reflect_amount": 0.95, "base_a": "#061428", "base_b": "#0c2242"},
			"SnowPine": {"shade": "#4a5a96", "line": "#0c1a24", "width": 1.3, "rim": 0.2,
				"rim_color": "#9fe8d8"},
			"Trunk": {"shade": "#2a1e26", "width": 0.0},
			"Peak": {"shade": "#5a6aa8", "width": 0.0, "rim": 0.25, "rim_color": "#8ff0d0",
				"highlight": 0.05},
			"Aurora": {"aurora": true},
			"Cabin": {"shade": "#2e2030", "line": "#120a10", "width": 1.3},
			"Roof": {"shade": "#7486c4", "line": "#1c2440", "width": 1.3},
			"Window": {"emissive": true, "use_vc": 0.0, "intensity": 1.2},
			"Smoke": {"shade": "#5e6a90", "soft": 0.12, "bias": 0.0, "rim": 0.0,
				"width": 0.0, "highlight": 0.0},
			"Meteor": {"emissive": true, "use_vc": 0.0, "intensity": 1.4, "fog_max": 0.0},
			"Glow": {"glow": true, "intensity": 0.45},
		},
	},
	"desert": {
		# A low sun from the right: faces toward it glow, the rest stand
		# dark and warm against the sky.
		"light": Vector3(0.75, 0.4, -0.3),
		"fog": "#e8905a", "fog_near": 60.0, "fog_far": 560.0, "fog_max": 0.62,
		# The painted board's heat haze still shimmers over it.
		"motion": true,
		"sky": {
			"top_color": Color("#3b2a6e"), "mid_color": Color("#e8783c"),
			"horizon_color": Color("#ffd27a"), "glow_dir": Vector3(0.1, 0.1, -1.0),
			"glow_color": Color("#ffcf70"), "glow_amount": 0.45,
			"mid_at": Vector2(-0.05, 0.12), "top_at": Vector2(0.15, 0.6),
		},
		"look": {
			"Sand": {"shade": "#b0605a", "width": 0.0, "rim": 0.0, "highlight": 0.05,
				"bias": 0.0},
			"Mesa": {"shade": "#6a2e44", "line": "#2a0e18", "width": 1.4, "rim": 0.3,
				"rim_color": "#ffc070"},
			"Cactus": {"shade": "#2e5a48", "line": "#10241c", "width": 1.3, "rim": 0.25,
				"rim_color": "#ffd08a"},
			"Brush": {"shade": "#4a4a34", "width": 0.0},
			"Pebble": {"shade": "#6a3440", "line": "#2a0e18", "width": 1.2},
			"Sun": {"emissive": true, "use_vc": 0.0, "intensity": 1.2, "fog_max": 0.0},
			"Glow": {"glow": true, "intensity": 0.5},
			# Lit from behind by the sun: pink-violet undersides, gold edges.
			"Cloud": {"light": Vector3(0.3, 0.1, -1.0), "shade": "#d27c96", "soft": 0.1,
				"bias": 0.1, "rim": 0.35, "rim_color": "#ffe0a0", "width": 0.0,
				"highlight": 0.0, "fog_max": 0.25},
			"Twig": {"shade": "#5a3a24", "line": "#2a1a10", "width": 1.2},
			"Bird": {"flat": true, "fog_max": 0.3},
		},
	},
	"nexus": {
		"light": Vector3(0.4, 0.7, 0.3),
		"fog": "#c8a0c8", "fog_near": 60.0, "fog_far": 560.0, "fog_max": 0.6,
		"sky": {
			"top_color": Color("#1a2260"), "mid_color": Color("#7a5aa8"),
			"horizon_color": Color("#ffcf8a"), "glow_dir": Vector3(0.0, 0.15, -1.0),
			"glow_color": Color("#ffd890"), "glow_amount": 0.5,
			"mid_at": Vector2(-0.1, 0.2), "top_at": Vector2(0.2, 0.7), "stars": 0.6,
		},
		"look": {
			"Tile": {"shade": "#6a5a7a", "line": "#2a2030", "width": 1.0, "rim": 0.1},
			"Pillar": {"shade": "#6a5a7e", "line": "#2a2034", "width": 1.4, "rim": 0.3,
				"rim_color": "#ffd890"},
			"Rune": {"emissive": true, "use_vc": 0.0, "pulse": 1.0, "intensity": 1.2,
				"fog_max": 0.2},
			"Gold": {"shade": "#9a5a2a", "line": "#4a2a10", "width": 1.4, "highlight": 0.35,
				"rim": 0.4, "rim_color": "#fff0b0"},
			"Portal": {"emissive": true, "use_vc": 0.0, "intensity": 1.3, "fog_max": 0.1,
				"pulse": 0.6},
			"Crystal": {"emissive": true, "use_vc": 0.0, "intensity": 1.1, "fog_max": 0.2},
			"Planet": {"shade": "#5a5a9a", "width": 0.0, "rim": 0.45, "rim_color": "#ffe0c0",
				"fog_max": 0.25},
			"Beam": {"ray": true, "intensity": 0.28},
			"Glow": {"glow": true, "intensity": 0.5},
			# Sunset-lit: peach tops, violet undersides, a gold rim.
			"Cloud": {"light": Vector3(0.1, 0.8, -0.3), "shade": "#8a6ab4", "line": "#6a4a90",
				"soft": 0.09, "bias": 0.1, "rim": 0.35, "rim_color": "#ffe0a8", "width": 1.2,
				"highlight": 0.0},
			"Grass": {"shade": "#3f9a6a", "line": "#24503c"},
			"Rock": {"shade": "#a26f82", "line": "#4a2d48"},
			"Leaves": {"shade": "#2f8a5e", "line": "#1b4a36", "sway": 0.02},
			"Ivy": {"shade": "#2f7a56", "line": "#1b4a36"},
			"Pine": {"shade": "#1f6a5c", "line": "#113c34", "sway": 0.02},
			"Trunk": {"shade": "#5e3b4a", "line": "#382230", "sway": 0.02},
			"Foam": {"shade": "#cfe6ff", "line": "#8fb4dc", "width": 1.2},
			"Pebble": {"shade": "#7b7599", "line": "#443d5e"},
			"Flower": {"shade": "#e0b4cf", "width": 0.0, "highlight": 0.0},
			"Water": {"water": true, "speed": 1.5},
			"Stream": {"water": true, "speed": 0.6, "fade": 0.0},
		},
	},
	"ocean": {
		# Light from the surface, straight down.
		"light": Vector3(0.1, 1.0, 0.2),
		"fog": "#0e4f94", "fog_near": 12.0, "fog_far": 150.0, "fog_max": 0.85,
		# The painted board's caustics still ripple over it.
		"motion": true,
		"sky": {
			"top_color": Color("#7fe0ff"), "mid_color": Color("#1f86cc"),
			"horizon_color": Color("#0b3d7a"), "glow_dir": Vector3(0.1, 1.0, -0.4),
			"glow_color": Color("#d8faff"), "glow_amount": 0.55,
			"mid_at": Vector2(-0.3, 0.15), "top_at": Vector2(0.2, 0.85),
		},
		"look": {
			"Sand": {"shade": "#5a86b8", "width": 0.0, "rim": 0.0, "highlight": 0.06,
				"bias": -0.1},
			"Reef": {"shade": "#16345a", "line": "#0a1a30", "width": 1.3, "rim": 0.3,
				"rim_color": "#8ff0ff"},
			"Coral": {"shade": "#4a4a9a", "line": "#1a1a40", "width": 1.2, "rim": 0.3,
				"rim_color": "#ffe0f0", "highlight": 0.15},
			"Kelp": {"shade": "#1e4a3e", "line": "#0c2420", "width": 1.0, "sway": 0.02,
				"sway_alpha": 1.0, "rim": 0.2, "rim_color": "#b0ffd0"},
			"Jelly": {"emissive": true, "use_vc": 0.0, "intensity": 1.1, "fog_max": 0.5},
			"Glow": {"glow": true, "intensity": 0.5},
			"Fish": {"shade": "#2a4a8a", "line": "#0c1a30", "width": 1.0, "rim": 0.3,
				"rim_color": "#ffffff"},
			"Whale": {"flat": true, "fog_max": 0.6},
			"Bubble": {"shade": "#8fd8f0", "rim": 0.7, "rim_color": "#ffffff", "width": 0.0,
				"highlight": 0.3, "fog_max": 0.5},
			"Shaft": {"ray": true, "intensity": 0.2},
		},
	},
	"space": {
		# From the upper left and in front, so the worlds show a lit face and
		# a dark limb with the nebula's violet on its edge.
		"light": Vector3(-0.5, 0.45, 0.6),
		"fog": "#140a2e", "fog_near": 200.0, "fog_far": 1500.0, "fog_max": 0.4,
		"sky": {
			"top_color": Color("#05030f"), "mid_color": Color("#0c0624"),
			"horizon_color": Color("#130a30"), "mid_at": Vector2(-0.5, 0.0),
			"top_at": Vector2(0.0, 0.8), "glow_amount": 0.0, "nebula": 0.6,
			"nebula_a": Color("#2c0e5e"), "nebula_b": Color("#b040c0"),
			"nebula_dir": Vector3(-0.1, 0.35, -1.0), "stars": 1.2,
		},
		"look": {
			"Planet": {"shade": "#2a1a5a", "width": 0.0, "rim": 0.5, "rim_color": "#e0b0ff",
				"highlight": 0.1, "bias": -0.05, "soft": 0.05},
			"Ring": {"flat": true, "fog_max": 0.3},
			"Moon": {"shade": "#3a3060", "line": "#140c24", "width": 1.2, "rim": 0.4,
				"rim_color": "#d0c0ff"},
			"Asteroid": {"shade": "#2a2040", "line": "#0c0814", "width": 1.3, "rim": 0.4,
				"rim_color": "#c090ff"},
			"Comet": {"emissive": true, "use_vc": 0.0, "intensity": 1.3, "fog_max": 0.0},
			"Tail": {"ray": true, "intensity": 0.35},
			"Glow": {"glow": true, "intensity": 0.5},
		},
	},
	"subway": {
		# From the tubes overhead.
		"light": Vector3(0.1, 0.9, 0.3),
		"fog": "#03050c", "fog_near": 14.0, "fog_far": 210.0, "fog_max": 0.96,
		# The wet floor reflects the train and the tubes.
		"reflection": 0.5,
		"sky": {
			"top_color": Color("#020306"), "mid_color": Color("#04060c"),
			"horizon_color": Color("#070a12"), "glow_amount": 0.0,
		},
		"look": {
			"Floor": {"road": true, "markings": 0.0, "sidewalk": 1.0, "slab": 1.2,
				"ripples": 0.0, "streak": 0.9, "reflect_amount": 0.85,
				"base_a": "#060914", "base_b": "#0e1426"},
			"Tactile": {"road": true, "markings": 0.0, "sidewalk": 1.0, "slab": 0.6, "dots": 1.0,
				"ripples": 0.0, "streak": 0.9, "reflect_amount": 0.5,
				"base_a": "#a87c0e", "base_b": "#e4b42a"},
			# Below the reflecting floor, so kept out of the reflection.
			"Edge": {"shade": "#101218", "width": 0.0, "rim": 0.0, "eye_only": true},
			"Ballast": {"shade": "#0c0c10", "width": 0.0, "rim": 0.0, "highlight": 0.0,
				"eye_only": true},
			"Rail": {"shade": "#3a3e4a", "width": 0.0, "rim": 0.6, "rim_color": "#ffd0d0",
				"highlight": 0.4, "eye_only": true},
			"Tiles": {"tiles": true, "tile": "#8c98b0", "band": "#b8121a", "grout": "#0e1220"},
			"TilesDark": {"tiles": true, "tile": "#2c3446", "band": "#2c3446", "grout": "#080a12"},
			# Lit from below by the tubes, so the underside of the vault is
			# the lit side.
			"Vault": {"light": Vector3(0.0, -1.0, 0.2), "shade": "#060912", "width": 0.0,
				"rim": 0.0, "highlight": 0.0, "bias": 0.3, "soft": 0.3},
			"Fixture": {"shade": "#141820", "width": 0.0},
			"Tube": {"emissive": true, "use_vc": 0.0, "intensity": 1.05, "fog_max": 0.6},
			"TubeFlicker": {"emissive": true, "use_vc": 0.0, "intensity": 1.05, "flicker": 1.0,
				"fog_max": 0.6},
			"Glow": {"glow": true, "intensity": 0.24},
			"Pillar": {"shade": "#141a26", "line": "#06080c", "width": 1.2, "rim": 0.45,
				"rim_color": "#aeb8d0", "highlight": 0.2},
			"Steel": {"shade": "#1c2336", "line": "#05070c", "width": 1.4, "rim": 0.45,
				"rim_color": "#e0e8ff", "highlight": 0.3},
			"TrainGlass": {"emissive": true, "use_vc": 0.0, "intensity": 0.5, "fog_max": 0.85},
			"TailLight": {"emissive": true, "use_vc": 0.0, "intensity": 1.4, "fog_max": 0.9},
			"Sign": {"emissive": true, "use_vc": 0.0, "intensity": 1.3, "fog_max": 0.9},
			"SignPanel": {"shade": "#0a0c12", "width": 0.8},
			"SignText": {"flat": true},
			"SignRed": {"flat": true},
			"Bench": {"shade": "#0e1118", "line": "#05070c", "width": 1.0, "rim": 0.35,
				"rim_color": "#aeb8d0"},
			"Bin": {"shade": "#2a2e3a", "line": "#05070c", "width": 1.0, "rim": 0.45,
				"rim_color": "#dfe6f5", "highlight": 0.3},
			"Signal": {"emissive": true, "intensity": 1.3, "fog_max": 0.5},
			"Stairs": {"shade": "#141820", "width": 0.8},
			"Person": {"shade": "#3a4270", "line": "#05070e", "width": 1.4, "highlight": 0.05,
				"rim": 0.4, "rim_color": "#c8d8ff"},
		},
	},
	"city": {
		# From above and a little behind: roofs, shoulders and car tops take
		# the light, and what faces the camera stays dark with a cold rim,
		# which is how a street reads at night.
		"light": Vector3(0.35, 0.75, 0.2),
		"fog": "#0f1a4c", "fog_near": 60.0, "fog_far": 520.0, "fog_max": 0.8,
		# The wet road reflects everything: a second camera, at this fraction
		# of the screen's resolution.
		"reflection": 0.5,
		"rain": "rain",
		"sky": {
			"top_color": Color("#02040f"), "mid_color": Color("#081238"),
			"horizon_color": Color("#18286e"), "glow_dir": Vector3(0.17, 0.5, -1.1),
			"glow_color": Color("#7a96ff"), "glow_amount": 0.3,
			"mid_at": Vector2(-0.05, 0.15), "top_at": Vector2(0.15, 0.6),
			"clouds": 0.75, "cloud_color": Color("#0a1034"),
		},
		"look": {
			"Road": {"road": true, "reflect_amount": 0.9},
			"Sidewalk": {"road": true, "sidewalk": 1.0, "reflect_amount": 0.45},
			"Curb": {"shade": "#141a30", "width": 0.0, "rim": 0.0},
			"Building": {"building": true},
			"Neon": {"emissive": true, "flicker": 1.0, "intensity": 1.25, "fog_max": 0.5},
			"NeonEdge": {"emissive": true, "intensity": 1.15, "fog_max": 0.55},
			"Door": {"emissive": true, "use_vc": 0.0},
			"Ad": {"emissive": true, "intensity": 1.1},
			"LampPost": {"shade": "#0a0c18", "line": "#05060c", "width": 1.2,
				"rim": 0.25, "rim_color": "#9fb4ff"},
			"LampBulb": {"emissive": true, "intensity": 1.3},
			"Glow": {"glow": true, "intensity": 0.55},
			"Pool": {"glow": true, "billboard": 0.0, "intensity": 0.22, "falloff": 1.6},
			"LightCone": {"cone": true},
			"Blink": {"emissive": true, "use_vc": 0.0, "blink": 0.6, "fog_max": 0.3},
			"Moon": {"emissive": true, "fog_max": 0.0},
			"Leaves": {"shade": "#0c1c1a", "line": "#050c0c", "rim": 0.3,
				"rim_color": "#ffcf7a", "width": 1.6},
			"Trunk": {"shade": "#140e14", "line": "#080508", "width": 1.2},
			"Shelter": {"shade": "#0c1024", "width": 1.2},
			"ShelterGlass": {"shade": "#141f3a", "rim": 0.4, "rim_color": "#8fb0ff",
				"width": 0.0, "vc_strength": 0.0},
			# One paint for every car: the colour is in the vertex colour, and
			# it multiplies both tones, so the shadow is the car's colour
			# gone dark blue.
			"Paint": {"shade": "#3a4468", "line": "#05070e", "width": 1.6,
				"highlight": 0.25, "rim": 0.35, "rim_color": "#cfe0ff"},
			"Glass": {"shade": "#0c1428", "vc_strength": 0.0, "highlight": 0.3,
				"rim": 0.3, "rim_color": "#8fb0ff", "width": 0.0},
			"Tire": {"shade": "#050608", "width": 0.0, "rim": 0.1},
			"Hub": {"shade": "#3a4050", "width": 0.0},
			"Headlight": {"emissive": true, "use_vc": 0.0, "intensity": 1.3},
			"Taillight": {"emissive": true, "use_vc": 0.0, "intensity": 1.2},
			"TaxiSign": {"emissive": true, "use_vc": 0.0},
			"BusGlass": {"emissive": true, "use_vc": 0.0, "intensity": 0.9},
			"BusSign": {"emissive": true, "use_vc": 0.0, "intensity": 1.3},
			"Person": {"shade": "#3a4270", "line": "#05070e", "width": 1.5,
				"highlight": 0.05, "rim": 0.4, "rim_color": "#9fc0ff"},
			"Umbrella": {"shade": "#303a60", "rim": 0.35, "rim_color": "#9fc0ff",
				"width": 1.3},
		},
	},
}

var scene_path := ""
var _player: AnimationPlayer
var _anim := ""
var _cache := {}
var _camera: Camera3D
var _cfg: Dictionary = {}
## The camera's width in the composed frame, as a horizontal field of view.
var _hfov := 0.0
## How much wider than the screen the viewport is. The game draws its backdrop
## with the shake margin hanging off both edges, so without this the scene
## would come out zoomed by that margin.
var _overscan := 1.0
## The wet-road reflection: a viewport sharing this scene's world, and a
## camera in it kept mirrored under the road.
var _refl_vp: SubViewport
var _refl_cam: Camera3D
var _refl_scale := 0.5
var _road_mats: Array[ShaderMaterial] = []


func _init(path := "", overscan := 1.0) -> void:
	scene_path = path
	_overscan = overscan
	_cfg = config(path)


## This scene's entry in `SCENES`, or an empty one.
static func config(path: String) -> Dictionary:
	# A variant of a scene ("city__overhead") shares the scene's settings.
	var key := path.get_file().get_basename()
	if not SCENES.has(key) and key.contains("__"):
		key = key.get_slice("__", 0)
	return SCENES.get(key, {})


## Whether the painted board's 2D motion should still run over this scene.
static func keeps_motion(path: String) -> bool:
	return bool(config(path).get("motion", false))


## The viewport is `k` times as wide as the screen it is shown on.
func set_overscan(k: float) -> void:
	_overscan = k
	_apply_fov()


func _apply_fov() -> void:
	if _camera == null:
		return
	_camera.fov = rad_to_deg(2.0 * atan(tan(_hfov * 0.5) * _overscan))


func _ready() -> void:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_warning("board3d: could not load %s" % scene_path)
		return
	var root := packed.instantiate()
	add_child(root)

	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		_dress(mi)

	var cams := root.find_children("*", "Camera3D", true, false)
	if not cams.is_empty():
		_camera = cams[0] as Camera3D
		var yfov := deg_to_rad(_camera.fov)
		_hfov = 2.0 * atan(tan(yfov * 0.5) * DESIGN_ASPECT)
		_camera.keep_aspect = Camera3D.KEEP_WIDTH
		_camera.current = true
		_apply_fov()
		if _cfg.has("rain"):
			_add_rain(String(_cfg["rain"]))
		if _cfg.has("reflection"):
			_add_reflection(float(_cfg["reflection"]))

	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY
	var sky_cfg: Dictionary = _cfg.get("sky", {})
	for k: String in sky_cfg:
		sky_mat.set_shader_parameter(k, sky_cfg[k])
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var players := root.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_player = players[0]
		var names := _player.get_animation_list()
		if not names.is_empty():
			_anim = names[0]
			_player.get_animation(_anim).loop_mode = Animation.LOOP_LINEAR
			_player.play(_anim)


## Three sheets of rain hung in front of the camera: near drops big and
## quick, far ones fine and slow. Sized to cover the tallest screen at their
## depth, and on a layer the reflection camera does not see.
func _add_rain(kind: String) -> void:
	var layers := [
		{"d": 4.0, "columns": 38.0, "rows": 2.0, "speed": 2.6, "strength": 0.2, "len": 0.3},
		{"d": 10.0, "columns": 70.0, "rows": 3.0, "speed": 2.0, "strength": 0.16, "len": 0.28},
		{"d": 26.0, "columns": 120.0, "rows": 5.0, "speed": 1.5, "strength": 0.12, "len": 0.24},
	]
	if kind == "snow":
		layers = [
			{"d": 4.0, "columns": 16.0, "rows": 9.0, "speed": 0.32, "strength": 0.7, "size": 0.2},
			{"d": 10.0, "columns": 30.0, "rows": 18.0, "speed": 0.24, "strength": 0.55, "size": 0.2},
			{"d": 26.0, "columns": 60.0, "rows": 36.0, "speed": 0.16, "strength": 0.4, "size": 0.22},
		]
	for l: Dictionary in layers:
		var d := float(l["d"])
		var w := 2.0 * d * tan(_hfov * 0.5) * _overscan * 1.15
		var q := QuadMesh.new()
		q.size = Vector2(w, w * 2.6)
		var m := ShaderMaterial.new()
		m.shader = RAIN
		m.set_shader_parameter("columns", float(l["columns"]))
		m.set_shader_parameter("rows", float(l["rows"]))
		m.set_shader_parameter("speed", float(l["speed"]))
		m.set_shader_parameter("strength", float(l["strength"]))
		if kind == "snow":
			m.set_shader_parameter("flakes", 1.0)
			m.set_shader_parameter("flake_size", float(l["size"]))
			m.set_shader_parameter("density", 0.3)
			m.set_shader_parameter("slant", 0.0)
			m.set_shader_parameter("color", Color(0.92, 0.95, 1.0))
		else:
			m.set_shader_parameter("drop_len", float(l["len"]))
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = m
		mi.layers = LAYER_EYE_ONLY
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(0.0, 0.0, -d)
		_camera.add_child(mi)


func _add_reflection(scale: float) -> void:
	_refl_scale = scale
	_refl_vp = SubViewport.new()
	_refl_vp.world_3d = get_viewport().find_world_3d()
	_refl_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_refl_vp.size = _refl_size()
	add_child(_refl_vp)
	_refl_cam = Camera3D.new()
	_refl_cam.cull_mask = 0xFFFFF & ~LAYER_EYE_ONLY
	_refl_vp.add_child(_refl_cam)
	_refl_cam.current = true
	for m in _road_mats:
		m.set_shader_parameter("reflection", _refl_vp.get_texture())
	_follow()


func _refl_size() -> Vector2i:
	var s := Vector2(get_viewport().size) * _refl_scale
	return Vector2i(maxi(int(s.x), 8), maxi(int(s.y), 8))


## Keep the reflection camera the main one mirrored in the road (y = 0):
## same place with its height negated, same heading with its pitch negated.
func _follow() -> void:
	if _refl_cam == null or _camera == null:
		return
	var t := _camera.global_transform
	var o := t.origin
	var f := -t.basis.z
	_refl_cam.keep_aspect = _camera.keep_aspect
	_refl_cam.fov = _camera.fov
	_refl_cam.near = _camera.near
	_refl_cam.far = _camera.far
	_refl_cam.global_transform = Transform3D(
		Basis.looking_at(Vector3(f.x, -f.y, f.z), Vector3.UP), Vector3(o.x, -o.y, o.z))
	var want := _refl_size()
	if _refl_vp.size != want:
		_refl_vp.size = want


func _process(_delta: float) -> void:
	_follow()


## Jump the loop to `t` seconds. For the capture tools; the game never calls it.
func seek(t: float) -> void:
	if _player != null and _anim != "":
		_player.seek(fmod(t, _player.get_animation(_anim).length), true)


func loop_length() -> float:
	if _player == null or _anim == "":
		return 0.0
	return _player.get_animation(_anim).length


## Every surface of the mesh gets the material its name asks for. (A car's
## body is one mesh with two: its paint and its windows.)
func _dress(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	for i in mi.mesh.get_surface_count():
		var src := mi.mesh.surface_get_material(i)
		var name := src.resource_name if src != null else ""
		if not _cache.has(name):
			var lit := Color.WHITE
			if src is BaseMaterial3D:
				lit = (src as BaseMaterial3D).albedo_color
			_cache[name] = _material(name, lit)
		mi.set_surface_override_material(i, _cache[name])
		# Some things should not turn up in a reflection: whatever sits below
		# the reflecting floor (a subway's track bed) would be seen from
		# underneath by the mirrored camera.
		var look: Dictionary = (_cfg.get("look", {}) as Dictionary).get(name, {})
		if look.get("eye_only", false):
			mi.layers = LAYER_EYE_ONLY
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _fog(m: ShaderMaterial, look: Dictionary) -> void:
	m.set_shader_parameter("fog_color", Color(String(_cfg.get("fog", "#cfe6ff"))))
	m.set_shader_parameter("fog_near", float(_cfg.get("fog_near", 30.0)))
	m.set_shader_parameter("fog_far", float(_cfg.get("fog_far", 130.0)))
	m.set_shader_parameter("fog_max", float(look.get("fog_max", _cfg.get("fog_max", 0.7))))


func _material(name: String, lit: Color) -> Material:
	var looks: Dictionary = _cfg.get("look", {})
	var look: Dictionary = looks.get(name, {})
	var flat := bool(look.get("flat", false))
	var m := ShaderMaterial.new()
	for kind: String in KINDS:
		if not look.get(kind, false):
			continue
		m.shader = KINDS[kind]
		_fog(m, look)
		match kind:
			"water":
				m.render_priority = 1
			"building", "tiles":
				m.set_shader_parameter("light_dir", _cfg.get("light", Vector3(0.35, 0.75, 0.2)))
			"road":
				_road_mats.append(m)
			"emissive":
				m.set_shader_parameter("color", lit)
		_pass_through(m, look)
		return m

	# Everything solid. `flat` is for things that are their own light (the
	# eruption) or a silhouette (the flock): one tone, no shading.
	m.shader = TOON
	_fog(m, look)
	m.set_shader_parameter("lit_color", lit)
	m.set_shader_parameter("light_dir",
		look.get("light", _cfg.get("light", Vector3(-0.5, 0.75, 0.45))))
	var shade := lit
	if not flat:
		shade = Color(String(look["shade"])) if look.has("shade") \
			else Color(lit.r * 0.55, lit.g * 0.62, lit.b * 0.85)
	m.set_shader_parameter("shade_color", shade)
	m.set_shader_parameter("band_soft", float(look.get("soft", 0.025)))
	m.set_shader_parameter("band_bias", float(look.get("bias", 0.08)))
	m.set_shader_parameter("rim_amount", 0.0 if flat else float(look.get("rim", 0.22)))
	if look.has("rim_color"):
		m.set_shader_parameter("rim_color", Color(String(look["rim_color"])))
	m.set_shader_parameter("highlight", 0.0 if flat else float(look.get("highlight", 0.08)))
	_pass_through(m, look)
	var sway := float(look.get("sway", 0.0))

	var width := float(look.get("width", 0.0 if flat else 2.4))
	if width > 0.0:
		var line := ShaderMaterial.new()
		line.shader = OUTLINE
		var ink := Color(String(look["line"])) if look.has("line") \
			else Color(lit.r * 0.3, lit.g * 0.3, lit.b * 0.42)
		line.set_shader_parameter("line_color", ink)
		line.set_shader_parameter("width_px", width)
		line.set_shader_parameter("sway", sway)
		line.set_shader_parameter("sway_alpha", float(look.get("sway_alpha", 0.0)))
		_fog(line, look)
		m.next_pass = line
	return m


## Every other key in a look is a uniform of the same name, passed straight
## through; a string starting with # is a colour.
func _pass_through(m: ShaderMaterial, look: Dictionary) -> void:
	for k: String in look:
		if KINDS.has(k) or k in META:
			continue
		var v: Variant = look[k]
		if v is String and String(v).begins_with("#"):
			v = Color(String(v))
		m.set_shader_parameter(k, v)
