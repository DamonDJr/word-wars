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


## A daily challenge on a day already played is answered, not refused.
##
## The bug: a challenge has a clock on it and the daily has one run in it, so
## somebody challenged after breakfast was told to come back at midnight and the
## challenge expired unanswered in between. From the sender's side that is the
## game ignoring them.
func _a_spent_daily_still_answers() -> void:
	print("--- and a spent daily sends the score it already has ---")
	var key: String = game.daily_key()

	# Today, played, 9,000 on the board. The challenge asks for 7,500.
	profile.daily.erase(key)
	profile.record_daily(key, 9000, 40, 12, 3)
	_arm(DAILY_BOARD, 7500)
	game.mode = game.Mode.NORMAL
	game.challenge_sent = ""

	var sub: String = game._challenge_sub()
	_expect("the door offers the score rather than a run: '%s'" % sub,
		sub.contains("Send your 9,000"))
	_expect("and still names the target", sub.contains("7,500"))

	game._start_challenge()
	_expect("pressing it starts no run at all", game.mode == game.Mode.NORMAL)
	_expect("the challenge is answered and dropped", not boards.challenge_armed())
	_expect("and nothing is labelled a challenge run",
		game.challenge_run.is_empty())
	_expect("the verdict is reported: '%s'" % game.challenge_sent,
		game.challenge_sent.contains("beats Anna"))
	_expect("and hot, because it beat the target", game.challenge_sent_hot)

	# The row has to survive the challenge being cleared, or the tap takes the
	# plate off the screen and reads as nothing having happened.
	var rows: Array = game._title_modes()
	_expect("the row stays up holding the answer",
		rows.size() > 0 and String((rows[0] as Array)[1]) == "SENT")
	_expect("and every band is still a real band",
		_bands_are_real(rows))

	# Short of the target is still an answer — it closes the challenge — and has
	# to say so rather than claiming a win.
	profile.daily.erase(key)
	profile.record_daily(key, 4000, 40, 12, 3)
	_arm(DAILY_BOARD, 7500)
	game.challenge_sent = ""
	game._start_challenge()
	_expect("falling short still sends: '%s'" % game.challenge_sent,
		game.challenge_sent.contains("Sent your 4,000"))
	_expect("and reports the gap", game.challenge_sent.contains("3,500"))
	_expect("without claiming it beat anything", not game.challenge_sent_hot)

	# And it expires, rather than sitting on the title screen forever.
	game._tick_challenges(game.CHALLENGE_SENT_LIFE + 1.0)
	_expect("the answer clears itself after a few seconds",
		game.challenge_sent == "")
	profile.daily.erase(key)


func _bands_are_real(rows: Array) -> bool:
	for r: Array in rows:
		if int(r[5]) < 0 or int(r[5]) >= game.TITLE_BANDS.size():
			return false
	return true


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


## Stands in for a `GKChallengeDefinition` and the `GKLeaderboard` hanging off
## it. Duck-typed for the same reason `ChallengeStub` is: `_definition_board`
## reads properties and never asks what class it was handed.
class LeaderboardStub:
	var base_leaderboard_id := ""


class DefinitionStub:
	var identifier := ""
	var title := ""
	var leaderboard = null


