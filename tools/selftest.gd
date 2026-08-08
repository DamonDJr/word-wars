extends SceneTree

func _initialize() -> void:
	var wb = load("res://scripts/word_bank.gd").new()
	wb._ready()  # not in the tree, so drive it directly

	print("--- is_valid ---")
	for w in ["strike", "friendship", "qqqqq", "zzz", "ing", "aardvark", "the"]:
		print("  %-12s %s" % [w, wb.is_valid(w)])

	print("--- valid_prefix_count vs common prefix_count ---")
	for p in ["ing", "ship", "cate", "ding", "est", "ke", "x", "st", "zz"]:
		print("  %-5s valid=%-5d common=%-4d answerable=%s" % [
			p, wb.valid_prefix_count(p), wb.prefix_count(p),
			wb.is_answerable(p, 40, 6)])

	print("--- stamp_from_tail (want 4, 40/6) ---")
	for w in ["strike", "running", "nation", "extraordinary", "complex",
			"friendship", "dedicate", "misunderstanding", "tennis", "box",
			"fix", "tax", "index", "happy", "music", "gentlest", "jazz", "quiz",
			"shipments", "mentioned", "developments", "buildings", "shoes",
			"cars", "makes", "happiness", "quickly", "nation"]:
		var s = wb.stamp_from_tail(w, 4, 40, 6)
		print("  %-18s -> %-5s (valid %d / common %d)" % [
			w, s, wb.valid_prefix_count(s), wb.prefix_count(s)])

	print("--- reach: how many blocks one word takes out ---")
	var board = load("res://scripts/board.gd").new()
	for i in 4:
		board.add_garbage("al", 0, 1, 1)
	for probe in ["all", "alarm", "alignment", "album", "alternatively"]:
		print("  %-14s %2d letters  reach %d  clears %d of 4" % [
			probe.to_upper(), probe.length(), WWBoard.reach(probe),
			board.would_clear(probe, WWBoard.reach(probe))])
	# And confirm a clear actually removes exactly that many.
	var before: int = board.blocks.size()
	var took: int = board.clear_matching("alarm", WWBoard.reach("alarm"))
	print("  ALARM removed %d, %d of %d left  %s" % [
		took, board.blocks.size(), before,
		"ok" if took == 2 and board.blocks.size() == 2 else "WRONG"])
	var rest: int = board.clear_matching("alignment", WWBoard.reach("alignment"))
	print("  ALIGNMENT then removed the remaining %d  %s" % [
		rest, "ok" if board.blocks.is_empty() else "WRONG"])

	print("--- stamp variety: 4000 attacks, want 4 ---")
	for mode in ["no memory", "with recent-stamp memory"]:
		var tally := {}
		var recent: Array = []
		var total_len := 0
		for i in 4000:
			var avoid := {}
			if mode.begins_with("with"):
				for s in recent:
					avoid[s] = true
			var st = wb.stamp_from_tail(wb.random_common(1.0), 4, 40, 6, avoid)
			tally[st] = tally.get(st, 0) + 1
			total_len += st.length()
			recent.push_front(st)
			if recent.size() > 8:
				recent.resize(8)
		var ranked := tally.keys()
		ranked.sort_custom(func(a, b): return tally[a] > tally[b])
		var top := []
		for i in mini(10, ranked.size()):
			top.append("%s %.1f%%" % [ranked[i], 100.0 * tally[ranked[i]] / 4000.0])
		print("  %-26s distinct=%d  avg len=%.2f" % [mode, tally.size(), total_len / 4000.0])
		print("     top: %s" % ", ".join(top))

	print("--- stamp length spread over 3000 random common words ---")
	for want in [2, 3, 4, 5]:
		var hist := {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
		var total := 0
		for i in 3000:
			var s = wb.stamp_from_tail(wb.random_common(1.0), want, 40, 6)
			hist[s.length()] = hist.get(s.length(), 0) + 1
			total += s.length()
		print("  want %d -> avg %.2f  %s" % [want, float(total) / 3000.0, hist])

	quit()
