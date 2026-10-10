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
		"font": "res://fonts/boards/BreeSerif.ttf", "font_axes": {},
		"font_scale": 1.04, "font_dy": -0.066,
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
		"font": "res://fonts/boards/Bungee.ttf", "font_axes": {},
		"font_scale": 0.95, "font_dy": 0.0,
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
		"font": "res://fonts/boards/Fredoka.ttf", "font_axes": {"wght": 600, "wdth": 100},
		"font_scale": 1.0, "font_dy": -0.019,
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
		"font": "res://fonts/boards/Orbitron.ttf", "font_axes": {"wght": 800},
		"font_scale": 0.95, "font_dy": -0.024,
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
		"font": "res://fonts/boards/ChakraPetch-Bold.ttf", "font_axes": {},
		"font_scale": 1.0, "font_dy": 0.008,
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
		"font": "res://fonts/boards/Comfortaa.ttf", "font_axes": {"wght": 700},
		"font_scale": 0.9, "font_dy": 0.067,
		"bright": true,
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
		"font": "res://fonts/boards/AlfaSlabOne.ttf", "font_axes": {},
		"font_scale": 0.9, "font_dy": 0.038,
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
		"font": "res://fonts/boards/JosefinSans.ttf", "font_axes": {"wght": 700},
		"font_scale": 1.0, "font_dy": 0.101,
	},

	# Subway: a 3D board from the start rather than a painting that became
	# one. Earned by playing three versus matches against real people; the
	# lock is its catalogue row in `Profile`, not anything here.
	#
	# Its art is a still of its own scene, which is what the previews show and
	# what `--board2d` falls back to. Red from the line's livery for the frame,
	# the platform edge's yellow for the accent, and Barlow, the house face, for
	# its lettering: a transit sign's grotesk was the right face and the game
	# already had one.
	"subway": {
		"top": "#070a14", "bottom": "#121826", "panel": "#0c1220", "panel_a": 0.44,
		"grid": "#c8d4ff", "grid_a": 0.10, "nodes": true,
		"frame": "#e8323c", "frame_a": 0.92, "frame_pulse": 0.12,
		"accent": "#ffc83a",
		"key_bg": "#141a28", "key_edge": "#e8323c", "key_ink": "#f2f4fa",
		"fire_bg": "#5a1418", "fire_edge": "#ffc83a",
		"glow": "#e8323c", "glow_a": 0.18,
		"art": "res://boards/3d/previews/subway.jpg", "art_a": 0.9, "art_dim": 0.3,
		"motion": "",
		"font": "res://fonts/BarlowSemiCondensed-Bold.ttf", "font_axes": {},
		"font_scale": 1.0, "font_dy": 0.0,
	},

	# The ninth, and the only board in the game that is not for sale.
	#
	# Nexus is the share reward — see the `shares` requirement on its
	# catalogue row. It sits in this table beside the eight paid ones because
	# it *is* one of them as far as every drawing routine is concerned: a
	# picture, a weather, a frame and a face. What differs is the lock on the
	# door, and locks live in `Profile`, not here.
	#
	# Its art is nearly square where the others are 9:16. `_draw_board_art`
	# centre-crops to the screen's own aspect, and the middle of this picture
	# is the portal, the sun and the plaza, so a phone gets the part of the
	# picture that matters.
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
		"font": "res://fonts/boards/Cinzel.ttf", "font_axes": {"wght": 800},
		"font_scale": 1.0, "font_dy": 0.048,
	},

	# Atlantis: the first board rendered rather than drawn live. The scene is
	# a picture made in Blender's path tracer, and what moves (the merman, the
	# kelp, the fish and jellyfish, the light) is added over it; see
	# `tools/blender/atlantis.py` and the plate path in `board3d.gd`.
	#
	# Sea blue for the frame, the trident's gold for the accent, and Cinzel,
	# the inscriptional face, because this is a city of carved stone. Nexus
	# uses it too, at a heavier weight.
	"atlantis": {
		"top": "#031424", "bottom": "#0a2e46", "panel": "#05202f", "panel_a": 0.42,
		"grid": "#bff4ff", "grid_a": 0.10, "nodes": true,
		"frame": "#3cc8e8", "frame_a": 0.92, "frame_pulse": 0.16,
		"accent": "#f0c060",
		"key_bg": "#082234", "key_edge": "#3cc8e8", "key_ink": "#e4f8ff",
		"fire_bg": "#1a4258", "fire_edge": "#f0c060",
		"glow": "#2aa8d8", "glow_a": 0.22,
		"art": "res://boards/3d/previews/atlantis.jpg", "art_a": 0.9, "art_dim": 0.3,
		"motion": "",
		"font": "res://fonts/boards/Cinzel.ttf", "font_axes": {"wght": 700},
		"font_scale": 1.0, "font_dy": 0.048,
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
	# The board's own lettering: block stamps, the INCOMING/SENT chips, the
	# word being typed and the keyboard. Empty keeps the house faces. Only the
	# Premium boards have one, which is part of what the pack sells.
	#
	# `font_axes` picks a weight (and width) from a variable font.
	# `font_scale` evens out cap heights against the house face, and `font_dy`
	# moves the letters down by that fraction of their size, because each face
	# sits its capitals at a different height in its line box and the game
	# centres on the box. `Fonts.for_board` bakes it into the face as a
	# baseline offset. Both were measured from the font files (cap height,
	# hhea ascent and descent), not guessed.
	"font": "", "font_axes": {}, "font_scale": 1.0, "font_dy": 0.0,
	# How hard the board's frame breathes, as a fraction of its own alpha.
	# Zero holds it at a constant brightness, which is what every painted-wash
	# theme did and should keep doing.
	"frame_pulse": 0.0,
	# Whether the picture behind the playfield is light. The block faces that
	# are mostly see-through (Wireframe, Glass) are drawn for a dark board:
	# pale ink and a pale frame, because everything behind them was dark. On a
	# light one that is pale on pale and the stamp is gone, so a board that is
	# light says so and those two faces put a pane of frost under themselves
	# and switch to dark ink. Only the playfield asks; a menu is washed in the
	# board's dark `top` whatever is equipped, so it never does.
	"bright": false,
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


# ----------------------------------------------------------- soft sprites
#
# The first versions of these effects drew with `draw_circle` and `draw_rect`,
# and that is most of why they read as basic: every shape had a hard edge. An
# ember with a hard edge is an orange dot, a star with one is a white dot, and a
# cloud made of hard discs is a stack of discs however they are arranged. Glow is
# a falloff, and immediate-mode primitives do not have one.
#
# So there are four small textures, generated once and then only ever tinted and
# scaled: a soft dot, a four-pointed glint, a cloud puff with a ragged edge, and
# a leaf. Built in code rather than shipped as files, so there is nothing to
# import, nothing to lose from an export filter, and the shapes live next to the
# effects that use them.

static var _tex_cache := {}


static func _cached(key: String, build: Callable) -> Texture2D:
	if not _tex_cache.has(key):
		_tex_cache[key] = ImageTexture.create_from_image(build.call())
	return _tex_cache[key]


## White, fading to nothing: a bright centre and a long soft tail, which is what
## reads as light rather than as paint.
static func soft_dot() -> Texture2D:
	return _cached("dot", func() -> Image:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
				var a := clampf(1.0 - d, 0.0, 1.0)
				# Two falloffs summed: a tight core and a wide halo.
				a = clampf(pow(a, 3.0) * 0.75 + pow(a, 1.6) * 0.45, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		return img)


## A star's glint: a soft core with four thin rays. Rotated slowly where it is
## drawn, the rays catch like light off something far away.
static func glint() -> Texture2D:
	return _cached("glint", func() -> Image:
		var n := 96
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var u := (x + 0.5) / n * 2.0 - 1.0
				var v := (y + 0.5) / n * 2.0 - 1.0
				var d := sqrt(u * u + v * v)
				var core := pow(clampf(1.0 - d * 2.2, 0.0, 1.0), 2.0)
				var ray_h := exp(-absf(v) * 60.0) * pow(clampf(1.0 - absf(u), 0.0, 1.0), 2.0)
				var ray_v := exp(-absf(u) * 60.0) * pow(clampf(1.0 - absf(v), 0.0, 1.0), 2.0)
				var halo := pow(clampf(1.0 - d, 0.0, 1.0), 4.0) * 0.35
				img.set_pixel(x, y, Color(1, 1, 1, clampf(core + ray_h + ray_v + halo, 0.0, 1.0)))
		return img)


## One puff of cumulus: dense in the middle, with an edge broken up by noise so a
## cluster of them reads as vapour rather than as overlapping circles.
static func cloud_puff() -> Texture2D:
	return _cached("puff", func() -> Image:
		var n := 128
		var noise := FastNoiseLite.new()
		noise.seed = 7
		noise.frequency = 0.022
		noise.fractal_octaves = 3
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var p := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5)
				var d := p.length() / (n * 0.5)
				# The noise moves the edge, not the middle.
				var edge := d + noise.get_noise_2d(x, y) * 0.22
				var a := clampf((1.0 - edge) / 0.45, 0.0, 1.0)
				a = a * a * (3.0 - 2.0 * a)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		return img)


## A leaf, pale so it can be tinted: a pointed oval with a darker midrib and a
## little shading towards the edges. Drawn along +x.
static func leaf() -> Texture2D:
	return _cached("leaf", func() -> Image:
		var w := 64
		var h := 32
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var u := (x + 0.5) / w * 2.0 - 1.0
				var v := (y + 0.5) / h * 2.0 - 1.0
				# Width along the leaf: zero at both tips, fullest a little
				# behind the middle, which is the shape of most real leaves.
				var half := pow(clampf(1.0 - u * u, 0.0, 1.0), 0.75) * (1.0 - 0.18 * u)
				var inside := half - absf(v)
				if inside <= 0.0:
					img.set_pixel(x, y, Color(1, 1, 1, 0))
					continue
				var a := clampf(inside * 10.0, 0.0, 1.0)
				var shade := 0.78 + 0.22 * clampf(inside / maxf(half, 0.001), 0.0, 1.0)
				# Midrib and a hint of veins running off it.
				if absf(v) < 0.07 and u > -0.9:
					shade *= 0.72
				elif absf(fmod(u * 4.0 + absf(v) * 2.2 + 8.0, 1.0) - 0.5) < 0.06 and absf(v) < half * 0.8:
					shade *= 0.88
				img.set_pixel(x, y, Color(shade, shade, shade, a))
		return img)


## A soft-edged shaft of light: a quad whose colour fades to nothing at both
## long edges, so it reads as a beam through haze rather than a pale trapezium.
static func _beam(node: CanvasItem, top_l: Vector2, top_r: Vector2,
		bot_r: Vector2, bot_l: Vector2, col: Color) -> void:
	var mid_t := (top_l + top_r) * 0.5
	var mid_b := (bot_l + bot_r) * 0.5
	var clear := Color(col, 0.0)
	node.draw_polygon(PackedVector2Array([top_l, mid_t, mid_b, bot_l]),
		PackedColorArray([clear, col, col, clear]))
	node.draw_polygon(PackedVector2Array([mid_t, top_r, bot_r, mid_b]),
		PackedColorArray([col, clear, clear, col]))


## A textured sprite centred on `at`, `size` across, turned by `angle`.
static func _sprite(node: CanvasItem, tex: Texture2D, at: Vector2, size: Vector2,
		col: Color, angle := 0.0) -> void:
	if angle == 0.0:
		node.draw_texture_rect(tex, Rect2(at - size * 0.5, size), false, col)
		return
	node.draw_set_transform(at, angle, Vector2.ONE)
	node.draw_texture_rect(tex, Rect2(-size * 0.5, size), false, col)
	node.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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


## Forest. Shafts of light through the canopy with dust hanging in them, and
## leaves coming down through it all.
##
## How a leaf falls is most of this effect. It does not drop; it swings — side
## to side like a pendulum, tilting into each swing and slowing at the end of it
## — and some of them tumble end over end as they go. Rectangles doing that read
## as confetti, so each one is `leaf()`, a pointed oval with a midrib, in a range
## of greens with the odd one already turning.
static func _motion_leaves(node: CanvasItem, size: Vector2, t: float,
		tint: Color, bound := false) -> void:
	var k: float = clampf(size.x / 720.0, 0.3, 1.5)
	var dot := soft_dot()
	var lf := leaf()

	# Light shafts, soft at both edges, slanting from the upper left and swaying
	# very slightly as the canopy moves.
	var sky: float = 0.0 if bound else -20.0
	for i in 3:
		var x: float = size.x * (0.10 + float(i) * 0.28)
		var sway: float = sin(t * 0.28 + float(i) * 1.3) * size.x * 0.03
		var wide: float = size.x * (0.08 + 0.025 * float(i))
		var a: float = 0.13 + 0.05 * sin(t * 0.45 + float(i))
		var slant: float = size.x * 0.22
		var bot: float = size.y
		if bound:
			slant = minf(slant, size.x - x - wide * 1.2)
		_beam(node, Vector2(x + sway - wide * 0.5, sky), Vector2(x + sway + wide * 0.5, sky),
			Vector2(x + sway + slant + wide * 1.1, bot), Vector2(x + sway + slant - wide * 0.1, bot),
			Color(1.0, 0.97, 0.80, a))

		# Dust in the beam: motes drifting on the air, glinting as they turn.
		for m in 7:
			var hm := _hash01(i * 7 + m, 40.0)
			var hn := _hash01(i * 7 + m, 41.0)
			var f: float = fmod(hn + t * (0.012 + hm * 0.02), 1.0)
			var mx: float = x + sway + slant * f + (hm - 0.5) * wide * (0.6 + f)
			var my: float = sky + (bot - sky) * f + sin(t * 0.8 + float(m)) * 6.0 * k
			var glint: float = pow(0.5 + 0.5 * sin(t * (1.5 + hm * 2.0) + float(m) * 3.0), 3.0)
			if bound and (mx < 0.0 or mx > size.x):
				continue
			_sprite(node, dot, Vector2(mx, my), Vector2(6, 6) * k * (0.6 + glint),
				Color(1.0, 0.98, 0.85, 0.15 + 0.5 * glint))

	# The leaves. Off a screen they fall in from above and out past the bottom;
	# inside a panel they live their whole fall within the frame.
	var over: float = 0.0 if bound else 60.0 * k
	var greens := [Color(0.40, 0.72, 0.28), Color(0.55, 0.80, 0.30), Color(0.30, 0.60, 0.25),
		Color(0.62, 0.78, 0.35), Color(0.90, 0.72, 0.25), Color(0.88, 0.50, 0.20)]
	for i in 34:
		var hx := _hash01(i, 1.0)
		var hs := _hash01(i, 2.0)
		var hc := _hash01(i, 42.0)
		var depth: float = float(i % 3) / 2.0
		var fall: float = (22.0 + hs * 26.0) * (0.6 + depth * 0.7) * k
		# Its own hash for where in the fall it starts — reusing `hx`, which also
		# places it across the screen, lined every leaf up on one diagonal.
		var hy := _hash01(i, 47.0)
		var y: float = fmod(t * fall + hy * (size.y + 200.0), size.y + over * 2.0) - over
		# The swing. `phase` runs steadily; the leaf is at the ends of its swing
		# when sin(phase) is ±1, which is where it tilts hardest and slows.
		var phase: float = t * (0.9 + hs * 0.6) + float(i) * 1.7
		var swing: float = sin(phase) * (28.0 + hs * 30.0) * k * (0.6 + depth * 0.6)
		var x: float = fmod(hx * size.x + swing + size.x, size.x)
		var tilt: float = cos(phase) * 0.9 + hx * 6.28
		# Some tumble end over end: the leaf narrows to its edge and back.
		var turn: float = 1.0
		if hc > 0.6:
			turn = cos(t * (2.0 + hs * 2.0) + float(i))
		var len: float = (22.0 + hs * 16.0) * k * (0.6 + depth * 0.6)
		# Mostly green; one in five already turning.
		var col: Color = greens[int(hc * 4.0) % 4] if hc < 0.8 else greens[4 + i % 2]
		col = col.lerp(tint, 0.2).darkened(0.25 * (1.0 - depth))
		var a: float = 0.55 + depth * 0.4
		if bound and (x < len or x > size.x - len):
			continue
		node.draw_set_transform(Vector2(x, y), tilt, Vector2(1.0, absf(turn) * 0.85 + 0.15))
		node.draw_texture_rect(lf, Rect2(-len * 0.5, -len * 0.25, len, len * 0.5), false,
			Color(col, a))
	node.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Volcano. Embers lifting off the ground and dying on the way up, a few of them
## big enough to glow, the odd fast spark, and ash drifting across it all — over
## a heat bloom that breathes at its own rate so nothing lines up.
##
## ## What makes an ember read as one
##
## A life, mostly. The first version sent dots straight from the bottom edge to
## the top at constant brightness, which is snow falling upwards. A real ember
## is born hot and bright, cools through orange into deep red as it climbs, and
## goes out somewhere on the way — not at the top of the screen. It rides the
## hot air, so it corkscrews rather than rising on a rail, and the bright ones
## have a halo of their own light around them. Each of those is one line below.
static func _motion_embers(node: CanvasItem, size: Vector2, t: float,
		tint: Color, bound := false) -> void:
	var k: float = clampf(size.x / 720.0, 0.3, 1.5)
	var dot := soft_dot()
	var breathe: float = 0.5 + 0.5 * sin(t * 0.8)

	# Heat off the ground: a soft bloom along the bottom edge, not a disc. In a
	# panel it is kept low and small, so it cannot spill onto the next one.
	var bloom_w: float = size.x * (1.6 if not bound else 1.0)
	var bloom_h: float = size.y * (0.55 if not bound else 0.30)
	_sprite(node, dot, Vector2(size.x * 0.5, size.y + bloom_h * (0.18 if not bound else 0.5)),
		Vector2(bloom_w, bloom_h), Color(tint, 0.20 * (0.65 + 0.35 * breathe)))
	_sprite(node, dot, Vector2(size.x * 0.3, size.y + bloom_h * 0.3),
		Vector2(bloom_w * 0.5, bloom_h * 0.6),
		Color(1.0, 0.75, 0.3, 0.08 * (0.6 + 0.4 * sin(t * 1.3 + 1.0))))

	# Ash: pale grey flakes drifting sideways, slowly, behind everything else.
	for i in 16:
		var hx := _hash01(i, 30.0)
		var hs := _hash01(i, 31.0)
		var y: float = fmod(hs * size.y + t * (6.0 + hs * 8.0), size.y)
		var x: float = fmod(hx * size.x + t * (10.0 + hx * 12.0), size.x)
		var r: float = (1.2 + hs * 1.8) * k
		node.draw_set_transform(Vector2(x, y), t * (0.6 + hx) + hs * 6.0, Vector2(1.0, 0.45))
		node.draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), Color(0.72, 0.66, 0.62, 0.20), true)
	node.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# The embers. Three depths: far ones small, slow and dim; near ones larger,
	# faster, and every sixth of them one of the big glowing ones.
	for i in 84:
		var hx := _hash01(i, 3.0)
		var hs := _hash01(i, 4.0)
		var hl := _hash01(i, 32.0)
		var depth: float = float(i % 3) / 2.0
		var rise: float = (38.0 + hs * 60.0) * (0.6 + depth * 0.8)
		# How high this one gets before it goes out, as a share of the screen.
		var reach: float = 0.45 + hl * 0.55
		var travel: float = size.y * reach
		var life: float = travel / rise
		var age: float = fmod(t + hx * 97.0, life + 0.6 + hs * 1.4)
		if age > life:
			continue
		var f: float = age / life
		var y: float = size.y + 8.0 * k - f * travel
		# Corkscrewing on the hot air: two sines at different rates, widening as
		# it climbs because the column spreads.
		var swirl: float = sin(t * (1.1 + hs) + float(i) * 0.8) * (8.0 + 26.0 * f) * k \
			+ sin(t * 2.7 + float(i) * 1.9) * 4.0 * k
		# A wind that leans the whole column a little to the right.
		var x: float = fmod(hx * size.x + swirl + f * size.x * 0.06 + size.x, size.x)
		var big: bool = i % 6 == 0 and depth > 0.4
		var r: float = (2.6 + hs * 2.6 + depth * 2.4) * k * (1.6 if big else 1.0)
		# Guttering: fast and irregular, so it burns rather than blinks.
		var flick: float = 0.62 + 0.38 * sin(t * (7.0 + hs * 5.0) + float(i) * 2.1) \
			* sin(t * 3.1 + float(i))
		# Cooling as it climbs: white-yellow, orange, deep red, gone.
		var hot := Color(1.0, 0.93, 0.62)
		var warm := Color(1.0, 0.52, 0.16).lerp(tint, 0.2)
		var cool := Color(0.78, 0.16, 0.06)
		var col: Color = hot.lerp(warm, clampf(f * 2.2, 0.0, 1.0)) if f < 0.45 \
			else warm.lerp(cool, clampf((f - 0.45) / 0.55, 0.0, 1.0))
		# Fades in over its first moment and out over its last third.
		var alive: float = clampf(f * 8.0, 0.0, 1.0) * clampf((1.0 - f) * 3.0, 0.0, 1.0)
		var a: float = alive * flick * (0.55 + depth * 0.45)
		if bound and (x < r or x > size.x - r or y < r or y > size.y - r):
			continue
		# The halo, then the core. Only the near embers get a halo worth the name.
		var halo: float = r * (9.0 if big else 5.0)
		_sprite(node, dot, Vector2(x, y), Vector2(halo, halo) * 2.0,
			Color(col, a * (0.85 if big else 0.50) * (0.8 + 0.2 * sin(t * 2.0 + float(i)))))
		_sprite(node, dot, Vector2(x, y), Vector2(r, r) * 2.6, Color(col.lightened(0.35), minf(1.0, a * 1.3)))
		# A white-hot pip in the brightest ones, which is what sells the glow.
		if f < 0.5:
			_sprite(node, dot, Vector2(x, y), Vector2(r, r) * 1.1, Color(1, 1, 0.9, a * (1.0 - f * 2.0)))

	# Sparks: a rare fast one with a short trail, spat off the ground.
	for i in 5:
		var hx := _hash01(i, 33.0)
		var period: float = 2.6 + hx * 3.4
		var age: float = fmod(t + hx * 11.0, period)
		if age > 0.7:
			continue
		var f: float = age / 0.7
		var x0: float = size.x * (0.1 + hx * 0.8)
		var head := Vector2(x0 + (hx - 0.5) * 140.0 * k * f, size.y - f * size.y * (0.35 + hx * 0.25))
		var tail := head + Vector2(-(hx - 0.5) * 30.0 * k, 26.0 * k)
		if bound and (head.y < 0.0 or tail.y > size.y):
			continue
		var a: float = (1.0 - f) * 0.85
		node.draw_line(tail, head, Color(1.0, 0.7, 0.3, a * 0.6), 1.6 * k, true)
		_sprite(node, dot, head, Vector2(7, 7) * k, Color(1.0, 0.9, 0.6, a))


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


