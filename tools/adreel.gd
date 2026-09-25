extends SceneTree
## A match that plays itself at 9:16, for cutting social ads out of.
##
## `demoreel.gd` already films a match; this is its louder sibling. Three
## differences, all of them about what an ad needs that a demo does not:
##
## 1. **9:16, not 1:2.** The demo films the phone's own 720x1440. TikTok, Reels
##    and Shorts all want 1080x1920, and letterboxing a 1:2 clip into that
##    leaves pillar bars down both sides of every frame. So the layout is driven
##    at the ad's aspect and fills it.
## 2. **A seed argument.** Five variants cut from one take look like one ad
##    posted five times. Different seeds deal different boards.
## 3. **A beat log.** Every fire prints its timestamp, the word, and the chain it
##    landed on. That is the cut sheet — it says where in the footage the big
##    detonations are, so captions can land on them instead of near them.
##
## ## Recording it
##
## Use `tools/adreel.sh`. It exists because Godot's movie writer takes its output
## size from `display/window/size/viewport_*` in project.godot, read once at
## startup and settable no other way — so something has to edit that file, run
## this, and put it back even if this crashes. Doing that by hand is how a repo
## ends up committed at 1080x1920.
##
##     tools/adreel.sh --seed 7 --seconds 24 --out build/ads/raw/take-7
##
## Everything `demoreel.gd` documents about the recording still applies: expect
## roughly a minute of wall clock per second of footage at this size, and
## `--fixed-fps` means the result is correctly timed however slowly it was made.

## The editorial line for what may appear in footage, shared with `trailer.gd`.
##
## Lives in its own file rather than here because both tools publish frames and
## there is only one policy — see `tools/ad_words.gd` for why it is a rank cap
## and a list rather than just a list.
const AdWords = preload("res://tools/ad_words.gd")

## Roughly 55wpm — quick enough to look competent, slow enough to read. Real
## thumbs land around 36-38, but nobody wants to watch that.
const KEY_EVERY := 0.055
## The beat between firing and starting the next word. Shorter than the demo's
## 0.34: an ad is watched for six seconds and thinking time is not the pitch.
const THINK := 0.22

# ------------------------------------------------------------ playing like one
#
# `--human` swaps the three numbers above and the picker below for ones a person
# could actually produce. It is off by default so the five existing variants keep
# cutting from the footage they were graded against.
#
# ## Why an ad would want to be slower
#
# The default reel is a machine: 55wpm sustained, no hesitation, and `_pick`
# takes the longest word on the board every single turn. That is the right
# footage for a hook test, where the question is whether a *line* works and the
# gameplay is wallpaper. It is the wrong footage for an install, and the reason
# is the same one `trailer.gd` wrote down about the App Preview — a stranger
# reading a board being cleared faster than they can follow does not think
# "impressive", they think "this is not for me", and that is a thought that ends
# in a scroll rather than a download.
#
# The game's own balance notes name the number this is aiming at: it is built
# around "a phone typist at 36-38 wpm", at which "a word is found and fired about
# every three seconds". So that is what these produce — not a guess at what looks
# human, but the speed the game was designed to be played at, which is also the
# speed the viewer will experience if they install it. An ad that shows the real
# thing is the one whose installs stay.

## Per keystroke, once a word has been decided on.
##
## Deliberately not the whole story: this is the *burst* rate of a thumb that
## already knows what it is typing, which is genuinely quick — the slowness in
## real play is in finding the word, not in entering it, and `THINK_BASE` is
## where that lives. Spreading the same three seconds evenly across the letters
## instead would read as somebody typing underwater.
const KEY_HUMAN := 0.17
## The pause before a word — reading the board and recognising something on it.
## Scales with what gets found, because spotting a ten-letter answer genuinely
## takes longer than spotting a five-letter one.
const THINK_BASE := 0.72
const THINK_PER_LETTER := 0.085
## Jitter, so the rhythm is not a metronome. Asymmetric: a person is more often
## a little slower than expected than a little faster.
const THINK_WOBBLE := Vector2(-0.12, 0.20)

