extends SceneTree
## The whole game, played to a script, in one take — for cutting a trailer from.
##
## `adreel.gd` films a match. This films a *story*: the rule, a rally, an
## argument conducted in emotes, a board that gets away from you, a loss, a
## comeback, a win, and the boards you land on afterwards. Twelve scenes, in
## order, in one recording.
##
##     tools/trailer.sh --out build/trailer/raw/take
##
## ## Why one take rather than twelve recordings
##
## Every `--script` run reloads the 350k-word dictionary and boots the whole
## autoload stack, so twelve recordings is twelve of those, plus twelve movie
## files to concatenate and twelve chances for one of them to come back at the
## wrong size. One take is one boot, one file, one timeline — and the cut is
## driven by markers printed as it goes rather than by anybody watching it.
##
## ## The markers are the edit
##
## Two kinds go to stdout:
##
##     [scene] rule 3.00 12.00
##     [beat]  6.42 FRIENDSHIP 3
##
## `[scene]` says where each movement starts and ends, so the cut can find the
## victory screen without anybody scrubbing for it. `[beat]` says the instant a
## word fired and the chain it landed on, so music and captions can hit the
## frame a block actually detonates. Same idea as the ad cut sheet, one level up.
##
## ## What is staged and what is real
##
## Everything on screen is drawn by the game from its own state. The staging is
## in *what state it is put into*: the boards are buried through the same mint
## and place the opening deal uses, the emotes are the same dictionaries the
## network path fills in, the leaderboard rows are injected exactly as
## `shots.gd` injects them, and the match is ended by calling the same
## `_end_match` a real loss calls. Nothing is drawn by hand and nothing is faked
## in the compositor — a trailer that shows a screen the build cannot produce is
## the one kind of trailer that is actually dishonest.
##
## Game Center cannot be reached from Linux, so the leaderboard names below are
## invented. That is the one screen whose *contents* are fiction; the screen
## itself is the real one, built on top of the injected rows.

## The editorial line for what may appear in footage, shared with `adreel.gd`.
const AdWords = preload("res://tools/ad_words.gd")

## Roughly 55wpm. Real thumbs land around 36-38, but nobody wants to watch that.
const KEY_EVERY := 0.055
## Slower for the scene that explains the rule, because that one is being read
## rather than watched — the viewer has to see the last letters land.
const KEY_SLOW := 0.085
const THINK := 0.24

var game: Node
var spent: Dictionary = {}
var _wb: Node
var _boards: Node
var _profile: Node

var _size := Vector2i(1080, 1920)
var _seed := 0
## `--preview` runs the short arc instead of the twelve-scene one. See
## `_run_preview` for what an App Preview is allowed to be.
var _preview := false
## Who the scenes play against. Magpie in the trailer, which is the roster's
## show-off — every word a mouthful — and exactly right for footage that is
## about to be cut and captioned.
##
## The preview needs the opposite. Magpie types long words slowly, so it does
## not clear its own board fast enough to drain what is being sent to it, and
## twenty seconds of that is a rail of undelivered blocks stacked down the
## screen. Duelist answers at a rate that makes the exchange look like an
## exchange, which is the only thing the rally scene is there to show.
var _rival := "Magpie"
## `--tablet` records the iPad layout, `--fullkeys` the non-split keyboard.
var _tablet := false
var _split := true
var _t := 0.0
## Frames emitted so far — the recording's own clock. See `_hold`.
var _frames := 0


func _init() -> void:
	_read_args()
	await _step()
	_wb = get_root().get_node("WordBank")
	_boards = get_root().get_node("Boards")
	_profile = get_root().get_node("Profile")
	# Saved somewhere of its own. `_pose_profile` writes an invented player's
	# record into the live profile, and the first save after it — the end of any
	# match — wrote that player over the real one on this machine.
	_profile.save_path = "user://profile-trailer.cfg"
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

	# The same invented player on every screen that shows one, so the title card
	# and the mastery card cannot disagree about what level this person is.
	_pose_profile()

	if _preview:
		await _run_preview()
	else:
		await _scene_title()
		await _scene_rule()
		await _scene_rally()
		await _scene_emotes()
		await _scene_chaos()
		await _scene_danger()
		await _scene_defeat()
		await _scene_comeback()
		await _scene_victory()
		await _scene_boards()
		await _scene_mastery()
		await _scene_endcard()

	print("[reel] total %.2fs (%d frames)" % [_t, _frames])
	quit(0)


