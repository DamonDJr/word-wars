extends SceneTree
## Winning and scoring have to agree.
##
## They did not. You could take a match and still finish second on points,
## because the two hardest things in the game paid nothing: overfilling somebody
## else's board scored exactly what the same attack scores landing on an empty
## one, and winning scored nothing at all. A scoreboard that can crown the loser
## is measuring something other than the game that was just played.
##
## Bonuses alone did not settle it. They were paid raw while a word's score was
## paid at SCALE, so the hardest thing in the game was worth a fifth of what it
## reads as — and offence still scored nothing in a match, only in a solo run.
## Every point in a duel came from clearing your own board, which the combo
## multiplier pays +60% a block for, so the player being buried out-earned the
## player doing the burying by tens of thousands.
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
const SECTIONS := 6


func _init() -> void:
	await process_frame
	game = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame

	# Off the real save. Every section here ends a match, and ending a match
	# banks the record and counts towards an ad break — against whatever profile
	# happens to be loaded, which used to be the developer's own.
	var P := get_root().get_node("Profile")
	P.save_path = "user://profile-score-test.cfg"
	P.owned = {}
	P.since_ad = 0
	P.ad_gap = P.ADS_EVERY_MAX

	_attacking_pays()
	_bonuses_are_scaled()
	_topout_pays()
	_winning_pays()
	_length_sets_a_floor()
	_focus_needs_a_crowd()
	_focus_stacks_with_attackers()
	_pops_do_not_pile_up()

	if done != SECTIONS:
		fails += 1
		print("  %-52s %s" % ["all %d sections ran" % SECTIONS,
			"FAILED (%d did)" % done])
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(P.save_path + suffix))
	print("--- %s ---" % ("scoring behaves" if fails == 0 else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)


## The one that let the scoreboard crown the loser by fifty thousand. A block
## sent used to be its own reward and nothing else: `_strike` handed it to the
## defender and returned zero, so in the only mode with an opponent, attacking
## paid nothing. Points came from answering garbage, and the player losing had
## the most garbage to answer.
func _attacking_pays() -> void:
	print("--- attacking pays, with a rival as well as without ---")
	game.start_match("Rookie", 1)
	game.phase = game.Phase.PLAY
	game.mode = game.Mode.NORMAL
	var me = game.sides[0]
	var them = game.sides[1]
	them.in_match = true
	them.alive = true
	them.pending.clear()

	var before: int = me.score
	var paid: int = game._strike(me, them, "strike", 3, 0.0, "ike")
	_expect("a block sent is paid for, by the cell",
		paid == game._cells(3) * game.STRIKE_PAY)
	_expect("and banked", me.score == before + paid)
	# And it is still an attack, not a payout instead of one.
	_expect("and it still lands on them", not them.pending.is_empty())

	# A bigger block is a bigger hit is more points, or the chain ladder buys
	# damage the scoreboard cannot see.
	_expect("a heavier block pays more",
		game._strike(me, them, "strike", 5, 0.0, "ike")
			> game._strike(me, them, "strike", 1, 0.0, "ike"))
	done += 1


## Every flat bonus is quoted in the same raw units a word's letters are counted
## in, so every one has to be scaled on the way to a scoreboard. The salvo was;
## the topout and the win were not, which is why they never bit.
func _bonuses_are_scaled() -> void:
	print("--- the flat bonuses are paid at scale ---")
	_expect("a topout is worth more than a salvo",
		Scoring.flat(Scoring.TOPOUT_BONUS) > Scoring.flat(Scoring.SALVO_BONUS))
	# The whole point of the win bonus is to outweigh whatever the loser piled up
	# in the last few seconds, so it has to be the biggest flat thing there is.
	_expect("and taking the match is worth more than either",
		Scoring.flat(Scoring.WIN_BONUS) > Scoring.flat(Scoring.TOPOUT_BONUS))
	_expect("scaling is what SCALE says it is",
		Scoring.flat(Scoring.WIN_BONUS) == Scoring.WIN_BONUS * Scoring.SCALE)
	done += 1


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
		me.score == before + Scoring.flat(Scoring.TOPOUT_BONUS))

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
	# Checked against the figure rather than against zero: it was never zero, it
	# was a fifth of what it should have been, which "worth something" cannot see.
	_expect("taking the match pays the scaled bonus",
		comfortable == Scoring.flat(Scoring.WIN_BONUS + 3 * Scoring.LIFE_BONUS))

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


