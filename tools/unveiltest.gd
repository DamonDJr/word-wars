extends SceneTree
## Unlocking a board, and owning the pack, as events rather than as small print.
##
## Two halves. The Subway's lock — three versus matches against real people —
## has to count the right matches, survive a save and a cloud merge, and refuse
## any amount of play against the CPU. And the unveiling has to happen for the
## right things, on the right screens, and own the screen while it is up
## without ever being able to strand somebody behind it.
##
## What it looks like is `tools/unveilshots.gd`; this is what it does.
##
##   godot --headless --script tools/unveiltest.gd

var game: Node
var stage: SubViewport
var P: Node
var fails := 0


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-62s %s" % [what, "ok" if ok else "FAILED"])


func _init() -> void:
	await process_frame
	P = get_root().get_node("Profile")
	# First, before anything can save: the pack's unveiling marks itself seen,
	# and a test that did that to the real profile would spend it on nobody.
	P.save_path = "user://profile-unveil-test.cfg"
	_blank()

	stage = SubViewport.new()
	stage.size = Vector2i(720, 1440)
	get_root().add_child(stage)
	game = load("res://scenes/main.tscn").instantiate()
	stage.add_child(game)
	await process_frame
	await process_frame
	if get_root().size_changed.is_connected(game._apply_orientation):
		get_root().size_changed.disconnect(game._apply_orientation)
	# The stage is a phone; the window running this is not. Pinned, or the
	# layout is whichever one the desktop window happened to suggest.
	game.portrait = true
	game._skip_splash()
	for i in 60:
		await process_frame
	game.phase = game.Phase.TITLE

	_the_subway_asks_for_three_people()
	_the_count_survives_a_save_and_a_merge()
	_a_versus_match_is_counted_as_one()
	await _a_harness_is_left_alone()
	game.reveal_demo = true
	_an_earned_board_is_unveiled()
	_a_palette_or_a_bought_board_is_not()
	_the_pack_is_owed_to_everybody_who_owns_it()
	_it_waits_for_a_screen_it_can_stand_on()
	await _it_owns_the_screen_until_answered()
	await _use_it_now_wears_it()
	await _the_pack_goes_to_the_wardrobe()
	await _not_from_a_summary()
	_the_hand_fits_on_the_screen()
	_the_share_card_waits_its_turn()
	_the_lobby_names_the_goal()

	for f in ["user://profile-unveil-test.cfg", "user://profile-unveil-test.cfg.bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	print("--- %s ---" % ("unlocks are events" if fails == 0
		else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)


## A new player, owning nothing, who has seen no unveilings and no pitches.
func _blank() -> void:
	P.owned = {}
	P.equipped = {}
	P.matches = 0
	P.wins = 0
	P.versus_matches = 0
	P.words = 0
	P.share_days = []
	P.prefs = {"taught": true, "tutorial_offered": true, "promo_seen": 99,
		"share_promo_seen": 99, "share_promo_day": "2999-01-01"}


func _reset_reveals() -> void:
	game._reveals = []
	game._reveal_reset()
	game.phase = game.Phase.TITLE


func _the_subway_asks_for_three_people() -> void:
	print("--- the subway is three matches against people ---")
	_blank()
	_expect("locked on a new profile", not P.is_unlocked("theme", "subway"))
	var st: Dictionary = P.standing(P.entry("theme", "subway")["need"])
	_expect("and says what it wants (%s)" % st["what"],
		String(st["what"]) == "play 3 versus matches" and int(st["want"]) == 3)

	# Any amount of CPU play. The lock is on who you played, not how much.
	for i in 40:
		P.record_match({"won": true, "words": 30})
	_expect("forty CPU matches do not open it", not P.is_unlocked("theme", "subway"))
	_expect("and did not count as versus", P.versus_matches == 0)

	P.record_match({"versus": true})
	P.record_match({"versus": true, "won": true})
	_expect("two versus matches do not", not P.is_unlocked("theme", "subway"))
	P.record_match({"versus": true})
	_expect("the third does, win or lose", P.is_unlocked("theme", "subway"))
	_expect("and it can be worn", P.equip("theme", "subway"))
	_blank()