## The App Preview arc.
##
## Apple allows 15 to 30 seconds and plays it muted and auto-starting in the
## first slot of the store listing, to somebody who has not decided to watch
## anything. So it has two seconds to be worth watching, and the rest of it to
## make the game make sense.
##
## The first version of this taught the rule first and slowly, on the default
## board, and ended on a summary screen — correct and lifeless. Three things
## changed, and each is the answer to a reason it felt dry:
##
##   * **It opens on impact.** A rally already running, a chain already high,
##     a big word landing in the first second. The rule comes second, once
##     somebody is watching.
##   * **Every scene is on a different painted board.** The paintings and their
##     weather are the best-looking thing in the game and the old footage never
##     showed one. A board changing at a scene boundary reads as a cut, which
##     buys the pace of an edit without cutting the take's audio.
##   * **There is somebody on the other side.** The rally carries an exchange of
##     emotes with a named rival, so the match reads as between people.
##
## No title card and no end card: the store draws the name, the icon and the
## price around the video already.
##
##   hook    Volcano   a chain already running, big hits straight away
##   rule    Space     one slow word, its tail landing on their board
##   rally   Clouds    trading at speed, emotes flying both ways
##   danger  Cyber     one life, the stack at the ceiling, the screen red
##   win     Forest    the answer to it, and the win
const PREVIEW_BOARDS := {
	"hook": "volcano", "rule": "space", "rally": "clouds",
	"danger": "cyber", "win": "forest",
}


func _run_preview() -> void:
	await _preview_hook()
	await _preview_rule()
	await _preview_rally()
	await _preview_danger()
	await _preview_win()


## Put a board on, with the block face drawn for it — the pairing the set was
## painted as, the same one `boardshots.gd` uses.
func _wear(id: String) -> void:
	_profile.equipped["theme"] = id
	var face := Cosmetics.face_for_board(id)
	_profile.equipped["blocks"] = face if face != "" else "solid"
	game._apply_theme()


## A fresh match on `board`, with an opening pile to answer.
func _fresh(board: String) -> void:
	_wear(board)
	spent.clear()
	game.start_match(_rival, 1)
	game.phase = game.Phase.PLAY
	game._deal_daily_opening()
	# Named from the first frame. A chip that reads CPU for two scenes and PRIYA
	# from the third is two different opponents to anybody watching.
	if game.ai_side:
		game.ai_side.label = "PRIYA"
	# And past its first word. Each scene is a fresh match, and a fresh match
	# teaches — "TYPE ANY WORD" over the middle of the board, under the caption.
	game.player.words_played = 1
	game._first_word_fade = 0.0


func _preview_hook() -> void:
	var t0 := _t
	_fresh(PREVIEW_BOARDS["hook"])
	# Already deep into a chain, so the very first word lands as a big hit —
	# the frame a scroller stops on.
	game.player.chain = 7
	game.player.chain_fill = 0.8
	game.pressure_interval = 1.4
	game.pressure_timer = 1.0
	await _play_for(2.6, KEY_EVERY, 0.14)
	_scene("hook", t0)


func _preview_rule() -> void:
	var t0 := _t
	_fresh(PREVIEW_BOARDS["rule"])
	game.pressure_interval = 3.2
	game.pressure_timer = 3.0
	await _hold(0.3)
	await _type_one(KEY_SLOW)
	await _hold(1.0)
	await _type_one(KEY_SLOW)
	await _hold(0.8)
	_scene("rule", t0)


func _preview_rally() -> void:
	var t0 := _t
	_fresh(PREVIEW_BOARDS["rally"])
	game.pressure_interval = 1.1
	game.pressure_timer = 0.6
	game.demo_emotes = true
	if game.ai_side:
		game.ai_side.label = "PRIYA"
	await _play_for(1.4, KEY_SLOW, 0.5)
	# One each way: a jab and the answer to it. Two is a conversation; four was
	# a scene of its own, which this format has no room for.
	for step: Array in [["in", "angry"], ["out", "hype"]]:
		var idx: int = game.EMOTES.find(step[1])
		if step[0] == "out":
			game._emote_out = {"i": idx, "left": game.EMOTE_SHOW}
		else:
			game._emote_in = {"i": idx, "left": game.EMOTE_SHOW}
		print("[emote] %.3f %s %s" % [_t, step[0], step[1]])
		await _play_for(2.3, KEY_SLOW, 0.5)
	game.demo_emotes = false
	game._emote_in = {}
	game._emote_out = {}
	_scene("rally", t0)


