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
## ## And a third thing, further down
##
## All of that is the summary's. The board *screen* — the one you open on
## purpose to read other people's scores — is the `view_*` half of this file,
## and it is deliberately not built out of the same variables. It is allowed to
## be loud about failing, because it has nothing else on it to fall back to.
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
		_wire_challenges()
		refresh_challenges()


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


# ---------------------------------------------------------------- the view
#
# Everything above answers one question — where did *I* come — for a summary
# that has to keep working when the answer is nothing at all. A screen that
# shows the board itself is a different question with different failure modes:
# it is opened deliberately, it is the only thing on screen, and "there is
# nobody here yet" is something it has to say out loud rather than quietly omit.
#
# So it gets its own state rather than borrowing `state`, `rank` and the rest.
# Neither can blank the other: the summary's two rows keep working while a board
# screen is loading, empty or refused, and a board screen says why it is empty
# while `rank` still holds whatever it held.
#
# ## One call draws the whole screen
#
# `load_local_player_entries` is named for the local player, but its range
# arguments page the *board*. Ask for ranks 1..25 and Apple hands back those
# twenty-five entries, the local player's own entry wherever it actually landed,
# and the size of the field — a top-N list, a "you are #412 of 9,120" line and a
# total, in one round trip. That is why there is no second request here and no
# paging: the screen wants exactly what one call already returns.
#
# `load_entries` is the call this looks like it should use and it is the wrong
# one. In this plugin it takes an *array of players* rather than a rank range —
# Apple's `loadEntries(for players:timeScope:)` overload — so it can only answer
# "what did these specific people score", which is not a leaderboard.

## Emitted when the rows change: a load finishing, failing, or being replaced by
## a different board. A screen that is up repaints on this and asks nothing.
signal view_changed

## Apple's scopes, as plain integers.
##
## Deliberately not `GKLeaderboard.GLOBAL` and friends. `game.gd` picks the scope
## and `game.gd` runs on Linux, where `GKLeaderboard` is a stub that exists
## enough to be named and not enough to be used. Copying the four values Apple
## has published since iOS 7 costs nothing and keeps the drawing code free of a
## class it cannot touch.
const GLOBAL := 0
const FRIENDS := 1
const TODAY := 0
const WEEK := 1
const ALL_TIME := 2

## OFF     — nothing has been asked for, or this build cannot ask.
## LOADING — a request is out.
## READY   — `view_rows` means something. It can still be empty; see EMPTY.
## EMPTY   — Apple answered, and the board has nobody on it for this scope. A
##           real answer, and a different sentence from a failure.
## FAILED  — Apple said no, or there is no account. `view_status` says which.
enum ViewState { OFF, LOADING, READY, EMPTY, FAILED }

var view_state: int = ViewState.OFF
var view_status := ""

## The page, top-first. Each row is
## `{rank: int, name: String, score: int, me: bool}` — everything a row needs to
## draw and nothing that would tie the screen to a `GKLeaderboardEntry`.
var view_rows: Array = []

## The local player's own row when it fell outside the page, and empty when it
## did not — either because they are on it already, or because they have no
## score on this board. A screen draws this under the list, detached, the same
## way the daily summary appends today's run at its real rank.
var view_me: Dictionary = {}

## How many people are on this board in this scope. 0 means Apple did not say.
var view_total := 0

## What is currently being shown, so a screen can tell whether the rows in hand
## are the ones it asked for.
var view_board := ""
var view_scope: int = GLOBAL
var view_time: int = TODAY

## How deep a page to ask for. Twenty-five is a screen and a half of scrolling on
## a phone and one request; the board being read is a global one, so anything
## past the first page or two is a number nobody is looking for themselves in.
const VIEW_ROWS := 25

## Boards this path has loaded, by id. Separate from `_board` and `_sv_board`
## above, which belong to the submit paths and are read here rather than
## replaced — loading a board twice is a wasted round trip, and reaching into
## the submit path's state to write it is a way to break a live screen from a
## new one.
var _view_boards: Dictionary = {}

