extends SceneTree
## What a purchase is worth, and what it must never be worth by accident.
##
## Two failures matter here and they fail in opposite directions. Handing a
## premium cosmetic to somebody who did not buy it costs the sale quietly; the
## XP formula gets re-tuned regularly, and every other unlock in the game is a
## pure function of the record, so a premium entry that answered to the record
## would be one balance pass away from being free.
##
## Not handing it over after a purchase is worse. So the round trip is checked
## through the save file, which is where a granted pack has to survive.
##
##   godot --headless --script tools/shoptest.gd

var fails := 0
var P: Node


func _init() -> void:
	await process_frame
	P = get_root().get_node("Profile")
	P.save_path = "user://profile-shop-test.cfg"
	P.owned = {}
	P.equipped = {}
	P.since_ad = 0

	_premium_is_unreachable_by_playing()
	_buying_grants_all_three()
	_it_survives_a_save()
	_ads_stop()

	print("--- %s ---" % ("shop behaves" if fails == 0 else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)


## The premium entries are the only ones in the catalogue that no amount of play
## can reach. Proved by giving the profile a career and checking they are still
## locked, rather than by reading the table.
func _premium_is_unreachable_by_playing() -> void:
	print("--- no amount of playing earns it ---")
	P.owned = {}
	P.matches = 100000
	P.wins = 100000
	P.flawless = 9999
	P.words = 9999999
	P.salvos = 99999
	P.multi_clears = 99999
	P.best_wpm = 999.0
	P.best_chain = 999
	P.best_combo = 999
	P.longest_word = "antidisestablishmentarianism"
	P.powers = {"COUNTER": 99999, "COMBO": 99999, "PERFECT": 99999, "CLUTCH": 99999}

	for pair in [["title", "founder"], ["theme", "prism"], ["victory", "supernova"]]:
		_expect("%s/%s stays locked at level %d" % [pair[0], pair[1], P.level()],
			not P.is_unlocked(String(pair[0]), String(pair[1])))

	# And the rest of the catalogue is genuinely reachable, or the check above
	# would pass just as well if everything were locked.
	_expect("an earned title does unlock with a record like that",
		P.is_unlocked("title", "centurion"))


func _buying_grants_all_three() -> void:
	print("--- buying grants exactly the three ---")
	var before: Dictionary = P.unlocked_set()
	P.grant(P.PACK_PREMIUM)
	for pair in [["title", "founder"], ["theme", "prism"], ["victory", "supernova"]]:
		_expect("%s/%s unlocks" % [pair[0], pair[1]],
			P.is_unlocked(String(pair[0]), String(pair[1])))

	# Nothing else may move. A pack that quietly unlocked a fourth thing would
	# be a bug nobody reports.
	var after: Dictionary = P.unlocked_set()
	var added := 0
	for slot in after:
		for id in after[slot]:
			if not (before[slot] as Array).has(id):
				added += 1
	_expect("and nothing else changed", added == 3)

	# Buying twice is not an error and does not stack.
	P.grant(P.PACK_PREMIUM)
	_expect("buying again is harmless", P.owns(P.PACK_PREMIUM))


func _it_survives_a_save() -> void:
	print("--- it survives a restart ---")
	P.equipped = {"title": "founder", "theme": "prism", "victory": "supernova"}
	P.save()
	P.owned = {}
	P.equipped = {}
	_expect("the file reads back as owned", P._read(P.save_path) == OK and P.owns(P.PACK_PREMIUM))
	_expect("and what was worn is still worn", P.worn("theme") == "prism")

	# Handing it back has to take the cosmetics off with it, or a revoked
	# purchase stays on screen.
	P.revoke(P.PACK_PREMIUM)
	_expect("revoking locks it again", not P.is_unlocked("theme", "prism"))
	_expect("and stops it being worn", P.worn("theme") != "prism")


func _ads_stop() -> void:
	print("--- the pack stops the ads ---")
	P.owned = {}
	P.since_ad = 0
	for i in P.ADS_EVERY:
		P.note_match_for_ads()
	_expect("a break is due after %d matches" % P.ADS_EVERY, P.ad_due())
	P.clear_ad()
	_expect("and not straight after one", not P.ad_due())

	P.grant(P.PACK_PREMIUM)
	for i in P.ADS_EVERY * 3:
		P.note_match_for_ads()
	_expect("an owner never has one due", not P.ad_due())


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-52s %s" % [what, "ok" if ok else "FAILED"])
