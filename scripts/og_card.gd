extends Node
class_name OgCard
## Draws the picture a link preview shows, and writes it to disk.
##
## Not the same picture as `share_card.gd`, and the difference is the whole
## reason this file exists. That card is 1080x1920 because it is *attached* to a
## message — a story, a reply, a DM — and every one of those is a vertical frame.
## This one is 1200x630 because it is *scraped*: Facebook, Threads and LinkedIn
## fetch the shared URL, read its `og:image`, and crop whatever they find to
## roughly 1.91:1. Hand them a portrait card and they take a letterboxed strip
## out of the middle of it, which is the wordmark and nothing else.
##
## ## Why there is no score on it
##
## The obvious version of this file draws the player's actual number, the way the
## story card does. It cannot: a link preview is composed on Facebook's servers
## from a URL they fetched, and the only thing on the far end of that URL is a
## static file sitting in `docs/`. There is no request-time renderer to put
## "14,320" into a picture, and there never will be on GitHub Pages.
##
## So the split is: the preview image is per *mode*, pre-rendered and committed,
## and the player's own numbers land on the page itself — `docs/s/` reads them
## out of the query string. The preview is the hook; the page is the payoff. That
## is a real loss against a server-rendered card and it is worth being honest
## about, but it is not close to the thing it replaces, which was a bare App
## Store link with a generic grey box beside it.
##
## ## What it has to do at thumbnail size
##
## A feed renders this at about 500 across, which is where most of the decisions
## here come from. Three things survive that: the name, the tiles, and one line
## of large type. Anything else — stats, a footer, a second sentence — is a smear
## at that size and was cut. The tiles do the heaviest lifting of the three:
## somebody scrolling past learns this is a word game from them alone.
##
## `tools/ogcards.gd` renders the set into `docs/s/og/`. Look at them before
## shipping; like the story card, this draws a picture nobody playing the game
## will ever see.

## The shape every scraper crops towards. Facebook's own guidance, and what
## Threads and LinkedIn inherit from it.
const SIZE := Vector2i(1200, 630)

## Side margin for everything that is not full-bleed.
const MARGIN := 80.0


var _painter: Node2D = null
var _vp: SubViewport = null
var _font: Font = null
var _font_bold: Font = null
var _font_title: Font = null
var _sb := StyleBoxFlat.new()

var _mode := ""
var _accent := Color("#ffd166")
var _word := ""
var _dare := ""


func _init(font: Font, font_bold: Font, font_title: Font = null) -> void:
	_font = font
	_font_bold = font_bold
	_font_title = font_title if font_title != null else font_bold


## Draw one card and write it to `path`. Returns false if nothing was written.
##
## The same viewport dance as `share_card.gd`, and for the same reason: a
## SubViewport does not render on the frame you fill it, so the image comes back
## blank without the await. See the long note there.
func render(mode: String, accent: Color, word: String, dare: String,
		path: String) -> bool:
	_mode = mode
	_accent = accent
	_word = word
	_dare = dare

	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_painter = Node2D.new()
	_painter.draw.connect(_paint)
	_vp.add_child(_painter)
	add_child(_vp)

	_painter.queue_redraw()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw

	var img := _vp.get_texture().get_image()
	var ok := false
	if img != null and img.get_width() == SIZE.x:
		ok = img.save_png(path) == OK
	if not ok:
		push_warning("[OgCard] could not write %s" % path)

	_vp.queue_free()
	_vp = null
	_painter = null
	return ok


func _paint() -> void:
	_backdrop()
	_header()
	_tiles()
	_dare_line()


# ------------------------------------------------------------------ the layers


