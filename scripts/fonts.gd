extends RefCounted
class_name Fonts
## The game's type, in one place.
##
## Barlow is the house face: Semi Condensed in real weights for everything you
## read, and Condensed Black for the things you glance at: the wordmark, the
## score, and the stamps on the blocks. Condensed is narrow enough that a
## four-letter stamp stays big on a one-cell block.
##
## A Premium board can bring its own face for the letters you play with; see
## `for_board` and the `font` keys in `Cosmetics.THEMES`.
##
## Every face falls back to the engine's own font, so a build that lost a file
## still draws text. Player names can be in any script; the imports allow the
## system fallback for glyphs Barlow does not have.

const BODY := "res://fonts/BarlowSemiCondensed-Medium.ttf"
const KEY := "res://fonts/BarlowSemiCondensed-SemiBold.ttf"
const BOLD := "res://fonts/BarlowSemiCondensed-Bold.ttf"
const DISPLAY := "res://fonts/BarlowCondensed-Black.ttf"

## How far to lift Barlow's glyphs, as a fraction of its line height.
##
## Every label in the game is centred on its font's line box, and Barlow sits
## its capitals low in that box: ascent 1.0, descent 0.2 and cap height 0.7 em
## put the middle of a capital 0.05 em below the middle of the box. Uncorrected,
## every key, tile and button label sits a couple of pixels low. -0.045 of the
## 1.2 em line puts them back in the middle. Measured from the font files.
const HOUSE_LIFT := -0.045

static var _cache := {}


static func _face(path: String, lift: float) -> Font:
	if not _cache.has(path):
		var f: Font = null
		if ResourceLoader.exists(path):
			f = load(path) as Font
		if f == null:
			push_warning("Fonts: %s missing, using the engine font" % path)
			f = ThemeDB.fallback_font
		else:
			var fv := FontVariation.new()
			fv.base_font = f
			fv.baseline_offset = lift
			f = fv
		_cache[path] = f
	return _cache[path]


static func body() -> Font:
	return _face(BODY, HOUSE_LIFT)


static func key() -> Font:
	return _face(KEY, HOUSE_LIFT)


static func bold() -> Font:
	return _face(BOLD, HOUSE_LIFT)


static func display() -> Font:
	return _face(DISPLAY, HOUSE_LIFT)


## A board's own face, at the weight its theme asks for, falling back to the
## house display face for any glyph it lacks (player names, punctuation) or if
## the file is missing. Returns null when the theme has no face of its own.
##
## `dy` is how far to move its glyphs down, as a fraction of the font size (the
## theme's `font_dy`). It becomes the face's own baseline offset, so every
## piece of code that draws with it gets its capitals centred without having
## to know which face it was handed.
static func for_board(path: String, axes: Dictionary, dy := 0.0) -> Font:
	if path == "":
		return null
	var key := "%s %s %s" % [path, axes, dy]
	if not _cache.has(key):
		var base: Font = null
		if ResourceLoader.exists(path):
			base = load(path) as Font
		if base == null:
			push_warning("Fonts: board face %s missing, using the house face" % path)
			_cache[key] = null
			return null
		var fv := FontVariation.new()
		fv.base_font = base
		if not axes.is_empty():
			# As numeric tags. The docs say names like "wght" work too; on 4.7
			# they are accepted and silently ignored, and the face draws at its
			# default (lightest) weight. Checked by rendering both.
			var ts := TextServerManager.get_primary_interface()
			var tagged := {}
			for k in axes:
				tagged[ts.name_to_tag(String(k)) if k is String else k] = axes[k]
			fv.variation_opentype = tagged
		# `baseline_offset` is a fraction of the line height, not of the size.
		fv.baseline_offset = dy * 100.0 / maxf(1.0, base.get_height(100))
		fv.fallbacks = [display()]
		_cache[key] = fv
	return _cache[key]


## A theme's own face, or null for one that keeps the house faces.
static func for_theme(id: String) -> Font:
	return for_board(String(Cosmetics.theme_opt(id, "font")),
		Cosmetics.theme_opt(id, "font_axes") as Dictionary,
		float(Cosmetics.theme_opt(id, "font_dy")))
