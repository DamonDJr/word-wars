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
var sharing_profile: Node
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
		_expect("mode %d carries a link" % m,
			game._share_text().contains(sharing.SHARE_BASE))


## Everything the redesigned card promises, for every mode that can produce one.
##
## The card stopped being a table of numbers and became an advertisement, and the
## parts that make it one are the parts a fifth mode would silently ship without:
## a question aimed at the reader, a line under it, and a badge saying why the
## number is worth anything. None of those are load-bearing for the *render* — a
## card with an empty dare draws perfectly happily, and looks exactly like the
## inert first cut this replaced.
func _the_card_sells_the_game() -> void:
	print("--- every card asks for something back ---")

	var modes := {
		game.Mode.SURVIVAL: "survival",
		game.Mode.DAILY: "daily",
		game.Mode.NORMAL: "a match",
	}
	for m: int in modes:
		game.start_match("Duelist", 1, [], m)
		game.player.score = 9400
		game.match_time = 187.0
		game.winner = "YOU"
		var c = game._share_card_data()
		var who := String(modes[m])
		_expect("%s dares the reader: '%s'" % [who, c.dare], c.dare != "")
		_expect("%s explains itself: '%s'" % [who, c.footer], c.footer != "")
		# The card draws three cells and no more. A fourth would be measured into
		# the layout and then never painted, which is a hole rather than a crash.
		_expect("%s carries no more than three stats (%d)" % [who, c.stats.size()],
			c.stats.size() <= 3)
		for row in c.stats:
			_expect("%s stat '%s' is a label and a value" % [who, row[0]],
				(row as Array).size() == 2 and String(row[1]) != "")

	# The best word is the only thing on the card that says "word game". It comes
	# off the side rather than being recomposed, so a rename upstream loses it
	# quietly.
	game.start_match("Duelist", 1, [], game.Mode.NORMAL)
	game.player.best_word = "ENTRANCE"
	game.player.best_word_score = 2440
	var w = game._share_card_data()
	_expect("the card carries the match's best word (%s)" % w.word,
		w.word == "ENTRANCE")
	_expect("and what it was worth: '%s'" % w.word_note, w.word_note.contains("2,440"))

	# A match with nothing played still has to draw. The word block is dropped
	# rather than left as an empty row of tiles.
	game.start_match("Duelist", 1, [], game.Mode.NORMAL)
	game.player.best_word = ""
	_expect("a match with no word drops the block outright",
		game._share_card_data().word == "")


## The link has something on the far end worth scraping.
##
## This is the check the whole share used to fail. It went out as the player's
## sentence with the App Store URL glued on, and Facebook, Threads and LinkedIn
## all do the same thing with that: find the URL, fetch it, render what it says
## about itself, discard the sentence and the picture. So a card that took a file
## to compose arrived as a grey box with an app name in it.
##
## The link is now a page we wrote, with `og:` tags and an image on it. Three
## things have to hold for that to keep working, and every one of them breaks
## silently — the game still shares, the sheet still opens, and nobody finds out
## until somebody looks at a post:
##
##   * every slug the game can produce has a page committed behind it. A missing
##     one is a 404 where the preview should be, which is worse than the bare
##     store link it replaced;
##   * the two halves agree on the address. `tools/ogcards.gd` writes the pages
##     and cannot see this autoload, so it keeps its own copy of the site root;
##   * nothing the player did not type ends up unescaped in a URL.
func _the_link_has_something_to_scrape() -> void:
	print("--- the link points at a page worth fetching ---")

	# Driven through the real slug function rather than listed, so a fifth mode
	# fails here instead of shipping a dead link.
	var seen: Array[String] = []
	for m in [game.Mode.SURVIVAL, game.Mode.DAILY, game.Mode.NORMAL]:
		for diff in ["Versus", "Duelist"]:
			for won in [true, false]:
				game.start_match(diff, 1, [], m)
				game.difficulty = diff
				game.winner = "YOU" if won else "THEM"
				game.player.score = 4200
				var slug: String = game._share_slug()
				if seen.has(slug):
					continue
				seen.append(slug)
				_expect("slug '%s' has a page" % slug,
					FileAccess.file_exists("res://docs/s/%s/index.html" % slug))
				_expect("slug '%s' has a preview image" % slug,
					FileAccess.file_exists("res://docs/s/og/%s.png" % slug))

	# The regression itself, stated plainly: the store link may not be what goes
	# out, because that is the thing the scrapers were eating.
	game.start_match("Duelist", 0, [], game.Mode.SURVIVAL)
	game.match_time = 252.0
	game.player.score = 14320
	var text: String = game._share_text()
	_expect("the share links to our page, not the store",
		text.contains(sharing.SHARE_BASE) and not text.contains(sharing.STORE_URL))
	_expect("and carries the run's numbers with it (%s)" % text.split("\n")[-1],
		text.contains("h=4%3A12"))

	# `ogcards.gd` is a standalone script and never loads this autoload, so it
	# writes the address out a second time. Two copies that can disagree is
	# exactly the sort of thing that is found six weeks later by a 404.
	var tool_script := load("res://tools/ogcards.gd")
	var consts: Dictionary = tool_script.get_script_constant_map()
	_expect("the page writer agrees on the site root",
		String(consts.get("SITE", "")) == sharing.SITE_URL)
	_expect("and on the store link",
		String(consts.get("STORE_URL", "")) == sharing.STORE_URL)

	# A versus badge can carry a rival's Game Center display name, which is
	# whatever they typed into it. It reaches the page through the query string.
	var hostile: String = sharing.page_url("survival",
		{"b": "beat \"Bobby\" & <friends>?"})
	_expect("a rival's name is encoded, not pasted: %s" % hostile.split("?")[-1],
		not hostile.contains(" ") and not hostile.contains("\"")
		and not hostile.contains("<"))
	_expect("and an empty value is dropped rather than left dangling",
		not sharing.page_url("daily", {"h": "8,150", "b": ""}).contains("b="))


## The one badge that can lie.
##
## Survival's "new personal best" cannot be worked out at summary time: by then
## `Profile.survival_best_time` has already been raised to include the run that
## just ended, so a naive comparison calls every single run a record. The answer
## is only knowable from `survival_took`, banked at the moment the run was
## recorded — and a run too short to bank is not a record at all.
func _the_record_badge_tells_the_truth() -> void:
	print("--- and only claims a record when there was one ---")

	game.start_match("Duelist", 0, [], game.Mode.SURVIVAL)
	game.match_time = 252.0
	game.player.score = 14320
	sharing_profile.survival_best_time = 402.0

	game.survival_took = {}
	var plain = game._share_card_data()
	_expect("an ordinary run is not announced as a best: '%s'" % plain.badge,
		not plain.badge.to_lower().contains("personal best"))
	_expect("and it is not drawn in gold", not plain.badge_hot)

	game.survival_took = {"time": true, "score": true}
	var best = game._share_card_data()
	_expect("the run that took the record says so: '%s'" % best.badge,
		best.badge.to_lower().contains("personal best"))
	_expect("and that one is gold", best.badge_hot)

	game.survival_took = {}


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
	# Named off the root rather than at class scope: `--script` compiles this
	# file before the autoloads exist, and a bare `Profile` here is a compile
	# error that takes the run down before a single check runs.
	sharing_profile = root.get_node("Profile")
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
	_the_link_has_something_to_scrape()
	_the_card_sells_the_game()
	_the_record_badge_tells_the_truth()
	_the_summary_fits_three_doors()
	_the_summary_has_no_letter_keys()

	print("--- %s ---" % ("sharing holds up" if fails == 0
		else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)