## Gradient, drifting blocks, and the mode's colour down the edges.
##
## Deliberately the same backdrop the story card wears. Somebody who sees the
## link preview and then gets sent the story card should recognise the second as
## the same game, and two different-looking cards from one share is how you get
## a game that reads as two games.
func _backdrop() -> void:
	var w := float(SIZE.x)
	var h := float(SIZE.y)

	for i in 48:
		var t := float(i) / 47.0
		_painter.draw_rect(Rect2(0.0, t * h, w, h / 48.0 + 1.0),
			ShareCard.BG_TOP.lerp(ShareCard.BG_BOTTOM, t), true)

	# Seeded with the same number the story card uses, so the two pictures drift
	# their blocks the same way rather than merely similarly.
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x57415253
	for i in 16:
		var cells := Vector2(float(rng.randi_range(1, 4)), float(rng.randi_range(1, 3)))
		var cell := rng.randf_range(44.0, 78.0)
		var at := Vector2(rng.randf_range(-60.0, w), rng.randf_range(-40.0, h))
		var col: Color = WWBoard.TIER_COLORS[rng.randi_range(
			0, WWBoard.TIER_COLORS.size() - 1)]
		_painter.draw_set_transform(at, rng.randf_range(-0.34, 0.34), Vector2.ONE)
		_round(Rect2(Vector2.ZERO, cells * cell), Color(col, 0.05),
			Color(col, 0.14), 10.0, 2.0)
		_painter.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Quietened top and bottom so the wordmark and the dare sit on something
	# even, whatever a block happened to drift into.
	for i in 22:
		var t := float(i) / 21.0
		var a := (1.0 - t) * 0.55
		_painter.draw_rect(Rect2(0.0, t * 210.0, w, 210.0 / 22.0 + 1.0),
			Color(ShareCard.BG_TOP, a), true)
		_painter.draw_rect(Rect2(0.0, h - t * 230.0 - 14.0, w, 230.0 / 22.0 + 1.0),
			Color(ShareCard.BG_TOP, a * 1.2), true)

	_painter.draw_rect(Rect2(0.0, 0.0, 12.0, h), Color(_accent, 0.9), true)
	_painter.draw_rect(Rect2(0.0, h - 12.0, w, 12.0), Color(_accent, 0.9), true)


## Wordmark and mode chip, side by side rather than stacked.
##
## Stacked is what the story card does and there is no room for it here — 630 of
## height has to hold a name, eight tiles and a line of 46pt type. The chip moves
## to the wordmark's right, baseline-aligned with it, which also puts the two
## things that identify the game in the top-left corner where a feed crops least.
func _header() -> void:
	var cx := float(SIZE.x) * 0.5

	# Shrunk to fit rather than tracked, for the same reason as the story card.
	var size := 82
	while size > 48 and _width(_font_title, "WORD WARS", size) > float(SIZE.x) - 420.0:
		size -= 2
	var mw := _width(_font_title, "WORD WARS", size)

	var label := _mode.to_upper()
	var tw := _tracked_width(_font_bold, label, 24, 9.0) if label != "" else 0.0
	var chip_w := tw + 56.0 if label != "" else 0.0
	var gap := 26.0 if label != "" else 0.0
	var total := mw + gap + chip_w
	var x := cx - total * 0.5

	_painter.draw_string(_font_title, Vector2(x, 96.0), "WORD WARS",
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, ShareCard.INK)
	_painter.draw_rect(Rect2(x, 116.0, mw, 4.0), Color(_accent, 0.55), true)

	if label == "":
		return
	var chip := Rect2(x + mw + gap, 46.0, chip_w, 52.0)
	_round(chip, Color(_accent, 0.16), Color(_accent, 0.75), 26.0, 2.0)
	_centred(_font_bold, Vector2(chip.get_center().x, 81.0), label, 24, _accent, 9.0)


