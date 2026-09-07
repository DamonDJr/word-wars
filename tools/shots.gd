extends SceneTree
## Marketing stills of the phone layout, rendered rather than screenshotted.
##
## Same job as `demoreel.gd` and the same three lines of layout forcing, but for
## single frames instead of footage — no movie writer, no project.godot edit, no
## thirty seconds of wall clock per second of output. One shot per invocation:
##
##     godot --script tools/shots.gd -- daily
##     godot --script tools/shots.gd -- daily --ipad
##     godot --script tools/shots.gd -- daily --appstore
##     godot --script tools/shots.gd -- daily --ipad --appstore
##
##     tools/shots.sh              # all of them, into build/shots/
##     tools/shots.sh --ipad       # the tablet layout, both keyboards
##     tools/shots.sh --appstore   # both submission sets, at Apple's sizes
##
## The shot name has to come first; the flags are order-free after it.
##
## **Do not pass `--headless`.** The dummy renderer saves a blank image. There is
## a real display on this machine, so a plain `--script` run is what works.
##
## ## Why each shot plays before it poses
##
## A screenshot of a fresh match is a screenshot of an empty grid: no blocks, no
## chain meter, no readout under the input line. So the gameplay shots deal an
## opening pile and then type real words at the board through `_press_key`,
## picking each one out of `WordBank.candidates` the way `demoreel.gd` does, so
## everything on screen is something the game actually produced.
##
## The last word is left half-typed on purpose. That is when the HUD is at its
## most explanatory — the blocks the word can reach are lit, and the readout
## under the line says how many of them it takes — and it is the single frame
## that best explains the mechanic to somebody who has never seen it.
##
## ## Why the leaderboard is injected
##
## Game Center cannot be reached from Linux; the plugin is a stub that refuses to
## instantiate. So the rows go straight into `Boards`, exactly as
## `tools/boardstest.gd` does, and what gets rendered is the screen built on top
## of them. The names below are invented.

const OUT_DIR := "res://build/shots"
const SHOT_SIZE := Vector2i(720, 1440)
## Frames to let the layout settle before the grab. Below about six the board is
## still mid-relayout and the grab catches it half-placed.
const SETTLE := 10
## Roughly 55wpm, as in the reel — fast enough to look competent.
const KEY_EVERY := 0.055
const THINK := 0.30

## Words the shots will not type. The picker takes the longest candidate on the
## board and the common-word list is a dictionary, not an advertising script.
## Substring match, so inflections go with it.
const NOT_IN_A_SHOT := ["sex", "lovemak", "kill", "death", "dead", "drug",
	"suicid", "rape", "nazi", "abort", "cancer", "murder", "slaughter",
	"terror", "victim", "corpse"]

var game: Node
## The game renders into this rather than into the window. A real window is
## clamped to the height of the actual screen — 1440 does not fit on a 1080
## desktop, so the root capture came back a soft 540x1080. A SubViewport is not
## a window and is not clamped, and `get_viewport_rect()` inside it reports the
## size we asked for, which is what every layout routine in `game.gd` reads.
var stage: SubViewport
var spent: Dictionary = {}
## Resolved off the root, never named at class scope: `--script` compiles this
## file before the autoloads are registered, so a bare `WordBank` here is a
## compile error that takes the whole run down before a window opens.
var _wb: Node
var _boards: Node
var _profile: Node


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var shot := String(args[0]) if args.size() > 0 else "daily"
	# `--ipad` renders the tablet layout instead, into the tablet viewport, so
	# the split keyboard and the rival board can be looked at without an iPad.
	ipad = args.has("--ipad")
	# `--fullkeys` renders the tablet with the split turned off, which is the
	# other half of the keyboard setting and the one nobody would otherwise
	# look at. Poked straight into the dictionary rather than through
	# `set_pref`, which would save it into the dev profile on the way past.
	full_keys = args.has("--fullkeys")
	# `--appstore` renders at the sizes App Store Connect will accept rather
	# than at the design space. See STORE_PHONE / STORE_TABLET.
	appstore = args.has("--appstore")

	_wb = get_root().get_node("WordBank")
	_boards = get_root().get_node("Boards")
	_profile = get_root().get_node("Profile")

	stage = SubViewport.new()
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_size_stage()
	get_root().add_child(stage)
	game = load("res://scenes/main.tscn").instantiate()
	stage.add_child(game)
	await process_frame
	await process_frame
	game._skip_splash()
	await process_frame
	_force_portrait()

	match shot:
		"title": await _shot_title()
		"daily": await _shot_daily()
		"survival": await _shot_survival()
		"boards": await _shot_boards()
		"solo": await _shot_solo()
		"mastery": await _shot_mastery()
		"settings": await _shot_settings()
		_:
			push_error("unknown shot: %s" % shot)
			quit(1)
			return

	for i in SETTLE:
		await process_frame
	_save(shot)
	quit(0)