## Space. Nebulae breathing behind three depths of stars, the brightest few with
## a glint that turns and shimmers, and now and then a shooting star.
##
## Parallax is still the first trick — near stars drift, far ones barely — but a
## field of round dots is a texture however it moves. What makes a star read as
## a star is the glint: rays that catch and turn, on a handful of them only, so
## the eye has something to find. And colour temperature: real stars are not all
## white, and a sprinkling of blue and warm ones is what separates a sky from a
## screen of pixels.
static func _motion_starfield(node: CanvasItem, size: Vector2, t: float,
		tint: Color, bound := false) -> void:
	var k: float = clampf(size.x / 720.0, 0.3, 1.5)
	var dot := soft_dot()
	var gl := glint()

	# Nebulae: large soft glows that swell and wander. Kept inside a panel, where
	# a glow wider than the preview would land on its neighbour.
	for i in 3:
		var f := float(i) / 2.0
		var swell: float = 0.72 + 0.28 * sin(t * 0.31 + float(i) * 2.2)
		var wander: float = sin(t * 0.17 + float(i)) * size.x * 0.02
		var c := Vector2(size.x * (0.62 - f * 0.22) + wander, size.y * (0.26 + f * 0.24))
		var w: float = size.x * (0.9 + f * 0.5) * (0.94 + 0.06 * swell)
		if bound:
			w = minf(w, size.x * 0.9)
		var col: Color = tint.lerp(Color(0.35, 0.55, 1.0), f * 0.6)
		_sprite(node, dot, c, Vector2(w, w * 0.7), Color(col, 0.14 * (1.0 - f * 0.4) * swell))

	# The field. Far stars are points; nearer ones get the soft dot so they have
	# a little bloom.
	var temps := [Color(1, 1, 1), Color(0.75, 0.85, 1.0), Color(1.0, 0.9, 0.75),
		Color(0.9, 0.8, 1.0)]
	for i in 170:
		var hx := _hash01(i, 7.0)
		var hy := _hash01(i, 8.0)
		var hc := _hash01(i, 34.0)
		var depth := float(i % 3)
		var speed: float = (2.0 + depth * 6.0) * k
		var x: float = fmod(hx * size.x + t * speed, size.x)
		var y: float = hy * size.y
		# Most stars hold steady; some twinkle, each on its own clock.
		var tw: float = 1.0
		if hc > 0.55:
			tw = 0.55 + 0.45 * sin(t * (1.6 + hx * 3.0) + float(i) * 1.3)
		var col: Color = (temps[int(hc * 4.0) % 4] as Color).lerp(tint, 0.15)
		var a: float = (0.45 + depth * 0.25) * tw
		if depth < 1.0:
			node.draw_rect(Rect2(x, y, 1.6 * k, 1.6 * k), Color(col, a), true)
		else:
			var r: float = (depth + hc) * 3.0 * k
			_sprite(node, dot, Vector2(x, y), Vector2(r, r) * 2.0, Color(col, a))

	# The bright few: a glint that turns slowly and shimmers, each at its own
	# pace, over a small bloom. Nine, spread so there is always one in view.
	for i in 9:
		var hx := _hash01(i, 35.0)
		var hy := _hash01(i, 36.0)
		var x: float = fmod(hx * size.x + t * 3.0 * k, size.x)
		var y: float = size.y * (0.05 + hy * 0.9)
		var shimmer: float = 0.5 + 0.5 * sin(t * (0.9 + hx * 1.4) + float(i) * 2.0)
		# Now and then a star flares for a moment, which is the shimmer people
		# notice from across a room.
		var flare: float = pow(maxf(0.0, sin(t * 0.37 + float(i) * 1.7)), 24.0)
		var s: float = (26.0 + hy * 16.0) * k * (0.75 + 0.35 * shimmer + 0.7 * flare)
		var col: Color = (temps[i % 4] as Color).lerp(tint, 0.2)
		if bound and (x < s * 0.5 or x > size.x - s * 0.5):
			continue
		_sprite(node, dot, Vector2(x, y), Vector2(s, s) * 0.9,
			Color(col, 0.35 + 0.25 * shimmer))
		_sprite(node, gl, Vector2(x, y), Vector2(s, s) * 2.2,
			Color(col, minf(1.0, 0.70 + 0.30 * shimmer + 0.2 * flare)), t * 0.15 + float(i))

	# A shooting star, every seven seconds or so, somewhere different each time.
	if not bound:
		var period := 7.0
		var n: int = int(t / period)
		var age: float = fmod(t, period)
		if age < 0.9:
			var f: float = age / 0.9
			var sx: float = size.x * (0.2 + _hash01(n, 37.0) * 0.7)
			var sy: float = size.y * (0.05 + _hash01(n, 38.0) * 0.35)
			var dir := Vector2(-1.0, 0.45).normalized()
			var head := Vector2(sx, sy) + dir * f * size.x * 0.55
			var len: float = size.x * 0.16 * (1.0 - f * 0.4)
			var a: float = sin(f * PI)
			for j in 8:
				var u := float(j) / 8.0
				node.draw_line(head - dir * len * u, head - dir * len * (u + 0.125),
					Color(1, 1, 1, a * (1.0 - u) * 0.8), 2.2 * k * (1.0 - u * 0.7), true)
			_sprite(node, dot, head, Vector2(10, 10) * k, Color(1, 1, 1, a))


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


