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
## The cost of refusing Apple's sheet is that we also refuse Apple's friend
## picker, so the game has to draw its own — which is what `load_friends` below
## is for, and why an invitation from inside the app is a list of `GKPlayer`
## rather than a view controller.
##
## Everything here is guarded on the platform rather than commented out for
## desktop testing: the plugin ships a Linux stub whose classes refuse to
## instantiate, so `available()` answers honestly and the rest of the game runs
## on a PC with multiplayer simply switched off.

signal state_changed(text: String)
signal match_started
signal match_ended(reason: String)
signal data_received(packet: Dictionary)
signal friends_changed

enum State { OFF, AUTHENTICATING, READY, MATCHMAKING, CONNECTING, HANDSHAKING, PLAYING }

## Where the friend list is up to.
##
## Apple gates the list behind a permission prompt we do not own and cannot
## pre-empt, so every answer it can give — including "no" — has to be a state the
## picker can say out loud. A screen that shows an empty list for "you declined",
## "you have none" and "it is still loading" alike is a screen that looks broken
## three different ways.
enum Friends { UNASKED, LOADING, READY, EMPTY, DENIED }

## How long to keep repeating the hello before giving up on the other end. The
## first one can land before the peer has finished attaching, so it is repeated
## rather than sent once and hoped for.
const HELLO_EVERY := 0.5
const HANDSHAKE_TIMEOUT := 15.0
## A match whose players never finish attaching. Without this the game sits in
## "waiting for the other player" with no way out but force-quitting.
const CONNECT_TIMEOUT := 30.0

var state: int = State.OFF
var status := "offline"

var game_center: GameCenterManager
var local_player: GKLocalPlayer
var current_match: GKMatch
var _matchmaker: GKMatchmaker

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
## Which GameKit callback delivered this match's packets. See `_note_delivery`.
var _delivery := ""

## The people the in-app picker offers, as `GKPlayer`.
var friends: Array = []
var friends_state: int = Friends.UNASKED
## Why the list is the way it is, when that needs saying.
var friends_note := ""
## Who an outstanding invitation went to, so a screen can name them instead of
## saying "waiting" at nobody in particular.
var invited := ""


## Whether this build can talk to Game Center at all.
##
## Asking `ClassDB.can_instantiate` is not enough: the desktop stub registers
## every class and answers yes, then refuses to construct them and hands back
## null. So the platform is checked first and the construction is checked after
## — which is what lets the whole file stay uncommented while the game runs on
## a PC with multiplayer simply switched off.
func available() -> bool:
	if not (OS.get_name() in ["iOS", "macOS"]):
		return false
	return ClassDB.can_instantiate("GameCenterManager")


func _ready() -> void:
	if not available():
		_set_state(State.OFF, "multiplayer needs an Apple device")
		return
	game_center = GameCenterManager.new()
	if game_center == null:
		_set_state(State.OFF, "Game Center is unavailable on this build")
		return
	game_center.authentication_result.connect(_on_authenticated)
	game_center.authentication_error.connect(_on_auth_failed)
	_set_state(State.AUTHENTICATING, "signing in to Game Center")
	game_center.authenticate()


func _process(delta: float) -> void:
	if state == State.CONNECTING:
		_wait_age += delta
		# Poll rather than trust `player_changed` alone: if both players were
		# already attached when the match arrived, that signal has nothing left
		# to fire and the only thing that ever moves is the count.
		_check_connected()
		if state == State.CONNECTING and _wait_age >= CONNECT_TIMEOUT:
			_fail("the other player never joined")
		return

	if state != State.HANDSHAKING:
		return
	# Repeat the hello until the other end answers. A single one sent the
	# instant the match arrives can be dropped while the peer is still
	# attaching, and a dropped hello is a game that never starts.
	_wait_age += delta
	_hello_timer -= delta
	if _hello_timer <= 0.0:
		_hello_timer = HELLO_EVERY
		_hellos_sent += 1
		_send_raw({"type": "hello", "id": _local_id})
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
		_local_id = ""
		# The friend list belongs to whoever was signed in. Left standing it would
		# offer the next account the last one's friends, and inviting them would
		# fail with no way to see why.
		friends = []
		friends_state = Friends.UNASKED
		friends_note = ""
		friends_changed.emit()
		_set_state(State.OFF, "not signed in to Game Center")
		return

	local_player = game_center.local_player
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
	_set_state(State.OFF, "Game Center sign-in failed")
	push_warning("Game Center: authentication failed — %s" % message)


