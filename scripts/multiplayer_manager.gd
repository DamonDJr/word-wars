extends Node
## Autoload `MultiplayerManager`. Game Center matchmaking, and the handshake that
## turns a connected match into a match both players are actually playing.
##
## Game Center is not a `MultiplayerPeer`. There is no host, no peer ids and no
## RPC — there is a bag of bytes you can send to everyone, and that is the whole
## transport. So the rules the old netfox build got from the high-level API have
## to be written out by hand here, and there are three of them:
##
## 1. **A match is not ready when you receive it.** The match object can arrive
##    with `expected_player_count` still counting down; players attach
##    afterwards. Anything sent before that reaches nobody.
## 2. **Both ends have to agree when to start.** Each device's callback fires at
##    its own moment, so without an exchange one player is mid-countdown while
##    the other is still on the title screen — which looks exactly like a game
##    that connected and then hung.
## 3. **Invites are a separate door.** Accepting one outside the app does
##    nothing at all unless a listener was registered first.
##
## ## Why there is no Game Center sheet
##
## `GKMatchmakerViewController` is the obvious way to do this and it is a trap
## with this plugin. Apple requires the app to dismiss that sheet itself from
## `matchmakerViewController(_:didFind:)`, and the plugin never does: both of its
## delegate classes — `Proxy` and `RequestMatchDelegate` — dismiss only from
## `matchmakerViewControllerWasCancelled`, and no `dismiss` is exposed to
## GDScript to do it by hand. So a *successful* match leaves Apple's sheet parked
## on screen saying "Starting Game…" forever, with the game running underneath
## where nobody can see or reach it.
##
## `GKMatchmaker` does the same matchmaking with no view controller at all, so
## there is no sheet to be stuck behind and the game's own screens stay in front.
## Invites go out through `recipients` and come back through `match_for_invite`,
## both of which are equally headless.
##
## That reasoning held until the plugin was fixed. `didFind` dismisses now, so
## Apple's screen is the door the game uses — see `open_native_matchmaker` — and
## it brings the one thing headless matchmaking never had: an invite that texts a
## link to any contact, rather than only to Game Center friends. The headless
## calls below are kept for the invite that arrives from outside the app, which
## has no sheet of its own and never did.
##
## Everything here is guarded on the platform rather than commented out for
## desktop testing: the plugin ships a Linux stub whose classes refuse to
## instantiate, so `available()` answers honestly and the rest of the game runs
## on a PC with multiplayer simply switched off.

signal state_changed(text: String)
signal match_started
signal match_ended(reason: String)
signal data_received(packet: Dictionary)

## Somebody's invitation is in hand and waiting on an answer. See the invite
## section below for why this is a signal rather than a join.
signal invite_offered(who: String)

enum State { OFF, AUTHENTICATING, READY, MATCHMAKING, CONNECTING, HANDSHAKING, PLAYING }

## How long to keep repeating the hello before giving up on the other end. The
## first one can land before the peer has finished attaching, so it is repeated
## rather than sent once and hoped for.
const HELLO_EVERY := 0.5
const HANDSHAKE_TIMEOUT := 15.0
## How long to hold the handshake open for Apple's sheet to take itself down.
##
## Short, and it used to be two minutes. The reasoning was that the only thing
## on the far side of that sheet is a person deciding to tap, which deserves
## patience — but that got the trade backwards. Holding costs the *other* player
## a wait they cannot explain or end, and on a device they gave up after five
## seconds and left. Starting behind a sheet is a cosmetic annoyance; leaving
## somebody staring at "waiting for them" is a lost match.
##
## So this is a grace period for the dismissal, not a wait for a person. If the
## sheet closes itself the handshake is released the moment it does. If it does
## not, the match starts anyway and the sheet goes back to being one tap in the
## way — which is exactly where this started, and no worse.
##
## Two seconds, not four and certainly not a hundred and twenty. With the fixed
## plugin the dismissal is requested *before* the match is handed over, so any
## wait at all is only covering the animation — and a dismissal that succeeds
## emits nothing, so there is nothing to wait *for*, only a moment to allow.
const SHEET_GRACE := 2.0
## A match whose players never finish attaching. Without this the game sits in
## "waiting for the other player" with no way out but force-quitting.
const CONNECT_TIMEOUT := 30.0
## Bumped whenever a packet changes meaning. Checked in the hello, so two builds
## that would misread each other refuse to start rather than play nonsense.
const PROTOCOL := 1

var state: int = State.OFF
var status := "offline"

## All untyped. These are Game Center classes, and naming one in a type hint is
## a parse error on Android, where the plugin has no library — see apple.gd.
##
## `current_match` holds whatever the running transport uses for a match: a
## `GKMatch` over Game Center, an `EOSGMultiplayerPeer` over Epic. Everything
## outside this file only ever asks whether it is null.
var game_center = null  # GameCenterManager
var local_player = null  # GKLocalPlayer
var current_match = null
var _matchmaker = null  # GKMatchmaker

## The other player's Game Center id, learned from their hello. Also the thing
## that decides seating: both ends sort the two ids the same way, so both agree
## who is who without anybody being the host.
var _peer_id := ""
var _local_id := ""
var _hello_timer := 0.0
var _wait_age := 0.0
var _peer_said_hello := false
## Counted only so a failed handshake can say how hard it tried. "Never
## answered" after one hello and after thirty are different faults.
var _hellos_sent := 0
var _send_failures := 0

## True while Apple's matchmaking sheet is still covering this device.
##
## The sheet is the plugin's to close and it does not, so a match found through
## Apple's screen starts underneath it — invisible on this device and already
## running on the other. Measured: the handshake completed 47ms after the match
## was found and the sheet was closed by hand eight seconds later, which is eight
## seconds of somebody else playing a match you cannot see.
##
## So this end holds. The handshake is what both devices already use to agree on
## when to start, and this is simply one more reason not to be ready yet: no
## hello goes out until the sheet is down, and the peer is told to keep waiting
## rather than being left to time out.
var _native_sheet_up := false

## How long *this* device's sheet has been up, on a clock the other end cannot
## touch.
##
## `_wait_age` cannot do this job, and using it deadlocked every automatch where
## both sheets stayed up. Each end sends `holding` every `HELLO_EVERY`; each
## `holding` received resets `_wait_age` to zero; and the escape from a stuck
## sheet was `_wait_age >= SHEET_GRACE`. So two devices politely told each other
## to keep waiting, four times faster than the two-second grace they were both
## waiting for, and neither ever escaped. Both screens read "waiting for them to
## close Game Center" — about the other player — forever, with no timeout behind
## it either, because `_process` returns before the handshake deadline while the
## sheet is up.
##
## A keepalive that resets the timer meant to escape it is a livelock, and the
## only fix is a clock the keepalive cannot reach.
var _sheet_age := 0.0
## Which GameKit callback delivered this match's packets. See `_note_delivery`.
var _delivery := ""

## Who an outstanding invitation went to, so a screen can name them instead of
## saying "waiting" at nobody in particular.
var invited := ""

## The opponent's Game Center name, for the board to be labelled with.
##
## `GKMatch.players` is everybody in the match *except* this device, which in a
## two-player game is exactly one person — so there is no ambiguity about whose
## name this is. Read once when the roster settles rather than per frame: the
## match holds it, but a board labelled from a live lookup would go blank the
## instant somebody disconnected, which is the moment you most want their name
## still on it.
var peer_name := ""


