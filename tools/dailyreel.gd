extends SceneTree
## A full daily run, played at a person's pace, for posting.
##
##     tools/dailyreel.sh                          # today's board
##     tools/dailyreel.sh --date 2026-09-27        # the board for the day you post
##     tools/dailyreel.sh --date 2026-09-27 --no-typos --board ember
##
## The real daily, not a staged match: the date's own seed, the 3-2-1, the
## 75-second clock, the pressure ramp the daily uses, and the summary it ends
## on. Everyone who opens the game on that date gets exactly this board, so the
## footage can say "play today's daily" and mean it.
##
## ## Played like a person
##
## `adreel.gd --human` worked out what a phone player looks like, and this
## reuses its numbers: about 36 wpm, a pause to find each word that grows with
## the word, mostly six-to-eight-letter answers with the odd long one. On top
## of that, taps go through the same path a thumb does (the key dips and its
## letter pops up above it), and now and then a letter lands on its neighbour
## and gets deleted, because a run with no mistyping at all reads as a bot.
##
## The score it ends on is this script's, not yours. Say so, or record your own
## run on your phone, before putting a number from it in a caption.
##
## ## What it does not touch
##
## Your real profile. A finished daily is banked and saved, so the save path
## is redirected before anything else happens, and the run is played on a
## clean slate (no earlier dailies, no share card owed) so nothing but the
## board shows up in the footage.

const AdWords = preload("res://tools/ad_words.gd")

## From `adreel.gd`'s `--human` block, where each is argued for.
const KEY_HUMAN := 0.17
const THINK_BASE := 0.72
const THINK_PER_LETTER := 0.085
const THINK_WOBBLE := Vector2(-0.12, 0.20)
const HUMAN_LEN := [5, 6, 6, 7, 7, 7, 8, 8, 9, 10]
const LONG_SHOT := 0.22

## How often a word gets one wrong letter that is then deleted.
const TYPO_CHANCE := 0.12
## Keys that sit next to each other, for a believable miss.
const NEIGHBOURS := {
	"q": "wa", "w": "qes", "e": "wrd", "r": "etf", "t": "ryg", "y": "tuh",
	"u": "yij", "i": "uok", "o": "ipl", "p": "ol", "a": "qsz", "s": "adwx",
	"d": "sfe", "f": "dgr", "g": "fht", "h": "gjy", "j": "hku", "k": "jli",
	"l": "ko", "z": "xa", "x": "zcs", "c": "xvd", "v": "cbf", "b": "vng",
	"n": "bmh", "m": "nj",
}
## Common openings to fire at when nothing on the board can be answered. The
## tutorial's own advice: you never have to wait for blocks, every word is an
## attack.
const OPENERS := ["st", "pr", "co", "re", "ca", "ma", "br", "tr", "pl", "sh"]

const FPS := 30.0

var game: Node
var spent: Dictionary = {}
var _wb: Node
var _size := Vector2i(1080, 1920)
var _date := ""
var _board := "midnight"
var _typos := true
## Seconds to stay on the summary once the run is over.
var _tail := 7.0
var _frames := 0


func _init() -> void:
	_read_args()
	await _step()
	_wb = get_root().get_node("WordBank")
	var profile := get_root().get_node("Profile")
	# First, before anything can save: see the note at the top.
	profile.save_path = "user://profile-dailyreel.cfg"
	# No ad break at the end of the run, and no Premium pitch over the summary.
	profile.owned[profile.PACK_PREMIUM] = true
	profile.daily = {}
	profile.daily_best = 0
	profile.prefs["share_promo_seen"] = 99
	profile.prefs["share_promo_day"] = _date
	profile.equipped["theme"] = _board
	profile.equipped["blocks"] = "solid"
	# The picker's choices, not the board: the board comes from the date.
	seed(hash("dailyreel-" + _date))

	game = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(game)
	await _step()
	await _step()
	game._skip_splash()
	await _step()
	_force_portrait(_size)
	game.daily_key_override = _date
	game._apply_theme()
	await _step()
	print("[reel] daily %s seed=%d board=%s typos=%s size=%s" % [
		_date, game.daily_seed(), _board, _typos, _size])

	game.start_match("Daily", 0, [], game.Mode.DAILY)
	while game.phase == game.Phase.COUNTDOWN:
		await _hold(1.0 / FPS)

	var words := 0
	while game.phase == game.Phase.PLAY:
		var word := _pick()
		if word == "":
			await _hold(0.2)
			continue
		await _hold(_think_for(word))
		if game.phase != game.Phase.PLAY:
			break
		if not await _type(word):
			break
		game._fire_pressed()
		spent[word] = true
		words += 1
		print("[beat] %.2f %s chain=%d score=%d" % [
			float(_frames) / FPS, word, int(game.player.chain), int(game.player.score)])
		await _hold(0.14)

	print("[reel] over after %d words, score %d, %d wpm" % [
		words, int(game.player.score), int(round(game._wpm()))])
	await _hold(_tail)
	quit(0)


