extends RefCounted
class_name Cosmetics
## What the unlockables actually look like. `Profile` owns which ones you have
## earned and which you are wearing; this owns the paint.
##
## Kept apart from `Profile` on purpose. One is a save file that must stay
## readable across versions; the other is art direction that will get fiddled
## with constantly. Mixing them means every colour tweak risks the save.

## Board themes repaint the world behind the game — the backdrop wash, the board
## panel and the grid ruling. Nothing here touches a block's tier colour: those
## carry meaning (a 4x3 is always red) and a theme that recoloured them would be
## trading readability for decoration.
const THEMES := {
	"midnight": {
		"top": "#0b1020", "bottom": "#141a36", "panel": "#0e142a",
		"grid": "#ffffff", "grid_a": 0.035,
	},
	"ember": {
		"top": "#170a09", "bottom": "#2f1611", "panel": "#241110",
		"grid": "#ffb08a", "grid_a": 0.055,
	},
	"chlorophyll": {
		"top": "#07150f", "bottom": "#0f2a1d", "panel": "#0b2016",
		"grid": "#9dffcb", "grid_a": 0.05,
	},
	"vapor": {
		"top": "#140a1f", "bottom": "#291340", "panel": "#1c0f2b",
		"grid": "#ffa8f0", "grid_a": 0.055,
	},
	"bone": {
		"top": "#11100c", "bottom": "#262019", "panel": "#1c1813",
		"grid": "#ffe9c2", "grid_a": 0.05,
	},
	# The premium one, and it is the only entry that uses more than the five keys
	# above — see the note under THEME_EXTRAS for why that had to change.
	"prism": {
		"top": "#04030c", "bottom": "#160a33", "panel": "#1a1140",
		"grid": "#7df5ff", "grid_a": 0.16,
		# Translucent, so the bloom behind it comes through the playfield. This
		# is the difference between a lit backdrop with a dark slab sitting on
		# it and a sheet of glass over a light — and it is the one property that
		# makes the board read as a different material rather than a different
		# colour.
		"panel_a": 0.62,
		# A frame that is not the same teal every other board wears.
		"frame": "#ffd8a8", "frame_a": 0.85,
		"accent": "#ffc46b",
		# The keyboard is roughly forty percent of a phone screen and every
		# theme left it identical, which is most of why a "new theme" read as a
		# filter. Prism repaints it.
		"key_bg": "#251a4e", "key_edge": "#c9a4ff", "key_ink": "#fff3d6",
		"fire_bg": "#4a2d7a", "fire_edge": "#ffd8a8",
		# A bloom behind the board, so the backdrop is lit rather than flat.
		"glow": "#7b3fe4", "glow_a": 0.30,
		# Bright points where the grid crosses. Cheap, and it makes the
		# playfield read as a lattice instead of ruled paper.
		"nodes": true,
	},

	# ----------------------------------------------------------- the eight
	#
	# Painted boards. Everything above this line is a palette; these carry a
	# picture and something moving on top of it, and that is the whole of the
	# difference — a wash can be argued about, but nobody mistakes a waterfall
	# for a filter.
	#
	# `top` and `bottom` stay dark on every one of them, including Clouds. They
	# are not only the backdrop: two dozen callsites in `game.gd` wash a menu in
	# `Color(bg_top, 0.93)` and then print white type on it, so a light `top`
	# would not brighten the game, it would erase every menu in it. The picture
	# carries the brightness instead, and the menus keep their dark ground.
	"forest": {
		"top": "#08150c", "bottom": "#132a18", "panel": "#0b2412", "panel_a": 0.42,
		"grid": "#bdf5c0", "grid_a": 0.10, "nodes": true,
		"frame": "#7dd94f", "frame_a": 0.95, "frame_pulse": 0.10,
		"accent": "#a7f04f",
		"key_bg": "#12301a", "key_edge": "#7dd94f", "key_ink": "#e8ffe0",
		"fire_bg": "#1d4a22", "fire_edge": "#a7f04f",
		"glow": "#3fa02a", "glow_a": 0.18,
		"art": "res://boards/forest.png", "art_a": 0.85, "art_dim": 0.30,
		"motion": "leaves",
	},
	"volcano": {
		"top": "#190704", "bottom": "#331008", "panel": "#260a05", "panel_a": 0.46,
		"grid": "#ffb08a", "grid_a": 0.10, "nodes": true,
		"frame": "#ff5722", "frame_a": 0.95, "frame_pulse": 0.28,
		"accent": "#ff8c42",
		"key_bg": "#2a0d07", "key_edge": "#ff6b2c", "key_ink": "#ffd9c2",
		"fire_bg": "#5a1a0a", "fire_edge": "#ff8c42",
		"glow": "#ff4500", "glow_a": 0.26,
		"art": "res://boards/volcano.png", "art_a": 0.90, "art_dim": 0.34,
		"motion": "embers",
	},
	"ocean": {
		"top": "#041526", "bottom": "#0a2f4d", "panel": "#062033", "panel_a": 0.40,
		"grid": "#b8f0ff", "grid_a": 0.11, "nodes": true,
		"frame": "#29c5f6", "frame_a": 0.95, "frame_pulse": 0.14,
		"accent": "#4dd0e1",
		"key_bg": "#0a2438", "key_edge": "#29c5f6", "key_ink": "#dff7ff",
		"fire_bg": "#0e3d5c", "fire_edge": "#4dd0e1",
		"glow": "#1e88c7", "glow_a": 0.22,
		"art": "res://boards/ocean.png", "art_a": 0.88, "art_dim": 0.30,
		"motion": "caustics",
	},
	"space": {
		"top": "#08041c", "bottom": "#1b0a3a", "panel": "#140a2e", "panel_a": 0.44,
		"grid": "#d9b8ff", "grid_a": 0.12, "nodes": true,
		"frame": "#b44cff", "frame_a": 0.95, "frame_pulse": 0.18,
		"accent": "#c77dff",
		"key_bg": "#1c1038", "key_edge": "#b44cff", "key_ink": "#f0e4ff",
		"fire_bg": "#3a1a63", "fire_edge": "#c77dff",
		"glow": "#7b2fd4", "glow_a": 0.28,
		"art": "res://boards/space.png", "art_a": 0.90, "art_dim": 0.26,
		"motion": "starfield",
	},
	"cyber": {
		"top": "#060619", "bottom": "#140a33", "panel": "#0c0a24", "panel_a": 0.42,
		"grid": "#7df5ff", "grid_a": 0.13, "nodes": true,
		"frame": "#ff2fd0", "frame_a": 0.95, "frame_pulse": 0.24,
		"accent": "#22e8ff",
		"key_bg": "#12103a", "key_edge": "#ff2fd0", "key_ink": "#d8fbff",
		"fire_bg": "#12385c", "fire_edge": "#22e8ff",
		"glow": "#c81ce0", "glow_a": 0.26,
		"art": "res://boards/cyber.png", "art_a": 0.90, "art_dim": 0.32,
		"motion": "scanlines",
	},
	# The one bright board, and the only theme in the game that prints dark type
	# on a light key. Everything that decides ink asks the theme for it, so this
	# works — but it is the reason `key_ink` exists as a value rather than as an
	# assumption, and a ninth board that forgets to set it gets the dark default
	# and is unreadable rather than merely wrong.
	"clouds": {
		"top": "#0a1424", "bottom": "#14243d", "panel": "#dbe9fa", "panel_a": 0.26,
		"grid": "#ffffff", "grid_a": 0.22, "nodes": false,
		"frame": "#ffffff", "frame_a": 0.85, "frame_pulse": 0.08,
		"accent": "#4fc3f7",
		"key_bg": "#e8f1fb", "key_edge": "#4fc3f7", "key_ink": "#12305a",
		"fire_bg": "#bfe0f7", "fire_edge": "#1f7fc4",
		"glow": "#ffffff", "glow_a": 0.20,
		"art": "res://boards/clouds.png", "art_a": 0.92, "art_dim": 0.12,
		"motion": "drift",
	},
	"desert": {
		"top": "#1a0c05", "bottom": "#35190a", "panel": "#2b1408", "panel_a": 0.42,
		"grid": "#ffd9a0", "grid_a": 0.11, "nodes": true,
		"frame": "#ff9e2c", "frame_a": 0.95, "frame_pulse": 0.12,
		"accent": "#ffb74d",
		"key_bg": "#2e1608", "key_edge": "#ff9e2c", "key_ink": "#ffeccd",
		"fire_bg": "#5c3010", "fire_edge": "#ffb74d",
		"glow": "#ff8f1f", "glow_a": 0.22,
		"art": "res://boards/desert.png", "art_a": 0.88, "art_dim": 0.30,
		"motion": "haze",
	},
	"aurora": {
		"top": "#04121f", "bottom": "#0a2a3f", "panel": "#06202e", "panel_a": 0.40,
		"grid": "#b6ffe8", "grid_a": 0.11, "nodes": true,
		"frame": "#2ee6c0", "frame_a": 0.95, "frame_pulse": 0.20,
		"accent": "#5eead4",
		"key_bg": "#07222f", "key_edge": "#2ee6c0", "key_ink": "#dcfff5",
		"fire_bg": "#0c3c4c", "fire_edge": "#5eead4",
		"glow": "#1fd9a8", "glow_a": 0.22,
		"art": "res://boards/aurora.png", "art_a": 0.90, "art_dim": 0.24,
		"motion": "ribbons",
	},

	# The ninth, and the only board in the game that is not for sale.
	#
	# Nexus is the share reward — see the `shares` requirement on its
	# catalogue row. It sits in this table beside the eight paid ones because
	# it *is* one of them as far as every drawing routine is concerned: a
	# picture, a weather, a frame and a face. What differs is the lock on the
	# door, and locks live in `Profile`, not here.
	#
	# Its art is the one piece in the set that arrived at full size rather than
	# sliced out of a contact sheet, and it is nearly square where the others
	# are 9:16. `_draw_board_art` centre-crops to the screen's own aspect, and
	# the middle of this picture is the portal, the sun and the plaza — so a
	# phone gets the composition the painting was built around.
	"nexus": {
		"top": "#0c0a1c", "bottom": "#221a33", "panel": "#140f2a", "panel_a": 0.40,
		"grid": "#ffe9b8", "grid_a": 0.12, "nodes": true,
		"frame": "#ffc850", "frame_a": 0.95, "frame_pulse": 0.22,
		"accent": "#ffd77a",
		"key_bg": "#1a1330", "key_edge": "#ffc850", "key_ink": "#fff3d6",
		"fire_bg": "#3d2a52", "fire_edge": "#ffd77a",
		"glow": "#c9973f", "glow_a": 0.26,
		"art": "res://boards/nexus.png", "art_a": 0.92, "art_dim": 0.28,
		"motion": "aether",
	},
}