## Which network a match runs over. Game Center still signs the player in on
## Apple devices either way — leaderboards, achievements and cloud saves all
## read `local_player` from here — but only one of the two carries matches.
enum Transport { GAME_CENTER, EOS }
var transport: int = Transport.GAME_CENTER


## Whether versus can run on this device at all, over either network.
func available() -> bool:
	return eos_possible() or game_center_available()


## Whether this build can talk to Game Center at all.
##
## Asking `ClassDB.can_instantiate` is not enough: the desktop stub registers
## every class and answers yes, then refuses to construct them and hands back
## null. So the platform is checked first and the construction is checked after
## — which is what lets the whole file stay uncommented while the game runs on
## a PC with multiplayer simply switched off.
func game_center_available() -> bool:
	if not (OS.get_name() in ["iOS", "macOS"]):
		return false
	return ClassDB.can_instantiate("GameCenterManager")


## Whether matches can go over Epic: credentials filled in, cross-play switched
## on, and the EOS extension actually loaded in this build.
func eos_possible() -> bool:
	return EOSConfig.CROSSPLAY and EOSConfig.is_configured() \
		and ClassDB.class_exists("EOSGMultiplayerPeer")


func _ready() -> void:
	transport = Transport.EOS if eos_possible() else Transport.GAME_CENTER
	print("[MP] matches go over %s" % Transport.keys()[transport])
	if transport == Transport.EOS:
		# Nothing to wait for: Epic signs in on the first search rather than at
		# launch, so a player who never opens versus never touches Epic at all.
		_set_state(State.READY, "ready")
		# Deferred so the game's own `_ready` has connected `invite_offered` —
		# autoloads are ready before the main scene is.
		_check_link.call_deferred(true)
	if not game_center_available():
		if transport == Transport.GAME_CENTER:
			_set_state(State.OFF, "multiplayer needs an Apple device")
		return
	game_center = Apple.make("GameCenterManager")
	if game_center == null:
		if transport == Transport.GAME_CENTER:
			_set_state(State.OFF, "Game Center is unavailable on this build")
		return
	game_center.authentication_result.connect(_on_authenticated)
	game_center.authentication_error.connect(_on_auth_failed)
	if transport == Transport.GAME_CENTER:
		_set_state(State.AUTHENTICATING, "signing in to Game Center")
	game_center.authenticate()


func _process(delta: float) -> void:
	# Before every early return below, because an invitation is held across all
	# of these states and the clock on it belongs to the sender rather than to
	# whatever this device happens to be doing. See `INVITE_HOLD`.
	if invite_waiting():
		_invite_age += delta
		if _invite_age >= INVITE_HOLD:
			print("[MP] invite from '%s' expired unanswered" % invite_from)
			_clear_invite()

	if transport == Transport.EOS:
		_eos_process(delta)

	if state == State.CONNECTING:
		_wait_age += delta
		if _quick_joining and _wait_age >= QUICK_CONNECT_TIMEOUT:
			_skip_dead_room()
			return
		# Poll rather than trust `player_changed` alone: if both players were
		# already attached when the match arrived, that signal has nothing left
		# to fire and the only thing that ever moves is the count.
		_check_connected()
		if state == State.CONNECTING and _wait_age >= CONNECT_TIMEOUT:
			_fail("the other player never joined")
		return

	if state != State.HANDSHAKING:
		return
	_wait_age += delta
	_hello_timer -= delta

	# Apple's sheet is still over this device, so this end is not ready to play
	# even though the match is perfectly connected underneath. Saying so keeps
	# the peer waiting instead of starting without us — see `_native_sheet_up`.
	if _native_sheet_up:
		_sheet_age += delta
		# Grace spent. The sheet is staying, so stop making the other player pay
		# for it: play the match and let the sheet be a tap in the way.
		#
		# Measured on `_sheet_age`, never on `_wait_age` — the peer's `holding`
		# packets reset that one, and this is the timer whose whole job is to
		# escape a peer who is holding.
		if _sheet_age >= SHEET_GRACE:
			print("[GC] native: sheet still up after %.0fs — starting anyway" % SHEET_GRACE)
			_native_sheet_up = false
			_hello_timer = 0.0
			_set_state(State.HANDSHAKING, "saying hello")
			return
		if _hello_timer <= 0.0:
			_hello_timer = HELLO_EVERY
			_send_raw({"type": "holding"})
		return

	# Repeat the hello until the other end answers. A single one sent the
	# instant the match arrives can be dropped while the peer is still
	# attaching, and a dropped hello is a game that never starts.
	if _hello_timer <= 0.0:
		_hello_timer = HELLO_EVERY
		_hellos_sent += 1
		_send_raw(_hello("hello"))
		# Every fourth, so a stalled handshake leaves a heartbeat in the device
		# log rather than fifteen seconds of nothing followed by a failure with
		# no history behind it.
		if _hellos_sent % 4 == 1:
			print("[GC] hello #%d sent at %.1fs — heard back: %s" % [
				_hellos_sent, _wait_age, _peer_said_hello])
	if _wait_age >= HANDSHAKE_TIMEOUT:
		_fail("the other player never answered after %d hellos" % _hellos_sent)


# ----------------------------------------------------------------- sign-in

## Apple calls its authentication handler more than once — on sign-in, and again
## whenever the account changes underneath the app — so this has to be safe to
## run twice, and it has to believe `signed_in` when it says no.
func _on_authenticated(signed_in: bool = true) -> void:
	if not signed_in:
		local_player = null
		if transport == Transport.EOS:
			# Matches do not need Game Center here. Leaderboards and cloud saves
			# do, and they listen to this signal to notice the sign-out.
			state_changed.emit(status)
			return
		_local_id = ""
		_set_state(State.OFF, "not signed in to Game Center")
		return

	local_player = game_center.local_player
	if transport == Transport.EOS:
		# Signed in for everything except matches. `_local_id` is the Epic id
		# over EOS, so it is left alone, and no invite listener is registered:
		# a Game Center invite would open a match on the wrong network.
		state_changed.emit(status)
		return
	if local_player != null:
		_local_id = _player_id(local_player)
		# Without this, an invite accepted from outside the app arrives nowhere
		# and the invite half of matchmaking looks broken while auto-match works.
		if not local_player.invite_accepted.is_connected(_on_invite_accepted):
			local_player.invite_accepted.connect(_on_invite_accepted)
		# The other direction: a player picking friends in the Game Center app
		# and starting a Word Wars match from there. Apple has already run the
		# friend picker at that point and just hands us the names, which is the
		# whole invite-sending flow with none of the UI we cannot dismiss.
		if not local_player.match_requested_with_other_players.is_connected(
				_on_match_requested):
			local_player.match_requested_with_other_players.connect(_on_match_requested)
		local_player.register_listener()
	# Only announce readiness from a standing start. A re-authentication that
	# lands mid-match must not knock the match back to the title screen.
	if state == State.OFF or state == State.AUTHENTICATING:
		_set_state(State.READY, "signed in")


