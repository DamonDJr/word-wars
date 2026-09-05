extends SceneTree
## What is left of versus once Apple's screen owns the matchmaking.
##
## There is no versus screen any more — the title door opens Apple's sheet
## directly — so what used to be tested here (three doors, a friend picker, a
## layout that predicted its own height) went with it. What remains is the part
## the game still owns and can still get wrong:
##
##   * the door itself, which must not start a second search on top of one
##     already running, and must fail quietly rather than pretend;
##   * the rematch negotiation, which is ours end to end and may only exist
##     while there is somebody to negotiate with;
##   * the summary screen, whose foot is *measured* rather than drawn — so if
##     the rows grow and the measurement does not, the buttons land underneath
##     the table.
##
## Game Center is unavailable on Linux, which is the same shape as "not signed
## in" — the case every one of these still has to behave in.
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


## The door hands straight over to Apple. All this end has to do is not make
## things worse: no second search, no phase change, no silent pretence.
func _the_door() -> void:
	print("--- the versus door ---")
	game.phase = game.Phase.TITLE

	game._activate("versus")
	_expect("the door does not navigate anywhere of ours",
		game.phase == game.Phase.TITLE)
	_expect("and leaves no search running with Game Center off",
		mm.available() or not game._versus_busy())

	# The title keys are the other way in, and must agree with the plate.
	_press(KEY_4)
	_press(KEY_V)
	_expect("4 and V are still the door, and still harmless",
		game.phase == game.Phase.TITLE)

	var sub: String = game._versus_sub()
	_expect("the plate says something either way: '%s'" % sub, sub != "")


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
	_rematch_follows_the_opponent()
	_summary_fits_a_phone()

	print("--- what the title says with Game Center off ---")
	print("  %s" % game._versus_sub())
	print("--- %s ---" % ("versus holds up" if fails == 0 else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)