## The lengths a person actually finds, as a bag to draw from.
##
## Weighted at six to eight because that is where the answers are on a board of
## four-letter prefixes, with a thin tail either side. Not a bell curve computed
## from anything — a bag of ten is legible, tunable by eye, and exactly as
## defensible as a distribution would be here.
const HUMAN_LEN := [5, 6, 6, 7, 7, 7, 8, 8, 9, 10]
## How often to take the best word on the board instead of a plausible one.
##
## Not zero, and this is the part that keeps the ad watchable. A reel with no big
## hits is honest and dull; a person who finds a twelve-letter word does exist,
## they are simply not that person on every turn. Roughly one turn in five is
## what makes the big ones read as a find rather than as the baseline.
const LONG_SHOT := 0.22
## Garbage cadence for a human take.
##
## Between the default 0.9 and the 1.6 the game's own notes call the hardest the
## daily ever gets, and the number was measured rather than chosen. At 1.6 a
## human picker out-clears the ramp: the first take emptied steadily and by
## twenty seconds the well was five blocks in the bottom corner with two thirds
## of the frame dead grid — true, winnable, and a bad picture. At 1.4 the board
## holds roughly the depth it starts at, which is what somebody scrolling needs
## to see to understand there is anything at stake.
##
## Still slower than the machine reel's 0.9, so this is not the ad leaning on a
## harder game than it is selling — it is the ad being played at something inside
## the range the daily already asks for.
const PRESSURE_HUMAN := 1.4

var game: Node
var spent: Dictionary = {}
## Resolved at runtime, never named at class scope. `--script` compiles this file
## before the autoloads are registered, so a bare `WordBank` here is a compile
## error that takes the whole reel down before a window ever opens.
var _wb: Node

var _size := Vector2i(1080, 1920)
var _seconds := 24.0
var _seed := 0
## `--human`. See the block of constants above for what it changes and why.
var _human := false
## Frames emitted so far. The movie writer writes one per processed frame at a
## fixed rate, so this is the recording's own clock and the only honest source
## for a timestamp in the beat sheet.
var _frames := 0