func _preview_danger() -> void:
	var t0 := _t
	_fresh(PREVIEW_BOARDS["danger"])
	if game.ai_side:
		game.ai_side.label = "PRIYA"
	_bury(9)
	game.player.lives = 1
	game.pressure_interval = 0.6
	await _play_for(4.2, KEY_SLOW, 0.35)
	_scene("danger", t0)


func _preview_win() -> void:
	var t0 := _t
	_fresh(PREVIEW_BOARDS["win"])
	if game.ai_side:
		game.ai_side.label = "PRIYA"
	game.player.chain = 5
	game.pressure_interval = 1.2
	await _play_for(3.2, KEY_EVERY, 0.22)
	var rival: Object = game.ai_side if game.ai_side else game.sides[1]
	rival.lives = 0
	rival.alive = false
	game._end_match(rival)
	await _hold(3.0)
	_scene("win", t0)


## The rally, cut to preview length.
##
## `_scene_rally` plays for nine seconds, which is right in a trailer that has
## fifty to spend. Eight is the number here, and it is chosen by subtraction
## rather than by taste: the other three scenes are fixed at about fourteen
## seconds between them, Apple's ceiling is thirty, and this is the only scene
## with give in it — its job is rhythm rather than information, so it is the one
## that can be any length at all.
##
## Eight puts the whole preview at about twenty-two seconds, which leaves room
## under the ceiling for the other three to drift as the game is tuned without
## anybody having to re-measure this. Measure it anyway: the script prints
## `[reel] total` at the end, and a preview over thirty seconds is rejected on
## upload rather than trimmed.
##
## ## And why it is typed slower than the trailer is
##
## The first render of this was unusable and it is worth writing down why,
## because the footage did not look fast, it looked broken.
##
## `KEY_EVERY` is 55ms a keystroke and `_pick` always returns the longest
## answer on the board, which together is about 73wpm sustained with no
## mistakes on nothing but nine-letter words. The game is balanced against a
## phone typist at 36-38. So the SENT rail filled faster than any opponent could
## drain it — thirteen chips stacked down the middle of the screen, "26
## incoming" on the rival's chip, and two score pops drawn on top of each other
## because a second word landed before the first had finished animating.
##
## A trailer can carry that: it is cut, captioned, and watched by somebody who
## has chosen to watch it. An App Preview is the whole video, autoplaying and
## muted next to the install button, and a stranger reading that frame does not
## think "fast", they think "this is buggy".
##
## `KEY_SLOW` with a longer pause between words is about 45wpm, which is brisk
## and human, halves the send rate, and leaves the rails short enough to read as
## what they are.
func _scene_rally_short() -> void:
	var t0 := _t
	game._deal_daily_opening()
	game.pressure_interval = 1.1
	game.pressure_timer = 0.6
	await _play_for(8.0, KEY_SLOW, 0.55)
	_scene("rally", t0)


# --- the scenes -----------------------------------------------------------


## The front door, held long enough to read the name.
func _scene_title() -> void:
	var t0 := _t
	game.phase = game.Phase.TITLE
	await _hold(2.6)
	_scene("title", t0)


## The rule, at reading speed.
##
## One long word, typed slowly enough to watch its tail arrive, against a board
## with enough on it to have somewhere to land. This is the only scene in the
## trailer whose job is comprehension rather than feeling, and it is early
## because nothing after it means anything until the viewer has this.
func _scene_rule() -> void:
	var t0 := _t
	game.start_match(_rival, 1)
	game.phase = game.Phase.PLAY
	game._deal_daily_opening()
	# Slow enough that the first blocks are not already raining in while the
	# viewer is still working out what a stamp is.
	game.pressure_interval = 3.2
	game.pressure_timer = 3.0
	await _hold(0.5)
	await _type_one(KEY_SLOW)
	await _hold(1.1)
	await _type_one(KEY_SLOW)
	await _hold(1.0)
	_scene("rule", t0)


## Trading at speed, chains climbing. The rule, now that it is understood.
func _scene_rally() -> void:
	var t0 := _t
	game._deal_daily_opening()
	game.pressure_interval = 1.1
	game.pressure_timer = 0.6
	await _play_for(9.0)
	_scene("rally", t0)


