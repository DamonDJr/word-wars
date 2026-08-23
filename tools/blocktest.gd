extends SceneTree
## What a block does, now that a block only does one thing.
##
## This suite used to check six special kinds — armour that ate a word, bombs
## that took their neighbours, splits, ice, curses and fuses. They are gone, and
## `clear_matching` was rewritten down to the one rule that is left: a word
## whose opening letters match a stamp destroys that block, up to the reach the
## word buys. Which is exactly why the file is still here rather than deleted —
## the rewrite is new code, it is the code every mode depends on, and the rules
## below are the ones that used to be tangled up with the kinds.
##
## `WWBoard` is loaded by path rather than named. Under `--script` the autoloads
## are not registered when a tool script's dependencies compile, and `board.gd`
## names `WordBank` — so mentioning `WWBoard` at parse time fails to compile the
## whole chain. That is not hypothetical: it is what this suite was doing. It
## defined twenty-three assertions, reported two, and still printed "blocks
## behave" and exited 0, because a section that dies on its first line prints its
## heading and nothing else. `SECTIONS` is the guard against that.
##
##   godot --headless --script tools/blocktest.gd

var game: Node
var fails := 0
var done := 0
const SECTIONS := 4
## Set in `_init`, once there is a frame and the autoloads exist.
var WWB: GDScript


func _init() -> void:
	await process_frame
	game = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	WWB = load("res://scripts/board.gd")
	game.start_match("Rookie", 1)
	game.phase = game.Phase.PLAY
	await process_frame

	_a_word_takes_what_it_matches()
	_reach_is_the_limit()
	_nothing_is_special()
	_a_full_board_tops_out()

	if done != SECTIONS:
		fails += 1
		print("  %-52s %s" % ["all %d sections ran" % SECTIONS,
			"FAILED (%d did)" % done])
	print("--- %s ---" % ("blocks behave" if fails == 0 else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)


## The whole rule: the stamp is a prefix, and a word that opens with it wins.
func _a_word_takes_what_it_matches() -> void:
	print("--- a word takes the blocks it opens ---")
	var b = _fresh()
	b.add_garbage("al", 0, 1, 1)
	b.add_garbage("zz", 0, 1, 1)
	_expect("a matching word takes its block", b.clear_matching("alarm", 4) == 1)
	_expect("and leaves the one it does not match", b.blocks.size() == 1)
	_expect("a word matching nothing takes nothing",
		b.clear_matching("quiet", 4) == 0)
	_expect("and the board is untouched", b.blocks.size() == 1)

	# The stamp has to be the *start* of the word, not merely inside it.
	b = _fresh()
	b.add_garbage("arm", 0, 1, 1)
	_expect("a stamp in the middle is not a match",
		b.clear_matching("alarm", 4) == 0)
	_expect("and the block is still standing", b.blocks.size() == 1)
	done += 1


## One word only reaches so far, which is the rule that makes a long word worth
## looking for. Every two letters buys one block.
func _reach_is_the_limit() -> void:
	print("--- reach is what a word can carry ---")
	_expect("two letters a block", WWB.reach("align") == 2)
	_expect("and a longer word reaches further",
		WWB.reach("alignment") > WWB.reach("align"))

	var b = _fresh()
	for i in 4:
		b.add_garbage("al", 0, 1, 1)
	_expect("a short word cannot take them all",
		b.clear_matching("all", WWB.reach("all")) == 1)
	_expect("three are left", b.blocks.size() == 3)
	_expect("a long one takes the rest",
		b.clear_matching("alignment", WWB.reach("alignment")) == 3)
	_expect("and the board is clear", b.blocks.is_empty())

	# `would_clear` is what the HUD highlights with, so it has to agree with what
	# actually happens — a highlight promising a clear that does not come is
	# worse than no highlight.
	b = _fresh()
	for i in 3:
		b.add_garbage("al", 0, 1, 1)
	var promised: int = b.would_clear("alarm", WWB.reach("alarm"))
	_expect("the preview promises what the word delivers",
		promised == b.clear_matching("alarm", WWB.reach("alarm")))
	done += 1


## There is no second category of block any more. Nothing survives a word that
## matched it, nothing takes anything else with it, and nothing changes under
## the player between one frame and the next.
func _nothing_is_special() -> void:
	print("--- and nothing is special about any of them ---")
	var b = _fresh()
	b.add_garbage("al", 0, 1, 1)
	b.add_garbage("zz", 0, 1, 1)
	b.add_garbage("en", 0, 1, 1)
	var before: int = b.blocks.size()
	var gone: int = b.clear_matching("alarm", 4)
	_expect("a word takes exactly what it matched", gone == 1)
	_expect("and nothing goes with it", b.blocks.size() == before - gone)

	# Stamps used to re-write themselves on a timer. Nothing does now, so a board
	# left alone is the same board however long you look at it.
	var stamps: Array = []
	for blk in b.blocks:
		stamps.append(blk.prefix)
	for i in 30:
		b._process(0.1)
	var after: Array = []
	for blk in b.blocks:
		after.append(blk.prefix)
	_expect("a board left alone does not change under you", stamps == after)
	_expect("and nothing goes off on its own", b.blocks.size() == before - gone)
	done += 1


## Overfilling is the only way to lose, so `add_garbage` refusing has to mean it.
func _a_full_board_tops_out() -> void:
	print("--- a board that cannot take another block says so ---")
	var b = _fresh()
	var fitted := 0
	var topped := false
	# A few past what the grid holds: exactly COLS * ROWS ones fit, so a loop
	# bounded at the cell count never asks the question this is here to ask.
	for i in int(WWB.COLS) * int(WWB.ROWS) + 4:
		if b.add_garbage("zz", 0, 1, 1):
			fitted += 1
		else:
			topped = true
			break
	_expect("it fills up", fitted > 0)
	_expect("and then refuses", topped)
	_expect("having taken no more than it holds",
		fitted <= int(WWB.COLS) * int(WWB.ROWS))
	done += 1


func _fresh():
	var b = game.player.board
	b.reset()
	return b


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-52s %s" % [what, "ok" if ok else "FAILED"])