## Bumped on every `open_view`. A reply carrying a stale number is dropped: the
## player can switch from daily to survival while the daily's request is still
## out, and without this the daily's rows arrive afterwards and overwrite the
## survival board the screen is now showing.
var _view_seq := 0


## Show a board. Safe to call on any platform, signed in or out — the state and
## the status line say what happened and the screen draws that instead of rows.
##
## Calling this again with anything different replaces what is on screen. The
## previous request is not cancelled, because there is no way to cancel it; it
## is discarded when it lands.
func open_view(board_id: String, scope: int = GLOBAL, time_scope: int = TODAY) -> void:
	view_board = board_id
	view_scope = scope
	view_time = time_scope
	view_rows = []
	view_me = {}
	view_total = 0
	_view_seq += 1

	if board_id == "" or not MultiplayerManager.available() \
			or not ClassDB.can_instantiate("GKLeaderboard"):
		_set_view(ViewState.OFF, "leaderboards need an Apple device")
		return
	if not _signed_in():
		# Not a failure of ours and worth saying plainly, because it is the one
		# cause on this list the player can actually do something about.
		_set_view(ViewState.FAILED, "sign in to Game Center to see this board")
		return

	_set_view(ViewState.LOADING, "reading the leaderboard")
	var board = _view_board_for(board_id)
	if board != null:
		_view_fetch(board, _view_seq)
		return
	GKLeaderboard.load_leaderboards(PackedStringArray([board_id]),
		_on_view_board_loaded.bind(board_id, _view_seq))


## Ask again for whatever is already on screen. For a screen being reopened, or
## reopened after a run that just changed where the player stands.
func refresh_view() -> void:
	if view_board == "":
		return
	open_view(view_board, view_scope, view_time)


## A board object we already hold. The submit paths above load the same two ids
## and there is no reason to ask Apple for them twice.
func _view_board_for(board_id: String):
	if board_id == DAILY_ID and _board != null:
		return _board
	if board_id == SURVIVAL_ID and _sv_board != null:
		return _sv_board
	return _view_boards.get(board_id)


func _on_view_board_loaded(boards: Array, error, board_id: String, seq: int) -> void:
	if seq != _view_seq:
		return
	if error != null:
		_set_view(ViewState.FAILED, "Game Center: %s" % str(error))
		return
	if boards.is_empty():
		# Same cause as the warnings in the submit paths — the id is missing from
		# App Store Connect — but this time there is a screen to say it on.
		push_warning("Boards: Game Center has no leaderboard %s" % board_id)
		_set_view(ViewState.FAILED, "this board is not set up yet")
		return
	_view_boards[board_id] = boards[0]
	_view_fetch(boards[0], seq)


func _view_fetch(board, seq: int) -> void:
	board.load_local_player_entries(view_scope, view_time, 1, VIEW_ROWS,
		_on_view_entries.bind(seq))


func _on_view_entries(local, entries: Array, range_total, error, seq: int) -> void:
	if seq != _view_seq:
		return
	if error != null:
		# A friends-only request fails on its own when the permission has been
		# refused, and that is the common case rather than an odd one. The screen
		# gets the sentence and keeps the tab it is on.
		_set_view(ViewState.FAILED, "Game Center: %s" % str(error))
		return

	view_total = int(range_total) if range_total != null else 0
	var mine := ""
	if MultiplayerManager.local_player != null:
		mine = String(MultiplayerManager.local_player.game_player_id)

	view_rows = []
	for e in entries:
		if e == null:
			continue
		view_rows.append(_view_row(e, mine))

	# The local player's own row, but only when the page does not already carry
	# it. `local` is non-null whenever they have a score at all, including when
	# they are sitting at #3 and already drawn — appending it then would print
	# them twice.
	view_me = {}
	if local != null:
		var row := _view_row(local, mine)
		var on_page := false
		for r: Dictionary in view_rows:
			if int(r["rank"]) == int(row["rank"]):
				on_page = true
				break
		if not on_page:
			view_me = row

	if view_rows.is_empty() and view_me.is_empty():
		_set_view(ViewState.EMPTY, "")
		return
	_set_view(ViewState.READY, "")