func _init() -> void:
	_read_args()
	await _step()
	_wb = get_root().get_node("WordBank")
	# Filmed as a premium install, which is what `Ads.wanted()` asks about.
	# Nothing in a sixteen-second take ends a match, so the ad break has never
	# actually fired here — but it fires on a cadence as well as on match end,
	# and the trailer recorder found that out the hard way with a full-screen
	# AdMob mock sitting over its best scene. Written into `owned` rather than
	# through `grant()`, which would persist it into the real save.
	var profile := get_root().get_node("Profile")
	profile.owned[profile.PACK_PREMIUM] = true
	# Before the match is dealt, so the opening pile and every prefix after it
	# come from this seed. Seeding after `start_match` reseeds nothing that is
	# already on the board, which looks like the flag being ignored.
	if _seed != 0:
		_wb.seed_run(_seed)
		seed(_seed)

	game = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(game)
	await _step()
	await _step()

	# Straight past the splash and into a match. The splash is a separate beat
	# with its own treatment in the cut, not two dead seconds at the head of the
	# gameplay clip.
	game._skip_splash()
	await _step()

	_force_portrait(_size)
	await _step()
	# `human` is logged because it is the one setting that cannot be recovered by
	# looking at the file afterwards, and it changes what the footage is for.
	print("[reel] viewport=%s rect=%s portrait=%s seed=%d human=%s" % [
		get_root().content_scale_size, game.get_viewport_rect().size,
		game.portrait, _seed, _human])

	game.start_match("Magpie", 1)
	game.phase = game.Phase.PLAY
	# A match opens on an empty board with the first garbage twenty seconds out,
	# which is twenty seconds of ad with nothing in it and nothing to type at.
	# The daily's opening pile is exactly the fix — a board that already means
	# something on frame one — so it is borrowed wholesale.
	#
	# Three piles, not the demo reel's two. The demo is showing how the game
	# works and a half-empty board is legible; this is showing what it feels
	# like, and the probe take spent its first seconds on four blocks in the
	# bottom corner of an otherwise empty well. The picker always takes the
	# longest word on offer, so it clears faster than any sane ramp refills — the
	# board has to start nearly buried or it never looks like trouble.
	game._deal_daily_opening()
	game._deal_daily_opening()
	game._deal_daily_opening()
	# And keeps coming. The standard ramp is built for a three-minute match; over
	# half a minute of footage it would deal twice.
	game.pressure_interval = PRESSURE_HUMAN if _human else 0.9
	game.pressure_timer = 0.4
	await _step()

	# Where the recording already is when the first key goes down. Beats are
	# printed against this rather than against zero, so a timestamp in the sheet
	# is a timestamp in the file.
	var head := float(_frames) / FPS
	var elapsed := 0.0
	while elapsed < _seconds:
		var word := _pick()
		if word == "":
			# Nothing on the board can be answered, which happens after a big
			# clear: the picker always takes the longest word available, so it
			# empties the board faster than any sane pressure ramp refills it.
			#
			# The demo reel waits here. An ad cannot — waiting is what produced a
			# take with a five-second hole in the middle of it, and the variant
			# cut from that take had nothing on screen for half its runtime. So
			# the board is topped up instead. The match is being staged for
			# footage either way; a pile arriving early is no less honest than a
			# pile arriving on a timer, and it is the difference between footage
			# that is usable end to end and footage that has to be hunted through
			# for a window.
			game._deal_daily_opening()
			elapsed += await _hold(0.12)
			continue
		# Finding it. Before the first keystroke rather than after the last, which
		# is where the pause actually belongs — and it keeps `start` below meaning
		# "the frame a finger moved", which is what `pick_window` opens the ad on.
		if _human:
			elapsed += await _hold(_think_for(word))
		var start := elapsed
		for i in word.length():
			game._press_key(word[i])
			elapsed += await _hold(KEY_HUMAN if _human else KEY_EVERY)
		game._fire_pressed()
		spent[word] = true
		# The cut sheet. `chain` is read after the fire because that is the
		# value the fire just produced — it is the ladder position the hit went
		# out at, and the number that says whether this beat is worth cutting to.
		print("[beat] %.3f %.3f %s %d %d" % [
			start + head, elapsed + head, word, int(game.player.chain),
			word.length()])
		# The machine's flat beat between words. In human mode the gap that
		# matters is the one before the next word, and it is taken up there once
		# that word is known — so this is only the moment after a fire, which is
		# short because the detonation is playing and it is worth watching.
		elapsed += await _hold(0.14 if _human else THINK)

	quit(0)


## Lay the game out for `want` and stop anything putting it back.
##
## Three ways of asking for a portrait window are all ignored under the movie
## writer: `--resolution`, `DisplayServer.window_set_size` and setting the root
## size. The recorder opens at the screen's own size and `_apply_orientation`
## reads the *window*, so the game lays itself out for a desktop while the writer
## — which records the project's viewport, not the window — captures a portrait
## slice of a landscape screen. That slice is the centre column of the HUD and
## nothing else: no board, no keyboard.
##
## So the layout is set directly and the resize hook is unhooked behind it,
## because that hook is the only thing that would undo this.
func _force_portrait(want: Vector2i) -> void:
	if get_root().size_changed.is_connected(game._apply_orientation):
		get_root().size_changed.disconnect(game._apply_orientation)
	game.portrait = true
	# A phone, and say so, because nothing here can work it out.
	#
	# `_measure_device` decides tablet-or-phone from the shape of the *window*,
	# and under the movie writer the window is the desktop — 16:9 landscape,
	# which is emphatically a tablet by that test. So the first take came out in
	# the iPad layout: split keyboard, a third-size board pushed left, and the
	# rival's board drawn full height beside it. All correct, and all the wrong
	# ad — this is a phone game and the footage has to look like a phone.
	#
	# `_kb_form` reads this flag live rather than caching a shape, so clearing it
	# here is the whole fix; the keyboard is back to the phone's form on the next
	# layout pass below.
	game.tablet = false
	# `expand` is the project's stretch aspect and it does exactly that: with a
	# landscape window and a portrait design it widens the viewport and lays the
	# keyboard out across all of it, while the recorder writes the middle — a
	# board correctly centred between a Q and a P that are off both edges.
	# `keep` pins the viewport to the design size instead.
	get_root().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	get_root().content_scale_size = want
	game._measure_safe_area(want)
	game._layout_boards()
	game.queue_redraw()


