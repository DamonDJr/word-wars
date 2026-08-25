extends SceneTree
## The emote art, pinned: seven names, seven textures, and the one property the
## tinting depends on.
##
##   godot --headless --script tools/emotetest.gd
##
## ## Why an asset test at all
##
## Emotes are referenced by name over the wire — a match sends `EMOTES[i]`, not a
## picture — so a renamed or missing file is not a missing picture, it is an
## index that resolves to nothing on one player's phone and to the wrong feeling
## on the other's. Nothing about that fails loudly at build time, and it cannot
## be seen at all without two devices and a live match.
##
## ## The white-body check is the load-bearing one
##
## These are drawn with `draw_texture_rect`'s modulate, which multiplies. That
## only produces the tint colour where the source is white: a body at 70% grey
## comes back at 70% of whatever colour was asked for, which reads as muddy
## rather than as wrong, and muddy survives review.
##
## The source art arrived at #B2B2B2 and was levelled to white on the way in, so
## this asserts the levelling happened — a re-export from the drawing tool that
## skips it would otherwise land silently.

var fails := 0

## Every emote, in wire order. The index is what crosses the network, so this
## array is an on-disk format: append only, and never reorder.
const EMOTES := ["cheer", "cry", "shock", "angry", "nice", "huh", "think"]


func _init() -> void:
	await process_frame

	print("--- the set is complete ---")
	_expect("seven emotes are named", EMOTES.size() == 7)

	var loaded := {}
	for name: String in EMOTES:
		var path := "res://emotes/%s.png" % name
		var tex := load(path) as Texture2D
		_expect("%-6s loads" % name, tex != null)
		if tex != null:
			loaded[name] = tex

	print("--- every one is the size it should be ---")
	for name: String in loaded:
		var tex: Texture2D = loaded[name]
		_expect("%-6s is 512x512 (got %dx%d)" % [name, tex.get_width(), tex.get_height()],
			tex.get_width() == 512 and tex.get_height() == 512)

	print("--- the bodies are white, or the tint will be muddy ---")
	for name: String in loaded:
		var img: Image = (loaded[name] as Texture2D).get_image()
		_expect("%-6s has a white body and keeps its ink" % name, _tintable(img))

	print("--- and there is something to see ---")
	for name: String in loaded:
		var img: Image = (loaded[name] as Texture2D).get_image()
		_expect("%-6s has transparent margins and an opaque middle" % name,
			_has_alpha_range(img))

	print("--- %s ---" % ("the emotes are ready" if fails == 0
		else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)


## White somewhere and near-black somewhere, among the pixels that are actually
## drawn. Both halves matter: white is what takes the tint, and the black is the
## eyes and the linework, which must *not* take it — multiply leaves black alone,
## so ink surviving is what stops a tinted emote becoming a flat silhouette.
func _tintable(img: Image) -> bool:
	var white := 0
	var ink := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			if c.r > 0.97 and c.g > 0.97 and c.b > 0.97:
				white += 1
			elif c.r < 0.15 and c.g < 0.15 and c.b < 0.15:
				ink += 1
	return white > 200 and ink > 20


## A sticker, not a full-bleed image: the corners have to be empty or it will
## sit in a rectangle of its own background when it pops up over the board.
func _has_alpha_range(img: Image) -> bool:
	var corner_clear := img.get_pixel(2, 2).a < 0.1 \
		and img.get_pixel(img.get_width() - 3, 2).a < 0.1
	var solid := 0
	for y in range(0, img.get_height(), 8):
		for x in range(0, img.get_width(), 8):
			if img.get_pixel(x, y).a > 0.9:
				solid += 1
	return corner_clear and solid > 100


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-52s %s" % [what, "ok" if ok else "FAILED"])
