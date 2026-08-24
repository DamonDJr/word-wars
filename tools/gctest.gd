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
## The daily leaderboard. Held to the same standard and for a stronger reason:
## nothing in it can be exercised anywhere but a signed-in Apple device, so the
## registration is not merely the cheapest check available, it is the only one.
const BOARDS := "res://scripts/leaderboards.gd"
## The store, for the same reason again: a purchase callback with the wrong
## arity throws inside Apple's handler on a device, and the only symptom is money
## taken and a pack not granted.
const STORE := "res://scripts/store.gd"

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
## Empty now that the friend picker is gone; kept because the check below is what
## makes a *new* unhandled signal a failure rather than a silence.
const UNCONNECTED: Array = []

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
	# Apple's own matchmaking screen, under test. Its `did_find_match` carries
	# only the match — no error argument — which is exactly the arity trap that
	# killed `invite_accepted`: Godot accepts the wrong handler and then throws
	# inside Apple's delegate, where the only symptom is a sheet that never
	# hands the match over.
	"GKMatchmakerViewController": {
		"did_find_match": "_on_native_match",
		"cancelled": "_on_native_cancelled",
		"failed_with_error": "_on_native_failed",
	},
	"StoreKitManager": {
		"products_request_completed": "_on_products",
		"purchase_completed": "_on_purchased",
		"restore_completed": "_on_restored",
		"transaction_updated": "_on_transaction",
		"unverified_transaction_updated": "_on_unverified",
	},
	"GKMatch": {
		"data_received": "_on_data",
		# Both, always. GameKit calls the recipient form *instead of* the plain
		# one when the delegate implements it, and this plugin's proxy does — so
		# connecting only `data_received` is a match that hands over no data at
		# all while reporting every send as a success.
		"data_received_for_recipient_from_player": "_on_data_for",
		"player_changed": "_on_player_changed",
		"did_fail_with_error": "_on_match_error",
	},
}

## class -> method -> how many arguments the manager passes.
const CALLS := {
	"GameCenterManager": {"authenticate": 0},
	"GKLocalPlayer": {"register_listener": 0},
	"GKMatchmaker": {
		"find_match": 2,
		"match_for_invite": 2,
		"finish_matchmaking": 1,
		"cancel": 0,
	},
	"GKMatch": {"send_data_to_all_players": 2, "disconnect": 0},
	# `create_controller` is static and takes the request; `present` is called on
	# what it hands back.
	"GKMatchmakerViewController": {"create_controller": 1, "present": 0},
	"StoreKitManager": {
		"start": 0,
		"request_products": 1,
		"purchase": 1,
		"restore_purchases": 0,
		"fetch_current_entitlements": 0,
	},
	# `load_leaderboards` is static and takes (ids, callback); the other two are
	# called on the board object Apple hands back.
	"GKLeaderboard": {
		"load_leaderboards": 2,
		"submit_score": 4,
		"load_local_player_entries": 5,
	},
}

## class -> properties the manager reads or writes.
const PROPERTIES := {
	"GameCenterManager": ["local_player"],
	# `players` is the attached roster, which is not the same question as
	# `expected_player_count` and is the one that says whether a broadcast has
	# anywhere to go.
	"GKMatch": ["expected_player_count", "players"],
	"GKPlayer": ["game_player_id", "display_name"],
	"GKMatchRequest": ["min_players", "max_players", "invite_message", "recipients"],
	# The mode picks which of Apple's three options the sheet offers. Default is
	# the full screen, which is the one with Invite Friends on it.
	"GKMatchmakerViewController": ["matchmaking_mode"],
	# What the store reads off a product and a transaction. `revocation_date` is
	# the one that matters most: it is how a refund takes the pack back, and a
	# silently missing field would leave refunded purchases owned forever.
	"StoreProduct": ["product_id", "display_price"],
	"StoreTransaction": ["product_id", "revocation_date"],
	# The only thing the summary reads off an entry. A rank that silently stops
	# arriving leaves the two Game Center rows off the board and looks exactly
	# like a device that is not signed in.
	"GKLeaderboardEntry": ["rank", "score"],
}

## Callbacks Game Center invokes on us that are not signals, so nothing checks
## them: class -> method taking the Callable -> arguments Apple passes back.
const CALLBACK_ARITY := {
	"_on_found_match": 2,
}

## The same, for `leaderboards.gd`. Every one of these runs inside an Apple
## completion handler on a device, where a wrong arity throws where nobody is
## looking and the only symptom is a rank that never turns up.
const BOARD_CALLBACK_ARITY := {
	# `(Array[GKLeaderboard] boards, Variant error)`.
	"_on_boards_loaded": 2,
	# `(Variant error)` — null on success.
	"_on_submitted": 1,
	# `(GKLeaderboardEntry local, Array entries, Variant range, Variant error)`.
	# Four, not three: `load_local_player_entries` sends a total alongside the
	# entries where `load_entries` does not, and taking the shorter form is the
	# `invite_accepted` bug over again.
	"_on_global": 4,
	"_on_friends": 4,
}

## Scope and time constants the daily board asks Apple for by name.
const BOARD_CONSTANTS := ["GLOBAL", "FRIENDS_ONLY", "TODAY"]

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
	# Both files hand Callables to Apple, and `_accepts` looks methods up by name
	# in one table. Only the handlers this suite actually pins are taken from the
	# second file, so a name the two happen to share — `available`, `_set_state`
	# — cannot quietly stand in for the other and have its arity checked as if it
	# were. A genuine clash between two pinned handlers is a failure, not a
	# silent overwrite.
	var boards: GDScript = load(BOARDS)
	for m in boards.get_script_method_list():
		if not BOARD_CALLBACK_ARITY.has(m.name):
			continue
		if handlers.has(m.name):
			_expect("%s is not a handler in both files" % m.name, false)
		handlers[m.name] = m
	# The store's handlers are connected to signals rather than passed as
	# Callables, so they are checked by `_signals_match_handlers` and only need
	# to be findable by name.
	for m in (load(STORE) as GDScript).get_script_method_list():
		if m.name.begins_with("_on_") and not handlers.has(m.name):
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
		"GKMatchmaker", "GKMatchRequest", "GKInvite", "GKLeaderboard",
		"GKLeaderboardEntry",
		"StoreKitManager", "StoreProduct", "StoreTransaction"]
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

	print("--- and the purchase outcomes the store tells apart ---")
	# `store.gd` matches on each of these. A rename turns a cancelled purchase
	# into an error message, or worse, an error into a granted pack.
	for name in ["OK", "USER_CANCELLED", "CANCELLED", "PURCHASE_PENDING"]:
		_expect("StoreKitManager.StoreKitStatus.%s exists" % name,
			ClassDB.class_has_integer_constant("StoreKitManager", name))

	print("--- and the error fields the log reads ---")
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

	print("--- the daily leaderboard's, and the scopes it asks by name ---")
	for name in BOARD_CALLBACK_ARITY:
		_expect("%s takes %d" % [name, BOARD_CALLBACK_ARITY[name]],
			_accepts(name, BOARD_CALLBACK_ARITY[name]))
	for name in BOARD_CONSTANTS:
		_expect("GKLeaderboard.%s exists" % name,
			ClassDB.class_has_integer_constant("GKLeaderboard", name))


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