## What a theme may set beyond the five originals, and what it falls back to.
##
## The five were `top`, `bottom`, `panel`, `grid` and `grid_a` — a backdrop
## wash and a ruling. That is a colour filter, and no amount of picking better
## colours makes a filter feel like an overhaul: two themes built from it differ
## in hue and in nothing else, which is exactly the complaint a paid one earns.
##
## So the surfaces that actually cover the screen are addressable now. The
## keyboard especially: it is about forty percent of a phone display and every
## theme in the game left it the same dark slab.
##
## Every default here reproduces what was hardcoded before, so the five free
## themes render byte-identically and only a theme that asks for more gets more.
const THEME_EXTRAS := {
	"frame": "", "frame_a": 0.28,
	"panel_a": 1.0,
	"accent": "",
	"key_bg": "#141b33", "key_edge": "", "key_ink": "#e6ecff",
	"fire_bg": "#1b2f4a", "fire_edge": "",
	"glow": "", "glow_a": 0.0,
	"nodes": false,
	# A picture behind the game, and how much of it survives to the screen.
	# `art_a` is the alpha it is drawn at over the theme's own wash, so it
	# doubles as the dim — 0.9 over a near-black `top` is a slightly darkened
	# photograph, which is what keeps white HUD type legible on top of one.
	# `art_dim` is the extra wash poured back over the top and bottom strips
	# where the clock and the keyboard sit; the middle, where the board is,
	# keeps its brightness.
	"art": "", "art_a": 1.0, "art_dim": 0.0,
	# Which of `draw_motion`'s effects runs over the picture. Empty is still.
	"motion": "",
	# How hard the board's frame breathes, as a fraction of its own alpha.
	# Zero holds it at a constant brightness, which is what every painted-wash
	# theme did and should keep doing.
	"frame_pulse": 0.0,
}


## An optional theme value, falling back to what the game did before themes
## could express it.
static func theme_opt(id: String, key: String):
	var t := theme(id)
	if t.has(key):
		return t[key]
	return THEME_EXTRAS.get(key, null)


## Same, as a colour, with a caller-supplied fallback for the keys whose default
## is "whatever the accent happens to be".
static func theme_tint(id: String, key: String, fallback: Color) -> Color:
	var v = theme_opt(id, key)
	if typeof(v) == TYPE_STRING and String(v) != "":
		return Color(String(v))
	return fallback


static func theme(id: String) -> Dictionary:
	return THEMES.get(id, THEMES["midnight"])


static func theme_color(id: String, key: String) -> Color:
	return Color(String(theme(id)[key]))


## Confetti, sunburst and shatter are all pure functions of the clock — no state
## to seed, reset or leak. A victory screen that has to be told to start is a
## victory screen that will one day forget to.
static func victory_confetti(node: CanvasItem, size: Vector2, t: float,
		tint: Color) -> void:
	for i in 110:
		var seed_x := fmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
		var seed_s := fmod(sin(float(i) * 78.233) * 24634.6345, 1.0)
		var x: float = absf(seed_x) * size.x
		var speed: float = 90.0 + absf(seed_s) * 190.0
		var y: float = fmod(t * speed + absf(seed_x) * 900.0, size.y + 60.0) - 30.0
		var sway: float = sin(t * 2.2 + float(i)) * 16.0
		var w: float = 4.0 + absf(seed_s) * 7.0
		var col := tint if i % 3 == 0 else (
			Color("#7bdff2") if i % 3 == 1 else Color("#c77dff"))
		# Squashed on a cycle so each piece reads as a flake turning over.
		var flip: float = absf(cos(t * 3.4 + float(i) * 0.7))
		node.draw_rect(Rect2(x + sway, y, w, w * 0.35 + w * 0.65 * flip),
			Color(col, 0.85), true)


static func victory_rays(node: CanvasItem, at: Vector2, t: float, tint: Color) -> void:
	var spokes := 18
	for i in spokes:
		var a: float = TAU * float(i) / float(spokes) + t * 0.22
		var wide := TAU / float(spokes) * 0.42
		var far := 900.0
		node.draw_colored_polygon(PackedVector2Array([
			at,
			at + Vector2(cos(a - wide), sin(a - wide)) * far,
			at + Vector2(cos(a + wide), sin(a + wide)) * far,
		]), Color(tint, 0.055 + 0.03 * sin(t * 1.7 + float(i))))


## The premium one. A shockwave that keeps going out, a core that keeps
## pulsing, and embers rising through both — three things happening at once
## rather than one, which is what makes it read as more than the others rather
## than merely different from them.
static func victory_supernova(node: CanvasItem, size: Vector2, at: Vector2,
		t: float, tint: Color) -> void:
	# Rings, each one a little behind the last, fading as they widen.
	for i in 4:
		var phase: float = fmod(t * 0.55 + float(i) * 0.25, 1.0)
		var r: float = 40.0 + phase * maxf(size.x, size.y) * 0.75
		var a: float = (1.0 - phase) * 0.5
		if a <= 0.01:
			continue
		node.draw_arc(at, r, 0.0, TAU, 96, Color(tint, a), 3.0 + (1.0 - phase) * 5.0)

	# A core that breathes rather than sits.
	var pulse: float = 0.5 + 0.5 * sin(t * 3.1)
	for i in 3:
		var rr: float = 26.0 + float(i) * 15.0 + pulse * 9.0
		node.draw_circle(at, rr, Color(tint, 0.16 - float(i) * 0.045))
	node.draw_circle(at, 18.0 + pulse * 5.0, Color(1, 1, 1, 0.55))

	# Embers, on the same deterministic hash the other effects use — no state to
	# seed and none to leak.
	for i in 70:
		var sx := fmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
		var ss := fmod(sin(float(i) * 78.233) * 24634.6345, 1.0)
		var x: float = absf(sx) * size.x
		var speed: float = 55.0 + absf(ss) * 120.0
		var y: float = size.y - fmod(t * speed + absf(sx) * 1200.0, size.y + 80.0)
		var w: float = 2.0 + absf(ss) * 3.5
		var flick: float = 0.35 + 0.65 * absf(sin(t * 4.0 + float(i)))
		node.draw_circle(Vector2(x + sin(t * 1.6 + float(i)) * 12.0, y), w,
			Color(tint, 0.5 * flick))


static func victory_shatter(node: CanvasItem, at: Vector2, t: float, tint: Color) -> void:
	# One three-second throw, looped, so it re-bursts rather than settling.
	var cycle := fmod(t, 3.0) / 3.0
	for i in 46:
		var a: float = TAU * fmod(sin(float(i) * 31.7) * 9713.3, 1.0)
		var speed: float = 220.0 + absf(fmod(sin(float(i) * 5.11) * 4271.1, 1.0)) * 520.0
		var d: float = cycle * speed
		var p: Vector2 = at + Vector2(cos(a), sin(a)) * d + Vector2(0.0, cycle * cycle * 300.0)
		var s: float = 5.0 + 9.0 * absf(fmod(sin(float(i) * 2.3) * 771.7, 1.0))
		var fade: float = clampf(1.0 - cycle, 0.0, 1.0)
		node.draw_set_transform(p, a + t * 3.0, Vector2.ONE)
		node.draw_rect(Rect2(-s * 0.5, -s * 0.5, s, s), Color(tint, 0.7 * fade), true)
	node.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------ boards in motion