## The word, drawn as the blocks it was played against.
##
## The one element that explains the game without a caption, and at feed size the
## only one that reads instantly. The letters spell something the mode is about —
## see `tools/ogcards.gd` — which is a small joke nobody has to get for the card
## to work.
func _tiles() -> void:
	var word := _word.to_upper()
	if word == "":
		return
	var n := word.length()
	var t := _tile_size(word)
	var gap := t * 0.11
	var total := t * float(n) + gap * float(n - 1)
	var x := float(SIZE.x) * 0.5 - total * 0.5
	var top := 208.0 + (116.0 - t) * 0.5

	for i in n:
		# The tier ladder, ramped left to right. A player who has seen a board
		# recognises blue-through-red as the thing that happens when a word gets
		# long, and running it across the letters makes the word read as
		# something that was built rather than something that was typed.
		var idx := 0 if n <= 1 else int(round(float(i) / float(n - 1)
			* float(WWBoard.TIER_COLORS.size() - 1)))
		var col: Color = WWBoard.TIER_COLORS[idx]
		var r := Rect2(x, top, t, t)
		_round(r, col, col.lightened(0.35), maxf(6.0, t * 0.18), 2.0)
		_centred(_font_bold, Vector2(r.get_center().x, r.get_center().y + t * 0.19),
			word[i], int(t * 0.5), Color("#0b1020"), 0.0)
		x += t + gap


## How big one letter can be. `ENDURANCE` is nine and the card is one width.
func _tile_size(word: String) -> float:
	var n := maxi(1, word.length())
	var avail := float(SIZE.x) - MARGIN * 2.0
	# Solving `n*t + (n-1)*0.11t = avail` for t, since the gap scales with the
	# tile and cannot be subtracted off first.
	return minf(116.0, avail / (float(n) + 0.11 * float(n - 1)))


## The line that asks for something, in a box so it survives a busy feed.
func _dare_line() -> void:
	var w := float(SIZE.x)
	var cx := w * 0.5
	if _dare != "":
		var box := Rect2(MARGIN + 40.0, 386.0, w - (MARGIN + 40.0) * 2.0, 106.0)
		_round(box, Color(_accent, 0.10), Color(_accent, 0.55), 24.0, 3.0)
		var line := _dare.to_upper()
		var size := 46
		while size > 26 and _width(_font_bold, line, size) > box.size.x - 72.0:
			size -= 2
		_centred(_font_bold, Vector2(cx, box.position.y + 68.0), line, size,
			_accent, 0.0)

	_centred(_font_bold, Vector2(cx, 556.0), "FREE ON THE APP STORE", 26,
		ShareCard.INK, 7.0)


# ----------------------------------------------------------------- the pencils
#
# The same four the story card uses, and deliberately not shared with it. They
# are twenty lines between them, and the alternative is either a base class whose
# only job is to hold them or making `share_card.gd` — which ships, and is
# correct — take a change it does not need.


func _round(r: Rect2, bg: Color, border: Color, radius: float,
		width: float) -> void:
	_sb.bg_color = bg
	_sb.set_corner_radius_all(int(radius))
	_sb.set_border_width_all(int(width))
	_sb.border_color = border
	_painter.draw_style_box(_sb, r)


func _width(font: Font, text: String, size: int) -> float:
	if font == null:
		return 0.0
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## What a tracked line measures, which is not what the font says it measures.
## Untracked it defers to the font, which knows about kerning that summing the
## glyphs one at a time does not.
func _tracked_width(font: Font, text: String, size: int, track: float) -> float:
	if font == null or text == "":
		return 0.0
	if track <= 0.0:
		return _width(font, text, size)
	var total := 0.0
	for ch in text:
		total += _width(font, ch, size) + track
	return maxf(0.0, total - track)


func _centred(font: Font, at: Vector2, text: String, size: int, col: Color,
		track: float) -> void:
	if font == null or text == "":
		return
	if track <= 0.0:
		_painter.draw_string(font, Vector2(at.x - _width(font, text, size) * 0.5, at.y),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		return
	var x := at.x - _tracked_width(font, text, size, track) * 0.5
	for ch in text:
		_painter.draw_string(font, Vector2(x, at.y), ch,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		x += _width(font, ch, size) + track
