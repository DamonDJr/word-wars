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

	print("--- %s ---" % ("net state behaves" if fails == 0 else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)


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


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-52s %s" % [what, "ok" if ok else "FAILED"])
