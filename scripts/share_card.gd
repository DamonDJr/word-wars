extends Node
class_name ShareCard
## Draws the picture that gets shared, and writes it to `user://`.
##
## Not a screenshot. The scoreboard is laid out for the phone it is on — wide in
## landscape, and with an ad curtain that can be over it — and what wants sharing
## is a different shape entirely: 1080x1920, because every place this is going
## (a story, a TikTok, a reply) is a vertical frame, and anything else arrives
## letterboxed or cropped through the middle of the score.
##
## So the card is composed from the numbers rather than captured from the screen.
## That also means it can be drawn while the scoreboard is still up, off-screen,
## with no flicker and nothing for the player to see happening.
##
## ## What the card is for
##
## Nobody sends one of these to file a report. They send it because they are
## pleased with themselves and they want somebody to react. The first cut of this
## card treated the job as record-keeping — a wordmark, a number, a two-column
## table of labels and values, and a small line at the bottom naming the store —
## and it read exactly like a receipt. Handsome, legible, and completely inert.
##
## What it was missing is the half of a share that does the work:
##
##   * **a reason the number matters.** "14,320" is a number. "14,320 — NEW
##     PERSONAL BEST" is news. The card now carries a badge that says which of
##     those it is, worked out from the profile the player already has on disk.
##   * **something that says what the game is.** The card went to people who have
##     never seen this game, and nothing on it suggested a word game at all. The
##     best word of the match is now drawn as real blocks in the real tier
##     palette, which explains the whole premise in one glance.
##   * **a dare.** The last line used to name the App Store the way a footer names
##     a copyright holder. It now asks the person holding the phone a question
##     with a number in it, which is the only line on the card that can turn a
##     look into an install.
##
## ## Why the middle of the card flows
##
## The old layout pinned everything to fixed heights, which works only if every
## card carries the same amount. They do not: a survival run has three stats and a
## daily board had one. At fixed positions the daily card came out as a single row
## marooned in a third of a screen of empty gradient — which reads as a card that
## failed to finish drawing rather than one with less to say.
##
## So the middle section is a stack of blocks with measured heights, and whatever
## room is left over is divided into the gaps between them. A card with less on it
## breathes more instead of leaving a hole.
##
## ## Why a SubViewport rather than an Image
##
## The card is mostly text, and text is the one thing `Image` cannot draw. A
## viewport with a `Node2D` in it gets the real font stack and the same
## `draw_string` every other screen in this game uses.
##
## The trap is timing: a viewport does not render on the frame you add things to
## it. `render()` awaits `RenderingServer.frame_post_draw` after asking for one
## update, which is the only point at which `get_texture().get_image()` is
## anything but blank — the same lesson the offscreen screenshot tooling learnt.
##
## `tools/cardshots.gd` renders one of every card to PNG. This file is the only
## thing in the project that draws a picture nobody playing the game will ever
## see, so it is the one most easily shipped unlooked-at. Look at it.

## Story shape, and the size every one of those places wants.
const SIZE := Vector2i(1080, 1920)

const BG_TOP := Color("#01060a")
const BG_BOTTOM := Color("#0a1228")
const INK := Color("#e6ecff")
const DIM := Color("#8d99bd")
const FAINT := Color("#5d6a92")
const PANEL := Color("#111a33")
const HOT := Color("#ffd166")

## Side margin for everything that is not full-bleed.
const MARGIN := 84.0
## What the flowing middle section gets to work with. Below it sits the dare,
## which is pinned — it is the point of the card and does not move to make room.
const BAND_TOP := 366.0
const BAND_BOTTOM := 1496.0


## What to draw. Filled by `game.gd`, which is the only thing that knows what a
## match was.
class Card:
	var mode := ""             ## "SURVIVAL", "DAILY", "VERSUS", "SOLO"
	var accent := Color("#ffd166")
	var headline := ""         ## the number this card is about
	var headline_note := ""    ## what that number is
	var verdict := ""          ## "WON", "LOST", or ""
	## Why the headline is worth looking at: a personal best, a streak, a margin.
	## Empty is allowed and simply drops the badge.
	var badge := ""
	## Draws the badge in gold rather than the mode colour. For the handful of
	## things worth actually shouting about — a record, mostly.
	var badge_hot := false
	## The best word of the match, drawn as blocks. The one element on the card
	## that says "word game" without needing a caption.
	var word := ""
	var word_note := ""        ## what it was worth
	## Up to three [label, value] pairs, drawn as a row of cells.
	var stats: Array = []
	## The question the card asks whoever is looking at it. This is the line the
	## whole picture exists to deliver.
	var dare := ""
	var footer := ""           ## the quieter line under the dare


