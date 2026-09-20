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
	_buying_grants_the_pack()
	_it_survives_a_save()
	_ads_stop()
	_the_gap_moves()
	_the_test_grant_is_taken_back()
	_free_themes_are_untouched()
	_premium_theme_actually_differs()
	_the_painted_boards_are_painted()
	_the_faces_match_the_boards()
	_the_pitch_is_owed_once()
	_the_badges_answer_to_different_things()
	_the_menu_knows_every_block_style()

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

	for pair in _paid():
		_expect("%s/%s stays locked at level %d" % [pair[0], pair[1], P.level()],
			not P.is_unlocked(String(pair[0]), String(pair[1])))

	# And the rest of the catalogue is genuinely reachable, or the check above
	# would pass just as well if everything were locked.
	_expect("an earned title does unlock with a record like that",
		P.is_unlocked("title", "centurion"))


## Everything in the catalogue that costs money, read off the catalogue rather
## than listed here.
##
## It used to be three entries written out by hand, which was fine while it was
## three. The painted boards took it to nineteen, and a hand-written list that
## long is one somebody will forget to extend — at which point the test for
## "no amount of playing earns it" quietly stops covering the thing that was
## just added, and still passes.
func _paid() -> Array:
	var out: Array = []
	for slot: String in P.SLOTS:
		for e: Dictionary in P.entries(slot):
			var need: Dictionary = e.get("need", {})
			if need.has("buy"):
				out.append([slot, String(e["id"])])
	return out


func _buying_grants_the_pack() -> void:
	print("--- buying grants exactly what it says ---")
	var paid := _paid()
	# Nineteen: the title, the Prism board, the Supernova win, eight painted
	# boards and the eight block faces drawn for them. Written down so that
	# adding a paid entry without meaning to has to argue with this number.
	_expect("the pack is nineteen entries", paid.size() == 19)

	var before: Dictionary = P.unlocked_set()
	P.grant(P.PACK_PREMIUM)
	for pair in paid:
		_expect("%s/%s unlocks" % [pair[0], pair[1]],
			P.is_unlocked(String(pair[0]), String(pair[1])))

	# Nothing else may move. A pack that quietly unlocked something it does not
	# advertise would be a bug nobody reports.
	var after: Dictionary = P.unlocked_set()
	var added := 0
	for slot in after:
		for id in after[slot]:
			if not (before[slot] as Array).has(id):
				added += 1
	_expect("and nothing else changed", added == paid.size())

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
	P.ad_gap = 0
	# The clock budget, zeroed too. `ad_due` is an `or` of two budgets — matches
	# played and seconds played — and this block is only asking about the first
	# one, so leaving the second alone does not neutralise it, it lets it answer.
	#
	# The autoload has already loaded the real `profile.cfg` by the time
	# `save_path` is redirected here, so `play_since_ad` arrives holding however
	# long whoever owns this machine has played since their last break. Anything
	# over a rolled five-to-eight minutes makes the very first assertion fail on
	# a developer who plays the game and pass on one who does not — which is
	# exactly the kind of failure that gets blamed on the last thing committed.
	P.play_since_ad = 0.0
	P.ad_gap_seconds = 0.0
	# The gap is rolled, so the test cannot name the match it lands on — only the
	# window it has to land inside. One short of the minimum is never due; the
	# maximum always is.
	for i in P.ADS_EVERY_MIN - 1:
		P.note_match_for_ads()
	_expect("no break before %d matches" % P.ADS_EVERY_MIN, not P.ad_due())
	for i in P.ADS_EVERY_MAX - (P.ADS_EVERY_MIN - 1):
		P.note_match_for_ads()
	_expect("one is due by %d" % P.ADS_EVERY_MAX, P.ad_due())
	P.clear_ad()
	_expect("and not straight after one", not P.ad_due())

	P.grant(P.PACK_PREMIUM)
	for i in P.ADS_EVERY_MAX * 3:
		P.note_match_for_ads()
	_expect("an owner never has one due", not P.ad_due())