## `--size WxH`, `--seconds N`, `--seed N`, all optional.
##
## Read off `OS.get_cmdline_user_args`, which is everything after the `--` that
## separates Godot's own flags from the script's. Godot parses the ones before
## it and would reject these.
func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--size":
				if i + 1 < args.size():
					var wh := String(args[i + 1]).split("x")
					if wh.size() == 2:
						_size = Vector2i(int(wh[0]), int(wh[1]))
			"--seconds":
				if i + 1 < args.size():
					_seconds = float(args[i + 1])
			"--seed":
				if i + 1 < args.size():
					_seed = int(args[i + 1])
			"--human":
				_human = true


## The longest word on offer for anything currently on the board.
##
## Longest on purpose: length drives the tier, so the long ones are the ones that
## visibly detonate. A reel of three-letter words would be honest and boring.
func _pick() -> String:
	if _human:
		return _pick_human()
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


## A word somebody could plausibly have spotted, rather than the best one there.
##
## Same candidate sweep as `_pick` and the same editorial filter — the only thing
## that changes is what is done with the pile at the end. `_pick` maximises;
## this draws a length out of `HUMAN_LEN` and takes something at it, which is a
## different selection pressure and the whole point of `--human`.
##
## The nearest *available* length, not the wanted one. A board whose only answers
## are nine letters long gives a nine-letter answer however modest this asked to
## be — refusing to play because the board did not offer a seven would be a
## picker that stalls, and a stall in an ad is a hole in the footage.
func _pick_human() -> String:
	var by_len := {}
	var seen := {}
	for p in game.player.board.prefixes():
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

	# The one they are pleased with. See `LONG_SHOT`.
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


## How long to stare at the board before typing `word`.
##
## Clamped at the bottom because the wobble can otherwise outrun a short word's
## think time and produce a negative pause, which `_hold` would round up to a
## single frame — an instant answer in the middle of a take that is
## specifically about not having instant answers.
func _think_for(word: String) -> float:
	return maxf(0.35, THINK_BASE + THINK_PER_LETTER * float(word.length())
		+ randf_range(THINK_WOBBLE.x, THINK_WOBBLE.y))


## Wait a whole number of frames.
##
## Frames rather than `create_timer(seconds)`, because a timer cannot fire
## between frames and the requested time is not what elapses. At `--fixed-fps 30`
## a frame is 33.3ms, so a 55ms keystroke hold waits two frames and costs 66.7ms
## — a 21% overshoot on every letter. The caller accumulates the *requested*
## times into the beat sheet, so across a take that drift put every beat several
## hundred milliseconds ahead of the frame it claimed to mark, and the captions
## cut against it landed early by a growing margin. `trailer.gd` found this the
## expensive way; see the note on `_hold` there.
##
## Returning the time actually spent, so the caller can add that instead of what
## it asked for.
const FPS := 30.0

func _hold(seconds: float) -> float:
	var frames := maxi(1, int(round(seconds * FPS)))
	for i in frames:
		await process_frame
	_frames += frames
	return float(frames) / FPS


## One frame, counted. Used for the setup awaits before the timing loop starts,
## which are frames the recording contains and the beat sheet would otherwise
## not know about — six of them, and every beat 0.2s early as a result.
func _step() -> void:
	await process_frame
	_frames += 1
