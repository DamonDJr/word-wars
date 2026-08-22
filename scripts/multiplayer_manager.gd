extends Node
## Autoload `MultiplayerManager`. Game Center matchmaking, and the handshake that
## turns a connected match into a match both players are actually playing.
##
## Game Center is not a `MultiplayerPeer`. There is no host, no peer ids and no
## RPC — there is a bag of bytes you can send to everyone, and that is the whole
## transport. So the rules the old netfox build got from the high-level API have
## to be written out by hand here, and there are three of them:
##
## 1. **A match is not ready when you receive it.** `didFindMatch` hands back a
##    `GKMatch` whose `expected_player_count` is still counting down; players
##    attach afterwards. Anything sent before that reaches nobody.
## 2. **Both ends have to agree when to start.** Each device's callback fires at
##    its own moment, so without an exchange one player is mid-countdown while
##    the other is still on the title screen — which looks exactly like a game
##    that connected and then hung.
## 3. **Invites are a separate door.** Accepting one outside the app does
##    nothing at all unless a listener was registered first, which is why the
##    invite path can look broken while auto-match half works.
##
## Everything here is guarded on the platform rather than commented out for
## desktop testing: the plugin ships a Linux stub whose classes refuse to
## instantiate, so `available()` answers honestly and the rest of the game runs
## on a PC with multiplayer simply switched off.

signal state_changed(text: String)
signal match_started
signal match_ended(reason: String)
signal data_received(packet: Dictionary)

enum State { OFF, AUTHENTICATING, READY, MATCHMAKING, CONNECTING, HANDSHAKING, PLAYING }

## How long to keep repeating the hello before giving up on the other end. The
## first one can land before the peer has finished attaching, so it is repeated
## rather than sent once and hoped for.
const HELLO_EVERY := 0.5
const HANDSHAKE_TIMEOUT := 15.0

var state: int = State.OFF
var status := "offline"

var game_center: GameCenterManager
var local_player: GKLocalPlayer
var current_match: GKMatch
var _controller

## The other player's Game Center id, learned from their hello. Also the thing
## that decides seating: both ends sort the two ids the same way, so both agree
## who is who without anybody being the host.
var _peer_id := ""
var _local_id := ""
var _hello_timer := 0.0
var _handshake_age := 0.0
var _peer_said_hello := false


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
	if state != State.HANDSHAKING:
		return
	# Repeat the hello until the other end answers. A single one sent the
	# instant the match arrives can be dropped while the peer is still
	# attaching, and a dropped hello is a game that never starts.
	_handshake_age += delta
	_hello_timer -= delta
	if _hello_timer <= 0.0:
		_hello_timer = HELLO_EVERY
		_send_raw({"type": "hello", "id": _local_id})
	if _handshake_age >= HANDSHAKE_TIMEOUT:
		_fail("the other player never answered")


# ----------------------------------------------------------------- sign-in

func _on_authenticated(_result: Variant = null) -> void:
	local_player = game_center.local_player
	if local_player != null:
		_local_id = _player_id(local_player)
		# Without this, an invite accepted from outside the app arrives nowhere
		# and the invite half of matchmaking looks broken while auto-match works.
		local_player.invite_accepted.connect(_on_invite_accepted)
		local_player.register_listener()
	_set_state(State.READY, "signed in")


func _on_auth_failed(error: Variant) -> void:
	_set_state(State.OFF, "Game Center sign-in failed")
	push_warning("Game Center: authentication failed — %s" % str(error))


## Game Center identifies a player by `game_player_id` on modern OS versions.
## Falls back to the display name, which is not guaranteed unique but is only
## used to break a tie between exactly two people.
func _player_id(p) -> String:
	if p == null:
		return ""
	for key in ["game_player_id", "gamePlayerID", "player_id"]:
		if key in p:
			var v = p.get(key)
			if typeof(v) == TYPE_STRING and String(v) != "":
				return String(v)
	return String(p.display_name) if "display_name" in p else ""


# ------------------------------------------------------------- matchmaking

func find_match() -> void:
	if not available():
		_set_state(State.OFF, "multiplayer needs an Apple device")
		return
	if state == State.MATCHMAKING or state == State.CONNECTING:
		return

	var request := GKMatchRequest.new()
	request.min_players = 2
	request.max_players = 2
	request.invite_message = "Join my Word Wars battle!"

	_set_state(State.MATCHMAKING, "finding an opponent")
	_present(request, null)