## The argument.
##
## Emotes are a *versus* feature — there is nobody to talk to in a CPU match, and
## `_send_emote` says so by refusing outside a live match. Two consequences for
## this scene, and both of them are about not lying:
##
## `demo_emotes` is set so the real emote UI draws, because on Linux the state it
## normally needs cannot be entered at all. See the long note on that flag in
## `game.gd`. The bubble dictionaries are then filled exactly as the network path
## fills them on the far side of the wire, so what is filmed is the game's own
## widget with the game's own art in it.
##
## And the rival is given a name. Left as CPU, this scene would show somebody
## trading emotes with a bot, which is a thing the game does not do — the caption
## over it in the cut says versus, and the board underneath it should agree.
##
## Four in sequence, alternating, because one emote is a button and four is a
## conversation. The fan is opened first so the nine faces are seen as a set
## before any of them is used.
func _scene_emotes() -> void:
	var t0 := _t
	game.demo_emotes = true
	if game.ai_side:
		game.ai_side.label = "PRIYA"

	# The picker, held open long enough to read.
	game._emote_open = true
	await _play_for(1.6)
	game._emote_open = false

	var script := [
		["out", "nice"], ["in", "angry"], ["out", "hype"], ["in", "dead"]]
	for step: Array in script:
		var idx: int = game.EMOTES.find(step[1])
		if step[0] == "out":
			game._emote_out = {"i": idx, "left": game.EMOTE_SHOW}
		else:
			game._emote_in = {"i": idx, "left": game.EMOTE_SHOW}
		print("[emote] %.3f %s %s" % [_t, step[0], step[1]])
		# Kept playing underneath. An emote scene where the typing stops reads
		# as a menu, not as somebody talking while they work.
		await _play_for(1.9)

	# Cleared behind us, so the scenes after this are a plain CPU match again.
	game.demo_emotes = false
	game._emote_in = {}
	game._emote_out = {}
	if game.ai_side:
		game.ai_side.label = "CPU"
	_scene("emotes", t0)


## It gets away from everybody. Pressure at its hardest and the board filling
## faster than it clears.
func _scene_chaos() -> void:
	var t0 := _t
	game.pressure_interval = 0.55
	game.pressure_timer = 0.3
	_bury(4)
	await _play_for(7.5)
	_scene("chaos", t0)


## One life left and the stack near the ceiling, which is where the game turns
## the screen red on its own.
func _scene_danger() -> void:
	var t0 := _t
	_bury(9)
	game.player.lives = 1
	game.pressure_interval = 0.5
	await _play_for(4.6)
	_scene("danger", t0)


## Losing, shown rather than implied.
##
## A trailer that only shows the win is selling a game nobody can lose, which is
## the same as selling one nobody can win. `_end_match(player)` is the call a
## real defeat makes, so this is the real screen with the real numbers on it.
func _scene_defeat() -> void:
	var t0 := _t
	# Knocked out first, and only then reported.
	#
	# `_end_match` names a winner by asking who is still standing rather than by
	# trusting the side handed to it — so calling it with the player as loser,
	# while the player is still alive, does not produce a loss. It produced YOU
	# WIN, because by this point in the take the CPU had genuinely been knocked
	# out during the chaos scene and was the only side not standing.
	#
	# So the state has to be true before the call: no lives, not alive, which is
	# exactly what the real path at `side.alive = false` leaves behind.
	game.player.lives = 0
	game.player.alive = false
	game._end_match(game.player)
	await _hold(3.0)
	_scene("defeat", t0)


## The answer to it. A fresh board, a clean run, and the chain allowed to climb.
func _scene_comeback() -> void:
	var t0 := _t
	spent.clear()
	game.start_match(_rival, 1)
	game.phase = game.Phase.PLAY
	game._deal_daily_opening()
	game._deal_daily_opening()
	game.pressure_interval = 1.0
	game.pressure_timer = 0.5
	await _play_for(8.5)
	_scene("comeback", t0)


