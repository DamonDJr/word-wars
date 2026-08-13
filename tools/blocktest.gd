extends SceneTree
## Each block kind has one rule, and each rule has one way of being wrong. These
## build the exact board a rule needs and check it does that and only that.
##
##   godot --headless --script tools/blocktest.gd

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

	_armored()
	_bomb()
	_frozen()
	_split()
	_curse()
	_volatile()
	_off_by_default()

	print("--- %s ---" % ("blocks behave" if fails == 0 else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)


## Two words, not one — and the first must visibly do something, or it reads as
## the game ignoring you.
func _armored() -> void:
	print("--- armoured ---")
	var b = _fresh()
	b.add_garbage("al", 0, 1, 1, WWBoard.Kind.ARMORED)
	var gone: int = b.clear_matching("alarm", 4)
	_expect("the first word destroys nothing", gone == 0)
	_expect("but it cracks the armour", int(b.last_report["cracked"]) == 1)
	_expect("and the block is still there", b.blocks.size() == 1)
	gone = b.clear_matching("alarming", 4)
	_expect("the second word takes it", gone == 1 and b.blocks.is_empty())


## A bomb clears its neighbours, and chains into other bombs — but not forever.
func _bomb() -> void:
	print("--- bomb ---")
	var b = _fresh()
	b.add_garbage("al", 0, 1, 1, WWBoard.Kind.BOMB)
	for i in 4:
		b.add_garbage("zz", 0, 1, 1)
	var before: int = b.blocks.size()
	var gone: int = b.clear_matching("alarm", 1)
	_expect("one word, but more than one block", gone > 1)
	_expect("the neighbours are counted", int(b.last_report["bombed"]) > 0)
	_expect("and are actually gone", b.blocks.size() == before - gone)

	# A full board of bombs must not clear itself off one word.
	b = _fresh()
	b.add_garbage("al", 0, 1, 1, WWBoard.Kind.BOMB)
	for i in 30:
		b.add_garbage("zz", 0, 1, 1, WWBoard.Kind.BOMB)
	var total: int = b.blocks.size()
	b.clear_matching("alarm", 1)
	_expect("a board of bombs does not all go at once (%d of %d left)" % [
		b.blocks.size(), total], b.blocks.size() > 0)


## Ice is not a stamp problem. It must not even be offered as a match, or the
## highlight promises a clear that cannot happen.
func _frozen() -> void:
	print("--- frozen ---")
	var b = _fresh()
	b.add_garbage("al", 0, 1, 1, WWBoard.Kind.FROZEN)
	_expect("a frozen block is not a match", b.matching_blocks("alarm").is_empty())
	_expect("and the preview agrees", b.would_clear("alarm", 4) == 0)
	var gone: int = b.clear_matching("alarm", 4)
	_expect("so the word does nothing", gone == 0 and b.blocks.size() == 1)

	b.add_garbage("zz", 0, 1, 1)
	b.clear_matching("zzz", 4)
	_expect("breaking something else thaws it", int(b.last_report["thawed"]) == 1)
	_expect("and now it can be answered", b.clear_matching("alarm", 4) == 1)


## Destroying it leaves two smaller problems where one bigger one was.
func _split() -> void:
	print("--- split ---")
	var b = _fresh()
	b.add_garbage("al", 3, 2, 2, WWBoard.Kind.SPLIT)
	b.clear_matching("alarm", 4)
	_expect("it reports the split", int(b.last_report["split"]) == 1)
	_expect("and leaves two behind", b.blocks.size() == 2)
	var small := true
	for c in b.blocks:
		if c.w != 1 or c.h != 1 or c.kind == WWBoard.Kind.SPLIT:
			small = false
	_expect("both are small, and neither splits again", small)


## The stamp moves. The point is the decision it forces, so it has to actually
## change and it has to stay answerable.
func _curse() -> void:
	print("--- cursed ---")
	var b = _fresh()
	b.add_garbage("al", 0, 1, 1, WWBoard.Kind.CURSE)
	var first: String = b.blocks[0].prefix
	var changed := false
	for i in 400:
		b._tick_kinds(0.1)
		if b.blocks[0].prefix != first:
			changed = true
			break
	_expect("the stamp changes on its own", changed)
	_expect("and it is still a real stamp", b.blocks[0].prefix.length() > 0)


## Leave it and it costs you. It does not clear itself — that would reward
## ignoring it.
func _volatile() -> void:
	print("--- volatile ---")
	var b = _fresh()
	b.add_garbage("al", 0, 1, 1, WWBoard.Kind.VOLATILE)
	var blew := [false]
	b.volatile_blew.connect(func(_at): blew[0] = true)
	for i in int(WWBoard.VOLATILE_FUSE * 10.0) + 20:
		b._tick_kinds(0.1)
	_expect("the fuse runs out", blew[0])
	_expect("and the block is still on the board", b.blocks.size() == 1)


## The base game has to stay the base game for anybody who never opens the
## lobby switches.
func _off_by_default() -> void:
	print("--- off unless asked for ---")
	game.block_kinds = []
	var plain := true
	for i in 400:
		if game._roll_kind() != WWBoard.Kind.PLAIN:
			plain = false
	_expect("no specials with nothing switched on", plain)

	game.block_kinds = ["bomb"]
	var seen := {}
	for i in 3000:
		seen[game._roll_kind()] = true
	_expect("only what was switched on turns up",
		seen.size() <= 2 and seen.has(WWBoard.Kind.BOMB))
	game.block_kinds = []


func _fresh():
	var b = game.player.board
	b.reset()
	b.mint = func() -> String: return ["al", "sh", "en", "ing"].pick_random()
	return b


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-52s %s" % [what, "ok" if ok else "FAILED"])
