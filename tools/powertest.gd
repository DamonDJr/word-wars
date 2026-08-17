extends SceneTree
## Headless check that the power words fire on exactly the situations they are
## meant to, and stay quiet otherwise.
##
## These cannot be tested by playing: COMBO wants three identically stamped
## blocks and a word long enough to reach all three, CLUTCH wants a board one row
## from the ceiling. Waiting for those to happen by accident is not a test. So
## the board is built to order and the word played straight into `_play_word`.
##
##   godot --headless --script tools/powertest.gd

var game: Node
var fails := 0


func _init() -> void:
	await process_frame
	game = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame

	game.start_match("Rookie", 1)
	game.phase = game.Phase.PLAY
	await process_frame

	_long_words_are_worth_more()
	_combo_and_perfect()
	_combo_without_chain()
	_counter()
	_clutch()
	_quiet_when_nothing_happens()

	print("--- %s ---" % ("all power words behave" if fails == 0 else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------- scenarios

## Three blocks stamped AL, a word that reaches all three, and a run already
## going. That is COMBO and PERFECT together: the tier owed to the next attack,
## and a whole extra block out the door now.
## A long word has to move the chain further than a short one.
##
## It did not, for the whole life of the game: the ladder counted how often you
## fired and nothing about what you fired, so CAT and CONSTELLATION were the
## same move. Reaching for a long word costs time, and if it buys nothing then
## the optimal play is to spam the shortest valid word forever — which is both
## boring and, for a game about vocabulary, the wrong lesson entirely.
func _long_words_are_worth_more() -> void:
	print("--- a long word fills more of the meter ---")
	var short_gain: float = game._chain_gain("cat")
	var long_gain: float = game._chain_gain("constellation")
	_expect("a minimum word is worth exactly one", is_equal_approx(short_gain, 1.0))
	_expect("a long word is worth more", long_gain > short_gain + 0.5)

	# The part that matters at the table: the same number of words gets you
	# further up the ladder when the words are longer.
	game.start_match("Rookie", 1)
	game.phase = game.Phase.PLAY
	var me = game.sides[0]
	me.chain_fill = 0.0
	me.chain = 0
	me.chain_timer = 99.0
	for i in 3:
		me.chain_fill += game._chain_gain("cat")
	var short_tier: int = game._chain_tier(int(floor(me.chain_fill)))

	me.chain_fill = 0.0
	for i in 3:
		me.chain_fill += game._chain_gain("shipment")
	var long_tier: int = game._chain_tier(int(floor(me.chain_fill)))
	_expect("three long words outrank three short ones", long_tier > short_tier)

	# And a run still has to be a run — one enormous word must not skip the
	# ladder outright, or the chain stops meaning consecutive play.
	me.chain_fill = game._chain_gain("antidisestablishmentarianism")
	_expect("one word alone cannot reach the top tier",
		game._chain_tier(int(floor(me.chain_fill))) < game.TIERS.size() - 1)


func _combo_and_perfect() -> void:
	var p = _fresh()
	for i in 3:
		p.board.add_garbage("al", 0, 1, 1)
	p.chain = 3
	p.chain_timer = 2.0            # the run is live, so PERFECT is in play
	var before: int = _rival().pending.size()

	game._play_word(p, "alignment")

	_expect("COMBO fires on three cleared", _fired("COMBO"))
	_expect("PERFECT fires with the run held", _fired("PERFECT"))
	_expect("COMBO owes the next attack a tier", p.tier_bonus == 1)
	# The ordinary attack plus PERFECT's extra one.
	_expect("PERFECT sends a second block", _rival().pending.size() - before >= 2)


## The same three blocks with a lapsed chain. COMBO still pays; PERFECT is the
## harder version and must not.
func _combo_without_chain() -> void:
	var p = _fresh()
	for i in 3:
		p.board.add_garbage("al", 0, 1, 1)
	p.chain = 0
	p.chain_timer = 0.0

	game._play_word(p, "alignment")

	_expect("COMBO fires without a chain", _fired("COMBO"))
	_expect("PERFECT stays quiet without a chain", not _fired("PERFECT"))


## Shooting down something already inbound sends one straight back.
func _counter() -> void:
	var p = _fresh()
	var inbound = load("res://scripts/game.gd").Pending.new()
	inbound.tier = 0
	inbound.prefix = "sh"
	inbound.cells = 1
	inbound.timer = 2.0
	p.pending.append(inbound)
	var before: int = _rival().pending.size()

	game._play_word(p, "shipments")

	_expect("COUNTER fires on an interception", _fired("COUNTER"))
	_expect("COUNTER sends one back per block shot down",
		_rival().pending.size() - before >= 2)


## Clearing anything with one row of headroom left buys a reprieve.
func _clutch() -> void:
	var p = _fresh()
	# Fill to the ceiling with something the test word cannot answer, then add one
	# it can. Garbage fills the deepest gap it can find rather than stacking, so
	# this has to run until the headroom actually reaches the brink instead of
	# assuming a fixed number of blocks gets there.
	for i in 120:
		if p.board.stack_top() <= game.CLUTCH_ROWS:
			break
		p.board.add_garbage("zx", 0, 1, 1)
	p.board.add_garbage("al", 0, 1, 1)
	var headroom: int = p.board.stack_top()

	game._play_word(p, "alarm")

	_expect("board really was at the brink (headroom %d)" % headroom,
		headroom <= game.CLUTCH_ROWS)
	_expect("CLUTCH fires at the brink", _fired("CLUTCH"))
	_expect("CLUTCH slows the garbage", p.slowdown > 0.0)


## The common case: an ordinary word on a quiet board should trip nothing at all.
## A power word that fires constantly is not a power word.
func _quiet_when_nothing_happens() -> void:
	var p = _fresh()
	p.board.add_garbage("al", 0, 1, 1)
	p.chain = 2
	p.chain_timer = 2.0

	game._play_word(p, "alarm")

	for name in ["COUNTER", "COMBO", "PERFECT", "CLUTCH"]:
		_expect("%s stays quiet on an ordinary word" % name, not _fired(name))


# ---------------------------------------------------------------------- harness

## A clean board and an empty log, so each scenario reads only its own results.
func _fresh():
	var p = game.player
	p.board.reset()
	p.pending.clear()
	p.used.clear()
	p.tier_bonus = 0
	p.slowdown = 0.0
	p.chain = 0
	p.chain_timer = 0.0
	p.respite = 0.0
	_rival().pending.clear()
	game.events.clear()
	return p


func _rival():
	return game.sides[1]


## Power words announce themselves in the match log, which is the same evidence
## the player gets.
func _fired(name: String) -> bool:
	for e in game.events:
		if String(e["text"]).contains(name):
			return true
	return false


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-46s %s" % [what, "ok" if ok else "FAILED"])