var _vp: SubViewport = null
var _painter: Node2D = null
var _card: Card = null
var _font: Font = null
var _font_bold: Font = null
var _font_title: Font = null
var _sb := StyleBoxFlat.new()


func _init(font: Font, font_bold: Font, font_title: Font = null) -> void:
	_font = font
	_font_bold = font_bold
	# The wordmark's own face, as the title screen wears it. Optional, because a
	# build that lost the asset should still send a card.
	_font_title = font_title if font_title != null else font_bold


## Draw `card` and write it to `path`. Returns false if anything went wrong, in
## which case nothing was written and the caller should fall back to text.
func render(card: Card, path: String) -> bool:
	_card = card

	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.transparent_bg = false
	# Once, on demand. The default would have it redrawing every frame for the
	# whole life of the node, which is a 1080x1920 target the game never looks at.
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_painter = Node2D.new()
	_painter.draw.connect(_paint)
	_vp.add_child(_painter)
	add_child(_vp)

	_painter.queue_redraw()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	# The frame the drawing actually lands on. Without this the image comes back
	# blank, which looks exactly like a card that failed to compose.
	await RenderingServer.frame_post_draw

	var img := _vp.get_texture().get_image()
	var ok := false
	if img != null and img.get_width() == SIZE.x:
		ok = img.save_png(path) == OK
	if not ok:
		push_warning("[ShareCard] could not write %s" % path)

	_vp.queue_free()
	_vp = null
	_painter = null
	return ok


func _paint() -> void:
	var c := _card
	if c == null:
		return

	_backdrop(c)
	_header(c)
	_middle(c)
	_dare(c)


# ------------------------------------------------------------------ the layers


## Gradient, drifting blocks, and the frame that says which mode this was.
func _backdrop(c: Card) -> void:
	var w := float(SIZE.x)
	var h := float(SIZE.y)

	# A flat fill reads as a screenshot of nothing; the gradient is what makes it
	# look composed rather than captured.
	for i in 64:
		var t := float(i) / 63.0
		_painter.draw_rect(Rect2(0.0, t * h, w, h / 64.0 + 1.0),
			BG_TOP.lerp(BG_BOTTOM, t), true)

	# The game's own backdrop, at the volume a backdrop should be played at.
	# Every menu in this game drifts tilted blocks behind it, and a share card
	# with a plain gradient behind it belonged to a different, tidier game than
	# the one it is advertising. Seeded rather than random so two renders of the
	# same result are the same picture.
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x57415253
	for i in 22:
		var cells := Vector2(float(rng.randi_range(1, 4)), float(rng.randi_range(1, 3)))
		var cell := rng.randf_range(46.0, 82.0)
		var at := Vector2(rng.randf_range(-60.0, w), rng.randf_range(-40.0, h))
		var col: Color = WWBoard.TIER_COLORS[rng.randi_range(0, WWBoard.TIER_COLORS.size() - 1)]
		_painter.draw_set_transform(at, rng.randf_range(-0.34, 0.34), Vector2.ONE)
		var r := Rect2(Vector2.ZERO, cells * cell)
		_round(r, Color(col, 0.045), Color(col, 0.13), 10.0, 2.0)
		_painter.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Darkened at top and bottom so the wordmark and the dare sit on something
	# quiet, whatever a block happened to drift into.
	for i in 26:
		var t := float(i) / 25.0
		var a := (1.0 - t) * 0.5
		_painter.draw_rect(Rect2(0.0, t * 300.0, w, 300.0 / 26.0 + 1.0),
			Color(BG_TOP, a), true)
		_painter.draw_rect(Rect2(0.0, h - t * 460.0 - 20.0, w, 460.0 / 26.0 + 1.0),
			Color(BG_TOP, a * 1.3), true)

	# A band of the mode's own colour down the left and along the bottom, so the
	# four modes tell apart at thumbnail size — which is the size most of these
	# are ever seen at.
	_painter.draw_rect(Rect2(0.0, 0.0, 14.0, h), Color(c.accent, 0.9), true)
	_painter.draw_rect(Rect2(0.0, h - 14.0, w, 14.0), Color(c.accent, 0.9), true)