func _on_auth_failed(message: String) -> void:
	if transport == Transport.EOS:
		push_warning("Game Center: authentication failed — %s" % message)
		state_changed.emit(status)
		return
	_set_state(State.OFF, "Game Center sign-in failed")
	push_warning("Game Center: authentication failed — %s" % message)


## Game Center identifies a player by `game_player_id`. Falls back to the display
## name, which is not guaranteed unique but is only ever used to break a tie
## between exactly two people.
func _player_id(p) -> String:
	if p == null:
		return ""
	if String(p.game_player_id) != "":
		return String(p.game_player_id)
	return String(p.display_name)


## The shared matchmaker, built on first use. Kept because Apple's `cancel()`
## applies to the shared instance and we need to be able to call it.
func _mm():
	if _matchmaker == null:
		_matchmaker = Apple.make("GKMatchmaker")
	return _matchmaker


# ------------------------------------------------------------- matchmaking

func _request(for_players: Array = []):
	var request = Apple.make("GKMatchRequest")
	request.min_players = 2
	request.max_players = 2
	request.invite_message = "Join my Word Wars battle!"
	if not for_players.is_empty():
		request.recipients = for_players
	return request


## Auto-match: ask Game Center for anyone else looking for a game. Headless, so
## the game's own screen keeps saying what is happening.
func find_match() -> void:
	if not available():
		_set_state(State.OFF, "multiplayer needs an Apple device")
		return
	if state != State.READY:
		return
	invited = ""
	if transport == Transport.EOS:
		_eos_find()
		return
	# Starting a search is a decision to stop waiting on Apple's screen. The flag
	# is what the handshake holds for, and left standing after a sheet that never
	# appeared it would make the next match wait `SHEET_GRACE` for nothing.
	_native_sheet_up = false
	_set_state(State.MATCHMAKING, "finding an opponent")
	_mm().find_match(_request(), _on_found_match)


# ------------------------------------------------- Apple's own matchmaker
#
# Under test, deliberately kept beside the headless path rather than replacing
# it. This is the screen with SharePlay, Invite Friends and Quick Match on it,
# and Invite Friends is the only route in the whole API that reaches somebody who
# is not already a Game Center friend: Apple sends them a link, by Messages, to
# any contact. That is worth a great deal more than the friend picker, which
# needs a mutual friend request and a permission prompt before it shows anybody.
#
# One thing is known to be wrong with it and it is the plugin's, not Apple's.
# Apple requires the app to dismiss this sheet from `didFind`; the plugin's
# `didFind` builds the match, hands it over and returns without dismissing —
# checked by disassembling the shipped framework, not by reading its source,
# which we do not have. Only `wasCancelled` dismisses.
#
# What that means in practice was never actually observed, because until the
# `data_received_for_recipient_from_player` fix no match ever finished its
# handshake — so there was never a game behind the sheet to be hidden by it. The
# whole point of this pass is to find out what the sheet does now that there is.
#
# The cancel handler was disassembled too: it dismisses the view controller and
# never touches the `GKMatch` — no `disconnect`, no reference to the match at
# all. So a match already delivered by `didFind` survives the user closing the
# sheet, which is what `_on_native_cancelled` relies on.

## Apple's matchmaking modes. 0 is the full screen; the rest narrow it down.
enum Native { DEFAULT, NEARBY_ONLY, AUTOMATCH_ONLY, INVITE_ONLY }

## Held because the sheet is presented by an object Apple does not retain for us.
var _native_vc = null  # GKMatchmakerViewController


## Put Apple's matchmaking screen up.
func open_native_matchmaker(mode: int = Native.DEFAULT) -> void:
	if not available():
		_set_state(State.OFF, "multiplayer needs an Apple device")
		return
	if state != State.READY:
		print("[GC] native: refused — state is %s, not READY" % State.keys()[state])
		return
	# Asked for twice, and allowed. It is tempting to refuse here — a second
	# controller over the first, with the first one's signals still connected,
	# is not tidy — but refusing is how this button goes dead. If the sheet did
	# not come up, `_native_sheet_up` is true and wrong, and a guard on it turns
	# the one press that could recover into another press that does nothing.
	#
	# Stacking is survivable: the old controller is RefCounted and goes when the
	# reference below is replaced, and `_on_native_match` already refuses a
	# second delivery of a match it is holding.
	if _native_sheet_up:
		print("[GC] native: a sheet was already asked for — asking again")

	_native_vc = Apple.call_static("GKMatchmakerViewController", "create_controller",
		[_request()])
	if _native_vc == null:
		print("[GC] native: create_controller returned null")
		_set_state(State.READY, "Game Center would not open its own screen")
		return

	_native_vc.matchmaking_mode = mode
	_native_vc.did_find_match.connect(_on_native_match)
	_native_vc.cancelled.connect(_on_native_cancelled)
	_native_vc.failed_with_error.connect(_on_native_failed)

	invited = ""
	_native_sheet_up = true
	_sheet_age = 0.0
	# Deliberately still READY, and this is the fix for a bug that read as the
	# wrong door entirely.
	#
	# This used to go to MATCHMAKING the instant `present()` was called. But
	# `present()` is fire-and-forget: it returns nothing, and if the sheet does
	# not actually come up, not one of `did_find_match`, `cancelled` or
	# `failed_with_error` will ever fire. There is no timeout on MATCHMAKING —
	# `_process` returns before reaching any clock unless the state is CONNECTING
	# or HANDSHAKING — so the game sat in a search that was not running, behind a
	# sheet that was not there, forever. From the sofa that is indistinguishable
	# from having pressed Quick Match, which is exactly what it was reported as.
	#
	# Staying READY costs nothing when the sheet does appear, because the sheet is
	# covering this screen anyway and Apple's own callbacks move the state on the
	# moment anything happens. And when the sheet does *not* appear, the lobby is
	# still a lobby: three live doors and an honest line, rather than a Stop
	# button for a search nobody started.
	# Phrased as the ask rather than the result, because this line is only ever
	# read in the case where the result did not happen: if the sheet is up it is
	# covering the screen this is drawn on.
	_set_state(State.READY, "asked Game Center to open its own screen")
	print("[GC] native: presenting (mode %d)" % mode)
	_native_vc.present()
	print("[GC] native: present() returned — sheet should be up")


## Apple found somebody. Same arrival as every other route, minus the error
## argument this signal does not carry.
## Apple's start button routes here too.
##
## With `min_players` and `max_players` both at two the match is full the instant
## the second player attaches, so GameKit fires this by itself and the sheet's
## start button has nothing left to decide — which is why, in testing, the match
## began without anybody pressing it. Pressing it anyway would deliver the same
## match a second time, and `_on_found_match` would take that at face value:
## reconnect every signal, reset the handshake, and throw away a match that was
## already playing. It is refused, and reported, because what that button does is
## still unknown and this is where we will find out.
func _on_native_match(found) -> void:
	if current_match != null:
		print("[GC] native: did_find_match again with a match already in hand — ignoring (same match: %s)"
			% (found == current_match))
		return
	print("[GC] native: did_find_match — the sheet is Apple's to close from here")
	_on_found_match(found, null)


