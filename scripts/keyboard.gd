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
static func _metrics(size: Vector2, bottom: float) -> Dictionary:
	var s := ui_scale(size)
	var gap: float = GAP * s
	var key_h: float = KEY_H * s
	var action_h: float = ACTION_H * s
	# SIDE stays unscaled. It is a margin against the edge of the glass rather
	# than a finger-sized quantity, and the pixel it is worth either way is not
	# one anybody is aiming at.
	var wide: float = size.x - SIDE * 2.0
	return {
		"gap": gap, "key_h": key_h, "action_h": action_h, "wide": wide,
		# Ten to a row is the widest row, so it sets the key width and every
		# other row is centred against it. Rows of differing key sizes read as
		# broken.
		"kw": (wide - gap * 9.0) / 10.0,
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
static func keys(size: Vector2, bottom: float) -> Array:
	var out: Array = []
	var m := _metrics(size, bottom)
	var gap: float = m["gap"]
	var key_h: float = m["key_h"]
	var kw: float = m["kw"]
	var top: float = m["top"]
	# The two keys on the ends of the bottom row, at iOS's proportion for shift
	# and backspace: half a letter wider than a letter. Centring the seven
	# letters then leaves exactly one gap on either side, so the row lines up
	# with the two above it without any of this being written down twice.
	var act_w: float = (kw * 3.0 + gap) * 0.5

	for r in ROWS.size():
		var row: String = ROWS[r]
		var span: float = float(row.length()) * kw + float(row.length() - 1) * gap
		var x: float = (size.x - span) * 0.5
		var y: float = top + float(r) * (key_h + gap)
		if r == ROWS.size() - 1:
			out.append({
				"id": "clear", "label": "CLR",
				"rect": Rect2(SIDE, y, act_w, key_h),
			})
			out.append({
				"id": "back", "label": "DEL",
				"rect": Rect2(size.x - SIDE - act_w, y, act_w, key_h),
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
static func height(size: Vector2) -> float:
	return (float(ROWS.size()) * (KEY_H + GAP) + ACTION_H + GAP) * ui_scale(size)


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
static func emote_rect(size: Vector2, bottom: float) -> Rect2:
	var m := _metrics(size, bottom)
	var s := ui_scale(size)
	var kw: float = m["kw"]
	var w: float = kw * 0.86
	# Right-aligned to P rather than centred on it, so the key and the letter
	# share the edge the thumb is already aiming at.
	var x: float = SIDE + 9.0 * (kw + float(m["gap"])) + (kw - w)
	return Rect2(x, float(m["top"]) - (EMOTE_H + EMOTE_RISE) * s, w, EMOTE_H * s)
