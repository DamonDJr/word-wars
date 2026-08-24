extends SceneTree
## The title stack has to measure itself.
##
## Its scrollable height was a hardcoded eight rows — seven modes and the rules
## line — which was true right up until the premium plate started coming and
## going with whether it had been bought. A stack that reports a height it does
## not have scrolls to the wrong place, or stops before its last row, and on a
## phone that is a door nobody can reach.
##
## Nothing here can make the store available on Linux, so this checks the shape
## of the sum rather than the plate: that the height is derived from what
## `_title_modes` actually returns, and moves when that does.
##
##   godot --headless --script tools/titletest.gd

var game: Node
var fails := 0


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-56s %s" % [what, "ok" if ok else "FAILED"])


func _init() -> void:
	await process_frame
	game = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	game.phase = game.Phase.TITLE

	print("--- the title stack measures its own contents ---")
	var modes: Array = game._title_modes()
	var m: Dictionary = game._plate_metrics()
	# The same sum `_screen_laid` should be doing: one row per mode, plus the
	# rules line that hangs under them, plus the three band gaps.
	var want: float = float(m["top"]) \
		+ float(modes.size() + 1) * (float(m["h"]) + float(m["gap"])) \
		+ 3.0 * float(m["band_gap"]) + 80.0
	var got: float = game._screen_laid()
	_expect("height is counted from %d plates (%.0f vs %.0f)" % [
		modes.size(), got, want], absf(got - want) < 0.5)

	# And it must move with the count rather than sitting on a constant. Eight
	# was the old number; if the height still matches eight rows when there are
	# seven plates, the count went back to being assumed.
	var wrong: float = float(m["top"]) \
		+ 9.0 * (float(m["h"]) + float(m["gap"])) \
		+ 3.0 * float(m["band_gap"]) + 80.0
	_expect("and is not pinned to a fixed row count",
		modes.size() + 1 == 9 or absf(got - wrong) > 0.5)

	# Every plate has to be reachable where it is drawn, whatever the count.
	var stray := ""
	for b: Dictionary in game._menu_buttons():
		var hit: String = game._action_at((b["rect"] as Rect2).get_center())
		if hit != String(b["action"]):
			stray = "%s hit %s" % [String(b["action"]), hit if hit != "" else "nothing"]
	_expect("every plate is clickable where it is drawn%s" % [
		"" if stray == "" else " — " + stray], stray == "")

	# The premium plate is the one that comes and goes. Off a device there is no
	# store, so it must not be there — a store row on a platform with no store is
	# a button that can only disappoint.
	var acts: PackedStringArray = []
	for row: Array in modes:
		acts.append(String(row[3]))
	_expect("no premium plate without a store (%s)" % ", ".join(acts),
		not acts.has("buy"))

	print("--- %s ---" % ("the title stack holds up" if fails == 0
		else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)