#
# What the painted boards do that the painted washes cannot.
#
# A still photograph behind a game looks like a wallpaper somebody set once.
# These are the layer that makes it a place: embers going up off the lava,
# light moving on the sea floor, a scan bar crawling down the city. Each is
# small on purpose — the board is the thing being read, and a backdrop that
# competes with it for attention is a backdrop that costs somebody a word.
#
# All of them are pure functions of `t`, on the same deterministic hash the
# victory effects use. Nothing to seed, nothing to reset between matches, and a
# board that has been on screen for an hour costs exactly what it did in the
# first second. That matters more here than it did for the victory effects:
# these run for the whole match rather than for the five seconds after it.
#
# Budget is a few dozen primitives each. `game.gd` redraws every frame, so this
# is paid sixty times a second on a phone, and the ceiling is what keeps a
# premium board from being the reason the thing stutters.


## Every effect `draw_motion` dispatches, in the order they were written.
##
## The match below has no fallback — a theme naming an effect that does not
## exist gets a still backdrop and no complaint, which is indistinguishable
## from a theme that meant to be still. This list is what `shoptest` holds the
## match against in both directions, so a typo in a theme's `motion` and an
## effect nothing uses are both findable without anyone having to look at the
## screen.
const MOTIONS := ["leaves", "embers", "caustics", "starfield", "scanlines",
	"drift", "haze", "ribbons", "aether"]


## A stable pseudo-random in 0..1 for index `i`, salted by `k` so one index can
## carry several independent numbers.
static func _hash01(i: int, k: float) -> float:
	return absf(fmod(sin(float(i) * 12.9898 + k * 78.233) * 43758.5453, 1.0))


## Run a theme's backdrop effect. `kind` is the theme's `motion` value; an
## unrecognised one draws nothing rather than falling back to something, because
## a board quietly wearing another board's weather is harder to notice than a
## board wearing none.
##
## Several of these are written to run off the edge of what they are given: a
## leaf enters from above the screen, the heat bloom under Volcano is a disc
## wider than the phone, the nebulae behind Space are cut off by the frame. That
## is right on a screen, where the edge does the cropping, and wrong in a shop
## preview, where there is no edge and the overflow lands on the panel next
## door. `bound` is the second case. Immediate-mode drawing has no scissor, so
## rather than clipping after the fact the effects are asked to stay inside:
## the ambient washes that only exist to be cropped are dropped, and the
## particles that wander in from off-screen wrap at the border instead.
##
## What survives `bound` is the part that matters — the things that move. A
## preview showing the leaves and not the light shafts is a smaller version of
## the board; a preview showing nothing is a lie about what was bought.
static func draw_motion(node: CanvasItem, kind: String, size: Vector2, t: float,
		tint: Color, bound := false) -> void:
	match kind:
		"leaves": _motion_leaves(node, size, t, tint, bound)
		"embers": _motion_embers(node, size, t, tint, bound)
		"caustics": _motion_caustics(node, size, t, tint)
		"starfield": _motion_starfield(node, size, t, tint, bound)
		"scanlines": _motion_scanlines(node, size, t, tint, bound)
		"drift": _motion_drift(node, size, t, tint, bound)
		"haze": _motion_haze(node, size, t, tint)
		"ribbons": _motion_ribbons(node, size, t, tint)
		"aether": _motion_aether(node, size, t, tint, bound)


## Forest. Shafts of light coming through the canopy from the upper left, and
## leaves turning over as they come down through them.
static func _motion_leaves(node: CanvasItem, size: Vector2, t: float,
		tint: Color, bound := false) -> void:
	for i in 3:
		var x: float = size.x * (0.12 + float(i) * 0.26)
		var sway: float = sin(t * 0.28 + float(i) * 1.3) * size.x * 0.035
		var wide: float = size.x * (0.07 + 0.02 * float(i))
		var a: float = 0.05 + 0.025 * sin(t * 0.45 + float(i))
		var sky: float = 0.0 if bound else -20.0
		node.draw_colored_polygon(PackedVector2Array([
			Vector2(x + sway - wide * 0.4, sky),
			Vector2(x + sway + wide * 0.4, sky),
			Vector2(x + sway + wide * 1.7, size.y),
			Vector2(x + sway + wide * 0.2, size.y),
		]), Color(1.0, 1.0, 0.86, a))

	# Off a screen a leaf falls in from above and out past the bottom; inside a
	# panel it has to do its whole life within the frame or it pops.
	var over: float = 0.0 if bound else 60.0
	for i in 26:
		var hx := _hash01(i, 1.0)
		var hs := _hash01(i, 2.0)
		var fall: float = 26.0 + hs * 42.0
		var y: float = fmod(t * fall + hx * (size.y + 200.0),
			size.y + over * 2.0) - over
		# Drifting sideways as it falls, and a little faster than it tumbles, so
		# no two leaves are ever in step.
		var x: float = hx * size.x + sin(t * 0.7 + float(i) * 1.7) * size.x * 0.07
		var w: float = 5.0 + hs * 7.0
		# Squashed on its own cycle, which is the whole of what makes a rectangle
		# read as a leaf turning over rather than as a falling chip.
		var flip: float = absf(cos(t * 1.6 + float(i) * 0.9))
		var green := Color(0.42 + hs * 0.35, 0.72, 0.26).lerp(tint, 0.3)
		node.draw_set_transform(Vector2(x, y), sin(t + float(i)) * 0.6, Vector2.ONE)
		node.draw_rect(Rect2(-w * 0.5, -w * 0.2, w, w * 0.18 + w * 0.42 * flip),
			Color(green, 0.30 + 0.25 * flip), true)
	node.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Volcano. Embers going up, and a heat bloom along the bottom that breathes at
## a different rate so the two never quite line up.
static func _motion_embers(node: CanvasItem, size: Vector2, t: float,
		tint: Color, bound := false) -> void:
	var breathe: float = 0.5 + 0.5 * sin(t * 0.8)
	# A disc wider than the screen, centred just below it. Only its top edge is
	# ever seen, which is what makes it read as heat off the ground rather than
	# as a circle — so in a panel, where the whole disc would show, it is left
	# out and the embers carry the effect on their own.
	if not bound:
		for i in 4:
			var f := float(i) / 3.0
			node.draw_circle(Vector2(size.x * 0.5, size.y * 1.02),
				size.x * (0.35 + f * 0.75),
				Color(tint, (0.055 - f * 0.012) * (0.6 + 0.4 * breathe)))

	for i in 58:
		var hx := _hash01(i, 3.0)
		var hs := _hash01(i, 4.0)
		var rise: float = 48.0 + hs * 130.0
		var y: float = size.y - fmod(t * rise + hx * 1400.0, size.y + 90.0)
		var x: float = hx * size.x + sin(t * 1.1 + float(i) * 0.8) * 16.0
		var w: float = 1.4 + hs * 2.6
		# Guttering, so an ember reads as burning rather than as a dot.
		var flick: float = 0.30 + 0.70 * absf(sin(t * 4.2 + float(i) * 2.1))
		# They cool as they climb: orange low, dull red by the top.
		var high: float = 1.0 - clampf(y / size.y, 0.0, 1.0)
		var col := Color(1.0, 0.55 - high * 0.30, 0.12).lerp(tint, 0.25)
		node.draw_circle(Vector2(x, y), w, Color(col, 0.55 * flick * (1.0 - high * 0.5)))


## Ocean. The moving bands of light on a sea floor, and bubbles going up through
## them. The bands are polylines rather than filled shapes because a caustic is
## a bright line and filling it makes it a cloud.
static func _motion_caustics(node: CanvasItem, size: Vector2, t: float,
		tint: Color) -> void:
	for i in 9:
		var base: float = size.y * (float(i) + 0.5) / 9.0
		var pts := PackedVector2Array()
		for s in 13:
			var u := float(s) / 12.0
			var y: float = base + sin(u * 6.0 + t * 0.9 + float(i) * 1.1) * 11.0 \
				+ sin(u * 14.0 - t * 1.4) * 4.0
			pts.append(Vector2(u * size.x, y))
		var a: float = 0.035 + 0.030 * sin(t * 1.3 + float(i) * 0.7)
		node.draw_polyline(pts, Color(0.75, 0.98, 1.0, maxf(a, 0.0)), 2.5, true)

	for i in 20:
		var hx := _hash01(i, 5.0)
		var hs := _hash01(i, 6.0)
		var rise: float = 30.0 + hs * 60.0
		var y: float = size.y - fmod(t * rise + hx * 1100.0, size.y + 60.0)
		var x: float = hx * size.x + sin(t * 1.5 + float(i)) * 13.0
		var r: float = 2.0 + hs * 4.5
		node.draw_arc(Vector2(x, y), r, 0.0, TAU, 10, Color(tint, 0.30), 1.2, true)


