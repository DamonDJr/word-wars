extends SceneTree
## The summary screen's emote row, filmed end to end — the feature demo.
##
## `adreel.gd` films a match and `trailer.gd` films a story. This films one
## screen: the thing that appears after a versus match is over, where the result
## is in and there is finally time to say something about it.
##
##     tools/emotereel.sh --out build/emotes/raw/take
##
## Four scenes, in one take. A short rally so the scoreboard behind the row has
## numbers somebody actually scored; the end of the match; the row arriving with
## its seven faces; and then a conversation that uses every one of them.
##
## ## The markers are the edit
##
##     [scene] talk 12.53 28.73 phase=4
##     [emote] 13.20 out nice tile=(314, 1604, 92, 92)
##
## `[scene]` bounds each movement. `[emote]` is the frame a sticker appears on,
## which direction it went, and the rect of the tile it came from — so a caption
## can point at the button being pressed without anybody scrubbing for it.
##
## ## What is staged and what is real
##
## Everything drawn is the game drawing itself. The row is `_draw_summary_emotes`
## laid out by `_summary_emote_rects`, the bubbles are `_draw_summary_emote`, the
## match is ended by the same `_end_match` a real win calls, and the incoming
## emotes go through `_on_net_emote` — the actual function the network handler
## calls, unmodified.
##
## The one thing that cannot be taken through its own front door is the *send*.
## `_send_emote` refuses outside a live match, and a live match is a `GKMatch`,
## and Game Center's plugin is a stub on Linux that will not instantiate — so on
## the only machine that can record, the send path is unreachable. See the long
## note on `demo_emotes` in `game.gd`, which exists for exactly this reason.
##
## `_say` therefore writes what `_send_emote` writes, field for field, and the
## comment there says so. What it does *not* do is guess where the button is:
## before every send it hit-tests the tile centre through the game's own
## `_action_at` and refuses to film anything if the answer is not the emote it
## meant to press. A reel that quietly drifts off the row as the layout changes
## would still look correct, which is the failure worth engineering against.

## The editorial line for what may appear in footage, shared with `adreel.gd`.
const AdWords = preload("res://tools/ad_words.gd")

const FPS := 30.0

## Roughly 55wpm — the trailer's pace. The rally here is context rather than
## subject, so it is typed at the speed the rest of the footage uses.
const KEY_EVERY := 0.055
const THINK := 0.24

## Who the rally is against, and whose name ends up on the incoming bubbles.
##
## Duelist rather than the trailer's Magpie: this scene needs a board that looks
## like an exchange for six seconds, not a show-off typing nine-letter words, and
## none of it is on screen long enough to be worth the wait.
const RIVAL := "Duelist"

## The name over the incoming sticker.
##
## Left as CPU the row would show somebody trading emotes with a bot, which is a
## thing the game does not do — `_summary_emotes_live` is versus-only and means
## it. The row is a conversation or it is a screensaver, and a conversation needs
## two names on it.
const THEM := "PRIYA"

## The conversation, in order: who says it, and which emote.
##
## Every one of `EMOTE_MENU` appears exactly once, because the video's job is to
## show what is on offer. Alternating sides, because the interesting frame is the
## one with two stickers on it — `_emote_in` and `_emote_out` are separate slots
## for precisely that, and a reel of seven consecutive sends would never once
## produce the state those two slots exist for.
##
## Starting with `nice` rather than `cheer`: the opener is the emote most likely
## to be the first thing a real player reaches for after a win, and `cheer` is
## held back for the end because it is the long one — 24 frames against everyone
## else's 18 — and is therefore the only one with the room to play out and fade
## on camera without the next line stepping on it.
const SCRIPT := [
	["out", "nice"],
	["in", "angry"],
	["out", "hype"],
	["in", "dead"],
	["out", "shock"],
	["in", "cry"],
	["out", "cheer"],
]

## Gap between lines.
##
## Longer than it feels like it needs to be, and the constraint is the cooldown
## rather than the reading. `EMOTE_COOLDOWN` is 2.5s and only the sends spend it,
## so alternating at 2.7 puts 5.4s between one send and the next — clear of it
## with room for the layout to be retuned. Land inside the cooldown and
## `_send_emote` would refuse, which on this recorder means `_say` asserts and
## the take stops rather than silently filming six emotes instead of seven.
##
## It also happens to be the number that shows the cooldown *working*: the row
## dims for 2.5s after each send and comes back for the 2.9 before the next one,
## so the only visible feedback a tap has is on film in both states.
const LINE_EVERY := 2.7

var game: Node
var spent: Dictionary = {}
var _wb: Node
var _profile: Node
## Fetched off the root rather than named directly. Autoload singletons are not
## bound as global identifiers when the engine is entered through `--script`, so
## `Sfx.play(...)` is a compile error here even though it is ordinary code inside
## `game.gd`. Same reason `_wb` and `_profile` are looked up.
var _sfx: Node
var _haptics: Node

var _size := Vector2i(1080, 1920)
var _seed := 0
var _tablet := false
var _split := true
var _t := 0.0
## Frames emitted so far — the recording's own clock. See `_hold`.
var _frames := 0


