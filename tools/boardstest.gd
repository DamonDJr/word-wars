extends SceneTree
## The board screen, measured rather than looked at.
##
## Nothing here can reach Game Center — this runs on Linux, where the plugin is
## a stub that refuses to instantiate — so the rows are injected straight into
## `Boards` and what gets checked is the screen built on top of them. That is
## the half that can be wrong on a device and look right on a desk: a list of
## twenty-five in a window that holds eight, buttons underneath rows that ran
## past them, a tab that asks for the wrong board.
##
## The failure this exists for is landscape. `_scrollable` is portrait-only
## across the whole game, so a landscape board has no way to reach anything the
## list pushes off the bottom — including the button that leaves the screen.
##
##   godot --headless --script tools/boardstest.gd

var game: Node
var boards: Node
var stage: SubViewport
var fails := 0


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-58s %s" % [what, "ok" if ok else "FAILED"])


func _orient(tall: bool) -> void:
	stage.size = game.PORTRAIT_SIZE if tall else game.LANDSCAPE_SIZE
	game.portrait = tall


## A page of rows, and the local player a long way below it.
func _fill(n: int) -> void:
	var rows: Array = []
	for i in n:
		rows.append({"rank": i + 1, "name": "Player %d" % (i + 1),
			"score": 40000 - i * 900, "me": false})
	boards.view_rows = rows
	boards.view_me = {"rank": 412, "name": "you", "score": 9180, "me": true}
	boards.view_total = 9120
	boards.view_state = boards.ViewState.READY