## Space. Stars at three depths, the near ones drifting visibly and the far ones
## barely at all, which is the only trick here — parallax is what stops a field
## of dots reading as a texture.
static func _motion_starfield(node: CanvasItem, size: Vector2, t: float,
		tint: Color, bound := false) -> void:
	# Nebulae, which are only nebulae because the frame cuts them. Whole, in a
	# preview panel, they are three lilac circles.
	#
	# They breathe, and that is not decoration — it is most of what this effect
	# does. Stars are the obvious idea for a space backdrop and the wrong one on
	# their own: a hundred one-pixel dots twinkling move about a tenth of a
	# percent of the screen, which is below the threshold at which anybody
	# registers that the board is alive at all. The clouds are the large slow
	# thing, and the stars are the detail on top of them.
	if not bound:
		for i in 3:
			var f := float(i) / 2.0
			var swell: float = 0.72 + 0.28 * sin(t * 0.31 + float(i) * 2.2)
			var wander: float = sin(t * 0.17 + float(i)) * size.x * 0.02
			node.draw_circle(
				Vector2(size.x * (0.62 - f * 0.1) + wander,
					size.y * (0.28 + f * 0.06)),
				size.x * (0.20 + f * 0.30) * (0.94 + 0.06 * swell),
				Color(tint, 0.042 * (1.0 - f * 0.5) * swell))

	for i in 150:
		var hx := _hash01(i, 7.0)
		var hy := _hash01(i, 8.0)
		var depth := float(i % 3)
		var speed: float = 6.0 + depth * 12.0
		var x: float = fmod(hx * size.x + t * speed, size.x)
		var y: float = hy * size.y
		var r: float = 1.0 + depth * 1.0
		# Not every star twinkles, and the ones that do are not in step. A field
		# where all of them pulse together reads as the screen flickering.
		var tw: float = 0.45 + 0.55 * sin(t * (1.2 + hx * 2.4) + float(i))
		var col := Color.WHITE.lerp(tint, hy * 0.5)
		node.draw_circle(Vector2(x, y), r, Color(col, (0.25 + depth * 0.22) * tw))


## Cyber. A scan bar crawling down the whole screen, CRT rows under it, and
## neon signs guttering at the edges.
static func _motion_scanlines(node: CanvasItem, size: Vector2, t: float,
		tint: Color, bound := false) -> void:
	var step: float = maxf(3.0, size.y / 150.0)
	var rows := int(size.y / step)
	for i in rows:
		node.draw_rect(Rect2(0.0, float(i) * step, size.x, 1.0),
			Color(0.0, 0.0, 0.0, 0.055), true)

	# The bar. Wraps with a gap, so there is a beat between passes rather than a
	# bar permanently on screen.
	var sweep: float = fmod(t * 0.22, 1.35) / 1.0
	if sweep <= 1.0:
		var run: float = size.y if bound else size.y + 160.0
		var y: float = sweep * run - (0.0 if bound else 80.0)
		var tail: float = minf(46.0, size.y * 0.12)
		for i in 5:
			var f := float(i) / 4.0
			node.draw_rect(Rect2(0.0, maxf(y - f * tail, 0.0 if bound else -200.0),
				size.x, tail * (1.0 - f) + 3.0),
				Color(tint, 0.055 * (1.0 - f)))

	# Signage. Two columns of bars that cut out at their own rates — a neon sign
	# that pulses smoothly is a neon sign nobody believes.
	for i in 8:
		var hs := _hash01(i, 9.0)
		var on: float = 1.0 if sin(t * (2.0 + hs * 5.0) + float(i) * 2.3) > -0.45 else 0.15
		var side: float = 0.03 if i % 2 == 0 else 0.93
		var y: float = size.y * (0.06 + hs * 0.55)
		var h: float = size.y * (0.02 + hs * 0.05)
		var col := Color("#ff2fd0") if i % 3 == 0 else tint
		node.draw_rect(Rect2(size.x * side, y, size.x * 0.04, h),
			Color(col, 0.22 * on), true)


## Clouds. Cumulus crossing at three depths. Nothing rises, nothing falls — the
## board is already in the sky, and the only honest motion up there is wind.
##
## ## Why this one had to be rebuilt
##
## The first version was three overlapping white discs at five percent alpha,
## which is a perfectly good cloud over a dark backdrop and nothing at all over
## this one. Clouds is the only board whose art is already white, and white at
## five percent on white is invisible — the effect was running the whole time
## and could not be seen.
##
## So it stopped painting with brightness and started painting with *shape*.
## Each cloud now carries a shaded underside as well as a lit top: the shadow is
## what reads against a bright sky, and it is what makes the thing look like a
## cumulus with a bottom to it rather than a smudge. The alpha is up by roughly
## three times, which it can afford to be now that the darker half is doing the
## work.
static func _motion_drift(node: CanvasItem, size: Vector2, t: float,
		tint: Color, bound := false) -> void:
	# Far masses first: very large, very slow, very faint. They are the reason
	# the sky reads as deep rather than as a flat plate with clouds on it.
	if not bound:
		for i in 3:
			var hb := _hash01(i, 20.0)
			var bx: float = fmod(hb * size.x * 1.6 + t * 3.5, size.x + size.x * 0.7) \
				- size.x * 0.35
			var by: float = size.y * (0.10 + hb * 0.62)
			var br: float = size.x * (0.26 + hb * 0.16)
			node.draw_circle(Vector2(bx, by), br, Color(1, 1, 1, 0.045))
			node.draw_circle(Vector2(bx + br * 0.55, by + br * 0.18), br * 0.72,
				Color(1, 1, 1, 0.045))

	for i in 11:
		var hx := _hash01(i, 10.0)
		var hy := _hash01(i, 11.0)
		var hr := _hash01(i, 21.0)
		var depth := float(i % 3)
		var speed: float = 5.0 + depth * 11.0
		var r: float = size.x * (0.042 + hr * 0.040) * (0.72 + depth * 0.34)
		# On a screen a cloud enters from beyond the edge; in a panel it wraps
		# inside one, which costs the entrance and keeps the wind.
		var edge: float = r * 2.6 if not bound else 0.0
		var span: float = size.x + edge * 2.0
		var x: float = fmod(hx * span + t * speed, span) - edge
		# Bobbing, barely. A cloud that only ever translates sideways reads as a
		# sprite on a rail.
		var y: float = hy * size.y + sin(t * 0.32 + float(i) * 1.7) * r * 0.16
		var lift: float = 0.45 + depth * 0.28

		# Five lobes along a shallow arc with a flat base, rather than three in a
		# row. The flat bottom is most of what separates a cumulus from a
		# caterpillar.
		var lobes := [
			[-1.05, 0.16, 0.62], [-0.48, -0.16, 0.86], [0.08, -0.26, 1.0],
			[0.66, -0.06, 0.80], [1.16, 0.18, 0.58],
		]
		# The shaded underside, offset down. Drawn first so the lit lobes sit on
		# top of it and only its lower edge shows — which is how a shadow works.
		var shade := Color(0.42, 0.52, 0.68).lerp(tint, 0.25)
		for l: Array in lobes:
			node.draw_circle(
				Vector2(x + r * float(l[0]), y + r * float(l[1]) + r * 0.22),
				r * float(l[2]), Color(shade, 0.085 * lift))
		var lit := Color.WHITE.lerp(tint, 0.10)
		for l: Array in lobes:
			node.draw_circle(
				Vector2(x + r * float(l[0]), y + r * float(l[1])),
				r * float(l[2]), Color(lit, 0.13 * lift))
		# A bright crown on the two tallest lobes, where the sun would be.
		for l: Array in [lobes[1], lobes[2]]:
			node.draw_circle(
				Vector2(x + r * float(l[0]), y + r * float(l[1]) - r * 0.16),
				r * float(l[2]) * 0.55, Color(1, 1, 1, 0.10 * lift))


## Desert. Heat coming off the sand: bands near the bottom that wobble, and dust
## hanging in the air above them. Strongest low down, where the ground is.
static func _motion_haze(node: CanvasItem, size: Vector2, t: float,
		tint: Color) -> void:
	for i in 12:
		var f := float(i) / 11.0
		# Low bands shimmer hard, high ones barely — heat rises off the floor,
		# not out of the sky.
		var ground: float = f * f
		var base: float = size.y * (0.42 + f * 0.58)
		var pts := PackedVector2Array()
		for s in 11:
			var u := float(s) / 10.0
			pts.append(Vector2(u * size.x,
				base + sin(u * 9.0 + t * 2.1 + float(i) * 0.8) * (2.0 + 6.0 * ground)))
		node.draw_polyline(pts, Color(1.0, 0.86, 0.58, 0.030 * ground + 0.010),
			3.0 + 3.0 * ground, true)

	for i in 22:
		var hx := _hash01(i, 12.0)
		var hs := _hash01(i, 13.0)
		var y: float = size.y - fmod(t * (10.0 + hs * 22.0) + hx * 900.0, size.y * 0.9)
		var x: float = fmod(hx * size.x + t * (6.0 + hs * 10.0), size.x)
		node.draw_circle(Vector2(x + sin(t * 0.8 + float(i)) * 9.0, y),
			1.0 + hs * 2.0, Color(tint, 0.14 + 0.10 * sin(t * 1.4 + float(i))))


