extends SceneTree
## The share door, its copy, and the layout it has to fit into.
##
## The addon is not installed on this machine and would not run here if it were —
## a share sheet is a native view controller. So what is checked is everything on
## our side of the seam, which is where the bugs actually were:
##
##   * the seam itself refuses cleanly rather than crashing when the addon is
##     absent, which is the state every desktop build and every export that
##     forgot the plugin is in;
##   * the card path is under `user://`, because an iOS share sheet cannot read
##     a path anywhere else and the addon says so in as many words;
##   * the copy, for all four modes — this leaves the game, so it may not lean
##     on anything only a player would know;
##   * the summary can lay out three buttons. It could not: `_over_button_rects`
##     asked `_grid_rects` for exactly two in landscape however many were wanted,
##     so the third door indexed past the end of the array.
##
##   godot --headless --script tools/sharetest.gd

var game: Node
var sharing: Node
var stage: SubViewport
var fails := 0


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-58s %s" % [what, "ok" if ok else "FAILED"])


func _orient(tall: bool) -> void:
	stage.size = game.PORTRAIT_SIZE if tall else game.LANDSCAPE_SIZE
	game.portrait = tall


## The seam holds with nothing behind it.
##
## "Nothing behind it" is two different states and both land here. The addon may
## be absent entirely, or — the case this machine is actually in — its GDScript
## half may be installed while the native singleton it drives is not, which is
## every desktop run and every iOS export that forgot to tick the plugin.
func _the_seam_refuses_cleanly() -> void:
	print("--- with no native plugin behind the addon ---")
	_expect("sharing reports itself unavailable", not sharing.available())
	_expect("and says why: '%s'" % sharing.why_unavailable(),
		sharing.why_unavailable() != "")
	# The whole point of the seam: these are called from a button and must not
	# take the game down when the plugin is not there.
	_expect("share_image refuses rather than crashing",
		sharing.share_image("user://share/nope.png", "t", "s", "c") == false)
	_expect("share_text refuses rather than crashing",
		sharing.share_text("t", "s", "c") == false)
	_expect("so the summary offers no Share door", not game._share_possible())

	var path: String = sharing.card_path()
	_expect("the card path is under user:// (%s)" % path,
		path.begins_with("user://"))
	_expect("and globalizes to a real absolute path",
		ProjectSettings.globalize_path(path).begins_with("/"))


## Four modes, four different sentences. None of them may be empty, and none may
## say something only somebody already playing would understand.
func _the_copy_reads_outside_the_game() -> void:
	print("--- what each mode says ---")

	game.start_match("Duelist", 0, [], game.Mode.SURVIVAL)
	game.match_time = 252.0
	game.player.score = 14320
	var surv: String = game._share_text()
	_expect("survival: %s" % surv, surv.contains("4:12") and surv.contains("14,320"))
	_expect("and its card leads on the clock",
		game._share_card_data().headline == "4:12")

	game.start_match("Duelist", 0, [], game.Mode.DAILY)
	game.player.score = 8150
	var daily: String = game._share_text()
	_expect("daily: %s" % daily, daily.contains("8,150"))
	_expect("and its card leads on the score",
		game._share_card_data().headline == "8,150")

	# A bot match names the bot. "CPU beat me" is what the seat label would give
	# and it means nothing to whoever is reading it.
	game.start_match("Berserker", 1, [], game.Mode.NORMAL)
	game.player.score = 6200
	for s in game.sides:
		if s != game.player and s.in_match:
			s.score = 11480
	game.winner = "THEM"
	var solo: String = game._share_text()
	_expect("solo names the opponent: %s" % solo, solo.contains("BERSERKER"))
	_expect("and does not say CPU", not solo.contains("CPU"))
	_expect("its card records the loss", game._share_card_data().verdict == "LOST")

	game.winner = "YOU"
	game.player.score = 12400
	_expect("a win says so", game._share_card_data().verdict == "WON")
	_expect("and the sentence flips: %s" % game._share_text(),
		game._share_text().begins_with("I beat"))

	# Every card has to carry a number, and every share the link. A blank
	# headline is a blank picture, and a share with no link is a nice picture
	# nobody can act on.
	for m in [game.Mode.SURVIVAL, game.Mode.DAILY, game.Mode.NORMAL]:
		game.start_match("Duelist", 1, [], m)
		game.player.score = 1000
		_expect("mode %d still has a headline and text" % m,
			game._share_card_data().headline != "" and game._share_line() != "")
		_expect("mode %d carries the store link" % m,
			game._share_text().contains(sharing.STORE_URL))


## The bug. Three doors have to get three rectangles, both ways up.
func _the_summary_fits_three_doors() -> void:
	print("--- three doors fit the summary ---")
	game.phase = game.Phase.OVER
	game.mode = game.Mode.NORMAL

	for tall in [true, false]:
		_orient(tall)
		var which := "portrait" if tall else "landscape"
		for n in [1, 2, 3]:
			var rects: Array = game._over_button_rects(n)
			_expect("%s lays out %d door%s" % [which, n, "" if n == 1 else "s"],
				rects.size() == n)
		var three: Array = game._over_button_rects(3)
		var view: Vector2 = game.get_viewport_rect().size
		var last: Rect2 = three[2]
		_expect("%s keeps the third inside the width" % which,
			last.position.x >= 0.0 and last.end.x <= view.x)
		# None of them may sit on top of another, which a hardcoded column count
		# would happily do.
		_expect("%s does not overlap the first two" % which,
			not (three[0] as Rect2).intersects(three[1])
			and not (three[1] as Rect2).intersects(three[2]))

	_orient(true)


## A letter shortcut here is how a word still in flight starts something. The
## summary dropped R for Rematch over exactly this, and Share must not add one.
func _the_summary_has_no_letter_keys() -> void:
	print("--- and no letter opens it by accident ---")
	game.phase = game.Phase.OVER
	game.mode = game.Mode.NORMAL
	for b: Dictionary in game._menu_buttons():
		var key := String(b["key"])
		_expect("%s carries no letter badge ('%s')" % [String(b["action"]), key],
			key == "" or key == "ESC")


func _init() -> void:
	await process_frame
	sharing = root.get_node("Sharing")
	game = load("res://scenes/main.tscn").instantiate()
	stage = SubViewport.new()
	stage.size = Vector2i(1280, 720)
	root.add_child(stage)
	stage.add_child(game)
	await process_frame
	await process_frame
	_orient(false)

	_the_seam_refuses_cleanly()
	_the_copy_reads_outside_the_game()
	_the_summary_fits_three_doors()
	_the_summary_has_no_letter_keys()

	print("--- %s ---" % ("sharing holds up" if fails == 0
		else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)