## Clouds. Cumulus crossing at three depths, thin wisps behind them, and the
## light coming from the upper left.
##
## Nothing rises, nothing falls — the board is already in the sky, and the only
## honest motion up there is wind.
##
## ## Why this one was rebuilt twice
##
## The first version was three white discs at five percent alpha, invisible on
## the only board whose art is already white. The second shaded the discs, which
## made them visible and made them discs: five hard-edged circles along an arc
## read as a caterpillar however they are coloured.
##
## A cloud is vapour, so this one is built from `cloud_puff`, whose edge is torn
## by noise, and a dozen of them are laid out the way cumulus actually grows —
## a flat base where the air stops rising and a dome of heaped towers above
## it. Three passes paint it: a blue-grey underside offset down, the lit body,
## and a bright rim on the towers facing the sun. The shadow is what makes it
## read against a pale sky; the rim is what makes it look lit rather than
## printed.
static func _motion_drift(node: CanvasItem, size: Vector2, t: float,
		tint: Color, bound := false) -> void:
	var k: float = clampf(size.x / 720.0, 0.3, 1.5)
	var puff := cloud_puff()

	# Wisps: long thin streaks of high cloud, far away and slow.
	for i in 4:
		var hb := _hash01(i, 20.0)
		var w: float = size.x * (0.55 + hb * 0.35)
		var span: float = size.x + (w if not bound else 0.0)
		var x: float = fmod(hb * span + t * (3.0 + hb * 2.0) * k, span) - (w * 0.5 if not bound else 0.0)
		if bound:
			x = clampf(x, w * 0.5, size.x - w * 0.5) if w < size.x else size.x * 0.5
			w = minf(w, size.x)
		var y: float = size.y * (0.08 + hb * 0.55)
		# The soft dot rather than the puff: stretched this thin, the puff's torn
		# edge becomes a hard one and a wisp becomes a bar.
		var dot := soft_dot()
		_sprite(node, dot, Vector2(x, y), Vector2(w, w * 0.10), Color(1, 1, 1, 0.20))
		_sprite(node, dot, Vector2(x + w * 0.15, y + w * 0.025), Vector2(w * 0.7, w * 0.07),
			Color(1, 1, 1, 0.14))

	# The shape of a cumulus: [x, y, size] in units of the cloud's radius. The
	# base row is wide and flat; the towers above it get bigger towards the
	# middle and a little to the left, where the sun is.
	var shape := [
		[-1.35, 0.30, 0.95], [-0.70, 0.36, 1.05], [0.00, 0.38, 1.10],
		[0.70, 0.36, 1.05], [1.35, 0.30, 0.90],
		[-0.95, -0.05, 1.05], [-0.25, -0.25, 1.35], [0.50, -0.12, 1.20],
		[1.10, 0.02, 0.90],
		[-0.50, -0.62, 1.05], [0.20, -0.72, 1.15], [0.75, -0.45, 0.85],
	]
	var shade := Color(0.50, 0.60, 0.78).lerp(tint, 0.2)
	var lit := Color(1.0, 1.0, 1.0).lerp(tint, 0.06)

	for i in 9:
		var hx := _hash01(i, 10.0)
		var hy := _hash01(i, 11.0)
		var hr := _hash01(i, 21.0)
		var depth := float(i % 3)
		var speed: float = (4.0 + depth * 9.0) * k
		var r: float = size.x * (0.050 + hr * 0.035) * (0.70 + depth * 0.32)
		var reach: float = r * 1.9
		var edge: float = reach if not bound else 0.0
		var span: float = size.x + edge * 2.0 - (reach * 2.0 if bound else 0.0)
		var x: float = fmod(hx * span + t * speed, span) - edge + (reach if bound else 0.0)
		var y: float = size.y * (0.08 + hy * 0.84) + sin(t * 0.3 + float(i) * 1.7) * r * 0.12
		if bound:
			y = clampf(y, reach, size.y - reach)
		# Far clouds are paler and flatter against the sky; near ones are dense.
		var dense: float = 0.45 + depth * 0.27
		var squash: float = 0.82 + depth * 0.06

		# This cloud's own version of the shape: every puff nudged and resized by
		# the cloud's hash, and some towers left out, so no two are the same
		# cloud stamped twice. A wider stretch makes some of them long and low.
		var stretch: float = 0.85 + _hash01(i, 43.0) * 0.5
		var mine: Array = []
		for j in shape.size():
			var p: Array = shape[j]
			var jx := _hash01(i * 13 + j, 44.0) - 0.5
			var jy := _hash01(i * 13 + j, 45.0) - 0.5
			var js := _hash01(i * 13 + j, 46.0)
			if j >= 9 and js < 0.3:
				continue
			mine.append([float(p[0]) * stretch + jx * 0.35, float(p[1]) + jy * 0.2,
				float(p[2]) * (0.8 + js * 0.4), j])
		# Underside: every puff, offset down, in blue-grey.
		for p: Array in mine:
			var c := Vector2(x + r * float(p[0]), y + r * (float(p[1]) * squash + 0.28))
			var d: float = r * float(p[2]) * 1.9
			_sprite(node, puff, c, Vector2(d, d * 0.9), Color(shade, 0.30 * dense))
		# Body.
		for p: Array in mine:
			var c := Vector2(x + r * float(p[0]), y + r * float(p[1]) * squash)
			var d: float = r * float(p[2]) * 1.9
			_sprite(node, puff, c, Vector2(d, d * 0.92), Color(lit, 0.34 * dense))
		# Sunlit rim on the upper towers, nudged towards the upper left.
		for p: Array in mine:
			if int(p[3]) < 5:
				continue
			var c := Vector2(x + r * (float(p[0]) - 0.12), y + r * (float(p[1]) * squash - 0.16))
			var d: float = r * float(p[2]) * 1.15
			_sprite(node, puff, c, Vector2(d, d * 0.9), Color(1, 1, 1, 0.30 * dense))


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


const STAMP_DARK := Color("#0b1020")

## The ink for a plain filled block: whichever of the house dark and white reads
## better on the tier's colour.
##
## Dark was assumed for every tier, and on the lightest four it is right. On the
## blue it is 4.1:1 and on the red 3.7:1, which is the whole of why those two
## stamps read as muddy; white is 4.7 and 5.1 on the same faces. The tier
## colours carry meaning, so it is the letters that move. `alpha` is how opaque
## the fill is, because a translucent one shows a little of the board's dark
## panel through it and reads a little darker than the tier.
static func plain_ink(col: Color, hot := false, alpha := 1.0) -> Color:
	var face := col.lightened(0.25) if hot else col
	face = Color(face.r * alpha + 0.055 * (1.0 - alpha),
		face.g * alpha + 0.078 * (1.0 - alpha),
		face.b * alpha + 0.165 * (1.0 - alpha))
	var fl := face.srgb_to_linear()
	var lum := 0.2126 * fl.r + 0.7152 * fl.g + 0.0722 * fl.b
	var dl := STAMP_DARK.srgb_to_linear()
	var dark_lum := 0.2126 * dl.r + 0.7152 * dl.g + 0.0722 * dl.b
	var vs_dark := (maxf(lum, dark_lum) + 0.05) / (minf(lum, dark_lum) + 0.05)
	var vs_white := 1.05 / (lum + 0.05)
	return STAMP_DARK if vs_dark >= vs_white else Color.WHITE


## The edge a stamp is set against. Dark letters get a pale one and light
## letters a dark one, so the stroke has an opposite-toned rim wherever the art
## behind it goes the wrong way: a bright blob in the nebula, the lit half of an
## ice facet, a crack through a magma block. It is what keeps a thin face (Josefin,
## Comfortaa, Cinzel's hairlines) readable at a size where the strokes are two
## pixels wide, and it costs nothing on a face that was already fine, because a
## rim the same tone as what is behind it cannot be seen.
static func stamp_halo(ink: Color) -> Color:
	var l := ink.srgb_to_linear()
	var lum := 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b
	return Color(STAMP_DARK, 0.62) if lum > 0.3 else Color(1, 1, 1, 0.5)


