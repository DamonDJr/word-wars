extends SceneTree
## The challenge door, and the run it starts.
##
## The bug this exists to stop coming back: a challenge accepted on Apple's
## screen left the player on the title menu with nothing to press and no sign a
## challenge was running at all. Apple's Start button cannot tell this game
## anything — `player(_:wantsToPlay:)` is not bridged by the plugin, and
## `tools/gctest.gd` pins the signals that *are* — so the game has to offer the
## run itself, off what `load_received_challenges` hands back.
##
## None of that can be exercised on a device without a second Apple account and
## a configured challenge, so what is checked here is everything on our side of
## the callback: the flattening, the door, the launch, and the verdict.
##
##   godot --headless --script tools/challengetest.gd

const SURVIVAL_BOARD := "com.damonj.wordwars.survival"
const DAILY_BOARD := "com.damonj.wordwars.daily"

var game: Node
var boards: Node
var profile: Node
var stage: SubViewport
var fails := 0


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-58s %s" % [what, "ok" if ok else "FAILED"])


## What `_on_challenges_loaded` would have left behind for a survival race.
func _arm(board: String, score: int, from: String = "Anna") -> void:
	boards.challenge = {
		"board": board, "score": score, "formatted": _commas(score),
		"from": from, "issued": 1750000000.0,
	}


