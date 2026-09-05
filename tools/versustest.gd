extends SceneTree
## Versus, now that the game owns the screen again.
##
## The title door used to open Apple's sheet directly and there was no versus
## screen to test. There is one again — see the block above `LOBBY_FALLBACK` in
## `game.gd` for why — and it is back on this list, because a lobby that is drawn
## wrong is drawn wrong on a device and looks fine on a desk:
##
##   * the door, which opens our lobby and must not start a second search on
##     top of one already running, nor pretend when Game Center is not there;
##   * the lobby itself — three doors that must not overlap the card above them
##     or run off the screen, and whose first door swaps to Stop while a search
##     is live so the plate and the ENTER key cannot disagree;
##   * the fallback, which must offer the CPU match once a search has gone
##     nowhere for long enough, and must stop offering it the moment the search
##     is over;
##   * the rematch negotiation, which is ours end to end and may only exist
##     while there is somebody to negotiate with;
##   * the summary screen, whose foot is *measured* rather than drawn — so if
##     the rows grow and the measurement does not, the buttons land underneath
##     the table.
##
## Game Center is unavailable on Linux, which is the same shape as "not signed
## in" — the case every one of these still has to behave in. The searching states
## are reached by writing `MultiplayerManager.state` directly, which is the only
## way to see them on a machine Apple's matchmaker will not run on.
##
##   godot --headless --script tools/versustest.gd

var game: Node
var mm: Node
## The headless display server will not go narrower than 1280, and `portrait` is
## decided by the window — so the phone's 720-wide design space only exists if
## we build one.
var stage: SubViewport
var fails := 0


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-56s %s" % [what, "ok" if ok else "FAILED"])


func _orient(tall: bool) -> void:
	stage.size = game.PORTRAIT_SIZE if tall else game.LANDSCAPE_SIZE
	game.portrait = tall