## The user closed the sheet.
##
## Which may mean they gave up, or may be the only way this build has of getting
## Apple's sheet off the screen once a match has started behind it — the plugin
## never dismisses from `didFind`, so closing it by hand is the documented
## workaround rather than an accident. A match already in hand is therefore kept,
## not cancelled: the cancel handler was checked and it does not touch the match.
func _on_native_cancelled(detail: String = "") -> void:
	_native_sheet_up = false
	if current_match != null:
		# The sheet is down and this end is finally ready to play. The hello goes
		# out now rather than on the next tick, so the pair converges as fast as
		# it did in testing — 47ms, measured — and both matches start together.
		print("[GC] native: sheet dismissed with a match in hand — releasing the handshake (%s)" % detail)
		_hello_timer = 0.0
		_wait_age = 0.0
		if state == State.HANDSHAKING:
			_set_state(State.HANDSHAKING, "saying hello")
			_send_raw(_hello("hello"))
			_begin_if_ready()
		return
	print("[GC] native: cancelled with no match — giving up (%s)" % detail)
	_native_vc = null
	_set_state(State.READY, "matchmaking cancelled")
	match_ended.emit("cancelled")


func _on_native_failed(message: String) -> void:
	print("[GC] native: failed — %s" % message)
	_native_sheet_up = false
	_native_vc = null
	_set_state(State.READY, "Game Center could not set that up")
	match_ended.emit("matchmaking failed")


## Invite specific people. Same call — Game Center sends the invitations itself
## when the request carries recipients, and hands back the match once they
## accept.
func invite_players(players: Array) -> void:
	if not available() or players.is_empty():
		return
	if state != State.READY:
		return
	invited = _names_of(players)
	var waiting := "waiting for them to accept"
	if invited != "":
		waiting = "waiting for %s to accept" % invited
	_set_state(State.MATCHMAKING, waiting)
	_mm().find_match(_request(players), _on_found_match)


## Whoever we are inviting, in a form a status line can use. Two names joined,
## and anything longer counted — a request can in principle carry a whole friend
## list, and a status line is one line.
func _names_of(players: Array) -> String:
	var names: PackedStringArray = []
	for p in players:
		if Apple.is_a(p, "GKPlayer"):
			var n := String(p.display_name)
			if n != "":
				names.append(n)
	if names.is_empty():
		return ""
	if names.size() == 1:
		return names[0]
	if names.size() == 2:
		return "%s and %s" % [names[0], names[1]]
	return "%s and %d others" % [names[0], names.size() - 1]


## Stop looking. Safe to call when nothing is in flight.
func cancel_find() -> void:
	if state != State.MATCHMAKING:
		return
	if transport == Transport.EOS:
		_eos_close()
	else:
		_mm().cancel()
	invited = ""
	_set_state(State.READY, "matchmaking cancelled")
	match_ended.emit("cancelled")


## Someone chose friends in the Game Center app and asked for a match. The
## picking is already done, so this is just `invite_players` with Apple's list.
func _on_match_requested(_player, recipients: Array) -> void:
	invite_players(recipients)


# ------------------------------------------------------- an invite arriving
#
# ## GameKit will not tell us an invitation arrived
#
# It is worth being plain about this, because the obvious feature — a banner in
# the game the moment somebody invites you — cannot be built, and the reason is
# not ours. Apple's `GKInviteEventListener` has exactly two callbacks:
# `didAccept` and `didRequestMatchWithRecipients`. There is no "an invite is
# waiting" event in the protocol, and the plugin's `GKLocalPlayer` exposes no
# such signal because there is none to expose. iOS draws its own banner when an
# invitation lands on a foregrounded app; tapping it is what reaches us, and by
# then the player has already said yes.
#
# ## So the question we ask is the one we are actually entitled to ask
#
# What the player said yes to is "open Word Wars and join this". What they were
# not asked, and could not have been, is whether the run currently on screen is
# worth abandoning for it — and this is the first and only point at which the
# game knows both halves. It used to answer for them: `leave_match()` on the
# spot, mid-daily, mid-match, with the score gone. A tap on a system banner is
# not consent to throw away a run that was three words from a personal best.
#
# So the invitation is held rather than taken, and `game.gd` decides. On a title
# screen it is taken immediately — there is nothing to interrupt, and a
# confirmation over an empty screen is friction for its own sake. Mid-run it
# becomes a banner with the sender's name on it, which is as close to the thing
# that cannot be built as the API allows.
#
# ## It is held on a clock, because the other end is waiting
#
# A `GKInvite` is not a message that sits in a queue. The sender is in Apple's
# matchmaker watching a spinner, and an invitation nobody answers fails on their
# device rather than ours. So the hold is short and it expires by itself: better
# to drop the banner and let them try again than to take an invite that died
# while the question was on screen.

## How long an unanswered invitation is kept. Short on purpose — see above; the
## person who sent it is looking at a spinner for every second of this.
const INVITE_HOLD := 20.0

## The invitation in hand, if any, and who sent it. `invite_from` is kept
## separately because it is what a banner prints, and reading a name off a
## `GKInvite` from drawing code would put a GameKit class in `game.gd`.
var _held_invite = null  # GKInvite
## The same thing over Epic: a room code that arrived in a link. Held exactly
## like a `GKInvite` so the game's banner and its title-screen shortcut work
## unchanged — only what accepting it does is different.
var _held_code := ""
var invite_from := ""
var _invite_age := 0.0


## Whether there is an invitation waiting on an answer.
func invite_waiting() -> bool:
	return _held_invite != null or _held_code != ""


## How much of the hold is left, for a banner to run a bar off. Zero when there
## is nothing waiting.
func invite_left() -> float:
	if not invite_waiting():
		return 0.0
	return maxf(0.0, INVITE_HOLD - _invite_age)


## Somebody accepted an invitation — from a notification, or by tapping a link
## Apple's screen texted them. This is the whole of the receiving end and it has
## no sheet in it: the invitee never sees Apple's matchmaker, only the match.
func _on_invite_accepted(_player, invite) -> void:
	if not available() or invite == null:
		return
	# A second invitation while one is already held replaces it. Two banners is
	# not a thing this game draws, and the newer one is the one whose sender is
	# still waiting.
	_held_invite = invite
	_invite_age = 0.0
	invite_from = ""
	if invite.sender != null:
		invite_from = String(invite.sender.display_name)
	print("[GC] invite held from '%s' — waiting on an answer" % invite_from)
	invite_offered.emit(invite_from)


## Take it. Whatever was running is dropped here rather than by the caller, so
## there is no window in which the match is gone and the invite has not been
## acted on.
func accept_invite() -> void:
	if _held_code != "":
		var code := _held_code
		_clear_invite()
		if current_match != null or state != State.READY:
			leave_match()
		join_code(code)
		return
	if _held_invite == null:
		return
	var invite = _held_invite
	_clear_invite()
	if not available():
		return
	if current_match != null:
		leave_match()
	_set_state(State.MATCHMAKING, "joining the invite")
	_mm().match_for_invite(invite, _on_found_match)


## Leave it. The sender is not told — there is no reject call on this path, only
## on a lobby invite — so from their side this is indistinguishable from nobody
## picking up, which is what it is.
func decline_invite() -> void:
	if not invite_waiting():
		return
	print("[MP] invite from '%s' declined" % invite_from)
	_clear_invite()


