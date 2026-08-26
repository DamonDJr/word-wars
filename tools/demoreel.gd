extends SceneTree
## A match that plays itself, for recording footage.
##
## Not a test — nothing here asserts anything. It exists because the game has no
## demo mode and a phone cannot be filmed over somebody's shoulder without the
## shoulder being in the shot.
##
## ## Recording it
##
## One manual step first, and it cannot be done from in here: Godot's movie
## writer takes its output size from `display/window/size/viewport_*` in
## project.godot, read once at startup. Set them to 720 x 1440, record, and put
## them back.
##
##     godot --fixed-fps 30 --write-movie reel.avi --script tools/demoreel.gd
##
## `--resolution` does not help — it sizes the *window*, which the writer
## ignores. Nor does resizing at runtime. Everything that decides the recording
## is either that project setting or the three lines in `_init` that force the
## layout; see the comment there for what each one is fighting.
##
## Expect roughly thirty seconds of wall clock per second of footage. Software
## rendering at this size is the cost, and `--fixed-fps` means the result is
## still perfectly timed however slowly it was produced.
##
## ## Why it reads the board instead of typing a script
##
## The obvious version is a list of nice words typed on a timer. It looks wrong
## within two seconds: garbage arrives with prefixes minted from the run's own
## seed, so a fixed word list mostly fires at nothing and the footage is a reel
## of rejected words — the exact opposite of the pitch.
##
## So each word is chosen from what is actually on the board, through the same
## `WordBank.candidates` the CPU opponents use. Whatever it types will clear
## something, because it was picked for being able to.
##
## Letters are typed one at a time at a human rate rather than assigned in one
## go. The typing *is* the game; a word appearing instantly reads as a cutscene.

## Roughly 55wpm, which is quick enough to look competent and slow enough to
## read. Real thumbs land around 36-38, but nobody wants to watch that.
const KEY_EVERY := 0.055
## The beat between firing and starting the next word — thinking time, and the
## window the impact animation needs to land before the screen gets busy again.
const THINK := 0.34
## Long enough to show the loop several times over. Trimmed to length later.
const REEL_SECONDS := 14.0

## Words the reel will not type.
##
## The picker takes the longest candidate on the board, and the common-word list
## is a dictionary rather than an advertising script — the first test run put
## "lovemaking" on screen in the second beat. The censor does not help here: it
## masks slurs, and this is not a slur, it is simply not what anybody wants in a
## shop window. Substring match, so the inflections go with it.
const NOT_IN_AN_AD := ["sex", "lovemak", "kill", "death", "dead", "drug",
	"suicid", "rape", "nazi", "abort", "cancer", "murder"]

var game: Node
var spent: Dictionary = {}
## Resolved at runtime, never named at class scope. `--script` compiles this
## file before the autoloads are registered, so a bare `WordBank` here is a
## compile error that takes the whole reel down before a window ever opens.
var _wb: Node


func _init() -> void:
	await process_frame
	_wb = get_root().get_node("WordBank")
	game = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame

	# Straight past the splash and into a match. The splash is filmed separately
	# — it is the best-looking thing in the build and deserves its own beat, not
	# a two-second wait at the head of the gameplay clip.
	game._skip_splash()
	await process_frame
	# Portrait, forced, after `_ready` rather than before it.
	#
	# Three ways of asking for a portrait window were all ignored here:
	# `--resolution`, `DisplayServer.window_set_size` and setting the root size.
	# The recorder opens at the screen's own 1920x1080 and `_apply_orientation`
	# reads the *window*, so the game laid itself out for a desktop and the movie
	# writer — which records the project's viewport, not the window — captured a
	# 720x1440 slice of a landscape screen. That is the centre column of the HUD
	# and nothing else: no board, no keyboard.
	#
	# So the layout is set directly and the resize hook is unhooked behind it,
	# because that hook is the only thing that would put it back.
	if get_root().size_changed.is_connected(game._apply_orientation):
		get_root().size_changed.disconnect(game._apply_orientation)
	game.portrait = true
	# `expand` is the project's stretch aspect, and it does exactly that: with a
	# 1920x1080 window and a 720x1440 design it widens the viewport to 2560 and
	# lays the keyboard out across all of it, while the recorder writes the
	# middle 720 — a board correctly centred between a Q and a P that are off
	# both edges. `keep` pins the viewport to the design size instead.
	get_root().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	get_root().content_scale_size = game.PORTRAIT_SIZE
	game._measure_safe_area(game.PORTRAIT_SIZE)
	game._layout_boards()
	game.queue_redraw()
	await process_frame
	print("[reel] viewport=%s rect=%s portrait=%s" % [
		get_root().content_scale_size, game.get_viewport_rect().size, game.portrait])
	game.start_match("Magpie", 1)
	game.phase = game.Phase.PLAY
	# A match opens on an empty board with the first garbage twenty seconds out,
	# which is twenty seconds of a reel with nothing in it and nothing to type
	# at. The daily's opening pile is exactly the fix — a board that already
	# means something on frame one — so it is borrowed wholesale.
	game._deal_daily_opening()
	# And kept coming. The standard ramp is built for a three-minute match; over
	# half a minute of footage it would deal twice.
	game.pressure_interval = 2.6
	game.pressure_timer = 1.2
	await process_frame

	var elapsed := 0.0
	while elapsed < REEL_SECONDS:
		var word := _pick()
		if word == "":
			# Nothing answerable on the board this instant, which happens right
			# after a big clear. Wait for the next garbage rather than firing
			# something that will bounce.
			await _hold(0.25)
			elapsed += 0.25
			continue
		# Through `_press_key`, not by assigning `typed`. It is the same call a
		# thumb makes, so the keystroke sounds, the counters and the cursor all
		# behave as they do in a real match — and naming `Sfx` here directly
		# would not even compile, since `--script` builds this file before the
		# autoloads exist. Same trap `selftest.gd` sat in for a year.
		for i in word.length():
			game._press_key(word[i])
			await _hold(KEY_EVERY)
			elapsed += KEY_EVERY
		game._fire_pressed()
		spent[word] = true
		print("[reel] %5.1fs  %s" % [elapsed, word])
		await _hold(THINK)
		elapsed += THINK

	quit(0)


## The longest word on offer for anything currently on the board.
##
## Longest on purpose: length drives the tier now, so the long ones are the ones
## that visibly detonate. A reel of three-letter words would be honest and
## boring.
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
			for bad in NOT_IN_AN_AD:
				if cand.contains(bad):
					ok = false
					break
			if ok:
				best = cand
	return best


## A real wait on the tree's own clock, so the game keeps animating through it.
## `await process_frame` returns nothing to subtract, which is a quiet way to
## write a loop that never sleeps and types the whole word in one frame.
func _hold(seconds: float) -> void:
	await create_timer(seconds).timeout