## Wordmark and mode. Fixed at the top, because a masthead that moves is not a
## masthead.
##
## The wordmark is set large and untracked, in the same compressed face as the
## title screen, and half again as big as the 720-unit phone sets it.
func _header(c: Card) -> void:
	var w := float(SIZE.x)
	var cx := w * 0.5
	var size := 112
	while size > 60 and _width(_font_title, "WORD WARS", size) > w - 190.0:
		size -= 2
	_centred(_font_title, Vector2(cx, 190.0), "WORD WARS", size, INK, 0.0)
	# The rule under the name, as the title screen wears it.
	var mw := _width(_font_title, "WORD WARS", size)
	_painter.draw_rect(Rect2(cx - mw * 0.5, 214.0, mw, 4.0),
		Color(c.accent, 0.55), true)

	var label := c.mode.to_upper()
	if label == "":
		return
	var tw := _tracked_width(_font_bold, label, 28, 10.0)
	var chip := Rect2(cx - tw * 0.5 - 34.0, 252.0, tw + 68.0, 60.0)
	_round(chip, Color(c.accent, 0.16), Color(c.accent, 0.75), 30.0, 2.0)
	_centred(_font_bold, Vector2(cx, 293.0), label, 28, c.accent, 10.0)


## The stack between the masthead and the dare, spaced to fill whatever room it
## has. See the note at the top of the file for why this is not a fixed layout.
func _middle(c: Card) -> void:
	var blocks: Array = []
	if c.verdict != "":
		blocks.append({"h": 108.0, "draw": _draw_verdict})
	blocks.append({"h": _headline_height(c), "draw": _draw_headline})
	if c.word != "":
		blocks.append({"h": _word_height(c), "draw": _draw_word})
	if not c.stats.is_empty():
		blocks.append({"h": 182.0, "draw": _draw_stats})

	var used := 0.0
	for b: Dictionary in blocks:
		used += float(b["h"])

	# Leftover room becomes the gaps. Clamped at the top so a sparse card — the
	# daily board with nothing but a score — spreads out instead of drifting into
	# three unrelated islands, and at the bottom so a full one still has air.
	var band := BAND_BOTTOM - BAND_TOP
	var gaps := maxi(1, blocks.size() - 1)
	var gap := clampf((band - used) / float(gaps), 30.0, 172.0)
	var total := used + gap * float(gaps)
	var y := BAND_TOP + maxf(0.0, (band - total) * 0.5)

	for b: Dictionary in blocks:
		var fn: Callable = b["draw"]
		fn.call(c, y, float(b["h"]))
		y += float(b["h"]) + gap


## The dare, and the only line on the card with an instruction in it.
##
## Pinned to the bottom rather than flowed, because this is the half of the share
## that does any work and it may not be pushed around by how many stats a mode
## happens to have.
func _dare(c: Card) -> void:
	var w := float(SIZE.x)
	var cx := w * 0.5
	if c.dare != "":
		var box := Rect2(MARGIN - 20.0, 1524.0, w - (MARGIN - 20.0) * 2.0, 216.0)
		_round(box, Color(c.accent, 0.10), Color(c.accent, 0.55), 26.0, 3.0)
		var line := c.dare.to_upper()
		# Shrunk to fit rather than allowed to run out of the box. "CAN YOU BEAT
		# 131,017?" is a wider line than "CAN YOU BEAT 8,150?" and the box is the
		# same box.
		var size := 52
		while size > 32 and _width(_font_bold, line, size) > box.size.x - 104.0:
			size -= 2
		line = _elide(_font_bold, line, size, box.size.x - 104.0)
		var mid := box.position.y + (100.0 if c.footer != "" else 128.0)
		_centred(_font_bold, Vector2(cx, mid), line, size, c.accent, 0.0)
		if c.footer != "":
			_centred(_font, Vector2(cx, box.position.y + 158.0), c.footer, 27, DIM, 0.0)
	elif c.footer != "":
		_centred(_font, Vector2(cx, 1640.0), c.footer, 27, DIM, 0.0)

	_centred(_font_bold, Vector2(cx, 1832.0), "FREE ON THE APP STORE", 30, INK, 7.0)


# ------------------------------------------------------------------ the blocks
#
# Each of these is handed the top of the space it was measured for. They come in
# pairs — a `_*_height` that measures and a `_draw_*` that fills — and the two
# have to agree or the flow above goes crooked.