## The gap has to actually vary, and has to stay inside its own bounds. A roll
## that always returned three would pass every check above while being the fixed
## cadence this replaced — so the spread is asserted rather than assumed.
func _the_gap_moves() -> void:
	print("--- the gap is 3 to 5 and not a metronome ---")
	P.owned = {}
	var seen: Dictionary = {}
	var in_range := true
	for i in 400:
		P.roll_ad_gap()
		in_range = in_range and P.ad_gap >= P.ADS_EVERY_MIN and P.ad_gap <= P.ADS_EVERY_MAX
		seen[P.ad_gap] = true
	_expect("every roll lands in range", in_range)
	_expect("and all three lengths come up",
		seen.size() == P.ADS_EVERY_MAX - P.ADS_EVERY_MIN + 1)

	# And it survives the save, or a restart is a way to roll again for a longer
	# one — the same hole as counting matches anywhere but here.
	P.ad_gap = P.ADS_EVERY_MAX
	P.since_ad = 1
	P.save()
	P.ad_gap = 0
	_expect("the file reads the gap back",
		P._read(P.save_path) == OK and P.ad_gap == P.ADS_EVERY_MAX)


## A pack handed out by the old test button has to be taken back on load.
##
## This is the bug that found itself: the button sat two taps from the volume
## sliders, one of the three things it granted was silence from the ad break,
## and a tap made and forgotten presented weeks later as ads that simply never
## appeared — with nothing on any screen to say why. The button is gone, which
## fixes it for new saves and does nothing at all for the ones already carrying
## a grant. So the migration is the fix, and this is the check on it.
func _the_test_grant_is_taken_back() -> void:
	print("--- an old test grant does not survive the update ---")
	var path := "user://profile-migrate-test.cfg"
	var cfg := ConfigFile.new()
	# A schema-1 file, written the way the old build wrote one: pack owned, and
	# one of its cosmetics worn.
	cfg.set_value("meta", "schema", 1)
	# Past 100, so Centurion is genuinely earned — otherwise the check below
	# passes for the wrong reason, the title being stripped as unearned rather
	# than kept as not the pack's to take.
	cfg.set_value("record", "matches", 140)
	cfg.set_value("shop", "owned", {P.PACK_PREMIUM: true})
	cfg.set_value("shop", "since_ad", 9)
	cfg.set_value("worn", "equipped", {"theme": "prism", "title": "centurion"})
	cfg.save(ProjectSettings.globalize_path(path))

	P.owned = {}
	P.equipped = {}
	_expect("the old file reads", P._read(path) == OK)
	_expect("the pack is gone", not P.owns(P.PACK_PREMIUM))
	_expect("so ads are back on", not P.ads_removed())
	_expect("and a break is due, having played 9", P.ad_due())
	_expect("the premium theme came off with it", P.worn("theme") != "prism")
	# Only what the pack paid for. An earned title is not the pack's to take.
	_expect("but an earned title stayed on", P.worn("title") == "centurion")
	_expect("and the record is untouched", P.matches == 140)

	# A real purchase, once there is one, must not be caught by this. Saves
	# written from here on carry the current schema and are left alone.
	P.owned = {}
	P.save_path = path
	P.grant(P.PACK_PREMIUM)
	P.owned = {}
	_expect("a grant written at the current schema survives a reload",
		P._read(path) == OK and P.owns(P.PACK_PREMIUM))

	P.save_path = "user://profile-shop-test.cfg"
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


## Widening what a theme may set must not change what the existing ones do.
##
## Every new property defaults to whatever was hardcoded before it existed, so
## the five free themes have to resolve to exactly those defaults. If one of
## them starts picking up premium paint, the paid theme stops being worth
## paying for and nobody would necessarily notice.
func _free_themes_are_untouched() -> void:
	print("--- the free themes are unchanged ---")
	for id in ["midnight", "ember", "chlorophyll", "vapor", "bone"]:
		var ok := true
		ok = ok and Cosmetics.theme_opt(id, "frame") == ""
		ok = ok and is_equal_approx(float(Cosmetics.theme_opt(id, "panel_a")), 1.0)
		ok = ok and is_equal_approx(float(Cosmetics.theme_opt(id, "glow_a")), 0.0)
		ok = ok and not bool(Cosmetics.theme_opt(id, "nodes"))
		ok = ok and String(Cosmetics.theme_opt(id, "key_bg")) == "#141b33"
		# And they stayed free of the painted boards' keys too. A free theme
		# that picked up a backdrop would be the pack's headline feature given
		# away, and it would happen by somebody pasting a row.
		ok = ok and String(Cosmetics.theme_opt(id, "art")) == ""
		ok = ok and String(Cosmetics.theme_opt(id, "motion")) == ""
		ok = ok and is_equal_approx(float(Cosmetics.theme_opt(id, "frame_pulse")), 0.0)
		_expect("%s still uses the stock paint" % id, ok)