## Aurora. Ribbons across the upper sky, each a band whose top and bottom edges
## wave out of phase with each other — that shear is what makes it a curtain
## rather than a snake.
static func _motion_ribbons(node: CanvasItem, size: Vector2, t: float,
		tint: Color) -> void:
	var cols := [tint, Color("#7cf6a0"), Color("#5ad0ff")]
	for i in 3:
		var base: float = size.y * (0.10 + float(i) * 0.085)
		var thick: float = size.y * (0.055 + 0.02 * float(i))
		var phase: float = t * (0.45 + float(i) * 0.12) + float(i) * 2.1
		var top := PackedVector2Array()
		var bottom := PackedVector2Array()
		for s in 15:
			var u := float(s) / 14.0
			var x: float = u * size.x
			var wave: float = sin(u * 4.4 + phase) * size.y * 0.035 \
				+ sin(u * 9.1 - phase * 1.4) * size.y * 0.012
			top.append(Vector2(x, base + wave))
			# The lower edge runs on its own phase, so the ribbon widens and
			# narrows along its length instead of sliding about rigidly.
			bottom.append(Vector2(x, base + wave + thick
				* (0.6 + 0.6 * sin(u * 3.2 - phase * 0.8))))
		var poly := PackedVector2Array()
		poly.append_array(top)
		for s in range(bottom.size() - 1, -1, -1):
			poly.append(bottom[s])
		var a: float = 0.055 + 0.030 * sin(t * 0.7 + float(i) * 1.9)
		node.draw_colored_polygon(poly, Color(cols[i], a))
		# A brighter lower lip, which is where a real one is densest.
		node.draw_polyline(bottom, Color(cols[i], a * 1.6), 2.0, true)


## Nexus. Motes of light rising off the plaza, and the ring overhead breathing.
##
## The picture already has the drama in it — a portal, a sun, a mile of cloud —
## so this stays quiet on purpose. A backdrop that is doing a lot needs less
## moving on top of it, not more: the job here is to stop it being a still, not
## to compete with it.
static func _motion_aether(node: CanvasItem, size: Vector2, t: float,
		tint: Color, bound := false) -> void:
	# The ring. A slow swell at the top third, roughly where the painting puts
	# its portal, so the two read as the same object. Skipped when bounded —
	# whole, in a preview panel, it is a circle floating in the middle of a
	# photograph that already has one.
	if not bound:
		var at := Vector2(size.x * 0.5, size.y * 0.24)
		var swell: float = 0.5 + 0.5 * sin(t * 0.55)
		for i in 3:
			var f := float(i) / 2.0
			node.draw_arc(at, size.x * (0.26 + f * 0.05 + swell * 0.012),
				0.0, TAU, 72,
				Color(tint, (0.045 - f * 0.012) * (0.45 + 0.55 * swell)),
				2.0 + (1.0 - f) * 2.0, true)

	# Motes. Rising, drifting, and fading out near the top rather than wrapping
	# hard — these are embers' gentler cousin and a hard wrap would read as a
	# loop where embers reads as a fire.
	for i in 46:
		var hx := _hash01(i, 22.0)
		var hs := _hash01(i, 23.0)
		var climb: float = fmod(t * (0.055 + hs * 0.075) + hx, 1.0)
		var y: float = size.y * (1.02 - climb * 1.06)
		var x: float = hx * size.x + sin(t * 0.7 + float(i) * 1.3) * size.x * 0.035
		var r: float = 1.1 + hs * 2.4
		# Brightest in the middle of the climb: born dim off the floor, spent by
		# the time it reaches the sky.
		var life: float = sin(climb * 3.14159)
		var twinkle: float = 0.55 + 0.45 * sin(t * 2.2 + float(i) * 2.7)
		node.draw_circle(Vector2(x, y), r,
			Color(Color.WHITE.lerp(tint, 0.55), 0.42 * life * twinkle))

	# Two shafts leaning in from the upper corners, on a long cycle, which is
	# what ties the motes to the light source above them.
	if not bound:
		for i in 2:
			var side: float = 0.16 + float(i) * 0.68
			var lean: float = sin(t * 0.21 + float(i) * 2.0) * size.x * 0.04
			var wide: float = size.x * 0.10
			var a: float = 0.030 + 0.018 * sin(t * 0.37 + float(i) * 1.6)
			node.draw_colored_polygon(PackedVector2Array([
				Vector2(size.x * side + lean - wide * 0.3, 0.0),
				Vector2(size.x * side + lean + wide * 0.3, 0.0),
				Vector2(size.x * side + lean + wide * 1.4, size.y * 0.82),
				Vector2(size.x * side + lean - wide * 0.5, size.y * 0.82),
			]), Color(1.0, 0.94, 0.78, a))


# ---------------------------------------------------------------- characters
#
# Who is sending the emote.
#
# There was a cosmetic slot here once that *tinted* the emotes — the art was
# drawn white and a style was a single multiply. BloqBot arrived already
# coloured and that slot died with it, as the note further down records. This
# is not that slot coming back. A character is a whole different set of
# drawings rather than a filter over one set, which is the difference between
# six recolours nobody could tell apart and two performers.
#
# Three things vary and they are all here rather than in `game.gd`, because all
# three are art direction: which sheet plays for which feeling, where the head
# sits in the frame, and what colour sits behind the character to lift it off a
# dark panel.
#
# ## Why the wire indices are the keys
#
# What crosses the network for an emote is an integer, and it means a *feeling*
# — 3 is anger whoever is expressing it. So each character maps those same
# indices onto its own drawings, and two players running different characters
# see their own performer play the emote the other one sent. A character that
# renumbered anything here would be a character that sends the wrong feeling.

const CHARACTERS := {
	"bloqbot": {
		"name": "BloqBot",
		# Seven feelings, seven sets. `frames` and `cols` describe the grid
		# `tools/build_emotes.py` packed; the script prints them.
		"anim": {
			0: {"sheet": "bot_excited", "frames": 24, "cols": 6},
			1: {"sheet": "bot_cry", "frames": 18, "cols": 6},
			2: {"sheet": "bot_shocked", "frames": 18, "cols": 6},
			3: {"sheet": "bot_mad", "frames": 18, "cols": 6},
			4: {"sheet": "bot_love", "frames": 18, "cols": 6},
			7: {"sheet": "bot_hype", "frames": 18, "cols": 6},
			8: {"sheet": "bot_dead", "frames": 18, "cols": 6},
		},
		# Where the head is in a frame, for the key legend — see the note on
		# `EMOTE_KEY_HEAD` in `game.gd` for why the key is cropped at all.
		"head": Rect2(0.24, 0.10, 0.54, 0.54),
		# Off its own visor. It has to be *its* blue rather than the UI purple,
		# because what this separates is a navy character whose ink is #0b1220
		# from a panel that bottoms out at #0b1020.
		"glow": "#68c4e0",
	},
	# An angry duck. Five sets against BloqBot's seven, so two of them answer
	# two feelings each.
	#
	# The pairings are not arbitrary and are worth writing down, because the
	# obvious reading of the folder names gets one of them wrong. "Wait" is not
	# an idle — it is arms folded and scowling, which is the angriest thing he
	# does, so it takes 3 rather than sitting unused while anger borrowed the
	# shocked face. Victory doubles for nice because both are him pleased with
	# himself; Exhausted doubles for dead because both are him spent.
	#
	# If an angry set and a love set are ever drawn, 3 and 4 are the two lines
	# to change and nothing else moves.
	"waddles": {
		"name": "Waddles",
		"anim": {
			0: {"sheet": "duck_victory", "frames": 24, "cols": 6},
			1: {"sheet": "duck_exhausted", "frames": 24, "cols": 6},
			2: {"sheet": "duck_shocked", "frames": 24, "cols": 6},
			3: {"sheet": "duck_wait", "frames": 24, "cols": 6},
			4: {"sheet": "duck_victory", "frames": 24, "cols": 6},
			7: {"sheet": "duck_dance", "frames": 24, "cols": 6},
			8: {"sheet": "duck_exhausted", "frames": 24, "cols": 6},
		},
		"head": Rect2(0.26, 0.04, 0.50, 0.50),
		# Amber rather than his own yellow. The halo's job is to seat him
		# against the panel, and a yellow glow behind a yellow bird is a
		# smudge with a duck in the middle of it.
		"glow": "#e0902c",
	},
}


static func character(id: String) -> Dictionary:
	return CHARACTERS.get(id, CHARACTERS["bloqbot"])


static func character_anim(id: String) -> Dictionary:
	return character(id)["anim"]


static func character_head(id: String) -> Rect2:
	return character(id)["head"]


static func character_glow(id: String) -> Color:
	return Color(String(character(id)["glow"]))


# ------------------------------------------------------------- the block face
#
# The four block styles, drawn somewhere that is not the playfield.
#
# The menu is built out of branded blocks, so the equipped block style has to
# reach it — otherwise "Wireframe" repaints the thing you look at during a match
# and leaves the thing you look at between matches alone, which is exactly the
# half-measure that made a theme feel like a filter.
#
# Deliberately a separate implementation from `board.gd`, because that one is
# tuned to cell-sized tiles: its bevel, its trace spacing and its type ramp are
# all in units of CELL. This one is tuned to a menu gutter. What they share is
# the vocabulary and the style ids, and `shoptest` checks that neither grows a
# style the other has never heard of.

