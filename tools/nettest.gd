extends SceneTree
## Everything the end-of-match scoreboard reads has to survive the wire.
##
## This exists because it did not. `_state_of` sent words played and blocks
## cleared — the two figures anything showed live — and the scoreboard then grew
## columns for score, powers, salvos and best chain. Against a CPU it looked
## perfect, because a CPU is simulated on this machine and its SideState is the
## real one. Against a person every one of those columns read zero, including
## for the player who had just won on score.
##
## Nothing in the game could catch that: both halves were individually correct,
## and the only way to see it was to finish a networked match and read the
## board. So the check is structural — take a side, put real numbers in it, run
## it through the same encode and decode the network uses, and require that what
## comes out the other end says the same thing.
##
##   godot --headless --script tools/nettest.gd

var game: Node
var fails := 0


func _init() -> void:
	await process_frame
	game = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame

	_scoreboard_survives_the_wire()
	_the_handicap_is_only_for_mixed_rooms()
	_two_held_sheets_do_not_deadlock()

	print("--- %s ---" % ("net state behaves" if fails == 0 else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)


## Both players automatch, both sheets stay up, and neither game ever starts.
##
## Each end sends `holding` every `HELLO_EVERY` while its sheet is up, and the
## handler reset `_wait_age` so a peer taking a while to find the X would not be
## timed out. But the escape from a stuck sheet was also measured on `_wait_age`
## — so two devices reset each other's escape timer four times faster than the
## two-second grace they were both waiting for, and neither ever reached it.
##
## Both screens then read "waiting for them to close Game Center", each about the
## other, with no timeout behind it: `_process` returns before the handshake
## deadline while the sheet is up. It hung until somebody force-quit.
##
## Driven here at a tenth of a second a tick, with a `holding` arriving at the
## real rate, because the bug only exists in the interleaving.
func _two_held_sheets_do_not_deadlock() -> void:
	print("--- two held sheets escape each other ---")
	var mm = Engine.get_main_loop().root.get_node("MultiplayerManager")

	mm.state = mm.State.HANDSHAKING
	mm._native_sheet_up = true
	mm._sheet_age = 0.0
	mm._wait_age = 0.0
	mm._hello_timer = mm.HELLO_EVERY
	mm._peer_said_hello = false

	var holding := {"type": "holding"}
	var t := 0.0
	var since_holding := 0.0
	# Twice the grace. If it cannot escape in that, it never will.
	while t < mm.SHEET_GRACE * 2.0 and mm._native_sheet_up:
		mm._process(0.1)
		t += 0.1
		since_holding += 0.1
		if since_holding >= mm.HELLO_EVERY:
			since_holding = 0.0
			mm._on_data(JSON.stringify(holding).to_utf8_buffer(), null)

	_expect("the sheet gives up inside twice the grace (%.1fs)" % t,
		not mm._native_sheet_up)
	_expect("and it took about the grace, not longer",
		t <= mm.SHEET_GRACE + 0.3)
	# The peer's keepalive must still do its job — it is what stops a slow
	# dismissal being read as a dead opponent.
	_expect("a holding packet still resets the handshake clock",
		mm._wait_age < mm.HANDSHAKE_TIMEOUT)

	mm.state = mm.State.OFF
	mm._native_sheet_up = false


func _scoreboard_survives_the_wire() -> void:
	print("--- the scoreboard survives a round trip ---")
	game.start_match("Rookie", 1)
	game.phase = game.Phase.PLAY

	# A rival with a match's worth of history on it, all of it distinct so no
	# field can pass by being accidentally equal to another.
	var them = game.sides[1]
	# A payload is routed by peer id, so the side has to have one — a local CPU
	# has none, and without this the decode returns before it touches anything.
	them.peer_id = 77001
	them.in_match = true
	them.score = 18342
	them.words_played = 77
	them.blocks_cleared = 41
	them.best_chain = 9
	them.best_combo = 4
	them.powers_fired = 13
	them.salvos = 3
	them.longest_word = "entertainment"

	var wire: Dictionary = game._state_of(them, them.peer_id)

	# Decode into a side that has none of it, which is what a peer's side looks
	# like before any packet lands.
	var blank = game.sides[1]
	blank.score = 0
	blank.words_played = 0
	blank.blocks_cleared = 0
	blank.best_chain = 0
	blank.best_combo = 0
	blank.powers_fired = 0
	blank.salvos = 0
	blank.longest_word = ""
	game._on_net_state(wire)

	# Named the way the scoreboard names them, so a failure reads as the column
	# that would be wrong on screen.
	var want := {
		"SCORE": [blank.score, 18342],
		"WORDS": [blank.words_played, 77],
		"CLEARED": [blank.blocks_cleared, 41],
		"CHAIN": [blank.best_chain, 9],
		"POWERS": [blank.powers_fired, 13],
		"SALVOS": [blank.salvos, 3],
	}
	for col in want:
		var pair: Array = want[col]
		_expect("%s arrives as %s" % [col, pair[1]], pair[0] == pair[1])
	_expect("the longest word arrives", blank.longest_word == "entertainment")

	# A payload from an older build must leave what is already there alone
	# rather than blanking it fifteen times a second.
	blank.score = 500
	blank.salvos = 2
	var old: Dictionary = game._state_of(them, them.peer_id)
	for key in ["sc", "pw", "sv", "bc", "bk", "lw"]:
		old.erase(key)
	game._on_net_state(old)
	_expect("an old payload does not zero the score", blank.score == 500)
	_expect("an old payload does not zero the salvos", blank.salvos == 2)


## The phone handicap has to be conditional, or it is not a handicap — it is
## just a slower game for everyone, and a phone playing a phone would be getting
## help against an opponent with exactly the same problem.
func _the_handicap_is_only_for_mixed_rooms() -> void:
	print("--- the handicap only applies to a mixed room ---")
	var L = get_root().get_node("Link")

	for setup in [
		{"what": "everyone on keys", "me": L.Device.KEYS, "them": L.Device.KEYS,
			"mine": 1.0, "theirs": 1.0},
		{"what": "everyone on phones", "me": L.Device.TOUCH, "them": L.Device.TOUCH,
			"mine": 1.0, "theirs": 1.0},
		{"what": "a phone against keys", "me": L.Device.TOUCH, "them": L.Device.KEYS,
			"mine": game.TOUCH_GRACE, "theirs": 1.0},
		{"what": "keys against a phone", "me": L.Device.KEYS, "them": L.Device.TOUCH,
			"mine": 1.0, "theirs": game.TOUCH_GRACE},
	]:
		game.start_match("Rookie", 1)
		game.sides[0].device = int(setup["me"])
		game.sides[1].device = int(setup["them"])
		game.sides[1].in_match = true
		game._apply_handicap()
		_expect("%s — you get x%.2f" % [setup["what"], setup["mine"]],
			is_equal_approx(game.sides[0].grace, float(setup["mine"])))
		_expect("%s — they get x%.2f" % [setup["what"], setup["theirs"]],
			is_equal_approx(game.sides[1].grace, float(setup["theirs"])))

	# And it has to actually reach the chain window, not just sit in a field.
	game.start_match("Rookie", 1)
	game.sides[0].device = L.Device.TOUCH
	game.sides[1].device = L.Device.KEYS
	game.sides[1].in_match = true
	game._apply_handicap()
	game.phase = game.Phase.PLAY
	game._play_word(game.sides[0], "planet")
	var mine: float = game.sides[0].chain_window
	game._play_word(game.sides[1], "planet")
	var theirs: float = game.sides[1].chain_window
	_expect("the phone's chain window is genuinely longer", mine > theirs + 0.01)


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-52s %s" % [what, "ok" if ok else "FAILED"])
