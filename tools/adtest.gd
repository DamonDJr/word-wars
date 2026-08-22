extends SceneTree
## The ad break: when it fires, when it must not, and that it gives the screen
## back afterwards.
##
## Three of these are the kind of bug you only find in the wild. A break that
## fires during a versus rematch leaves the other player staring at a card while
## nothing happens on their side. A break that forgets what the player asked for
## drops them on the title screen after they pressed Rematch. And a counter that
## is not cleared when the break is served shows the same one every match from
## then on. None of the three is visible from the summary screen, and all three
## are cheap to check here.
##
##   godot --headless --script tools/adtest.gd

var game: Node
var P: Node
var fails := 0


func _init() -> void:
	await process_frame
	game = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	P = get_root().get_node("Profile")
	P.save_path = "user://profile-ad-test.cfg"
	P.owned = {}

	_it_fires_inside_the_window()
	_it_holds_the_screen()
	_it_gives_back_what_was_asked_for()
	_the_pack_and_the_practice_modes_are_exempt()
	_versus_never_breaks()

	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(P.save_path + suffix))
	print("--- %s ---" % ("the break behaves" if fails == 0 else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)


## Sit on a finished normal match, which is the only place `_ad_before` says yes.
func _at_summary() -> void:
	game.start_match("Duelist", 1)
	game.phase = game.Phase.PLAY
	game.winner = "YOU"
	game._end_match(game.sides[1])


## How many matches it took to earn a break, counted the way the game counts
## them — through the end of a real match rather than by poking `since_ad`.
func _matches_until_break() -> int:
	P.owned = {}
	P.since_ad = 0
	P.ad_gap = 0
	for i in range(1, 40):
		_at_summary()
		if game._ad_before("title"):
			return i
	return -1


func _it_fires_inside_the_window() -> void:
	print("--- it lands between three and five matches ---")
	var lengths: Dictionary = {}
	var ok := true
	for run in 24:
		var n := _matches_until_break()
		ok = ok and n >= P.ADS_EVERY_MIN and n <= P.ADS_EVERY_MAX
		lengths[n] = true
		# Serve it, so the next run starts from a freshly rolled gap.
		game._start_ad("title")
		game._activate("title")
	_expect("every gap is %d to %d matches" % [P.ADS_EVERY_MIN, P.ADS_EVERY_MAX], ok)
	_expect("and the length actually varies", lengths.size() > 1)


func _it_holds_the_screen() -> void:
	print("--- it holds the screen for the dwell ---")
	P.since_ad = 0
	P.ad_gap = P.ADS_EVERY_MIN
	for i in P.ADS_EVERY_MIN:
		_at_summary()
	_expect("a break is due", game._ad_before("title"))

	game._activate("title")
	_expect("leaving the summary starts it", game.phase == game.Phase.AD)
	_expect("it did not go to the title instead", game.phase != game.Phase.TITLE)
	# Counted the moment it is served. Killing the app halfway through must not
	# be a way to be shown the same break forever.
	_expect("and the counter is spent", P.since_ad == 0)
	_expect("with a fresh gap rolled",
		P.ad_gap >= P.ADS_EVERY_MIN and P.ad_gap <= P.ADS_EVERY_MAX)

	_expect("close is dead at zero seconds", not game._ad_closable())
	_expect("and the button says so", _ad_button_action(0) == "ad_wait")
	game._activate("ad_wait")
	_expect("pressing it early changes nothing", game.phase == game.Phase.AD)

	game.ad_age = game.AD_DWELL - 0.1
	_expect("still dead a tenth short", not game._ad_closable())
	game.ad_age = game.AD_DWELL
	_expect("live once the dwell is up", game._ad_closable())
	_expect("and the button becomes Close", _ad_button_action(0) == "ad_close")
	game._activate("ad_close")
	_expect("which hands the screen back", game.phase == game.Phase.TITLE)


## The action on one of the break's two buttons, which is also what a tap on it
## would reach — both come off `_menu_buttons`.
func _ad_button_action(i: int) -> String:
	var buttons: Array = game._menu_buttons()
	if i >= buttons.size():
		return ""
	return String((buttons[i] as Dictionary)["action"])


func _it_gives_back_what_was_asked_for() -> void:
	print("--- it gives back the door that was asked for ---")
	P.since_ad = 0
	P.ad_gap = P.ADS_EVERY_MIN
	for i in P.ADS_EVERY_MIN:
		_at_summary()
	game._activate("rematch")
	_expect("Rematch starts a break too", game.phase == game.Phase.AD)
	_expect("and remembers which door it was", game.ad_next == "rematch")
	game.ad_age = game.AD_DWELL
	game._activate("ad_close")
	_expect("closing it starts the match, not the title",
		game.phase == game.Phase.COUNTDOWN or game.phase == game.Phase.PLAY)
	_expect("and nothing is left owed", game.ad_next == "")

	# Close is the only way off the break now that the test store has gone, and
	# it has to be the only way: a second button whose action nothing handles
	# would sit there looking live and swallow the tap that should have closed.
	P.since_ad = 0
	P.ad_gap = P.ADS_EVERY_MIN
	for i in P.ADS_EVERY_MIN:
		_at_summary()
	game._activate("title")
	game.ad_age = game.AD_DWELL
	var acts: PackedStringArray = []
	for b: Dictionary in game._menu_buttons():
		acts.append(String(b["action"]))
	_expect("the break offers exactly one door (%s)" % ", ".join(acts),
		acts.size() == 1 and acts[0] == "ad_close")
	game._activate("ad_close")
	_expect("and it leads out", game.phase == game.Phase.TITLE)


func _the_pack_and_the_practice_modes_are_exempt() -> void:
	print("--- who never sees one ---")
	P.owned = {}
	P.since_ad = 99
	P.ad_gap = P.ADS_EVERY_MIN
	_at_summary()
	_expect("an ordinary match is due one", game._ad_before("title"))

	P.grant(P.PACK_PREMIUM)
	_expect("an owner is not", not game._ad_before("title"))
	P.revoke(P.PACK_PREMIUM)

	# A lesson and a training run are not matches — they bank nothing and they
	# cost nothing, so they must not be interrupted to sell anything either.
	for how in [game.Mode.TUTORIAL, game.Mode.TRAINING, game.Mode.DAILY]:
		game.start_match("Rookie", 0, [], how)
		game.phase = game.Phase.OVER
		_expect("mode %d is exempt" % how, not game._ad_before("title"))

	# And no other button on the summary is a door a break stands behind.
	_at_summary()
	P.since_ad = 99
	for action in ["mastery", "settings", "cosmetics", "solo", "ad_close"]:
		_expect("%s is not gated" % action, not game._ad_before(action))


## A live Game Center match cannot be stood up on a Linux box, so `net_active()`
## is false here no matter what — which is why the network clause is a parameter
## rather than something `_ad_before` reads for itself. This is the only check in
## the file that could not exist otherwise.
func _versus_never_breaks() -> void:
	print("--- versus is never interrupted ---")
	game.start_match("Duelist", 1)
	game.mode = game.Mode.NORMAL
	_expect("a local match may be interrupted", game._ad_allowed(false))
	_expect("a networked one may not", not game._ad_allowed(true))
	_expect("and the real predicate is off the network state",
		game._ad_allowed(game.net_active()) == not game.net_active())


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-52s %s" % [what, "ok" if ok else "FAILED"])
