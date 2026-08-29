extends SceneTree
## The emote art, pinned: three sheets, the grid they are packed on, and the
## wire indices they hang off.
##
##   godot --headless --script tools/emotetest.gd
##
## ## Why an asset test at all
##
## Emotes are referenced by index over the wire — a match sends a number, not a
## picture — so a renamed file or a miscounted grid is not a missing picture, it
## is an index that resolves to nothing on one player's phone and to the wrong
## feeling on the other's. Nothing about that fails loudly at build time, and it
## cannot be seen at all without two devices and a live match.
##
## ## The grid checks are the load-bearing ones
##
## The character is drawn from a sprite sheet with `draw_texture_rect_region`,
## and every number describing that sheet lives in two places: in
## `tools/build_emotes.py`, which packs it, and in `game.gd`, which reads it.
## A cell size or frame count that drifts between the two does not crash — it
## draws a sliver of the wrong frame, or half of two, which is the kind of thing
## that survives review because it only shows up in motion.
##
## The two-pixel gutter is checked for the same reason. Bilinear filtering
## reaches a texel past the region it is handed, so a frame packed hard against
## its neighbour smears that neighbour's shoulder down its own edge. The margin
## is what stops it, it is invisible in the file, and a re-pack at a different
## cell size would quietly eat it.
##
## ## And the four that are gone
##
## The fan offers three of the seven. The other four are still named in `EMOTES`
## and still on disk, because a phone on the older build can send one, and this
## asserts the fallback has something to land on.

var fails := 0

## Every emote, in wire order. The index is what crosses the network, so this
## array is an on-disk format: append only, and never reorder.
const EMOTES := ["cheer", "cry", "shock", "angry", "nice", "huh", "think"]

## What the fan offers, and what it no longer does.
const MENU := [0, 2, 4]
const RETIRED := ["cry", "angry", "huh", "think"]


