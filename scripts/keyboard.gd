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
const KEY_H := 92.0
const GAP := 7.0
const SIDE := 10.0
const ACTION_H := 96.0


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
	var wide: float = size.x - SIDE * 2.0
	# Ten to a row is the widest row, so it sets the key width and every other
	# row is centred against it. Rows of differing key sizes read as broken.
	var kw: float = (wide - GAP * 9.0) / 10.0
	var top: float = bottom - ACTION_H - GAP - float(ROWS.size()) * (KEY_H + GAP)
	# The two keys on the ends of the bottom row, at iOS's proportion for shift
	# and backspace: half a letter wider than a letter. Centring the seven
	# letters then leaves exactly one GAP on either side, so the row lines up
	# with the two above it without any of this being written down twice.
	var act_w: float = (kw * 3.0 + GAP) * 0.5

	for r in ROWS.size():
		var row: String = ROWS[r]
		var span: float = float(row.length()) * kw + float(row.length() - 1) * GAP
		var x: float = (size.x - span) * 0.5
		var y: float = top + float(r) * (KEY_H + GAP)
		if r == ROWS.size() - 1:
			out.append({
				"id": "clear", "label": "CLR",
				"rect": Rect2(SIDE, y, act_w, KEY_H),
			})
			out.append({
				"id": "back", "label": "DEL",
				"rect": Rect2(size.x - SIDE - act_w, y, act_w, KEY_H),
			})
		for i in row.length():
			out.append({
				"id": row[i],
				"label": row[i].to_upper(),
				"rect": Rect2(x + float(i) * (kw + GAP), y, kw, KEY_H),
			})

	# Fire owns the action row outright. It is pressed once per word, more often
	# than any single letter, and it is the press you make in the most hurry.
	var y2: float = top + float(ROWS.size()) * (KEY_H + GAP)
	out.append({
		"id": "fire", "label": "FIRE",
		"rect": Rect2(SIDE, y2, wide, ACTION_H),
	})
	return out


## Total height, so a caller can work out what is left for everything else.
static func height() -> float:
	return float(ROWS.size()) * (KEY_H + GAP) + ACTION_H + GAP