func _init() -> void:
	await process_frame
	boards = get_root().get_node("Boards")
	game = load("res://scenes/main.tscn").instantiate()
	stage = SubViewport.new()
	stage.size = Vector2i(1280, 720)
	get_root().add_child(stage)
	stage.add_child(game)
	await process_frame
	await process_frame
	game.phase = game.Phase.BOARDS

	_the_top_is_a_different_place()
	_it_says_what_the_climb_costs()
	_the_list_fits_the_window()
	_nothing_lands_on_the_list()
	_the_tabs_ask_for_the_right_board()
	_every_button_goes_somewhere()
	_an_empty_board_says_why()
	_a_row_always_has_a_name()

	print("--- %s ---" % ("the board screen holds up" if fails == 0
		else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)


## A leaderboard whose rows are all the same is a table, and a table is a thing
## you read rather than a thing you want to be on.
func _the_top_is_a_different_place() -> void:
	print("--- the top three are drawn as the top three ---")
	_orient(true)
	var ordinary: float = game._boards_rank_h(9)
	_expect("first is the tallest row (%.0f > %.0f)" % [
		game._boards_rank_h(1), game._boards_rank_h(2)],
		game._boards_rank_h(1) > game._boards_rank_h(2))
	_expect("second and third are still above the rest",
		game._boards_rank_h(3) > ordinary)
	_expect("and the fourth is an ordinary row",
		is_equal_approx(game._boards_rank_h(4), ordinary))

	var tints := {}
	for rank in [1, 2, 3, 4]:
		tints[game._boards_rank_tint(rank)] = true
	_expect("gold, silver and bronze are three distinct colours",
		tints.size() == 4)

	# The phone scale is the whole reason this screen was rebuilt: it shipped at
	# landscape sizes and read as a spreadsheet.
	_orient(false)
	var land: float = game._boards_row_h()
	var land_type: int = game._boards_size(14)
	_orient(true)
	_expect("rows are taller in portrait (%.0f -> %.0f)" % [
		land, game._boards_row_h()], game._boards_row_h() > land)
	_expect("and the type grows with them (%d -> %d)" % [
		land_type, game._boards_size(14)], game._boards_size(14) > land_type)


## The line that turns a verdict into a target.
func _it_says_what_the_climb_costs() -> void:
	print("--- and it says what the next place would cost ---")
	_orient(true)
	_fill(10)

	# Off the page: the bottom of it is the nearest score Apple actually sent,
	# so the honest target is the page rather than a rank.
	boards.view_me = {"rank": 412, "name": "you", "score": 100, "me": true}
	var far: String = game._boards_climb()
	_expect("off the page it aims at the page — %s" % far,
		far.contains("top 10"))

	# On the page: the row directly above is a real player with a real score,
	# and that gap is usually one good word. This is the version worth having.
	boards.view_me = {}
	var rows: Array = boards.view_rows
	(rows[4] as Dictionary)["me"] = true
	var near: String = game._boards_climb()
	var gap: int = int((rows[3] as Dictionary)["score"]) \
		- int((rows[4] as Dictionary)["score"])
	_expect("on the page it aims at the row above — %s" % near,
		near.contains("#4") and near.contains(str(gap)))

	# Top of the board has nothing above it, and must not print a gap of zero.
	(rows[4] as Dictionary)["me"] = false
	(rows[0] as Dictionary)["me"] = true
	var top: String = game._boards_climb()
	_expect("the leader is told so instead — %s" % top,
		top != "" and not top.contains("#0"))
	(rows[0] as Dictionary)["me"] = false

	# And with nobody's row on screen at all there is nothing to say.
	boards.view_me = {}
	_expect("a board you are not on says nothing", game._boards_climb() == "")


func _the_list_fits_the_window() -> void:
	print("--- the list is cut to the window that cannot scroll ---")
	_fill(boards.VIEW_ROWS)

	_orient(true)
	_expect("portrait scrolls, so it draws all %d" % boards.VIEW_ROWS,
		game._boards_fit() == boards.VIEW_ROWS)

	_orient(false)
	var fit: int = game._boards_fit()
	_expect("landscape cuts the list (%d of %d)" % [fit, boards.VIEW_ROWS],
		fit > 0 and fit < boards.VIEW_ROWS)
	# The point of cutting it: everything the screen draws stays on the screen.
	var bottom: float = game._boards_foot() + game._boards_buttons_h()
	_expect("and everything still fits above %d (%.0f)" % [
		int(stage.size.y), bottom], bottom <= float(stage.size.y))

	# A board with three people on it must not be padded out to the cap.
	_fill(3)
	_expect("a short board draws exactly what it has",
		game._boards_fit() == 3)
	_orient(true)


func _nothing_lands_on_the_list() -> void:
	print("--- and no button sits on top of a row ---")
	for tall in [true, false]:
		_orient(tall)
		var where := "portrait" if tall else "landscape"
		for n in [0, 3, boards.VIEW_ROWS]:
			if n == 0:
				boards.view_rows = []
				boards.view_me = {}
				boards.view_state = boards.ViewState.EMPTY
			else:
				_fill(n)
			var foot: float = game._boards_foot()
			var clash := ""
			for b: Dictionary in game._menu_buttons():
				var r: Rect2 = b["rect"]
				# The tabs live above the list by design; only the block under
				# it is being checked for landing on the rows.
				if String(b["action"]).begins_with("btab:") \
						or String(b["action"]).begins_with("bscope:"):
					continue
				if r.position.y < foot:
					clash = String(b["action"])
			_expect("%s, %d rows: nothing under the list overlaps it%s" % [
				where, n, "" if clash == "" else " — " + clash], clash == "")
	_orient(true)


func _the_tabs_ask_for_the_right_board() -> void:
	print("--- each tab asks Apple for what it says ---")
	var was_tab: int = game.board_tab
	var was_scope: int = game.board_scope

	game.board_tab = 0
	_expect("DAILY reads the daily board", game._board_id() == boards.DAILY_ID)
	# Filtered to today, because a daily board that showed every day ever would
	# rank this morning's run against an all-time best and never move again.
	_expect("and asks for today only", game._board_time() == boards.TODAY)

	game.board_tab = 1
	_expect("SURVIVAL reads the survival board",
		game._board_id() == boards.SURVIVAL_ID)
	# The opposite, and for the opposite reason: survival is a lifetime best, so
	# filtering it to today empties it for anybody who last played yesterday.
	_expect("and asks for all time", game._board_time() == boards.ALL_TIME)

	_expect("the two boards are not the same id",
		boards.DAILY_ID != boards.SURVIVAL_ID)

	game.board_tab = was_tab
	game.board_scope = was_scope


func _every_button_goes_somewhere() -> void:
	print("--- and every button on the screen is handled ---")
	# `_activate` is a chain of `elif`s on a string. A button whose action is not
	# in it is a control that draws, highlights, plays its tap and does nothing —
	# which is indistinguishable from the game being slow.
	var src: String = FileAccess.get_file_as_string("res://scripts/game.gd")
	_fill(5)
	for tall in [true, false]:
		_orient(tall)
		for b: Dictionary in game._menu_buttons():
			var act := String(b["action"])
			var handled := false
			if act.contains(":"):
				# Prefixed actions are matched by `begins_with` in `_activate`.
				handled = src.contains('begins_with("%s:")'
					% act.split(":")[0])
			else:
				handled = src.contains('action == "%s"' % act)
			_expect("%s is handled by _activate" % act, handled)

	# The two that never appear here. `Boards.available()` and
	# `challenges_available()` are both false on Linux, so the loop above cannot
	# reach the challenges door or the way out to Apple's screen — which makes
	# them exactly the buttons that could rot unnoticed until a device build.
	for act2 in ["challenges", "gcboard"]:
		_expect("%s is handled by _activate" % act2,
			src.contains('action == "%s"' % act2))
	_orient(true)


func _an_empty_board_says_why() -> void:
	print("--- an empty board says which kind of empty it is ---")
	boards.view_rows = []
	boards.view_me = {}
	boards.view_total = 0

	var said := {}
	for state in [boards.ViewState.OFF, boards.ViewState.LOADING,
			boards.ViewState.FAILED, boards.ViewState.EMPTY]:
		boards.view_state = state
		boards.view_status = "Game Center: refused"
		var msg: String = game._boards_message()
		_expect("state %d says something" % state, msg.strip_edges() != "")
		said[msg] = true
	# Four causes, four sentences. A shared one would send somebody who is not
	# signed in looking for a problem with the board.
	_expect("and no two states say the same thing", said.size() == 4)

	# The friends tab has its own, because "nobody has played this" is wrong
	# when what happened is that you have no friends on it.
	boards.view_state = boards.ViewState.EMPTY
	var was: int = game.board_scope
	game.board_scope = boards.GLOBAL
	var global_msg: String = game._boards_message()
	game.board_scope = boards.FRIENDS
	_expect("an empty friends board reads differently from a global one",
		game._boards_message() != global_msg)
	game.board_scope = was


func _a_row_always_has_a_name() -> void:
	print("--- and a row always has a name against the score ---")
	# `_view_row` is what turns Apple's entry into something drawable, and its
	# whole job is that a blank `display_name` — which is what a player who never
	# set one has — does not reach the screen as a gap beside a score.
	var named := _entry(4, 1200, "Vex", "vex99", "AAA")
	var row: Dictionary = boards._view_row(named, "BBB")
	_expect("a display name is used", String(row["name"]) == "Vex")
	_expect("and somebody else is not me", not bool(row["me"]))

	var aliased := _entry(5, 900, "   ", "fallback", "AAA")
	_expect("a blank display name falls back to the alias",
		String(boards._view_row(aliased, "BBB")["name"]) == "fallback")

	var nameless := _entry(6, 800, "", "", "AAA")
	_expect("and a player with neither still draws something",
		String(boards._view_row(nameless, "BBB")["name"]).strip_edges() != "")

	var mine: Dictionary = boards._view_row(named, "AAA")
	_expect("the local player is marked", bool(mine["me"]))

	# An id that is empty on both sides is two different anonymous players, not
	# one — matching them would paint somebody else's row as yours.
	var anon := _entry(7, 700, "Ghost", "", "")
	_expect("two blank ids are not the same player",
		not bool(boards._view_row(anon, "")["me"]))

	for made in _made:
		made.free()
	_made.clear()


## Stand-ins for `GKLeaderboardEntry` and `GKPlayer`, built once. `_view_row` is
## untyped and reads four fields, so a plain object carrying those fields is
## indistinguishable from the real thing — which is the only way to exercise it
## anywhere but a signed-in Apple device.
var _made: Array[Object] = []
var _player_script: GDScript
var _entry_script: GDScript


func _entry(rank: int, score: int, display: String, alias: String,
		id: String) -> Object:
	if _player_script == null:
		_player_script = GDScript.new()
		_player_script.source_code = "extends Object\nvar display_name := \"\"\n" \
			+ "var alias := \"\"\nvar game_player_id := \"\"\n"
		_player_script.reload()
		_entry_script = GDScript.new()
		_entry_script.source_code = "extends Object\nvar rank := 0\n" \
			+ "var score := 0\nvar player = null\n"
		_entry_script.reload()

	var player: Object = _player_script.new()
	player.display_name = display
	player.alias = alias
	player.game_player_id = id
	var e: Object = _entry_script.new()
	e.rank = rank
	e.score = score
	e.player = player
	_made.append(player)
	_made.append(e)
	return e