## How wide the rim is for a stamp set at `size`.
##
## A tenth of the type, but never the two pixels it used to be at the bottom of
## the range. A rim that is a fifth of the stroke is not an edge, it is a smear:
## on the compressed face the gaps between letters are about two pixels, so a
## two-pixel rim closed them and `ING` read as one grey blob. Under the size
## where a stroke is a pixel and a half there is no rim at all, which is also
## where the ink is dark on a face that is already light enough to carry it.
static func stamp_rim(size: int) -> int:
	if size < 14:
		return 0
	if size < 20:
		return 1
	return clampi(int(round(float(size) * 0.10)), 2, 4)


## Draw a stamp: the halo, then the letters. Centred the way every label in the
## game is, on the middle of the font's line box. The width scales with the type
## and is clamped so a one-cell block does not get a smear and a big one does not
## get a sticker.
static func draw_stamp(node: CanvasItem, font: Font, center: Vector2, text: String,
		size: int, ink: Color) -> void:
	if font == null or text == "":
		return
	var m := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var at := Vector2(center.x - m.x * 0.5, center.y - m.y * 0.5 + font.get_ascent(size))
	var rim := stamp_rim(size)
	if rim > 0:
		node.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, rim,
			Color(stamp_halo(ink), stamp_halo(ink).a * ink.a))
	node.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)


## A pane of frost, for a see-through face to sit on when the board behind the
## playfield is light.
const FROST := Color("#f2f7ff")


## Whether a board's picture is light behind the playfield; see `THEME_EXTRAS`.
static func is_bright(theme_id: String) -> bool:
	return bool(theme_opt(theme_id, "bright"))


## Wireframe: the frame and nothing else. Reads as a hologram, and lets the
## board's own grid show through the stack.
##
## On a light board there is no hologram to read: pale ink and a pale frame on a
## pale sky are the same colour as the ground. So the frame goes dark, there is
## frost behind it for the letters to sit on, and the ink is the tier colour
## taken most of the way to black. The hue is still the tier's, in the frame and
## in the letters, because that is the rule the whole slot lives under.
static func outline_face(node: CanvasItem, rect: Rect2, col: Color, hot: bool,
		bright := false) -> Color:
	if bright:
		node.draw_rect(rect, Color(FROST, 0.74 if hot else 0.62), true)
		node.draw_rect(rect, Color(col, 0.34 if hot else 0.16), true)
		node.draw_rect(rect, Color(col.darkened(0.6 if hot else 0.35), 0.95), false,
			3.0 if hot else 2.0)
		node.draw_rect(rect.grow(-5.0), Color(col.darkened(0.35), 0.45), false, 1.0)
		return col.darkened(0.78)
	node.draw_rect(rect, Color(col, 0.10), true)
	node.draw_rect(rect, Color(col.lightened(0.2) if not hot else Color.WHITE,
		0.95), false, 2.0 if not hot else 3.0)
	node.draw_rect(rect.grow(-5.0), Color(col, 0.35), false, 1.0)
	return col.lightened(0.55)


## Glass: the tier colour as a tint, a highlight across the top and a bright
## edge. On a light board the tint alone is a light block on a light sky, so it
## sits on frost and the letters go dark; the edge is the tier colour rather than
## a paler one, since pale is what the sky already is.
static func glass_face(node: CanvasItem, rect: Rect2, col: Color, hot: bool,
		bright := false) -> Color:
	if bright:
		node.draw_rect(rect, Color(FROST, 0.62), true)
	node.draw_rect(rect, Color(col, 0.46 if bright else 0.34), true)
	node.draw_rect(Rect2(rect.position + Vector2(3, 3),
		Vector2(rect.size.x - 6.0, rect.size.y * 0.38)),
		Color(1, 1, 1, 0.30 if bright else 0.13), true)
	if bright:
		node.draw_rect(rect, Color(col.darkened(0.6 if hot else 0.25), 0.95), false,
			3.0 if hot else 2.0)
		return col.darkened(0.8)
	node.draw_rect(rect, Color(col.lightened(0.4) if not hot else Color.WHITE,
		0.9), false, 2.0 if not hot else 3.0)
	return Color.WHITE


## Paint one, and report what colour its label should be — the ink has to be
## decided per style rather than assumed dark, because two of the four are
## mostly transparent.
## `key` identifies the block for the patterned faces; see `_face_seed`. Every
## caller that draws a face on something which can move — a menu plate on a
## scrolling screen, a preview swatch that shifts when the panel resizes — has
## to pass one, or the pattern re-rolls as it moves. Anything static may leave
## it and be seeded from its own rect.
## `bright` is for a block that sits on a light board's picture; see `is_bright`.
## Only Wireframe and Glass care, since every other face brings its own ground.
static func draw_block_face(node: CanvasItem, rect: Rect2, col: Color,
		style: String, hot: bool, key: float = -1.0, bright := false) -> Color:
	match style:
		"outline":
			return outline_face(node, rect, col, hot, bright)
		"glass":
			return glass_face(node, rect, col, hot, bright)
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
			return plain_ink(col, hot, 0.92 if hot else 0.80)
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
			return plain_ink(col, hot, 0.92 if hot else 0.80)


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
# Most of them move, a little: Magma's cracks breathe and throw the odd spark,
# Coral's branches sway and a bubble goes up it, snow falls past Glacier and
# the aurora slides across it, Neon's scan bar sweeps, Nebula's stars catch,
# Rune's gold pulses and Cumulus's lobes breathe. All of it is read off `Time`
# rather than off any state, so a block that was drawn this frame and destroyed
# the next never had anything to clean up. Both callers already redraw every
# frame, so the motion costs nothing extra to keep running.
#
# What painting them does cost is kept near Cumulus's, which the game already
# carries: `tools/faceshots.gd` is where they are looked at, and a board's worth
# of each was timed against Cumulus when they were redrawn.


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


## Clouds, drawn the way the board's own clouds are: a lumpy cumulus with a
## lit crown and a cool underside split from it by a hard edge, an ink line
## round the lot, and a shine on the biggest lobe.
##
## The earlier face was a translucent tile with a gradient and white circles
## on it, and next to the toon-shaded islands behind it that read as a
## placeholder. What made the islands' clouds read was never softness, it was
## the opposite: two flat tones with a crisp line between them, and ink.
##
## Everything is drawn inside the rect (the ink included), because blocks sit
## three pixels apart and a lobe over the edge would sit on its neighbour. The
## silhouette is lobes along the top over a body with rounded feet, and the
## outline comes free: the same shapes drawn first a little larger in ink, then
## filled over. The lobes breathe, very slightly, each on its own clock.
static func _face_cloud(node: CanvasItem, rect: Rect2, col: Color, hot: bool,
		base: float, t: float) -> Color:
	var ow: float = clampf(minf(rect.size.x, rect.size.y) * 0.055, 1.5, 3.2)
	var inner := rect.grow(-ow)
	var w := inner.size.x
	var h := inner.size.y
	var lr: float = clampf(minf(w * 0.22, h * 0.4), 3.0, 17.0)

	# The tier survives as the hue of both tones: pale where it is lit, a step
	# deeper where it is not. The cool tiers also turn a little toward blue in
	# shadow, as the board's clouds go from white to lavender. The warm ones
	# keep their hue: any push toward blue turned yellow tan and any push
	# toward red turned it orange, and a cloud with a tan or orange underside
	# is a bread roll.
	var lit: Color = col.lerp(Color.WHITE, 0.5)
	var shade: Color
	if col.h > 0.2 and col.h < 0.8:
		shade = Color.from_hsv(minf(col.h + 0.04, 0.667), minf(1.0, col.s * 1.05), col.v * 0.86)
	else:
		shade = Color.from_hsv(col.h, col.s * 0.85, col.v * 0.94)
	# Navy ink on every tier, as the islands' clouds are lined in blue: a brown
	# line round the warm ones was the other half of the pastry.
	var ink: Color = Color.WHITE if hot else Color(0.15, 0.19, 0.42).lerp(col.darkened(0.45), 0.25)
	var line: float = ow * (1.5 if hot else 1.0)

	# The lobes along the top. The end ones are the base radius and sit in
	# the corners; the ones between vary, and bulge most in the middle, as a
	# cumulus piles up.
	var n := maxi(2, int(round(w / (lr * 1.45))))
	var lobes: Array[Vector3] = []
	for i in n:
		var u: float = (float(i) + 0.5) / float(n)
		var sd := _face_seed(base, 40.0 + float(i))
		var r: float = lr
		if i > 0 and i < n - 1:
			r = lr * (0.95 + 0.35 * sd) * (0.94 + 0.14 * sin(u * PI))
		r *= 1.0 + 0.03 * sin(t * 1.3 + sd * TAU)
		var cx: float = clampf(inner.position.x + w * u, inner.position.x + r, inner.end.x - r)
		lobes.append(Vector3(cx, inner.position.y + r, r))
	# Puffs on the sides of anything tall enough to have sides, so it is a
	# cloud all the way round and not a cloud on a brick.
	var side := 0.0
	if h > lr * 2.8:
		side = lr * 0.22
		for k in 2:
			var sd2 := _face_seed(base, 60.0 + float(k))
			var sr: float = lr * (0.62 + 0.18 * sd2)
			var sy: float = inner.position.y + lr + (h - lr) * (0.42 + 0.18 * sd2)
			lobes.append(Vector3(inner.position.x + sr if k == 0 else inner.end.x - sr, sy, sr))
	var body := Rect2(inner.position.x + side, inner.position.y, w - side * 2.0, h)
	var body_top: float = inner.position.y + lr
	var foot: float = minf(lr * 0.7, h * 0.3)

	# Ink, then shade, over the same shapes: the outline is the difference.
	for pass_i in 2:
		var grow: float = line if pass_i == 0 else 0.0
		var c: Color = ink if pass_i == 0 else shade
		for L in lobes:
			node.draw_circle(Vector2(L.x, L.y), L.z + grow, c)
		node.draw_colored_polygon(_cloud_body(body.grow(grow), body_top - grow, foot + grow), c)

	# The lit part: each lobe again, smaller and nudged up and left toward the
	# light, leaving a crescent of shade under it; and the body down to a
	# lumpy line a little past halfway, where the underside begins.
	var term: float = body_top + (inner.end.y - body_top) * 0.5
	node.draw_rect(Rect2(body.position.x + lr * 0.3, body_top,
		body.size.x - lr * 0.6, maxf(0.0, term - body_top)), lit)
	var bumps := maxi(2, int(round(body.size.x / (lr * 1.1))))
	for i in bumps:
		var u2: float = (float(i) + 0.5) / float(bumps)
		var sd3 := _face_seed(base, 70.0 + float(i))
		var br: float = lr * (0.5 + 0.25 * sd3)
		node.draw_circle(Vector2(clampf(body.position.x + body.size.x * u2,
			body.position.x + br + lr * 0.3, body.end.x - br - lr * 0.3),
			term - br * 0.2), br, lit)
	for L in lobes:
		var d: float = L.z * 0.22
		node.draw_circle(Vector2(L.x - d * 0.5, L.y - d * 0.9), L.z - d * 1.15, lit)

	# One shine, on the biggest lobe: the rim the islands' clouds catch.
	var big := lobes[0]
	for L in lobes:
		if L.z > big.z:
			big = L
	node.draw_circle(Vector2(big.x - big.z * 0.36, big.y - big.z * 0.42), big.z * 0.17,
		Color(1, 1, 1, 0.8))
	return Color("#16324f")


## A cloud's body: straight sides and top, and rounded feet.
static func _cloud_body(r: Rect2, top: float, foot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(r.position.x, top))
	pts.append(Vector2(r.end.x, top))
	for side in 2:
		var cx: float = r.end.x - foot if side == 0 else r.position.x + foot
		var a0: float = 0.0 if side == 0 else PI * 0.5
		for k in 7:
			var a: float = a0 + PI * 0.5 * float(k) / 6.0
			pts.append(Vector2(cx + cos(a) * foot, r.end.y - foot + sin(a) * foot))
	return pts


