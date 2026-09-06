extends RefCounted
class_name Keyboard
## The on-screen keyboard's shape, kept apart from its painting.
##
## Only the layout lives here — where the keys are and what they say. `game.gd`
## draws them, because drawing needs its fonts and panel helpers, and hit-tests
## them, because tapping a key is the same kind of event as clicking a menu
## button. Splitting it this way means the row arrangement can be argued about
## without touching a single draw call.
##
## QWERTY rather than alphabetical. Alphabetical looks tidier and is slower for
## everybody who has ever used a phone, and this is a game about typing fast.

const ROWS := ["qwertyuiop", "asdfghjkl", "zxcvbnm"]

## The two shapes this keyboard comes in.
##
## FULL is the phone's: ten keys across the whole width, and the only thing that
## fits on glass you hold in one hand. SPLIT is for a tablet, where the full
## width is a foot of glass and the middle of it is not reachable by either
## thumb — the halves hang off the two edges where the hands already are, and
## the space between them goes to the game instead.
enum Form { FULL, SPLIT }

## SPLIT's rows, as [left half, right half]. The same division iOS uses, which
## is worth copying not because it is optimal but because it is the split every
## thumb in the world has already learned.
const SPLIT_ROWS := [["qwert", "yuiop"], ["asdfg", "hjkl"], ["zxcv", "bnm"]]

## Everything is derived from these, so the whole keyboard resizes by changing
## two numbers rather than by moving thirty rectangles.
##
## Written for a screen exactly as tall as the design space assumes. Anything
## shorter gets them multiplied by `ui_scale` — see below.
const KEY_H := 92.0
const GAP := 7.0
const SIDE := 10.0
const ACTION_H := 96.0

## The design space's short axis. It is 720 in both orientations — 720x1440 on a
## phone, 1280x720 on a desktop — so one number covers both.
const SHORT_AXIS := 720.0
## Tablets run the compensation below off the end of its usefulness: their units
## are enormous already and doubling down produces keys the size of a fist. The
## shortest phone anyone still plays this on needs 1.125, so the cap sits just
## above that and catches everything wider.
const MAX_SCALE := 1.15

## The phone's keyboard, measured in points.
##
## Every other number in this file is in design units, which is the right unit
## for anything that has to sit in a composition and the wrong one for anything
## a thumb has to hit. A design unit is 0.55pt on an iPhone and 0.82pt on an
## iPad, so `KEY_H` — one number, unchanged — is a 50pt key on the phone and an
## 86pt key on the tablet. Sideways it is worse, because `kw` is derived from
## the viewport width and the tablet's viewport is 40% wider: 35pt against 74pt.
## Together that is a key with three and a half times the area.
##
## That is not a cosmetic difference. This is a game about typing fast under
## time pressure, where the cost of a big target is a miss that did not happen
## and the currency is words per minute. Handing one platform a keyboard that is
## measurably harder to mistype on is the definition of the unfair advantage
## this port is trying not to create.
##
## So on a tablet the keys are asked for in points instead, and these are the
## points to ask for: the numbers the phone layout above already produces on a
## 393pt handset, written down. A key is the same size against a thumb on every
## device that runs this game, and the tablet's extra glass is spent on things
## that are not targets.
##
## Deliberately no tablet bonus. There is an argument for one — a tablet is held
## further from the face and less steadily — and there is a better argument
## against, which is that "the same size everywhere" is a rule that can be
## explained to a player who thinks they were cheated, and "the same size plus
## twelve percent" is not. If it turns out to need one, it is this constant.
const KEY_W_PT := 34.8
const KEY_H_PT := 50.2
const GAP_PT := 3.8
const ACTION_H_PT := 52.4


## How much bigger than its written size the keyboard has to be drawn here.
##
## `expand` stretching pins one axis of the design space to the screen and lets
## the other overflow, and which axis it picks depends on the phone's shape. A
## 19.5:9 phone is taller than the 2:1 design space, so the *width* is pinned and
## a unit is 1/720th of the screen. A 16:9 phone is shorter, so the *height* is
## pinned instead — the viewport comes out 810 units across rather than 720, and
## every unit in it is 12% smaller than the one this file was measured in.
##
## Horizontal measurements do not care, because they are all derived from
## `size.x` and so track the screen by construction. Vertical ones are written as
## constants and do care: left alone, `KEY_H` means a 50pt key on a modern phone
## and a 42pt key on an older, smaller one — the keyboard quietly shrinks on
## exactly the handset whose owner has the least room to spare, while their thumb
## stays the size it always was. This is that difference, so the constants above
## can be multiplied back up to the size they were meant to be.
static func ui_scale(size: Vector2) -> float:
	return clampf(minf(size.x, size.y) / SHORT_AXIS, 1.0, MAX_SCALE)