## The modern challenge store, which is the one this app actually has.
##
## The bug this exists to stop coming back is the one that shipped: the game
## read `GKChallenge.load_received_challenges`, which is the legacy iOS 6 store,
## while every challenge it can actually receive is configured in App Store
## Connect as a challenge *definition* and arrives through
## `GKChallengeDefinition`. The legacy call returned an empty array, correctly,
## forever — and an empty array is indistinguishable from "nobody has challenged
## you" right up until you have checked App Store Connect.
func _definitions_drive_the_door() -> void:
	print("--- the modern challenge store ---")
	boards.challenge = {}
	boards.active = {}
	profile.daily.erase(game.daily_key())

	# A definition is placed by the leaderboard it tracks, not by its own id, so
	# renaming one in App Store Connect cannot unplug it.
	var daily := DefinitionStub.new()
	daily.identifier = "something.else.entirely"
	daily.leaderboard = LeaderboardStub.new()
	daily.leaderboard.base_leaderboard_id = DAILY_BOARD
	_expect("a definition is placed by its leaderboard",
		boards._definition_board(daily) == DAILY_BOARD)

	# And by its own id when the leaderboard relationship comes back null, which
	# the wrapper allows and which would otherwise make every definition
	# unplaceable.
	var fallback := DefinitionStub.new()
	fallback.identifier = boards.CHALLENGE_DEF_SURVIVAL
	_expect("and by its identifier when the leaderboard is null",
		boards._definition_board(fallback) == SURVIVAL_BOARD)

	var unknown := DefinitionStub.new()
	unknown.identifier = "com.damonj.wordwars.ch.somethingnew"
	_expect("one this build cannot place is dropped",
		boards._definition_board(unknown) == "")

	# Apple answers `has_active_challenges` with a bare bool and no clue which
	# definition it was about, so the board is bound on the way out.
	boards._on_definition_active(true, null, DAILY_BOARD)
	_expect("an active definition arms the board",
		boards.active_challenge_board() == DAILY_BOARD)
	_expect("but not the legacy door, which has no target to show",
		not boards.challenge_armed())

	var sub: String = game._running_challenge_sub()
	_expect("the door says a challenge is running: '%s'" % sub,
		sub.contains("challenge is running") and sub.contains("daily"))

	# Pressing it opens the mode the challenge is scored on, off the active
	# board rather than off the empty legacy dictionary.
	game.mode = game.Mode.NORMAL
	game._start_challenge()
	_expect("and pressing it starts the daily", game.mode == game.Mode.DAILY)
	_expect("without claiming the run is a challenge run",
		game.challenge_run.is_empty())
	_expect("so the summary says nothing about a verdict",
		game._challenge_line() == "")

	# The daily wins a tie: both boards can be running at once and the door has
	# room for one.
	boards._on_definition_active(true, null, SURVIVAL_BOARD)
	_expect("the daily outranks survival for the one door",
		boards.active_challenge_board() == DAILY_BOARD)
	boards._on_definition_active(false, null, DAILY_BOARD)
	_expect("and survival takes it once the daily is not running",
		boards.active_challenge_board() == SURVIVAL_BOARD)
	var ssub: String = game._running_challenge_sub()
	_expect("with its own copy: '%s'" % ssub, ssub.contains("Survival"))
	boards._on_definition_active(false, null, SURVIVAL_BOARD)
	_expect("and nothing at all once neither is running",
		game._running_challenge_sub() == "")


## A spent daily draws no door and sends the score anyway.
func _a_spent_daily_sends_itself() -> void:
	print("--- and a spent day sends itself, quietly ---")
	var key: String = game.daily_key()
	boards.challenge = {}
	boards.active = {}
	profile.daily.erase(key)
	profile.prefs.erase("challenge_sent_for")

	# Nothing to send before the board has been played, whatever is running.
	boards._on_definition_active(true, null, DAILY_BOARD)
	game._maybe_send_banked_to_challenge()
	_expect("an unplayed board sends nothing",
		String(profile.pref("challenge_sent_for")) == "")
	_expect("and the door offers the run instead",
		game._running_challenge_sub().contains("challenge is running"))

	profile.record_daily(key, 9000, 40, 12, 3)
	_expect("but a spent one draws no door at all",
		game._running_challenge_sub() == "")

	game._maybe_send_banked_to_challenge()
	_expect("and sends the banked score without being asked",
		String(profile.pref("challenge_sent_for")) == key)

	# Once. The poll behind this runs every frame the title screen is up.
	profile.set_pref("challenge_sent_for", "")
	profile.set_pref("challenge_sent_for", key)
	game._maybe_send_banked_to_challenge()
	_expect("exactly once, however many times it is asked",
		String(profile.pref("challenge_sent_for")) == key)

	# And nothing at all when no challenge is running — a resubmission with
	# nothing to close is noise on somebody's leaderboard.
	profile.prefs.erase("challenge_sent_for")
	boards.active = {}
	game._maybe_send_banked_to_challenge()
	_expect("and nothing when no challenge is running",
		String(profile.pref("challenge_sent_for")) == "")

	profile.daily.erase(key)
	profile.prefs.erase("challenge_sent_for")


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
	_a_spent_daily_still_answers()
	_definitions_drive_the_door()
	_a_spent_daily_sends_itself()
	_an_unknown_board_is_not_offered()
	_the_verdict_is_reported()
	_an_ordinary_run_is_silent()

	print("--- %s ---" % ("challenges hold up" if fails == 0
		else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)