## The four originals, then the eight that came with the painted boards.
##
## Every one of them is handed the block's *tier* colour and has to give it
## back recognisably. That is the rule the whole slot lives under: a 4x3 is red
## and a 1x1 is blue in every style the game has, because the colour is how you
## read the board at a glance and a style that repainted it would be selling
## decoration for legibility. So these change the material — crust, glass, ice,
## neon — and never the hue.
const BLOCK_STYLES := ["solid", "outline", "glass", "circuit",
	"bark", "magma", "coral", "nebula", "neon", "cloud", "sandstone", "ice",
	"rune"]

## The eight that arrive with the premium boards, and the board each was drawn
## against. Only used for presentation — the slot stays independent, and nothing
## stops Magma blocks on the Ocean board. The mastery screen reads this to say
## what a style was meant for, which is the difference between eight new names
## and eight new names somebody can make sense of.
const BLOCK_PAIRING := {
	"bark": "forest", "magma": "volcano", "coral": "ocean", "nebula": "space",
	"neon": "cyber", "cloud": "clouds", "sandstone": "desert", "ice": "aurora",
	"rune": "nexus",
}


## The face drawn for a board, which is `BLOCK_PAIRING` read backwards.
##
## Worth a function rather than a second dictionary, and worth a function
## rather than nothing: the table reads style-first because that is the
## question the mastery screen asks, and every other caller wants it the other
## way round. A board-keyed `.get` against it silently returns the fallback
## instead of failing, which is a bug that looks exactly like "the style did
## not apply" — so it is written once, here, where the direction is named.
static func face_for_board(theme_id: String) -> String:
	for style in BLOCK_PAIRING:
		if String(BLOCK_PAIRING[style]) == theme_id:
			return String(style)
	return ""


# Emotes used to have styles here: the art was drawn white so a style could be
# a single multiply, and the slot sold six of them. BloqBot arrived already
# coloured — navy body, cyan visor — and a multiply over that can only darken
# it, so there was nothing left for a style to do. The tint, the halo colour and
# the cosmetic slot behind them all went together. `game.gd` draws the halo in
# one fixed colour off the character's own visor.


## Paint one, and report what colour its label should be — the ink has to be
## decided per style rather than assumed dark, because two of the four are
## mostly transparent.
## `key` identifies the block for the patterned faces; see `_face_seed`. Every
## caller that draws a face on something which can move — a menu plate on a
## scrolling screen, a preview swatch that shifts when the panel resizes — has
## to pass one, or the pattern re-rolls as it moves. Anything static may leave
## it and be seeded from its own rect.
static func draw_block_face(node: CanvasItem, rect: Rect2, col: Color,
		style: String, hot: bool, key: float = -1.0) -> Color:
	match style:
		"outline":
			node.draw_rect(rect, Color(col, 0.10), true)
			node.draw_rect(rect, Color(col.lightened(0.2) if not hot else Color.WHITE,
				0.95), false, 2.0 if not hot else 3.0)
			node.draw_rect(rect.grow(-5.0), Color(col, 0.35), false, 1.0)
			return col.lightened(0.55)
		"glass":
			node.draw_rect(rect, Color(col, 0.34), true)
			node.draw_rect(Rect2(rect.position + Vector2(3, 3),
				Vector2(rect.size.x - 6.0, rect.size.y * 0.38)),
				Color(1, 1, 1, 0.13), true)
			node.draw_rect(rect, Color(col.lightened(0.4) if not hot else Color.WHITE,
				0.9), false, 2.0 if not hot else 3.0)
			return Color.WHITE
		"circuit":
			node.draw_rect(rect, Color(col, 0.92 if hot else 0.80), true)
			var pad := rect.get_center()
			var span: float = minf(rect.size.x, rect.size.y) * 0.5 - 4.0
			for i in 4:
				var a := TAU * float(i) / 4.0 + 0.6
				var out := pad + Vector2(cos(a), sin(a)) * span
				node.draw_line(pad, out, Color(0, 0, 0, 0.30), 2.0)
				node.draw_circle(out, 2.5, Color(0, 0, 0, 0.35))
			node.draw_circle(pad, 7.0, Color(0, 0, 0, 0.22))
			return Color("#0b1020")
		"bark", "magma", "coral", "nebula", "neon", "cloud", "sandstone", "ice", \
				"rune":
			return draw_premium_face(node, rect, col, style, hot, key)
		_:
			node.draw_rect(rect, Color(col, 0.92 if hot else 0.80), true)
			# The lighter top edge is most of what makes a filled rectangle read
			# as a block with a face rather than as a swatch.
			node.draw_rect(Rect2(rect.position + Vector2(4.0, 4.0),
				Vector2(rect.size.x - 8.0, 2.0)), Color(1, 1, 1, 0.30), true)
			node.draw_rect(rect.grow(-5.0), Color(1, 1, 1, 0.10), false, 1.0)
			return Color("#0b1020")


# ------------------------------------------------------- the premium block set
#
# Eight faces drawn against the eight painted boards, and the one place they are
# implemented.
#
# The four originals above are written twice on purpose — `board.gd` has its own
# copy tuned to a 42px cell, this one is tuned to a menu gutter, and the note up
# there explains why that was the right trade for them. It is not the right
# trade for eight more: sixteen implementations of eight styles is eight chances
# for the block you bought to look like something else in the shop than it does
# in the match. So these are scale-derived instead — every number below is a
# fraction of the rect it is given — and `board.gd` calls straight into here.
#
# Three of them move. Magma's cracks breathe, Coral's bubbles rise and Neon's
# scan bar sweeps, all read off `Time` rather than off any state, so a block
# that was drawn this frame and destroyed the next never had anything to clean
# up. Both callers already redraw every frame, so the motion costs nothing extra
# to keep running.


## The block's silhouette: a rectangle with its corners taken off, which is as
## close to a rounded corner as immediate-mode drawing gets without allocating a
## StyleBoxFlat per tier per frame.
static func _face_body(node: CanvasItem, rect: Rect2, col: Color) -> void:
	var cut: float = clampf(minf(rect.size.x, rect.size.y) * 0.16, 3.0, 9.0)
	var a := rect.position
	var b := rect.end
	node.draw_colored_polygon(PackedVector2Array([
		Vector2(a.x + cut, a.y), Vector2(b.x - cut, a.y),
		Vector2(b.x, a.y + cut), Vector2(b.x, b.y - cut),
		Vector2(b.x - cut, b.y), Vector2(a.x + cut, b.y),
		Vector2(a.x, b.y - cut), Vector2(a.x, a.y + cut),
	]), col)


## The rim. White when the block is one the typed word is about to take, which
## has to stay true in every style — that highlight is the game telling you your
## word landed, and a style that muted it would be a style that costs points.
static func _face_rim(node: CanvasItem, rect: Rect2, col: Color, hot: bool,
		width := 2.0) -> void:
	node.draw_rect(rect, Color.WHITE if hot else col, false,
		width + (1.0 if hot else 0.0))


## A per-block constant in 0..1. `base` identifies the block and `k` salts it,
## so one block can carry several independent numbers.
##
## `base` must be something that does not change while the block is on screen,
## which is the whole reason it is a parameter rather than being taken from the
## rect. This used to hash `rect.position`, and a falling block's rect position
## is the one thing about it that changes every frame — so Magma's seams,
## Coral's bubbles and Nebula's stars all re-rolled sixty times a second on the
## way down, which read as the surface boiling. `board.gd` passes `Blk.art`;
## the menu, where nothing moves, passes its rect and is none the wiser.
static func _face_seed(base: float, k: float) -> float:
	return absf(fmod(sin(base * 0.137 + k * 4.77) * 9137.3, 1.0))