## There is deliberately no "invite closed" signal to go with `invite_offered`.
## Every screen reads `invite_waiting()` as it draws, so an invitation that ages
## out simply stops being drawn — a second copy of that fact, delivered late,
## is the thing that goes stale.
func _clear_invite() -> void:
	_held_invite = null
	_held_code = ""
	invite_from = ""
	_invite_age = 0.0


## The whole of what Apple said, for the log. `str()` on a `GKError` prints the
## object rather than the failure, which is how a real error code once went
## unseen for a fortnight.
func _error_text(error) -> String:
	if not Apple.is_a(error, "GKError"):
		return str(error)
	var e = error
	return "code %d (%s) — %s" % [e.code, e.domain, e.message]


# ------------------------------------------------------- the match itself

## Both matchmaking calls land here: `(GKMatch match, Variant error)`, with
## exactly one of the two non-null.
func _on_found_match(found, error = null) -> void:
	if error != null:
		push_warning("Game Center: matchmaking failed — %s" % str(error))
		_set_state(State.READY, "could not find a match")
		match_ended.emit("matchmaking failed")
		return
	if found == null:
		_set_state(State.READY, "could not find a match")
		match_ended.emit("matchmaking failed")
		return

	current_match = found
	current_match.data_received.connect(_on_data)
	# GameKit has two data callbacks and only ever calls one of them.
	#
	# `match(_:didReceive:fromRemotePlayer:)` is the obvious one and it is the
	# only one this connected for weeks. But a delegate that *also* implements
	# `match(_:didReceive:forRecipient:fromRemotePlayer:)` gets the recipient
	# form instead — Apple prefers the more specific method and never calls the
	# plain one. This plugin's `GKMatch.Proxy` implements both, so every packet
	# that has ever been sent to this game arrived on the signal below, with
	# nothing listening to it.
	#
	# It presented as a network fault and is not one: sending returned OK on
	# every call, the roster was populated and named, and thirty hellos went out
	# over fifteen seconds while `_on_data` was never entered once. The plugin's
	# own guide connects both signals, which is the tell.
	current_match.data_received_for_recipient_from_player.connect(_on_data_for)
	current_match.player_changed.connect(_on_player_changed)
	current_match.did_fail_with_error.connect(_on_match_error)

	_peer_id = ""
	peer_name = ""
	_peer_said_hello = false
	_wait_age = 0.0
	_hellos_sent = 0
	_delivery = ""
	_set_state(State.CONNECTING, "connecting")
	_check_connected()


## A match can arrive before its players do. Nothing may be sent until the count
## reaches zero, so this is the gate everything else waits behind.
func _check_connected() -> void:
	if current_match == null:
		return
	if state == State.HANDSHAKING or state == State.PLAYING:
		return
	if current_match.expected_player_count > 0:
		if status != "waiting for the other player":
			_set_state(State.CONNECTING,
				"waiting for the other player")
			print("[GC] still expecting %d player(s)"
				% current_match.expected_player_count)
		return
	# Nobody else is coming, so stop Game Center looking for more.
	_mm().finish_matchmaking(current_match)
	_wait_age = 0.0
	_hello_timer = 0.0
	_send_failures = 0
	# `expected_player_count` reaching zero only means GameKit has stopped
	# recruiting. `players` is who is actually attached, and a broadcast to an
	# empty roster goes to nobody while reporting nothing wrong — which is
	# indistinguishable, from this side, from a peer who is ignoring us.
	var who: PackedStringArray = []
	for p in current_match.players:
		if Apple.is_a(p, "GKPlayer"):
			who.append(String(p.display_name))
	print("[GC] match ready — %d attached: %s" % [
		who.size(), ", ".join(who) if not who.is_empty() else "NOBODY"])
	# One opponent, so the first name is theirs. Kept even if the roster later
	# empties, because a board that loses its label the moment somebody drops is
	# a board you cannot make sense of afterwards.
	if not who.is_empty():
		peer_name = who[0]
	_set_state(State.HANDSHAKING,
		"waiting for Game Center to close" if _native_sheet_up else "saying hello")
	# The peer's hello can arrive while this device is still CONNECTING, in which
	# case `_begin_if_ready` was called too early to do anything and the answer is
	# already sitting here. Without this the match waits out another round trip
	# for news it has already had.
	_begin_if_ready()


func _on_player_changed(player, connected: bool) -> void:
	if connected:
		_check_connected()
		return
	# In a two-player match, one leaving is the end of it.
	if state == State.PLAYING or state == State.HANDSHAKING:
		_fail("%s left" % String(player.display_name))


func _on_match_error(message: String) -> void:
	push_warning("Game Center: match error — %s" % message)
	_fail("the connection dropped")


## The recipient-addressed form of the same delivery. Everything this game sends
## is a broadcast, so the recipient is always us and is thrown away — the point
## is only that the packet arrives at all.
func _on_data_for(data: PackedByteArray, _recipient, from) -> void:
	_note_delivery("for-recipient")
	_on_data(data, from)


## Which of GameKit's two callbacks is actually feeding us, said once per match.
## Recorded because the answer is not documented anywhere we control and it is
## the whole difference between a working match and a silent one — if a future
## iOS flips it back to the plain form, this line says so on the first packet
## rather than after another fortnight of "the other player never answered".
func _note_delivery(how: String) -> void:
	if _delivery == how:
		return
	_delivery = how
	print("[GC] data arriving via %s" % how)


func _on_data(data: PackedByteArray, _player = null) -> void:
	_note_delivery(_delivery if _delivery != "" else "from-remote-player")
	var packet = JSON.parse_string(data.get_string_from_utf8())
	if typeof(packet) != TYPE_DICTIONARY:
		return
	var kind := String(packet.get("type", ""))

	# They are connected and willing but Apple's sheet is still over their screen.
	# Nothing to do but wait, and say so — the point of the packet is that it
	# resets the clock, so a peer who takes a while to find the X does not get
	# thrown out for never answering.
	if kind == "holding":
		_wait_age = 0.0
		if status != "waiting for them to close Game Center":
			print("[GC] peer is holding — their Game Center sheet is still up")
			_set_state(State.HANDSHAKING, "waiting for them to close Game Center")
		return

	if kind == "hello" or kind == "hello_back":
		# Logged once. A handshake that times out is either "we sent thirty and
		# heard nothing" or "we heard them and still did not start", and those are
		# opposite faults that look identical from the outside — one line here
		# decides which, and repeating it thirty times would bury the rest.
		if not _peer_said_hello:
			print("[GC] heard %s from %s" % [kind, packet.get("id", "?")])
		_peer_id = String(packet.get("id", ""))
		# Game Center names the opponent from its roster; Epic has no roster
		# worth the name, so over EOS the name rides in the hello instead.
		if peer_name == "":
			peer_name = String(packet.get("name", "")).strip_edges().substr(0, 14)
		# A build that speaks a different match protocol would play a match in
		# which half the packets mean nothing. Refuse it while it is still a
		# lobby. Absent means a build from before this field, which is 1.
		if int(packet.get("v", 1)) != PROTOCOL:
			_fail("they are on a different version of Word Wars — update both")
			return
		# Answer immediately as well as on the timer, so the pair converges in
		# one round trip rather than waiting out another tick. Only `hello` is
		# answered — replying to a reply is how two devices talk forever.
		#
		# Except while holding: answering a hello is what starts their match, and
		# this end is not ready to play yet. They are told to keep waiting
		# instead, and get their answer the moment the sheet comes down.
		if kind == "hello":
			_send_raw({"type": "holding"} if _native_sheet_up
				else _hello("hello_back"))
		_peer_said_hello = true
		_begin_if_ready()
		return
	if kind == "bye":
		_fail("the other player left")
		return
	if state == State.PLAYING:
		data_received.emit(packet)


