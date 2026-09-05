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

## Story shape, and the size every one of those places wants.
const SIZE := Vector2i(1080, 1920)

const BG_TOP := Color("#01060a")
const BG_BOTTOM := Color("#0a1228")
const INK := Color("#e6ecff")
const DIM := Color("#8d99bd")
const FAINT := Color("#5d6a92")


## What to draw. Filled by `game.gd`, which is the only thing that knows what a
## match was.
class Card:
	var mode := ""             ## "SURVIVAL", "DAILY", "VERSUS", "SOLO"
	var accent := Color("#ffd166")
	var headline := ""         ## the number this card is about
	var headline_note := ""    ## what that number is
	var verdict := ""          ## "WON", "LOST", or ""
	var rows: Array = []       ## [[label, value], ...] up to four
	var footer := ""           ## the line that tells somebody where to get it


var _vp: SubViewport = null
var _painter: Node2D = null
var _card: Card = null
var _font: Font = null
var _font_bold: Font = null


func _init(font: Font, font_bold: Font) -> void:
	_font = font
	_font_bold = font_bold


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
	var w := float(SIZE.x)
	var h := float(SIZE.y)

	# A flat fill reads as a screenshot of nothing; the gradient is what makes it
	# look composed rather than captured.
	for i in 64:
		var t := float(i) / 63.0
		_painter.draw_rect(Rect2(0.0, t * h, w, h / 64.0 + 1.0),
			BG_TOP.lerp(BG_BOTTOM, t), true)

	# A band of the mode's own colour down the left, so the four modes are
	# telling apart at thumbnail size, which is the size most of these are seen at.
	_painter.draw_rect(Rect2(0.0, 0.0, 16.0, h), Color(c.accent, 0.9), true)

	var cx := w * 0.5
	_centred(_font_bold, Vector2(cx, 250.0), "WORD WARS", 58, INK, 6.0)
	_centred(_font, Vector2(cx, 320.0), c.mode.to_upper(), 30, c.accent, 10.0)

	if c.verdict != "":
		_centred(_font_bold, Vector2(cx, 470.0), c.verdict, 96,
			Color("#90be6d") if c.verdict == "WON" else Color("#ff6b6b"), 4.0)

	# The number is the whole point of the card and gets the room to prove it.
	#
	# It sits where the verdict is not: survival and the daily have nothing to
	# win, so their cards have no WON/LOST line, and leaving the headline at the
	# height that clears one put a hand's width of nothing above the only thing
	# on the card worth reading.
	var head_y := 700.0 if c.verdict != "" else 600.0
	_centred(_font_bold, Vector2(cx, head_y), c.headline, 150, INK, 0.0)
	if c.headline_note != "":
		_centred(_font, Vector2(cx, head_y + 100.0), c.headline_note.to_upper(),
			28, DIM, 8.0)

	# Centred in the space between the headline and the footer rather than pinned
	# under it. The card carries one row on a daily and three on a survival run,
	# and a fixed start left the two-row version with a third of the picture
	# empty below it — which reads as a card that failed to finish drawing.
	var block := float(c.rows.size()) * 110.0
	var y := 940.0 + maxf(0.0, (700.0 - block) * 0.5)
	for row: Array in c.rows:
		var label := String(row[0]).to_upper()
		var value := String(row[1])
		_painter.draw_rect(Rect2(140.0, y - 42.0, w - 280.0, 1.0),
			Color("#232c4d"), true)
		_left(_font, Vector2(150.0, y), label, 30, FAINT)
		_right(_font_bold, Vector2(w - 150.0, y), value, 38, INK)
		y += 110.0

	if c.footer != "":
		_centred(_font, Vector2(cx, h - 190.0), c.footer, 30, DIM, 0.0)
	_centred(_font_bold, Vector2(cx, h - 130.0), "WORD WARS ON THE APP STORE", 24,
		Color(c.accent, 0.85), 5.0)


## Centred, optionally letter-spaced. Tracking is what stops a short all-caps
## line reading as a cramped label rather than as a heading.
func _centred(font: Font, at: Vector2, text: String, size: int, col: Color,
		track: float) -> void:
	if font == null or text == "":
		return
	if track <= 0.0:
		var m := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		_painter.draw_string(font, Vector2(at.x - m.x * 0.5, at.y),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		return
	var total := 0.0
	for ch in text:
		total += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + track
	total -= track
	var x := at.x - total * 0.5
	for ch in text:
		_painter.draw_string(font, Vector2(x, at.y), ch,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + track


func _left(font: Font, at: Vector2, text: String, size: int, col: Color) -> void:
	if font == null or text == "":
		return
	_painter.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _right(font: Font, at: Vector2, text: String, size: int, col: Color) -> void:
	if font == null or text == "":
		return
	var m := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	_painter.draw_string(font, Vector2(at.x - m.x, at.y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