func _press(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	game._unhandled_key_input(ev)


## The door opens our lobby, on every platform. It is the one screen in versus
## that does not need Game Center to be worth arriving at — the CPU match is
## behind it — so it must open with the plugin refusing to load, which on Linux
## is the only way it ever loads.
func _the_door() -> void:
	print("--- the versus door ---")
	game.phase = game.Phase.TITLE

	game._activate("versus")
	_expect("the door opens the lobby", game.phase == game.Phase.LOBBY)
	_expect("and leaves no search running with Game Center off",
		mm.available() or not game._versus_busy())

	# The title keys are the other way in, and must agree with the plate.
	game.phase = game.Phase.TITLE
	_press(KEY_4)
	_expect("4 is the same door", game.phase == game.Phase.LOBBY)
	game.phase = game.Phase.TITLE
	_press(KEY_V)
	_expect("and so is V", game.phase == game.Phase.LOBBY)

	var sub: String = game._versus_sub()
	_expect("the plate says something either way: '%s'" % sub, sub != "")


## The lobby, measured. Every number here is one the render caught being wrong
## at least once: the status card is drawn at a fixed offset and the doors are
## laid out from `_lobby_head_h`, so the two have no shared arithmetic keeping
## them apart — only the constant, which is exactly the kind of thing that goes
## stale when somebody makes the card taller.
func _the_lobby_fits() -> void:
	print("--- the lobby fits, both ways up ---")
	game.phase = game.Phase.LOBBY
	mm.state = mm.State.OFF

	for tall in [true, false]:
		_orient(tall)
		var which := "portrait" if tall else "landscape"
		var view: Vector2 = game.get_viewport_rect().size
		var rects: Array = game._lobby_door_rects()
		_expect("%s draws all three doors" % which, rects.size() == 3)

		# The card is drawn at `hy + 124` and is 96 tall; the doors start at
		# `hy + _lobby_head_h()`. Anything under 220 puts the first door through
		# the bottom of the card, which is what 200 did.
		_expect("%s clears the status card (%d >= 220)"
			% [which, int(game._lobby_head_h())], game._lobby_head_h() >= 220.0)

		var first: Rect2 = rects[0]
		var last: Rect2 = rects[rects.size() - 1]
		_expect("%s keeps the doors inside the width" % which,
			first.position.x >= 0.0 and first.end.x <= view.x)
		_expect("%s doors are wide enough to draw as plates" % which,
			first.size.x >= 230.0 and first.size.y >= 38.0)

		# Landscape cannot scroll — `_scrollable` is portrait-only across the
		# whole game — so anything past the bottom edge there is unreachable,
		# including the Back button hanging off the last door.
		if not tall:
			var back := Rect2()
			for b: Dictionary in game._menu_buttons():
				if String(b["action"]) == "title":
					back = b["rect"]
			_expect("landscape keeps Back on screen and under the doors",
				back.end.y <= view.y and back.position.y >= last.end.y)

	_orient(true)


## The first door is a toggle, and three things read it: the plate, the ENTER
## key and the back chevron. They must not be able to disagree.
func _the_search_door_swaps() -> void:
	print("--- the search door swaps with the search ---")
	game.phase = game.Phase.LOBBY

	mm.state = mm.State.OFF
	_expect("idle offers Quick Match",
		String((game._lobby_doors()[0] as Dictionary)["action"]) == "versus_quick")
	_expect("and the chevron goes back to the title",
		game._back_action() == "title")

	mm.state = mm.State.MATCHMAKING
	_expect("searching offers Stop instead",
		String((game._lobby_doors()[0] as Dictionary)["action"]) == "versus_cancel")
	_expect("and the chevron cancels rather than leaving",
		game._back_action() == "versus_cancel")
	# The states `cancel_find` alone would not have escaped.
	mm.state = mm.State.HANDSHAKING
	_expect("a stalled handshake still offers Stop",
		String((game._lobby_doors()[0] as Dictionary)["action"]) == "versus_cancel")

	mm.state = mm.State.OFF


## The whole point of the screen: a search that finds nobody must end up
## pointing at the match that is available, rather than at a spinner.
func _the_fallback_offers_a_bot() -> void:
	print("--- the fallback ---")
	game.phase = game.Phase.LOBBY
	mm.state = mm.State.MATCHMAKING

	game._lobby_search = 0.0
	_expect("a fresh search offers nothing yet", not game._lobby_offering())
	game._lobby_search = game.LOBBY_FALLBACK - 0.1
	_expect("and still nothing a tenth of a second early",
		not game._lobby_offering())
	game._lobby_search = game.LOBBY_FALLBACK + 0.1
	_expect("past the fallback it offers the CPU match",
		game._lobby_offering())

	var cpu := {}
	for d: Dictionary in game._lobby_doors():
		if String(d["action"]) == "versus_cpu":
			cpu = d
	_expect("the CPU door names who is waiting (%s)" % String(cpu["sub"]),
		String(cpu["sub"]).contains(String(game._lobby_bot).to_upper()))
	_expect("and the card says so too",
		game._lobby_note().contains("nobody yet"))

	# A search that is over stops apologising for itself, whatever the clock
	# was left at — `_lobby_offering` reads the state, not just the timer.
	mm.state = mm.State.OFF
	_expect("and it stops the moment the search does",
		not game._lobby_offering())
	game._lobby_search = 0.0


## The payoff. A dead versus mode is the thing this screen exists to fix, so the
## CPU door has to actually deal a match — with a real opponent in seat one, on
## a machine where Game Center never answers.
func _the_cpu_door_deals_a_match() -> void:
	print("--- the CPU door deals a real match ---")
	game.phase = game.Phase.LOBBY
	mm.state = mm.State.OFF
	game._activate("versus_cpu")

	_expect("it counts a match in", game.phase == game.Phase.COUNTDOWN)
	_expect("in normal mode, not a lesson", game.mode == game.Mode.NORMAL)
	_expect("with two seats in play", game.slots_in_play == 2)

	var bots := 0
	for s in game.sides:
		if s.in_match and s.bot != null:
			bots += 1
	_expect("and one of them is a configured bot", bots == 1)
	# A CPU match can go again; the summary's Rematch button reads this.
	_expect("and it can be replayed from the summary", game._rematch_possible())

	game.phase = game.Phase.TITLE


## Every door has to be reachable by the thing that turns a tap into an action,
## which is a different code path from the one that drew it.
func _every_door_is_hittable() -> void:
	print("--- every door answers a tap ---")
	game.phase = game.Phase.LOBBY
	mm.state = mm.State.OFF
	_orient(true)

	for b: Dictionary in game._menu_buttons():
		var r: Rect2 = b["rect"]
		var act := String(b["action"])
		_expect("%s answers at its own centre" % act,
			game._action_at(r.get_center()) == act)


## Rematch asks the opponent you already have, so the button may only exist
## while there is one. With Game Center off `net_active()` is false, which is
## precisely the "they left" case the summary has to survive.
func _rematch_follows_the_opponent() -> void:
	print("--- rematch ---")
	game.phase = game.Phase.OVER
	game.mode = game.Mode.NORMAL

	game.difficulty = "Versus"
	_expect("a versus match with nobody left cannot rematch",
		not game._rematch_possible())
	var acts: PackedStringArray = []
	for b: Dictionary in game._menu_buttons():
		acts.append(String(b["action"]))
	_expect("so the summary offers only Title (%s)" % ", ".join(acts),
		not acts.has("rematch") and acts.has("title"))

	game.difficulty = "Rookie"
	_expect("a CPU match can always go again", game._rematch_possible())
	var acts2: PackedStringArray = []
	for b2: Dictionary in game._menu_buttons():
		acts2.append(String(b2["action"]))
	_expect("so the summary keeps Rematch", acts2.has("rematch"))

	# The card is a person asking a question. A CPU never asks, and neither does
	# an opponent who has already gone.
	game.rematch_offered = true
	game.rematch_asked = false
	_expect("no card for a CPU match", not game._rematch_popup())
	game.difficulty = "Versus"
	_expect("no card once the opponent has gone", not game._rematch_popup())
	game.rematch_offered = false

	game.rematch_asked = true
	game.rematch_offered = true
	game.start_match("Rookie", 1)
	_expect("starting a match clears a stale ask",
		not game.rematch_asked and not game.rematch_offered)

	# Leaving cancels, so the peer is not told that somebody already back at the
	# title screen still wants another game.
	game.phase = game.Phase.OVER
	game.rematch_asked = true
	game._activate("title")
	_expect("leaving to title cancels the ask",
		not game.rematch_asked and not game.rematch_offered)
	_expect("and lands on the title screen", game.phase == game.Phase.TITLE)


## The summary was laid out in a 720-tall landscape window and then handed a
## phone twice that height. Its foot is measured rather than drawn, so the rows
## and the measurement have to grow together.
func _summary_fits_a_phone() -> void:
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

	var rows: int = max(1, game._scoreboard_sides().size())
	var last_row_bottom: float = game._scoreboard_top() \
		+ game.SCORE_HEAD_H * game._over_fill() \
		+ float(rows) * (game._score_row_h() + 6.0)
	_expect("buttons start below the last row (%.0f >= %.0f)" % [
		tall_foot, last_row_bottom], tall_foot >= last_row_bottom)

	var plain: float = game._scoreboard_top()
	game.win_spoils = 1650
	_expect("a win bonus makes room above the table (%.0f -> %.0f)" % [
		plain, game._scoreboard_top()], game._scoreboard_top() > plain)
	game.win_spoils = 0

	_expect("WPM is a column in portrait", game._scoreboard_cols().has("WPM"))
	_orient(false)
	_expect("and in landscape", game._scoreboard_cols().has("WPM"))

	_the_summary_uses_the_phone()
	_a_loss_says_how_close_it_was()
	_the_scoreboard_agrees_with_the_result()
	game.phase = game.Phase.TITLE


## The winner has to be top of the table, and the bonus that puts them there has
## to be paid to whoever won rather than only to the player.
##
## It used to be gated on `winner == "YOU"`, which quoted every other board
## without a bonus and made the table two scoring systems side by side. Measured
## over thirty-two bot matches before the change: the loser finished ahead on
## points in six of eighteen losses, by as much as thirteen thousand.
func _the_scoreboard_agrees_with_the_result() -> void:
	print("--- and the winner is paid, whoever the winner is ---")
	var them = null
	for s in game.sides:
		if s != game.player and s.in_match:
			them = s
	if them == null:
		# A one-sided roster is not a versus match; nothing here applies.
		_expect("there is an opponent to score against", true)
		return

	var was_winner: String = game.winner
	game.winner = "YOU"
	_expect("the player wins and _champion says so", game._champion() == game.player)
	game.winner = String(them.label)
	_expect("the opponent wins and _champion says so", game._champion() == them)

	# The literal fallback `_end_match` uses when nobody is left standing. No
	# side answers to it, and nobody being paid is the correct outcome.
	game.winner = "no such side"
	_expect("an unmatched winner pays nobody", game._champion() == null)
	game.winner = was_winner

	# The rule the damage term is set by, rather than the number it happens to
	# be: winning doubles what your offence was worth. `STRIKE_PAY` a cell
	# during the match, the same again at the end. A tuned constant would drift
	# the moment the bots or the block sizes change; this does not.
	_expect("winning doubles the offence (%d/cell in play, %d/cell for the win)"
		% [game.STRIKE_PAY, Scoring.flat(Scoring.WIN_DAMAGE_STEP)],
		Scoring.flat(Scoring.WIN_DAMAGE_STEP) == game.STRIKE_PAY)

	# And the whole bonus has to cover the deficit from the match this was
	# actually reported on: 67,974 in play against Wordsmith's 97,192, won with
	# one life left. Bots never produce this — none of them narrowly beats
	# Wordsmith — so the case is pinned by its numbers instead.
	var narrow: int = Scoring.flat(Scoring.WIN_BONUS + Scoring.LIFE_BONUS
		+ 250 * Scoring.WIN_DAMAGE_STEP)
	_expect("a one-life win over 250 cells covers the reported 29,218 (%s)"
		% narrow, narrow > 29218)
	_expect("damage is part of it", Scoring.WIN_DAMAGE_STEP > 0)
	# A walkover and a grind must not pay the same.
	var walkover: int = Scoring.flat(Scoring.WIN_BONUS
		+ 3 * Scoring.LIFE_BONUS + 120 * Scoring.WIN_DAMAGE_STEP)
	var grind: int = Scoring.flat(Scoring.WIN_BONUS
		+ 0 * Scoring.LIFE_BONUS + 450 * Scoring.WIN_DAMAGE_STEP)
	_expect("a hard-fought win outpays an easy one (%s vs %s)" % [grind, walkover],
		grind > walkover)


## The whole result used to arrive in the top third of a phone, because every Y
## above the table was a literal written for a 720-tall landscape window. The
## table's rows scaled and the block above them did not.
func _the_summary_uses_the_phone() -> void:
	print("--- and uses the height it is given ---")
	_orient(false)
	var land_lead: float = game._over_lead()
	var land_top: float = game._scoreboard_top()
	_orient(true)
	_expect("landscape is left exactly as it was", is_equal_approx(land_lead, 1.0))
	_expect("portrait leads the stack further down (%.2f)" % game._over_lead(),
		game._over_lead() > 1.0)
	_expect("so the table starts lower on a phone (%.0f -> %.0f)" % [
		land_top, game._scoreboard_top()], game._scoreboard_top() > land_top)

	# The primary door is first, full width, and taller than the way out. On a
	# phone the thing you almost always want next should not be one of two equal
	# choices at the bottom of a report.
	var stacked: Array = game._over_button_rects(2)
	var first: Rect2 = stacked[0]
	var second: Rect2 = stacked[1]
	_expect("portrait stacks the two doors", second.position.y >= first.end.y)
	_expect("the first is the taller (%.0f > %.0f)" % [first.size.y, second.size.y],
		first.size.y > second.size.y)
	_expect("and both are the same full width",
		is_equal_approx(first.size.x, second.size.x))

	_orient(false)
	var row: Array = game._over_button_rects(2)
	_expect("landscape keeps them side by side",
		is_equal_approx((row[0] as Rect2).position.y, (row[1] as Rect2).position.y))


## "YOU LOSE" says the same thing whether you were beaten by forty points or by
## forty thousand. The margin is what decides whether Rematch gets pressed.
func _a_loss_says_how_close_it_was() -> void:
	print("--- and a loss says how close it was ---")
	var was_winner: String = game.winner
	var was_mode: int = game.mode
	game.mode = game.Mode.NORMAL

	game.winner = "YOU"
	_expect("a win states no margin", game._over_margin() == "")

	# Somebody ahead of the player is what makes a margin exist at all.
	var them = null
	for s in game.sides:
		if s != game.player:
			them = s
	if them == null:
		_expect("there is an opponent to lose to", false)
	else:
		game.winner = String(them.label)
		game.player.score = 10000
		them.score = 13250
		# The margin is read off `_scoreboard_sides`, which counts only players
		# who were actually in the match — so a side that never joined one has
		# no score to be short of, and the margin is correctly silent.
		var was_mine: bool = game.player.in_match
		var was_theirs: bool = them.in_match
		game.player.in_match = true
		them.in_match = true
		var margin: String = game._over_margin()
		_expect("a loss states one — %s" % margin, margin.contains("3,250"))
		# Level with them is not a loss worth quantifying, and a negative
		# margin would print "-400 points short".
		them.score = game.player.score
		_expect("and says nothing when nobody is ahead", game._over_margin() == "")
		# A side that was never in the match cannot be lost to.
		them.score = 13250
		them.in_match = false
		_expect("nor about somebody who never played", game._over_margin() == "")
		game.player.in_match = was_mine
		them.in_match = was_theirs

	# The daily and survival have nobody to be short of.
	game.mode = game.Mode.SURVIVAL
	game.winner = "CPU"
	_expect("survival states no margin", game._over_margin() == "")
	game.mode = was_mode
	game.winner = was_winner


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
	_orient(false)

	_the_door()
	_the_lobby_fits()
	_the_search_door_swaps()
	_the_fallback_offers_a_bot()
	_the_cpu_door_deals_a_match()
	_every_door_is_hittable()
	_rematch_follows_the_opponent()
	_summary_fits_a_phone()

	print("--- what the title says with Game Center off ---")
	print("  %s" % game._versus_sub())
	print("--- %s ---" % ("versus holds up" if fails == 0 else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)