func _begin_if_ready() -> void:
	if state != State.HANDSHAKING or not _peer_said_hello:
		return
	# Connected, agreed, and still behind Apple's sheet. Starting here is what
	# put one player eight seconds into a match the other could not see.
	if _native_sheet_up:
		return
	_set_state(State.PLAYING, "playing")
	match_started.emit()


## True when this device owns the coin-flip decisions — anything both ends must
## agree on and neither can derive. Decided by sorting the two ids, so both
## reach the same answer with no host and no extra round trip.
func is_first() -> bool:
	if _peer_id == "" or _local_id == "":
		return true
	return _local_id < _peer_id


func leave_match() -> void:
	# Cleared before the early return as well. Left standing, the next match made
	# any other way would hold for a sheet that is not there and never start.
	_native_sheet_up = false
	if state == State.MATCHMAKING:
		cancel_find()
		return
	if current_match != null:
		_send_raw({"type": "bye"})
		_drop_match()
	_peer_id = ""
	_peer_said_hello = false
	invited = ""
	if available():
		_set_state(State.READY, "ready" if transport == Transport.EOS else "signed in")
	else:
		_set_state(State.OFF, "multiplayer needs an Apple device")


func _fail(reason: String) -> void:
	_drop_match()
	_peer_said_hello = false
	invited = ""
	_native_sheet_up = false
	_set_state(State.READY if available() else State.OFF, reason)
	match_ended.emit(reason)


# --------------------------------------------------------------------- Epic
#
# Cross-play. Over EOS the lobby is only a meeting point: two devices find each
# other through it, open a P2P connection host-to-client, and from then on the
# connection is a bag of bytes exactly like a `GKMatch` — so everything below
# `_on_data`, the hello, the holding logic, `is_first`, all runs unchanged.
#
#   quick match   search the QUICK_BUCKET for a room with a seat; join it, or
#                 open one and wait there
#   invite        open a room whose bucket is a fresh five-letter code, and
#                 hand the code to the share sheet as a link
#   join by code  search that bucket, join the room it finds
#
# Signed in with a Device ID: no Epic account, no login screen. The id is
# recreated on every launch, so it cannot follow a player between sessions.
#
# The lobby is closed once the two ends are connected. The match does not need
# it, and a full room sitting in the directory is a room somebody else's search
# will keep finding and failing to join.

## Answered once and then remembered: Epic's platform can only be created once
## per run, and signing in is a round trip nobody should pay twice.
var _eos_ready := false
var _eos_signing_in := false
## The room this device is in, host or client. An `HLobby`.
var _lobby = null
## The connection, before and during a match. It only becomes `current_match`
## once the other end is actually attached — `current_match != null` is how the
## rest of the game knows a versus match is live, and a host sitting alone in a
## room is not one.
var _eos_peer = null
## Whether the room we are sitting in is a quick-match room we opened.
var _quick_hosting := false
var _research_age := 0.0
var _researching := false
## Every async flow checks this after each await and gives up if it moved:
## cancelling, leaving and starting again all bump it, so a search that the
## player abandoned cannot come back three seconds later and join something.
var _attempt := 0

## The code of the invite room we are hosting, for the share link. Empty when
## there is none.
var invite_code := ""
## A room is open and its code can be shared. The link itself is `invite_link`.
signal invite_ready(code: String)

## A quick-match room whose host never answers. Rooms outlive the app that
## opened them — kill it while it waits and the room stays listed until Epic
## notices — so a stranger's search can land in one. Rather than make them sit
## out the full CONNECT_TIMEOUT, a quick match gives up on the room early, notes
## its owner, and looks again. A code join keeps the long wait: there, the room
## is the one the player asked for and there is nowhere else to go.
const QUICK_CONNECT_TIMEOUT := 8.0
var _quick_joining := false
var _dead_owners := {}

## How long a host waits alone in a quick-match room before looking again for
## somebody else doing the same. See `_eos_process`.
const RESEARCH_EVERY := 4.0
## A fresh room takes a few seconds to appear in search. Without retries a
## friend who taps the link the moment it arrives finds nothing.
const CODE_TRIES := 5
const CODE_GAP := 2.0


func invite_link(code: String = invite_code) -> String:
	return EOSConfig.INVITE_URL % code


## Room codes are typed by people, so case, spaces and dashes are forgiven.
## Anything outside the alphabet is dropped — it has no 0, O, 1 or I, so no
## real code can contain one.
static func clean_code(text: String) -> String:
	var out := ""
	for ch in text.strip_edges().to_upper():
		if EOSConfig.CODE_ALPHABET.contains(ch):
			out += ch
	return out.substr(0, EOSConfig.CODE_LENGTH)


## Open a room for a friend and wait in it. `invite_ready` fires once the code
## is live, which is the moment to put the share sheet up.
func host_invite() -> void:
	if transport != Transport.EOS or state != State.READY:
		return
	var attempt := _new_attempt()
	_set_state(State.MATCHMAKING, "opening a room")
	if not await _eos_sign_in(attempt):
		return
	var code := ""
	for _i in EOSConfig.CODE_LENGTH:
		code += EOSConfig.CODE_ALPHABET[randi() % EOSConfig.CODE_ALPHABET.length()]
	if await _eos_host(attempt, code):
		invite_code = code
		invited = "your friend"
		_set_state(State.MATCHMAKING, "room %s — waiting for your friend" % code)
		invite_ready.emit(code)


## Join a friend's room by its code, from a link or typed in.
func join_code(text: String) -> void:
	if transport != Transport.EOS or state != State.READY:
		return
	var code := clean_code(text)
	if code.length() != EOSConfig.CODE_LENGTH:
		_set_state(State.READY, "room codes are %d characters" % EOSConfig.CODE_LENGTH)
		return
	var attempt := _new_attempt()
	_set_state(State.MATCHMAKING, "looking for room %s" % code)
	if not await _eos_sign_in(attempt):
		return
	for i in CODE_TRIES:
		var found = await HLobbies.search_by_bucket_id_async(code)
		if _stale(attempt):
			return
		for lobby in (found if found != null else []):
			if lobby.available_slots > 0:
				await _eos_join(attempt, lobby)
				return
		if i < CODE_TRIES - 1:
			await get_tree().create_timer(CODE_GAP).timeout
			if _stale(attempt):
				return
	_eos_give_up("no room %s — check the code, or ask them to send a new one" % code)


## A code arrived from outside the game — a tapped link. Held as an invitation
## so the game decides when to take it; see the invite section above.
func offer_code(text: String) -> void:
	var code := clean_code(text)
	if transport != Transport.EOS or code.length() != EOSConfig.CODE_LENGTH:
		return
	_held_code = code
	_held_invite = null
	_invite_age = 0.0
	invite_from = "a friend"
	print("[MP] invite link held for room %s" % code)
	invite_offered.emit(invite_from)


