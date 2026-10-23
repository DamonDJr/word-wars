extends SceneTree
## The iPhone Duo's poses, as assertions rather than as pictures.
##
## `duoshots.gd` and `shots.gd` show what a pose looks like; this is what stops
## it quietly looking wrong again. Every number below is a thing that was wrong
## at some point in the first Duo render of this game, or a thing Apple's own
## guide says to check:
##
##   - nothing interactive stands where the Dynamic Island and status bar do
##   - nothing interactive or readable stands in the fold
##   - a key is a key: wide enough and tall enough in *inches*, which design
##     units hide — a unit is 0.0036" on an iPhone 15 and 0.0049" on the open Duo
##   - tapping the middle of a key types that key, in every form of keyboard
##   - folding, opening and turning the device in the middle of a match keeps the
##     match: the blocks on the board, the word half typed, the phase
##
## One pose per invocation, the way `duoprobe.gd` is — `start_match` is not built
## to be called many times into one tree. `tools/duotest.sh` runs the lot.
##
##   godot --headless --script tools/duotest.gd -- inner-landscape
##   godot --headless --script tools/duotest.gd -- inner-landscape --then outer-portrait
##   godot --headless --script tools/duotest.gd -- classify
##
## Headless works here, unlike the shot tools: nothing is rendered, only laid out.

const Poses = preload("res://tools/duo_poses.gd")

## What a key must measure, in inches. The iPhone 15's keys are 0.23 x 0.33 and
## are the floor: a Duo must not be asked to type on less than a phone is.
const MIN_KEY_W_IN := 0.22
const MIN_KEY_H_IN := 0.30
## A board cell's height, in inches, below which a stamp is a smudge. The cover
## display's phone layout comes out at 0.15 and is the smallest in circulation.
const MIN_CELL_H_IN := 0.14

var game: Node
var stage: SubViewport
var fails := 0
var pose_name := ""


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and String(args[0]) == "classify":
		_classify()
		_done("device classes behave")
		return

	if args.size() > 0 and String(args[0]) == "hinge":
		await _hinge()
		_done("the hinge is read right")
		return

	pose_name = String(args[0]) if args.size() > 0 else "inner-landscape"
	if not Poses.POSES.has(pose_name):
		push_error("unknown pose: %s" % pose_name)
		quit(2)
		return

	await _boot(Poses.POSES[pose_name])
	print("--- %s ---" % pose_name)
	_check_layout(pose_name)

	var ti := args.find("--then")
	if ti >= 0 and ti + 1 < args.size():
		await _check_resize(String(args[ti + 1]))

	_done("%s behaves" % pose_name)


