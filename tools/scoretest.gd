extends SceneTree
## Winning and scoring have to agree.
##
## They did not. You could take a match and still finish second on points,
## because the two hardest things in the game paid nothing: overfilling somebody
## else's board scored exactly what the same attack scores landing on an empty
## one, and winning scored nothing at all. A scoreboard that can crown the loser
## is measuring something other than the game that was just played.
##
## Also here: focus fire, which is invisible by construction — the only symptom
## is that blocks get bigger, and nobody can tell a focus tier from a chain tier
## by looking at the block.
##
##   godot --headless --script tools/scoretest.gd

var game: Node
var fails := 0
## Sections that ran to the end. A runtime error inside one aborts it without
## touching `fails`, so a crash used to be reported as a pass — this is what
## makes an incomplete run fail instead of looking clean.
var done := 0
const SECTIONS := 4


func _init() -> void:
	await process_frame
	game = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame

	_topout_pays()
	_winning_pays()
	_focus_needs_a_crowd()
	_focus_stacks_with_attackers()

	if done != SECTIONS:
		fails += 1
		print("  %-52s %s" % ["all %d sections ran" % SECTIONS,
			"FAILED (%d did)" % done])
	print("--- %s ---" % ("scoring behaves" if fails == 0 else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)


func _topout_pays() -> void:
	print("--- overfilling a board pays ---")
	game.start_match("Rookie", 1)
	game.phase = game.Phase.PLAY
	var me = game.sides[0]
	var them = game.sides[1]
	them.in_match = true
	them.alive = true

	var before: int = me.score
	game._credit_topout(game._entity_of(me), them)
	_expect("the attacker is paid for it",
		me.score == before + Scoring.TOPOUT_BONUS)

	# Ambient pressure has nobody to pay, and a board that fills itself must not
	# pay its owner.
	before = me.score
	game._credit_topout(-1, them)
	_expect("ambient pressure pays nobody", me.score == before)
	game._credit_topout(game._entity_of(me), me)
	_expect("you are not paid for your own board", me.score == before)
	done += 1


func _winning_pays() -> void:
	print("--- winning pays, and comfort pays more ---")
	# A win with everything intact.
	game.start_match("Rookie", 1)
	game.phase = game.Phase.PLAY
	game.mode = game.Mode.NORMAL
	var me = game.sides[0]
	me.score = 0
	me.lives = 3
	me.alive = true
	game.sides[1].alive = false
	game._end_match(game.sides[1])
	var comfortable: int = me.score
	_expect("taking the match is worth something", comfortable > 0)

	# The same win, down to the last life.
	game.start_match("Rookie", 1)
	game.phase = game.Phase.PLAY
	game.mode = game.Mode.NORMAL
	me = game.sides[0]
	me.score = 0
	me.lives = 1
	me.alive = true
	game.sides[1].alive = false
	game._end_match(game.sides[1])
	var narrow: int = me.score
	_expect("a comfortable win beats a narrow one", comfortable > narrow)

	# And losing pays nothing, or the bonus says nothing.
	game.start_match("Rookie", 1)
	game.phase = game.Phase.PLAY
	game.mode = game.Mode.NORMAL
	me = game.sides[0]
	me.score = 0
	me.alive = false
	game._end_match(me)
	_expect("losing is not paid", me.score == 0)
	done += 1


func _focus_needs_a_crowd() -> void:
	print("--- focus fire needs a crowd ---")
	# A duel has nobody to gang up with, so a bonus there is just a damage buff.
	game.start_match("Rookie", 1)
	game.phase = game.Phase.PLAY
	game.sides[1].target = 0
	_expect("a duel has no focus bonus",
		game._focus_bonus(game.sides[1], game.sides[0]) == 0)
	done += 1


func _focus_stacks_with_attackers() -> void:
	print("--- and grows with the crowd ---")
	game.start_match("Duelist", 3)
	game.phase = game.Phase.PLAY
	for i in 4:
		game.sides[i].in_match = true
		game.sides[i].alive = true

	# Everyone aims somewhere else: nobody is ganged up on.
	game.sides[1].target = 2
	game.sides[2].target = 3
	game.sides[3].target = 1
	_expect("one attacker alone gets nothing",
		game._focus_bonus(game.sides[1], game.sides[2]) == 0)

	# Two on the same board.
	game.sides[1].target = 2
	game.sides[3].target = 2
	_expect("two on one board is worth a tier",
		game._focus_bonus(game.sides[1], game.sides[2]) == 1)

	# Three on the same board.
	game.sides[0].target = 2
	_expect("three on one board is worth two",
		game._focus_bonus(game.sides[1], game.sides[2]) == 2)

	# A board that is out no longer counts toward the pile-on.
	game.sides[3].alive = false
	_expect("a dead attacker stops counting",
		game._focus_bonus(game.sides[1], game.sides[2]) == 1)
	done += 1


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-52s %s" % [what, "ok" if ok else "FAILED"])