## A long word is worth something on its own.
##
## It used to reach the board only through the chain ladder, so ONOMATOPOEIA
## thrown from a standing start sent the same 1x1 as ONE — the game did not care
## what you found, only how fast you kept finding. The floor is the *larger* of
## the two ladders rather than their sum, so a long word inside a long run does
## not stack into an instant 4x3.
func _length_sets_a_floor() -> void:
	print("--- length is worth something by itself ---")
	# Written against the shape rather than the step positions. The ladder is
	# tuning and has moved once already; what must not move is that it climbs,
	# that it climbs more than twice, and that it stops.
	_expect("the shortest word earns no length tier", game._length_tier("one") == 0)
	var climbs := 0
	var last := 0
	var backwards := false
	for n in range(3, 20):
		var t: int = game._length_tier("a".repeat(n))
		if t > last:
			climbs += 1
		elif t < last:
			backwards = true
		last = t
	_expect("it climbs at least three times (%d)" % climbs, climbs >= 3)
	_expect("and never falls back", not backwards)
	_expect("and it never runs past the table",
		game._length_tier("a".repeat(40)) < game.TIERS.size())

	# The two ladders combine as the better plus half the other, so that length
	# keeps counting once the chain has overtaken it. It used to be the better
	# and nothing else, which meant that from chain 3 onwards every word threw
	# the same block whatever it was — see `game._base_tier`.
	var chain_t: int = game._chain_tier(3)
	var short_t: int = game._base_tier(3, "cat")
	var long_t: int = game._base_tier(3, "onomatopoeia")
	_expect("a short word in a run is worth the run (%d)" % short_t,
		short_t == chain_t)
	_expect("a long word in the same run is worth more (%d vs %d)"
		% [long_t, short_t], long_t > short_t)
	# And still not both ladders added, or a good word in a good run would jump
	# straight to the top of the table.
	_expect("but not the two simply added (%d)" % long_t,
		long_t < chain_t + game._length_tier("onomatopoeia"))


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

	# Every target pinned, including your own. `start_match` aims everyone, and
	# an unaimed board is aimed at whoever `_pick_target_for` happened to roll —
	# so leaving side 0 alone made this a coin flip on whether the player was
	# also pointing at the board under test. It passed for a while by luck.
	game.sides[0].target = 1
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


## Two payouts inside the same moment have to be two readable numbers.
##
## The bug: every pop started at one fixed height with a ±40 horizontal jitter,
## which is narrower than the numbers are wide. A strike and the salvo it
## completed resolve in the same frame, so the two were drawn on top of each
## other and neither could be read. Caught in a store preview, where it was on
## screen for most of the video, but it happens to everybody in ordinary play.
func _pops_do_not_pile_up() -> void:
	print("--- two payouts at once are two readable numbers ---")
	game.start_match("Rookie", 1)
	game.phase = game.Phase.PLAY
	game.score_pops.clear()

	game._pop_score("+480", "5x2 block", 480)
	game._pop_score("+829", "SALVO", 829)
	_expect("both are on screen", game.score_pops.size() == 2)
	var a: Vector2 = (game.score_pops[0] as Dictionary)["at"]
	var b: Vector2 = (game.score_pops[1] as Dictionary)["at"]
	_expect("and they are not at the same height (%.0f vs %.0f)" % [a.y, b.y],
		absf(a.y - b.y) >= game.POP_STACK_STEP)

	# Far enough apart to actually be two lines rather than two overlapping
	# ones. The `note` under a pop is drawn at `size * 0.72` below it, and the
	# largest a pop gets is 58.
	_expect("far enough apart to clear the note line under the first",
		absf(a.y - b.y) > 58.0 * 0.72)

	# A salvo can land a handful at once, and they must not march off the board.
	for i in 8:
		game._pop_score("+100", "", 100)
	var top := 0.0
	var base := 0.0
	for p: Dictionary in game.score_pops:
		var y: float = (p["at"] as Vector2).y
		base = maxf(base, y)
		top = minf(top, y) if top != 0.0 else y
	_expect("a pile of them stays within the cap (%.0f of %.0f)"
		% [base - top, game.POP_STACK_MAX], base - top <= game.POP_STACK_MAX)

	# And a pop that has already floated clear stops pushing new ones up, or a
	# long match would walk the stack off the top of the screen.
	game.score_pops.clear()
	game._pop_score("+100", "", 100)
	(game.score_pops[0] as Dictionary)["life"] = 0.1
	game._pop_score("+200", "", 200)
	var fresh: Vector2 = (game.score_pops[0] as Dictionary)["at"]
	var later: Vector2 = (game.score_pops[1] as Dictionary)["at"]
	_expect("an old pop no longer holds the base slot",
		is_equal_approx(fresh.y, later.y))


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-52s %s" % [what, "ok" if ok else "FAILED"])