## And the paid one has to differ in more than hue, which is the whole
## complaint that prompted this: two themes built from a backdrop wash and a
## ruling can only ever be the same board in a different colour.
func _premium_theme_actually_differs() -> void:
	print("--- prism is more than a colour filter ---")
	var free_paint := {
		"key_bg": Cosmetics.theme_opt("chlorophyll", "key_bg"),
		"panel_a": float(Cosmetics.theme_opt("chlorophyll", "panel_a")),
		"glow_a": float(Cosmetics.theme_opt("chlorophyll", "glow_a")),
		"nodes": bool(Cosmetics.theme_opt("chlorophyll", "nodes")),
		"frame": Cosmetics.theme_opt("chlorophyll", "frame"),
	}
	_expect("it repaints the keyboard",
		Cosmetics.theme_opt("prism", "key_bg") != free_paint["key_bg"])
	_expect("its playfield is translucent",
		float(Cosmetics.theme_opt("prism", "panel_a")) < free_paint["panel_a"])
	_expect("it lights the backdrop",
		float(Cosmetics.theme_opt("prism", "glow_a")) > free_paint["glow_a"])
	_expect("its grid has nodes", bool(Cosmetics.theme_opt("prism", "nodes")))
	_expect("it owns its frame",
		String(Cosmetics.theme_opt("prism", "frame")) != String(free_paint["frame"]))


## The eight boards that carry a picture have to actually carry one.
##
## A theme naming a file that is not in the export is the failure this is here
## for, and it is a nasty one: `_load_or_null` swallows it by design, so the
## board still equips, still plays, and is silently just its wash — a paid
## board that looks like a free one, reported as "it did nothing". Checked on
## disk rather than by reading the table back at itself.
const PAINTED := ["forest", "volcano", "ocean", "space", "cyber", "clouds",
	"desert", "aurora"]


func _the_painted_boards_are_painted() -> void:
	print("--- the painted boards have their art ---")
	var motions := {}
	for id: String in PAINTED:
		var art := String(Cosmetics.theme_opt(id, "art"))
		_expect("%s names a backdrop" % id, art != "")
		_expect("%s's backdrop is in the project" % id, ResourceLoader.exists(art))

		var motion := String(Cosmetics.theme_opt(id, "motion"))
		_expect("%s has something moving on it" % id, motion != "")
		motions[motion] = true

		# The dim is what keeps the clock legible over a sunlit photograph, and
		# a board that forgot it is a board you cannot read your own score on.
		_expect("%s dims for the HUD" % id,
			float(Cosmetics.theme_opt(id, "art_dim")) > 0.0)
		# Translucent, or the picture is behind an opaque slab and there was no
		# point buying it.
		_expect("%s lets the picture through the playfield" % id,
			float(Cosmetics.theme_opt(id, "panel_a")) < 0.7)

	# Eight boards, eight different effects. Two boards sharing one is the
	# shortcut that turns a set into a palette swap with extra steps.
	_expect("no two boards share an effect", motions.size() == PAINTED.size())

	# And every effect a board names is one `draw_motion` actually dispatches.
	# Its `match` has no fallback on purpose — an unrecognised kind draws
	# nothing and says nothing, which is the same silent downgrade as a missing
	# file, and `MOTIONS` is the list the match is kept in step with.
	for id: String in PAINTED:
		var kind := String(Cosmetics.theme_opt(id, "motion"))
		_expect("%s's '%s' is an effect that exists" % [id, kind],
			Cosmetics.MOTIONS.has(kind))
	# The other direction, which catches an effect that was written, dropped
	# from the theme that wanted it, and left behind costing a file to read.
	for kind: String in Cosmetics.MOTIONS:
		_expect("'%s' is on a board" % kind, motions.has(kind))