## Winning. `_end_match(ai_side)` leaves the last board standing as yours, which
## is what makes the screen say YOU rather than CPU.
func _scene_victory() -> void:
	var t0 := _t
	# Explicit for the same reason as the defeat scene: the winner is decided by
	# who is left standing, so the rival has to actually be out. Relying on the
	# match having gone that way on its own is how the last cut got a win where
	# it wanted a loss.
	var rival: Object = game.ai_side if game.ai_side else game.sides[1]
	rival.lives = 0
	rival.alive = false
	game._end_match(rival)
	await _hold(3.6)
	_scene("victory", t0)


## Where that score puts you. Injected, because Game Center cannot be reached
## from Linux and the plugin is a stub that refuses to instantiate.
##
## Mid-table on purpose. A trailer that shows the player at rank 1 is showing a
## screen almost nobody will ever see; rank 118 of 9,120 with the climb visible
## above it is the screen this is actually for.
func _scene_boards() -> void:
	var t0 := _t
	var names := ["quickfinger", "Adaeze", "typo_dynamo", "M. Okonkwo",
		"stampcollector", "wordsmith_99", "Priya R", "eleven letters",
		"BLOQHEAD", "chainbreaker", "Tomas V", "suffixation"]
	var rows: Array = []
	var top := 48210
	for i in names.size():
		rows.append({"rank": i + 1, "name": names[i],
			"score": top - i * 1180 - (i * i * 40), "me": false})
	_boards.view_rows = rows
	_boards.view_me = {"rank": 118, "name": "you", "score": 24630, "me": true}
	_boards.view_total = 9120
	_boards.view_board = _boards.DAILY_ID
	_boards.view_scope = _boards.GLOBAL
	_boards.view_state = _boards.ViewState.READY
	game.phase = game.Phase.BOARDS
	_boards.view_changed.emit()
	await _hold(3.4)
	_scene("boards", t0)


## What all of it adds up to.
func _scene_mastery() -> void:
	var t0 := _t
	game.phase = game.Phase.MASTERY
	await _hold(3.0)
	_scene("mastery", t0)


## Back to the front door, for the card to sit on.
func _scene_endcard() -> void:
	var t0 := _t
	game.phase = game.Phase.TITLE
	await _hold(3.0)
	_scene("endcard", t0)


# --- driving --------------------------------------------------------------


## Type and fire whole words for `seconds`, logging each one.
##
## Nothing here is allowed to end the match. The picker is good enough to knock
## the CPU out partway through a take on its own, and when it did, the summary
## screen came up during the chaos scene — so the scripted defeat two scenes
## later called `_end_match` on a match that had already finished and the trailer
## showed YOU WIN over the caption about losing.
##
## Both sides are therefore held alive with at least one life while a scene is
## playing, which makes `_scene_defeat` and `_scene_victory` the only two places
## a match can end. Topping out still costs a life and still blows the board
## apart — the life just never reaches zero unsupervised.
## `rate` and `think` default to the trailer's own pace so nothing about the
## twelve-scene take changes. The preview passes slower ones — see
## `_scene_rally_short` for why a store preview cannot be typed at trailer
## speed.
func _play_for(seconds: float, rate := KEY_EVERY, think := THINK) -> void:
	var until := _t + seconds
	while _t < until:
		for s: Object in game.sides:
			if s.active_slot():
				s.alive = true
				s.lives = maxi(s.lives, 1)
		# And if something ended it anyway, deal a fresh one rather than typing
		# into a summary screen for the rest of the scene.
		if game.phase != game.Phase.PLAY:
			game.start_match(_rival, 1)
			game.phase = game.Phase.PLAY
			game._deal_daily_opening()
		var word := _pick()
		if word == "":
			# Nothing answerable, which happens right after a big clear. Top the
			# board up rather than film the wait — see the long note in
			# `adreel.gd` for why this is a top-up and not a pause.
			game._deal_daily_opening()
			await _hold(0.12)
			continue
		await _type(word, rate)
		await _hold(think)


## One word at whatever speed, chosen off the board.
func _type_one(rate: float) -> void:
	var word := _pick()
	if word == "":
		game._deal_daily_opening()
		await _hold(0.2)
		word = _pick()
	if word != "":
		await _type(word, rate)


func _type(word: String, rate: float) -> void:
	for i in word.length():
		game._press_key(word[i])
		await _hold(rate)
	game._fire_pressed()
	spent[word] = true
	print("[beat] %.3f %s %d" % [_t, word, int(game.player.chain)])


## The longest word on offer for anything on the board.
##
## Longest on purpose: length drives the tier, so the long ones are the ones
## that visibly detonate. A trailer of three-letter words would be honest and
## boring.
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