func _draw_verdict(c: Card, y: float, h: float) -> void:
	var cx := float(SIZE.x) * 0.5
	var won := c.verdict == "WON"
	var col := Color("#90be6d") if won else Color("#ff6b6b")
	var text := c.verdict.to_upper()
	var tw := _tracked_width(_font_bold, text, 66, 8.0)
	var box := Rect2(cx - tw * 0.5 - 52.0, y, tw + 104.0, h)
	# Filled rather than outlined. A win is the loudest thing that ever happens
	# on this card and an outline is not a shout.
	_round(box, Color(col, 0.92), Color(col.lightened(0.3), 1.0), 20.0, 3.0)
	_centred(_font_bold, Vector2(cx, y + h * 0.5 + 23.0), text, 66,
		Color("#0b1020"), 8.0)


func _headline_height(c: Card) -> float:
	var h := 168.0
	if c.headline_note != "":
		h += 52.0
	if c.badge != "":
		h += 86.0
	return h


func _draw_headline(c: Card, y: float, _h: float) -> void:
	var cx := float(SIZE.x) * 0.5
	var mid := y + 84.0

	# A soft bloom behind the number, built out of circles because there is no
	# gradient brush on a canvas item. Drawn largest first so the alpha piles up
	# towards the middle, which is what a glow is.
	var glow: Color = HOT if c.badge_hot else c.accent
	for i in 26:
		var t := float(i) / 25.0
		_painter.draw_circle(Vector2(cx, mid),
			lerpf(430.0, 40.0, t), Color(glow, 0.016))

	# The number is the whole point of the card and gets the room to prove it.
	var size := 150
	while size > 90 and _width(_font_bold, c.headline, size) > float(SIZE.x) - 150.0:
		size -= 4
	_centred(_font_bold, Vector2(cx, mid + size * 0.36), c.headline, size, INK, 0.0)

	var below := y + 168.0
	if c.headline_note != "":
		_centred(_font, Vector2(cx, below + 30.0), c.headline_note.to_upper(),
			28, DIM, 8.0)
		below += 52.0

	if c.badge == "":
		return
	# The line that turns a number into news. Gold when it is a record, the
	# mode's colour when it is context.
	var col: Color = HOT if c.badge_hot else c.accent
	var text := c.badge.to_upper()
	var bs := 30
	while bs > 20 and _tracked_width(_font_bold, text, bs, 6.0) > float(SIZE.x) - 260.0:
		bs -= 2
	var tw := _tracked_width(_font_bold, text, bs, 6.0)
	var chip := Rect2(cx - tw * 0.5 - 38.0, below + 14.0, tw + 76.0, 62.0)
	_round(chip, Color(col, 0.18), Color(col, 0.8), 14.0, 2.0)
	_centred(_font_bold, Vector2(cx, below + 56.0), text, bs, col, 6.0)


func _word_height(c: Card) -> float:
	return 58.0 + _tile_size(c.word) + (52.0 if c.word_note != "" else 0.0)


## The best word of the match, drawn as the blocks it was played against.
##
## This is the only thing on the card that explains what the game is. A stranger
## looking at a wordmark over a number learns nothing; a stranger looking at
## eight lettered tiles in the game's own tier colours knows it is a word game
## before reading a single line of it.
func _draw_word(c: Card, y: float, _h: float) -> void:
	var w := float(SIZE.x)
	var cx := w * 0.5
	_centred(_font, Vector2(cx, y + 24.0), "BEST WORD", 24, FAINT, 8.0)

	var word := c.word.to_upper()
	var n := word.length()
	var t := _tile_size(word)
	var gap := t * 0.11
	var total := t * float(n) + gap * float(n - 1)
	var x := cx - total * 0.5
	var top := y + 58.0

	for i in n:
		# The tier palette, ramped left to right. The colours are the game's own
		# — a player who has seen a board recognises the ladder from blue to red —
		# and running them across the word makes it read as something that built
		# rather than something that was listed.
		var idx := 0 if n <= 1 else int(round(float(i) / float(n - 1)
			* float(WWBoard.TIER_COLORS.size() - 1)))
		var col: Color = WWBoard.TIER_COLORS[idx]
		var r := Rect2(x, top, t, t)
		_round(r, col, col.lightened(0.35), maxf(6.0, t * 0.18), 2.0)
		_centred(_font_bold, Vector2(r.get_center().x, r.get_center().y + t * 0.19),
			word[i], int(t * 0.5), Color("#0b1020"), 0.0)
		x += t + gap

	if c.word_note != "":
		_centred(_font, Vector2(cx, top + t + 42.0), c.word_note.to_upper(),
			25, DIM, 5.0)