# ------------------------------------------------------- the faces, redrawn
#
# Cumulus was the one face in the set that belonged to its board, and the reason
# was never the cloud. It was the drawing: two flat tones split by a hard edge,
# an ink line round the lot, one shine, and a silhouette taken from something in
# the scene. The boards are toon-shaded 3D now, and every one of them is drawn
# that way — the volcano's plates, the reef's rocks, the snow on the pines.
#
# The faces below were translucent fills with thin lines laid on top, which is
# the language of a UI tile, not of any of those places. So they are redrawn in
# the boards' own terms: ink, two tones, a shine, and each one something you can
# point at in its board. The tier still survives in the hue of the main tones;
# what changed is the material, never the colour.
#
# The helpers first. Everything is a fraction of the rect it is handed, and
# everything is drawn inside it, ink included: blocks sit six pixels apart, and
# a line over the edge would sit on the neighbour.


## The unit offsets a rounded rectangle's corners are made of, worked out
## once: three to a corner, which at these radii (a dozen pixels at most) is
## indistinguishable from more. These faces are painted for every block on the
## board every frame, and building their outlines was most of what they cost.
static var _corner_arc := PackedVector2Array()


## A rounded rectangle, as a polygon.
static func _rrect(r: Rect2, rad: float) -> PackedVector2Array:
	if _corner_arc.is_empty():
		for i in 4:
			for k in 3:
				var a: float = -PI * 0.5 + PI * 0.5 * float(i) + PI * 0.25 * float(k)
				_corner_arc.append(Vector2(cos(a), sin(a)))
	var half: float = minf(r.size.x, r.size.y) * 0.5
	rad = clampf(rad, 0.0, half)
	var c0 := Vector2(r.end.x - rad, r.position.y + rad)
	var c1 := Vector2(r.end.x - rad, r.end.y - rad)
	var c2 := Vector2(r.position.x + rad, r.end.y - rad)
	var c3 := Vector2(r.position.x + rad, r.position.y + rad)
	var pts := PackedVector2Array([
		c0 + _corner_arc[0] * rad, c0 + _corner_arc[1] * rad, c0 + _corner_arc[2] * rad,
		c1 + _corner_arc[3] * rad, c1 + _corner_arc[4] * rad, c1 + _corner_arc[5] * rad,
		c2 + _corner_arc[6] * rad, c2 + _corner_arc[7] * rad, c2 + _corner_arc[8] * rad,
		c3 + _corner_arc[9] * rad, c3 + _corner_arc[10] * rad, c3 + _corner_arc[11] * rad])
	if rad < half - 0.01:
		return pts
	# At a radius of half the short side the straight edges have no length,
	# and a point laid twice is a polygon the triangulator refuses — the shape
	# silently does not draw. Rare, so it is only paid for here.
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		if out.is_empty() or out[out.size() - 1].distance_squared_to(p) > 0.0001:
			out.append(p)
	if out.size() > 1 and out[0].distance_squared_to(out[out.size() - 1]) <= 0.0001:
		out.remove_at(out.size() - 1)
	return out


## The ink width a face is outlined at, from its size, as the cloud's is.
static func _ink_w(rect: Rect2) -> float:
	return clampf(minf(rect.size.x, rect.size.y) * 0.055, 1.5, 3.2)


## The tier a step deeper, for the side of a thing away from the light. The
## cool tiers turn a little toward blue in shadow, as everything on the boards
## does; the warm ones keep their hue, because a push either way turns yellow
## into tan and orange into brown. The same rule the cloud learned.
static func _deeper(col: Color, k: float) -> Color:
	if col.h > 0.2 and col.h < 0.8:
		return Color.from_hsv(minf(col.h + 0.03, 0.7), minf(1.0, col.s * 1.06),
			col.v * (1.0 - k))
	return Color.from_hsv(col.h, minf(1.0, col.s * 1.04), col.v * (1.0 - k))


## Dark type on a light face, light type on a dark one.
static func _stamp_on(face: Color, dark: Color, light := Color.WHITE) -> Color:
	return dark if face.get_luminance() > 0.52 else light


## Volcano. A plate of basalt, as the board's floor is made of: dark rock in
## the tier's hue, the edges nearest the lava lit orange from below, and a
## corner or two cracked off with the heat showing in the crack.
##
## The earlier face ran wandering seams across the middle, which put glowing
## scribbles through the stamp and read, on the blue tiers, as cracked glass.
## Basalt breaks in straight lines — the board's floor is hexagons — so the
## cracks are straight, and they stay in the corners, where the letters are not.
static func _face_magma(node: CanvasItem, rect: Rect2, col: Color, hot: bool,
		base: float, t: float) -> Color:
	var ow := _ink_w(rect)
	var ink: Color = Color.WHITE if hot else Color("#0c0406")
	node.draw_colored_polygon(_rrect(rect, ow * 1.8), ink)
	var r := rect.grow(-ow * (1.5 if hot else 1.0))
	var w := r.size.x
	var h := r.size.y
	var beat: float = 0.62 + 0.38 * sin(t * 1.7 + _face_seed(base, 1.0) * TAU)

	# The rock: the tier at a fraction of its brightness and a little less of
	# its saturation, so six tiers are six basalts rather than six tiles.
	# A yellow taken that dark turns olive, which nothing on the board is, so
	# the warm tiers lean a step toward the lava's own orange as they darken.
	var hue: float = col.h
	if hue > 0.07 and hue < 0.2:
		hue = lerpf(hue, 0.075, 0.45)
	var face := Color.from_hsv(hue, minf(1.0, col.s * 0.80), col.v * 0.44)
	var deep := Color.from_hsv(hue, minf(1.0, col.s * 0.74), col.v * 0.26)
	var lava := Color("#ff6414")
	var heat := Color("#ffc93c")

	# Three tones for a slab: the top and left edges in shadow, the face, and
	# the bottom and right edges lit by the lava the slab is standing in.
	var bv: float = clampf(minf(w, h) * 0.14, 2.5, 7.0)
	var rim := face.lerp(lava, 0.50 + 0.16 * beat)
	var f := _bevel(node, r, bv, ow, deep, face, rim)
	# A hotter line where the rim meets the lava, right along the bottom.
	node.draw_rect(Rect2(r.position.x + ow + bv * 0.5, r.end.y - maxf(1.2, bv * 0.32),
		w - ow * 2.0 - bv * 0.5, maxf(1.2, bv * 0.32)), Color(heat, 0.55 + 0.35 * beat))
	# And the lava's light up the lower part of the face, in one flat step
	# with a wavering edge, the way the board's rocks are lit from below.
	var warm_top: float = f.position.y + f.size.y * 0.68
	node.draw_rect(Rect2(f.position.x, warm_top, f.size.x, f.end.y - warm_top),
		face.lerp(lava, 0.14 + 0.05 * beat))
	var wav := PackedVector2Array()
	for s2 in 9:
		var x2: float = lerpf(f.position.x, f.end.x, float(s2) / 8.0)
		wav.append(Vector2(x2, warm_top + sin(x2 * 0.3 + t * 1.5) * minf(1.5, f.size.y * 0.04)))
	node.draw_polyline(wav, face.lerp(lava, 0.14 + 0.05 * beat), maxf(1.5, f.size.y * 0.06))

	# Pits in the rock, where gas came out of it as it cooled. In the corners,
	# small and few; texture is what separates rock from a painted tile.
	for i in 4:
		var px := _face_seed(base, 20.0 + float(i))
		var py := _face_seed(base, 24.0 + float(i))
		var cx: float = f.position.x + f.size.x * (0.08 + 0.2 * px if i % 2 == 0 else 0.72 + 0.2 * px)
		var cy: float = f.position.y + f.size.y * (0.12 + 0.2 * py if i < 2 else 0.68 + 0.2 * py)
		node.draw_circle(Vector2(cx, cy), maxf(0.8, minf(w, h) * 0.022), deep)

	# The cracks: one corner on a small block, two on a big one, never the
	# same two. Each cuts a chip off its corner; the chip sits at its own
	# darkness, and the crack between is dark with the heat showing up the
	# middle of it.
	var big := f.size.x > 60.0 and f.size.y > 44.0
	var first := int(_face_seed(base, 30.0) * 4.0) % 4
	var corners := [first] if not big else [first, (first + 2) % 4]
	for c: int in corners:
		var right := c == 1 or c == 2
		var bottom := c >= 2
		var cn := Vector2(f.end.x if right else f.position.x, f.end.y if bottom else f.position.y)
		var sx: float = -1.0 if right else 1.0
		var sy: float = -1.0 if bottom else 1.0
		var ax: float = minf(f.size.x * 0.40, 30.0) * (0.75 + 0.5 * _face_seed(base, 31.0 + float(c)))
		var ay: float = minf(f.size.y * 0.55, 24.0) * (0.75 + 0.5 * _face_seed(base, 35.0 + float(c)))
		var a := cn + Vector2(sx * ax, 0.0)
		var b := cn + Vector2(0.0, sy * ay)
		# One kink, bent out from the corner, so the crack is broken rather
		# than ruled.
		var k := a.lerp(b, 0.45 + 0.15 * _face_seed(base, 39.0 + float(c))) \
			+ Vector2(sx, sy) * minf(ax, ay) * 0.18
		# The chip has sunk a little: darker, with its broken edge catching
		# the glow from the crack beside it.
		node.draw_colored_polygon(PackedVector2Array([cn, a, k, b]), deep.lerp(face, 0.45))
		# A short fork off the crack, so it branches as cracks do and does not
		# read as a bracket.
		var fork_end: Vector2 = k + (k - cn).normalized().rotated(0.5 * sx * sy) \
			* minf(ax, ay) * 0.45
		fork_end = Vector2(clampf(fork_end.x, f.position.x + 1.0, f.end.x - 1.0),
			clampf(fork_end.y, f.position.y + 1.0, f.end.y - 1.0))
		var seam := PackedVector2Array([a, k, b])
		var wd: float = maxf(1.3, minf(w, h) * 0.055)
		node.draw_line(k, fork_end, deep.darkened(0.35), wd * 1.2)
		node.draw_line(k, k.lerp(fork_end, 0.7), heat.lerp(lava, 0.5), maxf(1.0, wd * 0.55))
		node.draw_polyline(seam, Color(lava, 0.30 + 0.16 * beat), wd * 3.6)
		node.draw_polyline(seam, deep.darkened(0.35), wd * 1.7)
		node.draw_polyline(seam, heat.lerp(lava, 0.35 - 0.3 * beat), maxf(1.0, wd * 0.9))
		# Now and then a spark comes up out of it and goes out.
		var es := _face_seed(base, 44.0 + float(c))
		var life: float = fmod(t * (0.35 + 0.2 * es) + es, 1.0)
		if life < 0.6:
			var ep: Vector2 = k + Vector2(-sx, -sy) * minf(w, h) * 0.02 \
				+ Vector2(sin(life * 9.0 + es * 5.0) * 1.5, -life * minf(h * 0.5, 18.0))
			ep.y = maxf(ep.y, f.position.y + 1.5)
			node.draw_circle(ep, maxf(0.9, wd * 0.55) * (1.0 - life), Color(heat, 1.0 - life / 0.6))

	# The top edge of the face catches a little of the glow off the cone.
	node.draw_rect(Rect2(f.position.x + 1.0, f.position.y, f.size.x - 2.0, maxf(1.0, bv * 0.22)),
		Color(face.lightened(0.22), 0.8))
	return Color("#ffeedd")