## Put `n` more blocks on the board, through the same mint-and-place pair the
## opening deal uses — so the stamps obey the same fairness rules and the sizes
## are sizes the game can actually produce. Lifted from `shots.gd`, which needed
## it for the same reason: `_deal_daily_opening` fills *up to* a fraction, so
## calling it again is a no-op once the board is already past that mark.
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


## A plausible regular player: more matches than wins, a daily streak that
## exists, a survival best that took some doing. Written straight into `Profile`
## and never saved — nothing here calls `save()`, so the real save on this
## machine is untouched.
##
## The premium pack is granted for one reason: it is what `Ads.wanted()` asks
## about. Without it the ad break fires on its own cadence partway through the
## take, and the desktop stand-in is a full-screen mock — the first cut had a
## Google AdMob placeholder sitting over the whole danger scene. Filming as a
## premium install is not a dodge; it is a real state of the build, and it is
## the one the trailer should be showing anyway.
##
## `owned` is written rather than `grant()` called, because `grant` persists and
## this must not touch the save on this machine.
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
## when the scene ended.
##
## The phase is logged because it is the thing that silently went wrong: the
## defeat scene called `_end_match` and the recording still showed a playfield,
## and there was no way to tell from the markers alone whether the call had not
## happened, had not taken, or had been undone. A number in the log answers that
## without re-recording anything.
func _scene(name: String, t0: float) -> void:
	print("[scene] %s %.3f %.3f phase=%d" % [name, t0, _t, int(game.phase)])


## See the long note in `adreel.gd`: three ways of asking for a portrait window
## are all ignored under the movie writer, and `_measure_device` decides
## tablet-or-phone from the shape of the *window*, which here is the desktop.
func _force_portrait(want: Vector2i) -> void:
	if get_root().size_changed.is_connected(game._apply_orientation):
		get_root().size_changed.disconnect(game._apply_orientation)
	game.portrait = true
	# Phone unless asked otherwise. `_measure_device` decides tablet-or-phone
	# from the shape of the window, and under the movie writer the window is the
	# desktop — 16:9 landscape, which is emphatically a tablet by that test — so
	# left alone every take came out in the iPad layout. `--tablet` is how an
	# App Preview for the iPad asks for the thing that is otherwise a bug.
	game.tablet = _tablet
	get_root().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	get_root().content_scale_size = want
	game._measure_safe_area(want)
	# The tablet layout puts the rivals down the right-hand side and reads the
	# split-keyboard preference to decide which keyboard to draw. Neither is
	# touched by `_measure_safe_area`, so both are set here rather than left to
	# whatever the dev profile on this machine happens to say.
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
			"--preview":
				_preview = true
				# Set with the mode rather than left to a flag somebody has to
				# remember. See `_rival`: the trailer's opponent is the wrong
				# one for a preview, and getting it wrong costs a re-render.
				_rival = "Duelist"
			"--tablet":
				_tablet = true
			"--fullkeys":
				_split = false


## Wait a whole number of frames, and count them.
##
## Frames rather than `create_timer(seconds)`, because a timer cannot fire
## between frames and the requested time is not what elapses. At `--fixed-fps 30`
## a frame is 33.3ms, so a 55ms keystroke hold waits 1.65 frames — meaning two —
## and costs 66.7ms. That is a 21% overshoot on every letter typed, and across a
## take of five hundred keystrokes it put the recording 13% longer than the
## clock the markers were written against: the script said the defeat screen
## began at 40.3s and in the file it began at 46. Every caption in the cut was
## timed against a timeline that did not exist.
##
## Counting frames removes the question. The movie writer emits exactly one
## frame per processed frame at a fixed rate, so a hold measured in frames *is*
## the footage's own clock, and `_t` is a timestamp the edit can trust. Holds are
## quantised to 1/30s as a side effect, which is what a 30fps recording can
## represent anyway.
const FPS := 30.0

func _hold(seconds: float) -> void:
	var frames := maxi(1, int(round(seconds * FPS)))
	for i in frames:
		await process_frame
	_frames += frames
	_t = float(_frames) / FPS


## One frame, counted. Used for the setup awaits before the first scene, which
## are frames the recording contains and the markers would otherwise not know
## about.
func _step() -> void:
	await process_frame
	_frames += 1
	_t = float(_frames) / FPS