func _done(ok_line: String) -> void:
	print("--- %s ---" % (ok_line if fails == 0 else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)


## A game in a SubViewport the size of the pose's design space, mid-match, with a
## half-typed word — everything a resize has to preserve.
func _boot(spec: Dictionary) -> void:
	stage = SubViewport.new()
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.size = spec["px"]
	stage.size_2d_override = spec["units"]
	stage.size_2d_override_stretch = true
	get_root().add_child(stage)
	game = load("res://scenes/main.tscn").instantiate()
	stage.add_child(game)
	await process_frame
	await process_frame
	game._skip_splash()
	await process_frame
	if get_root().size_changed.is_connected(game._apply_orientation):
		get_root().size_changed.disconnect(game._apply_orientation)
	# Saved nowhere real: a test that poses a player must not write the dev save.
	get_root().get_node("Profile").save_path = "user://profile-duotest.cfg"
	Poses.apply(game, spec)
	game.start_match("Magpie", 1)
	game.phase = game.Phase.PLAY
	game._deal_daily_opening()
	game._layout_boards()
	for ch in "star":
		game._press_key(ch)
	for i in 6:
		await process_frame


# --- layout ---------------------------------------------------------------


func _check_layout(name: String) -> void:
	var spec: Dictionary = Poses.POSES[name]
	var size: Vector2 = game.get_viewport_rect().size
	var usable: Rect2 = game._usable()
	var fold: Rect2 = game.fold
	var unit := Poses.unit_inches(name)

	var keys: Array = game._keyboard()
	_expect("a keyboard is up", not keys.is_empty())

	# Nothing the thumb has to hit may be in the island's column or the fold.
	var bad_edge: Array = []
	var bad_fold: Array = []
	for k: Dictionary in keys:
		var r: Rect2 = k["rect"]
		if not usable.grow(0.5).encloses(r):
			bad_edge.append(String(k["id"]))
		if fold.has_area() and fold.intersects(r):
			bad_fold.append(String(k["id"]))
	var emote: Rect2 = game._kb_emote_rect(size, game._keyboard_bottom())
	var back: Rect2 = game._back_rect()
	for pair in [["emote", emote], ["back", back]]:
		var pr: Rect2 = pair[1]
		if not usable.grow(0.5).encloses(pr):
			bad_edge.append(String(pair[0]))
		if fold.has_area() and fold.intersects(pr):
			bad_fold.append(String(pair[0]))
	_expect("every key, and the emote and back keys, are clear of the insets",
		bad_edge.is_empty(), ", ".join(bad_edge))
	_expect("every key, and the emote and back keys, are clear of the fold",
		bad_fold.is_empty(), ", ".join(bad_fold))

	# Boards: inside the usable area, out of the fold, and not under any key.
	var board_bad: Array = []
	var under_keys: Array = []
	for s: Variant in game.sides:
		var side: Object = s
		if side.slot > 0 and not side.in_match:
			continue
		var br: Rect2 = game._board_rect(side)
		# A rival parked off-screen to make way for its card is not a board.
		if br.position.x < -1000.0:
			continue
		if not usable.grow(0.5).encloses(br):
			board_bad.append("slot %d" % side.slot)
		if fold.has_area() and fold.intersects(br):
			board_bad.append("slot %d in fold" % side.slot)
		for k2: Dictionary in keys:
			if br.intersects(k2["rect"]):
				under_keys.append("%s/%s" % [side.slot, k2["id"]])
				break
	_expect("every board is inside the usable area and out of the fold",
		board_bad.is_empty(), ", ".join(board_bad))
	_expect("no board stands on a key", under_keys.is_empty(), ", ".join(under_keys))

	# The band under the board — the word you are typing — is read, so it is out
	# of the fold too, and above the keys it belongs to.
	if fold.has_area() and fold.size.x > fold.size.y:
		var band_top: float = game._portrait_band_top()
		_expect("the typed-word band is below a horizontal fold",
			band_top >= fold.end.y - 0.5)

	# Held as a laptop the lower half is all keyboard: the whole keyboard, not the
	# split one (G and H side by side, no lake between them), starting straight
	# under the strip for the word being typed.
	var by_id := {}
	for kk: Dictionary in keys:
		by_id[String(kk["id"])] = kk["rect"]
	if fold.has_area() and fold.size.x > fold.size.y:
		var g: Rect2 = by_id["g"]
		var h: Rect2 = by_id["h"]
		_expect("held as a laptop the keys run the whole width, unsplit",
			h.position.x - g.end.x < g.size.x * 0.5,
			"G ends %.0f, H starts %.0f" % [g.end.x, h.position.x])
		var keys_top := size.y
		for kt: Dictionary in keys:
			keys_top = minf(keys_top, (kt["rect"] as Rect2).position.y)
		var strip: float = 8.0 + 112.0 * game._kb_type_scale(size)
		_expect("held as a laptop the keys fill the half below the crease",
			keys_top <= fold.end.y + strip + 1.0,
			"keys start %.0f, crease ends %.0f" % [keys_top, fold.end.y])

	# Held as a book the keys are split, a half on each page of the crease.
	if fold.has_area() and fold.size.y >= fold.size.x:
		var left_page := true
		var right_page := true
		for id: String in ["q", "w", "e", "r", "t", "a", "s", "d", "f", "g", "z", "x", "c", "v"]:
			left_page = left_page and (by_id[id] as Rect2).end.x <= fold.position.x
		for id: String in ["y", "u", "i", "o", "p", "h", "j", "k", "l", "b", "n", "m"]:
			right_page = right_page and (by_id[id] as Rect2).position.x >= fold.end.x
		_expect("held as a book the keys split, a half on each page",
			left_page and right_page, "left=%s right=%s" % [left_page, right_page])

	# Tapping the middle of a key types that key. `_key_at` takes a point a
	# finger's lift below where it means, so the test supplies it.
	var missed: Array = []
	var lift: float = game._touch_lift(size)
	for k3: Dictionary in keys:
		var c: Vector2 = (k3["rect"] as Rect2).get_center()
		var got: String = game._key_at(c + Vector2(0.0, lift))
		if got != String(k3["id"]):
			missed.append("%s->%s" % [k3["id"], got])
	_expect("the middle of every key types that key", missed.is_empty(),
		", ".join(missed))

	# Physical sizes. Design units are what hides a keyboard that is smaller than
	# a phone's on a bigger device, so everything here is in inches.
	var small_keys: Array = []
	for k4: Dictionary in keys:
		var id: String = k4["id"]
		if id.length() != 1:
			continue
		var kr: Rect2 = k4["rect"]
		if kr.size.x * unit < MIN_KEY_W_IN or kr.size.y * unit < MIN_KEY_H_IN:
			small_keys.append("%s %.2fx%.2f" % [id, kr.size.x * unit, kr.size.y * unit])
			break
	_expect("a letter key is at least %.2f x %.2f in" % [MIN_KEY_W_IN, MIN_KEY_H_IN],
		small_keys.is_empty(), ", ".join(small_keys))

	var pb: Rect2 = game._board_rect(game.player)
	var cell_h_in: float = pb.size.y / float(game.WWBoard.ROWS) * unit \
		if "WWBoard" in game else pb.size.y / 12.0 * unit
	_expect("a board cell is at least %.2f in tall (is %.2f)" % [MIN_CELL_H_IN, cell_h_in],
		cell_h_in >= MIN_CELL_H_IN)

	# The title menu scrolls on a short glass, and has to scroll all the way: the
	# last door (Settings) was unreachable on an iPad held wide, because the
	# scroll limit was measured from a list that had already been scrolled.
	_check_title_scroll(name, size)
	_check_summary(name, size)

	# The home indicator and the like: nothing below the safe bottom.
	var lowest := 0.0
	for k5: Dictionary in keys:
		lowest = maxf(lowest, (k5["rect"] as Rect2).end.y)
	_expect("the keys stop above the bottom inset",
		lowest <= size.y - float(spec["safe"].y) + 0.5)

	# FIRE is the one press made in a hurry, and it has to be as wide as the
	# board it stands under or it is easy to miss.
	var fire: Rect2
	for k6: Dictionary in keys:
		if k6["id"] == "fire":
			fire = k6["rect"]
	_expect("FIRE exists and is at least 1.0 in wide", fire.size.x * unit >= 1.0,
		"%.2f" % (fire.size.x * unit))

	# Held wide there is a FIRE under each thumb and none in the middle; every
	# other shape has the one bar. Counted from the keys the game draws and hits.
	var fires: Array = []
	for k7: Dictionary in keys:
		if k7["id"] == "fire":
			fires.append(k7["rect"])
	if game.wide_touch:
		var left := false
		var right := false
		var middle := false
		for fr: Rect2 in fires:
			var cx: float = fr.get_center().x
			left = left or cx < size.x * 0.35
			right = right or cx > size.x * 0.65
			middle = middle or (cx >= size.x * 0.35 and cx <= size.x * 0.65)
		_expect("held wide there is a FIRE under each thumb and none between",
			fires.size() == 2 and left and right and not middle,
			"%d keys, left=%s right=%s middle=%s" % [fires.size(), left, right, middle])
	else:
		_expect("held tall there is one FIRE bar", fires.size() == 1,
			"%d keys" % fires.size())


## Scroll the title to the end and ask where its last door is. Run in every pose
## because the bug it guards against only shows where the list is taller than the
## glass, which is a question about the pose.
func _check_title_scroll(name: String, size: Vector2) -> void:
	var was: int = game.phase
	game.phase = game.Phase.TITLE
	game._scroll = 0.0
	game._tick_scroll()
	var reach: float = game._scroll_max
	# Scrolled to the end, and the limit asked again: it must not have moved.
	game._scroll = reach
	game._tick_scroll()
	var again: float = game._scroll_max
	var last := Rect2()
	for plate: Dictionary in game._title_plates():
		if String(plate["action"]) == "settings":
			last = plate["rect"]
	var bottom: float = size.y - game.safe_bottom
	_expect("the title's scroll limit does not shrink as it is scrolled",
		absf(again - reach) < 0.5, "%.0f then %.0f" % [reach, again])
	_expect("scrolled to the end, the last door is on the glass",
		last.has_area() and last.end.y <= bottom + 1.0,
		"ends at %.0f of %.0f" % [last.end.y, bottom])

	# And every other screen that scrolls, for the same circularity: a limit
	# computed from positions that the scroll itself moves.
	var unstable: Array = []
	for ph in [game.Phase.PRACTICE, game.Phase.SOLO, game.Phase.MASTERY,
			game.Phase.COSMETICS, game.Phase.SETTINGS, game.Phase.LOBBY,
			game.Phase.BOARDS, game.Phase.WEEKLY]:
		game.phase = ph
		game._scroll = 0.0
		game._tick_scroll()
		var m0: float = game._scroll_max
		game._scroll = m0
		game._tick_scroll()
		if absf(float(game._scroll_max) - m0) > 0.5:
			unstable.append("%d: %.0f then %.0f" % [ph, m0, game._scroll_max])
	_expect("no other scrolling screen's limit moves as it is scrolled",
		unstable.is_empty(), ", ".join(unstable))
	game._scroll = 0.0
	game.phase = was
	game._tick_scroll()


## The end-of-match summary has to be reachable to its last button on every
## glass, whichever way it is held. It was drawn at phone height regardless of
## the window, and scrolled nowhere: on an iPad held wide the table and the
## buttons were simply past the bottom.
##
## Run for the endings that change how tall it is — a loss with a margin line and
## a level-up under the buttons, a plain win, the daily with its board, a
## survival run — because each adds a different amount below the table.
func _check_summary(name: String, size: Vector2) -> void:
	var was_phase: int = game.phase
	var was_mode: int = game.mode
	var was_winner: String = game.winner
	var was_earned: Dictionary = game.earned
	var was_age: float = game.over_age
	var variants := [
		{"name": "loss", "mode": game.Mode.NORMAL, "winner": "Magpie",
			"earned": {"xp": 340, "from": 4, "to": 5, "new": ["Neon board", "Pulse stamp"]}},
		{"name": "win", "mode": game.Mode.NORMAL, "winner": "YOU", "earned": {}},
		{"name": "daily", "mode": game.Mode.DAILY, "winner": "YOU",
			"earned": {"xp": 90, "from": 4, "to": 4, "new": []}},
		{"name": "survival", "mode": game.Mode.SURVIVAL, "winner": "Magpie", "earned": {}},
	]
	var bottom: float = size.y - game.safe_bottom
	for v: Dictionary in variants:
		var tag := "%s summary" % v["name"]
		game.phase = game.Phase.OVER
		game.mode = int(v["mode"])
		game.winner = String(v["winner"])
		game.earned = v["earned"]
		game.over_age = 5.0
		game._scroll = 0.0
		game._tick_scroll()
		var reach: float = game._scroll_max

		# The limit is a fact about the content: asking again from the end of the
		# scroll must give the same answer.
		game._scroll = reach
		game._tick_scroll()
		_expect("the %s's scroll limit does not move as it is scrolled" % tag,
			absf(float(game._scroll_max) - reach) < 0.5,
			"%.0f then %.0f" % [reach, game._scroll_max])

		# At the end of the scroll every button is on the glass.
		var off: Array = []
		var lowest := 0.0
		for b: Dictionary in game._menu_buttons():
			var br: Rect2 = b["rect"]
			if String(b["action"]).begins_with("dtab:"):
				continue
			lowest = maxf(lowest, br.end.y)
			if br.end.y > bottom + 1.0 or br.position.x < -0.5 \
					or br.end.x > size.x + 0.5:
				off.append("%s %.0f-%.0f of %.0f" % [b["action"], br.position.y,
					br.end.y, bottom])
		_expect("scrolled to the end, every button of the %s is on the glass" % tag,
			off.is_empty(), ", ".join(off))
		_expect("...and the last of them is within the screen's lower half (%.0f)" % lowest,
			lowest > size.y * 0.35)

		# At rest the headline is on the glass: the top of the page is the top.
		game._scroll = 0.0
		game._tick_scroll()
		var top: float = game._scoreboard_top()
		_expect("at rest the %s's table starts on the glass (%.0f)" % [v["name"], top],
			top > 0.0 and top < size.y)
		# And it only scrolls when it has to: if it fits, there is nothing to drag.
		var fit_lowest := 0.0
		for b2: Dictionary in game._menu_buttons():
			if not String(b2["action"]).begins_with("dtab:"):
				fit_lowest = maxf(fit_lowest, (b2["rect"] as Rect2).end.y)
		if reach <= 1.0:
			_expect("a %s that does not scroll fits on the glass" % tag,
				fit_lowest <= bottom + 1.0, "%.0f of %.0f" % [fit_lowest, bottom])
		else:
			# And where it does, the page answers a drag. The wheel goes through
			# the same gate as a finger, `_scrollable() and _scroll_max > 1`.
			var wheel := InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
			wheel.pressed = true
			game._unhandled_input(wheel)
			_expect("the wheel scrolls the %s" % tag, float(game._scroll) > 0.0,
				"scroll %.0f of %.0f" % [game._scroll, reach])
			game._scroll = 0.0

	game._scroll = 0.0
	game.phase = was_phase
	game.mode = was_mode
	game.winner = was_winner
	game.earned = was_earned
	game.over_age = was_age
	game._tick_scroll()


# --- resize ---------------------------------------------------------------


## Turn, fold or open the device in the middle of the match: what the player was
## holding has to still be in their hands.
func _check_resize(to_name: String) -> void:
	if not Poses.POSES.has(to_name):
		push_error("unknown pose: %s" % to_name)
		fails += 1
		return
	var before_blocks: int = game.player.board.prefixes().size()
	var before_typed: String = game.typed
	var before_phase: int = game.phase
	var before_score: int = game.player.score

	var spec: Dictionary = Poses.POSES[to_name]
	stage.size = spec["px"]
	stage.size_2d_override = spec["units"]
	Poses.apply(game, spec)
	game._layout_boards()
	game.queue_redraw()
	for i in 6:
		await process_frame

	print("--- then %s ---" % to_name)
	_expect("the blocks on the board survive", \
		game.player.board.prefixes().size() == before_blocks,
		"%d -> %d" % [before_blocks, game.player.board.prefixes().size()])
	_expect("the half-typed word survives", game.typed == before_typed,
		"'%s' -> '%s'" % [before_typed, game.typed])
	_expect("the phase survives", game.phase == before_phase)
	_expect("the score survives", game.player.score == before_score)
	_check_layout(to_name)

	# And back again: the layout is a function of the pose, not of the history.
	var back: Dictionary = Poses.POSES[pose_name]
	stage.size = back["px"]
	stage.size_2d_override = back["units"]
	Poses.apply(game, back)
	game._layout_boards()
	await process_frame
	print("--- and back to %s ---" % pose_name)
	_check_layout(pose_name)


# --- classification -------------------------------------------------------


## The size class and the composition, from the numbers Apple publishes. Run
## against `classify_device`, which is `_measure_device` without the window.
func _classify() -> void:
	print("--- size classes from panel numbers ---")
	var G: Object = load("res://scripts/game.gd")
	var portrait := Vector2i(720, 1440)
	var landscape := Vector2i(1280, 720)
	# [name, window px, design space, scale, regular?, tablet?]
	var cases := [
		["iPhone 15, portrait", Vector2i(1179, 2556), portrait, 3.0, false, false],
		["iPhone 17 Pro Max, portrait", Vector2i(1320, 2868), portrait, 3.0, false, false],
		["iPhone 17 Pro Max, landscape", Vector2i(2868, 1320), landscape, 3.0, false, true],
		["Duo cover, portrait", Vector2i(1398, 2034), portrait, 3.0, false, true],
		["Duo cover, landscape", Vector2i(2034, 1398), landscape, 3.0, false, true],
		["Duo open, portrait (render size)", Vector2i(2007, 2853), portrait, 3.0, true, true],
		["Duo open, landscape (render size)", Vector2i(2853, 2007), landscape, 3.0, true, true],
		["Duo open, portrait (panel size)", Vector2i(1878, 2670), portrait, 2.807, true, true],
		["iPad mini, portrait", Vector2i(1488, 2266), portrait, 2.0, true, true],
		["iPad Air, portrait", Vector2i(1640, 2360), portrait, 2.0, true, true],
		["iPad Pro 13, landscape", Vector2i(2752, 2064), landscape, 2.0, true, true],
	]
	for c: Array in cases:
		var got: Dictionary = G.classify_device(c[1], c[2], float(c[3]), true)
		_expect("%s: %s%s" % [c[0], "regular" if c[4] else "compact",
				", tablet-shaped" if c[5] else ", phone-shaped"],
			bool(got["regular"]) == bool(c[4]) and bool(got["tablet"]) == bool(c[5]),
			"got regular=%s tablet=%s" % [got["regular"], got["tablet"]])

	# The two that the old single threshold could not tell apart.
	var cover: Dictionary = G.classify_device(Vector2i(1398, 2034), portrait, 3.0, true)
	var ipad: Dictionary = G.classify_device(Vector2i(1640, 2360), portrait, 2.0, true)
	_expect("a cover display and an iPad share a shape and not a class",
		bool(cover["tablet"]) == bool(ipad["tablet"]) \
			and bool(cover["regular"]) != bool(ipad["regular"]))

	# No fingers, no points: a desktop is as roomy as it looks.
	var desk: Dictionary = G.classify_device(Vector2i(1280, 720), landscape, 1.0, false)
	_expect("a desktop window is regular where it is wide", bool(desk["regular"]))


## The path from a line the native bridge writes to a crease the layout stays off.
func _hinge() -> void:
	print("--- hinge file to fold ---")
	await _boot(Poses.POSES["inner-landscape"])
	game.fold = Rect2()
	game._hinge_partial = false
	var path := OS.get_cache_dir().path_join(game.HINGE_FILE)
	var prefs: Dictionary = get_root().get_node("Profile").prefs

	# [text written, partly open?, what it is]. The status number is whatever the
	# system's enum is, so no case is allowed to depend on it.
	var cases := [
		["2 1.96", true, "112 degrees, one status numbering"],
		["1 1.96", true, "112 degrees, another status numbering"],
		["2 3.14", false, "flat"],
		["1 0.00", false, "shut, whatever the status says"],
		["9 1.50", true, "an unknown status, but plainly bent"],
		["9 0.05", false, "an unknown status, nearly shut"],
		["2 2.85", false, "163 degrees, flat enough"],
		["2 0.30", false, "17 degrees, shut enough"],
		["", false, "an empty file"],
	]
	for c: Array in cases:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(String(c[0]))
		f.close()
		# `get_modified_time` has one-second resolution, so a second write inside
		# the same second would not be seen. The poll is not meant to catch two
		# writes in a second — the bridge writes on change, and a hinge does not
		# change that fast — so the test resets what it remembers instead.
		game._hinge_stamp = -1
		game._hinge_age = 10.0
		game._poll_hinge(1.0)
		var got: bool = game.fold.has_area()
		_expect("%s -> %s" % [c[2], "a crease" if c[1] else "no crease"],
			got == bool(c[1]), "fold=%s" % game.fold)

	# With the setting off the layout never moves, whatever the hinge says.
	prefs["fold_layout"] = false
	var f2 := FileAccess.open(path, FileAccess.WRITE)
	f2.store_string("1 1.96")
	f2.close()
	game._hinge_stamp = -1
	game._hinge_age = 10.0
	game._poll_hinge(1.0)
	_expect("the setting switches it off", not game.fold.has_area())
	prefs["fold_layout"] = true

	# The crease is a function of the glass: across a tall one, down a wide one.
	var tall: Rect2 = game.fold_band(Vector2(1013, 1440))
	var wide: Rect2 = game.fold_band(Vector2(1280, 900))
	_expect("a tall glass is creased across its middle",
		tall.size.x == 1013.0 and absf(tall.get_center().y - 720.0) < 0.5)
	_expect("a wide glass is creased down its middle",
		wide.size.y == 900.0 and absf(wide.get_center().x - 640.0) < 0.5)
	DirAccess.remove_absolute(path)
	await process_frame


func _expect(what: String, ok: bool, detail := "") -> void:
	if not ok:
		fails += 1
	print("  %-66s %s%s" % [what, "ok" if ok else "FAILED",
		"" if ok or detail == "" else "  [%s]" % detail])
