extends SceneTree
## The versus screen is a layout that predicts itself, which is the interesting
## way for it to break.
##
## `_versus_laid` cannot measure the rects it lays out: those rects ask
## `_menu_offset` where the screen starts, and `_menu_offset` asks `_versus_laid`
## how tall it is. So the height is *predicted* — how many rows two doors will
## wrap to, how many rows a list of friends will take — and a prediction that
## disagrees with `_grid_rects` is a screen that scrolls to the wrong place, or
## stops scrolling before its last row. Nothing about that looks wrong until
## somebody cannot reach the bottom of their friend list on a phone.
##
## So the prediction is checked against the grid itself, at both design sizes,
## and every button is clicked at its own centre to prove that what is drawn and
## what is hit-tested are the same screen.
##
## Two things here are only real on a device, and are checked by `gctest.gd`
## against the plugin's registration instead: `GKPlayer` refuses to instantiate
## on the Linux stub, so the picker is exercised at zero friends, and
## `available()` is false, so the doors are exercised by the shape of the screen
## rather than by a live Game Center.
##
##   godot --headless --script tools/versustest.gd

var game: Node
var mm: Node
## The headless display server will not go narrower than 1280, and `portrait` is
## decided by the window — so the phone's 720-wide design space only exists if we
## build one. `_grid_rects` measures whatever viewport its node sits under, which
## makes a SubViewport a real test of the wrap rules rather than a re-derivation
## of them in the test.
var stage: SubViewport
var fails := 0


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-56s %s" % [what, "ok" if ok else "FAILED"])


## How many distinct rows a grid actually came back as.
func _rows_in(rects: Array) -> int:
	var tops: Array = []
	for r: Rect2 in rects:
		if not tops.has(r.position.y):
			tops.append(r.position.y)
	return tops.size()


func _orient(tall: bool) -> void:
	stage.size = game.PORTRAIT_SIZE if tall else game.LANDSCAPE_SIZE
	game.portrait = tall


## Everything on the screen has to be clickable where it is drawn, and the doors
## have to come with as many rects as there are doors.
func _reachable(where: String) -> void:
	var doors: Array = game._versus_doors()
	var rects: Array = game._versus_door_rects()
	_expect("%s: %d doors, %d rects" % [where, doors.size(), rects.size()],
		doors.size() == rects.size())

	var stray := ""
	for b: Dictionary in game._menu_buttons():
		var hit: String = game._action_at((b["rect"] as Rect2).get_center())
		if hit != String(b["action"]):
			stray = "%s hit %s" % [String(b["action"]), hit if hit != "" else "nothing"]
	for c: Dictionary in game._versus_friend_cards():
		var hit2: String = game._action_at((c["rect"] as Rect2).get_center())
		if hit2 != String(c["action"]):
			stray = "%s hit %s" % [String(c["action"]), hit2 if hit2 != "" else "nothing"]
	_expect("%s: every button is where it is drawn%s" % [
		where, "" if stray == "" else " — " + stray], stray == "")


## The drawer has four states and only one of them is a list. The other three
## are a sentence and a way to ask again, and each has to lay out.
func _sweep(label: String) -> void:
	game.versus_inviting = false
	_reachable("%s closed" % label)
	game.versus_inviting = true
	for st in [mm.Friends.UNASKED, mm.Friends.LOADING, mm.Friends.DENIED,
			mm.Friends.EMPTY, mm.Friends.READY]:
		mm.friends_state = st
		_reachable("%s open/%s" % [label, String(mm.Friends.keys()[st]).to_lower()])
		_expect("%s open/%s: measured taller than shut" % [
			label, String(mm.Friends.keys()[st]).to_lower()],
			game._versus_laid() > 0.0 and game._versus_foot() > 0.0)
	game.versus_inviting = false
	mm.friends_state = mm.Friends.UNASKED