func _the_count_survives_a_save_and_a_merge() -> void:
	print("--- the count is part of the record ---")
	_blank()
	P.versus_matches = 2
	var copy: Node = load("res://scripts/profile.gd").new()
	_expect("it round-trips through the save", copy.from_bytes(P.to_bytes())
		and copy.versus_matches == 2)
	# The other device has played more of them.
	copy.versus_matches = 3
	_expect("a merge takes the larger count", P.merge_from(copy)
		and P.versus_matches == 3)
	copy.versus_matches = 1
	P.merge_from(copy)
	_expect("and never moves it down", P.versus_matches == 3)
	copy.free()
	_blank()


## Through the real end-of-match path, so the flag that decides it is the one
## the game actually sets.
func _a_versus_match_is_counted_as_one() -> void:
	print("--- the end of a match knows who it was against ---")
	_blank()
	_reset_reveals()
	game.mode = game.Mode.NORMAL
	game.winner = ""
	game.difficulty = "Duelist"
	game._record_mastery()
	_expect("a CPU match is not a versus match", P.versus_matches == 0)
	game.difficulty = "Versus"
	game._record_mastery()
	game._record_mastery()
	_expect("a versus match is, lost or not", P.versus_matches == 2)
	_expect("nothing to unveil yet", game._reveals.is_empty())
	game._record_mastery()
	_expect("the third queues the Subway's unveiling",
		game._reveals.size() == 1 and String(game._reveals[0]["id"]) == "subway")
	game.phase = game.Phase.TITLE
	_reset_reveals()
	_blank()


## Every harness in `tools/` builds this scene by hand, most of them on the
## real profile. The pack's unveiling marks itself seen as it starts, so one
## firing in a test would be spent on nobody.
func _a_harness_is_left_alone() -> void:
	print("--- a harness does not get one ---")
	_blank()
	_reset_reveals()
	P.owned = {P.PACK_PREMIUM: true}
	for i in 4:
		await process_frame
	_expect("nothing queued for a scene nobody is running", game._reveals.is_empty())
	_expect("and the pack's is still owed", P.owes_premium_reveal())
	_blank()


func _an_earned_board_is_unveiled() -> void:
	print("--- a board earned is unveiled ---")
	_blank()
	_reset_reveals()
	P.versus_matches = 2
	var before: Dictionary = P.unlocked_set()
	P.versus_matches = 3
	P.matches = 3
	game._queue_reveals(before)
	_expect("one unveiling", game._reveals.size() == 1)
	var r: Dictionary = game._reveals[0] if not game._reveals.is_empty() else {}
	_expect("of the subway", String(r.get("id", "")) == "subway")
	_expect("saying what earned it (%s)" % r.get("how", ""),
		String(r.get("how", "")).contains("3 versus matches"))
	_expect("and naming what came with it (%s)" % str(r.get("also", [])),
		(r.get("also", []) as Array).has("Rookie title"))

	# The share ladder's board, through the same door.
	_reset_reveals()
	before = P.unlocked_set()
	for i in 8:
		P.share_days.append("2026-09-%02d" % (i + 1))
	game._queue_reveals(before)
	_expect("the Nexus gets one too", game._reveals.size() == 1
		and String(game._reveals[0]["id"]) == "nexus")
	_expect("with its block face named alongside",
		(game._reveals[0]["also"] as Array).has("Runestone blocks"))
	_reset_reveals()
	_blank()