## Every measurement the layout is built out of, worked out once.
##
## `keys` and `emote_rect` both need the key width and the top of the letter
## rows, and both used to derive them from scratch. Two copies of the same four
## lines is two chances for the emote key to end up describing a keyboard that is
## not the one being drawn, which is the one bug the key cannot afford: it sits
## directly above P and is hit-tested first.
## `ppu` is how many points one design unit is worth on this screen, and it is
## the switch between the two ways of sizing a key. Left at zero — which is what
## every phone and desktop caller passes — the keyboard is sized as a fraction
## of the viewport, exactly as it has shipped. Given a real number, the keys are
## sized in points instead and come out the same size against a thumb as they do
## on a phone. See `KEY_W_PT`.
##
## Only tablets pass it. Phones could — the two paths agree to within a third of
## a unit on a 393pt handset, which is the arithmetic confirming that `KEY_W_PT`
## and friends really were measured off this layout and not guessed — but the
## proportional path is the one that has shipped and been tuned against real
## thumbs, and a keyboard is not the place to take a rewrite for tidiness.
static func _metrics(size: Vector2, bottom: float, ppu := 0.0,
		form := Form.FULL) -> Dictionary:
	var gap: float
	var key_h: float
	var action_h: float
	var kw: float
	# SIDE stays unscaled in both paths. It is a margin against the edge of the
	# glass rather than a finger-sized quantity, and the pixel it is worth
	# either way is not one anybody is aiming at.
	var wide: float = size.x - SIDE * 2.0

	if ppu > 0.0:
		gap = GAP_PT / ppu
		key_h = KEY_H_PT / ppu
		action_h = ACTION_H_PT / ppu
		kw = KEY_W_PT / ppu
	else:
		var s := ui_scale(size)
		gap = GAP * s
		key_h = KEY_H * s
		action_h = ACTION_H * s
		# Ten to a row is the widest row, so it sets the key width and every
		# other row is centred against it. Rows of differing key sizes read as
		# broken.
		kw = (wide - gap * 9.0) / 10.0

	# The two ends of the bottom row, at iOS's proportion for shift and
	# backspace: half a letter wider than a letter. In FULL that lets the seven
	# centred letters leave exactly one gap either side; in SPLIT it is simply
	# the size a key that is not a letter gets.
	var act_w: float = (kw * 3.0 + gap) * 0.5 if ppu <= 0.0 else kw * 1.5

	return {
		"gap": gap, "key_h": key_h, "action_h": action_h, "wide": wide,
		"kw": kw, "act_w": act_w,
		# The widest row a cluster has to hold is five keys — see `SPLIT_ROWS`.
		# The bottom rows are shorter in letters but carry an action key, so
		# they run wider than this and are allowed to; they overhang *inward*,
		# into the gap between the halves, which is the one direction with
		# hundreds of units of nothing in it.
		"cluster_w": kw * 5.0 + gap * 4.0,
		"top": bottom - action_h - gap - float(ROWS.size()) * (key_h + gap),
	}