## Type `word` a key at a time, sometimes fumbling a letter and fixing it.
## False if the run ended partway through.
func _type(word: String) -> bool:
	var slip := -1
	if _typos and word.length() > 4 and randf() < TYPO_CHANCE:
		slip = randi_range(1, word.length() - 2)
	for i in word.length():
		if game.phase != game.Phase.PLAY:
			return false
		if i == slip:
			var near := String(NEIGHBOURS.get(word[i], ""))
			if near != "":
				await _tap(near[randi() % near.length()])
				# Noticing it takes a moment longer than typing it did.
				await _hold(0.22)
				await _tap("back")
		await _tap(word[i])
	return game.phase == game.Phase.PLAY


## One key, the way a thumb presses it: the key goes down, its letter pops up
## above it, and it comes back up when the finger lifts.
func _tap(id: String) -> void:
	game._keys_down[0] = id
	game._pop_key(id)
	game._press_key(id)
	await _hold(KEY_HUMAN * randf_range(0.8, 1.25))
	game._keys_down.erase(0)


## A word somebody could plausibly have spotted. See `adreel.gd`'s
## `_pick_human`, which this follows.
func _pick() -> String:
	var by_len := {}
	var seen := {}
	var prefixes: Array = game.player.board.prefixes()
	if prefixes.is_empty():
		prefixes = [OPENERS[randi() % OPENERS.size()]]
	for p in prefixes:
		var pre := String(p)
		if pre == "" or seen.has(pre):
			continue
		seen[pre] = true
		for w in _wb.candidates(pre, 5, 13, spent, 24, AdWords.MAX_RANK):
			var cand := String(w)
			if AdWords.unpostable(cand):
				continue
			var n := cand.length()
			if not by_len.has(n):
				by_len[n] = []
			(by_len[n] as Array).append(cand)
	if by_len.is_empty():
		return ""
	var lens: Array = by_len.keys()
	lens.sort()
	if randf() < LONG_SHOT:
		var top: Array = by_len[lens[lens.size() - 1]]
		return String(top[randi() % top.size()])
	var want: int = HUMAN_LEN[randi() % HUMAN_LEN.size()]
	var near: int = lens[0]
	for n: int in lens:
		if absi(n - want) < absi(near - want):
			near = n
	var pool: Array = by_len[near]
	return String(pool[randi() % pool.size()])


func _think_for(word: String) -> float:
	return maxf(0.35, THINK_BASE + THINK_PER_LETTER * float(word.length())
		+ randf_range(THINK_WOBBLE.x, THINK_WOBBLE.y))


## The phone layout at `want`, with the resize hook unhooked so nothing puts the
## desktop layout back. Why each line is needed is written up in `adreel.gd`.
func _force_portrait(want: Vector2i) -> void:
	if get_root().size_changed.is_connected(game._apply_orientation):
		get_root().size_changed.disconnect(game._apply_orientation)
	game.portrait = true
	game.tablet = false
	get_root().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	get_root().content_scale_size = want
	game._measure_safe_area(want)
	game._layout_boards()
	game.queue_redraw()


## `--size WxH`, `--date YYYY-MM-DD` (default today), `--board <theme>`,
## `--no-typos`, `--tail <seconds>`.
func _read_args() -> void:
	var d := Time.get_datetime_dict_from_system(false)
	_date = "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		var nxt := String(args[i + 1]) if i + 1 < args.size() else ""
		match args[i]:
			"--size":
				var wh := nxt.split("x")
				if wh.size() == 2:
					_size = Vector2i(int(wh[0]), int(wh[1]))
			"--date":
				_date = nxt
			"--board":
				_board = nxt
			"--no-typos":
				_typos = false
			"--tail":
				_tail = float(nxt)


## Whole frames, so the recording's clock is the one being counted. See
## `adreel.gd`'s `_hold` for why a timer is not good enough here.
func _hold(seconds: float) -> float:
	var frames := maxi(1, int(round(seconds * FPS)))
	for i in frames:
		await process_frame
	_frames += frames
	return float(frames) / FPS


func _step() -> void:
	await process_frame
	_frames += 1