func _a_palette_or_a_bought_board_is_not() -> void:
	print("--- a palette, and the pack's boards, are not ---")
	_blank()
	_reset_reveals()
	var before: Dictionary = P.unlocked_set()
	# Level three: Ember, a recoloured wash.
	P.matches = 40
	P.words = 3000
	P.wins = 20
	var gained: bool = P.is_unlocked("theme", "ember")
	game._queue_reveals(before)
	_expect("ember is earned (level %d)" % P.level(), gained)
	_expect("and gets the summary's line rather than a ceremony",
		game._reveals.is_empty())

	before = P.unlocked_set()
	P.owned = {P.PACK_PREMIUM: true}
	game._queue_reveals(before)
	_expect("the pack's boards are not unveiled one by one",
		not game._reveal_queued("board"))
	_reset_reveals()
	_blank()


func _the_pack_is_owed_to_everybody_who_owns_it() -> void:
	print("--- the pack's unveiling is owed to its owners ---")
	_blank()
	_expect("not to somebody who has not bought it", not P.owes_premium_reveal())
	# An owner from before this existed: owns it, has never been shown it.
	P.owned = {P.PACK_PREMIUM: true}
	_expect("to somebody who bought it before it existed", P.owes_premium_reveal())
	P.note_premium_reveal()
	_expect("once", not P.owes_premium_reveal())
	_expect("keyed to the drop, so a bigger pack is owed again",
		int(P.pref("premium_reveal")) == P.PROMO_DROP)
	_blank()


func _it_waits_for_a_screen_it_can_stand_on() -> void:
	print("--- it waits for a screen it can stand on ---")
	_blank()
	_reset_reveals()
	game._reveals = [{"kind": "board", "id": "subway", "how": "", "also": []}]
	for pair in [["PLAY", false], ["COUNTDOWN", false], ["LOBBY", false],
			["SPLASH", false], ["TITLE", true], ["COSMETICS", true],
			["SETTINGS", true], ["MASTERY", true]]:
		game.phase = game.Phase[String(pair[0])]
		_expect("%s: %s" % [pair[0], "shown" if pair[1] else "held"],
			game._reveal_up() == bool(pair[1]))
	game.phase = game.Phase.OVER
	game.over_age = 0.5
	_expect("a summary that has only just appeared: held", not game._reveal_up())
	game.over_age = game.REVEAL_OVER_WAIT + 0.1
	_expect("once it has been read: shown", game._reveal_up())
	game._curtain = game.Curtain.HOLDING
	_expect("never under an ad break", not game._reveal_up())
	game._curtain = game.Curtain.NONE

	# Walked away from halfway through: it starts over rather than resuming.
	game._reveal_t = 1.8
	game.phase = game.Phase.COUNTDOWN
	game._tick_reveal(0.016)
	_expect("left mid-way, it goes back to the start", game._reveal_t == 0.0
		and game._reveals.size() == 1)
	_reset_reveals()


func _it_owns_the_screen_until_answered() -> void:
	print("--- it owns the screen until it is answered ---")
	_blank()
	_reset_reveals()
	P.versus_matches = 3
	game._reveals = [{"kind": "board", "id": "subway", "how": "", "also": []}]
	# A real plate on the title screen, found with the unveiling out of the way.
	var plates: Array = game._menu_buttons()
	var plate: Vector2 = (plates[0]["rect"] as Rect2).get_center() \
		if not plates.is_empty() else Vector2(360, 700)
	var plate_action: String = String(plates[0]["action"]) if not plates.is_empty() else ""
	await process_frame
	_expect("it has started", game._reveal_t > 0.0)
	_expect("a tap on the title's %s plate reaches nothing" % plate_action,
		plate_action != "" and game._action_at(plate) == "")
	_expect("no buttons while it is arriving", game._reveal_buttons().is_empty())

	game._reveal_t = 1.0
	game._reveal_heard = {"rumble": true, "seam": true}
	game._reveal_skip()
	_expect("a skip lands on the settled screen", game._reveal_settled())
	var all_heard := true
	for beat: Array in game._reveal_beats():
		all_heard = all_heard and game._reveal_heard.has(String(beat[1]))
	_expect("with every beat it jumped marked as heard", all_heard)

	var bs: Array = game._reveal_buttons()
	_expect("two buttons once settled", bs.size() == 2)
	if bs.size() == 2:
		_expect("the first wears it", String(bs[0]["action"]) == "reveal_use")
		_expect("the second leaves it", String(bs[1]["action"]) == "reveal_close")
	for tall in [true, false]:
		game.portrait = tall
		stage.size = Vector2i(720, 1440) if tall else Vector2i(1280, 720)
		game._reveal_t = game._reveal_settle_at() + 1.0
		var view := Rect2(Vector2.ZERO, Vector2(stage.size))
		var inside := true
		for b: Dictionary in game._reveal_buttons():
			inside = inside and view.encloses(b["rect"])
		_expect("the buttons are on the screen (%s)" % ("portrait" if tall
			else "landscape"), inside and not game._reveal_buttons().is_empty())
	game.portrait = true
	stage.size = Vector2i(720, 1440)

	game._activate("reveal_close")
	_expect("Later takes it down", game._reveals.is_empty()
		and not game._reveal_up())
	_expect("and leaves the board where it was", P.worn("theme") != "subway")
	_expect("and the title is live again", game._action_at(plate) == plate_action)
	_reset_reveals()
	_blank()


