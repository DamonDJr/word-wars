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
## ## The colour checks are the load-bearing ones
##
## These are drawn with `draw_texture_rect`'s modulate, which multiplies, so both
## ends of the source art matter and neither is visible in a diff.
##
## The white end is what takes the tint. The art arrived at #B2B2B2 and was
## levelled to white on the way in; at 70% grey it would come back at 70% of
## whatever colour was asked for, which reads as muddy rather than as wrong, and
## muddy survives review.
##
## The dark end is what multiply cannot lift, so it is the same on every style —
## which made it the one part of an emote that had to already belong. It arrived
## at #000000, a colour the rest of this game uses precisely nowhere, and against
## a UI that bottoms out at #0b1020 it read as a hole punched through the panel.
## Raised to #2a3355, which the menus already use.
##
## Both were done to the files rather than in a shader. This project has no
## shaders, and neither of these is a per-frame problem.

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

	print("--- white bodies, dark ink, no pure black ---")
	for name: String in loaded:
		var img: Image = (loaded[name] as Texture2D).get_image()
		_expect("%-6s is white, inked, and free of pure black" % name, _tintable(img))

	print("--- and there is something to see ---")
	for name: String in loaded:
		var img: Image = (loaded[name] as Texture2D).get_image()
		_expect("%-6s has transparent margins and an opaque middle" % name,
			_has_alpha_range(img))

	_styles()
	# Awaited, or it returns at its first `await` having asserted nothing — and
	# a section that prints its heading and no results looks like a section that
	# passed.
	await _gesture()

	print("--- %s ---" % ("the emotes are ready" if fails == 0
		else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)


## Every style has to produce a colour, and the default has to be reachable
## without owning anything — a cosmetic slot whose first entry is locked leaves
## `worn` returning something the player cannot see.
func _styles() -> void:
	print("--- the styles paint ---")
	var p = Engine.get_main_loop().root.get_node("Profile")
	_expect("emote is a cosmetic slot", p.SLOTS.has("emote"))
	_expect("and it has a name", String(p.SLOT_NAMES.get("emote", "")) != "")

	var entries: Array = p.entries("emote")
	_expect("there are styles to choose from", entries.size() >= 4)
	_expect("the first is free", (entries[0] as Dictionary)["need"].is_empty())

	for e: Dictionary in entries:
		var id := String(e["id"])
		_expect("%-7s is painted" % id, Cosmetics.EMOTE_STYLES.has(id))
		# Multiply cannot lift a channel, so a style darker than the art is a
		# style that can only ever make the character muddier.
		var c: Color = Cosmetics.emote_tint(id, 0.0)
		_expect("%-7s is bright enough to tint with (v=%.2f)" % [id, c.v],
			c.v > 0.55)

	# The cycling one has to actually cycle, or it is an expensive white.
	var a: Color = Cosmetics.emote_tint("holo", 0.0)
	var b: Color = Cosmetics.emote_tint("holo", 2.0)
	_expect("holo moves over time", not a.is_equal_approx(b))
	_expect("an unknown style falls back rather than crashing",
		Cosmetics.emote_tint("nonsense", 0.0).v > 0.0)


## The gesture, driven the way a thumb drives it. None of this needs a match —
## the point is that the state machine cannot be left half-open.
func _gesture() -> void:
	print("--- the gesture opens, picks and closes ---")
	var game = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(game)
	await process_frame

	_expect("nothing is held to begin with", game._emote_touch == -2)
	_expect("and the menu is shut", not game._emote_open)

	game._emote_begin(0)
	_expect("a press takes the touch", game._emote_touch == 0)
	_expect("but does not open it yet", not game._emote_open)

	# Held, but not in a match — the menu must not open over a solo board.
	game._tick_emotes(game.EMOTE_HOLD + 0.05)
	_expect("a hold outside a match opens nothing", not game._emote_open)
	_expect("and the gesture is dropped", game._emote_touch == -2)

	# The wire index is clamped, because it arrives from another device.
	game._on_net_emote(999)
	_expect("an out-of-range emote is ignored", game._emote_in.is_empty())
	game._on_net_emote(-1)
	_expect("and so is a negative one", game._emote_in.is_empty())
	game._on_net_emote(2)
	_expect("a real one is shown", int(game._emote_in.get("i", -1)) == 2)

	# And it leaves on its own, or it would sit over the card forever.
	game._tick_emotes(game.EMOTE_SHOW + 0.1)
	_expect("and it expires by itself", game._emote_in.is_empty())

	# The cooldown is what stops a held finger flooding the other screen.
	game._emote_cool = game.EMOTE_COOLDOWN
	game._send_emote(0)
	_expect("a second emote inside the cooldown is refused",
		is_equal_approx(game._emote_cool, game.EMOTE_COOLDOWN))
	game._tick_emotes(game.EMOTE_COOLDOWN + 0.1)
	_expect("and the cooldown runs out", is_zero_approx(game._emote_cool))

	_expect("the wire list matches the files", game.EMOTES == EMOTES)
	game.queue_free()


## White somewhere and dark ink somewhere, among the pixels actually drawn, and
## nothing at pure black at all.
##
## The first two are what makes a tint work: white takes the colour, and the ink
## stays dark because multiply cannot lift it, which is what stops a tinted emote
## collapsing into a flat silhouette.
##
## The third is a palette rule, and it is the reason the art was re-levelled.
## `game.gd` uses `#000000` exactly nowhere — the whole UI bottoms out at
## `#0b1020` — so pure black anywhere on screen is only ever these files, and it
## read as a hole punched through the panel. The ink now sits at `#2a3355`, which
## is a colour the menus already use. Asserted rather than trusted because it is
## invisible in a diff and a re-export from the drawing tool would undo it.
func _tintable(img: Image) -> bool:
	var white := 0
	var ink := 0
	var pure_black := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			if c.r > 0.97 and c.g > 0.97 and c.b > 0.97:
				white += 1
			elif c.v < 0.45:
				ink += 1
			if c.r < 0.02 and c.g < 0.02 and c.b < 0.02:
				pure_black += 1
	return white > 200 and ink > 20 and pure_black == 0


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