## Portrait, forced, after `_ready` rather than before it — and the resize hook
## unhooked behind it, because that hook is the only thing that would put it
## back. See the long note in `demoreel.gd` for what each line is fighting.
func _force_portrait() -> void:
	if get_root().size_changed.is_connected(game._apply_orientation):
		get_root().size_changed.disconnect(game._apply_orientation)
	game.portrait = true
	_size_stage()
	game._measure_safe_area(_stage_size())
	if ipad:
		# `_measure_device` reads the real window, which here is a desktop one,
		# so the two numbers it would have worked out are set directly instead —
		# exactly what `--ipad` does inside the game. An iPad Air's: 0.82 points
		# to a design unit, and a home indicator at the bottom with nothing at
		# the top, because no iPad has a notch.
		game.tablet = true
		game.points_per_unit = _ppu()
		game.safe_top = 0.0
		game.safe_bottom = 24.0
		if full_keys:
			_profile.prefs["split_keys"] = false
	game._layout_boards()
	game.queue_redraw()


## The iPad Air's portrait viewport, in design units, and what a unit is worth
## there in points.
##
## Not a guess. `expand` stretching pins whichever axis runs out first: against
## a 720x1440 design space a 820x1180pt iPad runs out of height, so the height
## pins at 1440 and the width opens up to 820/(1180/1440) = 1001. Every iPad
## lands between 945 and 1080 across by the same arithmetic, so this one shot
## stands in for all of them to within a few percent.
const IPAD_SIZE := Vector2i(1001, 1440)
const IPAD_PPU := 0.8194

## What App Store Connect will actually take, and the design-space viewport each
## one implies. `--appstore` renders these instead of the sizes above.
##
## Apple wants one size per device family and scales the rest of the listing
## from it: 1320x2868 for the 6.9-inch iPhone, 2064x2752 for the 13-inch iPad.
## Nothing this tool produced was ever one of those — the raw stills are the
## game's 720x1440 design space and the caption cards are 1080x1920, which is a
## social shape and says so in `caption-shots.py`.
##
## The `units` half is the same arithmetic as `IPAD_SIZE`, run against the two
## devices Apple asks about:
##
##   iPhone 6.9"   440x956pt   440/720  = 0.611 pins width  ->  720 x 1564
##   iPad 13"     1032x1376pt 1376/1440 = 0.956 pins height -> 1080 x 1440
##
## ## Why this is not just a bigger viewport
##
## Rendering straight at 1320x2868 does not work. The game lays out in design
## units and its type sizes are constants, so a viewport 1320 units wide draws a
## 68-unit headline at half the size it is meant to be — a correct screenshot of
## the wrong layout. `size_2d_override` is the seam: the game is handed the
## design size and the render target is the pixel size behind it, so the result
## is drawn at full resolution rather than upscaled from a 720-wide grab.
const STORE_PHONE := {
	"px": Vector2i(1320, 2868), "units": Vector2i(720, 1564), "ppu": 0.6111}
const STORE_TABLET := {
	"px": Vector2i(2064, 2752), "units": Vector2i(1080, 1440), "ppu": 0.9556}

var ipad := false
var full_keys := false
var appstore := false


## The pixel size to render at, or zero for "same as the design size".
func _render_px() -> Vector2i:
	if not appstore:
		return Vector2i.ZERO
	return Vector2i(STORE_TABLET["px"] if ipad else STORE_PHONE["px"])


## The size the game is told it has, in design units.
func _stage_size() -> Vector2i:
	if appstore:
		return Vector2i(STORE_TABLET["units"] if ipad else STORE_PHONE["units"])
	return IPAD_SIZE if ipad else SHOT_SIZE


## What a design unit is worth in points on whichever device is being posed.
func _ppu() -> float:
	if appstore:
		return float(STORE_TABLET["ppu"] if ipad else STORE_PHONE["ppu"])
	return IPAD_PPU


## Resize the target, keeping the design-space override in step with it. Both
## `_init` and `_force_portrait` set the size, and a render that has the pixel
## size without the override is the wrong-layout screenshot described above.
func _size_stage() -> void:
	var px := _render_px()
	if px == Vector2i.ZERO:
		stage.size_2d_override = Vector2i.ZERO
		stage.size = _stage_size()
		return
	stage.size = px
	stage.size_2d_override = _stage_size()
	stage.size_2d_override_stretch = true