## Did the game open from an invite link? Asked at launch and on every resume:
## a link tapped while the game is already running brings it to the front
## without a relaunch, so launch alone would miss it.
##
## Android hands the link to `GodotApp` (see tools/android-template.sh), which
## holds it until asked. On a desktop `--join=CODE` stands in for a link.
func _check_link(at_launch: bool = false) -> void:
	if transport != Transport.EOS:
		return
	var link := ""
	if OS.get_name() == "Android":
		var app = JavaClassWrapper.wrap("com.godot.game.GodotApp")
		if app != null:
			link = String(app.takeLink())
	if at_launch:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--join="):
				link = arg.substr(7)
	var code := code_from_link(link)
	if code != "":
		print("[MP] opened from an invite link — room %s" % code)
		offer_code(code)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		_check_link()


## The room code out of anything that might carry one: the page's link
## (`…/j/?c=K7QMX`), the app scheme (`wordwars://join/K7QMX`), or a bare code.
static func code_from_link(link: String) -> String:
	if link == "":
		return ""
	var at := link.find("c=")
	var raw := link.substr(at + 2).get_slice("&", 0) if at >= 0 \
		else link.strip_edges().get_slice("?", 0).trim_suffix("/").get_file()
	# Strict, unlike `clean_code`. That one forgives stray characters because a
	# person typing is making slips; here the text came from a clipboard and
	# could be anything, and forgiving it turned "nothing useful" into room
	# NTHNG. So only spaces and dashes may sit inside a code, and nothing else
	# may be left over.
	var bare := raw.strip_edges().replace(" ", "").replace("-", "").to_upper()
	if bare.length() != EOSConfig.CODE_LENGTH:
		return ""
	for ch in bare:
		if not EOSConfig.CODE_ALPHABET.contains(ch):
			return ""
	return bare


func _eos_find() -> void:
	var attempt := _new_attempt()
	_set_state(State.MATCHMAKING, "finding an opponent")
	if not await _eos_sign_in(attempt):
		return
	var open: Array = await _open_quick_rooms()
	if _stale(attempt):
		return
	if not open.is_empty():
		await _eos_join(attempt, open[0])
		return
	if await _eos_host(attempt, EOSConfig.QUICK_BUCKET):
		_quick_hosting = true
		_research_age = 0.0
		_set_state(State.MATCHMAKING, "waiting for an opponent")


## Quick-match rooms somebody else opened that still have a seat, oldest owner
## id first — the order both ends of a collision agree on, see `_eos_process`.
func _open_quick_rooms() -> Array:
	var found = await HLobbies.search_by_bucket_id_async(EOSConfig.QUICK_BUCKET)
	var open: Array = []
	for lobby in (found if found != null else []):
		if lobby.available_slots > 0 and lobby.owner_product_user_id != _local_id \
				and not _dead_owners.has(lobby.owner_product_user_id):
			open.append(lobby)
	open.sort_custom(func(a, b): return a.owner_product_user_id < b.owner_product_user_id)
	return open


## Bring Epic up and sign in, once per run. False, with the state already set
## to say why, if it could not.
func _eos_sign_in(attempt: int) -> bool:
	while _eos_signing_in:
		await get_tree().process_frame
	if _stale(attempt):
		return false
	if _eos_ready:
		return true
	_eos_signing_in = true
	var ok := await _eos_start()
	_eos_signing_in = false
	if _stale(attempt):
		return false
	if not ok:
		_eos_give_up("could not reach Epic — check your connection")
	return ok


func _eos_start() -> bool:
	if not await HPlatform.setup_eos_async(EOSConfig.make_credentials()):
		push_warning("EOS: platform setup failed")
		return false
	# Relayed only. A direct connection hands each player the other's IP
	# address; through Epic's relays neither sees it. The cost is a few tens of
	# milliseconds, which a word game does not feel.
	HP2P.set_relay_control(EOS.P2P.RelayControl.ForceRelays)
	# Presence needs an Epic account, which a Device ID sign-in does not have.
	HLobbies.presence_enabled = false
	# Epic insists on a display name for the sign-in; it is never shown to
	# anybody — the opponent's label comes from the hello.
	var shown := my_name()
	# Twice. The Device ID sign-in deletes and recreates the device's id, and a
	# second copy of the game doing the same at the same moment — a test rig, or
	# a relaunch on top of a dying process — gets DuplicateNotAllowed once.
	var signed := false
	for i in 2:
		signed = await HAuth.login_anonymous_async(shown if shown != "" else "Player")
		if signed:
			break
		await get_tree().create_timer(1.5).timeout
	if not signed:
		push_warning("EOS: sign-in failed — check the client policy allows Device ID and Lobbies")
		return false
	_local_id = HAuth.product_user_id
	_eos_ready = true
	print("[MP] signed in to Epic as %s" % _local_id)
	return true


## Open a room in `bucket` and wait in it with a server socket.
func _eos_host(attempt: int, bucket: String) -> bool:
	var opts := EOS.Lobby.CreateLobbyOptions.new()
	opts.bucket_id = bucket
	opts.max_lobby_members = 2
	opts.permission_level = EOS.Lobby.LobbyPermissionLevel.PublicAdvertised
	opts.presence_enabled = false
	var lobby = await HLobbies.create_lobby_async(opts)
	if _stale(attempt):
		if lobby != null:
			lobby.destroy_async()
		return false
	if lobby == null:
		_eos_give_up("Epic would not open a room")
		return false
	_lobby = lobby
	var peer = ClassDB.instantiate("EOSGMultiplayerPeer")
	if peer.create_server(EOSConfig.SOCKET) != OK:
		_eos_give_up("could not open a connection")
		return false
	# Otherwise every arrival waits on an accept that nothing ever sends.
	peer.set_auto_accept_connection_requests(true)
	_attach(peer)
	return true


## Take the seat in `lobby` and connect to whoever opened it.
func _eos_join(attempt: int, lobby) -> void:
	var joined = await HLobbies.join_async(lobby)
	if _stale(attempt):
		if joined != null:
			joined.leave_async()
		return
	if joined == null:
		# Almost always somebody else took the seat between our search and our
		# join. For a quick match that just means look again.
		if lobby.bucket_id == EOSConfig.QUICK_BUCKET:
			_set_state(State.READY, "ready")
			_eos_find()
		else:
			_eos_give_up("that room is full or closed")
		return
	_lobby = joined
	var peer = ClassDB.instantiate("EOSGMultiplayerPeer")
	if peer.create_client(EOSConfig.SOCKET, lobby.owner_product_user_id) != OK:
		_eos_give_up("could not reach the other player")
		return
	_attach(peer)
	_quick_joining = lobby.bucket_id == EOSConfig.QUICK_BUCKET
	_joined_owner = lobby.owner_product_user_id
	_wait_age = 0.0
	_set_state(State.CONNECTING, "connecting")


var _joined_owner := ""


func _skip_dead_room() -> void:
	print("[MP] quick room from %s never answered — looking again" % _joined_owner)
	_dead_owners[_joined_owner] = true
	_eos_close()
	_set_state(State.READY, "ready")
	_eos_find()