func _init() -> void:
	_read_args()
	await _step()
	_wb = get_root().get_node("WordBank")
	_profile = get_root().get_node("Profile")
	_sfx = get_root().get_node("Sfx")
	_haptics = get_root().get_node("Haptics")
	if _seed != 0:
		_wb.seed_run(_seed)
		seed(_seed)

	game = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(game)
	await _step()
	await _step()
	game._skip_splash()
	await _step()
	_force_portrait(_size)
	await _step()
	print("[reel] viewport=%s portrait=%s seed=%d" % [
		get_root().content_scale_size, game.portrait, _seed])

	_pose_profile()

	await _scene_match()
	await _scene_over()
	await _scene_row()
	await _scene_talk()
	await _scene_fade()

	print("[reel] total %.2fs (%d frames)" % [_t, _frames])
	quit(0)


## Enough of a match to have been in one.
##
## The row is drawn over a scoreboard, and a scoreboard of zeroes would say the
## feature arrives at the end of nothing. Six seconds is the shortest rally that
## puts a believable number on both sides.
func _scene_match() -> void:
	var t0 := _t
	game.start_match(RIVAL, 1)
	game.phase = game.Phase.PLAY
	game._deal_daily_opening()
	await _play_for(6.0)
	_scene("match", t0)


## The end of it, which is the only door the row is behind.
##
## The rival is knocked out explicitly rather than left to the rally, for the
## reason `trailer.gd` learned the hard way: whoever is still standing decides
## what the summary says, and a take that happened to lose would put the row on a
## defeat screen. Either is a real screen, but a demo should show the one the
## feature was written for.
func _scene_over() -> void:
	var t0 := _t
	var rival: Object = game.ai_side if game.ai_side else game.sides[1]
	rival.lives = 0
	rival.alive = false
	game._end_match(rival)
	# Named after the match is over rather than before it, so the rally above is
	# an ordinary CPU match and only the summary claims a person.
	if game.ai_side:
		game.ai_side.label = THEM
	# Long enough for the score to finish counting up. The row is switched on in
	# the next scene rather than this one so it does not arrive during that.
	await _hold(2.4)
	_scene("over", t0)


## The row, arriving.
##
## `demo_emotes` is what puts it there — see the long note on the flag in
## `game.gd`, and the header above for why the real state it stands in for cannot
## be entered on this machine. Held with nothing said, because seven tiles need
## to read as a set of choices before any one of them is used.
func _scene_row() -> void:
	var t0 := _t
	game.demo_emotes = true
	if not game._summary_emotes_live():
		# The row has four conditions and this recorder can only satisfy three of
		# them by hand. Stopping here is the honest failure: the alternative is
		# thirty seconds of a summary screen with no row on it and markers that
		# claim otherwise.
		push_error("the emote row is not live — phase=%d mode=%d"
			% [int(game.phase), int(game.mode)])
		quit(1)
		return
	print("[reel] row=%s" % [game._summary_emote_rects(
		game.get_viewport_rect().size)])
	await _hold(2.2)
	_scene("row", t0)


## The conversation.
func _scene_talk() -> void:
	var t0 := _t
	for line: Array in SCRIPT:
		if line[0] == "out":
			_say(String(line[1]))
		else:
			_hear(String(line[1]))
		await _hold(LINE_EVERY)
	_scene("talk", t0)


## The last one, played out.
##
## `cheer` is 24 frames at `EMOTE_FPS`, so `_emote_life` on the summary gives it
## three 2.0s loops and a 0.6s fade — 6.6s, and the hold is that plus a moment of
## the row alone afterwards. The fade is the part worth waiting for: it is the
## only thing on this screen that ends by itself, and cutting away before it
## would leave the reel looking like the sticker is still there when the video
## stops.
func _scene_fade() -> void:
	var t0 := _t
	await _hold(game._emote_life(game.EMOTES.find("cheer")) + 1.2)
	game.demo_emotes = false
	game._emote_in = {}
	game._emote_out = {}
	_scene("fade", t0)


## Press one of the row's tiles.
##
## What `_send_emote` does, minus the packet it cannot send and the guard it
## cannot pass. The fields are copied from it rather than paraphrased — `span`
## alongside `left` because `_draw_summary_emote` derives the animation frame
## from the difference between the two, and a bubble missing it would sit on
## frame zero for its whole life.
##
## The sound is fired for the same reason the drawing is real: `record.sh`
## captures the game's own audio, and a demo of a button that makes a noise
## should make the noise.
##
## The hit-test is the part that is not decoration. `_action_at` is the function
## a finger goes through, and asking it what is at the tile centre is the only
## way this script can know the row is still where it thinks it is.
func _say(name: String) -> void:
	var idx: int = game.EMOTES.find(name)
	var slot: int = game.EMOTE_MENU.find(idx)
	assert(slot != -1, "%s is not offered in the row" % name)
	var tiles: Array = game._summary_emote_rects(game.get_viewport_rect().size)
	var tile: Rect2 = tiles[slot]
	var got: String = game._action_at(tile.get_center())
	assert(got == "emote:%d" % idx,
		"the tile for %s answers '%s'" % [name, got])
	# `_send_emote` would refuse inside the cooldown, so a script that lands
	# inside one is a script whose timings have drifted — see `LINE_EVERY`.
	assert(is_zero_approx(game._emote_cool), "%s lands inside the cooldown" % name)

	game._emote_cool = game.EMOTE_COOLDOWN
	var life: float = game._emote_life(idx)
	game._emote_out = {"i": idx, "left": life, "span": life}
	_haptics.fire("power", 0.7)
	_sfx.play("zap", 1.12)
	print("[emote] %.3f out %s tile=%s" % [_t, name, tile])