func _save(shot: String) -> void:
	# The submission set lands in its own directory rather than mixed in with
	# the stills, because it is uploaded as a set and picking six files out of
	# eighteen by suffix is how the wrong one gets sent.
	var dir := "%s/appstore" % OUT_DIR if appstore else OUT_DIR
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var img := stage.get_texture().get_image()
	var tag := ""
	if ipad:
		tag = "-ipad-full" if full_keys else "-ipad"
	var path := "%s/%s%s.png" % [dir, shot, tag]
	# Apple refuses a screenshot that carries an alpha channel, and refuses it
	# for *having* one rather than for using it. A viewport grab is RGBA8 with
	# every pixel opaque, which passes `detect_alpha()` — that answers "is
	# anything transparent", which is a different question — and still arrives
	# at App Store Connect with the channel on it. Dropped to RGB8 here, which
	# is the only thing that actually removes it.
	if appstore:
		img.convert(Image.FORMAT_RGB8)
	img.save_png(path)
	print("[shots] %s  %dx%d" % [path, img.get_width(), img.get_height()])


# --- the shots ------------------------------------------------------------


## Not in `shots.sh` — nothing about a settings list sells a game. It is here
## because the split-keyboard switch only exists on a tablet, and a row that
## only appears on hardware nobody in the room owns is a row that ships
## unlooked-at.
func _shot_settings() -> void:
	_pose_profile()
	game.phase = game.Phase.SETTINGS


func _shot_title() -> void:
	_pose_profile()
	game.phase = game.Phase.TITLE


## A run against the clock with the board already meaning something. The daily
## opens part-buried by design, so this is the mode's own opening pile rather
## than anything staged.
func _shot_daily() -> void:
	game.start_match("Daily", 0, [], game.Mode.DAILY)
	game.phase = game.Phase.PLAY
	await _stage()


## Deep enough into a run that the clock reads like an achievement and the
## pressure has climbed off its opening setting.
func _shot_survival() -> void:
	game.start_match("Survival", 0, [], game.Mode.SURVIVAL)
	game.phase = game.Phase.PLAY
	game.match_time = 214.0
	game.pressure_interval = 11.0
	game.pressure_timer = 4.0
	await _stage()


## A duel: your board full size, the rival along the top where a phone puts it.
func _shot_solo() -> void:
	game.start_match("Magpie", 1)
	game.phase = game.Phase.PLAY
	# The header clock counts up in a normal match, and a board this busy over
	# `0:04` reads as a bug. Ninety seconds is what the rest of the frame implies.
	game.match_time = 95.0
	await _stage()


## The progression screen, posed with an invented player rather than whatever is
## in the dev save — which has been reset enough times to read 8 matches against
## 262 wins, and a screenshot that contradicts itself is worse than no
## screenshot. Everything below is a plausible regular player: more matches than
## wins, a daily streak that exists, a survival best that took some doing.
##
## `Profile` is written directly and never saved; nothing here calls `save()`, so
## the real save on this machine is untouched.
func _shot_mastery() -> void:
	_pose_profile()
	game.phase = game.Phase.MASTERY


## The same player on every screen that shows one. The title screen prints the
## level and title in its header, so a set of shots where the title card says
## LEVEL 36 and the mastery card says LEVEL 38 is a set that has visibly been
## assembled from different sessions.
func _pose_profile() -> void:
	_profile.matches = 431
	_profile.wins = 262
	_profile.flawless = 153
	_profile.words = 16065
	_profile.salvos = 867
	_profile.multi_clears = 492
	_profile.best_wpm = 111.0
	_profile.best_chain = 13
	_profile.best_combo = 6
	_profile.best_score = 131017
	_profile.longest_word = "ENTERTAINMENT"
	_profile.daily_best = 34870
	_profile.daily_best_streak = 19
	_profile.survival_best_time = 402.0


## The daily board, mid-table, with the climb visible above you. `view_total` is
## what makes the screen say how many people are on it; `view_me` is what makes
## it say where you are when you are nowhere near the top.
func _shot_boards() -> void:
	var names := ["quickfinger", "Adaeze", "typo_dynamo", "M. Okonkwo",
		"stampcollector", "wordsmith_99", "Priya R", "eleven letters",
		"BLOQHEAD", "chainbreaker", "Tomas V", "suffixation"]
	var rows: Array = []
	var top := 48210
	for i in names.size():
		rows.append({
			"rank": i + 1,
			"name": names[i],
			"score": top - i * 1180 - (i * i * 40),
			"me": false,
		})
	_boards.view_rows = rows
	_boards.view_me = {"rank": 118, "name": "you", "score": 24630, "me": true}
	_boards.view_total = 9120
	_boards.view_board = _boards.DAILY_ID
	_boards.view_scope = _boards.GLOBAL
	_boards.view_state = _boards.ViewState.READY
	game.phase = game.Phase.BOARDS
	_boards.view_changed.emit()


# --- typing ---------------------------------------------------------------