## How big one letter can be. Long words shrink to fit rather than running off
## the card — `ENTERTAINMENT` is thirteen letters and the card is one width.
func _tile_size(word: String) -> float:
	var n := maxi(1, word.length())
	var avail := float(SIZE.x) - MARGIN * 2.0
	# Solving `n*t + (n-1)*0.11t = avail` for t, since the gap scales with the
	# tile and cannot be subtracted off first.
	return minf(112.0, avail / (float(n) + 0.11 * float(n - 1)))


## The supporting numbers, as a row of cells rather than a column of rows.
##
## The old table put a faint label on the left and a value on the right with a
## rule between them, which is how a bank prints a statement. Three cells side by
## side occupy the width instead of stretching down the card, and stack the value
## over its label so the number is what the eye lands on.
func _draw_stats(c: Card, y: float, h: float) -> void:
	var w := float(SIZE.x)
	var n: int = mini(3, c.stats.size())
	if n <= 0:
		return
	var gap := 22.0
	var avail := w - MARGIN * 2.0
	var cw := minf(304.0, (avail - gap * float(n - 1)) / float(n))
	var total := cw * float(n) + gap * float(n - 1)
	var x := (w - total) * 0.5

	for i in n:
		var row: Array = c.stats[i]
		var r := Rect2(x, y, cw, h)
		_round(r, Color(PANEL, 0.85), Color(c.accent, 0.28), 18.0, 2.0)
		# A stripe of the mode colour along the top edge, which is what keeps a
		# row of dark plates from reading as three empty boxes.
		_painter.draw_rect(Rect2(x + 18.0, y + 2.0, cw - 36.0, 3.0),
			Color(c.accent, 0.55), true)

		var value := String(row[1])
		var vs := 48
		while vs > 26 and _width(_font_bold, value, vs) > cw - 28.0:
			vs -= 2
		_centred(_font_bold, Vector2(r.get_center().x, y + 88.0), value, vs, INK, 0.0)

		# A stat label is usually a word we wrote, and occasionally a rival's
		# display name. Shrink two steps for the long ones, then cut — below 18
		# the label stops being readable and a shorter line is worth more than a
		# complete one nobody can make out.
		var label := String(row[0]).to_upper()
		var ls := 22
		while ls > 18 and _tracked_width(_font, label, ls, 4.0) > cw - 24.0:
			ls -= 1
		label = _elide(_font, label, ls, cw - 24.0, 4.0)
		_centred(_font, Vector2(r.get_center().x, y + 130.0), label, ls, FAINT, 4.0)
		x += cw + gap


# ----------------------------------------------------------------- the pencils


## A rounded plate. The same shape the menus use, drawn on the card's own canvas.
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


## Cut a line down to something that fits, once shrinking the type has stopped
## being an answer.
##
## Everywhere this is used, the shrink loop runs first and this only bites at the
## floor. That order matters: shrinking is invisible and eliding is not, so type
## size is spent before any of the text is. What forces the issue is that two
## lines on this card are built from a name somebody else typed — a versus rival
## is whatever their Game Center profile says — and there is no length a player
## cannot exceed. Left alone, "xX_stampcollector_Xx" either ran out of its cell
## or shrank to a grey smear too small to read, and both look like a broken card
## rather than a long name.
func _elide(font: Font, text: String, size: int, max_w: float,
		track: float = 0.0) -> String:
	if font == null or text == "" or _tracked_width(font, text, size, track) <= max_w:
		return text
	var cut := text
	while cut.length() > 1 \
			and _tracked_width(font, cut + "…", size, track) > max_w:
		cut = cut.substr(0, cut.length() - 1)
	return cut + "…"


## What a tracked line measures, which is not what the font says it measures.
##
## Untracked it defers to the font, which knows about kerning that summing the
## glyphs one at a time does not — and which is what `_centred` uses to place the
## same line. The two must agree or a measured box lands off its own text.
func _tracked_width(font: Font, text: String, size: int, track: float) -> float:
	if font == null or text == "":
		return 0.0
	if track <= 0.0:
		return _width(font, text, size)
	var total := 0.0
	for ch in text:
		total += _width(font, ch, size) + track
	return maxf(0.0, total - track)


## Centred, optionally letter-spaced. Tracking is what stops a short all-caps
## line reading as a cramped label rather than as a heading.
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
