extends SceneTree
## Cloud saves: the merge, the round trip, and the rule that stops a fresh
## install from erasing a hundred matches.
##
##   godot --headless --script tools/cloudtest.gd
##
## Game Center refuses to exist off an Apple device, so the half of `cloud.gd`
## that talks to Apple cannot be run here and is pinned against `ClassDB`
## instead — the same trade `gctest` and `awardtest` make, and for the same
## reason: the plugin is a binary nobody here controls, and a rename in it fails
## at the call, on a phone, inside a callback nobody is watching.
##
## The half that *can* be run here is the half that decides what a player keeps,
## and it is exercised properly. Every test below is a scenario somebody could
## actually be in — a new phone, two devices, a purchase made on one of them —
## and the thing being checked is always the same: that nothing a sync does can
## leave a player with less than they had before it.

const PROFILE := "res://scripts/profile.gd"
const CLOUD := "res://scripts/cloud.gd"

var fails := 0


func _init() -> void:
	await process_frame
	_the_plugin_still_has_these()
	_a_profile_survives_the_round_trip()
	_a_new_phone_gets_everything_back()
	_a_full_profile_is_not_erased_by_a_blank_one()
	_two_devices_keep_the_best_of_both()
	_nothing_a_merge_does_moves_a_number_down()
	_purchases_and_days_are_unions()
	_the_ad_cadence_is_left_alone()
	_a_merge_says_whether_it_gained()
	_the_upload_refuses_until_it_has_downloaded()
	_a_sync_that_never_answers_gives_up()
	_a_download_does_not_swallow_a_pending_upload()
	_a_download_holds_on_to_what_it_is_downloading()
	_it_only_claims_a_backup_it_has_confirmed()

	print("--- %s ---" % ("cloud saves behave" if fails == 0 else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)


## Every plugin call `cloud.gd` makes, checked against the registered API.
##
## On a desktop these all register and refuse to construct, which is exactly
## enough to check that the names and arities are still there.
func _the_plugin_still_has_these() -> void:
	print("--- the plugin still has what we call ---")
	for c in ["GKLocalPlayer", "GKSavedGame"]:
		_expect("%-22s registers" % c, ClassDB.class_exists(c))
	for m in ["save_game_data", "fetch_saved_games", "resolve_conflicting_saved_games",
			"register_listener"]:
		_expect("GKLocalPlayer.%-32s exists" % m,
			ClassDB.class_has_method("GKLocalPlayer", m, true))
	_expect("GKSavedGame.load_data%-24s exists" % "",
		ClassDB.class_has_method("GKSavedGame", "load_data", true))
	# The conflict signal is the whole of the two-device story. Connected by
	# name, so a rename would be a runtime error inside Apple's callback.
	_expect("GKLocalPlayer has conflicting_saved_games",
		_has_signal("GKLocalPlayer", "conflicting_saved_games"))


func _has_signal(cls: String, sig: String) -> bool:
	for s in ClassDB.class_get_signal_list(cls, true):
		if String(s["name"]) == sig:
			return true
	return false


## What goes up has to be what comes down. Everything a player can see is
## checked field by field, because a serialiser that quietly drops one key is
## indistinguishable from a working one until somebody loses that key.
func _a_profile_survives_the_round_trip() -> void:
	print("--- a profile survives being turned into bytes and back ---")
	var a := _make({
		"matches": 41, "wins": 19, "flawless": 3, "words": 620, "chars": 4100,
		"salvos": 12, "multi_clears": 30, "best_wpm": 66.5, "best_chain": 9,
		"best_combo": 5, "best_score": 8800, "longest_word": "ALIGNMENT",
		"powers": {"COUNTER": 31, "CLUTCH": 11},
		"owned": {"premium": true},
		"daily": {"2026-09-01": {"score": 900, "wpm": 60, "words": 20, "chain": 4}},
		"daily_best": 900, "daily_best_streak": 7,
		"survival_best_time": 412.5, "survival_best_score": 5100, "survival_runs": 6,
		"equipped": {"title": "salvo_king", "theme": "ember"},
		"prefs": {"music": 0.4, "taught": true},
	})
	var b: Node = load(PROFILE).new()
	_expect("the bytes parse", b.from_bytes(a.to_bytes()))

	for f in ["matches", "wins", "flawless", "words", "chars", "salvos",
			"multi_clears", "best_wpm", "best_chain", "best_combo", "best_score",
			"longest_word", "daily_best", "daily_best_streak", "survival_runs",
			"survival_best_time", "survival_best_score"]:
		_expect("%-20s comes back" % f, a.get(f) == b.get(f))
	_expect("powers come back", b.powers.get("COUNTER", 0) == 31)
	_expect("purchases come back", b.owns("premium"))
	_expect("the daily history comes back", b.daily.has("2026-09-01"))
	_expect("what is worn comes back", String(b.equipped.get("title", "")) == "salvo_king")
	_expect("settings come back", bool(b.prefs.get("taught", false)))
	# The derived numbers are the ones a player actually reads, so they are
	# checked as well as the fields they are built from.
	_expect("and so does the level", a.level() == b.level())
	a.free()
	b.free()


## The reason this feature exists. A profile with nothing in it, merged with one
## that has a career in it, has to end up with the career.
func _a_new_phone_gets_everything_back() -> void:
	print("--- a new phone gets everything back ---")
	var fresh: Node = load(PROFILE).new()
	var old := _make({
		"matches": 120, "wins": 61, "words": 3000, "best_wpm": 71.0,
		"best_chain": 9, "longest_word": "PERPENDICULAR",
		"owned": {"premium": true},
		"daily_best_streak": 22,
		"equipped": {"title": "centurion", "theme": "vapor"},
		"prefs": {"taught": true},
	})
	var before: int = fresh.level()
	_expect("the merge reports a gain", fresh.merge_from(old))
	_expect("the matches are back", fresh.matches == 120)
	_expect("the level is back", fresh.level() == old.level() and fresh.level() > before)
	_expect("the purchase is back", fresh.owns("premium"))
	_expect("the streak record is back", fresh.daily_best_streak == 22)
	_expect("the loadout is back", String(fresh.equipped.get("title", "")) == "centurion")
	# Specifically: the tutorial does not open its mouth on the new phone.
	_expect("and the tutorial knows it was taught", bool(fresh.pref("taught")))
	fresh.free()
	old.free()


## The same scenario pointed the other way, which is the one that loses a
## player's game if it is wrong: a blank profile must never subtract.
func _a_full_profile_is_not_erased_by_a_blank_one() -> void:
	print("--- a blank save cannot erase a full one ---")
	var full := _make({
		"matches": 120, "wins": 61, "best_wpm": 71.0, "longest_word": "PERPENDICULAR",
		"owned": {"premium": true},
		"daily": {"2026-08-30": {"score": 700}},
		"equipped": {"title": "centurion"},
	})
	var blank: Node = load(PROFILE).new()
	_expect("nothing is gained from an empty one", not full.merge_from(blank))
	_expect("the matches are untouched", full.matches == 120)
	_expect("the peak is untouched", is_equal_approx(full.best_wpm, 71.0))
	_expect("the longest word is untouched", full.longest_word == "PERPENDICULAR")
	_expect("the purchase is untouched", full.owns("premium"))
	_expect("the history is untouched", full.daily.has("2026-08-30"))
	_expect("and the loadout is untouched",
		String(full.equipped.get("title", "")) == "centurion")
	full.free()
	blank.free()


## Two devices, each ahead on something. Both sides of every pair have to come
## through, and the merge has to be the same whichever device runs it.
func _two_devices_keep_the_best_of_both() -> void:
	print("--- two devices keep the best of both ---")
	var phone := _make({
		"matches": 40, "wins": 20, "best_wpm": 71.0, "best_chain": 5,
		"longest_word": "SHORT", "powers": {"COUNTER": 30, "CLUTCH": 2},
		"survival_best_time": 400.0, "survival_best_score": 100,
	})
	var tablet := _make({
		"matches": 12, "wins": 30, "best_wpm": 55.0, "best_chain": 9,
		"longest_word": "PERPENDICULAR", "powers": {"COUNTER": 5, "PERFECT": 25},
		"survival_best_time": 90.0, "survival_best_score": 9000,
	})
	# Merged the other way as well, to prove the answer does not depend on which
	# device happened to open the game first.
	var mirror := _make({
		"matches": 12, "wins": 30, "best_wpm": 55.0, "best_chain": 9,
		"longest_word": "PERPENDICULAR", "powers": {"COUNTER": 5, "PERFECT": 25},
		"survival_best_time": 90.0, "survival_best_score": 9000,
	})
	var other := _make({
		"matches": 40, "wins": 20, "best_wpm": 71.0, "best_chain": 5,
		"longest_word": "SHORT", "powers": {"COUNTER": 30, "CLUTCH": 2},
		"survival_best_time": 400.0, "survival_best_score": 100,
	})
	phone.merge_from(tablet)
	mirror.merge_from(other)

	_expect("the higher match count wins", phone.matches == 40)
	_expect("the higher win count wins", phone.wins == 30)
	_expect("the faster wpm wins", is_equal_approx(phone.best_wpm, 71.0))
	_expect("the longer chain wins", phone.best_chain == 9)
	_expect("the longer word wins", phone.longest_word == "PERPENDICULAR")
	_expect("each power keeps its own best", phone.powers["COUNTER"] == 30
		and phone.powers["CLUTCH"] == 2 and phone.powers["PERFECT"] == 25)
	_expect("the longer run wins", is_equal_approx(phone.survival_best_time, 400.0))
	_expect("the better survival score wins", phone.survival_best_score == 9000)
	# The one that would double-count if the totals were summed rather than maxed.
	_expect("nothing is counted twice", phone.matches == 40 and phone.wins == 30)
	_expect("and it does not matter which device merged",
		phone.matches == mirror.matches and phone.wins == mirror.wins
		and phone.longest_word == mirror.longest_word
		and phone.xp_total() == mirror.xp_total())

	for p in [phone, tablet, mirror, other]:
		p.free()


## The property the whole design rests on, stated as a property: after a merge,
## every number a player can see is at least what it was before it. Run against
## a spread of pairs rather than one hand-picked case.
func _nothing_a_merge_does_moves_a_number_down() -> void:
	print("--- a merge never moves a number down ---")
	var watched := ["matches", "wins", "flawless", "words", "chars", "salvos",
		"multi_clears", "best_wpm", "best_chain", "best_combo", "best_score",
		"survival_runs", "survival_best_time", "survival_best_score",
		"daily_best", "daily_best_streak"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260902
	var dropped := ""
	for _i in 40:
		var a := _random(rng)
		var b := _random(rng)
		var before := {}
		for f in watched:
			before[f] = a.get(f)
		var xp: int = a.xp_total()
		var lv: int = a.level()
		var word: int = a.longest_word.length()
		a.merge_from(b)
		for f in watched:
			if float(a.get(f)) < float(before[f]) and dropped == "":
				dropped = f
		if a.xp_total() < xp and dropped == "":
			dropped = "xp_total"
		if a.level() < lv and dropped == "":
			dropped = "level"
		if a.longest_word.length() < word and dropped == "":
			dropped = "longest_word"
		a.free()
		b.free()
	_expect("40 random pairs, nothing lost%s" % ("" if dropped == "" else " (%s)" % dropped),
		dropped == "")


func _purchases_and_days_are_unions() -> void:
	print("--- purchases and days are unions ---")
	var a := _make({
		"matches": 5,
		"daily": {
			"2026-08-30": {"score": 700, "wpm": 50, "words": 15, "chain": 3},
			"2026-08-31": {"score": 400, "wpm": 40, "words": 10, "chain": 2},
		},
	})
	var b := _make({
		"matches": 5,
		"owned": {"premium": true},
		"daily": {
			# The same day played on both devices, better on this one. Possible
			# whenever one of them was offline at midnight.
			"2026-08-31": {"score": 950, "wpm": 62, "words": 22, "chain": 5},
			"2026-09-01": {"score": 500, "wpm": 44, "words": 12, "chain": 3},
		},
	})
	a.merge_from(b)
	_expect("a purchase on either device is owned on both", a.owns("premium"))
	_expect("days only on one side are kept", a.daily.has("2026-08-30"))
	_expect("days only on the other are taken", a.daily.has("2026-09-01"))
	_expect("a day played twice keeps the better run",
		int((a.daily["2026-08-31"] as Dictionary)["score"]) == 950)

	# Three consecutive days is now provable out of the merged history, and
	# neither device could prove it alone.
	_expect("a streak split across two devices is put back together",
		a.daily_best_streak >= 3)

	# And the history cannot grow without bound, or a sync becomes a way to turn
	# the profile into a log file.
	var big := _make({"matches": 1})
	var older := _make({"matches": 1})
	for i in 90:
		big.daily["2026-%02d-%02d" % [1 + i / 28, 1 + i % 28]] = {"score": i}
	for i in 90:
		older.daily["2025-%02d-%02d" % [1 + i / 28, 1 + i % 28]] = {"score": i}
	big.merge_from(older)
	_expect("and the merged history is still trimmed to %d days" % big.DAILY_KEPT,
		big.daily.size() <= big.DAILY_KEPT)

	a.free()
	b.free()
	big.free()
	older.free()


## The ad cadence is not a record and is deliberately left out of the merge. If
## it were maxed, a sync could bring somebody's next ad break forward — which is
## the one thing in this file a player would notice and resent.
func _the_ad_cadence_is_left_alone() -> void:
	print("--- a sync cannot bring an ad break forward ---")
	var here := _make({"matches": 10})
	here.since_ad = 0
	here.play_since_ad = 0.0
	var there := _make({"matches": 10})
	there.since_ad = 9
	there.play_since_ad = 6000.0
	here.merge_from(there)
	_expect("the match counter is untouched", here.since_ad == 0)
	_expect("the clock is untouched", is_equal_approx(here.play_since_ad, 0.0))
	_expect("so no break is suddenly due", not here.ad_due())
	here.free()
	there.free()


## `merge_from` answering "did anything change" is what decides whether an upload
## happens at all, so a wrong answer is either a write per launch forever or a
## profile that never reaches the cloud.
func _a_merge_says_whether_it_gained() -> void:
	print("--- a merge reports honestly whether it gained ---")
	var a := _make({"matches": 10, "wins": 4, "longest_word": "WORD"})
	var same := _make({"matches": 10, "wins": 4, "longest_word": "WORD"})
	_expect("two identical profiles gain nothing", not a.merge_from(same))
	var ahead := _make({"matches": 11, "wins": 4, "longest_word": "WORD"})
	_expect("one match ahead is a gain", a.merge_from(ahead))
	_expect("and it is not a gain the second time", not a.merge_from(ahead))
	a.free()
	same.free()
	ahead.free()


## Rule one, checked as state rather than as behaviour: nothing on a desktop can
## make the plugin calls, but the guard that stops a blank upload is ours and is
## checkable. `_pulled` starting false is the whole of it.
func _the_upload_refuses_until_it_has_downloaded() -> void:
	print("--- nothing uploads before it has downloaded ---")
	var c: Node = load(CLOUD).new()
	_expect("a fresh session has not read the cloud", not c._pulled)
	_expect("and is switched off away from Apple", not c.available())
	# `push` is guarded four ways over; the one that matters here has to be the
	# `_pulled` flag rather than the platform, or a future Apple-only bug would
	# be one `available()` away from erasing records.
	var src := FileAccess.get_file_as_string(CLOUD)
	_expect("push refuses on read_failed or an unpulled session",
		src.contains("if Profile.read_failed or not _pulled:"))
	_expect("and a sign-out makes the session unpulled again",
		src.contains("_pulled = false"))
	c.free()


## Everything is gated on one `_busy` flag that a callback clears, so a callback
## that never arrives would switch syncing off for the whole session rather than
## fail one attempt. The watchdog is the answer, and what it must *not* do is
## forget that the cloud has been read.
func _a_sync_that_never_answers_gives_up() -> void:
	print("--- a call that never comes back does not kill the session ---")
	var c: Node = load(CLOUD).new()
	c._pulled = true
	c._busy = true
	c._loading = 2
	c._gained = true
	c._process(c.GIVE_UP + 1.0)
	_expect("the flag is released", not c._busy)
	_expect("and the session is free to try again", c._loading == 0)
	# The one thing giving up must not do. `_pulled` false is what lets a blank
	# profile be uploaded over a full one, and a timeout says nothing at all
	# about whether the cloud is empty.
	_expect("but it still knows it has read the cloud", c._pulled)
	_expect("and it says so on the row", c.state == c.State.FAILED)

	# And it does not fire early — eight seconds of a slow connection is a slow
	# connection, not a failure.
	var d: Node = load(CLOUD).new()
	d._busy = true
	d._process(8.0)
	_expect("a slow answer is still waited for", d._busy)
	c.free()
	d.free()


## A download that finds nothing new must not clear the "there is something to
## upload" flag, or a cosmetic changed just before a sync is never sent.
func _a_download_does_not_swallow_a_pending_upload() -> void:
	print("--- a download does not swallow a pending upload ---")
	var c: Node = load(CLOUD).new()
	c._dirty = true
	c._settled(false)
	_expect("a pull leaves the pending change pending", c._dirty)
	c._settled(true)
	_expect("and an upload clears it", not c._dirty)
	_expect("both record when it happened", c.last_sync > 0)
	c.free()


## The bug that shipped in 0.42.0, pinned.
##
## `fetch_saved_games` hands back reference-counted `GKSavedGame` objects and
## `load_data` on them is asynchronous. Starting the loads and then letting the
## array go out of scope frees them mid-flight, the completion handlers never
## arrive, and the restore hangs until the watchdog kills it — silently, and only
## on installs where there was something to restore, which is why it survived
## testing on the install that had nothing.
##
## Exercised with stand-ins rather than the real class, which cannot be built off
## a device. What is being checked is ours: that the array is still referenced
## after `_absorb` returns, and released once the loads are done.
func _a_download_holds_on_to_what_it_is_downloading() -> void:
	print("--- a download keeps hold of what it is downloading ---")
	var c: Node = load(CLOUD).new()
	var saves := [_FakeSave.new(), _FakeSave.new()]
	c._absorb(saves)
	_expect("both loads were started",
		saves[0].asked and saves[1].asked)
	_expect("and it is still waiting for two", c._loading == 2)
	# The whole of it: if this array were dropped here, the only remaining
	# references on a device would be Apple's, and there are none.
	_expect("the saves are still referenced after the call returns",
		c._fetched.size() == 2)

	# And they are let go once there is nothing left to wait for, rather than
	# held for the life of the session.
	c._on_loaded(PackedByteArray(), null)
	_expect("still held while one load is outstanding", c._fetched.size() == 2)
	c._on_loaded(PackedByteArray(), null)
	_expect("released once every load is in", c._fetched.is_empty())
	_expect("and the session counts as having read the cloud", c._pulled)
	c.free()


## The second half of what went wrong: the row said "saved to your Apple ID at
## 00:58" after a round trip that moved nothing. A backup that reports success it
## has not verified is worse than no backup, because it is the reason somebody
## stops making their own.
func _it_only_claims_a_backup_it_has_confirmed() -> void:
	print("--- it only claims a backup it has confirmed ---")
	var c: Node = load(CLOUD).new()
	_expect("a session with nothing confirmed claims nothing", c.last_sync == 0)
	_expect("and does not read as success", not c.note().contains("backed up"))

	# Apple accepting the write is not the claim. Being able to see it afterwards
	# is — so an upload that verifies to an empty account is a failure, not a
	# "saved at 00:58".
	c._on_verified([], null)
	_expect("an upload that vanishes is a failure", c.state == c.State.FAILED)
	_expect("with nothing claimed", c.last_sync == 0)
	_expect("and it says so plainly", c.note().contains("not keeping"))

	c._on_verified([_FakeSave.new()], null)
	_expect("an upload Apple can see is a backup", c.state == c.State.READY)
	_expect("and now there is a time to show", c.last_sync > 0)
	_expect("and it says what it did", c.note().contains("backed up"))

	# A restore says so instead, because that is the thing the player on a new
	# phone is actually waiting to be told.
	c.restored = true
	_expect("a restore is reported as a restore", c.note().contains("restored"))
	c.free()


## Stands in for a `GKSavedGame`, which cannot be constructed off an Apple
## device. Only the two things `_absorb` touches: it can be asked for its data,
## and it notices being asked.
class _FakeSave extends RefCounted:
	var asked := false

	func load_data(_done: Callable) -> void:
		asked = true


# ---------------------------------------------------------------------- helpers

## A detached profile with the given fields set. Never added to the tree, so it
## never runs `_ready`, never reads the real save and never writes one — the same
## trick `cloud.gd` uses to parse a download.
func _make(fields: Dictionary) -> Node:
	var p: Node = load(PROFILE).new()
	for f: String in fields:
		p.set(f, fields[f])
	return p


func _random(rng: RandomNumberGenerator) -> Node:
	var words := ["", "CAT", "PLANET", "ALIGNMENT", "PERPENDICULAR"]
	return _make({
		"matches": rng.randi_range(0, 200),
		"wins": rng.randi_range(0, 100),
		"flawless": rng.randi_range(0, 20),
		"words": rng.randi_range(0, 5000),
		"chars": rng.randi_range(0, 30000),
		"salvos": rng.randi_range(0, 60),
		"multi_clears": rng.randi_range(0, 200),
		"best_wpm": rng.randf_range(0.0, 90.0),
		"best_chain": rng.randi_range(0, 12),
		"best_combo": rng.randi_range(0, 6),
		"best_score": rng.randi_range(0, 20000),
		"longest_word": words[rng.randi_range(0, words.size() - 1)],
		"powers": {"COUNTER": rng.randi_range(0, 40), "CLUTCH": rng.randi_range(0, 20)},
		"survival_runs": rng.randi_range(0, 30),
		"survival_best_time": rng.randf_range(0.0, 900.0),
		"survival_best_score": rng.randi_range(0, 9000),
		"daily_best": rng.randi_range(0, 2000),
		"daily_best_streak": rng.randi_range(0, 40),
	})


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-52s %s" % [what, "ok" if ok else "FAILED"])