## The order every gameplay shot poses in, and each step is here for a reason the
## first cut got wrong.
##
## Playing first and dealing second, rather than the other way round: the picker
## always takes the longest word available, so two words clear the opening pile
## faster than it can be refilled and the frame came back a near-empty grid. So
## the words are played for their side effects — a lit chain meter and a score
## that is not zero — and the board is refilled underneath them afterwards.
##
## The pause is not padding. A score pop lives exactly one second, and two of
## them mid-fade sit on top of each other and render as unreadable mush right in
## the middle of the board. 1.2s clears them and still leaves the chain window
## open, which is what keeps the meter lit.
func _stage() -> void:
	game._deal_daily_opening()
	await _play(2)
	# `_deal_daily_opening` fills *up to* a target fraction, so calling it again
	# is a no-op the moment the board is already past that mark — which is why
	# four calls looked exactly like two. The top-up has to place blocks itself.
	_bury(6)
	await _hold(1.2)
	await _half_type()


## Put `n` more blocks on the board, through the same mint-and-place pair the
## opening deal uses — so the stamps obey the same fairness rules and the sizes
## are sizes the game can actually produce. Nothing here is drawn by hand.
##
## Two thirds full is the number worth aiming at, and the window is narrow in
## both directions. A third reads as the opening seconds of a match: no jeopardy,
## nothing near the ceiling, no reason to care. Nine blocks instead of six pushed
## it the other way — the stack reached the danger line, the whole frame went red
## with the critical-pressure tint, and every shot in the set looked like a board
## about to be lost. Jeopardy sells; a funeral does not.
func _bury(n: int) -> void:
	var stalled := 0
	for i in n:
		var tier: int = [1, 2, 3][randi() % 3]
		var spec: Dictionary = game.TIERS[tier]
		var stamp: String = game._mint_stamp(
			_wb.random_common(), game.STAMP_WANT, game.player)
		if not game.player.board.add_garbage(stamp, tier, spec["w"], spec["h"]):
			stalled += 1
			if stalled > 2:
				break
	game.player.board.snap_to_grid()


## Play `n` whole words at the board, so the chain meter is lit and the score is
## not zero when the frame is taken.
func _play(n: int) -> void:
	for i in n:
		var word := _pick()
		if word == "":
			await _hold(0.25)
			continue
		for c in word.length():
			game._press_key(word[c])
			await _hold(KEY_EVERY)
		game._fire_pressed()
		spent[word] = true
		print("[shots]   typed %s" % word)
		await _hold(THINK)


## Leave a word part-typed. Everything the word can reach is lit on the board and
## the readout under the line says how far it gets — which is the whole mechanic
## in one frame, and invisible on an idle input line.
func _half_type() -> void:
	var word := _pick_reaching()
	if word == "":
		word = _pick()
	if word == "":
		return
	var upto: int = maxi(2, word.length() - 3)
	for c in upto:
		game._press_key(word[c])
		await _hold(KEY_EVERY)
	print("[shots]   left %s of %s on the line" % [word.substr(0, upto), word])


## A word answering whichever stamp is on the *most* blocks at once.
##
## `_pick` optimises for length, which is right for a reel — long words detonate
## visibly. It is wrong for a still. The readout under the input line says how
## far a word reaches, and "takes out 1 block" explains nothing to somebody who
## has never seen the game, while "takes out 3 of 5" explains the entire reach
## rule in four words. That readout only appears when one stamp is repeated, so
## the shot goes looking for the repeat rather than for the longest word.
func _pick_reaching() -> String:
	var count: Dictionary = {}
	for p in game.player.board.prefixes():
		var pre := String(p)
		if pre == "":
			continue
		count[pre] = int(count.get(pre, 0)) + 1
	var order: Array = count.keys()
	order.sort_custom(func(a, b): return count[a] > count[b])
	for pre in order:
		if int(count[pre]) < 2:
			break
		var best := ""
		for w in _wb.candidates(String(pre), 5, 13, spent, 24):
			var cand := String(w)
			if cand.length() <= best.length():
				continue
			var ok := true
			for bad in NOT_IN_A_SHOT:
				if cand.contains(bad):
					ok = false
					break
			if ok:
				best = cand
		if best != "":
			return best
	return ""


## The longest word on offer for anything currently on the board. Longest
## because those are the ones that visibly reach across several blocks.
func _pick() -> String:
	var seen := {}
	var best := ""
	for p in game.player.board.prefixes():
		var pre := String(p)
		if pre == "" or seen.has(pre):
			continue
		seen[pre] = true
		for w in _wb.candidates(pre, 5, 13, spent, 24):
			var cand := String(w)
			if cand.length() <= best.length():
				continue
			var ok := true
			for bad in NOT_IN_A_SHOT:
				if cand.contains(bad):
					ok = false
					break
			if ok:
				best = cand
	return best


## A real wait on the tree's own clock, so the game keeps animating through it.
func _hold(seconds: float) -> void:
	await create_timer(seconds).timeout