func _attach(peer) -> void:
	_eos_peer = peer
	peer.peer_connected.connect(_on_eos_connected)
	peer.peer_disconnected.connect(_on_eos_disconnected)


## Both ends land here once the connection is up — the host when the client
## attaches, the client when it reaches the host. From here it is the same
## handshake Game Center uses.
func _on_eos_connected(_id: int) -> void:
	if current_match != null:
		return
	print("[MP] connected over Epic")
	current_match = _eos_peer
	_quick_hosting = false
	_quick_joining = false
	invite_code = ""
	_close_lobby()
	_peer_id = ""
	peer_name = ""
	_peer_said_hello = false
	_hellos_sent = 0
	_send_failures = 0
	_wait_age = 0.0
	_hello_timer = 0.0
	_set_state(State.HANDSHAKING, "saying hello")


func _on_eos_disconnected(_id: int) -> void:
	if state in [State.HANDSHAKING, State.PLAYING, State.CONNECTING]:
		_fail("the other player left")


## Called every frame while Epic is the transport. The peer is not handed to
## Godot's multiplayer API — the packets are this file's own JSON, not RPCs — so
## polling and reading it is our job.
func _eos_process(delta: float) -> void:
	if _eos_peer != null:
		_eos_peer.poll()
		# `poll` can close the connection underneath us, and `_on_data` can end
		# the match, so the peer is re-read each time round.
		while _eos_peer != null and _eos_peer.get_available_packet_count() > 0:
			_on_data(_eos_peer.get_packet())

	# Two players pressing Quick Match in the same second both search, both find
	# nothing, and both open a room — then sit in separate rooms waiting for each
	# other. So a host alone in a quick room keeps looking, and if it finds
	# another open room whose owner sorts lower, it closes its own and goes
	# there. Both ends apply the same rule, so exactly one of them moves.
	if not _quick_hosting or state != State.MATCHMAKING or current_match != null:
		return
	_research_age += delta
	if _research_age < RESEARCH_EVERY or _researching:
		return
	_research_age = 0.0
	_researching = true
	var attempt := _attempt
	var open: Array = await _open_quick_rooms()
	_researching = false
	if _stale(attempt) or not _quick_hosting or current_match != null:
		return
	if not open.is_empty() and String(open[0].owner_product_user_id) < _local_id:
		print("[MP] another quick room is waiting — moving to it")
		var there = open[0]
		# `_eos_close` retires the current attempt, so the move is a new one.
		_eos_close()
		await _eos_join(_attempt, there)


func _eos_send(bytes: PackedByteArray, reliable: bool) -> int:
	if _eos_peer == null:
		return ERR_UNCONFIGURED
	_eos_peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable \
		else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
	_eos_peer.set_target_peer(MultiplayerPeer.TARGET_PEER_BROADCAST)
	return _eos_peer.put_packet(bytes)


## Hang up and leave the room, whatever stage things were at.
func _eos_close() -> void:
	_attempt += 1
	_quick_hosting = false
	_quick_joining = false
	invite_code = ""
	if _eos_peer != null:
		# Closed on the next frame, never here. The commonest way to arrive is a
		# `bye` read out of the packet loop in `_eos_process`, and closing an
		# EOSG peer from inside that loop segfaults — measured, on the first
		# match that ever ended. Deferred, nothing is mid-read when it goes.
		var peer = _eos_peer
		_eos_peer = null
		for sig in [[peer.peer_connected, _on_eos_connected],
				[peer.peer_disconnected, _on_eos_disconnected]]:
			if (sig[0] as Signal).is_connected(sig[1]):
				(sig[0] as Signal).disconnect(sig[1])
		peer.close.call_deferred()
	_close_lobby()


## Fire-and-forget: the requests go out before the first await, and nothing
## that calls this should have to become async to do it.
func _close_lobby() -> void:
	if _lobby == null:
		return
	var lobby = _lobby
	_lobby = null
	if lobby.is_owner():
		lobby.destroy_async()
	else:
		lobby.leave_async()


func _eos_give_up(reason: String) -> void:
	_eos_close()
	invited = ""
	_set_state(State.READY, reason)
	match_ended.emit(reason)


func _new_attempt() -> int:
	_attempt += 1
	return _attempt


## Whether an async flow has been overtaken — cancelled, restarted, or left.
func _stale(attempt: int) -> bool:
	return attempt != _attempt or state == State.READY or state == State.OFF


# ------------------------------------------------------------------ sending

func send_event(type: String, payload: Dictionary = {}) -> void:
	if state != State.PLAYING:
		return
	_send_raw({"type": type, "payload": payload})


## The board mirror, fifteen times a second. Sent unreliably on purpose: it is a
## snapshot of the whole board, so a dropped one is corrected by the next one a
## sixteenth of a second later — whereas queueing them reliably would build a
## backlog that arrives late and animates the opponent playing the past.
func send_state(payload: Dictionary) -> void:
	if state != State.PLAYING or current_match == null:
		return
	_send({"type": "state", "payload": payload}, false)


func _send_raw(packet: Dictionary) -> void:
	_send(packet, true)


## Every outgoing packet, so one place can notice that sending is failing.
##
## `send_data_to_all_players` returns an `Error` and this used to drop it on the
## floor. That is how a handshake which never left the device looked exactly like
## a peer who never answered: thirty hellos, no error anywhere, and a log whose
## only evidence was that nothing came back. The two have opposite fixes.
func _send(packet: Dictionary, reliable: bool) -> void:
	if current_match == null:
		return
	var bytes := JSON.stringify(packet).to_utf8_buffer()
	var err: int
	if transport == Transport.EOS:
		err = _eos_send(bytes, reliable)
	else:
		err = current_match.send_data_to_all_players(bytes,
			Apple.k("GKMatch", "RELIABLE" if reliable else "UNRELIABLE"))
	if err == OK:
		return
	_send_failures += 1
	# The board mirror goes out fifteen times a second, so a broken channel would
	# bury the whole log inside a second. Loud at first, then a heartbeat.
	if _send_failures <= 3 or _send_failures % 30 == 0:
		print("[GC] send failed (error %d) on '%s' — %d failed so far" % [
			err, packet.get("type", "?"), _send_failures])
		push_warning("Game Center: send failed — error %d" % err)


## The hello, and its answer. `name` and `v` are new with cross-play; a Game
## Center build from before them simply ignores both.
func _hello(kind: String) -> Dictionary:
	return {"type": kind, "id": _local_id, "name": my_name(), "v": PROTOCOL}


## What the other player sees this board called. Game Center's own name where
## there is one; otherwise nothing, and the far side falls back to OPPONENT.
func my_name() -> String:
	if local_player != null:
		return String(local_player.display_name)
	return ""


## Close whatever the match is running over. Both transports, because `_fail`
## and `leave_match` are shared and must not care which one is in use.
func _drop_match() -> void:
	if transport == Transport.EOS:
		_eos_close()
	elif current_match != null:
		current_match.disconnect()
	current_match = null


func in_match() -> bool:
	return state == State.PLAYING


func _set_state(next: int, text: String) -> void:
	state = next
	status = text
	# Printed as well as signalled: on a device this log is the only window
	# into where a handshake stalled.
	print("[GC] %s — %s" % [State.keys()[next], text])
	state_changed.emit(text)