func _init() -> void:
	await process_frame

	print("--- the set is complete ---")
	_expect("seven emotes are named", EMOTES.size() == 7)

	var game = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(game)
	await process_frame

	_sheets(game)
	_wiring(game)
	_retired()
	_slot_is_gone()
	# Awaited, or it returns at its first `await` having asserted nothing — and
	# a section that prints its heading and no results looks like a section that
	# passed.
	await _gesture(game)

	print("--- %s ---" % ("the emotes are ready" if fails == 0
		else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)


## Every sheet loads, is exactly the size its grid says, has something in every
## cell, and keeps its margins clear.
func _sheets(game) -> void:
	print("--- the sheets are packed the way the game reads them ---")
	var cell: float = game.EMOTE_CELL
	var gutter: float = game.EMOTE_GUTTER
	_expect("the cell is bigger than its margins", cell > gutter * 2.0 + 8.0)

	for idx: int in game.EMOTE_ANIM:
		var anim: Dictionary = game.EMOTE_ANIM[idx]
		var name := String(anim["sheet"])
		var count := int(anim["frames"])
		var cols := int(anim["cols"])
		var rows: int = int(ceil(float(count) / float(cols)))

		var tex := load("res://emotes/%s.png" % name) as Texture2D
		_expect("%-12s loads" % name, tex != null)
		if tex == null:
			continue
		_expect("%-12s is %dx%d as its grid says (got %dx%d)"
			% [name, cols * int(cell), rows * int(cell),
				tex.get_width(), tex.get_height()],
			tex.get_width() == cols * int(cell)
			and tex.get_height() == rows * int(cell))

		var img: Image = tex.get_image()
		var blank := 0
		var leaky := 0
		for i in count:
			var r: Rect2 = game._emote_frame(anim, float(i) / game.EMOTE_FPS)
			if not _has_content(img, r):
				blank += 1
			if not _margin_clear(img, i, cols, cell, gutter):
				leaky += 1
		_expect("%-12s has all %d frames drawn" % [name, count], blank == 0)
		_expect("%-12s keeps a clear margin round every cell" % name, leaky == 0)
		# The palette rule the old art was re-levelled for, and the reason it is
		# still worth asserting: `game.gd` uses `#000000` precisely nowhere, the
		# whole UI bottoms out at `#0b1020`, and pure black on screen reads as a
		# hole punched through the panel rather than as ink.
		_expect("%-12s is free of pure black" % name, not _has_pure_black(img))

	# The frame walks the grid and comes back round. A cycle that ran off the
	# end would sample empty sheet, which is an emote that vanishes mid-play.
	var first: Dictionary = game.EMOTE_ANIM[MENU[0]]
	var n := int(first["frames"])
	var a: Rect2 = game._emote_frame(first, 0.0)
	var b: Rect2 = game._emote_frame(first, float(n) / game.EMOTE_FPS)
	_expect("the cycle loops back to its first frame", a.is_equal_approx(b))
	var mid: Rect2 = game._emote_frame(first, float(n / 2) / game.EMOTE_FPS)
	_expect("and moves in between", not a.is_equal_approx(mid))
	_expect("a negative age does not walk off the sheet",
		game._emote_frame(first, -1.0).position.x >= 0.0)


## The three the fan offers, and the promise that goes with the numbers.
func _wiring(game) -> void:
	print("--- the fan and the wire agree ---")
	_expect("the menu is the three that were animated", game.EMOTE_MENU == MENU)
	for i in game.EMOTE_MENU.size():
		var idx := int(game.EMOTE_MENU[i])
		_expect("slot %d is a real wire index" % i,
			idx >= 0 and idx < EMOTES.size())
		_expect("and %-5s has a sheet" % EMOTES[idx], game.EMOTE_ANIM.has(idx))
	# The whole reason these three indices and not 0, 1, 2. Every index this
	# build can send is one the seven-emote build already understood, so a match
	# across versions reads correctly in both directions.
	_expect("nothing sent here is new to an older build",
		MENU.max() < EMOTES.size())
	_expect("the column is as tall as the menu",
		(game._emote_rects() as Array).size() == game.EMOTE_MENU.size())
	_expect("the wire list matches the files", game.EMOTES == EMOTES)


## The four the fan dropped are still drawable, because somebody else's phone
## can still send one.
func _retired() -> void:
	print("--- the retired four still have something to land on ---")
	for name: String in RETIRED:
		var tex := load("res://emotes/%s.png" % name) as Texture2D
		_expect("%-6s still loads" % name, tex != null)


## The cosmetic slot that existed to tint white art, and does not any more.
func _slot_is_gone() -> void:
	print("--- the tint went, and took its slot with it ---")
	var p = Engine.get_main_loop().root.get_node("Profile")
	_expect("emote is no longer a cosmetic slot", not p.SLOTS.has("emote"))
	_expect("and has no name left behind", not p.SLOT_NAMES.has("emote"))
	_expect("and no entries left behind", (p.entries("emote") as Array).is_empty())
	# Every remaining slot still has to work, or removing one has broken the
	# screen that lists them.
	for slot: String in p.SLOTS:
		_expect("%-8s still has a wearable default" % slot,
			String(p.worn(slot)) != "")


## The gesture, driven the way a thumb drives it. None of this needs a match —
## the point is that the state machine cannot be left half-open.
func _gesture(game) -> void:
	print("--- the gesture opens, picks and closes ---")
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

	# One of the four the fan dropped. It has to still arrive, or a match
	# against the older build is one where half of what they say is silence.
	game._on_net_emote(3)
	_expect("and so does one this build cannot send",
		int(game._emote_in.get("i", -1)) == 3)

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

	# ------------------------------------------------------------ the wire
	#
	# The half that cannot be tested by playing: sending needs a live match and
	# receiving needs somebody else's phone. So the packet is built exactly as
	# `MultiplayerManager.send_event` builds it, put through the same JSON round
	# trip the radio does, and handed to the same dispatcher — which is every
	# step between the two devices except the radio itself.
	print("--- the packet survives the round trip ---")
	game._emote_in = {}
	var packet := {"type": "emote", "payload": {"i": 2}}
	var wire = JSON.parse_string(JSON.stringify(packet))
	_expect("it parses back to a dictionary", typeof(wire) == TYPE_DICTIONARY)

	# JSON has one number type, so an int leaves as an int and comes back a
	# float. `_on_multiplayer_data` casts, and this is the assertion that says
	# so — an index compared without casting would silently match nothing.
	var got = (wire as Dictionary)["payload"]["i"]
	_expect("and the index arrives as a float (%s), not an int"
		% type_string(typeof(got)), typeof(got) == TYPE_FLOAT)

	game._on_multiplayer_data(wire as Dictionary)
	_expect("the dispatcher shows it anyway",
		int(game._emote_in.get("i", -1)) == 2)

	# The send path, which headless cannot take: `_send_emote` needs a live
	# `GKMatch` and there is not one here. So what is asserted is the guard —
	# and specifically that a refused send costs nothing. Spending the cooldown
	# on a packet that never left would leave the key dark for two and a half
	# seconds with nothing to show for it, which is the same bug as build 2
	# wearing a different hat.
	_expect("there is no match in a headless run", not game.net_active())
	game._emote_out = {}
	game._emote_cool = 0.0
	game._send_emote(4)
	_expect("a send with no match echoes nothing", game._emote_out.is_empty())
	_expect("and costs no cooldown", is_zero_approx(game._emote_cool))

	# The two slots are independent, so a reply cannot delete what it replies to.
	game._emote_out = {"i": 4, "left": game.EMOTE_SHOW}
	_expect("yours and theirs coexist",
		int(game._emote_in.get("i", -1)) == 2
		and int(game._emote_out.get("i", -1)) == 4)
	game._tick_emotes(game.EMOTE_SHOW + 0.1)
	_expect("and both expire", game._emote_in.is_empty()
		and game._emote_out.is_empty())

	game.queue_free()


## Whether a frame has a character in it at all. A cell that came out empty
## means the grid in `game.gd` and the grid on disk disagree about the shape of
## the sheet, which is the one failure that looks like nothing until it is on a
## phone.
func _has_content(img: Image, r: Rect2) -> bool:
	var solid := 0
	var y := int(r.position.y)
	while y < int(r.end.y):
		var x := int(r.position.x)
		while x < int(r.end.x):
			if img.get_pixel(x, y).a > 0.9:
				solid += 1
			x += 4
		y += 4
	return solid > 100


## The transparent ring that keeps bilinear filtering from reaching into the
## next frame. Checked all the way round rather than sampled, because a leak
## down one edge is exactly what a mis-set gutter produces.
func _margin_clear(img: Image, i: int, cols: int, cell: float,
		gutter: float) -> bool:
	var ox := (i % cols) * int(cell)
	var oy := (i / cols) * int(cell)
	var span := int(cell)
	var g := int(gutter)
	for k in span:
		for d in g:
			if img.get_pixel(ox + k, oy + d).a > 0.02:
				return false
			if img.get_pixel(ox + k, oy + span - 1 - d).a > 0.02:
				return false
			if img.get_pixel(ox + d, oy + k).a > 0.02:
				return false
			if img.get_pixel(ox + span - 1 - d, oy + k).a > 0.02:
				return false
	return true


## Pure black anywhere among the pixels actually drawn. See `_sheets` for why
## this is a rule rather than a preference.
func _has_pure_black(img: Image) -> bool:
	var y := 0
	while y < img.get_height():
		var x := 0
		while x < img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5 and c.r < 0.02 and c.g < 0.02 and c.b < 0.02:
				return true
			x += 3
		y += 3
	return false


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-52s %s" % [what, "ok" if ok else "FAILED"])