func _use_it_now_wears_it() -> void:
	print("--- Use it now puts it behind the game ---")
	_blank()
	_reset_reveals()
	P.versus_matches = 3
	game._reveals = [{"kind": "board", "id": "subway", "how": "", "also": []}]
	await process_frame
	game._reveal_skip()
	game._activate("reveal_use")
	_expect("it is worn", P.worn("theme") == "subway")
	_expect("the unveiling is over", game._reveals.is_empty() and game._reveal_t == 0.0)
	_expect("and its scene was handed on rather than dropped",
		game._reveal3d == null and (game._art3d == null
			or String(game._art3d.get_meta("scene")).ends_with("subway.glb")))
	P.equipped = {}
	game._apply_theme()
	_reset_reveals()
	_blank()


func _the_pack_goes_to_the_wardrobe() -> void:
	print("--- the pack's unveiling goes to the boards ---")
	_blank()
	_reset_reveals()
	game._pack_at_boot = true
	P.owned = {P.PACK_PREMIUM: true}
	await process_frame
	await process_frame
	_expect("an owner from before is shown it", game._reveal_queued("premium")
		and game._reveal_up())
	_expect("thanked as one", not bool(game._reveals[0]["fresh"]))
	_expect("and it is marked seen as it starts", not P.owes_premium_reveal())
	var tiles: Array = game._pack_tiles()
	_expect("it deals the pack's eight boards and the ad break (%d)" % tiles.size(),
		tiles.size() == 9 and tiles.has("forest") and tiles.has("aurora")
		and not tiles.has("subway") and not tiles.has("nexus")
		and String(tiles[-1]) == "")
	_expect("and names the rest (%s)" % game._pack_extras(),
		game._pack_extras().contains("8 block faces")
		and game._pack_extras().contains("Founder title"))
	game._reveal_skip()
	var bs: Array = game._reveal_buttons()
	_expect("settled on Pick a board", not bs.is_empty()
		and String(bs[0]["action"]) == "reveal_pick")
	game._activate("reveal_pick")
	_expect("which opens the wardrobe", game.phase == game.Phase.COSMETICS)
	_expect("on the boards", game.mastery_slot == P.SLOTS.find("theme"))
	for i in 3:
		await process_frame
	_expect("and does not come back", game._reveals.is_empty())
	_reset_reveals()
	_blank()


