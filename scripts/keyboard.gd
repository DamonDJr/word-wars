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
## letter keys, or "back" / "fire" for the two actions — so the caller matches on
## a string rather than on a position, and the layout stays free to move.
static func keys(size: Vector2, bottom: float) -> Array:
	var out: Array = []
	var wide: float = size.x - SIDE * 2.0
	# Ten to a row is the widest row, so it sets the key width and every other
	# row is centred against it. Rows of differing key sizes read as broken.
	var kw: float = (wide - GAP * 9.0) / 10.0
	var top: float = bottom - ACTION_H - GAP - float(ROWS.size()) * (KEY_H + GAP)

	for r in ROWS.size():
		var row: String = ROWS[r]
		var span: float = float(row.length()) * kw + float(row.length() - 1) * GAP
		var x: float = (size.x - span) * 0.5
		var y: float = top + float(r) * (KEY_H + GAP)
		for i in row.length():
			out.append({
				"id": row[i],
				"label": row[i].to_upper(),
				"rect": Rect2(x + float(i) * (kw + GAP), y, kw, KEY_H),
			})

	# Backspace and fire share the last row. Fire is the wider of the two and
	# sits under the right hand, because it is pressed far more often.
	var y2: float = top + float(ROWS.size()) * (KEY_H + GAP)
	var back_w: float = wide * 0.3
	out.append({
		"id": "back", "label": "DEL",
		"rect": Rect2(SIDE, y2, back_w, ACTION_H),
	})
	out.append({
		"id": "fire", "label": "FIRE",
		"rect": Rect2(SIDE + back_w + GAP, y2, wide - back_w - GAP, ACTION_H),
	})
	return out


## Total height, so a caller can work out what is left for everything else.
static func height() -> float:
	return float(ROWS.size()) * (KEY_H + GAP) + ACTION_H + GAP
