extends Node
## Autoload `Boards`. Today's daily score, on Game Center, and where it puts you.
##
## The daily is the one mode where a global ranking means anything: everybody
## gets the same board, the same sixty seconds and one attempt, so two scores
## from the same day are genuinely comparable. Nothing else in the game is —
## a versus score depends on who you drew.
##
## ## This is the second board, not the only one
##
## The summary's leaderboard is built from `Profile.daily_ranked()` and needs no
## network, no account and no Apple device. What is here only ever *adds* two
## lines to it: where today's run stands globally, and where it stands among
## friends. That split is deliberate and load-bearing — Game Center is
## unreachable on most of the machines this game is developed on, it can be
## signed out on the ones where it is reachable, and a leaderboard that shows
## nothing at all under those conditions is a feature that is missing far more
## often than it is present.
##
## So every failure here is silent and local: `rank` stays 0, the UI leaves the
## rows out, and the board the player came to see is already on screen.
##
## ## Setting it up in App Store Connect
##
## `DAILY_ID` must exist as a **classic** leaderboard, score format integer,
## sort order high-to-low. Classic rather than recurring on purpose: a classic
## board keeps every score forever and GameKit will filter it to `TODAY` for us,
## which is exactly the daily's ranking and costs no configuration. A recurring
## board would also work and would prune itself, but its occurrences have to be
## lined up with local midnight, and the daily's midnight is the *player's* —
## see `game.daily_key()`. There is no one occurrence schedule that matches.

## Emitted whenever a rank arrives or the state moves, so a screen that is
## already up can repaint. There is no polling here; the summary asks once.
signal changed

## The App Store Connect leaderboard id. Empty disables submission entirely —
## which is the right behaviour before the board exists, because submitting to
## an id that is not configured is an error per submission, forever.
##
## Reverse-DNS on the bundle id, matching the in-app purchase. Apple does not
## require the convention and will accept anything, but two ids in one project
## that follow two different rules is a thing somebody has to remember rather
## than work out.
##
## This must match App Store Connect exactly. It does not, yet: nothing breaks
## if the board is missing — `_on_boards_loaded` says so and everything stays
## local — but nothing ranks either.
const DAILY_ID := "com.damonj.wordwars.daily"

## OFF      — no Apple device, no plugin, or no id configured. The resting state
##            on every desktop build, and not a fault.
## WAITING  — signed out, or Game Center has not finished authenticating. A
##            score submitted now is held rather than dropped.
## LOADING  — talking to Apple.
## READY    — `rank` and friends below mean something.
## FAILED   — Apple said no. `status` says what it said.
enum State { OFF, WAITING, LOADING, READY, FAILED }

var state: int = State.OFF
var status := ""

## Today's placing. 0 means "not known", which is what every screen checks —
## a rank of 0 is never drawn, so an unreachable Game Center and a run that was
## never submitted look the same on the summary, which is correct: in both cases
## there is nothing true to say.
var rank := 0
var total := 0
var friend_rank := 0
var friend_total := 0

## The board object, once Apple has handed it over. Loaded at most once.
var _board = null
## A score that arrived before we could send it. The daily is one run a day, so
## there is only ever one of these — a second would be a bug elsewhere.
var _pending := -1
var _loading_board := false


func _ready() -> void:
	if not available():
		_set_state(State.OFF, "leaderboards need an Apple device")
		return
	_set_state(State.WAITING, "waiting for Game Center")
	MultiplayerManager.state_changed.connect(_on_gc_state_changed)
	# Already signed in by the time we got here — the autoloads race and
	# MultiplayerManager may well have won. Without this the first launch of a
	# session submits nothing and reports no rank, and the second works.
	if _signed_in():
		_wake()


## Whether this build can reach Game Center leaderboards at all.
##
## Three separate things, and all three have to hold. The platform check comes
## first for the same reason it does in `MultiplayerManager.available()`: the
## desktop stub registers every class and answers `can_instantiate` with yes,
## then hands back null when you try. The id check is last because it is ours
## rather than Apple's — a build with no leaderboard configured is switched off
## here rather than failing one call at a time.
func available() -> bool:
	if DAILY_ID == "":
		return false
	if not MultiplayerManager.available():
		return false
	return ClassDB.can_instantiate("GKLeaderboard")


func _signed_in() -> bool:
	return MultiplayerManager.local_player != null


## Today's score, on its way to Apple.
##
## Called once, from `_finish_daily`, immediately after the run is banked. Safe
## to call when signed out, on a desktop build, or before authentication has
## finished: the score is held and sent when there is somewhere to send it.
func submit_daily(score: int) -> void:
	if not available():
		return
	_pending = score
	if not _signed_in():
		_set_state(State.WAITING, "waiting for Game Center")
		return
	_wake()


## Ask where today's run stands, without submitting anything. For a summary
## reopened later in the day, when the score went up hours ago.
func refresh() -> void:
	if not available() or not _signed_in():
		return
	_wake()


# ------------------------------------------------------------------ survival
#
# A second board, kept deliberately apart from the first rather than folded into
# it.
#
# Everything above is built around one board and one rank: `_board`, `rank`,
# `friend_rank` and the whole `_wake` -> `_flush` -> `_load_ranks` chain are the
# daily's, and the summary reads them by name. Generalising that to a dictionary
# of boards would touch every line of a path that is live, working, and the only
# thing on the daily summary — to add a mode that wants none of it.
#
# So survival gets what it actually needs, which is a submit and nothing else.
# No rank is read back because no screen shows one yet; when one does, that is
# the moment to make this generic, with a reason to.

