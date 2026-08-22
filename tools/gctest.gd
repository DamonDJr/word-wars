extends SceneTree
## The Game Center API is not checkable by reading the code.
##
## `invite_accepted` carries `(player, invite)`. The handler took `(invite)`.
## Godot does not refuse that connection — it accepts it, then throws a runtime
## error at emit time, on a device, inside a callback nobody is watching. The
## invite half of multiplayer was dead for weeks and looked from the outside
## like Apple not delivering invites.
##
## Nothing in the game can catch that, because the game never gets to run the
## handler. But the plugin registers its whole API with `ClassDB` — including on
## the Linux stub, which is the entire reason the stub exists — so every name and
## every arity can be checked against the real thing from a PC.
##
## Every entry below is something `multiplayer_manager.gd` actually depends on.
## If the plugin is updated and something moves, this fails here rather than
## silently on a phone.
##
##   godot --headless --script tools/gctest.gd

const MANAGER := "res://scripts/multiplayer_manager.gd"
const GAME := "res://scripts/game.gd"

## The manager's own signals, and what `game.gd` connects to each. Same failure
## mode as the plugin's, and it bit just as hard: `_on_multiplayer_data` took a
## `player` argument that `data_received` never sends, so Godot dropped every
## emit and a connected match had no attacks, no salvos and no board mirror.
const GAME_CONNECTIONS := {
	"match_started": "_on_match_started",
	"match_ended": "_on_match_ended",
	"state_changed": "_on_net_status",
	"data_received": "_on_multiplayer_data",
}

## Signals the manager emits that nothing in `game.gd` connects to, on purpose.
## The versus screen is drawn every frame and reads the friend list straight out
## of the manager, so a handler would only be a second copy of state that can go
## stale. Listed rather than left out, so "no handler" reads as a decision.
const UNCONNECTED := ["friends_changed"]

## class -> signal -> the manager method we connect to it.
const CONNECTIONS := {
	"GameCenterManager": {
		"authentication_result": "_on_authenticated",
		"authentication_error": "_on_auth_failed",
	},
	"GKLocalPlayer": {
		"invite_accepted": "_on_invite_accepted",
		"match_requested_with_other_players": "_on_match_requested",
	},
	"GKMatch": {
		"data_received": "_on_data",
		"player_changed": "_on_player_changed",
		"did_fail_with_error": "_on_match_error",
	},
}

## class -> method -> how many arguments the manager passes.
const CALLS := {
	"GameCenterManager": {"authenticate": 0},
	"GKLocalPlayer": {"register_listener": 0, "load_challengeable_friends": 1,
		"load_friends": 1, "load_friends_authorization_status": 1},
	"GKMatchmaker": {
		"find_match": 2,
		"match_for_invite": 2,
		"finish_matchmaking": 1,
		"cancel": 0,
	},
	"GKMatch": {"send_data_to_all_players": 2, "disconnect": 0},
}

## class -> properties the manager reads or writes.
const PROPERTIES := {
	"GameCenterManager": ["local_player"],
	# `players` is the attached roster, which is not the same question as
	# `expected_player_count` and is the one that says whether a broadcast has
	# anywhere to go.
	"GKMatch": ["expected_player_count", "players"],
	# `alias` and `is_invitable` are what the in-app friend picker draws each row
	# from. Neither is load-bearing enough to crash if it moves — a missing one is
	# a blank name or a wrong hint — which is exactly why nothing else would catch
	# it before somebody saw it on a phone.
	"GKPlayer": ["game_player_id", "display_name", "alias", "is_invitable"],
	"GKMatchRequest": ["min_players", "max_players", "invite_message", "recipients"],
}

## Callbacks Game Center invokes on us that are not signals, so nothing checks
## them: class -> method taking the Callable -> arguments Apple passes back.
const CALLBACK_ARITY := {
	"_on_found_match": 2,
	# `(Array[GKPlayer] friends, Variant error)`, and either can be null. Getting
	# this wrong is the `invite_accepted` bug again: Godot accepts the Callable
	# and then throws inside Apple's completion handler, so the friend picker
	# would simply never fill in and nothing would say why.
	"_on_friends_loaded": 2,
	# `(int status, Variant error)`. Only ever logged, which is exactly why it
	# needs pinning: a wrong arity here throws inside Apple's handler and takes
	# the one line that says whether the player granted access with it.
	"_on_friends_authorization": 2,
}

var fails := 0
var handlers := {}