## Game Center identifies a player by `game_player_id`. Falls back to the display
## name, which is not guaranteed unique but is only ever used to break a tie
## between exactly two people.
func _player_id(p: GKPlayer) -> String:
	if p == null:
		return ""
	if String(p.game_player_id) != "":
		return String(p.game_player_id)
	return String(p.display_name)


## The shared matchmaker, built on first use. Kept because Apple's `cancel()`
## applies to the shared instance and we need to be able to call it.
func _mm() -> GKMatchmaker:
	if _matchmaker == null:
		_matchmaker = GKMatchmaker.new()
	return _matchmaker


# ------------------------------------------------------------- matchmaking

func _request(for_players: Array = []) -> GKMatchRequest:
	var request := GKMatchRequest.new()
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
var _native_vc: GKMatchmakerViewController


## Put Apple's matchmaking screen up.
func open_native_matchmaker(mode: int = Native.DEFAULT) -> void:
	if not available():
		_set_state(State.OFF, "multiplayer needs an Apple device")
		return
	if state != State.READY:
		print("[GC] native: refused — state is %s, not READY" % State.keys()[state])
		return

	_native_vc = GKMatchmakerViewController.create_controller(_request())
	if _native_vc == null:
		print("[GC] native: create_controller returned null")
		_set_state(State.READY, "Game Center would not open its own screen")
		return

	_native_vc.matchmaking_mode = mode
	_native_vc.did_find_match.connect(_on_native_match)
	_native_vc.cancelled.connect(_on_native_cancelled)
	_native_vc.failed_with_error.connect(_on_native_failed)

	invited = ""
	_set_state(State.MATCHMAKING, "Game Center is asking")
	print("[GC] native: presenting (mode %d)" % mode)
	_native_vc.present()
	print("[GC] native: present() returned — sheet should be up")


## Apple found somebody. Same arrival as every other route, minus the error
## argument this signal does not carry.
func _on_native_match(found) -> void:
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
	if current_match != null:
		print("[GC] native: cancelled with a match already in hand — sheet dismissed, keeping the match (%s)" % detail)
		return
	print("[GC] native: cancelled with no match — giving up (%s)" % detail)
	_native_vc = null
	_set_state(State.READY, "matchmaking cancelled")
	match_ended.emit("cancelled")


func _on_native_failed(message: String) -> void:
	print("[GC] native: failed — %s" % message)
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
		if p is GKPlayer:
			var n := String((p as GKPlayer).display_name)
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
	_mm().cancel()
	invited = ""
	_set_state(State.READY, "matchmaking cancelled")
	match_ended.emit("cancelled")


## Someone chose friends in the Game Center app and asked for a match. The
## picking is already done, so this is just `invite_players` with Apple's list.
func _on_match_requested(_player: GKPlayer, recipients: Array) -> void:
	invite_players(recipients)


# ---------------------------------------------------------------- friends

## Apple's friend list, so the game can run its own picker.
##
## The obvious way to send an invitation from inside an app is
## `GKMatchmakerViewController` in invite-only mode, and that is the sheet this
## file exists to avoid: it cannot be dismissed from GDScript, so a successful
## invite would leave Apple's "Starting Game…" parked over a match nobody can
## see. Until that changes, the only route to inviting a *specific* person from
## inside the app is to know who your friends are and pass them to `find_match`
## as recipients — which is exactly what `load_friends` is for.
##
## Two things about this call are not obvious and both have bitten already.
##
## It needs `NSGKFriendListUsageDescription` in the app's Info.plist, the same
## way the camera does. Without it Apple refuses with
## `FRIEND_LIST_DESCRIPTION_MISSING` — which looks exactly like the player
## declining, and is not: it is the build being wrong, and no amount of tapping
## "ask again" will fix it. It is set in `export_presets.cfg` for iOS and macOS.
##
## And it is mutual: Apple returns the friends who have *also* granted this game
## access to them, so a short list — or an empty one — is normal and is not the
## same as having no friends. The copy has to say so, or the picker reads as
## broken to somebody with a full friends list in the Game Center app.
##
## A refusal comes back as an error rather than an empty array, which is what
## lets all of those be told apart and said differently.
func load_friends(force := false) -> void:
	if not available() or local_player == null:
		friends = []
		friends_state = Friends.DENIED
		friends_note = "sign in to Game Center first"
		friends_changed.emit()
		return
	if friends_state == Friends.LOADING:
		return
	# Already answered, and asking again re-prompts. Only a deliberate retry —
	# after a refusal, or after adding someone — goes back to Apple.
	if friends_state != Friends.UNASKED and not force:
		return
	friends_state = Friends.LOADING
	friends_note = "asking Game Center"
	friends_changed.emit()
	print("[GC] asking for friends (forced: %s)" % force)
	# Asked for the log's sake and nothing else. An empty friend list has two
	# completely different causes — the player never granted access, or they did
	# and simply share no mutual authoriser — and from the empty array alone
	# those are indistinguishable. The status is the only thing that separates
	# them, and separating them is the difference between "tap Ask again" and
	# "get your friend to open the app".
	local_player.load_friends_authorization_status(_on_friends_authorization)
	local_player.load_friends(_on_friends_loaded)