## Ocean. A stone off the reef floor with the reef growing on it: a faceted
## rock in the tier's colour, lit on its top and left and dark on its right, as
## the pillars on the board are, and standing on it a few of the things on the
## board's sand — branching coral, forked and angular, and low coral domes — in
## the reef's own pinks, violets and golds.
##
## The earlier face was a translucent rectangle with three faint circles on it,
## a tile with a watermark rather than anything that lives in the sea. A first
## redraw lined the top with little round polyps, which read as a row of beads;
## the board's coral is sparse and angular, so this is too.
static func _face_coral(node: CanvasItem, rect: Rect2, col: Color, hot: bool,
		base: float, t: float) -> Color:
	var ow := _ink_w(rect)
	var ink: Color = Color.WHITE if hot else Color("#0b2442")
	var line: float = ow * (1.5 if hot else 1.0)
	var inner := rect.grow(-ow)
	var w := inner.size.x
	var h := inner.size.y
	var cr: float = clampf(h * 0.34, 8.0, 19.0)
	var stone := Rect2(inner.position.x, inner.position.y + cr * 0.6, w, h - cr * 0.6)
	var rad: float = clampf(minf(stone.size.x, stone.size.y) * 0.16, 2.5, 8.0)

	# The rock, in three flat tones: its face, a lit top where the light comes
	# down through the water, and a dark right side.
	var face := col
	var top_c := col.lerp(Color.WHITE, 0.26)
	var side := _deeper(col, 0.30)
	node.draw_colored_polygon(_rrect(stone.grow(line), rad + line), ink)
	var outline := _rrect(stone, rad)
	node.draw_colored_polygon(outline, face)
	var cut: float = stone.position.x + stone.size.x * (0.72 + 0.08 * _face_seed(base, 71.0))
	var slant: float = minf(stone.size.x * 0.08, 6.0)
	var right := outline.duplicate()
	for i in right.size():
		var edge: float = lerpf(cut + slant, cut - slant,
			(right[i].y - stone.position.y) / maxf(1.0, stone.size.y))
		right[i].x = maxf(right[i].x, edge)
	node.draw_colored_polygon(right, side)
	var lid: float = stone.position.y + maxf(2.0, stone.size.y * 0.16)
	var top := outline.duplicate()
	for i in top.size():
		top[i].y = minf(top[i].y, lid)
	node.draw_colored_polygon(top, top_c)
	node.draw_line(Vector2(cut + slant, stone.position.y + 1.0),
		Vector2(cut - slant, stone.end.y - 1.0), Color(ink, 0.35), maxf(1.0, ow * 0.4))
	# The rock's shine, and two pocks in it.
	node.draw_circle(Vector2(stone.position.x + rad + 2.0, lid + (stone.end.y - lid) * 0.22),
		maxf(1.0, rad * 0.3), Color(1, 1, 1, 0.6))
	for k in 2:
		node.draw_circle(Vector2(stone.position.x + stone.size.x * (0.14 + 0.62 * float(k)),
			stone.end.y - stone.size.y * (0.18 + 0.1 * _face_seed(base, 72.0 + float(k)))),
			maxf(0.8, rad * 0.2), side)

	# The reef. Colours from the board's own corals, skipping any too near the
	# tier's hue, so the growth is never lost against its rock.
	var reef := [Color("#ff5c8a"), Color("#a45cf0"), Color("#ffb13d"), Color("#ff7ac8"),
		Color("#45d6c8"), Color("#ffd84a")]
	var pal: Array = []
	for c: Color in reef:
		var dh: float = absf(c.h - col.h)
		if minf(dh, 1.0 - dh) > 0.09:
			pal.append(c)
	# A cluster in one top corner, or both on a wide block: a branching coral
	# rooted a little way down the rock, so it can stand tall, with a dome at
	# its foot on the inside. Corners, because the letters are in the middle.
	var sides: Array = [_face_seed(base, 96.0) < 0.5]
	if w > 90.0:
		sides = [true, false]
	for i in sides.size():
		var left: bool = sides[i]
		var sd := _face_seed(base, 90.0 + float(i))
		var c1: Color = pal[int(_face_seed(base, 97.0 + float(i)) * float(pal.size())) % pal.size()]
		var c2: Color = pal[(pal.find(c1) + 1 + int(sd * 3.0)) % pal.size()]
		var inward: float = 1.0 if left else -1.0
		var bx: float = inner.position.x + w * (0.13 if left else 0.87)
		var dx: float = bx + inward * clampf(w * 0.14, 6.0, 16.0)
		_coral_dome(node, dx, stone.position.y, inner, cr, c2, ink, line)
		_coral_branch(node, bx, stone.position.y + stone.size.y * 0.30, inner, cr,
			c1, ink, line, sd if left else 1.0 - sd, t)

	# A bubble going up one side, away from the letters.
	var hb := _face_seed(base, 5.0)
	var rise: float = fmod(t * (0.22 + hb * 0.18) + hb, 1.0)
	var bx: float = stone.position.x + stone.size.x * (0.12 if hb < 0.5 else 0.88)
	var by: float = stone.end.y - rad - rise * (stone.size.y - rad * 2.0)
	node.draw_arc(Vector2(bx, by), maxf(1.2, minf(w, h) * 0.05), 0.0, TAU, 10,
		Color(1, 1, 1, 0.6 * sin(rise * PI)), maxf(1.0, ow * 0.5), true)
	return _stamp_on(face, Color("#0b2442"))


## Branching coral, as it grows on the board's sand: a trunk that forks, and
## forks again, all in straight segments. Stands on `foot` at `x` and stays
## inside `inner`.
static func _coral_branch(node: CanvasItem, x: float, foot: float, inner: Rect2, cr: float,
		c: Color, ink: Color, line: float, sd: float, t: float) -> void:
	var tall: float = foot - (inner.position.y + line * 1.5)
	var bw: float = clampf(tall * 0.13, 1.6, 3.6)
	var spread: float = tall * 0.42
	x = clampf(x, inner.position.x + spread + bw + line, inner.end.x - spread - bw - line)
	var sway: float = sin(t * 0.9 + sd * TAU) * bw * 0.35
	var b0 := Vector2(x, foot + bw)
	var fork := Vector2(x + (sd - 0.5) * bw, foot - tall * 0.42)
	var segs: Array = [[b0, fork]]
	var lean: float = -1.0 if sd < 0.5 else 1.0
	for k in 3:
		var ang: float = (-0.62 + 0.62 * float(k)) * lean
		var reach: float = tall * (0.58 if k == 1 else 0.46)
		var tip := fork + Vector2(sin(ang) * reach + sway, -cos(ang) * reach)
		tip.y = maxf(tip.y, inner.position.y + line * 1.5)
		segs.append([fork, tip])
		if k != 1 and tall > 15.0:
			var mid: Vector2 = fork.lerp(tip, 0.55)
			var twig := mid + Vector2(sin(ang - 0.7 * lean) * reach * 0.36 + sway,
				-cos(ang - 0.7 * lean) * reach * 0.36)
			twig.y = maxf(twig.y, inner.position.y + line * 1.5)
			segs.append([mid, twig])
	for pass_i in 2:
		var wd: float = bw + (line * 2.0 if pass_i == 0 else 0.0)
		for sg: Array in segs:
			node.draw_line(sg[0], sg[1], ink if pass_i == 0 else c, wd)
	# A catch of light up the trunk and the tallest arm.
	for sg: Array in segs.slice(0, 3):
		node.draw_line(sg[0], (sg[0] as Vector2).lerp(sg[1], 0.5), c.lerp(Color.WHITE, 0.3),
			maxf(1.0, bw * 0.4))


static var _dome_arc := PackedVector2Array()


## A low coral dome, a flattened half of an ellipse sitting on the rock.
static func _coral_dome(node: CanvasItem, x: float, foot: float, inner: Rect2, cr: float,
		c: Color, ink: Color, line: float) -> void:
	var rx: float = clampf(cr * 0.75, 5.0, 13.0)
	var ry: float = minf(rx * 0.55, foot - inner.position.y - line * 1.5)
	x = clampf(x, inner.position.x + rx + line, inner.end.x - rx - line)
	if _dome_arc.is_empty():
		for k in 9:
			var a: float = PI + PI * float(k) / 8.0
			_dome_arc.append(Vector2(cos(a), sin(a)))
	var o := Vector2(x, foot + 1.0)
	var pts := PackedVector2Array()
	var grown := PackedVector2Array()
	var cap := PackedVector2Array()
	for v: Vector2 in _dome_arc:
		pts.append(o + v * Vector2(rx, ry))
		grown.append(o + v * Vector2(rx + line, ry + line))
		cap.append(o + Vector2(-rx * 0.12, -ry * 0.06) + v * Vector2(rx * 0.72, ry * 0.8))
	grown.append(o + Vector2(rx + line, line))
	grown.append(o + Vector2(-rx - line, line))
	node.draw_colored_polygon(grown, ink)
	node.draw_colored_polygon(pts, c.darkened(0.18))
	node.draw_colored_polygon(cap, c)
	node.draw_circle(Vector2(x - rx * 0.4, foot + 1.0 - ry * 0.55), maxf(0.8, ry * 0.14),
		Color(1, 1, 1, 0.7))


## Aurora. A block of glacier ice with snow on it: hard facets in the tier's
## colour, a crack caught inside, the green of the sky sliding across the
## surface, and a cap of snow drawn the way the board's pines and rocks wear
## theirs — white on top, lavender underneath, with an ink line round it.
##
## The earlier face was a tinted pane with lines to an apex, which read as an
## envelope; nothing on the board is made of panes.
static func _face_ice(node: CanvasItem, rect: Rect2, col: Color, hot: bool,
		base: float, t: float) -> Color:
	var ow := _ink_w(rect)
	var ink: Color = Color.WHITE if hot else Color("#0f2442")
	var line: float = ow * (1.5 if hot else 1.0)
	node.draw_colored_polygon(_rrect(rect, ow * 1.2), ink)
	var r := rect.grow(-line)
	var w := r.size.x
	var h := r.size.y
	var sh: float = clampf(h * 0.34, 7.0, 18.0)

	# The ice, in three facets: a lit one catching the sky up and to the left,
	# a deep one in the lower right, and the middle between them. Split with
	# straight edges, because that is what makes it ice and not water.
	var mid_c := col.lerp(Color.WHITE, 0.34)
	var lit := col.lerp(Color.WHITE, 0.62)
	var deep := _deeper(col, 0.14).lerp(Color("#3b4aa8"), 0.18)
	node.draw_colored_polygon(_rrect(r, ow * 0.6), mid_c)
	var jig := _face_seed(base, 60.0) * 0.12
	var lit_poly := PackedVector2Array([
		r.position + Vector2(1.0, 1.0), Vector2(r.position.x + w * (0.60 + jig), r.position.y + 1.0),
		Vector2(r.position.x + w * (0.34 + jig), r.position.y + h * 0.52),
		Vector2(r.position.x + 1.0, r.position.y + h * (0.74 - jig)),
	])
	node.draw_colored_polygon(lit_poly, lit)
	var deep_poly := PackedVector2Array([
		Vector2(r.end.x - 1.0, r.position.y + h * (0.28 + jig)), r.end - Vector2(1.0, 1.0),
		Vector2(r.position.x + w * (0.40 - jig), r.end.y - 1.0),
		Vector2(r.position.x + w * (0.70 - jig), r.position.y + h * 0.60),
	])
	node.draw_colored_polygon(deep_poly, deep)
	# The ridges between facets, lit.
	node.draw_polyline(PackedVector2Array([lit_poly[1], lit_poly[2], lit_poly[3]]),
		Color(1, 1, 1, 0.55), maxf(1.0, ow * 0.45), true)
	node.draw_polyline(PackedVector2Array([deep_poly[0], deep_poly[3], deep_poly[2]]),
		Color(lit, 0.45), maxf(1.0, ow * 0.4), true)

	# The sky on the surface: a slow band of aurora green crossing the face,
	# kept inside by building it from the face's own edges.
	var run: float = fmod(t * 0.07 + _face_seed(base, 61.0), 1.0)
	var bx: float = r.position.x - w * 0.4 + run * w * 1.8
	var band := PackedVector2Array([
		Vector2(clampf(bx, r.position.x + 1.0, r.end.x - 1.0), r.position.y + sh),
		Vector2(clampf(bx + w * 0.16, r.position.x + 1.0, r.end.x - 1.0), r.position.y + sh),
		Vector2(clampf(bx + w * 0.16 - h * 0.5, r.position.x + 1.0, r.end.x - 1.0), r.end.y - 1.0),
		Vector2(clampf(bx - h * 0.5, r.position.x + 1.0, r.end.x - 1.0), r.end.y - 1.0),
	])
	node.draw_colored_polygon(band, Color("#6dffc8", 0.16))

	# Now and then, a glint off the lit facet.
	var gp: float = fmod(t * 0.23 + _face_seed(base, 62.0), 1.0)
	if gp < 0.14:
		var gs: float = minf(w, h) * 0.55 * sin(gp / 0.14 * PI)
		_sprite(node, glint(), Vector2(r.position.x + w * 0.22, r.position.y + sh + h * 0.12),
			Vector2(gs, gs), Color(1, 1, 1, 0.9))

	# The snow, faceted as it lies on the board's pines: a white top plane and
	# under it a deep indigo side that is thick in places and thin in others,
	# with an ink line along the bottom of it. The lumpy cap of a first redraw
	# read as lace trim; the board's snow is cut, not piped.
	var steps := maxi(3, int(round(w / 11.0)))
	var edge := PackedVector2Array()
	for i in steps + 1:
		var u: float = float(i) / float(steps)
		var depth: float = 0.55 + 0.45 * _face_seed(base, 64.0 + float(i))
		if i == 0 or i == steps:
			depth = 0.62
		edge.append(Vector2(r.position.x + w * u, r.position.y + sh * depth))
	var cap := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y)])
	for i in range(edge.size() - 1, -1, -1):
		cap.append(edge[i])
	var shadow := cap.duplicate()
	for i in shadow.size():
		shadow[i].y += line
	node.draw_colored_polygon(shadow, ink)
	node.draw_colored_polygon(cap, Color("#5663c4"))
	var plane := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y)])
	for i in range(edge.size() - 1, -1, -1):
		var e: Vector2 = edge[i]
		var lift: float = 0.66 + 0.18 * _face_seed(base, 80.0 + float(i))
		plane.append(Vector2(e.x, r.position.y + (e.y - r.position.y) * lift))
	node.draw_colored_polygon(plane, Color("#f3f7ff"))
	node.draw_rect(Rect2(r.position.x + 1.0, r.position.y, w - 2.0, maxf(1.0, sh * 0.12)),
		Color(1, 1, 1, 0.9))

	# Icicles off the deepest points of the snow, on anything big enough to
	# hang them clear of the letters.
	if w > 60.0 and h > 56.0:
		# From the outer quarters of the edge, so they hang at the ends of the
		# block and not into the letters in the middle of it.
		var reach := maxi(1, int(float(steps) * 0.25))
		for k in 2:
			var ei: int = 1 + int(_face_seed(base, 66.0 + float(k)) * float(reach))
			if k == 1:
				ei = steps - ei
			var p0: Vector2 = edge[ei]
			var iw: float = maxf(1.5, sh * 0.2)
			var ih: float = sh * (0.8 + 0.5 * _face_seed(base, 70.0 + float(k)))
			var icicle := PackedVector2Array([p0 + Vector2(-iw, -1.0), p0 + Vector2(iw, -1.0),
				p0 + Vector2(0.0, ih)])
			node.draw_colored_polygon(PackedVector2Array([icicle[0] + Vector2(-line, 0.0),
				icicle[1] + Vector2(line, 0.0), icicle[2] + Vector2(0.0, line * 1.5)]), ink)
			node.draw_colored_polygon(icicle, Color("#dff2ff"))
			node.draw_line(icicle[0].lerp(icicle[2], 0.1), icicle[2].lerp(icicle[0], 0.3),
				Color(1, 1, 1, 0.9), maxf(1.0, iw * 0.4))

	# And snow coming down across it, as it does over the whole board.
	for k in 2:
		var fs := _face_seed(base, 74.0 + float(k))
		var fall: float = fmod(t * (0.10 + 0.06 * fs) + fs, 1.0)
		var fx: float = r.position.x + w * (0.15 + 0.7 * fs) + sin(t * 1.3 + fs * 9.0) * w * 0.04
		var fy: float = r.position.y + sh + fall * (h - sh - 2.0)
		var fsz: float = maxf(2.5, minf(w, h) * 0.09)
		_sprite(node, soft_dot(), Vector2(fx, fy), Vector2(fsz, fsz),
			Color(1, 1, 1, 0.85 * sin(fall * PI)))
	return Color("#0f2442")