func _commas(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out


## The door exists, says who and what, and is the first thing on the screen.
func _the_title_offers_the_challenge() -> void:
	print("--- the title screen offers a waiting challenge ---")
	boards.challenge = {}
	var plain: Array = game._title_modes()
	_expect("no challenge, no door", not _has_challenge_door(plain))

	_arm(SURVIVAL_BOARD, 14320)
	_expect("an armed challenge reports itself", boards.challenge_armed())
	var rows: Array = game._title_modes()
	_expect("the door appears", _has_challenge_door(rows))
	# Above PRACTICE, above the modes, above everything. It is the only row on
	# this screen somebody else is waiting on.
	_expect("and it is the first row", String((rows[0] as Array)[3]) == "challenge")

	var sub: String = game._challenge_sub()
	_expect("it names the challenger: '%s'" % sub, sub.contains("Anna"))
	_expect("and the number to beat", sub.contains("14,320"))
	_expect("and which mode that is", sub.contains("Survival"))

	# The challenge door was given a band of its own — WAITING — which meant
	# renumbering every other row on the screen. `_draw_title_bands` indexes
	# `TITLE_BANDS` with that number and does not check it, so a row left on the
	# old numbering runs off the end of the array and takes the title screen
	# down on launch. Checked with the door and without it, because the shift
	# has to hold in both.
	for armed in [true, false]:
		if not armed:
			boards.challenge = {}
		var check: Array = game._title_modes()
		var bands: int = game.TITLE_BANDS.size()
		var ok := true
		for r: Array in check:
			if int(r[5]) < 0 or int(r[5]) >= bands:
				ok = false
		_expect("every band is a real band (%s a challenge)"
			% ("with" if armed else "without"), ok)
	_arm(SURVIVAL_BOARD, 14320)

	# A number with nobody on it is still a challenge. Apple can hand back a
	# player whose display name and alias are both empty.
	_arm(SURVIVAL_BOARD, 14320, "")
	var anon: String = game._challenge_sub()
	_expect("a nameless challenger still reads: '%s'" % anon,
		anon.contains("14,320") and not anon.contains("says"))


func _has_challenge_door(rows: Array) -> bool:
	for r: Array in rows:
		if String(r[3]) == "challenge":
			return true
	return false


## Pressing it starts the right mode. This is the whole bug.
func _the_door_starts_the_right_mode() -> void:
	print("--- and pressing it starts that mode ---")

	_arm(SURVIVAL_BOARD, 14320)
	game.phase = game.Phase.TITLE
	game._start_challenge()
	_expect("a survival challenge starts survival",
		game.mode == game.Mode.SURVIVAL)
	_expect("and the run remembers what it is for",
		int(game.challenge_run.get("score", 0)) == 14320)
	# Dropped locally rather than waited on: Apple will not move the challenge
	# out of `pending` until the score lands.
	_expect("and the door closes behind it", not boards.challenge_armed())

	_arm(DAILY_BOARD, 9000)
	profile.daily.erase(game.daily_key())
	game._start_challenge()
	_expect("a daily challenge starts the daily", game.mode == game.Mode.DAILY)

	# An ordinary run is not a challenge run, however many are waiting. This is
	# the one that would quietly mislabel every daily somebody played on a day a
	# friend happened to challenge them.
	_arm(DAILY_BOARD, 9000)
	profile.daily.erase(game.daily_key())
	game.start_match("Daily", 0, [], game.Mode.DAILY)
	_expect("the DAILY door does not inherit a waiting challenge",
		game.challenge_run.is_empty())
	_expect("and says nothing about one", game._challenge_line() == "")


## A board this build has never heard of is not a door.
##
## Challenges are configured in App Store Connect against a leaderboard, and a
## leaderboard can be added after a version ships. Opening "whichever mode came
## first" for one of those is worse than not offering it.
func _an_unknown_board_is_not_offered() -> void:
	print("--- and an unknown board is not offered at all ---")
	boards.challenge = {}
	var made: Dictionary = boards._playable_challenge(
		_fake_challenge(0, "com.damonj.wordwars.somethingnew", 500))
	_expect("a score challenge on an unknown board is dropped", made.is_empty())
	made = boards._playable_challenge(_fake_challenge(0, SURVIVAL_BOARD, 500))
	_expect("one on the survival board is kept", not made.is_empty())
	_expect("with the board it came off",
		String(made.get("board", "")) == SURVIVAL_BOARD)
	# An achievement challenge has no score and no mode. Apple sends them.
	made = boards._playable_challenge(_fake_challenge(1, SURVIVAL_BOARD, 500))
	_expect("an achievement challenge is dropped", made.is_empty())

	_arm(SURVIVAL_BOARD, 100)
	boards.challenge = {}
	game.mode = game.Mode.NORMAL
	game._start_challenge()
	_expect("pressing a door with nothing behind it starts nothing",
		game.mode == game.Mode.NORMAL)


## Stands in for a `GKChallenge`, which cannot be built off a device. Duck-typed
## on purpose: `_playable_challenge` reads properties and never asks what class
## it was handed, so this exercises the real code path.
func _fake_challenge(kind: int, board: String, score: int) -> Object:
	var o := ChallengeStub.new()
	o.challenge_type = kind
	o.leaderboard_identifier = board
	o.score = score
	return o


class ChallengeStub:
	var challenge_type := 0
	var leaderboard_identifier := ""
	var score := 0
	var formatted_score := ""
	var issue_date := 1750000000.0
	var issuing_player = null


## Beaten, missed, and the tie that Apple counts as beaten.
func _the_verdict_is_reported() -> void:
	print("--- and the summary says how it went ---")

	_arm(SURVIVAL_BOARD, 14320)
	game._start_challenge()
	game.player.score = 20000
	var won: Dictionary = game._challenge_verdict()
	_expect("out-scoring the target beats it", bool(won["beat"]))
	_expect("by the difference", int(won["by"]) == 5680)
	_expect("and the summary says so: '%s'" % game._challenge_line(),
		game._challenge_line().contains("BEATEN"))

	game.player.score = 9000
	_expect("falling short misses it",
		not bool(game._challenge_verdict()["beat"]))
	_expect("and the summary says that: '%s'" % game._challenge_line(),
		game._challenge_line().contains("MISSED"))

	# A tie goes to the challenger's target being matched, because Apple ranks
	# an equal score ahead of the one submitted later — claiming a loss the
	# leaderboard is about to contradict is the one wrong answer available.
	game.player.score = 14320
	_expect("a tie counts as beaten", bool(game._challenge_verdict()["beat"]))

	# The share card's badge outranks whatever the mode had to say.
	game.player.score = 20000
	var c = game._share_card_data()
	_expect("the share card leads on the challenge: '%s'" % c.badge,
		c.badge.to_lower().contains("challenge") or c.badge.contains("Anna"))
	_expect("and draws it in gold", c.badge_hot)

	game.player.score = 9000
	_expect("a missed one is not gold", not game._share_card_data().badge_hot)


## An ordinary run says nothing at all, and the summary reserves no room for it.
func _an_ordinary_run_is_silent() -> void:
	print("--- an ordinary run says nothing about challenges ---")
	boards.challenge = {}
	game.start_match("Duelist", 0, [], game.Mode.SURVIVAL)
	game.player.score = 5000
	_expect("no verdict", game._challenge_verdict().is_empty())
	_expect("no line", game._challenge_line() == "")
	var plain: float = game._scoreboard_top()
	_arm(SURVIVAL_BOARD, 100)
	game._start_challenge()
	game.player.score = 5000
	# The table has to start lower, or it is drawn through the verdict — which
	# is exactly what one reserved row for two lines did.
	_expect("and a challenge run pushes the table down",
		game._scoreboard_top() > plain)


func _init() -> void:
	await process_frame
	boards = root.get_node("Boards")
	profile = root.get_node("Profile")
	game = load("res://scenes/main.tscn").instantiate()
	stage = SubViewport.new()
	stage.size = Vector2i(720, 1440)
	root.add_child(stage)
	stage.add_child(game)
	await process_frame
	await process_frame
	game.portrait = true

	_the_title_offers_the_challenge()
	_the_door_starts_the_right_mode()
	_an_unknown_board_is_not_offered()
	_the_verdict_is_reported()
	_an_ordinary_run_is_silent()

	print("--- %s ---" % ("challenges hold up" if fails == 0
		else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)
