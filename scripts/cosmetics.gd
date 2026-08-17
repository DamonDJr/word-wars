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

const BLOCK_STYLES := ["solid", "outline", "glass", "circuit"]


## Paint one, and report what colour its label should be — the ink has to be
## decided per style rather than assumed dark, because two of the four are
## mostly transparent.
static func draw_block_face(node: CanvasItem, rect: Rect2, col: Color,
		style: String, hot: bool) -> Color:
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
		_:
			node.draw_rect(rect, Color(col, 0.92 if hot else 0.80), true)
			# The lighter top edge is most of what makes a filled rectangle read
			# as a block with a face rather than as a swatch.
			node.draw_rect(Rect2(rect.position + Vector2(4.0, 4.0),
				Vector2(rect.size.x - 8.0, 2.0)), Color(1, 1, 1, 0.30), true)
			node.draw_rect(rect.grow(-5.0), Color(1, 1, 1, 0.10), false, 1.0)
			return Color("#0b1020")