## One entry, flattened to what a row draws.
##
## The name falls back through `display_name` to `alias` to a placeholder. Both
## can be empty — `display_name` is empty for a player who has not set one, and
## Apple's own screens show something rather than a gap — and a blank row next to
## a score reads as a bug in the game.
func _view_row(entry, mine: String) -> Dictionary:
	var name := ""
	var id := ""
	if entry.player != null:
		name = String(entry.player.display_name)
		if name.strip_edges() == "":
			name = String(entry.player.alias)
		id = String(entry.player.game_player_id)
	if name.strip_edges() == "":
		name = "Player"
	return {
		"rank": int(entry.rank),
		"name": name,
		"score": int(entry.score),
		"me": id != "" and id == mine,
	}


func _set_view(to: int, text: String) -> void:
	view_state = to
	view_status = text
	view_changed.emit()


# ------------------------------------------------------------- challenges
#
# A challenge is a time-limited race on a leaderboard between people who chose
# each other. Apple runs the whole thing: it picks the participants, holds the
# clock, decides who won, and — the part that matters here — sends the push
# notifications when somebody takes your place or your time is nearly up. None
# of that is ours and none of it can be built here.
#
# ## There is no submit call for a challenge, and that is not an omission
#
# Challenges sit on top of a leaderboard rather than beside it. `submit_daily`
# and `submit_survival` above already feed every challenge running on those two
# boards, because Apple routes a submitted score into the challenges that score
# is eligible for. So the retention half of this feature was finished before any
# of it was written, and it will keep working if every line below is deleted.
#
# What is below is the part the game has to do: knowing that a challenge is
# waiting, so there is something on the menu to come back *to*, and a door to
# Apple's screen so it can be answered.
#
# ## Which means App Store Connect is where this actually gets turned on
#
# No challenge exists until one is configured against a leaderboard and passes
# review. Until then everything here is correct, quiet and empty — `pending` is
# zero forever and the door opens a dashboard with nothing in it. See
# `docs/game-center-setup.md`.

## Emitted when the count changes, so a menu badge can repaint.
signal challenges_changed

## Challenges issued *to* the local player and not yet answered. This is the
## number worth putting on a menu: it is a thing waiting for them, unlike the
## ones they issued, which are waiting for somebody else.
var pending := 0

## `GKChallenge.ChallengeState.pending`, written out.
##
## The plugin documents the enum and does not bind it — `GKChallenge` reports no
## integer constants at all to `ClassDB`, so `GKChallenge.PENDING` is a parse
## error rather than a value. The number is Apple's and has been 1 since iOS 6.
const CHALLENGE_PENDING := 1

var _challenges_loading := false
var _challenges_wired := false


## Whether this build can see challenges at all. Challenges ride the leaderboards
## so this is `available()` plus the class, and the class is the part that moves:
## `GKChallenge` is iOS 26 in practice even though GameKit has carried the name
## since iOS 6, because the plugin's wrapper is new.
func challenges_available() -> bool:
	return available() and ClassDB.can_instantiate("GKChallenge")


## Count what is waiting. Cheap, and safe to call from a screen opening.
func refresh_challenges() -> void:
	if not challenges_available() or not _signed_in() or _challenges_loading:
		return
	_challenges_loading = true
	GKChallenge.load_received_challenges(_on_challenges_loaded)


func _on_challenges_loaded(challenges: Array, error) -> void:
	_challenges_loading = false
	if error != null:
		# Nothing on screen depends on this being right — a badge that fails to
		# appear is a badge nobody knew about — so it is logged and dropped.
		print("[Boards] challenges refused: %s" % str(error))
		return
	var was := pending
	pending = 0
	for c in challenges:
		if c != null and int(c.state) == CHALLENGE_PENDING:
			pending += 1
	if pending != was:
		challenges_changed.emit()