## Apple's raw `GKFriendsAuthorizationStatus`: 0 not determined, 1 denied,
## 2 restricted, 3 authorised. Logged rather than acted on — `load_friends` is
## the call that actually decides, and second-guessing it here would mean two
## sources of truth for one question.
func _on_friends_authorization(status: int, error = null) -> void:
	if error != null:
		print("[GC] friend authorization unavailable — %s" % _error_text(error))
		return
	var names := ["not determined", "denied", "restricted", "authorized"]
	print("[GC] friend authorization: %s (%d)" % [
		names[status] if status >= 0 and status < names.size() else "unknown",
		status])


func _on_friends_loaded(list, error = null) -> void:
	if error != null:
		friends = []
		friends_state = Friends.DENIED
		friends_note = _friends_refused(error)
		push_warning("Game Center: load_friends failed — %s" % _error_text(error))
		print("[GC] friends failed — %s" % _error_text(error))
		friends_changed.emit()
		return

	friends = []
	var raw: int = 0
	if list != null:
		raw = list.size()
		for p in list:
			if p is GKPlayer:
				friends.append(p)
	# `raw` against the kept count separates "Apple sent nobody" from "Apple sent
	# people and the filter dropped them", which is the difference between a
	# Game Center problem and one of ours.
	print("[GC] friends — Apple returned %d, kept %d" % [raw, friends.size()])
	for p: GKPlayer in friends:
		print("[GC]   %s (invitable: %s)" % [
			String(p.display_name), p.is_invitable])
	# Whoever is taking invitations comes first, then alphabetically. `is_invitable`
	# is only ever a sort key here and never a gate: if the plugin leaves it false
	# for everyone the order is simply alphabetical, whereas gating on it would
	# turn one unpopulated property into a picker with nothing pickable in it.
	friends.sort_custom(_friend_before)
	friends_state = Friends.READY if not friends.is_empty() else Friends.EMPTY
	# Not "you have no friends" — Apple only hands back the ones who have also
	# let this game see them, so an empty list is the common case for a brand new
	# install and says nothing about the Game Center friends list itself.
	friends_note = "" if not friends.is_empty() \
		else "none of your friends have shared themselves with Word Wars"
	friends_changed.emit()


func _friend_before(a: GKPlayer, b: GKPlayer) -> bool:
	if a.is_invitable != b.is_invitable:
		return a.is_invitable
	return String(a.display_name).nocasecmp_to(String(b.display_name)) < 0


## Why Apple said no, in words meant for whoever has to do something about it.
##
## This started as one catch-all — "Game Center would not share your friends" —
## and that message cost a build-and-install to diagnose: the refusal was
## `FRIEND_LIST_DESCRIPTION_MISSING`, which is not the player declining anything
## but the app shipping without `NSGKFriendListUsageDescription` in its
## Info.plist. Three of these are three different jobs for three different
## people, and a message that cannot tell them apart sends the wrong one.
func _friends_refused(error) -> String:
	if not (error is GKError):
		return "Game Center would not share your friends"
	match (error as GKError).code:
		GKError.Code.FRIEND_LIST_DESCRIPTION_MISSING:
			# Nothing the player can do; the build is wrong.
			return "this build is missing its friend-list permission"
		GKError.Code.FRIEND_LIST_DENIED:
			return "friends are switched off for Word Wars in Settings"
		GKError.Code.FRIEND_LIST_RESTRICTED:
			return "Screen Time is holding the friend list back"
		GKError.Code.NOT_AUTHENTICATED:
			return "sign in to Game Center first"
		GKError.Code.CANCELLED:
			return "cancelled — ask again when you are ready"
	return "Game Center would not share your friends"