## The reply.
##
## Straight through `_on_net_emote`, which is the real receiver — it is what the
## dispatcher calls when a packet lands, it has no guard to get past, and using
## it means the incoming half of this video is not staged at all.
func _hear(name: String) -> void:
	var idx: int = game.EMOTES.find(name)
	game._on_net_emote(idx)
	print("[emote] %.3f in %s" % [_t, name])


## Type and fire whole words for `seconds`, logging each one.
##
## Both sides are held alive while the rally plays. The picker is good enough to
## end the match on its own, and an early finish here would hand `_scene_over` a
## summary screen to call `_end_match` on top of — which is how `trailer.gd` once
## got a defeat under a caption about winning.
func _play_for(seconds: float) -> void:
	var until := _t + seconds
	while _t < until:
		for s: Object in game.sides:
			if s.active_slot():
				s.alive = true
				s.lives = maxi(s.lives, 1)
		if game.phase != game.Phase.PLAY:
			game.start_match(RIVAL, 1)
			game.phase = game.Phase.PLAY
			game._deal_daily_opening()
		var word := _pick()
		if word == "":
			# Nothing answerable, which happens right after a big clear. Top the
			# board up rather than film the wait.
			game._deal_daily_opening()
			await _hold(0.12)
			continue
		await _type(word)
		await _hold(THINK)


func _type(word: String) -> void:
	for i in word.length():
		game._press_key(word[i])
		await _hold(KEY_EVERY)
	game._fire_pressed()
	spent[word] = true
	print("[beat] %.3f %s %d" % [_t, word, int(game.player.chain)])


## The longest word on offer for anything on the board.
func _pick() -> String:
	var seen := {}
	var best := ""
	for p in game.player.board.prefixes():
		var pre := String(p)
		if pre == "" or seen.has(pre):
			continue
		seen[pre] = true
		for w in _wb.candidates(pre, 5, 13, spent, 24, AdWords.MAX_RANK):
			var cand := String(w)
			if cand.length() <= best.length():
				continue
			if AdWords.unpostable(cand):
				continue
			best = cand
	return best


## A plausible regular player, written straight into `Profile` and never saved —
## nothing here calls `save()`, so the real save on this machine is untouched.
##
## The premium pack is granted because it is what `Ads.wanted()` asks about, and
## the summary is exactly where a break would fire. On this desktop the stand-in
## is a full-screen mock, and a mock over the screen this video is about would
## cost the whole take.
func _pose_profile() -> void:
	_profile.owned[_profile.PACK_PREMIUM] = true
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


## The marker the cut is driven from, plus the phase the game was actually in
## when the scene ended — the thing that silently goes wrong.
func _scene(name: String, t0: float) -> void:
	print("[scene] %s %.3f %.3f phase=%d" % [name, t0, _t, int(game.phase)])


## See the long note in `adreel.gd`: three ways of asking for a portrait window
## are all ignored under the movie writer, and `_measure_device` decides
## tablet-or-phone from the shape of the *window*, which here is the desktop.
func _force_portrait(want: Vector2i) -> void:
	if get_root().size_changed.is_connected(game._apply_orientation):
		get_root().size_changed.disconnect(game._apply_orientation)
	game.portrait = true
	game.tablet = _tablet
	get_root().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	get_root().content_scale_size = want
	game._measure_safe_area(want)
	if _tablet:
		_profile.prefs["split_keys"] = _split
	game._layout_boards()
	game.queue_redraw()


func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--size":
				if i + 1 < args.size():
					var wh := String(args[i + 1]).split("x")
					if wh.size() == 2:
						_size = Vector2i(int(wh[0]), int(wh[1]))
			"--seed":
				if i + 1 < args.size():
					_seed = int(args[i + 1])
			"--tablet":
				_tablet = true
			"--fullkeys":
				_split = false


## Wait a whole number of frames, and count them. Frames rather than a timer,
## because under `--fixed-fps` the wall clock and the recording's clock are not
## the same thing and only one of them is in the file.
func _hold(seconds: float) -> void:
	var frames := maxi(1, int(round(seconds * FPS)))
	for i in frames:
		await process_frame
	_frames += frames
	_t = float(_frames) / FPS


## One frame, counted.
func _step() -> void:
	await process_frame
	_frames += 1
	_t = float(_frames) / FPS
