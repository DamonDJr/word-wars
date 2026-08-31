extends SceneTree
## Achievements, the survival board, and the ad cadence.
##
##   godot --headless --script tools/awardtest.gd
##
## None of this can be exercised by playing on the machine it is written on:
## Game Center refuses to exist off an Apple device, so every call here returns
## early on the only platform that can run the test. What is checkable is the
## shape — that the ids are well formed, that every requirement resolves to a
## real percentage, that nothing walks backwards, and that the classes the code
## calls are still the ones the plugin ships.

var fails := 0


func _init() -> void:
	await process_frame
	_the_plugin_still_has_these()
	_every_award_resolves()
	_progress_only_moves_forward()
	_ids_are_well_formed()
	_the_cadence_is_what_we_think()

	print("--- %s ---" % ("awards behave" if fails == 0 else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)


## The classes and calls this code depends on, pinned against `ClassDB`.
##
## Same job `gctest` does for matchmaking: the plugin is a binary nobody here
## controls, and a rename in it fails at the call rather than at the build. On a
## desktop these all register and refuse to construct, which is exactly enough to
## check the names.
func _the_plugin_still_has_these() -> void:
	print("--- the plugin still has what we call ---")
	for c in ["GKAchievement", "GKAchievementDescription", "GKLeaderboard"]:
		_expect("%-24s registers" % c, ClassDB.class_exists(c))
	for m in ["make", "report_achievement", "load_achievements"]:
		_expect("GKAchievement.%-20s exists" % m,
			ClassDB.class_has_method("GKAchievement", m, true))
	for p in ["percent_complete", "identifier", "shows_completion_banner"]:
		_expect("GKAchievement.%-20s exists" % p,
			ClassDB.class_has_integer_constant("GKAchievement", p)
			or _has_property("GKAchievement", p))


func _has_property(cls: String, prop: String) -> bool:
	for p in ClassDB.class_get_property_list(cls, true):
		if String(p["name"]) == prop:
			return true
	return false


## Every requirement in the catalogue has to be one `Profile.standing` knows.
##
## An unrecognised key falls through its `match` and returns `have = 0`, which is
## not an error and never will be — it is an achievement silently stuck at zero
## per cent for the life of the app.
func _every_award_resolves() -> void:
	print("--- every award resolves to a percentage ---")
	var p = Engine.get_main_loop().root.get_node("Profile")
	var awards = Engine.get_main_loop().root.get_node("Awards")
	_expect("there are awards to report", awards.AWARDS.size() >= 10)

	for id: String in awards.AWARDS:
		var need: Dictionary = awards.AWARDS[id]
		var s: Dictionary = p.standing(need)
		_expect("%-18s has a target" % id, int(s.get("want", 0)) > 0)
		# `what` is how the mastery screen describes a locked entry. Empty means
		# `standing` did not recognise the key.
		_expect("%-18s is described" % id, String(s.get("what", "")) != "")


## A fresh profile is at zero, a maxed one at a hundred, and neither overshoots.
## Apple rejects anything over 100 and ignores anything below what it holds, so
## an unclamped value is a submission that silently does nothing.
func _progress_only_moves_forward() -> void:
	print("--- progress stays inside nought and a hundred ---")
	var p = Engine.get_main_loop().root.get_node("Profile")
	var awards = Engine.get_main_loop().root.get_node("Awards")
	p.save_path = "user://profile-award-test.cfg"

	p.matches = 0; p.wins = 0; p.words = 0
	var lo: float = awards._percent({"matches": 10})
	_expect("nothing played is 0%% (got %.0f)" % lo, is_zero_approx(lo))

	p.matches = 500
	var hi: float = awards._percent({"matches": 10})
	_expect("fifty times over is capped at 100%% (got %.0f)" % hi,
		is_equal_approx(hi, 100.0))

	p.matches = 5
	var mid: float = awards._percent({"matches": 10})
	_expect("half way is 50%% (got %.0f)" % mid, is_equal_approx(mid, 50.0))

	# A need with no target must not divide by zero, and must not read as done.
	# `Profile.standing` answers 100% for an empty need — correct for a starter
	# cosmetic, catastrophic for an achievement, which would unlock itself with a
	# banner on first launch.
	_expect("an empty need is 0%, not complete",
		is_zero_approx(awards._percent({})))

	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p.save_path + suffix))


## Ids are typed into App Store Connect by hand, and a mismatch is silent.
func _ids_are_well_formed() -> void:
	print("--- the ids are shaped like the others ---")
	var awards = Engine.get_main_loop().root.get_node("Awards")
	var boards = Engine.get_main_loop().root.get_node("Boards")
	_expect("the award prefix is reverse-DNS",
		awards.PREFIX.begins_with("com.damonj.wordwars."))
	_expect("the survival board matches the daily's convention",
		boards.SURVIVAL_ID.begins_with("com.damonj.wordwars."))
	_expect("and is not the daily board",
		boards.SURVIVAL_ID != boards.DAILY_ID)

	var seen := {}
	for id: String in awards.AWARDS:
		_expect("%-18s asks for something" % id,
			not (awards.AWARDS[id] as Dictionary).is_empty())
		_expect("%-18s is lowercase and plain" % id,
			id == id.to_lower() and not id.contains(" ") and not id.contains("."))
		_expect("%-18s is unique" % id, not seen.has(id))
		seen[id] = true


## The numbers a player actually feels. Asserted because they were retuned off a
## single report of "two ads in twenty minutes", and the two budgets only stay
## interchangeable while they cost about the same.
func _the_cadence_is_what_we_think() -> void:
	print("--- the ad cadence ---")
	var p = Engine.get_main_loop().root.get_node("Profile")
	_expect("a break comes every %d-%d matches" % [p.ADS_EVERY_MIN, p.ADS_EVERY_MAX],
		p.ADS_EVERY_MIN >= 2 and p.ADS_EVERY_MAX <= 3)
	_expect("or every %.0f-%.0f minutes" % [p.ADS_MINUTES_MIN, p.ADS_MINUTES_MAX],
		p.ADS_MINUTES_MIN >= 4.0 and p.ADS_MINUTES_MAX <= 9.0)
	# Two on purpose, never one: a break after every single match is a rhythm
	# players learn to feel coming, and the match they feel it on is the one they
	# stop before.
	_expect("but never after every match", p.ADS_EVERY_MIN >= 2)
	_expect("and the clock is the looser of the two for normal play",
		p.ADS_MINUTES_MIN * 60.0 > float(p.ADS_EVERY_MIN) * 60.0)


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-52s %s" % [what, "ok" if ok else "FAILED"])