## The whole of what Apple said, for the log. `str()` on a `GKError` prints the
## object rather than the failure, which is how the code above went unseen.
func _error_text(error) -> String:
	if not (error is GKError):
		return str(error)
	var e := error as GKError
	return "code %d (%s) — %s" % [e.code, e.domain, e.message]


func _on_invite_accepted(_player: GKPlayer, invite: GKInvite) -> void:
	if not available() or invite == null:
		return
	# An invite can arrive at any moment, including mid-match — accepting one
	# from the notification banner is a decision to abandon whatever is running.
	if current_match != null:
		leave_match()
	_set_state(State.MATCHMAKING, "joining the invite")
	_mm().match_for_invite(invite, _on_found_match)


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
		if p is GKPlayer:
			who.append(String((p as GKPlayer).display_name))
	print("[GC] match ready — %d attached: %s" % [
		who.size(), ", ".join(who) if not who.is_empty() else "NOBODY"])
	_set_state(State.HANDSHAKING, "saying hello")
	# The peer's hello can arrive while this device is still CONNECTING, in which
	# case `_begin_if_ready` was called too early to do anything and the answer is
	# already sitting here. Without this the match waits out another round trip
	# for news it has already had.
	_begin_if_ready()


func _on_player_changed(player: GKPlayer, connected: bool) -> void:
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
func _on_data_for(data: PackedByteArray, _recipient: GKPlayer,
		from: GKPlayer) -> void:
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


func _on_data(data: PackedByteArray, _player: GKPlayer) -> void:
	_note_delivery(_delivery if _delivery != "" else "from-remote-player")
	var packet = JSON.parse_string(data.get_string_from_utf8())
	if typeof(packet) != TYPE_DICTIONARY:
		return
	var kind := String(packet.get("type", ""))

	if kind == "hello" or kind == "hello_back":
		# Logged once. A handshake that times out is either "we sent thirty and
		# heard nothing" or "we heard them and still did not start", and those are
		# opposite faults that look identical from the outside — one line here
		# decides which, and repeating it thirty times would bury the rest.
		if not _peer_said_hello:
			print("[GC] heard %s from %s" % [kind, packet.get("id", "?")])
		_peer_id = String(packet.get("id", ""))
		# Answer immediately as well as on the timer, so the pair converges in
		# one round trip rather than waiting out another tick. Only `hello` is
		# answered — replying to a reply is how two devices talk forever.
		if kind == "hello":
			_send_raw({"type": "hello_back", "id": _local_id})
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
	if state == State.MATCHMAKING:
		cancel_find()
		return
	if current_match != null:
		_send_raw({"type": "bye"})
		current_match.disconnect()
		current_match = null
	_peer_id = ""
	_peer_said_hello = false
	invited = ""
	if available():
		_set_state(State.READY, "signed in")
	else:
		_set_state(State.OFF, "multiplayer needs an Apple device")


func _fail(reason: String) -> void:
	if current_match != null:
		current_match.disconnect()
		current_match = null
	_peer_said_hello = false
	invited = ""
	_set_state(State.READY if available() else State.OFF, reason)
	match_ended.emit(reason)


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
	_send({"type": "state", "payload": payload}, GKMatch.SendDataMode.UNRELIABLE)


func _send_raw(packet: Dictionary) -> void:
	_send(packet, GKMatch.SendDataMode.RELIABLE)


## Every outgoing packet, so one place can notice that sending is failing.
##
## `send_data_to_all_players` returns an `Error` and this used to drop it on the
## floor. That is how a handshake which never left the device looked exactly like
## a peer who never answered: thirty hellos, no error anywhere, and a log whose
## only evidence was that nothing came back. The two have opposite fixes.
func _send(packet: Dictionary, mode: int) -> void:
	if current_match == null:
		return
	var err: int = current_match.send_data_to_all_players(
		JSON.stringify(packet).to_utf8_buffer(), mode)
	if err == OK:
		return
	_send_failures += 1
	# The board mirror goes out fifteen times a second, so a broken channel would
	# bury the whole log inside a second. Loud at first, then a heartbeat.
	if _send_failures <= 3 or _send_failures % 30 == 0:
		print("[GC] send failed (error %d) on '%s' — %d failed so far" % [
			err, packet.get("type", "?"), _send_failures])
		push_warning("Game Center: send failed — error %d" % err)


func in_match() -> bool:
	return state == State.PLAYING


func _set_state(next: int, text: String) -> void:
	state = next
	status = text
	# Printed as well as signalled: on a device this log is the only window
	# into where a handshake stalled.
	print("[GC] %s — %s" % [State.keys()[next], text])
	state_changed.emit(text)