## Where the keys are, for a keyboard occupying the full width of `size` and
## sitting with its last row at the bottom of `bottom`.
##
## Returns rows of `{"id", "label", "rect"}`. `id` is a single letter for the
## letter keys, or "back" / "clear" / "fire" for the three actions — so the
## caller matches on a string rather than on a position, and the layout stays
## free to move.
##
## DEL used to sit at the bottom left, sharing the action row with FIRE, and it
## was the single most complained-about thing on the screen: every phone keyboard
## anybody has ever used puts backspace at the right end of the bottom letter
## row, and thirty years of that beats whatever this game would prefer. So the
## bottom letter row now flanks ZXCVBNM the way iOS does — CLR where shift is,
## DEL where backspace is — and FIRE, freed of sharing, takes the whole action
## row. Every one of those is a bigger target than it was before.
static func keys(size: Vector2, bottom: float, ppu := 0.0,
		form := Form.FULL) -> Array:
	var m := _metrics(size, bottom, ppu, form)
	if form == Form.SPLIT:
		return _split_keys(size, m)

	var out: Array = []
	var gap: float = m["gap"]
	var key_h: float = m["key_h"]
	var kw: float = m["kw"]
	var top: float = m["top"]
	var act_w: float = m["act_w"]
	# The block the ten-key row occupies, and where its left edge falls. CLR,
	# DEL and FIRE are placed against these rather than against the edges of the
	# screen, which is the same thing right up until it is not: on the
	# proportional path `kw` is *derived* from the viewport width, so the block
	# is the full width, `block_x` is `SIDE`, and every rectangle below comes out
	# byte-identical to what the phone has always drawn. Size the keys in points
	# instead and the ten of them only span two thirds of a tablet, at which
	# point "the left edge of the screen" and "the left edge of the keyboard"
	# are two hundred units apart — and CLR and DEL were being left stranded out
	# at the first one, a thumb's journey from the letters they belong to.
	var block: float = kw * 10.0 + gap * 9.0
	var block_x: float = (size.x - block) * 0.5

	for r in ROWS.size():
		var row: String = ROWS[r]
		var span: float = float(row.length()) * kw + float(row.length() - 1) * gap
		var x: float = block_x + (block - span) * 0.5
		var y: float = top + float(r) * (key_h + gap)
		if r == ROWS.size() - 1:
			out.append({
				"id": "clear", "label": "CLR",
				"rect": Rect2(block_x, y, act_w, key_h),
			})
			out.append({
				"id": "back", "label": "DEL",
				"rect": Rect2(block_x + block - act_w, y, act_w, key_h),
			})
		for i in row.length():
			out.append({
				"id": row[i],
				"label": row[i].to_upper(),
				"rect": Rect2(x + float(i) * (kw + gap), y, kw, key_h),
			})

	# Fire owns the action row outright. It is pressed once per word, more often
	# than any single letter, and it is the press you make in the most hurry.
	var y2: float = top + float(ROWS.size()) * (key_h + gap)
	out.append({
		"id": "fire", "label": "FIRE",
		"rect": Rect2(block_x, y2, block, m["action_h"]),
	})
	return out


## SPLIT's keys: two thumb-sized halves pinned to the two edges of the glass.
##
## Each half is aligned to the edge it hangs off — the left rows all start at
## the left margin, the right rows all end at the right one — so the outer
## column of keys is a straight line under the thumb that has to reach it, and
## the raggedness is pushed to the inner edge where there is nothing to collide
## with. Centring the rows within each half instead would trade a tidy inner
## edge for a wobbly outer one, which is the wrong way round: nobody aims at the
## middle of this keyboard, and everybody aims at its edges.
##
## That alignment is also what makes the two action keys fall out for free. CLR
## is the first thing in the left bottom row and DEL the last thing in the right
## one, which puts them on the outer edges — where shift and backspace sit on
## every phone keyboard, and where the two thumbs are already resting.
##
## FIRE stays one key spanning the whole width rather than becoming a pair, one
## per half. A pair is better for the thumbs and worse for everything else: two
## keys that do the same thing can be pressed at once, and the second press of a
## double-fire lands on an empty line. One wide bar is reachable from either
## side, is where FIRE already is on the phone so the habit transfers intact,
## and cannot be pressed twice.
static func _split_keys(size: Vector2, m: Dictionary) -> Array:
	var out: Array = []
	var gap: float = m["gap"]
	var key_h: float = m["key_h"]
	var kw: float = m["kw"]
	var act_w: float = m["act_w"]
	var top: float = m["top"]
	var right_edge: float = size.x - SIDE

	for r in SPLIT_ROWS.size():
		var y: float = top + float(r) * (key_h + gap)
		var last: bool = r == SPLIT_ROWS.size() - 1
		var pair: Array = SPLIT_ROWS[r]

		# Left half, laid out rightward from the left margin, with CLR taking
		# the outer slot on the bottom row.
		var x: float = SIDE
		if last:
			out.append({
				"id": "clear", "label": "CLR",
				"rect": Rect2(x, y, act_w, key_h),
			})
			x += act_w + gap
		var left: String = pair[0]
		for i in left.length():
			out.append({
				"id": left[i], "label": left[i].to_upper(),
				"rect": Rect2(x, y, kw, key_h),
			})
			x += kw + gap

		# Right half. Measured first and then laid out from the resulting left
		# edge, because the row has to *end* on the margin and the number of
		# keys in it changes from row to row.
		var right: String = pair[1]
		var span: float = float(right.length()) * kw \
			+ float(right.length() - 1) * gap
		if last:
			span += act_w + gap
		x = right_edge - span
		for i in right.length():
			out.append({
				"id": right[i], "label": right[i].to_upper(),
				"rect": Rect2(x, y, kw, key_h),
			})
			x += kw + gap
		if last:
			out.append({
				"id": "back", "label": "DEL",
				"rect": Rect2(x, y, act_w, key_h),
			})

	var y2: float = top + float(SPLIT_ROWS.size()) * (key_h + gap)
	out.append({
		"id": "fire", "label": "FIRE",
		"rect": Rect2(SIDE, y2, m["wide"], m["action_h"]),
	})
	return out