static func draw_premium_face(node: CanvasItem, rect: Rect2, col: Color,
		style: String, hot: bool, key: float = -1.0) -> Color:
	var t := Time.get_ticks_msec() / 1000.0
	var w := rect.size.x
	var h := rect.size.y
	var mid := rect.get_center()
	# Who this block is, for the patterned faces. A caller that has a stable id
	# for the block passes it; one that does not falls back to where the block
	# is, which is correct anywhere the block is not moving.
	var base: float = key * 7.31 if key >= 0.0 \
		else rect.position.x + rect.position.y * 2.27

	match style:
		# Forest. Heartwood with the grain running across it and a cut top edge,
		# so a stack of them reads as sawn timber rather than as tiles.
		"bark":
			_face_body(node, rect, Color(col.darkened(0.18), 0.92 if hot else 0.86))
			node.draw_rect(Rect2(rect.position + Vector2(w * 0.10, h * 0.09),
				Vector2(w * 0.80, maxf(1.5, h * 0.05))), Color(1, 1, 1, 0.22), true)
			var grain := Color(col.darkened(0.45), 0.55)
			for i in 3:
				var y: float = rect.position.y + h * (0.32 + float(i) * 0.21)
				var bow: float = h * 0.035 * (1.0 if i % 2 == 0 else -1.0)
				node.draw_polyline(PackedVector2Array([
					Vector2(rect.position.x + w * 0.10, y),
					Vector2(mid.x, y + bow),
					Vector2(rect.end.x - w * 0.10, y),
				]), grain, maxf(1.0, h * 0.030), true)
			_face_rim(node, rect, Color(col.lightened(0.30), 0.9), hot)
			return Color("#10200f")

		# Volcano. Cooled crust with the heat still moving underneath it.
		#
		# The first version drew a straight vertical line with three straight
		# horizontal ones crossing it, and at cell size that is not a crack, it
		# is scaffolding laid on a flat tile. Two things were wrong and both
		# were structural: a crack in cooling rock is never straight, and the
		# glow belongs *in* the gap rather than painted over the surface.
		#
		# So the face is built the way the backdrop art is — irregular plates
		# with lit seams between them. The seams wander, each is drawn as a wide
		# dim bleed with a narrow bright core inside it, and the plates either
		# side sit at different darknesses so the crust has facets instead of
		# being one flat wash.
		"magma":
			# Darkened enough to read as crust and not so far that a red 4x3 and
			# a blue 1x1 become the same brown tile. A board you cannot read by
			# tier is a board that costs somebody the word they were about to
			# type.
			_face_body(node, rect, Color(col.darkened(0.46), 0.95))
			var beat: float = 0.55 + 0.45 * sin(t * 1.9 + _face_seed(base, 1.0) * TAU)
			# Pulled toward lava rather than left as a lightened tier colour.
			# `col.lightened(0.55)` on a cyan tier is very nearly white, and a
			# white line across a block reads as a scratch, not as something
			# glowing underneath it. The body keeps the tier — that is where the
			# colour has to survive — and the seam is allowed to be hot.
			# Three quarters of the way to lava. At 0.62 a cyan tier came out tan
			# and the seams read as roads across the block; the tier still has to
			# survive, but it survives in the crust, not in the fire.
			var hotcol: Color = col.lightened(0.30).lerp(Color("#ff6a10"), 0.78)
			var core: Color = hotcol.lightened(0.42)

			# Facets. Two wedges of crust at different darknesses, anchored to
			# the corners so they read as plates rather than as blobs floating
			# on the face.
			var f0 := _face_seed(base, 11.0)
			var f1 := _face_seed(base, 12.0)
			node.draw_colored_polygon(PackedVector2Array([
				rect.position,
				rect.position + Vector2(w * (0.42 + f0 * 0.22), 0.0),
				rect.position + Vector2(w * (0.26 + f1 * 0.18),
					h * (0.52 + f0 * 0.16)),
				rect.position + Vector2(0.0, h * 0.68),
			]), Color(col.darkened(0.34), 0.55))
			node.draw_colored_polygon(PackedVector2Array([
				Vector2(rect.end.x, rect.position.y + h * (0.18 + f1 * 0.16)),
				rect.end,
				Vector2(rect.position.x + w * (0.44 + f1 * 0.20), rect.end.y),
				Vector2(rect.position.x + w * (0.62 + f0 * 0.16),
					rect.position.y + h * (0.46 + f1 * 0.14)),
			]), Color(col.darkened(0.60), 0.50))

			# Two seams that wander, one down the block and one across it, so a
			# pair never reads as two parallel scratches.
			for s in 2:
				var sd := _face_seed(base, 13.0 + float(s) * 3.0)
				var pts := PackedVector2Array()
				var steps := 5
				for k in steps + 1:
					var u := float(k) / float(steps)
					var ax := 0.0
					var ay := 0.0
					if s == 0:
						ax = w * (0.26 + sd * 0.44) + w * 0.20 * (u - 0.5) * 2.0
						ay = h * u
					else:
						ax = w * u
						ay = h * (0.32 + sd * 0.36) + h * 0.22 * sin(u * 3.1 + sd * 6.0)
					# The wander, hashed per point, so a seam has a shape that
					# belongs to this block and does not redraw itself each frame.
					var jig: float = _face_seed(base, 30.0 + float(s) * 7.0 + float(k)) - 0.5
					if s == 0:
						ax += jig * w * 0.20
					else:
						ay += jig * h * 0.18
					pts.append(Vector2(
						clampf(rect.position.x + ax, rect.position.x + 1.0,
							rect.end.x - 1.0),
						clampf(rect.position.y + ay, rect.position.y + 1.0,
							rect.end.y - 1.0)))
				# The bleed, then the core inside it. Two passes is what makes a
				# line read as something glowing up through a gap rather than as
				# a stroke drawn on top of the surface.
				node.draw_polyline(pts, Color(hotcol, 0.11 + 0.08 * beat),
					maxf(3.0, minf(w, h) * 0.20), true)
				node.draw_polyline(pts, Color(hotcol, 0.50 + 0.30 * beat),
					maxf(1.4, minf(w, h) * 0.075), true)
				# And a thread of white heat down the middle of the core, which
				# is what stops a wide warm line reading as a painted stripe.
				node.draw_polyline(pts, Color(core, 0.55 + 0.35 * beat),
					maxf(1.0, minf(w, h) * 0.028), true)

			_face_rim(node, rect, Color(col.lightened(0.15), 0.95), hot)
			return Color(col.lightened(0.85))

		# Ocean. A rounded, slightly soft body with air coming off the top of it.
		"coral":
			_face_body(node, rect, Color(col, 0.80 if hot else 0.70))
			# Lobes along the top, which is what stops it reading as a pill.
			var lobe: float = minf(w * 0.18, h * 0.22)
			for i in 3:
				node.draw_circle(Vector2(rect.position.x + w * (0.25 + float(i) * 0.25),
					rect.position.y + lobe * 0.55), lobe,
					Color(col.lightened(0.28), 0.55))
			for i in 3:
				var hb := _face_seed(base, 5.0 + float(i))
				var rise: float = fmod(t * (0.35 + hb * 0.30) + hb, 1.0)
				var bx: float = rect.position.x + w * (0.18 + hb * 0.64)
				var by: float = rect.end.y - h * 0.12 - rise * h * 0.72
				node.draw_arc(Vector2(bx, by), maxf(1.2, minf(w, h) * 0.055),
					0.0, TAU, 9, Color(1, 1, 1, 0.45 * (1.0 - rise)), 1.2, true)
			_face_rim(node, rect, Color(col.lightened(0.45), 0.9), hot)
			return Color.WHITE

		# Space. Thin enough to see through, with a field of stars caught inside
		# it and a bloom at the middle.
		"nebula":
			# Opaque enough to carry its tier. At 0.48 over a purple backdrop
			# every tier arrived the same lilac, which is the nebula eating the
			# one thing the block had to say.
			_face_body(node, rect, Color(col, 0.78 if not hot else 0.90))
			for i in 3:
				var f := float(i) / 2.0
				node.draw_circle(mid, minf(w, h) * (0.16 + f * 0.26),
					Color(col.lightened(0.40), 0.13 * (1.0 - f)))
			for i in 7:
				var sx := _face_seed(base, 7.0 + float(i))
				var sy := _face_seed(base, 17.0 + float(i))
				var tw: float = 0.45 + 0.55 * sin(t * (1.4 + sx * 2.0) + float(i) * 1.7)
				node.draw_circle(Vector2(rect.position.x + w * (0.12 + sx * 0.76),
					rect.position.y + h * (0.12 + sy * 0.76)),
					maxf(0.8, minf(w, h) * 0.030), Color(1, 1, 1, 0.70 * tw))
			_face_rim(node, rect, Color(col.lightened(0.50), 0.95), hot)
			return Color.WHITE

		# Cyber. Housing almost black, edge doing all the work, and a bar
		# crawling down the inside of it.
		"neon":
			# A dark housing, but a *tinted* dark one. At 0.82 darkened the six
			# tiers were six shades of black and the edge was the only thing
			# telling them apart, which is too little to read a stack by at a
			# glance.
			_face_body(node, rect, Color(col.darkened(0.55), 0.90))
			_face_body(node, rect.grow(-minf(w, h) * 0.14), Color(col, 0.28))
			var glow := col.lightened(0.35)
			var sweep: float = fmod(t * 0.55 + _face_seed(base, 9.0), 1.0)
			var bar_h: float = maxf(2.0, h * 0.14)
			node.draw_rect(Rect2(rect.position.x + 2.0,
				rect.position.y + sweep * (h - bar_h), w - 4.0, bar_h),
				Color(glow, 0.20), true)
			# Corner ticks, so the housing reads as a machined part rather than
			# as a rectangle somebody drew a line around.
			var tick: float = minf(w, h) * 0.22
			for c: Vector2 in [Vector2(rect.position.x, rect.position.y),
					Vector2(rect.end.x, rect.position.y),
					Vector2(rect.position.x, rect.end.y),
					Vector2(rect.end.x, rect.end.y)]:
				var sx: float = 1.0 if c.x < mid.x else -1.0
				var sy: float = 1.0 if c.y < mid.y else -1.0
				var o: Vector2 = c + Vector2(sx, sy) * 3.0
				node.draw_line(o, o + Vector2(sx * tick, 0.0), Color(glow, 0.85), 2.0)
				node.draw_line(o, o + Vector2(0.0, sy * tick), Color(glow, 0.85), 2.0)
			node.draw_rect(rect, Color(col, 0.35), false, 3.0)
			_face_rim(node, rect, Color(glow, 0.95), hot, 1.5)
			return col.lightened(0.62)

		# Clouds. The one soft face in the set, and the second of the two that
		# print dark type — the body is too pale for white to survive on it.
		#
		# The first version was the flat body with three white circles sitting
		# on top of it, and three circles on a rectangle is a diagram of a cloud
		# rather than a cloud. What was missing was not more lobes, it was
		# *light*: a cumulus is legible because it is bright where the sun hits
		# the top and blue-grey underneath where it does not, and nothing in a
		# ring of same-coloured discs says which way is up.
		#
		# So this is built as a lit object. A vertical ramp from shaded base to
		# bright crown does most of the work, the lobes are cut into the top
		# edge rather than stuck above it, and the underside carries a cool band
		# that is the single strongest cue that the thing has volume.
		"cloud":
			_face_body(node, rect, Color(col, 0.86 if not hot else 0.94))

			# The ramp. Fourteen bands rather than six: at six the steps were
			# plainly visible as stripes across the face, and stripes are the
			# specific thing that made this read as cheap. Same total lift,
			# spread thin enough that the eye reads a gradient.
			for i in 14:
				var f := float(i) / 13.0
				node.draw_rect(Rect2(rect.position.x + 1.0,
					rect.position.y + f * h, w - 2.0, h / 14.0 + 1.0),
					Color(1, 1, 1, 0.115 * (1.0 - f) * (1.0 - f)))
			# And the cool underside, which is what stops it reading as a tile
			# with a gradient on it.
			var under := Color(0.34, 0.45, 0.63)
			for i in 6:
				var f2 := float(i) / 5.0
				node.draw_rect(Rect2(rect.position.x + 1.0,
					rect.end.y - h * 0.34 + f2 * h * 0.34,
					w - 2.0, h * 0.34 / 6.0 + 1.0),
					Color(under, 0.035 + 0.075 * f2 * f2))

			# Lobes along the top, each a disc sitting *on* the top edge so its
			# lower half is inside the block and its upper half is the bulge.
			#
			# Every one is a different size and sits at a slightly different
			# height, taken from the block's own seed. Evenly spaced discs of
			# equal radius are a doily, not a cumulus, and that regularity was
			# the other half of what looked cheap — a real one is lumpy, and
			# the lumpiness has to belong to the block so it does not crawl
			# while the block falls.
			var lobe: float = clampf(minf(w * 0.19, h * 0.34), 3.5, 15.0)
			var n := maxi(3, int(w / maxf(lobe * 1.15, 1.0)))
			for i in n:
				var u: float = (float(i) + 0.5) / float(n)
				var hs := _face_seed(base, 40.0 + float(i))
				var hv := _face_seed(base, 60.0 + float(i))
				# Bigger in the middle of the block, as a mass piles up.
				var rise: float = (0.70 + 0.30 * sin(u * 3.14159)) * (0.72 + hs * 0.56)
				var at := Vector2(
					rect.position.x + w * u + (hv - 0.5) * lobe * 0.30,
					rect.position.y + lobe * (0.16 + hv * 0.34))
				node.draw_circle(at, lobe * rise, Color(1, 1, 1, 0.24))
				# A brighter cap on the upper half, which is the part a real one
				# catches the light on.
				node.draw_circle(at - Vector2(0.0, lobe * rise * 0.30),
					lobe * rise * 0.58, Color(1, 1, 1, 0.22))

			# A second, smaller row tucked below and between the first, so the
			# top edge has depth instead of being one scalloped line.
			for i in maxi(2, n - 1):
				var u2: float = (float(i) + 1.0) / float(maxi(2, n - 1) + 1)
				var hs2 := _face_seed(base, 80.0 + float(i))
				node.draw_circle(
					Vector2(rect.position.x + w * u2,
						rect.position.y + lobe * (0.86 + hs2 * 0.30)),
					lobe * (0.40 + hs2 * 0.26), Color(1, 1, 1, 0.13))

			# And a couple bulging out of the base, so the silhouette is not a
			# cloud sitting on a brick.
			for i in 2:
				var ub: float = 0.28 + float(i) * 0.44
				var hb := _face_seed(base, 90.0 + float(i))
				node.draw_circle(
					Vector2(rect.position.x + w * ub, rect.end.y - lobe * 0.24),
					lobe * (0.50 + hb * 0.34), Color(under, 0.13))

			_face_rim(node, rect, Color(1, 1, 1, 0.80), hot)
			return Color("#16324f")

		# Desert. Laid-down strata, thickest at the bottom, which is the one
		# style in the set that says something about which way is up.
		"sandstone":
			_face_body(node, rect, Color(col, 0.90 if hot else 0.84))
			var bands := 4
			for i in bands:
				var f := float(i) / float(bands)
				var y: float = rect.position.y + h * (0.16 + f * 0.74)
				var thick: float = maxf(1.5, h * (0.045 + f * 0.030))
				var shade := Color(1, 1, 1, 0.14) if i % 2 == 0 \
					else Color(0, 0, 0, 0.16)
				node.draw_rect(Rect2(rect.position.x + w * 0.06, y,
					w * 0.88, thick), shade, true)
			node.draw_rect(Rect2(rect.position + Vector2(w * 0.08, h * 0.07),
				Vector2(w * 0.84, maxf(1.5, h * 0.045))), Color(1, 1, 1, 0.26), true)
			_face_rim(node, rect, Color(col.darkened(0.30), 0.9), hot)
			return Color("#2a1405")

		# Nexus. Cut stone with a glyph lit into the face of it — the boards in
		# the painting are masonry with gold worked through the joints, and this
		# is that at tile size.
		"rune":
			_face_body(node, rect, Color(col.darkened(0.30), 0.93))
			var gold := Color("#ffc850")
			var pulse: float = 0.5 + 0.5 * sin(t * 1.15
				+ _face_seed(base, 50.0) * TAU)
			# Masonry: two courses split by a joint, each a slightly different
			# darkness, so the block reads as cut rather than cast.
			#
			# The joint sits in the upper third rather than across the middle.
			# Centred it landed exactly where the stamp is and read as a line
			# struck through the letters — the block is a label first and a
			# piece of stonework second.
			var split: float = 0.20 + _face_seed(base, 51.0) * 0.14
			node.draw_rect(Rect2(rect.position.x + 1.0, rect.position.y + 1.0,
				w - 2.0, h * split), Color(1, 1, 1, 0.07), true)
			node.draw_rect(Rect2(rect.position.x + 1.0,
				rect.position.y + h * split - 1.0, w - 2.0,
				maxf(1.0, h * 0.02)), Color(0, 0, 0, 0.16), true)
			# The glyph. A ring with two chords across it, which is enough to
			# read as carved at 36px and cheap enough to draw on forty blocks.
			var gr: float = minf(w, h) * 0.26
			node.draw_arc(mid, gr, 0.0, TAU, 28,
				Color(gold, 0.30 + 0.30 * pulse), maxf(1.2, gr * 0.16), true)
			node.draw_arc(mid, gr * 0.58, 0.0, TAU, 20,
				Color(gold, 0.20 + 0.22 * pulse), maxf(1.0, gr * 0.10), true)
			for i in 2:
				var a2: float = _face_seed(base, 52.0 + float(i)) * TAU
				node.draw_line(mid + Vector2(cos(a2), sin(a2)) * gr * 1.05,
					mid - Vector2(cos(a2), sin(a2)) * gr * 1.05,
					Color(gold, 0.22 + 0.20 * pulse), maxf(1.0, gr * 0.09))
			# Gold worked into the joint, which is the motif the board is built
			# on and the thing that ties the face to the picture behind it.
			node.draw_rect(Rect2(rect.position.x + w * 0.08,
				rect.end.y - h * 0.13, w * 0.84, maxf(1.2, h * 0.035)),
				Color(gold, 0.26 + 0.18 * pulse), true)
			_face_rim(node, rect, Color(gold, 0.85), hot)
			return Color("#fff3d6")

		# Aurora. Cut glass: thin body, hard facets, a frosted double edge.
		"ice":
			# Glass, not water. 0.34 was see-through enough that the aurora
			# behind it decided the block's colour instead of the tier.
			_face_body(node, rect, Color(col, 0.62 if not hot else 0.76))
			var apex := Vector2(mid.x + w * 0.10, mid.y - h * 0.06)
			for c: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y),
					Vector2(rect.position.x, rect.end.y), rect.end]:
				node.draw_line(c.lerp(mid, 0.18), apex, Color(1, 1, 1, 0.26), 1.0)
			node.draw_colored_polygon(PackedVector2Array([
				rect.position + Vector2(w * 0.10, h * 0.10),
				rect.position + Vector2(w * 0.52, h * 0.10),
				rect.position + Vector2(w * 0.26, h * 0.42),
			]), Color(1, 1, 1, 0.20))
			node.draw_rect(rect.grow(-3.0), Color(1, 1, 1, 0.18), false, 1.0)
			_face_rim(node, rect, Color(col.lightened(0.55), 0.95), hot)
			return Color.WHITE

	return Color.WHITE