## A purchase approved while a versus summary is up. The wardrobe is somewhere
## else, and walking there would leave a rematch unanswered.
func _not_from_a_summary() -> void:
	print("--- from a summary it only offers to carry on ---")
	_blank()
	_reset_reveals()
	game._pack_at_boot = false
	P.owned = {P.PACK_PREMIUM: true}
	game.phase = game.Phase.OVER
	game.over_age = 5.0
	await process_frame
	await process_frame
	_expect("a purchase this session is welcomed as one",
		game._reveal_queued("premium") and bool(game._reveals[0]["fresh"]))
	game._reveal_skip()
	var bs: Array = game._reveal_buttons()
	_expect("one button, and it stays on the summary", bs.size() == 1
		and String(bs[0]["action"]) == "reveal_close")
	game._activate("reveal_close")
	_expect("still on the summary", game.phase == game.Phase.OVER)
	_reset_reveals()
	_blank()


func _the_hand_fits_on_the_screen() -> void:
	print("--- the pack's hand fits ---")
	for tall in [true, false]:
		for safe in [[0.0, 0.0], [104.0, 40.0]]:
			game.portrait = tall
			var size := Vector2(720, 1440) if tall else Vector2(1280, 720)
			game.safe_top = float(safe[0]) if tall else 0.0
			game.safe_bottom = float(safe[1]) if tall else 0.0
			var n: int = game._pack_tiles().size()
			var rects: Array = game._pack_tile_rects(size, n)
			var ok := true
			# Under the second line of words, with room to spare: a fixed
			# offset used to put that line behind the top row in landscape.
			var top: float = float(game._pack_head(size)["two"]) + 14.0
			for i in n:
				var r: Rect2 = rects[i]
				ok = ok and r.position.y >= top and r.end.y < game._reveal_button_top(size) - 40.0
				ok = ok and r.position.x >= 0.0 and r.end.x <= size.x
				ok = ok and r.size.x >= 90.0
				for j in range(i + 1, n):
					ok = ok and not r.intersects(rects[j])
			_expect("%s, insets %s: under the words, over the buttons, apart" % [
				"portrait" if tall else "landscape", str(safe)], ok)
	game.portrait = true
	game.safe_top = 0.0
	game.safe_bottom = 0.0


func _the_share_card_waits_its_turn() -> void:
	print("--- the share card waits its turn ---")
	_blank()
	_reset_reveals()
	P.prefs.erase("share_promo_seen")
	P.prefs.erase("share_promo_day")
	P.owned = {P.PACK_PREMIUM: true}
	game.share_promo_open = false
	game._raise_share_promo()
	_expect("not raised while the pack's unveiling is owed", not game.share_promo_open)
	P.note_premium_reveal()
	game._raise_share_promo()
	_expect("raised once it is not", game.share_promo_open)
	game.share_promo_open = false
	_reset_reveals()
	_blank()


func _the_lobby_names_the_goal() -> void:
	print("--- versus says what it is counting towards ---")
	_blank()
	P.versus_matches = 1
	var g: Dictionary = game._versus_goal()
	_expect("the subway, one of three", String(g.get("id", "")) == "subway"
		and int(g.get("have", -1)) == 1 and int(g.get("want", -1)) == 3)
	# The line hangs 46 under the footnotes' edge. In landscape the Back button
	# is under them too, and has to have moved out of its way.
	game.portrait = false
	stage.size = Vector2i(1280, 720)
	game.phase = game.Phase.LOBBY
	var foot: float = game._grid_bottom(game._lobby_door_rects(), 360.0 + game.safe_top) + 30.0
	var line := Rect2(0.0, foot + 46.0 - 10.0, 1280.0, 20.0)
	var clear := true
	var back_seen := false
	for b: Dictionary in game._menu_buttons():
		if String(b["action"]) == "title":
			back_seen = true
			clear = clear and not (b["rect"] as Rect2).intersects(line)
	_expect("in landscape it clears the Back button", back_seen and clear)
	_expect("and everything still fits on the screen",
		game._menu_buttons().all(func(b): return (b["rect"] as Rect2).end.y <= 720.0))
	game.phase = game.Phase.TITLE
	game.portrait = true
	stage.size = Vector2i(720, 1440)

	P.versus_matches = 7
	_expect("and nothing once it is earned", game._versus_goal().is_empty())
	_blank()