## One place that opens the matchmaker, whether it came from the button or from
## an accepted invite — so the two paths cannot drift, which is how one of them
## ends up working and the other not.
func _present(request, invite) -> void:
	_controller = null
	# The controller form is preferred because it carries `cancelled` and
	# `failed_with_error`, and without those a dismissed sheet leaves the game
	# sitting in "finding an opponent" forever with nothing to say.
	if ClassDB.can_instantiate("GKMatchmakerViewController"):
		var vc = GKMatchmakerViewController.new()
		var made = null
		if invite != null:
			made = vc.create_controller_from_invite(invite)
		else:
			made = vc.create_controller(request)
		_controller = made if made != null else vc
		if _controller.has_signal("did_find_match"):
			_controller.did_find_match.connect(_on_found_match)
			_controller.cancelled.connect(_on_cancelled)
			_controller.failed_with_error.connect(_on_matchmaking_failed)
			_controller.present()
			return
	# Fallback: the convenience call, which presents and dismisses itself but
	# reports nothing when the sheet is cancelled.
	if invite == null:
		GKMatchmakerViewController.request_match(request, _on_found_match_cb)


func _on_found_match_cb(found, error: Variant) -> void:
	if error:
		_on_matchmaking_failed(error)
		return
	_on_found_match(found)


func _on_invite_accepted(invite) -> void:
	_set_state(State.MATCHMAKING, "joining the invite")
	_present(null, invite)


func _on_cancelled() -> void:
	_controller = null
	_set_state(State.READY, "matchmaking cancelled")
	match_ended.emit("cancelled")


func _on_matchmaking_failed(error: Variant) -> void:
	_controller = null
	push_warning("Game Center: matchmaking failed — %s" % str(error))
	_set_state(State.READY, "could not find a match")
	match_ended.emit("matchmaking failed")


# ------------------------------------------------------- the match itself

func _on_found_match(found) -> void:
	_controller = null
	if found == null:
		_on_matchmaking_failed("no match")
		return
	current_match = found
	current_match.data_received.connect(_on_data)
	current_match.player_changed.connect(_on_player_changed)
	current_match.did_fail_with_error.connect(_on_match_error)

	_peer_id = ""
	_peer_said_hello = false
	_set_state(State.CONNECTING, "connecting")
	_check_connected()


## A match arrives before its players do. Nothing may be sent until the count
## reaches zero, so this is the gate everything else waits behind.
func _check_connected() -> void:
	if current_match == null:
		return
	if current_match.expected_player_count > 0:
		_set_state(State.CONNECTING, "waiting for the other player")
		return
	if state == State.HANDSHAKING or state == State.PLAYING:
		return
	_handshake_age = 0.0
	_hello_timer = 0.0
	_set_state(State.HANDSHAKING, "saying hello")


func _on_player_changed(player: GKPlayer, connected: bool) -> void:
	if connected:
		_check_connected()
		return
	# In a two-player match, one leaving is the end of it.
	if state == State.PLAYING or state == State.HANDSHAKING:
		_fail("%s left" % String(player.display_name))


func _on_match_error(error: String) -> void:
	push_warning("Game Center: match error — %s" % error)
	_fail("the connection dropped")


func _on_data(data: PackedByteArray, _player: GKPlayer) -> void:
	var packet = JSON.parse_string(data.get_string_from_utf8())
	if typeof(packet) != TYPE_DICTIONARY:
		return
	var kind := String(packet.get("type", ""))

	if kind == "hello":
		_peer_id = String(packet.get("id", ""))
		# Answer immediately as well as on the timer, so the pair converges in
		# one round trip rather than waiting out another tick.
		_send_raw({"type": "hello_back", "id": _local_id})
		_peer_said_hello = true
		_begin_if_ready()
		return
	if kind == "hello_back":
		_peer_id = String(packet.get("id", ""))
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
	if current_match != null:
		_send_raw({"type": "bye"})
		current_match.disconnect()
		current_match = null
	_peer_id = ""
	_peer_said_hello = false
	if available():
		_set_state(State.READY, "signed in")
	else:
		_set_state(State.OFF, "multiplayer needs an Apple device")


func _fail(reason: String) -> void:
	if current_match != null:
		current_match.disconnect()
		current_match = null
	_peer_said_hello = false
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
	current_match.send_data_to_all_players(
		JSON.stringify({"type": "state", "payload": payload}).to_utf8_buffer(),
		GKMatch.SendDataMode.UNRELIABLE
	)


func _send_raw(packet: Dictionary) -> void:
	if current_match == null:
		return
	current_match.send_data_to_all_players(
		JSON.stringify(packet).to_utf8_buffer(),
		GKMatch.SendDataMode.RELIABLE
	)


func in_match() -> bool:
	return state == State.PLAYING


func _set_state(next: int, text: String) -> void:
	state = next
	status = text
	# Printed as well as signalled: on a device this log is the only window
	# into where a handshake stalled.
	print("[GC] %s — %s" % [State.keys()[next], text])
	state_changed.emit(text)