## Apple's own challenge screen.
##
## Two doors to the same room, because the direct one is iOS 26 and the game
## ships to 17. `trigger_for_challenges` opens the dashboard already on
## Challenges; on anything older it does nothing at all — silently, which would
## be a dead button — so older systems get the dashboard's front page instead
## and one more tap.
func open_challenges() -> void:
	if not available():
		return
	if _os_major() >= 26 and MultiplayerManager.game_center != null:
		var ap = MultiplayerManager.game_center.access_point
		if ap != null:
			ap.trigger_for_challenges(_on_dashboard_closed)
			return
	GKGameCenterViewController.show_type(GKGameCenterViewController.DASHBOARD)


## Apple's leaderboard screen, for one board. The game draws its own — see the
## `view_*` half above — and this is the way out to the one with profiles,
## avatars and the challenge button on it, which are Apple's to draw and not
## worth reimplementing.
func open_board(board_id: String, scope: int = GLOBAL, time_scope: int = TODAY) -> void:
	if not available() or board_id == "":
		return
	GKGameCenterViewController.show_leaderboard_time_period(board_id, scope, time_scope)


## The access point's triggers all take a completion handler and none of them
## take no arguments, so there has to be something to hand them. It is not
## unused: coming back from the dashboard is the one moment the count is most
## likely to be wrong, because answering a challenge is what the player just went
## in there to do.
func _on_dashboard_closed() -> void:
	refresh_challenges()


## The major version of the OS, or 0 where that cannot be read. `OS.get_version`
## is "26.0.1" on an iPhone and something else entirely everywhere else, so this
## has to fail to a number that switches the new path off rather than on.
func _os_major() -> int:
	var bits := OS.get_version().split(".")
	if bits.is_empty() or not bits[0].is_valid_int():
		return 0
	return int(bits[0])


## Listen for challenges arriving and finishing.
##
## Connected once, and only after `MultiplayerManager` has authenticated —
## `register_listener` has already been called on this object by then, and these
## signals are Godot's rather than Apple's, so a late connection still receives.
func _wire_challenges() -> void:
	if _challenges_wired or not challenges_available():
		return
	var lp = MultiplayerManager.local_player
	if lp == null:
		return
	lp.challenge_received.connect(_on_challenge_moved)
	lp.challenge_completed.connect(_on_challenge_moved)
	lp.challenge_other_player_completed.connect(_on_challenge_moved)
	_challenges_wired = true


## Every one of the three means the same thing to this file: the count is stale.
## What actually changed is on Apple's screen, and the player has already been
## told about it by a notification we did not send.
func _on_challenge_moved(_a = null, _b = null, _c = null) -> void:
	refresh_challenges()


func _on_gc_state_changed(_text: String) -> void:
	if not available():
		return
	# Signing out invalidates every rank on screen: they were somebody else's.
	if not _signed_in():
		rank = 0
		total = 0
		friend_rank = 0
		friend_total = 0
		# The board screen's rows are somebody else's too, and unlike the summary
		# it is probably the thing being looked at right now.
		if view_state != ViewState.OFF:
			view_rows = []
			view_me = {}
			view_total = 0
			_set_view(ViewState.FAILED, "sign in to Game Center to see this board")
		# Somebody else's challenges, and a badge counting them is worse than no
		# badge: it advertises something the signed-out player cannot open.
		if pending != 0:
			pending = 0
			challenges_changed.emit()
		_set_state(State.WAITING, "waiting for Game Center")
		return
	_wake()
	# A run finished while signed out has been waiting for exactly this.
	_sv_wake()
	# So has a board screen that was open when the account arrived.
	if view_board != "" and view_state == ViewState.FAILED:
		refresh_view()
	_wire_challenges()
	refresh_challenges()


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