## A slab in three tones: `hi` along its top and left edges, `lo` along its
## bottom and right, and `face` inside them. Returns the face.
static func _bevel(node: CanvasItem, r: Rect2, b: float, rad: float, hi: Color,
		face: Color, lo: Color) -> Rect2:
	node.draw_colored_polygon(_rrect(r, rad), hi)
	var f := r.grow(-b)
	node.draw_colored_polygon(PackedVector2Array([
		Vector2(r.end.x, r.position.y + rad), Vector2(r.end.x, r.end.y - rad),
		Vector2(r.end.x - rad, r.end.y), Vector2(r.position.x + rad, r.end.y),
		Vector2(f.position.x, f.end.y), f.end, Vector2(f.end.x, f.position.y),
	]), lo)
	node.draw_rect(f, face)
	return f


## A soft cap of lumps along the top of `r` — moss here, and the cloud's lobes
## are the same idea — inked, in two tones, and kept inside `r`.
static func _lumpy_cap(node: CanvasItem, r: Rect2, depth: float, lit: Color,
		shade: Color, ink: Color, line: float, base: float, salt: float) -> void:
	var n := maxi(2, int(round(r.size.x / (depth * 1.7))))
	var lumps: Array[Vector3] = []
	for i in n:
		var u: float = (float(i) + 0.5) / float(n)
		var lr: float = depth * 0.5 * (0.8 + 0.45 * _face_seed(base, salt + float(i)))
		var lx: float = clampf(r.position.x + r.size.x * u, r.position.x + lr, r.end.x - lr)
		lumps.append(Vector3(lx, r.position.y + depth * 0.5, lr))
	var band := Rect2(r.position.x, r.position.y, r.size.x, depth * 0.5)
	for L in lumps:
		node.draw_circle(Vector2(L.x, L.y), L.z + line, ink)
	node.draw_rect(Rect2(band.position, band.size + Vector2(0.0, line)), ink)
	node.draw_colored_polygon(_rrect(band, minf(line * 1.5, band.size.y * 0.5)), shade)
	for L in lumps:
		node.draw_circle(Vector2(L.x, L.y), L.z, shade)
	for L in lumps:
		node.draw_circle(Vector2(L.x - L.z * 0.15, L.y - L.z * 0.25), L.z * 0.72, lit)
	node.draw_rect(Rect2(band.position + Vector2(line, 0.0),
		Vector2(band.size.x - line * 2.0, band.size.y * 0.7)), lit)


## Forest. A plank of timber with moss on it: the tier as the wood, a darker
## edge along the bottom where the plank has thickness, grain that runs round a
## knot, and a cushion of moss along the top in the greens of the board's trees.
static func _face_bark(node: CanvasItem, rect: Rect2, col: Color, hot: bool,
		base: float, t: float) -> Color:
	var ow := _ink_w(rect)
	var ink: Color = Color.WHITE if hot else Color("#1f1a0c")
	var line: float = ow * (1.5 if hot else 1.0)
	node.draw_colored_polygon(_rrect(rect, ow * 1.6), ink)
	var r := rect.grow(-line)
	var w := r.size.x
	var h := r.size.y
	# Wood: the tier, pulled a little toward the timber on the board, so the
	# blue tiers are weathered grey-blue boards rather than blue plastic.
	var wood := col.lerp(Color("#9a6534"), 0.20)
	var edge := wood.darkened(0.30)
	var grain := wood.darkened(0.24)
	var plank := _rrect(r, ow)
	node.draw_colored_polygon(plank, edge)
	var lip: float = maxf(2.0, h * 0.15)
	var face := plank.duplicate()
	for i in face.size():
		face[i].y = minf(face[i].y, r.end.y - lip)
	node.draw_colored_polygon(face, wood)
	node.draw_line(Vector2(r.position.x + ow, r.end.y - lip), Vector2(r.end.x - ow, r.end.y - lip),
		wood.darkened(0.45), maxf(1.0, ow * 0.5))

	# Grain, bending round a knot in one of the outer thirds.
	var moss_d: float = clampf(h * 0.24, 5.0, 12.0)
	var gy0: float = r.position.y + moss_d * 0.9
	var gy1: float = r.end.y - lip - 2.0
	# Low and toward an end, where it is a knot in the wood and not a bullet
	# point beside the letters.
	var kx: float = r.position.x + w * (0.13 if _face_seed(base, 10.0) < 0.5 else 0.87)
	var ky: float = lerpf(gy0, gy1, 0.82)
	var kr: float = clampf(minf(w, h) * 0.10, 2.0, 7.0)
	if gy1 - gy0 > 6.0:
		for k in 3:
			var gy: float = lerpf(gy0, gy1, (float(k) + 0.5) / 3.0)
			var pts := PackedVector2Array()
			for s in 7:
				var x: float = lerpf(r.position.x + ow * 2.0, r.end.x - ow * 2.0, float(s) / 6.0)
				var d: float = clampf(absf(x - kx) / (kr * 3.0), 0.0, 1.0)
				var push: float = kr * 1.6 * (1.0 - d * d) * (1.0 - d * d) * signf(gy - ky + 0.01)
				pts.append(Vector2(x, gy + push + (0.8 if (s + k) % 2 == 0 else -0.8)))
			node.draw_polyline(pts, grain, maxf(1.0, ow * 0.45), true)
		node.draw_arc(Vector2(kx, ky), kr * 1.25, 0.0, TAU, 16, grain, maxf(1.0, ow * 0.5), true)
		node.draw_circle(Vector2(kx, ky), kr * 0.6, wood.darkened(0.38))
	# The lit top edge of the board, under the moss.
	node.draw_rect(Rect2(r.position.x + ow, r.position.y + moss_d * 0.62, w - ow * 2.0,
		maxf(1.0, h * 0.03)), Color(1, 1, 1, 0.25))

	_lumpy_cap(node, Rect2(r.position, Vector2(w, moss_d)), moss_d, Color("#86d64a"),
		Color("#3d8a36"), ink, line, base, 40.0)
	return _stamp_on(wood, Color("#1a1208"))


## Desert. A block of the canyon: laid-down strata in the tier's colour, lit
## on top where the sun catches it and in shadow down one side as the canyon
## walls are, and the corners worn round by the wind.
static func _face_sandstone(node: CanvasItem, rect: Rect2, col: Color, hot: bool,
		base: float, t: float) -> Color:
	var ow := _ink_w(rect)
	var ink: Color = Color.WHITE if hot else Color("#4a220c")
	var line: float = ow * (1.5 if hot else 1.0)
	var rad: float = clampf(minf(rect.size.x, rect.size.y) * 0.2, 3.0, 11.0)
	node.draw_colored_polygon(_rrect(rect, rad), ink)
	var r := rect.grow(-line)
	rad = maxf(1.0, rad - line)
	var w := r.size.x
	var h := r.size.y

	# The strata, drawn from the bottom up: each band is the whole shape cut
	# flat at its own top, over the ones below it.
	var tones := [col.lerp(Color.WHITE, 0.30), col.lerp(Color.WHITE, 0.08),
		_deeper(col, 0.08), col.lerp(Color.WHITE, 0.14), _deeper(col, 0.18)]
	var n := 3 if h < 50.0 else 5
	var cuts: Array[float] = []
	for i in n:
		var f: float = float(i) / float(n)
		cuts.append(r.position.y + h * (f * 0.92 + (0.0 if i == 0 else 0.05 * _face_seed(base, 10.0 + float(i)))))
	var shape := _rrect(r, rad)
	node.draw_colored_polygon(shape, tones[n - 1])
	for i in range(n - 2, -1, -1):
		var band := shape.duplicate()
		for j in band.size():
			band[j].y = minf(band[j].y, cuts[i + 1])
		node.draw_colored_polygon(band, tones[i])
	# The lines between the layers. Straight, with a step or two where the
	# rock has worn back unevenly: a wavy line made the blue tiers read as
	# water, and the canyon's layers are flat.
	for i in range(1, n):
		var y0: float = cuts[i]
		var step_x: float = r.position.x + w * (0.25 + 0.5 * _face_seed(base, 20.0 + float(i)))
		var dy: float = minf(2.0, h * 0.04) * (1.0 if i % 2 == 0 else -1.0)
		node.draw_polyline(PackedVector2Array([
			Vector2(r.position.x + rad * 0.4, y0), Vector2(step_x, y0),
			Vector2(step_x + 1.5, y0 + dy), Vector2(r.end.x - rad * 0.4, y0 + dy),
		]), Color(_deeper(col, 0.32), 0.75), maxf(1.0, ow * 0.5))

	# The shaded side of the block.
	var cut: float = r.position.x + w * (0.80 + 0.06 * _face_seed(base, 30.0))
	var slant: float = minf(w * 0.05, 4.0)
	var side := shape.duplicate()
	for i in side.size():
		var ex: float = lerpf(cut - slant, cut + slant, (side[i].y - r.position.y) / maxf(1.0, h))
		side[i].x = maxf(side[i].x, ex)
	node.draw_colored_polygon(side, Color(_deeper(col, 0.35), 0.55))
	# The lip of the top layer, where the sun is.
	node.draw_rect(Rect2(r.position.x + rad, r.position.y + maxf(1.0, h * 0.04), w - rad * 2.0,
		maxf(1.0, h * 0.035)), Color(1, 1, 1, 0.45))

	return _stamp_on(tones[1], Color("#3a1a08"))


