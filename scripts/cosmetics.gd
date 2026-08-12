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
}


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