## Each painted board was drawn with a block face to match, and the mastery
## screen says which. Nothing enforces the pairing at runtime — the slot is
## independent and stays that way — so the only thing that can go wrong is the
## table lying: a style pointing at a board that does not exist, or a board
## whose face was never added. Both print a wrong sentence under the preview
## and neither would crash.
func _the_faces_match_the_boards() -> void:
	print("--- every painted board has a face drawn for it ---")
	var claimed := {}
	for style in Cosmetics.BLOCK_PAIRING:
		var sid := String(style)
		var board := String(Cosmetics.BLOCK_PAIRING[style])
		_expect("%s is a style the game can draw" % sid,
			Cosmetics.BLOCK_STYLES.has(sid))
		_expect("%s is sold" % sid,
			P.entry("blocks", sid).get("need", {}).has("buy"))
		_expect("%s points at the %s board" % [sid, board], PAINTED.has(board))
		claimed[board] = true
	_expect("all eight boards are spoken for", claimed.size() == PAINTED.size())
	_expect("and there are exactly eight faces",
		Cosmetics.BLOCK_PAIRING.size() == PAINTED.size())


## The slideshow is shown once per content drop and never again.
##
## Both halves of that matter and they fail in opposite directions. Never
## showing it means eight boards were built and nobody was told. Showing it
## every launch is the thing that turns a pack somebody was going to buy into a
## reason to delete the game — and it is the easy failure to write, because
## "has seen it" is one forgotten `set_pref` away from being permanently false.
func _the_pitch_is_owed_once() -> void:
	print("--- the pitch is owed once per drop ---")
	P.owned = {}
	P.prefs["promo_seen"] = 0
	_expect("a player who has not seen it is owed it", P.owes_promo())

	P.note_promo_seen()
	_expect("and is not owed it twice", not P.owes_promo())
	_expect("seeing it records the current drop",
		int(P.pref("promo_seen")) == P.PROMO_DROP)

	# Marking it again is not an error and does not move anything.
	P.note_promo_seen()
	_expect("marking it again is harmless",
		int(P.pref("promo_seen")) == P.PROMO_DROP)

	# The next batch of boards. Standing in for a `PROMO_DROP` bump by putting
	# the save one behind, which is exactly what an upgrading player looks like.
	P.prefs["promo_seen"] = P.PROMO_DROP - 1
	_expect("a new drop is owed again", P.owes_promo())

	# Every save written before any of this existed has no key at all, and must
	# read as owed rather than as seen.
	P.prefs.erase("promo_seen")
	_expect("a save from before the feature is owed it", P.owes_promo())

	# And the one case where it must never appear.
	P.grant(P.PACK_PREMIUM)
	_expect("somebody who already bought it is never pitched to",
		not P.owes_promo())
	P.prefs["promo_seen"] = 0
	_expect("not even with the counter reset", not P.owes_promo())
	P.revoke(P.PACK_PREMIUM)


## The two badges look identical and mean different things, which is the kind of
## pair that quietly becomes one flag during a tidy-up.
func _the_badges_answer_to_different_things() -> void:
	print("--- the two badges are not the same flag ---")
	P.owned = {}
	P.prefs["promo_seen"] = 0
	P.prefs["cosmetics_seen"] = 0
	_expect("the wardrobe is new to a player who has not opened it",
		P.cosmetics_are_new())

	# Seeing the pitch says nothing about having looked at the wardrobe.
	P.note_promo_seen()
	_expect("and still is after the pitch has been seen",
		P.cosmetics_are_new())

	P.note_cosmetics_seen()
	_expect("opening it clears it", not P.cosmetics_are_new())

	# The important half: this badge is not an offer, so owning the pack does
	# not silence it. A buyer is the one person who can actually wear the new
	# faces, and hiding the door from them would be the wrong way round.
	P.prefs["cosmetics_seen"] = 0
	P.grant(P.PACK_PREMIUM)
	_expect("an owner is still told there is something new to wear",
		P.cosmetics_are_new())
	P.revoke(P.PACK_PREMIUM)


## The menu is built out of blocks now, so a block style has to reach it. The
## two renderers are separate on purpose — one is tuned to cell-sized tiles and
## one to a menu gutter — which makes it possible for a style to be added to the
## board and never drawn on the title. This is the check that stops that.
func _the_menu_knows_every_block_style() -> void:
	print("--- the menu can draw every block style ---")
	var catalogue: Array = []
	for e: Dictionary in P.entries("blocks"):
		catalogue.append(String(e["id"]))
	for id: String in catalogue:
		_expect("%s is a style the menu handles" % id,
			Cosmetics.BLOCK_STYLES.has(id))
	_expect("and the menu claims no style the catalogue lacks",
		Cosmetics.BLOCK_STYLES.size() == catalogue.size())


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-52s %s" % [what, "ok" if ok else "FAILED"])