## The heights `_versus_laid` guesses at, against the grid that will lay them out.
func _prediction_matches_the_grid() -> void:
	print("--- the predicted row counts are the grid's ---")
	for tall in [false, true]:
		_orient(tall)
		var where := "portrait" if tall else "landscape"
		for n in [1, 2]:
			var real := _rows_in(game._grid_rects(n, 0.0, 2, 320.0, 104.0, 20.0,
				340.0, 16.0))
			var guess: int = n if tall else int(ceil(float(n) * 0.5))
			_expect("%s: %d doors lay out in %d rows" % [where, n, real],
				real == guess)
		for n2 in [1, 5, 12]:
			var cols: int = game._versus_friend_cols()
			var real2 := _rows_in(game._grid_rects(n2, 0.0, cols, 340.0,
				game._versus_row_h(), 12.0, 0.0, 10.0))
			var guess2: int = int(ceil(float(n2) / float(cols)))
			_expect("%s: %d friends lay out in %d rows" % [where, n2, real2],
				real2 == guess2)
	_orient(false)


## The doors are a toggle, a search and a way out of one, and none of them may
## leave the screen somewhere it cannot come back from.
func _doors_do_what_they_say() -> void:
	print("--- the doors ---")
	game._activate("versus")
	_expect("versus opens the screen", game.phase == game.Phase.VERSUS)

	game._activate("invite")
	_expect("invite opens the drawer", game.versus_inviting)
	_expect("and asks Game Center for the list",
		mm.friends_state != mm.Friends.UNASKED)
	game._activate("invite")
	_expect("invite shuts it again", not game.versus_inviting)

	# Every one of these is a no-op with Game Center switched off, and a no-op is
	# what they have to be — not an error, and not a screen with no way out.
	game._activate("quick_match")
	game._activate("friends_refresh")
	# A name that is not in the list any more must be refused, not rounded to
	# whoever is nearest.
	game._activate("invite:not-a-real-player-id")
	game._activate("versus_stop")
	_expect("none of them leave the versus screen",
		game.phase == game.Phase.VERSUS)

	game.versus_inviting = true
	_expect("back shuts the drawer before the screen",
		game._back_action() == "invite" or not mm.available())
	game._activate("title")
	_expect("title leaves", game.phase == game.Phase.TITLE)
	_expect("and shuts the drawer behind it", not game.versus_inviting)


## Rematch asks the opponent you already have. The button must therefore exist
## only while there is one — and with Game Center off, `net_active()` is false,
## which is exactly the "they left" case the summary screen has to survive.
func _rematch_button_follows_the_opponent() -> void:
	print("--- rematch ---")
	game.phase = game.Phase.OVER
	game.mode = game.Mode.NORMAL

	game.difficulty = "Versus"
	_expect("a versus match with nobody left cannot rematch",
		not game._rematch_possible())
	var gone: Array = game._menu_buttons()
	var acts: PackedStringArray = []
	for b: Dictionary in gone:
		acts.append(String(b["action"]))
	_expect("so the summary offers only Title (%s)" % ", ".join(acts),
		not acts.has("rematch") and acts.has("title"))

	# A CPU match has nobody to ask and can always be re-run, so the button stays.
	game.difficulty = "Rookie"
	_expect("a CPU match can always go again", game._rematch_possible())
	var acts2: PackedStringArray = []
	for b2: Dictionary in game._menu_buttons():
		acts2.append(String(b2["action"]))
	_expect("so the summary keeps Rematch (%s)" % ", ".join(acts2),
		acts2.has("rematch"))

	# The card is only ever raised for a request that arrived, and only while
	# there is still somebody on the other end of it.
	game.phase = game.Phase.OVER
	game.rematch_offered = true
	game.rematch_asked = false
	game.difficulty = "Versus"
	_expect("no card once the opponent has gone", not game._rematch_popup())
	game.difficulty = "Rookie"
	_expect("nor for a CPU match that never asked", not game._rematch_popup())
	game.rematch_offered = false

	# The negotiation flags must never outlive the match they belong to.
	game.rematch_asked = true
	game.rematch_offered = true
	game.start_match("Rookie", 1)
	_expect("starting a match clears a stale ask",
		not game.rematch_asked and not game.rematch_offered)

	# Leaving cancels: the flags go, so the peer is not left being told that
	# somebody who is back at the title screen still wants another game.
	game.phase = game.Phase.OVER
	game.rematch_asked = true
	game._activate("title")
	_expect("leaving to title cancels the ask",
		not game.rematch_asked and not game.rematch_offered)
	_expect("and lands on the title screen", game.phase == game.Phase.TITLE)


