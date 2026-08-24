extends SceneTree
## The two things a profanity filter gets wrong: letting something through, and
## refusing an innocent word because a rude one is hiding inside it.
##
##   godot --headless --script tools/censortest.gd

var fails := 0


func _init() -> void:
	# Autoloads are not up until a frame has passed.
	await process_frame
	print("--- caught ---")
	for w in ["shit", "SHIT", "Shit!", "fucking", "bitches", "arsehole",
			"twats", "wanker", "bollocks"]:
		_expect("%s is masked" % w, Censor.clean(w) != w)

	print("--- names, where somebody can punctuate around the list ---")
	for w in ["s.h.i.t", "S H I T", "f-u-c-k", "shit"]:
		_expect("the name %s is masked" % w, Censor.clean_name(w) != w)
	for w in ["K-RIZMA", "Mary-Jane", "O'Brien", "classic"]:
		_expect("the name %s survives" % w, Censor.clean_name(w) == w)

	print("--- not caught (the Scunthorpe problem) ---")
	# Every one of these contains a rude substring. In a game about the letters
	# inside words, substring matching would fire on these constantly.
	for w in ["classic", "assassin", "assess", "assign", "asset", "class",
			"shuttlecock", "cockpit", "Scunthorpe", "analysis", "bass", "grass",
			"pastitsio", "titles", "constitution", "dickens", "hellenic",
			"shiitake", "mishit", "cumulative", "circumstance", "document"]:
		_expect("%s survives" % w, Censor.clean(w) == w)

	print("--- sentences ---")
	var line := "YOU: SHIT x3 (cleared 2, sent 2x2)"
	var got: String = Censor.clean(line)
	_expect("a log line keeps its shape", got == "YOU: **** x3 (cleared 2, sent 2x2)")
	_expect("length is preserved", Censor.clean("fuck").length() == 4)
	_expect("an ordinary line is untouched",
		Censor.clean("YOU: ALIGNMENT x2 (sent 2x1)") == "YOU: ALIGNMENT x2 (sent 2x1)")
	_expect("empty input is safe", Censor.clean("") == "")

	print("--- stamps are never minted rude ---")
	# The important one: a stamp must never need masking, because a masked stamp
	# is a block nobody can answer.
	var wb = Engine.get_main_loop().root.get_node("WordBank")
	var minted := 0
	var rude := 0
	for i in 4000:
		var st = wb.stamp_from_tail(wb.random_common(1.0), 4, 40, 6)
		minted += 1
		if Censor.is_profane(st):
			rude += 1
			print("    MINTED: %s" % st)
	_expect("%d stamps, none of them rude" % minted, rude == 0)

	print("--- slurs are not words this game knows ---")
	# Masking a slur on screen while still paying points for it is a ranked game
	# rewarding hate speech quietly. These are removed from the dictionary, so
	# they cannot be typed for score, minted onto a block, or reach a leaderboard.
	var leaked := 0
	for w in Censor.SLURS:
		if wb.is_valid(w):
			leaked += 1
			print("    PLAYABLE: %s" % w)
	_expect("all %d refused by the dictionary" % Censor.SLURS.size(), leaked == 0)

	# The other half, and the one that is easy to get wrong. Running the profanity
	# suffixes over these deletes `spicy` and `spices`, so the slur list is written
	# out in full instead — this is what proves it still is.
	var innocent := ["spicy", "spices", "spice", "coonhound", "flag", "flags",
		"scunthorpe", "assess", "assign", "classic", "shuttlecock"]
	var lost := 0
	for w in innocent:
		# Only the ones the dictionary actually carries; the point is that nothing
		# was taken away, not that every example is in the word list.
		if Censor.is_slur(w):
			lost += 1
			print("    WRONGLY REFUSED: %s" % w)
	_expect("no ordinary word caught by the slur list", lost == 0)

	# And profanity is still playable, which is the whole distinction.
	var rude_gone := 0
	for w in ["damn", "hell", "shit", "arse", "bugger", "dyke", "cracker", "queer"]:
		if not wb.is_valid(w):
			rude_gone += 1
			print("    LOST: %s" % w)
	_expect("rude words are masked, not removed", rude_gone == 0)

	print("--- %s ---" % ("censor behaves" if fails == 0 else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-46s %s" % [what, "ok" if ok else "FAILED"])