## Space. A slab of dark glass with the board's sky caught in it: the tier
## deep and lit from inside in flat steps, a drift of nebula through it, stars
## that catch, and on a big one a ringed planet like the one on the board.
static func _face_nebula(node: CanvasItem, rect: Rect2, col: Color, hot: bool,
		base: float, t: float) -> Color:
	var ow := _ink_w(rect)
	var ink: Color = Color.WHITE if hot else Color("#150a33")
	var line: float = ow * (1.5 if hot else 1.0)
	node.draw_colored_polygon(_rrect(rect, ow * 2.0), ink)
	var r := rect.grow(-line)
	var w := r.size.x
	var h := r.size.y
	var deep := Color.from_hsv(col.h, minf(1.0, col.s * 1.05), col.v * 0.42)
	var mid := Color.from_hsv(col.h, minf(1.0, col.s * 1.0), col.v * 0.62)
	var glow := col.lerp(Color.WHITE, 0.15)
	node.draw_colored_polygon(_rrect(r, ow * 1.2), deep)
	# Lit from inside, off-centre, in two flat steps.
	var core := r.get_center() + Vector2(-w * 0.12, -h * 0.10)
	var cw: float = w * 0.78
	var ch: float = h * 0.72
	node.draw_colored_polygon(_rrect(Rect2(core - Vector2(cw, ch) * 0.5, Vector2(cw, ch)),
		minf(cw, ch) * 0.45), mid)
	node.draw_colored_polygon(_rrect(Rect2(core - Vector2(cw, ch) * 0.28, Vector2(cw, ch) * 0.56),
		minf(cw, ch) * 0.28), Color(glow, 0.55))
	# A ribbon of nebula across it, magenta, drifting.
	var drift: float = sin(t * 0.25 + _face_seed(base, 3.0) * TAU) * w * 0.04
	for k in 5:
		var u: float = (float(k) + 0.5) / 5.0
		var cx: float = r.position.x + w * u + drift
		var cy: float = r.position.y + h * (0.62 - 0.30 * u + 0.08 * sin(u * 6.0 + base))
		var cr: float = minf(w, h) * (0.14 + 0.06 * _face_seed(base, 4.0 + float(k)))
		cx = clampf(cx, r.position.x + cr, r.end.x - cr)
		cy = clampf(cy, r.position.y + cr, r.end.y - cr)
		node.draw_circle(Vector2(cx, cy), cr, Color("#ff5fd2", 0.13))
	# The planet, in a corner, only where there is a corner to spare: on
	# anything shorter than three rows it landed under the letters.
	if w > 100.0 and h > 90.0:
		var pr: float = clampf(minf(w, h) * 0.13, 5.0, 11.0)
		var right := _face_seed(base, 5.0) < 0.5
		var pc := Vector2(r.end.x - pr * 2.0 if right else r.position.x + pr * 2.0,
			r.end.y - pr * 1.8)
		var ring_c := Color("#e8d6ff")
		node.draw_circle(pc, pr + line, ink)
		node.draw_circle(pc, pr, Color("#b27cf0"))
		node.draw_circle(pc + Vector2(-pr * 0.2, -pr * 0.2), pr * 0.72, Color("#c99bff"))
		var ring := PackedVector2Array()
		for k in 17:
			var a: float = PI * float(k) / 16.0
			ring.append(pc + Vector2(cos(a) * pr * 1.75, sin(a) * pr * 0.42).rotated(-0.35))
		node.draw_polyline(ring, ink, maxf(2.0, line * 2.2), true)
		node.draw_polyline(ring, ring_c, maxf(1.2, line * 0.9), true)
	# Stars. Most are points; one is a glint that catches now and then.
	for k in 5:
		var sx := _face_seed(base, 7.0 + float(k))
		var sy := _face_seed(base, 17.0 + float(k))
		var tw: float = 0.5 + 0.5 * sin(t * (1.3 + sx * 2.0) + float(k) * 1.7)
		node.draw_circle(Vector2(r.position.x + w * (0.1 + sx * 0.8), r.position.y + h * (0.1 + sy * 0.8)),
			maxf(0.8, minf(w, h) * 0.022), Color(1, 1, 1, 0.45 + 0.5 * tw))
	var gp: float = fmod(t * 0.3 + _face_seed(base, 8.0), 1.0)
	if gp < 0.2:
		var gs: float = minf(w, h) * 0.5 * sin(gp / 0.2 * PI)
		_sprite(node, glint(), Vector2(r.position.x + w * (0.2 + 0.6 * _face_seed(base, 9.0)),
			r.position.y + h * 0.25), Vector2(gs, gs), Color(1, 1, 1, 0.95))
	# The glass: a shine across the top corner.
	node.draw_colored_polygon(PackedVector2Array([
		r.position + Vector2(ow, ow), r.position + Vector2(w * 0.42, ow),
		r.position + Vector2(ow, h * 0.46)]), Color(1, 1, 1, 0.10))
	node.draw_rect(Rect2(r.position.x + ow * 1.5, r.position.y + ow, w * 0.3, maxf(1.0, h * 0.03)),
		Color(1, 1, 1, 0.5))
	return Color.WHITE


## Nexus. A block of the plaza: pale cut stone in the tier's colour, bevelled
## so it has an edge to catch the light, and gold set into its corners the way
## the plaza's floor has gold run through its joints, glowing a little and
## slowly.
static func _face_rune(node: CanvasItem, rect: Rect2, col: Color, hot: bool,
		base: float, t: float) -> Color:
	var ow := _ink_w(rect)
	var ink: Color = Color.WHITE if hot else Color("#2a2046")
	var line: float = ow * (1.5 if hot else 1.0)
	node.draw_colored_polygon(_rrect(rect, ow * 1.4), ink)
	var r := rect.grow(-line)
	var w := r.size.x
	var h := r.size.y
	var stone := col.lerp(Color("#e8e0d0"), 0.35)
	var bv: float = clampf(minf(w, h) * 0.12, 2.5, 6.0)
	var f := _bevel(node, r, bv, ow, stone.lerp(Color.WHITE, 0.45), stone,
		_deeper(stone, 0.26))
	var gold := Color("#e8a92c")
	var hotg := Color("#ffe08a")
	var pulse: float = 0.5 + 0.5 * sin(t * 1.15 + _face_seed(base, 50.0) * TAU)
	# The inlay: gold set into each corner of the face, a bracket with a stud
	# at its point. A full border ran through the letters on anything small.
	var inset: float = maxf(2.0, minf(f.size.x, f.size.y) * 0.10)
	var ring := f.grow(-inset)
	var arm: float = clampf(minf(ring.size.x, ring.size.y) * 0.34, 3.0, 14.0)
	var gw: float = maxf(1.3, minf(w, h) * 0.04)
	for c: Vector2 in [ring.position, Vector2(ring.end.x, ring.position.y),
			Vector2(ring.position.x, ring.end.y), ring.end]:
		var sx: float = 1.0 if c.x < ring.get_center().x else -1.0
		var sy: float = 1.0 if c.y < ring.get_center().y else -1.0
		var bracket := PackedVector2Array([c + Vector2(sx * arm, 0.0), c, c + Vector2(0.0, sy * arm)])
		node.draw_polyline(bracket, gold.darkened(0.35), gw + 1.2)
		node.draw_polyline(bracket, gold.lerp(hotg, pulse * 0.6), gw * 0.6)
		var stud: float = maxf(1.4, gw * 1.1)
		node.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -stud),
			c + Vector2(stud, 0), c + Vector2(0, stud), c + Vector2(-stud, 0)]),
			hotg.lerp(Color.WHITE, pulse * 0.4))
	# And a gold joint along the foot of the big ones, as the plaza's floor
	# has gold run through it.
	if f.size.y > 44.0:
		node.draw_line(Vector2(ring.position.x + arm + 3.0, ring.end.y),
			Vector2(ring.end.x - arm - 3.0, ring.end.y), Color(gold, 0.35 + 0.3 * pulse),
			maxf(1.0, gw * 0.5))
	# A chip off one corner of the stone, so it is cut and worn and not cast.
	var right := _face_seed(base, 51.0) < 0.5
	var cc := Vector2(r.end.x if right else r.position.x, r.position.y)
	var cs: float = bv * 1.4
	node.draw_colored_polygon(PackedVector2Array([cc, cc + Vector2(-cs if right else cs, 0.0),
		cc + Vector2(0.0, cs)]), ink)
	return _stamp_on(stone, Color("#2a2046"))


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
		# Forest. See `_face_bark`.
		"bark":
			return _face_bark(node, rect, col, hot, base, t)

		# Volcano, and Ocean. See `_face_magma` and `_face_coral`.
		"magma":
			return _face_magma(node, rect, col, hot, base, t)
		"coral":
			return _face_coral(node, rect, col, hot, base, t)

		# Space. See `_face_nebula`.
		"nebula":
			return _face_nebula(node, rect, col, hot, base, t)

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
			# Wet glass: a sheen across it, and drops running down in the little
			# hops rain makes on a window, each on its own clock.
			node.draw_colored_polygon(PackedVector2Array([
				rect.position + Vector2(w * 0.18, 2.0), rect.position + Vector2(w * 0.34, 2.0),
				rect.position + Vector2(w * 0.12, h - 2.0), rect.position + Vector2(w * -0.04 + 2.0, h - 2.0),
			]), Color(1, 1, 1, 0.06))
			var dr: float = maxf(1.2, minf(w, h) * 0.035)
			for i in 3:
				var ds := _face_seed(base, 120.0 + float(i))
				var hop: float = fmod(t * (0.10 + ds * 0.08) + ds, 1.0) * 6.0
				var fall: float = (floorf(hop) + smoothstep(0.6, 1.0, fmod(hop, 1.0))) / 6.0
				var dx: float = rect.position.x + w * (0.14 + ds * 0.72)
				var dy: float = rect.position.y + 3.0 + fall * (h - 6.0)
				node.draw_line(Vector2(dx, dy - h * 0.14 * smoothstep(0.0, 0.2, fall)),
					Vector2(dx, dy), Color(glow, 0.22), maxf(1.0, dr * 0.6))
				node.draw_circle(Vector2(dx, dy), dr, Color(glow.lightened(0.3), 0.55))
			# The tube, glowing: three strokes from wide and faint to thin and
			# hot, all inside the block so it does not bleed onto its
			# neighbours. And now and then a buzz, like the signs on the street.
			var buzz: float = 0.35 if _face_seed(floorf(t * 8.0) + base, 140.0) > 0.975 else 1.0
			node.draw_rect(rect.grow(-3.0), Color(glow, 0.16 * buzz), false, 5.0)
			node.draw_rect(rect.grow(-1.5), Color(glow, 0.35 * buzz), false, 3.0)
			node.draw_rect(rect, Color(col, 0.35), false, 3.0)
			_face_rim(node, rect, Color(glow, 0.95 * buzz), hot, 1.5)
			return col.lightened(0.62)

		# Clouds. The one soft face in the set, and the second of the two that
		# print dark type — the body is too pale for white to survive on it.
		# Drawn the way the board's own clouds are drawn; see `_face_cloud`.
		"cloud":
			return _face_cloud(node, rect, col, hot, base, t)

		# Desert, and Nexus. See `_face_sandstone` and `_face_rune`.
		"sandstone":
			return _face_sandstone(node, rect, col, hot, base, t)
		"rune":
			return _face_rune(node, rect, col, hot, base, t)

		# Aurora. See `_face_ice`.
		"ice":
			return _face_ice(node, rect, col, hot, base, t)

	return Color.WHITE

	return Color.WHITE