## Total height, so a caller can work out what is left for everything else.
##
## The emote key is deliberately *not* in here. It sits above the top letter row
## in space the board was already leaving empty, and folding it into the height
## would push `PORTRAIT_BOARD_TOP` down and shrink the playfield on every phone —
## which is a real cost, paid on every screen, for a control used a handful of
## times a match. So it hangs off the top of the band and is hit-tested ahead of
## the keyboard rather than as part of it.
static func height(size: Vector2, ppu := 0.0, form := Form.FULL) -> float:
	if ppu > 0.0:
		# Both forms have three letter rows and one action row, so this is the
		# same sum either way — SPLIT is narrower, not shorter.
		return (float(ROWS.size()) * (KEY_H_PT + GAP_PT) + ACTION_H_PT + GAP_PT) / ppu
	return (float(ROWS.size()) * (KEY_H + GAP) + ACTION_H + GAP) * ui_scale(size)


## How much to multiply a type size by so the lettering tracks the keys.
##
## `_draw_keyboard` used `ui_scale` for this, which was the same number as the
## one sizing the keys right up until the keys started being sized in points.
## Deriving it from the key height instead keeps the two locked together by
## construction: a cap is a fixed fraction of the key it is printed on, whatever
## decided how big that key is. On the proportional path this returns exactly
## `ui_scale`, which is what makes the phone layout come out unchanged.
static func type_scale(size: Vector2, ppu := 0.0, form := Form.FULL) -> float:
	if ppu > 0.0:
		return (KEY_H_PT / ppu) / KEY_H
	return ui_scale(size)


## How tall the emote key is, and how far above the letters it floats.
const EMOTE_H := 54.0
const EMOTE_RISE := 10.0


## The emote key, sitting directly above P.
##
## Above P specifically because it is the far right of the top row: the only
## letter with nothing above it and no neighbour to its right, so a thumb
## overshooting it lands on screen furniture rather than on another letter. It is
## also the corner a right thumb reaches without crossing the board.
##
## Narrower than P on purpose. It is a hold-to-open control, so a stray tap costs
## nothing — but a stray tap that *misses P* costs a letter, and the whole point
## of the last keyboard pass was that letters are the thing you must not miss.
## In SPLIT, P is the last key of the right half's top row and that row is
## aligned to the right margin — so "right-aligned to P" resolves to the margin
## itself, and the rule that put this key in the corner on a phone puts it in
## the same corner on a tablet without being told about halves at all.
static func emote_rect(size: Vector2, bottom: float, ppu := 0.0,
		form := Form.FULL) -> Rect2:
	var m := _metrics(size, bottom, ppu, form)
	var s := type_scale(size, ppu, form)
	var kw: float = m["kw"]
	var w: float = kw * 0.86
	# Right-aligned to P rather than centred on it, so the key and the letter
	# share the edge the thumb is already aiming at.
	var x: float = size.x - SIDE - w
	if form == Form.FULL:
		# Off the left edge of the key block, not of the screen — see `keys`.
		var gap: float = m["gap"]
		var block_x: float = (size.x - (kw * 10.0 + gap * 9.0)) * 0.5
		x = block_x + 9.0 * (kw + gap) + (kw - w)
	return Rect2(x, float(m["top"]) - (EMOTE_H + EMOTE_RISE) * s, w, EMOTE_H * s)