## The summary was built in the landscape design space. Its foot is measured
## rather than drawn, so if the rows grow and the measurement does not, the
## buttons end up underneath the table.
func _summary_grows_for_a_phone() -> void:
	print("--- the summary fits a phone ---")
	game.phase = game.Phase.OVER
	game.mode = game.Mode.NORMAL
	game.difficulty = "Rookie"
	game.win_spoils = 0

	_orient(false)
	var land_row: float = game._score_row_h()
	var land_foot: float = game._over_foot()
	_orient(true)
	var tall_row: float = game._score_row_h()
	var tall_foot: float = game._over_foot()
	_expect("rows are taller in portrait (%.0f -> %.0f)" % [land_row, tall_row],
		tall_row > land_row)
	_expect("and the foot moves down with them (%.0f -> %.0f)" % [
		land_foot, tall_foot], tall_foot > land_foot)

	# The buttons hang off the foot, so they must clear the last row.
	var rows: int = max(1, game._scoreboard_sides().size())
	var last_row_bottom: float = game._scoreboard_top() \
		+ game.SCORE_HEAD_H * game._over_fill() \
		+ float(rows) * (game._score_row_h() + 6.0)
	_expect("buttons start below the last row (%.0f >= %.0f)" % [
		tall_foot, last_row_bottom], tall_foot >= last_row_bottom)

	# A win pushes the table down to make room for the reconciliation line.
	var plain: float = game._scoreboard_top()
	game.win_spoils = 1650
	_expect("a win bonus makes room above the table (%.0f -> %.0f)" % [
		plain, game._scoreboard_top()], game._scoreboard_top() > plain)
	game.win_spoils = 0

	_expect("WPM is a column in both orientations",
		game._scoreboard_cols().has("WPM"))
	_orient(false)
	_expect("and in landscape too", game._scoreboard_cols().has("WPM"))
	game.phase = game.Phase.TITLE


func _init() -> void:
	await process_frame
	mm = root.get_node("MultiplayerManager")
	# `--script` boots the autoloads but not the main scene, so put it up by hand.
	game = load("res://scenes/main.tscn").instantiate()
	stage = SubViewport.new()
	stage.size = Vector2i(1280, 720)
	root.add_child(stage)
	stage.add_child(game)
	await process_frame
	await process_frame

	# Off the real save, onto one of our own. This screen drives `_activate` on a
	# finished match, and two of the things that hang off that — banking the
	# record, counting matches towards an ad break — write whatever profile is
	# loaded. Left alone it was the developer's own, which is how a run of the
	# test suite quietly added matches to somebody's career; and once a break
	# could be due, "title leaves" started depending on how many matches the
	# machine running the test had played.
	var P := root.get_node("Profile")
	P.save_path = "user://profile-versus-test.cfg"
	P.owned = {}
	P.since_ad = 0
	P.ad_gap = P.ADS_EVERY_MAX

	game._activate("versus")
	print("--- the screen holds together at both sizes ---")
	_orient(false)
	_sweep("landscape")
	_orient(true)
	_sweep("portrait")
	_orient(false)

	_prediction_matches_the_grid()
	_doors_do_what_they_say()
	_rematch_button_follows_the_opponent()
	_summary_grows_for_a_phone()

	print("--- what the screen says with Game Center off ---")
	print("  status: %s" % game._versus_state_line())
	print("  title:  %s" % game._versus_sub())

	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(P.save_path + suffix))
	print("--- %s ---" % ("the versus screen holds up" if fails == 0
		else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)