func _init() -> void:
	# `game.gd` names the `MultiplayerManager` autoload, and autoloads are not
	# registered until the first frame — loading it any earlier fails to compile
	# on an identifier that is perfectly fine at runtime.
	await process_frame

	var script: GDScript = load(MANAGER)
	for m in script.get_script_method_list():
		handlers[m.name] = m

	_classes_exist()
	_signals_match_handlers()
	_methods_exist()
	_properties_exist()
	_constants_exist()
	_callbacks_take_what_apple_sends()
	_game_takes_what_the_manager_sends()

	print("--- %s ---" % ("the Game Center API matches" if fails == 0
		else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)


func _classes_exist() -> void:
	print("--- the plugin is installed ---")
	var names := ["GameCenterManager", "GKLocalPlayer", "GKPlayer", "GKMatch",
		"GKMatchmaker", "GKMatchRequest", "GKInvite"]
	for n in names:
		_expect("%s is registered" % n, ClassDB.class_exists(n))


func _signals_match_handlers() -> void:
	print("--- every handler takes what its signal sends ---")
	for cls in CONNECTIONS:
		for sig in CONNECTIONS[cls]:
			var handler: String = CONNECTIONS[cls][sig]
			var found := {}
			for s in ClassDB.class_get_signal_list(cls, true):
				if s.name == sig:
					found = s
			if found.is_empty():
				_expect("%s.%s exists" % [cls, sig], false)
				continue
			var sent: int = found.args.size()
			_expect("%s takes the %d %s sends" % [handler, sent, sig],
				_accepts(handler, sent))


func _methods_exist() -> void:
	print("--- every call is a real method ---")
	for cls in CALLS:
		for name in CALLS[cls]:
			var passing: int = CALLS[cls][name]
			var found := {}
			for m in ClassDB.class_get_method_list(cls, true):
				if m.name == name:
					found = m
			if found.is_empty():
				_expect("%s.%s exists" % [cls, name], false)
				continue
			var most: int = found.args.size()
			var least: int = most - found.default_args.size()
			_expect("%s.%s takes %d" % [cls, name, passing],
				passing >= least and passing <= most)


func _properties_exist() -> void:
	print("--- every property is a real property ---")
	for cls in PROPERTIES:
		var have := {}
		for p in ClassDB.class_get_property_list(cls, true):
			have[p.name] = true
		for name in PROPERTIES[cls]:
			_expect("%s.%s exists" % [cls, name], have.has(name))


func _constants_exist() -> void:
	print("--- the send modes are named what we think ---")
	# Uppercase here, lowercase in the plugin's own documentation examples. The
	# registration is what runs, so it is what gets checked.
	for name in ["RELIABLE", "UNRELIABLE"]:
		_expect("GKMatch.SendDataMode.%s exists" % name,
			ClassDB.class_has_integer_constant("GKMatch", name))

	print("--- and the refusals the friend picker tells apart ---")
	# `_friends_refused` turns each of these into different advice for a
	# different person. If one is renamed the match arm stops matching and every
	# refusal quietly collapses back to the catch-all that hid
	# FRIEND_LIST_DESCRIPTION_MISSING in the first place.
	for name in ["FRIEND_LIST_DESCRIPTION_MISSING", "FRIEND_LIST_DENIED",
			"FRIEND_LIST_RESTRICTED", "NOT_AUTHENTICATED", "CANCELLED"]:
		_expect("GKError.Code.%s exists" % name,
			ClassDB.class_has_integer_constant("GKError", name))
	for name in ["code", "domain", "message"]:
		var have := false
		for p in ClassDB.class_get_property_list("GKError", true):
			if p.name == name:
				have = true
		_expect("GKError.%s exists" % name, have)


func _callbacks_take_what_apple_sends() -> void:
	print("--- and the completion handlers do too ---")
	for name in CALLBACK_ARITY:
		_expect("%s takes %d" % [name, CALLBACK_ARITY[name]],
			_accepts(name, CALLBACK_ARITY[name]))


func _game_takes_what_the_manager_sends() -> void:
	print("--- and the game takes what the manager sends ---")
	var manager: GDScript = load(MANAGER)
	var sends := {}
	for s in manager.get_script_signal_list():
		sends[s.name] = s.args.size()

	var game_handlers := {}
	for m in (load(GAME) as GDScript).get_script_method_list():
		game_handlers[m.name] = m

	# Every signal is either wired up or deliberately not. A new one that is
	# neither is a message being emitted into nothing.
	for name in sends:
		_expect("MultiplayerManager.%s is accounted for" % name,
			GAME_CONNECTIONS.has(name) or UNCONNECTED.has(name))

	for sig in GAME_CONNECTIONS:
		var handler: String = GAME_CONNECTIONS[sig]
		if not sends.has(sig):
			_expect("MultiplayerManager.%s exists" % sig, false)
			continue
		if not game_handlers.has(handler):
			_expect("game.%s exists" % handler, false)
			continue
		var m: Dictionary = game_handlers[handler]
		var most: int = m.args.size()
		var least: int = most - m.default_args.size()
		var sent: int = sends[sig]
		_expect("%s takes the %d %s sends" % [handler, sent, sig],
			sent >= least and sent <= most)


## Whether the manager's `name` can be called with exactly `count` arguments.
## Optional parameters widen the range, which is how a handler stays valid
## across a plugin that adds one.
func _accepts(name: String, count: int) -> bool:
	if not handlers.has(name):
		return false
	var m: Dictionary = handlers[name]
	var most: int = m.args.size()
	var least: int = most - m.default_args.size()
	return count >= least and count <= most


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-52s %s" % [what, "ok" if ok else "FAILED"])
