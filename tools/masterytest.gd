extends SceneTree
## Headless check on the mastery record: that XP and levels move the way the
## table says, that unlocks open on the right thresholds and not before, that
## equipping refuses what has not been earned, and — the one that actually
## matters — that a saved profile survives a round trip to disk.
##
## A bug anywhere in here costs somebody every hour they have put in, which is a
## different order of mistake from a block landing in the wrong column.
##
##   godot --headless --script tools/masterytest.gd

const SCRATCH := "user://profile-test.cfg"

var fails := 0


func _init() -> void:
	await process_frame
	var p = Engine.get_main_loop().root.get_node("Profile")
	p.save_path = SCRATCH
	_wipe(p)

	_levels(p)
	_unlocks(p)
	_equipping(p)
	_round_trip(p)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	print("--- %s ---" % ("mastery holds up" if fails == 0 else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)


func _levels(p) -> void:
	print("--- levels ---")
	_expect("a fresh profile is level 1", p.level() == 1)
	_expect("and has earned nothing", p.xp_total() == 0)

	# A modest first match: no win, no heroics.
	p.record_match({"words": 12, "chars": 90, "wpm": 30.0, "chain": 3, "combo": 1,
		"longest": "banking", "powers": {}})
	var after_one: int = p.xp_total()
	_expect("one match is worth something", after_one > 0)
	print("    one ordinary match: %d xp, level %d" % [after_one, p.level()])

	for i in 12:
		p.record_match({"won": true, "words": 30, "wpm": 48.0, "chain": 6,
			"combo": 3, "salvos": 1, "longest": "shipments",
			"powers": {"COMBO": 2, "COUNTER": 1}})
	print("    after thirteen matches: %d xp, level %d" % [p.xp_total(), p.level()])
	_expect("levels climb with play", p.level() > 1)

	var prog: Dictionary = p.level_progress()
	_expect("progress stays inside its own level",
		int(prog["into"]) >= 0 and int(prog["into"]) <= int(prog["need"]))
	_expect("the bar matches the numbers",
		absf(float(prog["frac"]) - float(prog["into"]) / float(prog["need"])) < 0.001)

	# Peaks are peaks: a bad match must not drag your ceiling back down.
	var peak: int = p.best_chain
	p.record_match({"chain": 1, "wpm": 5.0, "longest": "cat", "powers": {}})
	_expect("a bad match cannot lower your best chain", p.best_chain == peak)
	_expect("nor your best wpm", p.best_wpm >= 48.0)
	_expect("nor your longest word", p.longest_word.length() >= 9)
	# Last, because it wipes the record it is measuring against.
	_pacing()


## Not a pass/fail — a curve to look at. The numbers here are the whole feel of
## the system, and they are the thing most likely to be wrong.
func _pacing() -> void:
	var q = Engine.get_main_loop().root.get_node("Profile")
	var save: String = q.save_path
	q.save_path = "user://profile-pace.cfg"
	_wipe(q)
	print("    pacing, for a middling player:")
	for n in [1, 5, 10, 25, 50, 100, 200]:
		_wipe(q)
		for i in n:
			q.record_match({"won": i % 2 == 0, "flawless": i % 9 == 0,
				"words": 26, "chars": 190, "wpm": 42.0, "chain": 6, "combo": 3,
				"salvos": 1, "longest": "shipments",
				"powers": {"COMBO": 2, "COUNTER": 1}})
		print("      %4d matches -> level %-3d (%d xp)" % [n, q.level(), q.xp_total()])
	_wipe(q)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(q.save_path))
	q.save_path = save


func _unlocks(p) -> void:
	print("--- unlocks ---")
	_wipe(p)
	_expect("the defaults are open from the start",
		p.is_unlocked("title", "none") and p.is_unlocked("theme", "midnight"))
	_expect("SALVO KING is not free", not p.is_unlocked("title", "salvo_king"))

	# Exactly on the threshold, and one short of it.
	p.salvos = 11
	_expect("one short does not open it", not p.is_unlocked("title", "salvo_king"))
	p.salvos = 12
	_expect("exactly enough opens it", p.is_unlocked("title", "salvo_king"))

	p.powers = {"CLUTCH": 10}
	_expect("power-word titles read the tally", p.is_unlocked("title", "clutch"))

	_wipe(p)
	p.best_chain = 8
	_expect("Chainbreaker wants a x8 chain", p.is_unlocked("title", "chainbreaker"))
	_expect("and does not also hand over Wordsmith",
		not p.is_unlocked("title", "wordsmith"))

	# Every locked entry has to be able to say what it wants, or the mastery
	# screen shows a blank shrug next to it.
	for slot in p.SLOTS:
		for e in p.entries(slot):
			if (e["need"] as Dictionary).is_empty():
				continue
			var st: Dictionary = p.standing(e["need"])
			if String(st["what"]) == "" or int(st["want"]) <= 0:
				_expect("%s/%s explains itself" % [slot, e["id"]], false)
	_expect("every locked entry explains itself", true)


func _equipping(p) -> void:
	print("--- equipping ---")
	_wipe(p)
	_expect("cannot wear what is not earned", not p.equip("title", "salvo_king"))
	_expect("and is not wearing it afterwards", p.worn("title") != "salvo_king")

	p.salvos = 20
	_expect("can wear it once earned", p.equip("title", "salvo_king"))
	_expect("and is wearing it", p.worn("title") == "salvo_king")
	_expect("the title reads out", p.title_text() == "SALVO KING")

	# The failure mode that matters: a profile carrying a cosmetic it no longer
	# qualifies for must fall back rather than show a locked item.
	p.salvos = 0
	_expect("wearing something no longer earned falls back",
		p.worn("title") == "none")


func _round_trip(p) -> void:
	print("--- saving ---")
	_wipe(p)
	p.record_match({"won": true, "flawless": true, "words": 44, "chars": 300,
		"wpm": 61.0, "chain": 7, "combo": 4, "salvos": 2, "longest": "misunderstanding",
		"powers": {"PERFECT": 3, "CLUTCH": 1}})
	p.equip("theme", "midnight")
	var before := {
		"xp": p.xp_total(), "level": p.level(), "words": p.words,
		"wpm": p.best_wpm, "longest": p.longest_word,
		"powers": p.powers.duplicate(), "flawless": p.flawless,
	}
	p.save()

	# Wipe the object in memory, then read it back from the file alone.
	_wipe(p)
	_expect("wiping really wiped it", p.xp_total() == 0)
	p.load_profile()

	_expect("xp survives the round trip", p.xp_total() == int(before["xp"]))
	_expect("level survives", p.level() == int(before["level"]))
	_expect("words survive", p.words == int(before["words"]))
	_expect("best wpm survives", absf(p.best_wpm - float(before["wpm"])) < 0.01)
	_expect("longest word survives", p.longest_word == String(before["longest"]))
	_expect("flawless wins survive", p.flawless == int(before["flawless"]))
	_expect("power tallies survive",
		int(p.powers.get("PERFECT", 0)) == int((before["powers"] as Dictionary)["PERFECT"]))


func _wipe(p) -> void:
	p.matches = 0
	p.wins = 0
	p.flawless = 0
	p.words = 0
	p.chars = 0
	p.salvos = 0
	p.multi_clears = 0
	p.best_wpm = 0.0
	p.best_chain = 0
	p.best_combo = 0
	p.best_score = 0
	p.longest_word = ""
	p.powers = {}
	p.equipped = {}


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-52s %s" % [what, "ok" if ok else "FAILED"])