## Highest score from a run, on the survival board. Empty disables it, the same
## way an empty `DAILY_ID` disables the daily.
const SURVIVAL_ID := "com.damonj.wordwars.survival"

var _sv_board = null
## A score waiting for somewhere to go. Unlike the daily's, this one takes the
## highest rather than the latest: a player can finish three runs on a plane, and
## the board wants their best, not their last.
var _sv_pending := -1
var _sv_loading := false


## A finished run, on its way to Apple. Safe signed out, off-device, or before
## authentication finishes — it is held and sent when there is somewhere to send.
func submit_survival(score: int) -> void:
	if not available() or SURVIVAL_ID == "" or score <= 0:
		return
	_sv_pending = maxi(_sv_pending, score)
	if not _signed_in():
		return
	_sv_wake()


func _sv_wake() -> void:
	if _sv_pending < 0:
		return
	if _sv_board != null:
		var score := _sv_pending
		_sv_pending = -1
		_sv_board.submit_score(score, 0, MultiplayerManager.local_player,
			_on_sv_submitted)
		return
	if _sv_loading:
		return
	_sv_loading = true
	GKLeaderboard.load_leaderboards(
		PackedStringArray([SURVIVAL_ID]), _on_sv_loaded)


func _on_sv_loaded(boards: Array, error) -> void:
	_sv_loading = false
	if error != null or boards.is_empty():
		# Said out loud because nothing on screen will: survival has no rank row,
		# so a missing board is invisible until somebody checks App Store Connect.
		push_warning("Boards: no survival leaderboard %s" % SURVIVAL_ID)
		return
	_sv_board = boards[0]
	_sv_wake()


func _on_sv_submitted(error) -> void:
	if error == null:
		return
	# The run is already on the record screen. Losing the global placing is the
	# whole cost, and it is not worth a message over somebody's death screen.
	print("[Boards] survival submit refused: %s" % str(error))


func _on_gc_state_changed(_text: String) -> void:
	if not available():
		return
	# Signing out invalidates every rank on screen: they were somebody else's.
	if not _signed_in():
		rank = 0
		total = 0
		friend_rank = 0
		friend_total = 0
		_set_state(State.WAITING, "waiting for Game Center")
		return
	_wake()
	# A run finished while signed out has been waiting for exactly this.
	_sv_wake()


## Get the board, then do whatever is outstanding with it.
func _wake() -> void:
	if _board != null:
		_flush()
		return
	if _loading_board:
		return
	_loading_board = true
	_set_state(State.LOADING, "reading the leaderboard")
	GKLeaderboard.load_leaderboards(
		PackedStringArray([DAILY_ID]), _on_boards_loaded)


func _on_boards_loaded(boards: Array, error) -> void:
	_loading_board = false
	if error != null:
		_set_state(State.FAILED, "Game Center: %s" % str(error))
		return
	if boards.is_empty():
		# The id is wrong, or the board is not live yet. Worth saying out loud in
		# the log because nothing on screen will show it — the summary simply
		# leaves the two rows out, which looks like a device with no account.
		push_warning("Boards: Game Center has no leaderboard %s" % DAILY_ID)
		_set_state(State.FAILED, "no such leaderboard")
		return
	_board = boards[0]
	_flush()


## Send anything waiting, then read back where it put us.
func _flush() -> void:
	if _board == null:
		return
	if _pending >= 0:
		var score := _pending
		_pending = -1
		_set_state(State.LOADING, "posting your score")
		_board.submit_score(score, 0, MultiplayerManager.local_player,
			_on_submitted)
		return
	_load_ranks()


func _on_submitted(error) -> void:
	if error != null:
		# The run is banked locally either way — `record_daily` has already been
		# and gone — so this costs the player their place on the global board and
		# nothing else. Not worth a message over their summary.
		_set_state(State.FAILED, "Game Center: %s" % str(error))
		return
	_load_ranks()


func _load_ranks() -> void:
	if _board == null:
		return
	_set_state(State.LOADING, "reading the leaderboard")
	# Rank 1, length 1: we want the local player's own placing and the size of
	# the field, not a page of other people's scores. The summary has a board on
	# it already and it is the player's own history.
	_board.load_local_player_entries(
		GKLeaderboard.GLOBAL, GKLeaderboard.TODAY, 1, 1, _on_global)


func _on_global(local, _entries: Array, range_total, error) -> void:
	if error != null:
		_set_state(State.FAILED, "Game Center: %s" % str(error))
		return
	# Null means signed in, board found, and no score posted today — a real
	# answer rather than a failure, and the one every player has before they
	# play. Left at zero so nothing is drawn.
	rank = int(local.rank) if local != null else 0
	total = int(range_total) if range_total != null else 0
	changed.emit()
	_board.load_local_player_entries(
		GKLeaderboard.FRIENDS_ONLY, GKLeaderboard.TODAY, 1, 1, _on_friends)


func _on_friends(local, _entries: Array, range_total, error) -> void:
	# A friends board can fail on its own — the permission is separate and can be
	# refused — and that must not take the global rank down with it, which has
	# already arrived and is already on screen.
	if error != null:
		friend_rank = 0
		friend_total = 0
		_set_state(State.READY, "")
		return
	friend_rank = int(local.rank) if local != null else 0
	friend_total = int(range_total) if range_total != null else 0
	_set_state(State.READY, "")


func _set_state(to: int, text: String) -> void:
	state = to
	status = text
	changed.emit()
