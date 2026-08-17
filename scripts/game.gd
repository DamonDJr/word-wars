extends Node2D
## Word Wars — match director.
##
## Rules in one breath: type a real word. Any block on your board whose stamp
## opens that word is destroyed. Whatever attack power is left over first cancels
## garbage already inbound at you, then the remainder is stamped with the LAST
## letters of your word and dropped on your opponent — your tail becomes the head
## they have to answer with.
##
## Block size comes from RHYTHM, not vocabulary: keep firing without letting the
## chain lapse and every hit lands bigger. Word length buys you nothing directly,
## it only earns you more time for the next link. Stamp length is independent of
## block size, so a 4x3 can perfectly well say A.

## The two design spaces. One build serves both: the window is measured and the
## content scale swapped, rather than a separate mobile project that would have
## to be kept in step with this one forever.
##
## Portrait is 720x1440 — a clean 1:2 that sits within a couple of percent of
## every modern phone, so the letterboxing is a few pixels rather than a band.
const LANDSCAPE_SIZE := Vector2i(1280, 720)
const PORTRAIT_SIZE := Vector2i(720, 1440)

## Up to four boards at once: yours full size on the left, the rest shrunk into a
## row on the right. Their boards are scaled by the node transform rather than by
## a second set of drawing code, so everything on them keeps working.
const SLOTS := 4
const BOARD_MARGIN_X := 120.0
## Portrait puts the rival strip and the clock above the board, and the keyboard
## below it. This is the one number the whole phone layout hangs off.
const PORTRAIT_BOARD_TOP := 208.0
const BOARD_TOP := 130.0
const RIVAL_SCALE := 0.55
const RIVAL_TOP := 196.0
const RIVAL_X := [0.0, 662.0, 854.0, 1046.0]
const CHIP_W := 82.0
const CHIP_H := 34.0
const CHIP_GAP := 6.0

const MIN_WORD_LEN := 3
## A stamp must have this many answers in the full dictionary, and this many in
## the common list. Tuned so a stamp reaches 3-4 letters as often as English
## allows while still leaving both sides something they can actually type.
const STAMP_MIN_VALID := 40
const STAMP_MIN_COMMON := 6
## How many recent stamps stay "spent". English endings cluster hard, so without
## this every board fills up with ING and LY.
const RECENT_STAMP_MEMORY := 8
const DROP_DELAY := 2.8
const PRESSURE_START := 22.0
const PRESSURE_MIN := 8.0
const PRESSURE_STEP := 1.5

## Block shapes by tier. Which one you send is decided by your chain, never by
## how long the word was.
const TIERS := [
	{"w": 1, "h": 1},
	{"w": 2, "h": 1},
	{"w": 2, "h": 2},
	{"w": 3, "h": 2},
	{"w": 3, "h": 3},
	{"w": 4, "h": 3},
]

## Every block aims for the same stamp length regardless of size — a 1x1 can
## carry SHIP and a 4x3 can carry A. What you get is whatever the word's tail
## can fairly support.
const STAMP_WANT := 4

## Chain length needed for each tier. The early steps come quickly so a short
## run still feels rewarding, then it stretches: the 4x3 wants nine clean words
## in a row. Combos stack on top, so a big clear mid-run is the shortcut.
const CHAIN_TIER_AT := [1, 2, 3, 5, 7, 9]

## What one word is worth to that ladder.
##
## It used to be one word, one step, which made CAT and CONSTELLATION the same
## move — the ladder measured how often you fired and nothing about what you
## fired. A three-letter word is still worth exactly one, because the ladder was
## built around that; every letter past the minimum adds a quarter.
##
## Three short words and three long ones are no longer the same run. Three
## threes reach 3.0 and a 2x2; three sevens reach 6.0 and a 3x2. Reaching for a
## long word costs time, and now it buys something.
const CHAIN_GAIN_PER_CHAR := 0.25

## Past the top of the ladder the chain does not simply keep paying out a 4x3
## forever — one flawless run would just end the match. The tenth word cashes the
## whole thing in as a scatter of single cells and puts you back to nothing.
const SALVO_AT := 10
const SALVO_BLOCKS := 10

## Topping out costs a life and wipes your board rather than ending the match.
## Ambient pressure keeps climbing across lives, so the board you get back is
## never as forgiving as the one you started with.
## How full your board has to be before the soundtrack escalates, measured in
## empty rows above the stack. `_MUSIC_HOLD` stops it flapping between tracks
## every time a block lands and clears.
const MUSIC_CRITICAL_ROWS := 6
const MUSIC_CLUTCH_ROWS := 3
const MUSIC_HOLD := 4.0

const LIVES := 3
## Nothing lands for a moment after a wipe, so you get to type before it rains.
const RESPITE := 2.5

## What counts as a hit worth shaking the room for. Set high on purpose: a
## celebration that fires on every third word stops reading as a celebration.
const BIG_SCORE := 600

## Special garbage. All off by default — the base game is the base game, and
## these are switched on in the lobby by people who already know the rules they
## are complicating. Each is roughly as likely as the others when enabled, and
## the chance is low enough that a special block is an event rather than the
## texture of every board.
const KIND_CHANCE := 0.30
const KIND_NAMES := {
	"bomb": WWBoard.Kind.BOMB,
	"armored": WWBoard.Kind.ARMORED,
	"volatile": WWBoard.Kind.VOLATILE,
	"split": WWBoard.Kind.SPLIT,
	"frozen": WWBoard.Kind.FROZEN,
	"curse": WWBoard.Kind.CURSE,
}
## Order they appear in the lobby, and the words that explain them there.
const KIND_ORDER := ["bomb", "armored", "volatile", "split", "frozen", "curse"]
## Kept short enough to sit on a switch card without being shrunk to nothing.
## The full explanation lives on the rules screen.
const KIND_BLURB := {
	"bomb": ["Bomb", "clears its neighbours"],
	"armored": ["Armoured", "needs two words"],
	"volatile": ["Volatile", "goes off if ignored"],
	"split": ["Split", "breaks into two"],
	"frozen": ["Frozen", "locked until something breaks"],
	"curse": ["Cursed", "changes its own stamp"],
}
## A bomb is worth more than the block it sits on, so it asks a harder question.
const BOMB_STAMP_WANT := 5

## Power words. None of these ask anything new of you — they are all things the
## rules already let you do, that the game never bothered to notice. That is the
## point: they teach the deep play by rewarding it the first time it happens by
## accident, rather than by explaining it up front.
##
##   COUNTER  shoot down something already inbound   -> send one straight back
##   COMBO    break three at once                    -> next attack is a tier bigger
##   PERFECT  break three at once WITHOUT dropping   -> a whole extra attack
##            your run, which is the hard version
##   CLUTCH   break anything with one row of         -> the garbage nearly stops
##            headroom left
const COMBO_AT := 3
const PERFECT_AT := 3
## Headroom, in rows, that counts as one from death.
const CLUTCH_ROWS := 1
const CLUTCH_TIME := 4.5
## How fast garbage falls during a reprieve. Not zero — a stay of execution, not
## a pardon.
const CLUTCH_RATE := 0.3

const POWERS := {
	"COUNTER": {"tint": "#7bdff2", "bonus": 150, "note": "sent it back"},
	"COMBO": {"tint": "#ffd166", "bonus": 250, "note": "next hit is bigger"},
	"PERFECT": {"tint": "#c77dff", "bonus": 500, "note": "free attack"},
	"CLUTCH": {"tint": "#90be6d", "bonus": 300, "note": "garbage slowed"},
}
## Loudest last, so a word that trips several announces the best of them nearest
## the eye and does not bury it under the ordinary ones.
const POWER_ORDER := ["COUNTER", "COMBO", "CLUTCH", "PERFECT"]

## A word earns time proportional to its own length, so long words are not
## punished for taking longer to type — but they buy no extra block size.
const CHAIN_BASE := 1.8
const CHAIN_PER_CHAR := 0.2
## What a phone's chain window is multiplied by in a room that also has a
## keyboard in it. A starting number rather than a measured one: good phone
## typists manage about half their desktop speed, and a full 2.0 here felt like
## a different game rather than a level one, so this gives back most of the gap
## and leaves the pressure clock alone.
const TOUCH_GRACE := 1.55

const PLAYER_ACCENT := Color("#7bdff2")
const AI_ACCENT := Color("#ff8fa3")
## One colour per board, so "who just hit me" is answerable at a glance.
const SLOT_ACCENTS := [
	Color("#7bdff2"), Color("#ff8fa3"), Color("#ffd166"), Color("#c77dff"),
]
## Repainted by the equipped board theme; see `_apply_theme`. Everything that
## draws a backdrop reads these rather than a constant, which is what lets a
## cosmetic change the whole world without touching a single drawing routine.
var bg_top := Color("#0b1020")
var bg_bottom := Color("#141a36")
## Theme-owned paint for the surfaces that used to be hardcoded. Defaults match
## what was there before, so an unthemed build looks exactly as it did.
var _key_bg := Color("#141b33")
var _key_edge := Color("#7bdff2")
var _key_ink := Color("#e6ecff")
var _fire_bg := Color("#1b2f4a")
var _fire_edge := Color("#7bdff2")
var _glow := Color.BLACK
var _glow_a := 0.0

## The whole scene shifts when something heavy lands, so the background is drawn
## this far past the viewport on every side to keep the edges covered.
const SHAKE_MARGIN := 56.0

## An attack used to teleport: you fired, and a number appeared under somebody
## else's board. Now it flies there. With four boards this is the difference
## between knowing you were hit and knowing WHO hit you, and it costs the attack
## a moment in the air, which is the moment the hit actually feels like it lands.
const TRACER_SPAN := 0.46
const TRACER_ARC := 150.0

## Time briefly stops on a heavy hit. This is the cheapest trick in the box and
## the one that does the most: a fortieth of a second of nothing is what makes an
## impact feel like it has weight rather than merely happening.
const HITSTOP_SCALE := 0.12
const HITSTOP_HEAVY := 90     ## milliseconds, a big block landing
const HITSTOP_POWER := 120    ## a power word
const HITSTOP_SALVO := 220    ## the whole chain cashing in

## Screen texture, all of it deliberately near the threshold of noticing. Turn
## any of these up and the game starts looking like a filter instead of a game.
## Scanlines were tried here and cut: at any strength you could actually see,
## they claim a CRT this game is not pretending to be, and below that they were
## a draw call doing nothing. Grain and a vignette give the surface interest
## without making a period argument.
const GRAIN := 0.05
const VIGNETTE := 0.40

enum Phase { SPLASH, TITLE, SOLO, LOBBY, MASTERY, SETTINGS, PRACTICE,
	COUNTDOWN, PLAY, OVER, COSMETICS }

## What a match is for. A tutorial and a training run use the whole machine —
## real board, real typing, real rules — and differ only in what is switched off
## around them. Neither can be lost, and neither banks anything: a mode with no
## opponent and no death would be an XP farm, and the level has to keep meaning
## matches played through.
enum Mode { NORMAL, TUTORIAL, TRAINING, DAILY }

## The daily board: one run, everybody gets the same one, and it is over when
## the clock runs out rather than when somebody wins.
##
## There is no opponent. A shared board only means anything if the thing being
## compared is the same for everyone, and an opponent — human or CPU — makes
## every run diverge on its second word. So the pressure is the ambient clock
## and nothing else, and what is being measured is how much you can wring out
## of three minutes of it.
const DAILY_SECONDS := 180.0
## The block kinds are part of the day. Rolled from the seed, so the setting is
## as fixed as the letters are.
const DAILY_KIND_POOL := ["bomb", "armoured", "volatile", "split", "frozen", "cursed"]

## The key art gets a moment of its own before the menu arrives, then dissolves
## into it. Any key or click cuts it short — nobody should have to watch this
## twice, least of all somebody who just wants a rematch.
const SPLASH_HOLD := 1.7
const SPLASH_FADE := 0.7
## The art is 3:2 against a 16:9 screen, so it is framed rather than cropped —
## it is a composed picture and trimming its edges costs more than two bars. This
## is sampled from the art's own border so the join does not read as a letterbox,
## and `boot_splash/bg_color` in project.godot is set to match.
const SPLASH_MATTE := Color("#01061a")

## Both players stare at the same 3-2-1 before anyone can type, which matters far
## more over a network than it does alone: it is what makes the start fair.
const COUNTDOWN_TIME := 3.0


class Pending extends RefCounted:
	var tier := 0
	var prefix := ""
	var cells := 1
	var timer := 0.0
	var kind := 0
	## Who sent it, as an entity id — 0 for the local player, a peer id for
	## anyone else, and -1 for ambient pressure, which has nobody to credit.
	## Carried so a board that overfills can pay whoever filled it.
	var from := -1


## An attack in flight. Purely cosmetic — the rules already resolved the moment
## the word was fired — so it can be lobbed on a curve and take its time.
class Tracer extends RefCounted:
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var arc := Vector2.ZERO
	var t := 0.0
	var span := TRACER_SPAN
	var color := Color.WHITE
	var text := ""
	var width := 3.0
	var at_me := false
	var mine := false
	## Untyped on purpose: `SideState` is declared after this class.
	var target = null

	func at(u: float) -> Vector2:
		var v := 1.0 - u
		return from * (v * v) + arc * (2.0 * v * u) + to * (u * u)


class SideState extends RefCounted:
	var board: WWBoard
	var slot := 0
	var label := ""
	var accent := Color.WHITE
	## Who runs this board: you, a bot on this machine, or somebody's network peer.
	var is_local := false
	var bot: AiOpponent = null
	var peer_id := 0
	var alive := true
	## Whose board this side is currently dropping blocks on.
	var target := 0
	## Slots beyond the roster size are not in the match at all.
	var in_match := false
	## What this player has typed so far, for the watch-them-work display.
	var typing := ""

	func active_slot() -> bool:
		return in_match
	var pending: Array = []
	var used: Dictionary = {}
	var words_played := 0
	var blocks_cleared := 0
	var score := 0
	## Best single word, for the end screen — the one you want to tell people about.
	var best_word := ""
	var best_word_score := 0
	var best_combo := 0
	var chain := 0
	## The meter behind the number. A word is worth one plus a quarter for every
	## letter past the minimum, so `chain` is what the meter has filled to rather
	## than how many words have been fired — see `_chain_gain`.
	var chain_fill := 0.0
	var chain_timer := 0.0
	var chain_window := 1.0
	var best_chain := 0
	var bot_switch := 0.0
	var lives := LIVES
	var respite := 0.0
	var life_flash := 0.0
	var salvos := 0
	var salvo_flash := 0.0
	## Owed by a COMBO to the NEXT attack, and spent there.
	## Power word name -> times earned this match, and the longest word played.
	var power_tally: Dictionary = {}
	var longest_word := ""
	var tier_bonus := 0
	## Seconds of CLUTCH reprieve still running on this board.
	var slowdown := 0.0
	var powers_fired := 0
	## What this player is typing on, and what that is worth. See `_apply_handicap`.
	var device: int = 0
	var grace := 1.0
	var in_danger := false
	## How many rivals were aiming here last time it was checked, so a change can
	## be announced once rather than every frame.
	var focused_by := 0
	var flash := 0.0

	func pending_cells() -> int:
		var n := 0
		for p: Pending in pending:
			n += p.cells
		return n


var phase: int = Phase.SPLASH
var splash_time := 0.0
## How long the summary has been up. A match ends while your hands are still
## moving, and whatever you were halfway through typing arrives here — so for
## the first moment of it nothing is listening, keys or taps.
var over_age := 0.0
const OVER_LOCKOUT := 1.1
## Whether the premium row is waiting for its second tap. Deliberately not
## saved: an armed purchase should not survive leaving the screen.
var _buy_armed := false
## Screen furniture to keep clear of, in design units. See `_measure_safe_area`.
var safe_top := 0.0
var safe_bottom := 0.0
## Every board in the match. `sides[0]` is always yours; the rest are rivals,
## living or knocked out. `player` and `ai_side` are kept as names for slot 0 and
## the first rival so the one-on-one code paths still read naturally.
var sides: Array[SideState] = []
var player: SideState
var ai_side: SideState
var difficulty := "Duelist"
## How many boards this match was set up with.
var slots_in_play := 2

var typed := ""
var message := ""
var message_color := Color.WHITE
var message_life := 0.0
var events: Array = []
var recent_stamps: Array = []
var match_time := 0.0
var pressure_interval := PRESSURE_START
var pressure_timer := PRESSURE_START
var winner := ""

## Floating "+N" numbers, and the running total's own animation. `score_shown`
## chases the real total rather than snapping to it, so the counter visibly
## climbs — half the pleasure of a big word is watching it land.
var score_pops: Array = []
var score_shown := 0.0
var score_kick := 0.0
## Power-word banners. Kept separate from the score pops because they are an
## announcement rather than a number, and they stack when one word trips several.
var power_pops: Array = []
## Characters actually typed, for a real WPM rather than one inferred from words.
var chars_typed := 0

## One per accepted keystroke, for the equipped typing effect to draw. Spawned
## even when the effect is "plain" would be waste, so the input handler checks.
var _key_flecks: Array = []

## Attacks in flight, and the deadline for the current freeze-frame.
var tracers: Array = []
var _hitstop_until := 0

## Cached from the profile by `_apply_prefs`, because these are read every frame
## and every heavy hit respectively.
var fx_texture := true
var fx_hitstop := true
var fx_censor := true

var _grain: Texture2D
var _vignette: Texture2D

var shake := 0.0
var flash := 0.0
var flash_color := Color.WHITE
var show_rules := false
## Which cosmetic category the mastery screen is showing.
var mastery_slot := 0
## True while the window is taller than it is wide. Every layout branches on
## this rather than on a platform, so the phone screen is testable by dragging a
## desktop window narrow — which is the only reason it got built at all.
var portrait := false

var mode := Mode.NORMAL
## Where the tutorial has got to, and how long the current step has been up.
var lesson := 0
var lesson_age := 0.0
var lesson_done := false
## The last word the player fired, so the lesson can brand a block with their
## own tail rather than with an example.
var _lesson_word := ""
## Training pace, as an index into TRAINING_PACE.
var train_pace := 1

## How often ambient garbage arrives in training, and what to call it. Practice
## is worthless if it is not at a speed you would actually meet.
const TRAINING_PACE := [
	{"name": "Calm", "note": "room to think", "every": 9.0},
	{"name": "Steady", "note": "about a real match", "every": 5.5},
	{"name": "Relentless", "note": "faster than anyone plays", "every": 2.8},
]

## Which special block kinds are switched on. Empty is the default and the base
## game; the lobby fills it.
var block_kinds: Array = []

## Single-player setup: the three rival seats, and which one the roster fills.
var solo_seats: Array = ["Duelist", "", ""]
var solo_pick := 0
## True while the settings screen has the keyboard for the name field.
var settings_editing := false
## Set when a finished match is folded into the profile, so the end screen can
## show what it earned. Cleared when a new match starts.
var earned: Dictionary = {}
var decor: Array = []
var join_ip := "127.0.0.1"
var lobby_field := 1        # 0 = name, 1 = address
## Link.Backend. Defaults to whichever backend owns the code slot — EOS once
## credentials exist, noray otherwise.
var lobby_backend: int = Link.Backend.EOS if EOSConfig.is_configured() else Link.Backend.ROOM
var countdown := 0.0
var paused := false
var _last_count_beep := -1
var _music_key := ""
var _music_hold := 0.0

var _font: Font
var _font_bold: Font
var _font_title: Font
var _splash: Texture2D
var _splash_tall: Texture2D
var _overlay: Node2D
var _chip_sb: StyleBoxFlat
var _ui_sb: StyleBoxFlat
var _hover_action := ""


func _ready() -> void:
	randomize()
	_font = ThemeDB.fallback_font
	var fv := FontVariation.new()
	fv.base_font = _font
	fv.variation_embolden = 0.6
	_font_bold = fv

	# The wordmark gets its own face; everything else stays on the plain one,
	# which is what keeps a display font from becoming a headache to read. Both
	# fall back rather than crash, so a build that lost an asset still runs.
	_font_title = _load_or_null("res://fonts/RubikGlitch-Regular.ttf") as Font
	if _font_title == null:
		push_warning("Game: title font missing — falling back to the plain face")
		_font_title = _font_bold
	_splash = _load_or_null("res://splashScreen.png") as Texture2D
	# The portrait cut, for phones. Optional on purpose: without it the landscape
	# art is used in both orientations, which is worse but not broken.
	_splash_tall = _load_or_null("res://iosSplashScreen.png") as Texture2D
	if _splash == null:
		push_warning("Game: splash art missing — going straight to the menu")
		phase = Phase.TITLE

	_chip_sb = StyleBoxFlat.new()
	_chip_sb.set_corner_radius_all(6)
	_ui_sb = StyleBoxFlat.new()
	_seed_decor()

	for i in SLOTS:
		var s := SideState.new()
		s.slot = i
		s.accent = SLOT_ACCENTS[i]
		s.board = WWBoard.new()
		s.board.block_landed.connect(_on_block_landed)
		# Curses re-brand themselves and split children need branding, both from
		# inside the board. It has the blocks; we have the dictionary.
		s.board.mint = func() -> String:
			return _mint_stamp(WordBank.random_common(), STAMP_WANT, s)
		s.board.volatile_blew.connect(_on_volatile_blew.bind(s))
		add_child(s.board)
		s.board.set_accent(s.accent)
		sides.append(s)

	player = sides[0]
	player.label = "YOU"
	player.is_local = true
	ai_side = sides[1]
	_layout_boards()

	_overlay = Node2D.new()
	add_child(_overlay)
	# The grain is tiled from a small texture, which needs repeat turned on for
	# this canvas item specifically.
	_overlay.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_overlay.draw.connect(_draw_overlay)
	_build_screen_texture()

	_apply_orientation()
	get_tree().get_root().size_changed.connect(_apply_orientation)
	_apply_theme()
	_apply_prefs()
	Profile.changed.connect(_apply_theme)
	var saved: Array = Profile.pref("solo")
	if saved.size() == solo_seats.size():
		solo_seats = saved.duplicate()
	block_kinds = (Profile.pref("kinds") as Array).duplicate()

	_net_setup()


## Measure the window and pick a design space to match it. Called on boot and on
## every resize, so rotating a phone — or dragging a desktop window narrow — lands
## in the other layout immediately.
func _apply_orientation() -> void:
	var win := DisplayServer.window_get_size()
	var want_portrait: bool = win.y > win.x
	var want: Vector2i = PORTRAIT_SIZE if want_portrait else LANDSCAPE_SIZE
	if get_window().content_scale_size == want and portrait == want_portrait:
		return
	portrait = want_portrait
	get_window().content_scale_size = want
	_measure_safe_area(want)
	_layout_boards()
	queue_redraw()
	_overlay.queue_redraw()


## How much of the screen the phone's own furniture is sitting on, in the design
## space the game draws in. Filling the screen means the top of the board is now
## under the Dynamic Island and the keyboard's bottom row is under the home
## indicator, so everything that touches an edge is inset by these instead.
##
## Zero on desktop, where the safe area is the whole screen — so the same code
## runs everywhere and there is no platform branch to get wrong.
func _measure_safe_area(base: Vector2i) -> void:
	safe_top = 0.0
	safe_bottom = 0.0
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0 or base.x <= 0 or base.y <= 0:
		return
	var screen := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var safe := DisplayServer.get_display_safe_area()
	if screen.y <= 0:
		return
	# Both are screen pixels; the game's units are the design space, and with
	# `expand` the factor between them is whichever axis the screen ran out of.
	var k: float = minf(float(win.x) / float(base.x), float(win.y) / float(base.y))
	if k <= 0.0:
		return
	safe_top = maxf(0.0, float(safe.position.y)) / k
	safe_bottom = maxf(0.0, float(screen.y - safe.end.y)) / k

	# `godot -- --safe=104,40` forces the insets, so a notch can be laid out from
	# a desktop window. Same reasoning as deciding the orientation by measuring
	# the window: the only way any of this got built without a phone in the room
	# is that none of it asks what platform it is on.
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--safe="):
			var parts := a.substr(7).split(",")
			if parts.size() == 2:
				safe_top = maxf(0.0, parts[0].to_float())
				safe_bottom = maxf(0.0, parts[1].to_float())


## Push the equipped board theme and block style out to everything that paints.
## Called on boot and whenever the profile changes, so equipping something in the
## mastery screen shows up behind it immediately rather than next match.
func _apply_theme() -> void:
	var id := Profile.worn("theme")
	bg_top = Cosmetics.theme_color(id, "top")
	bg_bottom = Cosmetics.theme_color(id, "bottom")
	var panel := Color(Cosmetics.theme_color(id, "panel"),
		float(Cosmetics.theme_opt(id, "panel_a")))
	var grid := Cosmetics.theme_color(id, "grid")
	var grid_a: float = float(Cosmetics.theme(id)["grid_a"])
	var style := Profile.worn("blocks")
	var nodes: bool = bool(Cosmetics.theme_opt(id, "nodes"))
	for s: SideState in sides:
		s.board.set_theme(panel, grid, grid_a, style)
		s.board.set_grid_nodes(nodes)
		# A frame that a theme can own. Every board wore the player accent
		# before, which meant the one part of the playfield with a hard edge on
		# it looked the same whatever was equipped.
		s.board.set_frame(Cosmetics.theme_tint(id, "frame", s.accent),
			float(Cosmetics.theme_opt(id, "frame_a")))

	# The keyboard is the largest single surface on a phone and was hardcoded, so
	# a change of theme left forty percent of the screen untouched.
	_key_bg = Cosmetics.theme_tint(id, "key_bg", Color("#141b33"))
	_key_edge = Cosmetics.theme_tint(id, "key_edge", PLAYER_ACCENT)
	_key_ink = Cosmetics.theme_tint(id, "key_ink", Color("#e6ecff"))
	_fire_bg = Cosmetics.theme_tint(id, "fire_bg", Color("#1b2f4a"))
	_fire_edge = Cosmetics.theme_tint(id, "fire_edge", PLAYER_ACCENT)
	_glow = Cosmetics.theme_tint(id, "glow", Color.BLACK)
	_glow_a = float(Cosmetics.theme_opt(id, "glow_a"))
	queue_redraw()


## Two small textures, built once and tiled or stretched from then on. A
## per-pixel grain done honestly in `_draw` would cost more than the rest of the
## game put together; one 96px tile with a moving offset is indistinguishable
## from the real thing in motion, and it is a single draw call.
func _build_screen_texture() -> void:
	var g := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	for y in 96:
		for x in 96:
			# Squared so most of the tile is nearly clear and the speckle is
			# sparse — even noise reads as a dirty screen rather than as film.
			var n := randf()
			g.set_pixel(x, y, Color(1.0, 1.0, 1.0, n * n))
	_grain = ImageTexture.create_from_image(g)

	# White with an alpha ramp toward the corners, so the colour it is drawn in
	# is decided at draw time — which is what lets it turn red when you are
	# about to die instead of needing a second texture.
	var v := Image.create(160, 90, false, Image.FORMAT_RGBA8)
	for y in 90:
		for x in 160:
			var d: float = Vector2(x / 159.0 - 0.5, y / 89.0 - 0.5).length() / 0.7071
			v.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(pow(d, 2.4), 0.0, 1.0)))
	_vignette = ImageTexture.create_from_image(v)


## Art and fonts are cosmetic, so a build that somehow shipped without one should
## still play. `load()` on a missing path is a hard error, hence the check.
func _load_or_null(path: String) -> Resource:
	if not ResourceLoader.exists(path):
		return null
	return load(path)


## Yours is drawn at full size on the left; rivals are the same board scaled down
## by the node transform, which keeps every effect and label working on them.
func _layout_boards() -> void:
	var size := get_viewport_rect().size
	var bw := WWBoard.COLS * WWBoard.CELL
	var duel := slots_in_play <= 2

	if portrait:
		# One board, sized by what is left after the keyboard has taken its
		# share. There is no room for a second playfield on a phone and no point
		# shrinking the one that matters to make space for it — rivals become
		# chips along the top instead.
		var bh := WWBoard.ROWS * WWBoard.CELL
		var top := _portrait_board_top()
		var room := _portrait_board_bottom() - top
		var scale: float = clampf(minf(room / bh, (size.x - 72.0) / bw), 0.7, 1.6)
		for s2: SideState in sides:
			s2.board.scale = Vector2(scale, scale)
			s2.board.position = Vector2((size.x - bw * scale) * 0.5, top)
		return

	for s: SideState in sides:
		if s.slot == 0:
			s.board.position = Vector2(BOARD_MARGIN_X, BOARD_TOP)
			s.board.scale = Vector2.ONE
		elif duel:
			# One rival gets the whole right-hand side, as it always did.
			s.board.position = Vector2(size.x - BOARD_MARGIN_X - bw, BOARD_TOP)
			s.board.scale = Vector2.ONE
		else:
			s.board.position = Vector2(RIVAL_X[s.slot], RIVAL_TOP)
			s.board.scale = Vector2(RIVAL_SCALE, RIVAL_SCALE)


## The whole match HUD for a phone, in the strip above the board and the one
## below it. Not a squeezed version of the landscape HUD — that has a centre
## column and three rival playfields, neither of which exists here.
##
## Rivals are reduced to chips. You cannot read four boards on a phone and
## pretending otherwise costs the one board you can read; a name, lives and how
## much is falling on them is the part you actually act on.
func _draw_portrait_hud(size: Vector2) -> void:
	var cx := size.x * 0.5
	# The header hangs off the top of the safe area rather than the top of the
	# screen, so the clock does not sit behind the Dynamic Island.
	var top := safe_top

	var clock: float = daily_left() if mode == Mode.DAILY else match_time
	var kick := score_kick * score_kick
	_text_pair(_font_bold, _font_bold, Vector2(cx, top + 34.0),
		"%d:%02d" % [int(clock) / 60, int(clock) % 60],
		_commas(int(round(score_shown))), 26, int(26 + 8.0 * kick),
		Color("#ff6b6b") if (mode == Mode.DAILY and clock <= 15.0) else Color("#e6ecff"),
		Color("#ffd166").lerp(Color.WHITE, kick * 0.7), 34.0)
	_text_centered(_font, Vector2(cx, top + 60.0),
		"pressure in %ds" % int(ceil(pressure_timer)), 11, Color("#5d6a92"))

	# Your lives, as the same pips the landscape header uses.
	for i in LIVES:
		var lit: bool = i < player.lives
		draw_rect(Rect2(cx - 30.0 + i * 22.0, top + 76.0, 15.0, 9.0),
			player.accent if lit else Color("#2a3355"), true)

	var rivals := []
	for s: SideState in sides:
		if s.slot > 0 and s.in_match:
			rivals.append(s)
	if not rivals.is_empty():
		var cw: float = minf(196.0, (size.x - 24.0) / float(rivals.size()) - 8.0)
		var span: float = float(rivals.size()) * cw + float(rivals.size() - 1) * 8.0
		for i in rivals.size():
			var s2: SideState = rivals[i]
			var r := Rect2(cx - span * 0.5 + float(i) * (cw + 8.0), top + 100.0, cw, 62.0)
			var aimed: bool = player.target == s2.slot
			_panel(r, Color("#141b33"), Color(s2.accent, 0.9 if aimed else 0.25), 8.0,
				2.0 if aimed else 1.0)
			_text_fit(_font_bold, Vector2(r.get_center().x, r.position.y + 17.0),
				_show(s2.label), 14, cw - 12.0, s2.accent if s2.alive else Color("#4d5878"))
			for k in LIVES:
				draw_rect(Rect2(r.get_center().x - 20.0 + k * 14.0, r.position.y + 28.0,
					9.0, 6.0), s2.accent if k < s2.lives else Color("#2a3355"), true)
			var inbound := s2.pending_cells()
			_text_centered(_font, Vector2(r.get_center().x, r.end.y - 12.0),
				("%d incoming" % inbound) if inbound > 0 else _commas(s2.score), 10,
				Color("#ffd166") if inbound > 0 else Color("#7c88ad"))

	# Everything below the board: what is falling on you, the run you are on,
	# and the line you are typing, stacked into the gap above the keyboard.
	_draw_portrait_rails()

	var below := _portrait_board_bottom()
	var bw := WWBoard.COLS * WWBoard.CELL * player.board.scale.x
	var meter := Rect2(cx - bw * 0.5, below + 30.0, bw, 6.0)
	draw_rect(meter, Color("#141b33"), true)
	if player.chain > 0:
		var frac: float = clampf(player.chain_timer / maxf(player.chain_window, 0.01),
			0.0, 1.0)
		draw_rect(Rect2(meter.position, Vector2(meter.size.x * frac, meter.size.y)),
			WWBoard.TIER_COLORS[_chain_tier(player.chain)], true)

	var hits := _preview_hits(player, typed)
	var col := PLAYER_ACCENT
	if typed.length() >= MIN_WORD_LEN:
		if hits > 0:
			col = Color("#ffd166")
		elif not WordBank.is_valid(typed):
			col = Color("#7c88ad")
	_text_fit(_font_bold, Vector2(cx, below + 66.0), typed.to_upper(), 34,
		size.x - 40.0, col)

	var note := ""
	if hits > 0:
		note = "takes out %d block%s" % [hits, "" if hits == 1 else "s"]
	elif player.chain + 1 >= SALVO_AT:
		note = "NEXT HIT IS A SALVO"
	elif player.chain >= 2:
		note = "chain x%d" % player.chain
	elif message_life > 0.0:
		note = message
	if note != "":
		_text_fit(_font, Vector2(cx, below + 90.0), note, 12, size.x - 40.0,
			Color("#ffd166") if hits > 0 else Color("#8d99bd"))


## The two columns either side of the board in portrait.
##
## A phone board is one column of playfield in the middle of a screen with a
## hand's width of nothing down each side, and what used to be in that space was
## the words "3 incoming" under the board. A count is the least useful thing you
## can say about a queue of attacks: it will not tell you which one lands first,
## what letters answer it, or whether the word you are halfway through typing is
## going to catch any of them.
##
## So the same chips the desktop draws go in the gutters, and the two sides carry
## opposite halves of the fight — left is what is falling on you, right is what
## you have put in the air. That is worth more than symmetry for its own sake:
## seeing your own salvo still in flight is what makes sending one feel like a
## thing you did rather than a number that went up.
func _draw_portrait_rails() -> void:
	var r := _board_rect(player)
	var gutter: float = r.position.x - 10.0
	if gutter < 54.0:
		return
	var cw: float = minf(150.0, gutter - 12.0)
	var ch := 34.0

	_draw_rail(Rect2(r.position.x - 10.0 - cw, r.position.y, cw, r.size.y),
		player.pending, "INCOMING", Color("#ff6b6b"), _typing_of(player), true)

	# The right rail follows whoever you are aiming at, so switching target
	# switches what you are watching — the two are the same decision.
	var mark := _target_side()
	if mark != null and mark != player:
		_draw_rail(Rect2(r.end.x + 10.0, r.position.y, cw, r.size.y),
			mark.pending, "SENT", mark.accent, "", false)


## One column of attack chips, newest at the bottom, clipped to the board's own
## height so a long queue cannot run off into the keyboard.
func _draw_rail(box: Rect2, queue: Array, label: String, tint: Color,
		aiming: String, incoming: bool) -> void:
	_text_centered(_font_bold, Vector2(box.get_center().x, box.position.y - 12.0),
		label, 9, Color(tint, 0.55 if queue.is_empty() else 0.95))
	if queue.is_empty():
		return

	# Only the reach a word has left after it has finished with the board can
	# touch something still in the air, which is the whole of why intercepting is
	# a decision rather than a freebie.
	var budget := 0
	if incoming and aiming.length() >= MIN_WORD_LEN:
		budget = _reach(aiming) - player.board.would_clear(aiming, _reach(aiming))

	var y := box.position.y
	for p: Pending in queue:
		if y + CHIP_H > box.end.y:
			# Whatever did not fit, said as a number rather than not said at all.
			_text_centered(_font, Vector2(box.get_center().x, y + 10.0),
				"+%d more" % (queue.size() - int((y - box.position.y) / (CHIP_H + CHIP_GAP))),
				10, Color(tint, 0.8))
			return
		var rect := Rect2(box.position.x, y, box.size.x, CHIP_H)
		var locked: bool = budget > 0 and p.prefix != "" and aiming.begins_with(p.prefix)
		if locked:
			budget -= 1

		_chip_sb.bg_color = Color(WWBoard.TIER_COLORS[p.tier], 0.92)
		_chip_sb.border_color = Color.WHITE if locked else Color(0, 0, 0, 0.35)
		_chip_sb.set_border_width_all(3 if locked else 1)
		draw_style_box(_chip_sb, rect)

		_text_fit(_font_bold, Vector2(rect.position.x + rect.size.x * 0.38,
			rect.get_center().y - 2.0), p.prefix.to_upper(), 16,
			rect.size.x * 0.6, Color("#0b1020"), 8)
		_draw_shape_pip(Vector2(rect.end.x - 20.0, rect.get_center().y - 2.0), p.tier)

		# The fuse is the only part of a chip that is worth watching second to
		# second, so it gets the full width of the chip rather than a corner.
		var fuse := 1.0 - clampf(p.timer / DROP_DELAY, 0.0, 1.0)
		draw_rect(Rect2(rect.position.x + 4.0, rect.end.y - 7.0,
			(rect.size.x - 8.0) * fuse, 3.0), Color("#0b1020"), true)

		y += CHIP_H + CHIP_GAP


## Where the board has to stop, so the typed line and the keyboard both fit.
func _portrait_board_bottom() -> float:
	return _keyboard_bottom() - Keyboard.height() - 92.0


## Where the board starts, below the status header and whatever the phone has
## parked at the top of the screen.
func _portrait_board_top() -> float:
	return PORTRAIT_BOARD_TOP + safe_top


## The baseline the keyboard's last row sits on. Held off the very bottom edge
## by the home indicator, which otherwise takes swipes meant for the FIRE key.
func _keyboard_bottom() -> float:
	return get_viewport_rect().size.y - 18.0 - safe_bottom


## The free space between your board and the rivals. The centre column has to
## live here, or it draws straight through somebody's playfield.
func _center_band() -> Vector2:
	var size := get_viewport_rect().size
	if portrait:
		return Vector2(16.0, size.x - 16.0)
	var left := BOARD_MARGIN_X + WWBoard.COLS * WWBoard.CELL + 16.0
	var right := size.x - BOARD_MARGIN_X - WWBoard.COLS * WWBoard.CELL - 16.0
	if slots_in_play > 2:
		right = RIVAL_X[1] - 16.0
	return Vector2(left, right)


func _board_rect(s: SideState) -> Rect2:
	var sz := s.board.board_size() * s.board.scale
	return Rect2(s.board.position, sz)


## Everyone still standing, yourself included.
func _living() -> Array:
	var out: Array = []
	for s: SideState in sides:
		if s.active_slot() and s.alive:
			out.append(s)
	return out


## Rivals you could aim at right now.
func _living_rivals() -> Array:
	var out: Array = []
	for s: SideState in _living():
		if s != player:
			out.append(s)
	return out


## Only the heavy stuff moves the whole screen — a 1x1 tapping down should not
## rattle the room, but a 4x3 arriving should be felt.
func _on_block_landed(tier: int, _at: Vector2, impact: float) -> void:
	if tier < 2:
		return
	shake = maxf(shake, (0.12 + 0.10 * (tier - 1)) * (0.55 + 0.45 * impact))
	if tier >= 4:
		_hitstop(HITSTOP_HEAVY)
		_bloom(WWBoard.TIER_COLORS[tier], 0.16)


func _bloom(color: Color, amount: float) -> void:
	flash = maxf(flash, amount)
	flash_color = color


## `bots` is how many CPU rivals to line up. Versus passes 0 and fills the extra
## slots with peers instead.
## `lineup` names each CPU outright — that is what single-player setup passes.
## Left empty, the roster picks for you, which is what the networked path and a
## rematch off an old save still do.
func start_match(diff: String, bots: int = 1, lineup: Array = [],
		how: int = Mode.NORMAL) -> void:
	mode = how
	lesson = 0
	lesson_age = 0.0
	lesson_done = false
	difficulty = diff
	# A lesson, a practice run and the daily are played alone. There is nobody to
	# lose to and nothing to be distracted by, which is the entire point.
	if mode != Mode.NORMAL:
		bots = 0
		lineup = []
	# Fix the deal before a single block is minted, or the seed is meaningless.
	if mode == Mode.DAILY:
		WordBank.seed_run(daily_seed())
		block_kinds = daily_kinds()
	else:
		WordBank.free_run()
	slots_in_play = clampi(1 + bots, 2, SLOTS)
	if lineup.is_empty():
		lineup = _bot_lineup(diff, slots_in_play - 1)

	for s: SideState in sides:
		s.in_match = s.slot < slots_in_play
		s.alive = s.in_match
		if s.slot == 0:
			s.label = "YOU"
		elif s.in_match and not net_active():
			var who: String = lineup[s.slot - 1]
			# Named by personality rather than "CPU 2". In a four-way, knowing
			# that the board on the right is BERSERKER and the one beside it is
			# BULWARK is the difference between three opponents and one opponent
			# drawn three times.
			s.label = who.to_upper() if slots_in_play > 2 else "CPU"
			s.bot = AiOpponent.new()
			s.bot.configure(who)
			s.peer_id = 0
		if s.bot != null and not s.in_match:
			s.bot = null

	_layout_boards()
	for s: SideState in sides:
		s.board.reset()
		s.pending.clear()
		s.used.clear()
		s.words_played = 0
		s.blocks_cleared = 0
		s.score = 0
		s.best_word = ""
		s.best_word_score = 0
		s.best_combo = 0
		s.chain = 0
		s.chain_fill = 0.0
		s.chain_timer = 0.0
		s.best_chain = 0
		s.lives = LIVES
		s.respite = 0.0
		s.life_flash = 0.0
		s.salvos = 0
		s.salvo_flash = 0.0
		s.tier_bonus = 0
		s.slowdown = 0.0
		s.powers_fired = 0
		s.power_tally = {}
		s.longest_word = ""
		s.in_danger = false
		s.flash = 0.0
		s.target = 0
	if mode != Mode.NORMAL:
		# The second board is left in the match so every layout and every draw
		# routine still has the two sides they were written for, but nobody is
		# home: no bot, no attacks, nothing to answer.
		for s2: SideState in sides:
			if s2.slot > 0:
				s2.bot = null
				s2.label = "PRACTICE" if mode == Mode.TRAINING else "LESSON"
	_aim_everyone()
	typed = ""
	message = ""
	message_life = 0.0
	events.clear()
	recent_stamps.clear()
	score_pops.clear()
	power_pops.clear()
	_key_flecks.clear()
	tracers.clear()
	_clear_hitstop()
	score_shown = 0.0
	score_kick = 0.0
	chars_typed = 0
	match_time = 0.0
	pressure_interval = PRESSURE_START
	pressure_timer = PRESSURE_START
	if mode == Mode.TRAINING:
		# Set after the generic reset, not before it, or the reset wins and the
		# first block takes twenty-two seconds to turn up.
		pressure_interval = float(TRAINING_PACE[train_pace]["every"])
		pressure_timer = pressure_interval
	winner = ""
	shake = 0.0
	flash = 0.0
	_hover_action = ""
	position = Vector2.ZERO
	_overlay.position = Vector2.ZERO
	earned = {}
	if mode == Mode.TUTORIAL:
		_lesson_begin()
	countdown = COUNTDOWN_TIME
	paused = false
	_last_count_beep = -1
	phase = Phase.COUNTDOWN
	_log("%s — get ready" % diff, Color("#c8d3f5"))


## Who you are actually facing. The one you picked always turns up; the rest of
## a free-for-all is filled with *different* personalities, because three copies
## of the same opponent is one opponent with more boards. They are drawn from
## nearby on the roster so the table stays roughly the difficulty you asked for.
func _bot_lineup(pick: String, count: int) -> Array:
	var out: Array = [pick]
	if count <= 1:
		return out

	var roster: Array = AiOpponent.ROSTER
	var at := roster.find(pick)
	if at < 0:
		at = roster.find("Duelist")
	# Nearest neighbours first, alternating either side of the one you chose.
	var near: Array = []
	for step in range(1, roster.size()):
		for dir: int in [-1, 1]:
			var i: int = at + step * dir
			if i >= 0 and i < roster.size() and not near.has(roster[i]):
				near.append(roster[i])
	# Shuffle only the closest handful. Shuffling the whole roster would throw
	# away the ordering that keeps the table near the level you asked for, but
	# taking the nearest strictly would deal the same names every single match.
	var window: Array = near.slice(0, mini(count + 2, near.size()))
	window.shuffle()
	while out.size() < count and not window.is_empty():
		out.append(window.pop_front())
	while out.size() < count:
		out.append(pick)
	return out


## Boards this machine is responsible for: your own, and any bots you run.
func _owned_here(s: SideState) -> bool:
	return s.is_local or s.bot != null


## What a given board is mid-way through typing: your own line, a bot's progress,
## or whatever a peer last told us.
func _typing_of(s: SideState) -> String:
	if s.is_local:
		return typed
	if s.bot != null:
		return s.bot.visible_text()
	return s.typing


## Opening the menu freezes a solo match outright. It cannot freeze a networked
## one — everybody else is still playing — so there the match runs on underneath
## and the menu says so rather than pretending otherwise.
func _toggle_pause() -> void:
	paused = not paused
	_hover_action = ""
	Sfx.play("back", 1.1 if paused else 0.9)


# --------------------------------------------------------------------- aiming

## Give everyone somebody to hit. You keep whatever you had if it is still
## standing; bots pick fresh so a free-for-all does not gang up by accident.
func _aim_everyone() -> void:
	for s: SideState in _living():
		if not _is_valid_target(s, sides[s.target]):
			_aim(s, _pick_target_for(s))


func _is_valid_target(shooter: SideState, mark: SideState) -> bool:
	return mark != null and mark != shooter and mark.in_match and mark.alive


func _pick_target_for(shooter: SideState) -> SideState:
	var options: Array = []
	for s: SideState in _living():
		if s != shooter:
			options.append(s)
	if options.is_empty():
		return shooter
	return options[randi() % options.size()]


func _aim(shooter: SideState, mark: SideState) -> void:
	shooter.target = mark.slot


## Step your aim to the next living rival. What Tab does.
## Today, as a date, in the player's own timezone — so the board turns over at
## their midnight rather than at some arbitrary hour of their evening.
##
## The trade is worth stating, because the two things asked of a daily pull
## against each other. Seeding from the local date means everybody playing a
## given calendar date plays the same board, which is the sense of "the same
## one" that matters — but two players either side of a date line are on
## different boards for a few hours, because it is genuinely a different date
## where they are standing. The alternative, UTC, keeps the whole world in step
## at the cost of rolling the board over mid-afternoon for some of them.
##
## Local wins because a daily is a thing you do as part of your day. It is also
## what Wordle does, so the behaviour is already familiar.
func daily_key() -> String:
	var d := Time.get_datetime_dict_from_system(false)
	return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]


## The seed for today.
##
## It is the date and nothing else, which is the whole trick: no server, no
## sync, no clock to agree on. Two machines that think it is the same day deal
## the same board because they compute the same number from the same string.
##
## Hashed rather than used raw because consecutive dates are consecutive
## integers, and consecutive seeds deal recognisably similar sequences — the
## hash makes yesterday and today unrelated.
func daily_seed() -> int:
	return seed_for(daily_key())


## The seed a given date deals. Split out from the clock so it can be checked
## against a fixed date — the promise that two machines agree is a promise about
## this function, and it cannot be tested through something that reads `now`.
func seed_for(key: String) -> int:
	return hash("wordwars-daily-" + key)


## Which special blocks are in play today. Two of them, picked by the seed, so
## the setting varies day to day and is still the same setting for everyone.
func daily_kinds(key: String = "") -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_for(key if key != "" else daily_key())
	var pool := DAILY_KIND_POOL.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	return pool.slice(0, 2)


## How long is left of the daily run.
func daily_left() -> float:
	return maxf(0.0, DAILY_SECONDS - match_time)


## Extra weight when a board is being ganged up on.
##
## In a four-way, spreading fire is safe and coordinating is not rewarded, so
## everybody quietly plays their own solitaire and the free-for-all stops being a
## free-for-all. This makes a shared target worth agreeing on: two attackers on
## one board each hit a tier harder, three hit two harder.
##
## It reads live off who is aiming where rather than from anything remembered, so
## it appears the moment a second player switches on and goes the moment they
## switch off — and the target can feel it and re-aim, which is the counterplay.
## Only ever with three or more boards in the match: in a duel there is nobody to
## gang up with, and a "focus bonus" there would just be a damage buff.
func _focus_bonus(attacker: SideState, defender: SideState) -> int:
	if slots_in_play < 3 or defender == null:
		return 0
	var on_them := 0
	for s: SideState in sides:
		if s == defender or not s.in_match or not s.alive:
			continue
		if s.target == defender.slot:
			on_them += 1
	# One attacker is not a gang. Every attacker past the first adds a tier.
	return maxi(0, on_them - 1)


## Pay for overfilling somebody's board.
##
## Only the machine that owns the board knows the block landed, and only the
## attacker's machine holds the attacker's score — so a local culprit is paid
## here and a remote one is told. Ambient pressure has nobody to pay.
func _credit_topout(culprit: int, victim: SideState) -> void:
	if culprit < 0 or victim == null:
		return
	var who := _side_for_entity(culprit)
	if who == null or who == victim:
		return
	if _owned_here(who):
		who.score += Scoring.TOPOUT_BONUS
		if who == player:
			_pop_score("+%s" % _commas(Scoring.TOPOUT_BONUS), "TOPPED THEM OUT",
				Scoring.TOPOUT_BONUS)
			score_kick = 1.0
			Sfx.play("salvo", 1.1)
			Haptics.fire("salvo")
			_say("TOPPED OUT %s — +%s" % [_show(victim.label),
				_commas(Scoring.TOPOUT_BONUS)], Color("#ffd166"))
		_log("%s overfilled %s — +%s" % [_show(who.label), _show(victim.label),
			_commas(Scoring.TOPOUT_BONUS)], Color("#ffd166"))
	elif net_active():
		Link.send_topout(culprit)


## Their attack ended one of our lives, and they are owed for it.
func _on_topout_credit(_culprit: int) -> void:
	player.score += Scoring.TOPOUT_BONUS
	_pop_score("+%s" % _commas(Scoring.TOPOUT_BONUS), "TOPPED THEM OUT",
		Scoring.TOPOUT_BONUS)
	score_kick = 1.0
	Sfx.play("salvo", 1.1)
	Haptics.fire("salvo")
	_say("TOPPED THEM OUT — +%s" % _commas(Scoring.TOPOUT_BONUS), Color("#ffd166"))


## A side as a network entity id: 0 for your own board, its peer id otherwise.
## Bots have negative peer ids, which is what distinguishes "the host's CPU"
## from "a person" when a topout has to be credited.
func _entity_of(s: SideState) -> int:
	if s == null:
		return -1
	return 0 if s == player else s.peer_id


## Whoever you are aiming at, or null if that slot is gone.
func _target_side() -> SideState:
	if player.target < 0 or player.target >= sides.size():
		return null
	var mark: SideState = sides[player.target]
	return mark if mark.in_match else null


func _cycle_target(step: int) -> void:
	var rivals := _living_rivals()
	if rivals.is_empty():
		return
	var at := 0
	for i in rivals.size():
		if rivals[i].slot == player.target:
			at = i
			break
	var pick: SideState = rivals[(at + step + rivals.size()) % rivals.size()]
	if pick.slot != player.target:
		_aim(player, pick)
		Sfx.play("count", 1.25)
		_say("targeting %s" % pick.label, pick.accent)


## Skips to the start of the dissolve rather than to the menu outright, so
## cutting the splash short still hands over gracefully instead of snapping.
func _skip_splash() -> void:
	splash_time = maxf(splash_time, SPLASH_HOLD)


func _target_slot(slot: int) -> void:
	if slot < 0 or slot >= sides.size():
		return
	var mark: SideState = sides[slot]
	if not _is_valid_target(player, mark):
		return
	if mark.slot != player.target:
		_aim(player, mark)
		Sfx.play("count", 1.25)
		_say("targeting %s" % mark.label, mark.accent)


# ----------------------------------------------------------------------- input

func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return

	# Any key cuts the splash short — and does only that, so an impatient press
	# cannot also land on whatever is sitting under it on the menu.
	if phase == Phase.SPLASH:
		_skip_splash()
		return

	# Not a letter key — every one of those is needed for typing.
	if k.keycode == KEY_F1:
		Music.toggle_mute()
		_say("sound off" if Sfx.toggle_mute() else "sound on", Color("#8892b0"))
		Sfx.play("back", 1.4)
		return

	if phase == Phase.PRACTICE:
		match k.keycode:
			KEY_1: _activate("tutorial")
			KEY_2: _activate("training")
			KEY_ESCAPE: _activate("title")
		return

	if phase == Phase.SOLO:
		match k.keycode:
			KEY_ENTER, KEY_KP_ENTER: _activate("solo_start")
			KEY_ESCAPE: _activate("title")
			KEY_1, KEY_2, KEY_3:
				_activate("pick:%d" % (k.keycode - KEY_1))
		return

	if phase == Phase.SETTINGS:
		if settings_editing:
			# The name field owns the keyboard while it is open, so nothing else
			# in here can be triggered by a letter that belongs in a name.
			match k.keycode:
				KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE:
					settings_editing = false
					_hide_keyboard()
					Sfx.play("back")
				KEY_BACKSPACE:
					Link.set_name_and_save(Link.my_name.substr(
						0, maxi(0, Link.my_name.length() - 1)))
				_:
					if k.unicode > 0 and Link.my_name.length() < 14:
						var ch := String.chr(k.unicode)
						if ch.unicode_at(0) >= 32:
							Link.set_name_and_save(Link.my_name + ch.to_upper())
			return
		match k.keycode:
			KEY_ESCAPE: _activate("title")
		return

	if phase == Phase.MASTERY:
		match k.keycode:
			KEY_ESCAPE, KEY_P: _activate("title")
			KEY_C: _activate("cosmetics")
		return

	if phase == Phase.COSMETICS:
		match k.keycode:
			KEY_LEFT, KEY_A: _activate("slot:-1")
			KEY_RIGHT, KEY_D: _activate("slot:1")
			KEY_ESCAPE, KEY_C: _activate("title")
		return

	# The lobby's text fields own the keyboard while it is up.
	if phase == Phase.LOBBY:
		match k.keycode:
			KEY_ENTER, KEY_KP_ENTER:
				_activate("ready" if Link.connected else "join")
			KEY_ESCAPE:
				_activate("leave" if Link.connected else "title")
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD: _activate("addbot")
			KEY_MINUS, KEY_KP_SUBTRACT: _activate("dropbot")
			KEY_TAB:
				lobby_field = 1 - lobby_field
				Sfx.play("key", 1.2)
			KEY_V when k.ctrl_pressed:
				if not Link.connected and lobby_field == 1:
					var pasted := DisplayServer.clipboard_get().strip_edges().substr(0, 48)
					# A code copied out of a chat window arrives chunked for
					# reading. Addresses are pasted exactly as they came.
					if _backend_uses_codes():
						pasted = Link.clean_code(pasted, lobby_backend)
					join_ip = pasted
					Sfx.play("count", 1.2)
			KEY_C when k.ctrl_pressed:
				if Link.room_code != "":
					DisplayServer.clipboard_set(Link.room_code)
					Link.status = "code copied to your clipboard"
					Sfx.play("count", 1.3)
			# Hosting is CTRL+H, not H. A bare letter cannot be a shortcut while
			# a text field has the keyboard: H is a perfectly ordinary character
			# in a room code, and swallowing it would make any code containing
			# one impossible to type by hand — which is most of them.
			KEY_H when k.ctrl_pressed:
				if not Link.connected:
					_activate("host")
			KEY_BACKSPACE:
				_lobby_edit("", true)
			_:
				if Link.connected:
					return
				if k.unicode > 0:
					_lobby_edit(String.chr(k.unicode), false)
		return

	# The summary is the payoff for the match you just played, and it used to
	# share the title screen's keys — so 1, 2, 3, 4, 5, V, P and H all threw you
	# somewhere else the instant they were pressed. You finish a match with your
	# hands mid-word, the trailing keystrokes land here, and the scoreboard you
	# were meant to read is gone before you have seen it.
	#
	# So OVER gets its own two keys and nothing else: the two things drawn on the
	# screen. Everything else is ignored rather than repurposed.
	if phase == Phase.OVER:
		if over_age < OVER_LOCKOUT:
			return
		# One key, and it is the one nobody presses by accident.
		#
		# R started a rematch, and R is a letter — you finish a match with a word
		# half typed and the rest of it lands here, so the scoreboard vanished
		# into a new match before anyone read it. The lockout was not enough,
		# because people do not stop typing for a whole second. ENTER was worse
		# still: it fires a word during play, so it is the single most likely key
		# to be in flight at the moment a match ends.
		#
		# Rematch is a button now. It is the one action on this screen with a
		# cost, and it should take a deliberate click rather than a letter.
		match k.keycode:
			KEY_ESCAPE: _activate("title")
		return

	if phase == Phase.TITLE:
		match k.keycode:
			KEY_1: _activate("practice")
			KEY_2: _activate("daily")
			KEY_3: _activate("solo")
			KEY_4: _activate("versus")
			KEY_5: _activate("mastery")
			KEY_6: _activate("cosmetics")
			KEY_7: _activate("settings")
			KEY_V: _activate("versus")
			KEY_P: _activate("mastery")
			KEY_H:
				show_rules = not show_rules
				Sfx.play("back", 1.2)
			KEY_ESCAPE:
				get_tree().quit()
		return

	# Nothing to type until GO.
	if phase == Phase.COUNTDOWN:
		return

	match k.keycode:
		KEY_BACKSPACE:
			if paused or not player.alive:
				return
			if k.ctrl_pressed:
				typed = ""
			else:
				typed = typed.substr(0, maxi(0, typed.length() - 1))
			Sfx.play("back", randf_range(0.94, 1.06))
		KEY_ESCAPE:
			_toggle_pause()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			# Deliberately not a resume key: you arrive at this menu with your
			# hands on SPACE, and unpausing by reflex is the same trap ENTER was.
			if paused:
				pass
			elif mode == Mode.TUTORIAL and typed.is_empty() and (lesson_done
					or String(Tutorial.step(lesson).get("id", "")) == "done"):
				# The same key that fires a word. A lesson that needed its own
				# button would be teaching the button as well as the game.
				_lesson_next()
			else:
				_submit_player()
		KEY_TAB:
			if not paused and player.alive:
				_cycle_target(-1 if k.shift_pressed else 1)
		KEY_1: _target_slot(1)
		KEY_2: _target_slot(2)
		KEY_3: _target_slot(3)
		# Guarded, not `KEY_Q:` with an `if` inside. `match` does not fall
		# through, so an unguarded arm claims the key whether or not the body
		# does anything with it — and Q is the only letter of the alphabet with
		# an arm of its own here, so Q was the one letter that could not be
		# typed. Everything else fell to `_:` and got through. With the guard on
		# the pattern, a Q pressed while playing fails to match and carries on to
		# the default arm, which is where letters are supposed to end up.
		KEY_Q when paused:
			_activate("leave_match")
		_:
			# Modifiers and arrows report unicode 0; chr(0) builds a NUL string.
			if k.unicode <= 0 or paused or not player.alive:
				return
			var low := String.chr(k.unicode).to_lower()
			if low.length() == 1 and low >= "a" and low <= "z" and typed.length() < 20:
				typed += low
				# Counted here rather than on submit, so the WPM at the end is
				# what you actually typed — including the letters you thought
				# better of. That is what a typing test would measure.
				chars_typed += 1
				_fleck(low)
				# Slight per-key drift, or a held burst sounds like a machine.
				Sfx.play("key", randf_range(0.92, 1.10))


func _submit_player() -> void:
	if not player.alive or paused:
		typed = ""
		return
	var w := typed
	typed = ""
	# Firing an empty line is a slip, not an attempt — no penalty for it.
	if w.is_empty():
		return

	if w.length() < MIN_WORD_LEN:
		_reject(w, "too short — %d letters minimum" % MIN_WORD_LEN, Color("#ffb703"), 1.25)
		return
	if player.used.has(w):
		_reject(w, "\"%s\" already spent" % w, Color("#ffb703"), 1.1)
		return
	if not WordBank.is_valid(w):
		_reject(w, "\"%s\" is not a word" % w, Color("#ff6b6b"), 1.0)
		return
	_play_word(player, w)


## A word you fired that did not qualify costs you the run. That is the whole
## tension of the chain: the longer it gets the more a wild guess is worth.
func _reject(word: String, reason: String, color: Color, pitch: float) -> void:
	var lost := player.chain
	player.chain = 0
	player.chain_fill = 0.0
	player.chain_timer = 0.0
	Sfx.play("reject", pitch)
	# Harder the more it cost. A rejection that broke a nine-word run and one
	# that broke nothing are the same event to the rules and nothing like the
	# same event to the player.
	Haptics.fire("reject", 1.0 + 0.08 * float(mini(lost, 6)))
	if lost >= 2:
		Sfx.play("lapse", 0.9)
		_say("%s — chain x%d broken" % [reason, lost], Color("#ff6b6b"))
		_log("YOU: %s rejected — chain x%d broken" % [word.to_upper(), lost], Color("#ff6b6b"))
	else:
		_say(reason, color)


# ------------------------------------------------------------------ core rules

func _play_word(attacker: SideState, word: String) -> void:
	var defender: SideState = sides[attacker.target]
	if not _is_valid_target(attacker, defender):
		defender = _pick_target_for(attacker)
		_aim(attacker, defender)
	attacker.used[word] = true
	attacker.words_played += 1
	if attacker == player:
		_lesson_word = word
	if word.length() > attacker.longest_word.length():
		attacker.longest_word = word

	# Both measured before the word does its work: clearing raises the ceiling and
	# firing resets the chain window, so afterwards there is no way to tell
	# whether this was a rescue or whether the run was already going.
	var on_the_brink := attacker.board.stack_top() <= CLUTCH_ROWS
	var held_chain := attacker.chain_timer > 0.0

	# One word only reaches so far. Blocks already on the board go first — they
	# are the ones crowding you right now — then anything still inbound.
	var budget := _reach(word)

	var cleared := attacker.board.clear_matching(word, budget)
	var extras: Dictionary = attacker.board.last_report
	attacker.blocks_cleared += cleared
	# Armour swallowed the word without dying. It still cost reach — that is what
	# makes it two words rather than one — so it comes off the budget too.
	budget -= cleared + int(extras["cracked"])

	var intercepted := 0
	if budget > 0:
		var keep: Array = []
		for p: Pending in attacker.pending:
			if budget > 0 and p.prefix != "" and word.begins_with(p.prefix):
				intercepted += 1
				budget -= 1
			else:
				keep.append(p)
		attacker.pending = keep

	var combo := cleared + intercepted
	attacker.best_combo = maxi(attacker.best_combo, combo)

	# Rhythm decides the size of the hit. Fire again before the chain lapses and
	# it steps up a tier; the word you just played earns the time for the next.
	if attacker.chain_timer > 0.0:
		attacker.chain_fill += _chain_gain(word)
	else:
		attacker.chain_fill = _chain_gain(word)
	attacker.chain = int(floor(attacker.chain_fill))
	attacker.chain_window = (CHAIN_BASE + word.length() * CHAIN_PER_CHAR) * attacker.grace
	attacker.chain_timer = attacker.chain_window
	attacker.best_chain = maxi(attacker.best_chain, attacker.chain)
	# Banked after the chain steps up, so the word that extends a run is paid at
	# the run's new length rather than its old one.
	var earned := _award(attacker, word, combo)

	# What this word noticed about itself. Order does not matter here; it does
	# when they are announced.
	var powers: Array = []
	if intercepted > 0:
		powers.append("COUNTER")
	if cleared >= COMBO_AT:
		powers.append("COMBO")
	if cleared >= PERFECT_AT and held_chain:
		powers.append("PERFECT")
	if cleared > 0 and on_the_brink:
		powers.append("CLUTCH")

	# Top of the ladder: cash the run in and start over. A salvo is already the
	# biggest thing in the game, so it swallows any power words the same word
	# earned rather than stacking on top of them.
	if attacker.chain >= SALVO_AT:
		_note_best(attacker, word, earned)
		_fire_salvo(attacker, defender, word, combo)
		return

	# Garbage is only ever removed by answering its letters, so the whole hit
	# goes out. Nothing is held back to defend with. A tier owed by an earlier
	# COMBO is spent here — one earned just now is owed to the next word, which
	# is what makes it a promise rather than a bonus.
	var spent := attacker.tier_bonus
	attacker.tier_bonus = 0
	var focus := _focus_bonus(attacker, defender)
	var out_tier := clampi(_chain_tier(attacker.chain) + combo + spent + focus,
		0, TIERS.size() - 1)

	if out_tier >= 0:
		_send_block(defender, word, out_tier, DROP_DELAY, attacker)
		_throw(attacker, defender, out_tier, word.substr(maxi(0, word.length() - 3)))

	earned += _fire_powers(attacker, defender, word, powers, out_tier, intercepted)
	_note_best(attacker, word, earned)
	_voice_attack(attacker, cleared, intercepted, out_tier)
	_report(attacker, word, cleared, intercepted, out_tier, spent)
	_report_kinds(attacker, extras)


## The specials a word set off, said out loud. Without this a bomb reads as the
## clear inexplicably counting four, and armour reads as the word simply not
## working.
func _report_kinds(attacker: SideState, extras: Dictionary) -> void:
	var bits: Array = []
	if int(extras["cracked"]) > 0:
		bits.append("cracked %d armour" % int(extras["cracked"]))
	if int(extras["bombed"]) > 0:
		bits.append("bomb took %d more" % int(extras["bombed"]))
	if int(extras["split"]) > 0:
		bits.append("%d split" % int(extras["split"]))
	if int(extras["thawed"]) > 0:
		bits.append("thawed %d" % int(extras["thawed"]))
	if bits.is_empty():
		return
	_log("%s: %s" % [attacker.label, ", ".join(bits)], Color("#7bdff2"))
	if attacker == player:
		if int(extras["bombed"]) > 0:
			shake = maxf(shake, 0.28)
			_bloom(Color("#f8961e"), 0.16)
		if int(extras["cracked"]) > 0 and cleared_nothing(extras):
			_say("armour holds — one more word", Color("#8d99bd"))


## True when a word only cracked armour and destroyed nothing, which is the one
## case a player is likely to read as the game ignoring them.
func cleared_nothing(extras: Dictionary) -> bool:
	return int(extras["bombed"]) == 0 and int(extras["split"]) == 0


## The best word of the match is what that word was worth all in — its own score
## plus anything it triggered — since that is the one you would want to tell
## somebody about afterwards.
func _note_best(side: SideState, word: String, earned: int) -> void:
	if earned > side.best_word_score:
		side.best_word_score = earned
		side.best_word = word


## One block on its way. The defender mints its own stamp over a network,
## because only they can see what their board is already holding.
func _send_block(defender: SideState, word: String, tier: int, delay: float,
		from: SideState = null) -> void:
	if net_active() and not _owned_here(defender):
		Link.send_attack(defender.peer_id, word, tier)
		defender.flash = 1.0
		return
	var p := Pending.new()
	p.from = _entity_of(from)
	p.tier = tier
	p.kind = _roll_kind()
	# A bomb clears its neighbours, so it has to be worth the trouble of setting
	# off — it asks for a longer stamp than anything else on the board.
	p.prefix = _mint_stamp(word,
		BOMB_STAMP_WANT if p.kind == WWBoard.Kind.BOMB else STAMP_WANT, defender)
	p.cells = _cells(tier)
	p.timer = delay
	defender.pending.append(p)
	defender.flash = 1.0


## Which special this block is, if any. Rolled per block on the machine that
## owns the board, which is safe over a network because each board is simulated
## by exactly one machine and the enabled set is agreed before the match starts.
func _roll_kind() -> int:
	if block_kinds.is_empty() or WordBank.rng.randf() >= KIND_CHANCE:
		return WWBoard.Kind.PLAIN
	return int(KIND_NAMES[block_kinds[WordBank.rng.randi_range(0, block_kinds.size() - 1)]])


## Throw a visible attack from one board to another. Cosmetic only — the rules
## resolved the instant the word was fired — so it can be lobbed and take its
## time getting there.
func _throw(from_side: SideState, to_side: SideState, tier: int, text: String) -> void:
	if from_side == null or to_side == null or from_side == to_side:
		return
	if not from_side.in_match or not to_side.in_match:
		return
	# Nothing to watch an attack arrive at in a lesson or a practice run, so
	# nothing is thrown — a tracer sailing off to an invisible board reads as a
	# rendering fault.
	if not to_side.board.visible:
		return
	var tr := Tracer.new()
	var muzzle := _board_rect(from_side)
	tr.from = Vector2(muzzle.get_center().x, muzzle.end.y - 10.0)
	tr.to = _board_rect(to_side).get_center()
	# Lobbed rather than fired flat: an arc reads as a distance crossed, where a
	# straight line between two panels just looks like a UI divider.
	tr.arc = (tr.from + tr.to) * 0.5 - Vector2(0.0, TRACER_ARC + 26.0 * tier)
	tr.color = from_side.accent
	tr.text = text.to_upper()
	tr.width = 3.2 + tier * 1.2
	tr.span = TRACER_SPAN + 0.035 * tier
	tr.at_me = to_side == player
	tr.mine = from_side == player
	tr.target = to_side
	tracers.append(tr)
	# A salvo throws ten at once; past this the screen is a smear anyway.
	if tracers.size() > 28:
		tracers.pop_front()


## The moment a thrown attack reaches the board it was aimed at. The debris is
## thrown on the target board itself, in its own coordinates, so a hit on a
## shrunken rival panel scatters at that panel's scale.
func _tracer_impact(tr: Tracer) -> void:
	var side: SideState = tr.target as SideState
	if side != null and side.in_match:
		var force: float = clampf((tr.width - 3.0) / 6.0, 0.1, 1.0)
		side.board.splash(
			Vector2(WWBoard.COLS * WWBoard.CELL * 0.5, WWBoard.ROWS * WWBoard.CELL * 0.5),
			tr.color, force)
	if tr.at_me:
		shake = maxf(shake, 0.10 + tr.width * 0.02)
		_bloom(tr.color, 0.10)
		Sfx.play("zap", 0.7, -6.0)
	else:
		Sfx.play("zap", 1.4, -12.0)


## Freeze the world for a moment. This is the cheapest juice there is and the
## most effective, but it scales the whole engine — including the clock the
## netcode runs on — so a networked match does without rather than risk the two
## machines disagreeing about how much time has passed.
func _hitstop(ms: int) -> void:
	if net_active() or not fx_hitstop:
		return
	_hitstop_until = maxi(_hitstop_until, Time.get_ticks_msec() + ms)


func _clear_hitstop() -> void:
	_hitstop_until = 0
	Engine.time_scale = 1.0


## Pay out whatever the word triggered, and say so. Everyone can earn these —
## they are rules, not a player perk — but only your own get a banner, for the
## same reason only your own score is drawn.
func _fire_powers(attacker: SideState, defender: SideState, word: String,
		powers: Array, out_tier: int, intercepted: int) -> int:
	var paid := 0
	for name: String in POWER_ORDER:
		if not powers.has(name):
			continue
		attacker.powers_fired += 1
		attacker.power_tally[name] = int(attacker.power_tally.get(name, 0)) + 1
		var spec: Dictionary = POWERS[name]
		var tint := Color(String(spec["tint"]))

		match name:
			"COUNTER":
				# Literally back where it came from: one for one, so it can never
				# pay out more than was aimed at you in the first place.
				for i in intercepted:
					_send_block(defender, word, 0, DROP_DELAY + 0.25 + i * 0.12, attacker)
					_throw(attacker, defender, 0, "")
			"COMBO":
				attacker.tier_bonus = 1
			"PERFECT":
				_send_block(defender, word, out_tier, DROP_DELAY + 0.4, attacker)
				_throw(attacker, defender, out_tier, "")
			"CLUTCH":
				attacker.slowdown = CLUTCH_TIME

		# Flat, and announced on the banner itself rather than as a second
		# floating number — one thing arriving that says both what happened and
		# what it paid, instead of two things competing.
		var bonus := int(spec["bonus"])
		attacker.score += bonus
		paid += bonus
		_log("%s: %s — %s" % [attacker.label, name, String(spec["note"])], tint)
		if attacker == player:
			_pop_power(name, bonus, tint)
			score_kick = 1.0
			_hitstop(HITSTOP_POWER)
	return paid


## Bank what a word was worth. Everyone scores — a rival's total is how you know
## whether you are actually ahead — but only yours gets thrown up on screen,
## because four sets of arithmetic flying about is noise, not feedback.
func _award(side: SideState, word: String, combo: int, extra: int = 0) -> int:
	var a: Dictionary = Scoring.award(word, side.chain, combo)
	var total: int = int(a["total"]) + extra
	side.score += total

	if side == player:
		# The popup shows its working — "34 x3.4" teaches the multipliers without
		# anybody having to read a rules screen.
		var mult: float = a["mult"]
		var note := ""
		if mult > 1.01:
			note = "x%.1f" % mult
		_pop_score("+%s" % _commas(total), note, total)
		score_kick = minf(1.0, score_kick + 0.35 + 0.45 * clampf(total / 900.0, 0.0, 1.0))
		# Genuinely big hits get the room to move. The threshold is high enough
		# that it stays an event rather than a texture.
		if total >= BIG_SCORE:
			Sfx.play("clear", 1.35, -2.0)
			shake = maxf(shake, 0.18)
			_bloom(Color("#ffd166"), 0.14)
	return total


## An announcement across your own board. Several can be up at once — a word
## that counters, combos and clutches all at once has earned three lines — so
## each new one pushes the ones before it upward rather than landing on them.
func _pop_power(name: String, bonus: int, tint: Color) -> void:
	for p: Dictionary in power_pops:
		p["row"] = int(p["row"]) + 1
	power_pops.append({
		"name": name, "bonus": bonus, "tint": tint, "life": 1.0, "row": 0,
	})
	if power_pops.size() > 4:
		power_pops.pop_front()
	Sfx.play("power", 0.9 + 0.12 * POWER_ORDER.find(name))
	Haptics.fire("power")
	shake = maxf(shake, 0.16)
	_bloom(tint, 0.12)


## A number where the eye already is: just under your own board, drifting up.
func _pop_score(text: String, note: String, weight: int) -> void:
	var bw := WWBoard.COLS * WWBoard.CELL
	score_pops.append({
		"text": text,
		"note": note,
		"at": Vector2(player.board.position.x + bw * 0.5 + randf_range(-40.0, 40.0),
			BOARD_TOP + WWBoard.ROWS * WWBoard.CELL + 4.0),
		"life": 1.0,
		"size": clampf(22.0 + weight / 44.0, 22.0, 58.0),
	})
	# A salvo can stack several at once; keep the oldest from piling up.
	if score_pops.size() > 10:
		score_pops.pop_front()


## The audible shape of a turn. Firing rises with the chain and clears rise with
## the combo, so a good run sounds like it is climbing. The CPU is mixed well
## down — you want to hear that it acted, not compete with it.
func _voice_attack(attacker: SideState, cleared: int, intercepted: int, out_tier: int) -> void:
	var mine := attacker == player
	var quiet := 0.0 if mine else -9.0

	Sfx.play("fire", 1.0 + 0.07 * (attacker.chain - 1), quiet)

	var combo := cleared + intercepted
	if intercepted > 0:
		Sfx.play("zap", 1.0 + 0.06 * (intercepted - 1), quiet - 1.0)
	if cleared > 0:
		Sfx.play("clear", 1.0 + 0.11 * (combo - 1), quiet)
	if mine and combo >= 2:
		shake = maxf(shake, 0.14 + 0.06 * combo)
		_bloom(Color("#ffd166"), 0.10 + 0.05 * combo)
	if mine and out_tier >= 3:
		# A heavy hit going out deserves some weight behind it.
		Sfx.play("land", 0.8 - 0.05 * out_tier, -4.0)

	# Only your own turns are felt. A CPU acting is mixed nine decibels down
	# because it is not your doing, and a buzz has no volume to be mixed down —
	# it would land in the hand exactly as hard as your own hit.
	if mine and combo > 0:
		# Scaled by the size of the break, so a triple is felt as a triple.
		Haptics.fire("combo" if combo >= 3 else "clear",
			1.0 + 0.16 * float(combo - 1))


## The payoff for a maxed chain: not one enormous block but a scatter of single
## cells, staggered so they rain in. Individually trivial to answer, collectively
## a mess — they land unevenly and clog the board in a way one big slab does not.
## Then the chain goes back to zero, so nobody rides a single run to victory.
func _fire_salvo(attacker: SideState, defender: SideState, word: String, combo: int) -> void:
	var power := SALVO_BLOCKS + combo

	if net_active() and not _owned_here(defender):
		Link.send_salvo(defender.peer_id, word, power)
		defender.flash = 1.0
	else:
		for i in power:
			var p := Pending.new()
			p.from = _entity_of(attacker)
			p.tier = 0
			p.prefix = _mint_stamp(word, STAMP_WANT, defender)
			p.cells = 1
			p.timer = DROP_DELAY + i * 0.10
			defender.pending.append(p)
			_throw(attacker, defender, 0, "")
		if power > 0:
			defender.flash = 1.0

	attacker.salvos += 1
	attacker.salvo_flash = 1.0
	# Paid on top of the word that cashed the run in, which `_play_word` has
	# already banked at full chain.
	var bounty: int = Scoring.SALVO_BONUS * Scoring.SCALE
	attacker.score += bounty
	if attacker == player:
		_pop_score("SALVO +%s" % _commas(bounty), "", bounty)
		score_kick = 1.0
	attacker.chain = 0
	attacker.chain_fill = 0.0
	attacker.chain_timer = 0.0

	_log("%s: %s — SALVO (%d blocks)" % [attacker.label, word.to_upper(), power],
		Color("#ffd166"))

	var mine := attacker == player
	Sfx.play("salvo", 1.0, 0.0 if mine else -8.0)
	if mine:
		Haptics.fire("salvo")
		_say("SALVO — %d blocks away, chain spent" % power, Color("#ffd166"))
		shake = maxf(shake, 0.5)
		_bloom(Color("#ffd166"), 0.30)
		_hitstop(HITSTOP_SALVO)


func _report(attacker: SideState, word: String, cleared: int, intercepted: int,
		out_tier: int, spent: int = 0) -> void:
	var bits: Array = []
	if cleared > 0:
		bits.append("cleared %d" % cleared)
	if intercepted > 0:
		bits.append("shot down %d" % intercepted)
	if out_tier >= 0:
		var how := "sent %dx%d" % [TIERS[out_tier]["w"], TIERS[out_tier]["h"]]
		# Worth saying out loud, or a COMBO's promise cashes in invisibly.
		if spent > 0:
			how += " (+%d tier)" % spent
		bits.append(how)
	var tail := (" (%s)" % ", ".join(bits)) if not bits.is_empty() else " (fizzled)"

	var combo := cleared + intercepted
	var mark := " x%d" % attacker.chain if attacker.chain >= 2 else ""
	_log("%s: %s%s%s" % [attacker.label, word.to_upper(), mark, tail],
		Color("#ffd166") if combo >= 2 or attacker.chain >= 3 else attacker.accent)

	if attacker != player:
		return
	if combo >= 2:
		_say("%d-block combo!" % combo, Color("#ffd166"))
	elif cleared == 1:
		_say("block down", PLAYER_ACCENT)
	elif intercepted == 1:
		_say("shot it down", PLAYER_ACCENT)
	elif out_tier >= 0:
		_say("sent %s" % _tier_name(out_tier), PLAYER_ACCENT)
	else:
		_say("absorbed", Color("#8892b0"))


## What a word adds to the chain meter.
func _chain_gain(word: String) -> float:
	return 1.0 + CHAIN_GAIN_PER_CHAR * float(maxi(0, word.length() - MIN_WORD_LEN))


## Highest tier a chain of this length has earned on its own.
func _chain_tier(chain: int) -> int:
	var t := 0
	for i in CHAIN_TIER_AT.size():
		if chain >= int(CHAIN_TIER_AT[i]):
			t = i
		else:
			break
	return t


func _cells(tier: int) -> int:
	return int(TIERS[tier]["w"]) * int(TIERS[tier]["h"])


func _tier_name(tier: int) -> String:
	return "%dx%d block" % [TIERS[tier]["w"], TIERS[tier]["h"]]


## Brand a block with the tail of `word`, steering away from stamps this player
## is already staring at or has just been hit with.
func _mint_stamp(word: String, want: int, defender: SideState) -> String:
	var avoid := {}
	for s: String in defender.board.prefixes():
		avoid[s] = true
	for p: Pending in defender.pending:
		avoid[p.prefix] = true
	for s: String in recent_stamps:
		avoid[s] = true

	var stamp := WordBank.stamp_from_tail(word, want, STAMP_MIN_VALID, STAMP_MIN_COMMON, avoid)
	recent_stamps.push_front(stamp)
	if recent_stamps.size() > RECENT_STAMP_MEMORY:
		recent_stamps.resize(RECENT_STAMP_MEMORY)
	return stamp


func _reach(word: String) -> int:
	return WWBoard.reach(word)


## Blocks `word` would remove right now: landed ones first, then interceptions,
## both drawing on the same reach.
func _preview_hits(side: SideState, word: String) -> int:
	if word.length() < MIN_WORD_LEN:
		return 0
	var budget := _reach(word)
	var n := side.board.would_clear(word, budget)
	budget -= n
	for p: Pending in side.pending:
		if budget <= 0:
			break
		if p.prefix != "" and word.begins_with(p.prefix):
			n += 1
			budget -= 1
	return n


## Everything the word opens, whether it can reach that far or not.
func _preview_matches(side: SideState, word: String) -> int:
	if word.length() < MIN_WORD_LEN:
		return 0
	var n := side.board.total_matching(word)
	for p: Pending in side.pending:
		if p.prefix != "" and word.begins_with(p.prefix):
			n += 1
	return n


# --------------------------------------------------------------------- runtime

func _process(delta: float) -> void:
	# Measured against the wall clock, not `delta` — `delta` is the thing being
	# slowed, so a freeze timed with it would never end.
	if Time.get_ticks_msec() < _hitstop_until:
		Engine.time_scale = HITSTOP_SCALE
	elif Engine.time_scale != 1.0:
		Engine.time_scale = 1.0

	for i in range(tracers.size() - 1, -1, -1):
		var tr: Tracer = tracers[i]
		tr.t += delta / tr.span
		if tr.t >= 1.0:
			_tracer_impact(tr)
			tracers.remove_at(i)

	for s: SideState in sides:
		var w := _typing_of(s)
		s.board.highlight_word = w
		s.board.highlight_limit = _reach(w) if w.length() >= MIN_WORD_LEN else 0

	message_life = maxf(0.0, message_life - delta)

	# The counter chases the real total instead of snapping to it, and the kick
	# fattens the type for a moment when it moves.
	score_shown = lerpf(score_shown, float(player.score), clampf(delta * 7.0, 0.0, 1.0))
	score_kick = maxf(0.0, score_kick - delta * 2.4)
	var live_pops: Array = []
	for p: Dictionary in score_pops:
		p["life"] = float(p["life"]) - delta * 0.85
		if p["life"] > 0.0:
			live_pops.append(p)
	score_pops = live_pops

	var live_flecks: Array = []
	for f: Dictionary in _key_flecks:
		f["life"] = float(f["life"]) - delta * 1.7
		if f["life"] > 0.0:
			live_flecks.append(f)
	_key_flecks = live_flecks

	var live_powers: Array = []
	for p: Dictionary in power_pops:
		p["life"] = float(p["life"]) - delta * 0.62
		if p["life"] > 0.0:
			live_powers.append(p)
	power_pops = live_powers

	# Shake the world, then hold the menus still on top of it.
	shake = maxf(0.0, shake - delta * 2.6)
	flash = maxf(0.0, flash - delta * 1.8)
	var kick := Vector2.ZERO
	if shake > 0.0:
		kick = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake * 16.0
	position = kick
	_overlay.position = -kick

	for e: Dictionary in events:
		e["life"] = maxf(0.0, e["life"] - delta * 0.12)
	player.flash = maxf(0.0, player.flash - delta * 2.0)
	ai_side.flash = maxf(0.0, ai_side.flash - delta * 2.0)
	player.salvo_flash = maxf(0.0, player.salvo_flash - delta * 2.2)
	ai_side.salvo_flash = maxf(0.0, ai_side.salvo_flash - delta * 2.2)
	player.life_flash = maxf(0.0, player.life_flash - delta * 0.9)
	ai_side.life_flash = maxf(0.0, ai_side.life_flash - delta * 0.9)

	if phase == Phase.SPLASH:
		splash_time += delta
		if splash_time >= SPLASH_HOLD + SPLASH_FADE:
			phase = Phase.TITLE

	if phase == Phase.OVER:
		over_age += delta

	# The playfields have nothing to say on the front-of-house screens.
	var showing_boards := phase != Phase.SPLASH and phase != Phase.TITLE \
		and phase != Phase.LOBBY and phase != Phase.MASTERY \
		and phase != Phase.SOLO and phase != Phase.SETTINGS \
		and phase != Phase.PRACTICE and phase != Phase.COSMETICS
	for s: SideState in sides:
		# There is no rival in a lesson or a practice run, so its board is not
		# drawn at all — an empty playfield sitting there reads as an opponent
		# who is somehow doing nothing.
		s.board.visible = showing_boards and s.in_match \
			and (mode == Mode.NORMAL or s.slot == 0) \
			and (not portrait or s.slot == 0)
	if phase != Phase.PLAY:
		_step_decor(delta)

	if phase == Phase.COUNTDOWN:
		countdown -= delta
		var mark := int(ceil(countdown))
		if mark != _last_count_beep and mark > 0:
			_last_count_beep = mark
			Sfx.play("count", 1.0 + 0.10 * (3 - mark))
		if countdown <= 0.0:
			phase = Phase.PLAY
			Sfx.play("start")
			_log("GO!", Color("#ffd166"))

	if phase == Phase.PLAY and paused and not net_active():
		# Solo: the world waits.
		_tick_music(delta)
		queue_redraw()
		_overlay.queue_redraw()
		return

	if phase == Phase.PLAY:
		match_time += delta
		# The daily ends on the clock, not on a winner. Three minutes is the
		# whole of the contest, so it is checked before anything else can move.
		if mode == Mode.DAILY and daily_left() <= 0.0:
			_finish_daily()
		for s: SideState in sides:
			if not s.in_match or not s.alive:
				continue
			if s.chain_timer > 0.0:
				s.chain_timer -= delta
				if s.chain_timer <= 0.0:
					# Losing a run you had going should sting audibly.
					if s == player and s.chain >= 2:
						Sfx.play("lapse")
					s.chain = 0
					s.chain_fill = 0.0
		if mode == Mode.TUTORIAL:
			_lesson_tick(delta)
		_tick_focus()
		_tick_danger(player)
		_tick_pending(player, delta)
		_tick_pressure(delta)
		if net_active():
			# Other people's boards are mirrored, not simulated. Bots are the
			# exception: the host runs them like any local opponent.
			for s: SideState in sides:
				if s.bot != null and s.in_match and s.alive:
					_tick_pending(s, delta)
			_tick_bots(delta)
			_push_state(delta)
		else:
			for s: SideState in sides:
				if s != player and s.in_match and s.alive:
					_tick_pending(s, delta)
			_tick_bots(delta)
		# Somebody may have just been knocked out.
		_aim_everyone()

	_tick_music(delta)
	queue_redraw()
	_overlay.queue_redraw()


## Picks the bed from what is actually happening. Escalation is instant so the
## music arrives with the danger; calming back down has to wait out `MUSIC_HOLD`,
## because a board that dips below the line for half a second has not really
## recovered and swapping back would just sound indecisive.
func _tick_music(delta: float) -> void:
	_music_hold = maxf(0.0, _music_hold - delta)

	var want := "menu"
	match phase:
		Phase.SPLASH, Phase.TITLE, Phase.SOLO, Phase.LOBBY, Phase.MASTERY, Phase.SETTINGS, \
				Phase.PRACTICE, Phase.COSMETICS:
			want = "menu"
		Phase.COUNTDOWN:
			want = "main"
		Phase.OVER:
			want = "victory" if winner == "YOU" else "death"
		Phase.PLAY:
			want = "main"
			if player.alive and player.respite <= 0.0:
				var headroom := player.board.stack_top()
				if headroom < MUSIC_CLUTCH_ROWS:
					want = "clutch"
				elif headroom < MUSIC_CRITICAL_ROWS:
					want = "critical"

	if want == _music_key:
		return
	# Rising tension takes hold at once; relaxing has to earn it.
	var rank := {"main": 0, "critical": 1, "clutch": 2}
	if rank.has(want) and rank.has(_music_key) \
			and rank[want] < rank[_music_key] and _music_hold > 0.0:
		return

	_music_key = want
	_music_hold = MUSIC_HOLD
	match want:
		"death":
			Music.play("death", false)
		"victory":
			Music.play("victory", false)
		_:
			Music.play(want)


## Being ganged up on is the one thing in a four-way you have to answer, and it
## was completely silent — the blocks simply got bigger. Said once when it starts
## and once when it stops, like the danger alarm, because a warning that repeats
## every frame is a warning nobody reads.
func _tick_focus() -> void:
	if slots_in_play < 3 or not player.alive:
		return
	var on_me := 0
	for s: SideState in sides:
		if s != player and s.in_match and s.alive and s.target == player.slot:
			on_me += 1
	if on_me == player.focused_by:
		return
	if on_me >= 2 and player.focused_by < 2:
		_say("%d ON YOU — their blocks are bigger" % on_me, Color("#ff6b6b"))
		Sfx.play("danger", 1.15)
		Haptics.fire("danger")
	elif on_me < 2 and player.focused_by >= 2:
		_say("no longer focused", Color("#8892b0"))
	player.focused_by = on_me


## Sound the alarm once on the way into the red, not every frame you sit there.
func _tick_danger(side: SideState) -> void:
	var danger := side.board.stack_top() <= 3
	if danger and not side.in_danger:
		Sfx.play("danger")
		if side == player:
			Haptics.fire("danger")
	side.in_danger = danger


func _tick_pending(side: SideState, delta: float) -> void:
	if side.respite > 0.0:
		side.respite -= delta
		return
	# A CLUTCH does not stop the garbage, it slows it. A stay of execution rather
	# than a pardon — you still have to type your way out.
	var rate := 1.0
	if side.slowdown > 0.0:
		side.slowdown -= delta
		rate = CLUTCH_RATE
	for i in range(side.pending.size() - 1, -1, -1):
		var p: Pending = side.pending[i]
		p.timer -= delta * rate
		if p.timer <= 0.0:
			side.pending.remove_at(i)
			var spec: Dictionary = TIERS[p.tier]
			var fit: bool = side.board.add_garbage(p.prefix, p.tier, spec["w"], spec["h"],
				p.kind)
			side.board.shake = maxf(side.board.shake, 0.5)
			# Bigger blocks land lower and louder.
			Sfx.play("land", 1.15 - 0.09 * p.tier,
				(-1.0 if side == player else -7.0) + p.tier * 0.6)
			if side == player:
				Haptics.fire("land", 0.7 + 0.12 * float(p.tier))
			if not fit:
				_credit_topout(p.from, side)
				_lose_life(side)
				return


func _tick_pressure(delta: float) -> void:
	# The lesson decides when anything arrives. A clock ticking underneath a
	# step that is waiting for the player would undo the step.
	if mode == Mode.TUTORIAL:
		return
	pressure_timer -= delta
	if pressure_timer > 0.0:
		return
	if mode == Mode.TRAINING:
		# A fixed pace, because the point is to practise at a speed you chose.
		pressure_timer = float(TRAINING_PACE[train_pace]["every"])
	else:
		pressure_interval = maxf(PRESSURE_MIN, pressure_interval - PRESSURE_STEP)
		pressure_timer = pressure_interval

	# Both peers run the clock so both HUDs agree, but only the host decides when
	# it actually fires — otherwise the two boards drift apart.
	if net_active() and not Link.is_host:
		return
	var source := WordBank.random_common()
	if net_active():
		Link.send_pressure(source)
	_seed_pressure(source)


## One seed per board. Each side mints its own stamp from the shared word, so the
## stamps stay varied against whatever that player is already holding.
func _seed_pressure(source: String) -> void:
	# Every board this machine is responsible for: your own, plus any bots you
	# are running. Everyone else seeds their own from the same shared word.
	# This used to name `player` and `ai_side` outright, which quietly left the
	# third and fourth boards out of the ambient pressure entirely — a free ride
	# for two of the three CPUs in every free-for-all.
	var fed := 0
	for side: SideState in sides:
		if not side.in_match or not side.alive or not _owned_here(side):
			continue
		# A reprieve means nothing NEW arrives either, or the mercy is hollow.
		if side.slowdown > 0.0:
			continue
		var p := Pending.new()
		p.tier = 0
		p.prefix = _mint_stamp(source, STAMP_WANT, side)
		p.cells = _cells(0)
		p.timer = DROP_DELAY
		side.pending.append(p)
		fed += 1
	if fed > 0:
		_log("pressure rising — every board seeded", Color("#8892b0"))


## Every bot runs its own search against its own board and its own victim.
func _tick_bots(delta: float) -> void:
	for s: SideState in sides:
		if s.bot == null or not s.in_match or not s.alive:
			continue
		s.bot_switch -= delta
		if s.bot_switch <= 0.0:
			# Bots wander their aim, so a four-way is not three guns on one board.
			# How long each one stays put is part of its personality: a grudge
			# holder picks a victim and works on them.
			s.bot_switch = s.bot.attention_span()
			_aim(s, _pick_target_for(s))

		var targets := s.board.prefixes()
		for p: Pending in s.pending:
			targets.append(p.prefix)
		var word := s.bot.update(delta, targets, s.used, s.chain_timer, _peril(s))
		if s.bot.fumbled:
			s.bot.fumbled = false
			if s.chain >= 2:
				_log("%s fumbled — chain x%d broken" % [s.label, s.chain], Color("#8892b0"))
			s.chain = 0
			s.chain_fill = 0.0
			s.chain_timer = 0.0
		if word != "":
			_play_word(s, word)


## A volatile block reached the end of its fuse. It does not clear itself — it
## drops a fresh block on the board that left it there, which is the whole
## bargain: answer it, or answer it and one more.
func _on_volatile_blew(_at: Vector2, side: SideState) -> void:
	var p := Pending.new()
	p.tier = 0
	p.prefix = _mint_stamp(WordBank.random_common(), STAMP_WANT, side)
	p.cells = 1
	p.timer = 0.9
	side.pending.append(p)
	side.flash = 1.0
	if side == player:
		shake = maxf(shake, 0.3)
		_bloom(Color("#f94144"), 0.14)
		_say("a volatile block went off", Color("#f94144"))
	_log("%s: a volatile block went off" % side.label, Color("#f94144"))


# ------------------------------------------------------------------- the lesson
#
# Nothing here advances on a timer. Every step ends because the player did the
# thing, so nobody is ever carried past a rule they have not got yet — and being
# slow costs a first-time player nothing.

## Set up whatever situation the current step needs. Called once when the step
## arrives; `lesson_age` is how long it has been up, which is only used to let a
## board settle before checking anything.
func _lesson_begin() -> void:
	lesson_age = 0.0
	lesson_done = false
	var step: Dictionary = Tutorial.step(lesson)
	if step.is_empty():
		return
	player.pending.clear()

	match String(step["id"]):
		"tail":
			# The block they are about to see is branded with the tail of the
			# word they just played. That is the rule, demonstrated on their own
			# word rather than on an example.
			var tail := _lesson_word.substr(maxi(0, _lesson_word.length() - 3))
			player.board.add_garbage(tail if tail != "" else "sh", 1, 2, 1)
		"answer":
			player.board.reset()
			player.board.add_garbage("ship", 2, 2, 2)
		"reach":
			player.board.reset()
			for i in 3:
				player.board.add_garbage("al", 1, 1, 1)
		"chain":
			player.board.reset()
			player.chain = 0
			player.chain_fill = 0.0
			player.chain_timer = 0.0
		"danger":
			player.board.reset()
			# Two rows short of the ceiling: alarming, survivable, and every
			# block answerable by a word somebody will already know.
			for w in ["st", "co", "re", "in", "de", "pr", "ma", "tr", "un", "ca",
					"pl", "sh", "gr", "br"]:
				player.board.add_garbage(w, 0, 1, 1)
		_:
			pass


## Has the current step been satisfied? Read every frame; the answer is allowed
## to be "not yet" forever.
func _lesson_check() -> bool:
	var step: Dictionary = Tutorial.step(lesson)
	if step.is_empty():
		return false
	match String(step["id"]):
		"fire":
			return player.words_played >= 1
		"tail":
			# Purely something to look at, so a beat of reading time and one
			# more word moves it on.
			return lesson_age > 1.2 and player.words_played >= 2
		"answer":
			return player.board.blocks.is_empty()
		"reach":
			return player.board.blocks.is_empty()
		"chain":
			return player.chain >= 4
		"danger":
			return player.board.stack_top() >= WWBoard.ROWS - 3
		"done":
			return false     # ends on the key, not on a condition
	return false


func _lesson_tick(delta: float) -> void:
	lesson_age += delta
	if lesson_done:
		return
	if not _lesson_check():
		return
	lesson_done = true
	Sfx.play("power", 1.2)
	_bloom(Color("#7bdff2"), 0.16)


## Move on. Called from the same key that fires a word, so the lesson never
## needs a control of its own.
func _lesson_next() -> void:
	if lesson >= Tutorial.count() - 1:
		_finish_lesson()
		return
	lesson += 1
	_lesson_begin()
	Sfx.play("count", 1.2)


## The clock ran out, or the lives did. Either way the run is spent for today.
##
## Banked before the summary is drawn, and banked whichever way it ended, so
## quitting out of a bad run is not a way to get a second go at the same board.
func _finish_daily() -> void:
	phase = Phase.OVER
	over_age = 0.0
	typed = ""
	_hover_action = ""
	_clear_hitstop()
	tracers.clear()
	winner = "YOU"
	Profile.record_daily(daily_key(), player.score, int(round(_wpm())),
		player.words_played, player.best_chain)
	earned = {}
	Sfx.play("win")
	Haptics.fire("win")
	WordBank.free_run()


func _finish_lesson() -> void:
	Sfx.play("win")
	_say("lesson complete", Color("#ffd166"))
	phase = Phase.PRACTICE
	mode = Mode.NORMAL
	_hover_action = ""
	Profile.set_pref("taught", true)


## How close a board is to topping out — 0 calm, 1 drowning. The bots read this
## so a personality stays a tendency rather than a suicide note: the ones that
## never defend still start defending when the stack reaches the ceiling.
func _peril(s: SideState) -> float:
	# Inbound garbage counts against the headroom. A board that looks calm with
	# six cells already falling towards it is not calm.
	var headroom: float = float(s.board.stack_top()) - float(s.pending_cells()) * 0.15
	return clampf(1.0 - headroom / float(WWBoard.ROWS), 0.0, 1.0)


## Hitting the ceiling wipes the board and costs a life. The wipe is the whole
## point: you get a clean board back, but the pressure clock never rewinds, so
## the third life is played under conditions the first never saw.
func _lose_life(side: SideState) -> void:
	# Practice you can fail is not practice. The board still comes apart — that
	# is the feedback — but nothing is spent and the run carries on. The daily
	# is not practice: it has real lives, and running out ends the run early.
	if mode == Mode.DAILY:
		side.lives -= 1
		side.chain = 0
		side.chain_fill = 0.0
		side.chain_timer = 0.0
		side.pending.clear()
		side.board.reset()
		side.respite = RESPITE
		side.life_flash = 1.0
		Sfx.play("lose")
		Haptics.fire("life")
		if side.lives <= 0:
			_finish_daily()
		return
	if mode != Mode.NORMAL:
		side.chain = 0
		side.chain_fill = 0.0
		side.chain_timer = 0.0
		side.pending.clear()
		side.respite = RESPITE
		side.life_flash = 1.0
		side.in_danger = false
		side.board.detonate()
		shake = maxf(shake, 0.7)
		_say("topped out — board cleared, carry on", Color("#ffd166"))
		return
	side.lives -= 1
	side.chain = 0
	side.chain_fill = 0.0
	side.chain_timer = 0.0
	side.pending.clear()
	side.respite = RESPITE
	side.life_flash = 1.0
	side.in_danger = false

	# Take the whole board apart rather than blinking it out of existence.
	side.board.detonate()
	shake = maxf(shake, 0.7)

	if side.lives <= 0:
		side.alive = false
		side.pending.clear()
		_log("%s is out" % side.label, Color("#ff6b6b"))
		if side == player and net_active():
			Link.send_topped_out()
		_aim_everyone()
		var standing := _living()
		if standing.size() <= 1:
			_end_match(side)
		elif side == player:
			# You are out, but the match is not: keep watching.
			_say("you are out — %d still standing" % standing.size(), Color("#ff6b6b"))
			Music.play("death", false, "main")
			_music_key = "main"
			_music_hold = MUSIC_HOLD
		return

	var mine := side == player
	Sfx.play("lose" if mine else "land", 1.0 if mine else 0.7, 0.0 if mine else -6.0)
	if mine:
		Haptics.fire("life")
		_bloom(Color("#ff6b6b"), 0.35)
		_say("BOARD LOST — %d %s left" % [side.lives, "life" if side.lives == 1 else "lives"],
			Color("#ff6b6b"))
	_log("%s topped out — %d %s left" % [
		side.label, side.lives, "life" if side.lives == 1 else "lives"], Color("#ff6b6b"))


func _end_match(loser: SideState) -> void:
	phase = Phase.OVER
	over_age = 0.0
	# Whatever was half-typed when it ended is not a command for this screen.
	typed = ""
	_hover_action = ""
	_clear_hitstop()
	tracers.clear()
	var standing := _living()
	if standing.size() == 1:
		winner = "YOU" if standing[0] == player else standing[0].label
	else:
		winner = "YOU" if loser != player else (
			ai_side.label if net_active() else "CPU")
	loser.board.shake = 1.0

	# Taking the match is worth points, and how comfortably you took it is worth
	# more. Without this a win and a loss scored the same, which is why the
	# scoreboard could crown somebody who had just lost.
	if mode == Mode.NORMAL and winner == "YOU" and player.alive:
		var lives_left: int = maxi(0, player.lives)
		var spoils: int = Scoring.WIN_BONUS + lives_left * Scoring.LIFE_BONUS
		player.score += spoils
		_pop_score("+%s" % _commas(spoils), "VICTORY", spoils)
		score_kick = 1.0
		_log("victory — +%s (%d %s left)" % [_commas(spoils), lives_left,
			"life" if lives_left == 1 else "lives"], Color("#ffd166"))

	Sfx.play("win" if winner == "YOU" else "lose")
	Haptics.fire("win" if winner == "YOU" else "lose")
	_log("%s wins" % winner, Color("#ffd166"))
	if mode == Mode.NORMAL:
		_record_mastery()


## Fold the finished match into the lifetime record, and keep what it earned so
## the end screen can show it. Done here rather than as the match runs, so a
## match abandoned halfway banks nothing — the level has to mean matches played
## through, or it means nothing.
func _record_mastery() -> void:
	# Counted alongside the record, so it moves for exactly the matches that
	# count as matches — a tutorial or a practice run is not an ad break.
	Profile.note_match_for_ads()
	var was_xp := Profile.xp_total()
	var was_level := Profile.level()
	var was_unlocked := Profile.unlocked_set()

	Profile.record_match({
		"won": winner == "YOU",
		# Winning without spending a single life. The hardest of the flags and
		# the only one that gates two cosmetics.
		"flawless": winner == "YOU" and player.lives >= LIVES,
		"words": player.words_played,
		"chars": chars_typed,
		"salvos": player.salvos,
		# COMBO fires on exactly "three or more broken by one word", so it is
		# already the multi-clear count; deriving it beats keeping a second
		# tally that could disagree with the first.
		"multi_clears": int(player.power_tally.get("COMBO", 0)),
		"wpm": _wpm(),
		"chain": player.best_chain,
		"combo": player.best_combo,
		"score": player.score,
		"longest": player.longest_word,
		"powers": player.power_tally,
	})

	var fresh: Array = []
	var now := Profile.unlocked_set()
	for slot: String in Profile.SLOTS:
		for id in now[slot]:
			if not (was_unlocked[slot] as Array).has(id):
				fresh.append("%s: %s" % [String(Profile.SLOT_NAMES[slot]),
					String(Profile.entry(slot, String(id))["name"]).to_upper()])
	earned = {
		"xp": Profile.xp_total() - was_xp,
		"from": was_level,
		"to": Profile.level(),
		"new": fresh,
	}
	if not fresh.is_empty() or Profile.level() > was_level:
		Sfx.play("salvo", 1.15)
		Haptics.fire("level")


## Gross words per minute, the way a typing test counts it: every five characters
## entered is one "word", including the ones you backspaced away.
func _wpm() -> float:
	if match_time < 1.0 or chars_typed == 0:
		return 0.0
	return (float(chars_typed) / 5.0) / (match_time / 60.0)


## Everything the game echoes back at the player passes through here. Your own
## line as you type it does not — you have to be able to see what you are
## entering — but the moment it is repeated anywhere, it is masked.
func _show(text: String) -> String:
	return Censor.clean(text) if fx_censor else text


## For names, which are the one piece of free text in the game and therefore the
## one place somebody can punctuate their way around a word list.
func _show_name(text: String) -> String:
	return Censor.clean_name(text) if fx_censor else text


func _say(text: String, color: Color) -> void:
	message = _show(text)
	message_color = color
	message_life = 2.2


func _log(text: String, color: Color) -> void:
	events.push_front({"text": _show(text), "color": color, "life": 1.0})
	if events.size() > 7:
		events.resize(7)


# --------------------------------------------------------------------- drawing

func _draw() -> void:
	var size := get_viewport_rect().size
	var m := SHAKE_MARGIN
	draw_rect(Rect2(-m, -m, size.x + m * 2.0, size.y + m * 2.0), bg_top, true)
	# Soft vertical wash so the board area lifts off the background.
	for i in 24:
		var t := float(i) / 24.0
		draw_rect(Rect2(-m, size.y * t, size.x + m * 2.0, size.y / 24.0 + 1.0),
			bg_top.lerp(bg_bottom, t), true)
	draw_rect(Rect2(-m, size.y, size.x + m * 2.0, m), bg_bottom, true)

	# A bloom behind the playfield, for themes that carry one. Drawn as a few
	# soft discs rather than a shader so it costs nothing and works on the
	# compatibility renderer — the point is that the backdrop is lit rather than
	# a flat wash, which is most of the difference between a theme and a filter.
	if _glow_a > 0.0:
		var at := Vector2(size.x * 0.5, size.y * (0.44 if portrait else 0.46))
		var reach: float = maxf(size.x, size.y) * 0.55
		for i in 7:
			var f := float(i) / 6.0
			draw_circle(at, reach * (0.30 + f * 0.70),
				Color(_glow, _glow_a * 0.10 * (1.0 - f)))

	if phase != Phase.COUNTDOWN and phase != Phase.PLAY and phase != Phase.OVER:
		return

	if portrait:
		_draw_portrait_hud(size)
	else:
		_draw_side_header(player, player.board.position)
		_draw_chain_meter(player)
		_draw_pending(player, false)
		for s: SideState in sides:
			if s.slot > 0 and s.in_match and mode == Mode.NORMAL:
				_draw_rival_panel(s)
	# The summary covers the same ground and sits in the same column, so leaving
	# the live readout underneath it just prints two scores on top of each other.
	if phase != Phase.COUNTDOWN and phase != Phase.OVER and mode == Mode.NORMAL \
			and not portrait:
		_draw_center_hud(size)
	if not portrait:
		_draw_player_input(size)
	# Last, so an attack crossing the screen passes over the boards rather than
	# under them, and on the world canvas so it moves with the shake.
	_draw_tracers()


# --------------------------------------------------------------- the keyboard
#
# A drawn keyboard rather than the system one. Everything in this game is
# already custom `_draw`, so this is the same kind of code as the rest of it —
# and it buys two things the iOS keyboard cannot give: no autocorrect fighting a
# 350k-word dictionary, and a layout that cannot shove the board about as it
# appears.
#
# It used to buy a third. Keys were dimmed when no word began that way and lit
# when they opened a stamp you were facing, on the theory that typing at a third
# your desktop speed should be paid back in information. Played on a phone it
# reads as the keyboard flickering under your thumbs while you are trying to
# read the board — twenty-six keys changing colour on every keystroke is motion
# in the exact part of the screen you are not looking at. The information was
# real and the distraction was worse, so the keys are plain now.

## Which key is held down, for the pressed look. Cleared on release, so a
## finger slid off a key does not leave it looking stuck.
var _key_down := ""


# -------------------------------------------------------------- the back key
#
# A phone has no Escape. Every screen in this game was reachable only by
# pressing it, which on desktop is so obvious it is not worth a button and on
# glass means the first menu you open is the last one you ever see. So portrait
# grows one control the keyboard version does not need.
#
# It is deliberately the same button everywhere rather than a "leave lobby" here
# and a "back to menu" there: one corner, one meaning, learned once. What it
# does is whatever Escape does on the screen you are looking at, read off the
# same phase table, so the two cannot drift apart.
#
# There is no quit. iOS apps are not supposed to have one — you leave with the
# home gesture — so on the title screen, where Escape quits on desktop, the
# button simply is not drawn.

## What the back button would do here, or "" if this screen has no way back.
func _back_action() -> String:
	if phase == Phase.PLAY:
		return "" if paused else "pause"
	# The rules cover the title screen whole, and on a phone H is not a key you
	# have — so without this the only door in is a door with no way out.
	if phase == Phase.TITLE and show_rules:
		return "rules"
	match phase:
		Phase.PRACTICE, Phase.SOLO, Phase.MASTERY, Phase.SETTINGS, Phase.OVER, \
				Phase.COSMETICS:
			return "title"
		Phase.LOBBY:
			return "leave" if Link.connected else "title"
	return ""


## Top-left, below the notch, and 64 across — Apple's own floor for a touch
## target is 44 and this one is pressed in a hurry.
func _back_rect() -> Rect2:
	return Rect2(16.0, safe_top + 14.0, 64.0, 64.0)


## The pitch and height of one stacked title door, and where the stack starts.
const PORTRAIT_DOOR_PITCH := 104.0
const PORTRAIT_DOOR_H := 92.0

## Breathing room down each side of every card grid.
const GRID_MARGIN := 36.0


## How much bigger a menu's rows can afford to be.
##
## Every screen here was laid out in design units tuned for a 720px landscape
## window, and portrait then hands it a space twice as tall. In a match that is
## fine — the keyboard takes the bottom third — but Practice, Solo, Mastery and
## Cosmetics have no keyboard, so a layout built for 720 sat in the top third of
## the phone with a band of nothing under it.
##
## Rather than a second set of constants per screen, each one states how tall it
## naturally is and gets back a factor. Card heights and gaps are multiplied by
## it, and because `_draw_plate` already picks its type size from the height it
## is given, the text grows with the plate rather than needing its own pass.
##
## Capped, because a screen with two rows on it should fill the space, not turn
## into two slabs the size of a hand.
func _menu_fill(natural: float, cap: float = 1.3) -> float:
	if not portrait or natural <= 1.0:
		return 1.0
	var top: float = 214.0 + safe_top
	var avail: float = get_viewport_rect().size.y - safe_bottom - top - 48.0
	return clampf(avail / natural, 1.0, cap)


## Where a menu's content should start so it sits in the middle of what is left,
## rather than at the top of it.
##
## The factors above make the rows bigger and push them apart, but a factor
## cannot know where the block actually ended up — the first attempt spread the
## gaps by a number that looked right and still left a third of the phone empty
## underneath. This measures the laid-out block instead and centres it, which is
## the part that makes a short screen stop looking like it fell to the top.
##
## Biased slightly high, because a menu that sits dead centre reads as floating
## while one a little above centre reads as placed.
func _menu_offset(laid: float) -> float:
	if not portrait:
		return 0.0
	var top: float = 214.0 + safe_top
	var avail: float = get_viewport_rect().size.y - safe_bottom - top - 40.0
	return maxf(0.0, (avail - laid) * 0.30)


## The other half of filling a screen, and the half that was wrong first time.
##
## Inflating every row until the content reached the bottom turned two doors
## into two letterboxes with small text stranded in them. A row has a natural
## proportion and wants to grow a little; the space left over belongs in the
## gaps between rows, which is what spreads a short menu down a tall phone
## without making any single thing absurd.
func _menu_spread(natural: float, cap: float = 3.2) -> float:
	if not portrait or natural <= 1.0:
		return 1.0
	var top: float = 214.0 + safe_top
	var avail: float = get_viewport_rect().size.y - safe_bottom - top - 48.0
	return clampf(avail / natural, 1.0, cap)


## Fit `count` cards into the width actually available, centred, in as many rows
## as that takes.
##
## Every menu in this game is a centred strip of fixed-width cards, and every one
## of them was written against 1280px. On a 720px screen they ran off both edges
## — mastery's record strip was eight 138px tiles in a row that needed 1168.
##
## `want_cols` and `want_w` are what the desktop layout asks for and it still
## gets exactly that, because at 1280 nothing here binds. Narrower, cards shrink
## until they would go under `min_w`, and only then does a column get dropped and
## the rest widen to fill the row. That order matters: four seats that wrap to
## 3 + 1 read as a broken table, while four narrower seats read as a table.
##
## One helper for all of them, so a grid cannot be reflowed for portrait and
## another quietly left behind.
func _grid_rects(count: int, top: float, want_cols: int, want_w: float, ch: float,
		gap: float = 10.0, min_w: float = 0.0, vgap: float = 10.0) -> Array:
	var size := get_viewport_rect().size
	var usable: float = maxf(120.0, size.x - GRID_MARGIN * 2.0)
	var cols: int = maxi(1, mini(want_cols, count))
	while cols > 1 and (usable - gap * float(cols - 1)) / float(cols) < min_w:
		cols -= 1
	var room: float = (usable - gap * float(cols - 1)) / float(cols)
	# Only widen past the desktop width when columns had to be given up — a full
	# row of the intended count keeps the intended size.
	var cw: float = minf(want_w, room) if cols >= mini(want_cols, count) else room

	var out: Array = []
	for i in count:
		var row: int = i / cols
		var col: int = i % cols
		var wide: int = mini(cols, count - row * cols)
		var span: float = float(wide) * cw + float(wide - 1) * gap
		out.append(Rect2(size.x * 0.5 - span * 0.5 + float(col) * (cw + gap),
			top + float(row) * (ch + vgap), cw, ch))
	return out


## The bottom edge of a grid, for laying out whatever comes under it.
func _grid_bottom(rects: Array, fallback: float) -> float:
	if rects.is_empty():
		return fallback
	return (rects[rects.size() - 1] as Rect2).end.y

## Centred between the wordmark and the bottom of the safe area rather than
## fixed at 620. Once the viewport expands to the real screen instead of a 1:2
## design space, a constant that sat right on one phone leaves a void on the
## next — a Pro Max is 124 units taller than the base, and all of it was
## collecting under the last door.
func _portrait_menu_top(doors: int) -> float:
	var stack := float(doors) * PORTRAIT_DOOR_PITCH - (PORTRAIT_DOOR_PITCH - PORTRAIT_DOOR_H)
	# The stack plus the two hint lines under it, which travel with it.
	# The stack, the "tap to choose" line and the rules door under it, which all
	# travel together.
	var block := stack + 120.0
	var head := 210.0 + safe_top
	var avail: float = (get_viewport_rect().size.y - safe_bottom - 24.0) - head
	return head + maxf(0.0, (avail - block) * 0.5)


func _draw_back_button() -> void:
	var act := _back_action()
	if act == "":
		return
	var r := _back_rect()
	var accent := Color("#8892b0") if act != "pause" else PLAYER_ACCENT
	_panel(r, Color("#141b33"), Color(accent, 0.45), 10.0, 1.5)
	var c := r.get_center()
	if act == "pause":
		# Two bars. Drawn rather than typed, because a glyph for this is not
		# something either font can be relied on to have.
		_overlay.draw_rect(Rect2(c.x - 9.0, c.y - 11.0, 6.0, 22.0), accent, true)
		_overlay.draw_rect(Rect2(c.x + 3.0, c.y - 11.0, 6.0, 22.0), accent, true)
	else:
		var w := 8.0
		var h := 11.0
		_overlay.draw_line(c + Vector2(w * 0.5, -h), c + Vector2(-w * 0.5, 0.0), accent, 3.0)
		_overlay.draw_line(c + Vector2(-w * 0.5, 0.0), c + Vector2(w * 0.5, h), accent, 3.0)


## Runs the back button. Kept apart from `_activate` because two of the things
## it does — closing the name field, pausing — are not menu actions at all.
func _press_back() -> void:
	var act := _back_action()
	if act == "":
		return
	if phase == Phase.SETTINGS:
		_buy_armed = false
	if phase == Phase.SETTINGS and settings_editing:
		# The name field has the keyboard; back closes that before it closes the
		# screen, or a rename is thrown away by the gesture that confirms it.
		settings_editing = false
		_hide_keyboard()
		Sfx.play("back")
		return
	if act == "pause":
		Haptics.fire("tap")
		_toggle_pause()
		return
	# Everything else routes through `_activate`, which owns its own sound.
	_activate(act)


## The keys, positioned against the current screen. One source for drawing and
## for hit-testing, the same rule the menus follow.
func _keyboard() -> Array:
	return Keyboard.keys(get_viewport_rect().size, _keyboard_bottom())


func _draw_keyboard() -> void:
	var accent := PLAYER_ACCENT
	for k: Dictionary in _keyboard():
		var r: Rect2 = k["rect"]
		var id: String = k["id"]
		var down: bool = _key_down == id
		if down:
			r = Rect2(r.position + Vector2(0, 3), r.size - Vector2(0, 3))

		var bg := _key_bg
		var edge := Color(_key_edge, 0.18)
		var ink := _key_ink
		match id:
			"fire":
				bg = _fire_bg if not down else _fire_bg.lightened(0.18)
				edge = Color(_fire_edge, 0.75)
			"back":
				bg = _key_bg.darkened(0.25) if not down else _key_bg.lightened(0.10)
				edge = Color("#c77dff", 0.5)
		if down:
			bg = bg.lightened(0.12)
		_panel(r, bg, edge, 9.0, 2.0)
		_otext(_font_bold, r.get_center(), String(k["label"]),
			26 if id.length() == 1 else 19, ink)


# --------------------------------------------------- the system keyboard
#
# The drawn keyboard is for the match, and only for the match. The lobby and the
# settings screen have text fields — your name, and a room code — and those
# needed the system one instead, for two reasons the drawn one cannot meet: a
# room code has digits and punctuation in it, and it arrives by being pasted out
# of a chat window rather than by being typed at all.
#
# Godot delivers what is typed on it as ordinary key events, so `_lobby_edit` and
# the settings branch below carry on working unchanged and there is no second
# implementation of what a keystroke means.

var _vk_open := false


## Raise it for a field holding `text`. Silently does nothing where there is no
## virtual keyboard, which is every desktop — the field is already typeable there.
func _show_keyboard(text: String) -> void:
	if not portrait or not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return
	DisplayServer.virtual_keyboard_show(text, Rect2i(), DisplayServer.KEYBOARD_TYPE_DEFAULT,
		48, text.length(), text.length())
	_vk_open = true


func _hide_keyboard() -> void:
	if not _vk_open:
		return
	_vk_open = false
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()


## Which key is under a point, or "" for none.
func _key_at(p: Vector2) -> String:
	for k: Dictionary in _keyboard():
		if (k["rect"] as Rect2).grow(2.0).has_point(p):
			return String(k["id"])
	return ""


## A tap on a key does exactly what the matching physical key does, so there is
## one set of rules about what typing means and the keyboard is only an input
## device rather than a second implementation of the game.
func _press_key(id: String) -> void:
	if id == "":
		return
	_key_down = id
	if id == "fire":
		_submit_player()
		return
	if id == "back":
		if player.alive and not paused:
			typed = typed.substr(0, maxi(0, typed.length() - 1))
			Sfx.play("back", randf_range(0.94, 1.06))
			Haptics.fire("back")
		return
	if paused or not player.alive or typed.length() >= 20:
		return
	typed += id
	chars_typed += 1
	Haptics.fire("key")
	_fleck(id)
	Sfx.play("key", randf_range(0.92, 1.10))


## A comet on a curve with a tapering tail sampled back along the same curve, and
## for your own attacks the letters it is carrying riding the head — so you can
## watch the stamp you just minted travel to the board it is about to brand.
func _draw_tracers() -> void:
	const STEPS := 12
	const STEP := 0.035
	# Only your own attacks wear your cosmetic. A rival's shot has to keep
	# reading as a rival's shot, or the one thing tracers were added to make
	# clear — who is hitting whom — goes back to being a guess.
	var style := Profile.worn("attack")
	for tr: Tracer in tracers:
		var u := clampf(tr.t, 0.0, 1.0)
		var head := tr.at(u)
		if tr.mine and style != "comet":
			_draw_tracer_styled(tr, style, u, head)
			continue
		# Two passes: a wide soft one for the glow, a narrow bright one for the
		# filament inside it. One line at one width reads as a UI stroke; the
		# pair reads as something hot going past.
		for pass_i in 2:
			var wide := pass_i == 0
			for i in STEPS:
				var back: float = u - float(i + 1) * STEP
				if back < 0.0:
					break
				var fade: float = 1.0 - float(i) / float(STEPS)
				var col := Color(tr.color, 0.16 * fade) if wide \
					else Color(1.0, 1.0, 1.0, 0.55 * fade * fade).lerp(
						Color(tr.color, 0.8 * fade), 0.55)
				draw_line(tr.at(back), tr.at(u - float(i) * STEP), col,
					tr.width * fade * (3.2 if wide else 1.0), true)
		draw_circle(head, tr.width * 3.0, Color(tr.color, 0.22))
		draw_circle(head, tr.width * 1.6, Color(tr.color, 0.7))
		draw_circle(head, tr.width * 0.7, Color(1.0, 1.0, 1.0, 0.95))
		# The stamp rides the shot. Everyone's is shown, not just yours: watching
		# ING cross the screen towards you is a second of warning about what you
		# are going to have to answer.
		if tr.text != "":
			_text_centered(_font_bold, head - Vector2(0.0, 22.0), tr.text, 16,
				Color(1.0, 1.0, 1.0, 0.9 * (1.0 - u * 0.45)))


## The earned alternatives to the default comet. Each has to keep the two things
## the tracer exists for — a clear direction of travel and the stamp it carries
## — and differ in everything else.
func _draw_tracer_styled(tr: Tracer, style: String, u: float, head: Vector2) -> void:
	match style:
		"dart":
			# A rigid arrowhead facing its own travel, with a thin taut line
			# behind it. No glow at all; it reads as precision rather than power.
			var back := tr.at(maxf(0.0, u - 0.09))
			var dir := (head - back).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.RIGHT
			var side := Vector2(-dir.y, dir.x)
			draw_line(tr.at(maxf(0.0, u - 0.5)), head, Color(tr.color, 0.45),
				tr.width * 0.45, true)
			var nose: float = 9.0 + tr.width * 1.5
			draw_colored_polygon(PackedVector2Array([
				head + dir * nose,
				head - dir * nose * 0.5 + side * nose * 0.55,
				head - dir * nose * 0.5 - side * nose * 0.55,
			]), Color(tr.color, 0.95))
		"swarm":
			# One shot drawn as a shoal, each member weaving around the path.
			for i in 9:
				var lag: float = float(i) * 0.028
				var at := tr.at(clampf(u - lag, 0.0, 1.0))
				var wob := Vector2(
					sin(Time.get_ticks_msec() / 90.0 + float(i) * 1.7),
					cos(Time.get_ticks_msec() / 70.0 + float(i) * 2.3)) * (5.0 + i)
				draw_circle(at + wob, tr.width * (0.85 - 0.05 * i),
					Color(tr.color, 0.85 - 0.07 * i))
		"bolt":
			# The path, redrawn as a jagged discharge that re-strikes every frame.
			var pts := PackedVector2Array()
			var steps := 14
			for i in steps + 1:
				var f: float = float(i) / float(steps)
				var on := tr.at(clampf(u * f + (u - 0.35) * (1.0 - f), 0.0, 1.0))
				var kink: float = 0.0 if i == 0 or i == steps else randf_range(-11.0, 11.0)
				pts.append(on + Vector2(kink, kink * 0.6))
			for i in pts.size() - 1:
				draw_line(pts[i], pts[i + 1], Color(tr.color, 0.28), tr.width * 2.6, true)
				draw_line(pts[i], pts[i + 1], Color(1.0, 1.0, 1.0, 0.8), tr.width * 0.7, true)
			draw_circle(head, tr.width * 2.2, Color(tr.color, 0.6))

	if tr.text != "":
		_text_centered(_font_bold, head - Vector2(0.0, 22.0), tr.text, 16,
			Color(1.0, 1.0, 1.0, 0.9 * (1.0 - u * 0.45)))


func _draw_side_header(side: SideState, board_pos: Vector2) -> void:
	var bw := WWBoard.COLS * WWBoard.CELL
	var center_x := board_pos.x + bw * 0.5
	_text_centered(_font_bold, Vector2(center_x, BOARD_TOP - 44.0), _show(side.label), 26,
		side.accent)

	# Score leads: in a four-way it is the only quick answer to "am I winning".
	var sub := "%s · %d words" % [_commas(side.score), side.words_played]
	_text_centered(_font, Vector2(center_x, BOARD_TOP - 20.0), sub, 13, Color("#7c88ad"))

	# Lives, as pips beside the board name. The last one pulses, because being on
	# your last life is the single most important thing on the screen.
	var pip := 13.0
	var gap := 7.0
	var span := LIVES * pip + (LIVES - 1) * gap
	for i in LIVES:
		var r := Rect2(center_x - span * 0.5 + i * (pip + gap), BOARD_TOP - 76.0, pip, pip)
		if i < side.lives:
			var tint := side.accent
			if side.lives == 1:
				tint = Color("#ff6b6b") * Color(1, 1, 1,
					0.65 + 0.35 * sin(Time.get_ticks_msec() / 150.0))
			draw_rect(r, tint, true)
		else:
			draw_rect(r, Color("#2a3355"), true)
			draw_rect(r, Color("#ff6b6b") * Color(1, 1, 1, 0.35), false, 1.0)

	# The board is being put back together; say so rather than leaving it blank.
	if side.respite > 0.0:
		_text_centered(_font_bold, side.board.position + side.board.board_size() * 0.5,
			"%d %s LEFT" % [side.lives, "LIFE" if side.lives == 1 else "LIVES"], 30,
			Color("#ff6b6b") * Color(1, 1, 1, clampf(side.respite, 0.0, 1.0)))

	if side.life_flash > 0.0:
		var lr := Rect2(board_pos - Vector2(13, 13),
			Vector2(bw + 26, WWBoard.ROWS * WWBoard.CELL + 26))
		draw_rect(lr, Color("#ff6b6b") * Color(1, 1, 1, side.life_flash * 0.8), false, 4.0)

	if side.flash > 0.0:
		var r := Rect2(board_pos - Vector2(13, 13), Vector2(bw + 26, WWBoard.ROWS * WWBoard.CELL + 26))
		draw_rect(r, Color(side.accent, side.flash * 0.35), false, 3.0)


## One segment per block size, lit up to the current chain. The live segment
## drains as the chain runs out, so you can see both how big your next hit will
## be and how long you have to keep it.
func _draw_chain_meter(side: SideState) -> void:
	var bw := WWBoard.COLS * WWBoard.CELL
	var x := side.board.position.x
	var y := BOARD_TOP + WWBoard.ROWS * WWBoard.CELL + 12.0
	var n := TIERS.size()
	var gap := 4.0
	var seg := (bw - gap * (n - 1)) / float(n)

	# The instant a salvo goes off, the whole meter whites out and empties.
	if side.salvo_flash > 0.0:
		for i in n:
			draw_rect(Rect2(x + i * (seg + gap), y, seg, 7.0),
				Color(1, 1, 1, side.salvo_flash), true)
		return

	# Tiers no longer arrive one per word, so the next segment fills gradually to
	# show how much of the run still stands between you and it.
	var earned: int = _chain_tier(side.chain) if side.chain > 0 else -1

	for i in n:
		var r := Rect2(x + i * (seg + gap), y, seg, 7.0)
		var col: Color = WWBoard.TIER_COLORS[i]
		if i <= earned:
			draw_rect(r, col, true)
			continue
		draw_rect(r, Color("#1a2140"), true)
		if i == earned + 1 and side.chain > 0:
			var from: float = float(CHAIN_TIER_AT[i - 1]) if i > 0 else 0.0
			var span: float = maxf(1.0, float(CHAIN_TIER_AT[i]) - from)
			# Off the meter rather than the whole-word count, so a long word is
			# visibly a bigger push toward the next tier than a short one. That
			# is the entire feedback for reaching, and it was invisible while
			# this read an integer.
			var p := clampf((side.chain_fill - from) / span, 0.0, 1.0)
			draw_rect(Rect2(r.position, Vector2(r.size.x * p, r.size.y)), Color(col, 0.45), true)

	# Time left on the run, spanning the whole meter.
	if side.chain > 0:
		var frac := clampf(side.chain_timer / maxf(side.chain_window, 0.001), 0.0, 1.0)
		draw_rect(Rect2(x, y + 10.0, bw, 2.0), Color("#1a2140"), true)
		draw_rect(Rect2(x, y + 10.0, bw * frac, 2.0), Color(side.accent, 0.9), true)


## Inbound garbage, shown on the inner edge of each board: stamp, a miniature of
## the shape that is coming, and a fuse. Answer the stamp before the fuse burns
## out and the block never lands.
func _draw_pending(side: SideState, on_right: bool) -> void:
	if side.pending.is_empty():
		return
	var bw := WWBoard.COLS * WWBoard.CELL
	var x: float = (side.board.position.x + bw + 16.0) if on_right else (side.board.position.x - 16.0 - CHIP_W)
	var y := BOARD_TOP
	var aiming: String = _typing_of(side)
	# Chips only light up while the word still has reach left after the board.
	var budget := 0
	if aiming.length() >= MIN_WORD_LEN:
		budget = _reach(aiming) - side.board.would_clear(aiming, _reach(aiming))

	for p: Pending in side.pending:
		var rect := Rect2(x, y, CHIP_W, CHIP_H)
		var locked: bool = budget > 0 and p.prefix != "" and aiming.begins_with(p.prefix)
		if locked:
			budget -= 1

		_chip_sb.bg_color = Color(WWBoard.TIER_COLORS[p.tier], 0.92)
		_chip_sb.border_color = Color.WHITE if locked else Color(0, 0, 0, 0.35)
		_chip_sb.set_border_width_all(3 if locked else 1)
		draw_style_box(_chip_sb, rect)

		_text_fit(_font_bold, Vector2(rect.position.x + 28.0, rect.get_center().y - 2.0),
			p.prefix.to_upper(), 15, 48.0, Color("#0b1020"), 8)
		_draw_shape_pip(Vector2(rect.end.x - 20.0, rect.get_center().y - 2.0), p.tier)

		var fuse := 1.0 - clampf(p.timer / DROP_DELAY, 0.0, 1.0)
		draw_rect(Rect2(x + 4, y + CHIP_H - 7, (CHIP_W - 8) * fuse, 3), Color("#0b1020"), true)

		y += CHIP_H + CHIP_GAP
		if y > BOARD_TOP + WWBoard.ROWS * WWBoard.CELL - CHIP_H:
			break


## Tiny w-by-h dot grid so the chip reads as "a 3x2 is coming", not just "a block".
func _draw_shape_pip(center: Vector2, tier: int) -> void:
	var w: int = TIERS[tier]["w"]
	var h: int = TIERS[tier]["h"]
	var dot := 3.0
	var step := dot + 1.0
	var origin := center - Vector2(w * step, h * step) * 0.5
	for cy in h:
		for cx in w:
			draw_rect(Rect2(origin + Vector2(cx * step, cy * step), Vector2(dot, dot)),
				Color(0, 0, 0, 0.55), true)


func _draw_center_hud(size: Vector2) -> void:
	var band := _center_band()
	var cx := (band.x + band.y) * 0.5

	_text_centered(_font_bold, Vector2(cx, BOARD_TOP + 6.0),
		"%d:%02d" % [int(match_time) / 60, int(match_time) % 60], 30, Color("#e6ecff"))
	_text_centered(_font, Vector2(cx, BOARD_TOP + 32.0), difficulty.to_upper(), 12, Color("#5d6a92"))

	# The score is the loudest thing in this column on purpose: it is the number
	# you are playing for, and it swells for a beat every time it moves.
	var kick := score_kick * score_kick
	_text_centered(_font_bold, Vector2(cx, BOARD_TOP + 66.0),
		_commas(int(round(score_shown))), int(30 + 12.0 * kick),
		Color("#ffd166").lerp(Color.WHITE, kick * 0.7))

	var next_seed: int = int(ceil(pressure_timer))
	_text_centered(_font, Vector2(cx, BOARD_TOP + 96.0),
		"pressure in %ds" % next_seed, 12, Color("#7c88ad"))

	if slots_in_play > 2 and player.alive:
		var mark: SideState = sides[player.target]
		_text_centered(_font, Vector2(cx, BOARD_TOP + 118.0), "AIMING AT", 10, Color("#5d6a92"))
		_text_centered(_font_bold, Vector2(cx, BOARD_TOP + 136.0), _show(mark.label), 17,
			mark.accent)


	# Kept inside the free band so it never draws over anybody's playfield.
	var log_width := maxf(180.0, band.y - band.x - 24.0)
	var y := BOARD_TOP + (144.0 if slots_in_play <= 2 else 166.0)
	var room := 7 if slots_in_play <= 2 else 5
	var shown := 0
	for e: Dictionary in events:
		if shown >= room:
			break
		shown += 1
		var alpha: float = 0.25 + 0.75 * float(e["life"])
		_text_fit(_font, Vector2(cx, y), e["text"], 13 if slots_in_play <= 2 else 12,
			log_width, Color(e["color"], alpha), 9)
		y += 22.0 if slots_in_play <= 2 else 19.0


func _draw_player_input(size: Vector2) -> void:
	var bw := WWBoard.COLS * WWBoard.CELL
	var cx := player.board.position.x + bw * 0.5
	var base_y := BOARD_TOP + WWBoard.ROWS * WWBoard.CELL + 46.0

	var hits := _preview_hits(player, typed)
	var col := PLAYER_ACCENT
	if typed.length() >= MIN_WORD_LEN:
		if hits > 0:
			col = Color("#ffd166")
		elif not WordBank.is_valid(typed):
			col = Color("#7c88ad")

	# The cosmetic caret is drawn rather than typed, so it can be a shape instead
	# of an underscore. The text is measured without it and the caret is placed
	# after — a caret glyph inside the string would shove the line about as it
	# blinked.
	_text_fit(_font_bold, Vector2(cx, base_y), typed.to_upper(), 34, bw + 46.0, col)
	_draw_caret(Vector2(cx, base_y), typed, col, bw + 46.0)
	_draw_typing_effect(Vector2(cx, base_y), col)

	var status_y := base_y + 26.0
	if hits > 0:
		var matches := _preview_matches(player, typed)
		if matches > hits:
			# Teach the rule at the moment it bites.
			_text_centered(_font, Vector2(cx, status_y),
				"takes out %d of %d — a longer word reaches further" % [hits, matches],
				13, Color("#f8961e"))
		else:
			_text_centered(_font, Vector2(cx, status_y),
				"takes out %d block%s" % [hits, "" if hits == 1 else "s"], 13, Color("#ffd166"))
	elif player.chain + 1 >= SALVO_AT:
		# Telegraph the payoff, or it arrives out of nowhere.
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 110.0)
		_text_centered(_font_bold, Vector2(cx, status_y),
			"CHAIN x%d · NEXT HIT IS A SALVO" % player.chain, 14,
			Color("#ffd166") * Color(1, 1, 1, pulse))
	elif player.chain >= 2:
		var next_tier := _chain_tier(player.chain + 1)
		_text_centered(_font_bold, Vector2(cx, status_y),
			"CHAIN x%d · next hit %s" % [player.chain, _tier_name(next_tier)], 13,
			WWBoard.TIER_COLORS[next_tier])
	elif message_life > 0.0:
		_text_centered(_font, Vector2(cx, status_y), message, 13,
			Color(message_color, clampf(message_life, 0.0, 1.0)))
	else:
		_text_centered(_font, Vector2(cx, status_y),
			"keep firing without pausing — the chain makes blocks bigger", 12, Color("#4d5878"))


## One keystroke's worth of flourish, parked where the line is being typed. The
## effect that consumes it decides what it looks like; this only decides that
## something happened and roughly where.
func _fleck(ch: String) -> void:
	if Profile.worn("typing") == "plain":
		return
	var bw := WWBoard.COLS * WWBoard.CELL
	var at := Vector2(player.board.position.x + bw * 0.5 + randf_range(-70.0, 70.0),
		BOARD_TOP + WWBoard.ROWS * WWBoard.CELL + 46.0)
	_key_flecks.append({
		"at": at,
		"vel": Vector2(randf_range(-150.0, 150.0), randf_range(-230.0, -90.0)),
		"life": 1.0,
		"ch": ch.to_upper(),
	})
	if _key_flecks.size() > 26:
		_key_flecks.pop_front()


## Where the next letter would go, in whatever shape has been earned. Blinks on
## the same clock in every style so the styles differ in look, not in rhythm.
func _draw_caret(at: Vector2, text: String, col: Color, max_width: float) -> void:
	var size := 34
	var m := _font_bold.get_string_size(text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	while size > 11 and m.x > max_width:
		size -= 1
		m = _font_bold.get_string_size(text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var x := at.x + m.x * 0.5 + 5.0
	var on: bool = fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.55
	var h := float(size) * 0.78

	match Profile.worn("cursor"):
		"block":
			if on:
				draw_rect(Rect2(x, at.y - h * 0.5, size * 0.46, h), Color(col, 0.85), true)
		"pulse":
			# Never fully gone: it breathes rather than blinks.
			var beat: float = 0.35 + 0.65 * absf(sin(Time.get_ticks_msec() / 260.0))
			draw_rect(Rect2(x, at.y - h * 0.5 * beat, 4.0, h * beat), Color(col, beat), true)
			draw_circle(Vector2(x + 2.0, at.y), 7.0 * beat, Color(col, 0.16 * beat))
		"spark":
			var t := Time.get_ticks_msec() / 1000.0
			draw_rect(Rect2(x, at.y - h * 0.5, 3.0, h), Color("#ffd166"), true)
			for i in 7:
				var ph: float = fmod(t * 1.7 + float(i) * 0.31, 1.0)
				var lift: float = ph * 26.0
				draw_rect(Rect2(x + sin(t * 5.0 + float(i)) * 4.0, at.y - h * 0.4 - lift,
					2.5, 2.5), Color(Color("#f8961e").lerp(Color("#ffd166"), ph),
					0.9 * (1.0 - ph)), true)
		_:
			if on:
				draw_rect(Rect2(x, at.y + h * 0.42, size * 0.5, 3.0), Color(col, 0.9), true)


## Per-keystroke flourish around the line you are typing. Fed by `_key_flecks`,
## which the input handler stocks on every accepted letter.
func _draw_typing_effect(at: Vector2, col: Color) -> void:
	var style := Profile.worn("typing")
	if style == "plain" or _key_flecks.is_empty():
		return
	for f: Dictionary in _key_flecks:
		var life: float = f["life"]
		var age: float = 1.0 - life
		var p: Vector2 = f["at"]
		match style:
			"sparks":
				var v: Vector2 = f["vel"]
				draw_rect(Rect2(p + v * age * 0.34 + Vector2(0.0, age * age * 90.0),
					Vector2(3.0, 3.0)), Color(col, life), true)
			"ripple":
				draw_arc(p, 6.0 + age * 46.0, 0.0, TAU, 22,
					Color(col, 0.45 * life), 2.0, true)
			"ghost":
				# The letter you just pressed, left behind and drifting up.
				_text_centered(_font_bold, p - Vector2(0.0, age * 34.0),
					String(f["ch"]), int(30.0 - 10.0 * age), Color(col, 0.55 * life))


## A rival, in the space of a postcard: name, lives, what they are typing, how
## much is falling on them, and whether you are pointed at them.
func _draw_rival_panel(s: SideState) -> void:
	var r := _board_rect(s)
	var cx := r.get_center().x
	# With one rival there is nothing to choose between, so the aim marker is
	# just noise; it earns its place only in a free-for-all.
	var aimed := slots_in_play > 2 and player.target == s.slot and player.alive
	var out := not s.alive

	# The aim marker has to be unmistakable — it decides where your words land.
	if aimed:
		var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 220.0)
		draw_rect(r.grow(9.0), Color(s.accent, 0.35 + 0.4 * pulse), false, 3.0)
		var tip := Vector2(cx, r.position.y - 30.0)
		draw_colored_polygon(PackedVector2Array([
			tip + Vector2(0, 12), tip + Vector2(-9, -4), tip + Vector2(9, -4)]),
			Color(s.accent, 0.6 + 0.4 * pulse))

	var name_col: Color = s.accent if not out else Color("#4d5878")
	var title := _show("%d · %s" % [s.slot, s.label] if slots_in_play > 2 else s.label)
	_text_centered(_font_bold, Vector2(cx, r.position.y - 54.0), title,
		26 if slots_in_play <= 2 else 16, name_col)
	if slots_in_play <= 2:
		_text_centered(_font, Vector2(cx, r.position.y - 30.0),
			"%s · %d words" % [_commas(s.score), s.words_played], 13,
			Color("#7c88ad"))
	else:
		# In a four-way this is the only quick read on who is actually winning —
		# the boards tell you who is in trouble, which is a different question.
		# It sits under the panel rather than under the name because the aim
		# marker lives up there, and it stays on screen after somebody is
		# knocked out so the final table is still readable.
		_text_centered(_font, Vector2(cx, r.end.y + 62.0), _commas(s.score), 12,
			Color("#7c88ad") if not out else Color("#4d5878"))

	# Lives as pips.
	var pip := 9.0
	var gap := 5.0
	var span := LIVES * pip + (LIVES - 1) * gap
	for i in LIVES:
		var pip_y := r.position.y - (76.0 if slots_in_play <= 2 else 38.0)
		var pr := Rect2(cx - span * 0.5 + i * (pip + gap), pip_y, pip, pip)
		draw_rect(pr, s.accent if i < s.lives and not out else Color("#2a3355"), true)

	if out:
		_text_centered(_font_bold, r.get_center(), "OUT", 26, Color("#ff6b6b"))
		return

	# What they are mid-way through typing.
	var shown := _show(_typing_of(s).to_upper())
	_text_fit(_font_bold, Vector2(cx, r.end.y + 18.0),
		shown if shown != "" else "…", 18, r.size.x + 30.0,
		Color(s.accent, 0.9) if shown != "" else Color("#3d4666"))

	# Their chain, and how much is queued on them.
	var seg := (r.size.x - 5 * 3.0) / 6.0
	var earned: int = _chain_tier(s.chain) if s.chain > 0 else -1
	for i in TIERS.size():
		draw_rect(Rect2(r.position.x + i * (seg + 3.0), r.end.y + 30.0, seg, 4.0),
			WWBoard.TIER_COLORS[i] if i <= earned else Color("#1a2140"), true)
	if not s.pending.is_empty():
		_text_centered(_font, Vector2(cx, r.end.y + 46.0),
			"%d incoming" % s.pending.size(), 11, Color("#ffd166"))

	if s.respite > 0.0:
		_text_centered(_font_bold, r.get_center(),
			"%d LEFT" % s.lives, 20, Color("#ff6b6b"))


# ------------------------------------------------------------------- overlays

## Grain and a vignette, both sitting just at the edge of noticing.
## Turn any of them up and the game starts looking like a filter rather than a
## game — the job is to stop the flat panels reading as a spreadsheet.
##
## The vignette does double duty. It frames the picture, and it is where the
## board's danger is *felt* rather than read: past halfway to the ceiling it
## reddens and starts beating, faster the closer you get. The screen itself gets
## nervous, which is a thing you notice without having to look at anything.
func _draw_screen_texture(size: Vector2) -> void:
	if _vignette == null or not fx_texture:
		return
	var full := Rect2(-SHAKE_MARGIN, -SHAKE_MARGIN,
		size.x + SHAKE_MARGIN * 2.0, size.y + SHAKE_MARGIN * 2.0)

	var tint := Color(0.0, 0.0, 0.0)
	var amount := VIGNETTE
	if phase == Phase.PLAY and player.alive and not paused:
		var peril := _peril(player)
		if peril > 0.45:
			var heat: float = (peril - 0.45) / 0.55
			var beat: float = 0.5 + 0.5 * sin(
				Time.get_ticks_msec() / (280.0 - 150.0 * heat))
			tint = Color(0.62, 0.04, 0.07) * (0.3 + 0.7 * beat)
			amount += heat * (0.20 + 0.18 * beat)
	_overlay.draw_texture_rect(_vignette, full, false,
		Color(tint.r, tint.g, tint.b, amount))

	# Re-offset every frame, or a static tile reads as a smudge on the monitor.
	var jog := Vector2(randi() % 96, randi() % 96)
	_overlay.draw_texture_rect(_grain, Rect2(full.position - jog, full.size + jog),
		true, Color(1.0, 1.0, 1.0, GRAIN))


func _draw_overlay() -> void:
	var size := get_viewport_rect().size
	_draw_screen_texture(size)
	if flash > 0.0:
		_overlay.draw_rect(Rect2(-SHAKE_MARGIN, -SHAKE_MARGIN,
			size.x + SHAKE_MARGIN * 2.0, size.y + SHAKE_MARGIN * 2.0),
			Color(flash_color, flash * 0.5), true)
	if phase == Phase.PLAY:
		if portrait:
			_draw_keyboard()
			_draw_back_button()
		_draw_score_pops()
		_draw_power_pops()
		# Drawn here rather than in `_draw`, because everything it uses paints on
		# this canvas item and `draw_*` outside its own draw pass silently does
		# nothing at all.
		if mode != Mode.NORMAL:
			_draw_coaching(size)
		if paused:
			_draw_pause(size)
		elif not player.alive:
			_draw_spectating(size)
		return

	if phase == Phase.SPLASH:
		# The menu assembles underneath while the art dissolves off the top of
		# it, so the two never trade places against an empty screen.
		_draw_title(size)
		_draw_splash(size)
	elif phase == Phase.TITLE:
		_draw_title(size)
	elif phase == Phase.SOLO:
		_draw_solo(size)
	elif phase == Phase.PRACTICE:
		_draw_practice(size)
	elif phase == Phase.MASTERY:
		_draw_mastery(size)
	elif phase == Phase.COSMETICS:
		_draw_cosmetics(size)
	elif phase == Phase.LOBBY:
		_draw_lobby(size)
	elif phase == Phase.SETTINGS:
		_draw_settings(size)
	elif phase == Phase.LOBBY:
		_draw_lobby(size)
	elif phase == Phase.COUNTDOWN:
		_draw_countdown(size)
	elif phase == Phase.OVER:
		_draw_gameover(size)

	# Last, so it sits over whatever the screen drew — several of these paint a
	# full-width header straight through the corner it lives in.
	if portrait:
		_draw_back_button()


## The numbers you just earned, rising off the bottom of your own board and
## fading out. Drawn on the overlay so the screen shake does not drag them about
## — a number that jitters is a number you cannot read.
func _draw_score_pops() -> void:
	for p: Dictionary in score_pops:
		var life: float = p["life"]
		# Leaps out of the board and then eases to a stop, rather than drifting
		# at a constant rate — the snap is what makes it feel like a payout.
		var t: float = 1.0 - life
		var rise: float = 74.0 * (1.0 - (1.0 - t) * (1.0 - t))
		var at: Vector2 = (p["at"] as Vector2) - Vector2(0.0, rise)
		var fade: float = clampf(life * 1.6, 0.0, 1.0)
		var size: int = int(p["size"] * (0.75 + 0.25 * clampf(life * 2.4, 0.0, 1.0)))
		_otext(_font_bold, at, String(p["text"]), size, Color("#ffd166", fade))
		if String(p["note"]) != "":
			_otext(_font, at + Vector2(0.0, size * 0.72), String(p["note"]),
				maxi(11, size / 3), Color("#e6ecff", fade * 0.8))


## Power-word banners, struck across the middle of your own board. They punch in
## oversized and settle, which is the whole trick: the eye reads the word before
## it has finished arriving.
func _draw_power_pops() -> void:
	var bw := WWBoard.COLS * WWBoard.CELL
	var cx := player.board.position.x + bw * 0.5
	const PUNCH := 1.3
	for p: Dictionary in power_pops:
		var life: float = p["life"]
		var tint: Color = p["tint"]
		var fade: float = clampf(life * 2.2, 0.0, 1.0)
		var punch: float = clampf((1.0 - life) * 5.0, 0.0, 1.0)
		var y: float = BOARD_TOP + WWBoard.ROWS * WWBoard.CELL * 0.42 - int(p["row"]) * 46.0

		# Name and payout on one line, so there is nothing to hang off the side
		# of a playfield that is only six cells wide. The size is fitted at the
		# punched size rather than the settled one — otherwise the arrival, which
		# is the part anybody actually notices, is the part that overflows.
		var text := "%s +%s" % [String(p["name"]), _commas(int(p["bonus"]))]
		var size := 34
		while size > 14 and _font_bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
				-1, int(size * PUNCH)).x > bw - 24.0:
			size -= 2
		var shown := int(size * lerpf(PUNCH, 1.0, punch))

		var m := _font_bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, shown)
		# A bar behind it, because these land on top of a board full of blocks
		# and coloured type alone would not survive the background.
		_overlay.draw_rect(Rect2(cx - m.x * 0.5 - 12.0, y - m.y * 0.5 - 4.0,
			m.x + 24.0, m.y + 8.0), Color(bg_top, 0.78 * fade), true)
		_overlay.draw_rect(Rect2(cx - m.x * 0.5 - 12.0, y + m.y * 0.5 + 2.0,
			m.x + 24.0, 2.0), Color(tint, 0.85 * fade), true)
		_otext(_font_bold, Vector2(cx, y), text, shown, Color(tint, fade))


## Big and unmissable, scaling down as each number's second runs out.
func _draw_countdown(size: Vector2) -> void:
	var cx := size.x * 0.5
	var cy := size.y * 0.42
	var mark := int(ceil(countdown))
	var frac: float = countdown - floor(countdown)
	var label := str(mark) if mark > 0 else "GO"
	var tint: Color = Color("#ffd166") if mark <= 1 else PLAYER_ACCENT

	# Ring closing in on the number.
	_overlay.draw_arc(Vector2(cx, cy), 78.0, 0.0, TAU, 48, Color(tint, 0.13), 4.0, true)
	_overlay.draw_arc(Vector2(cx, cy), 78.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 48,
		Color(tint, 0.7), 4.0, true)
	var pop: float = 1.0 + (1.0 - frac) * 0.35
	_otext(_font_bold, Vector2(cx, cy), label, int(96 * pop), Color(tint, 0.5 + 0.5 * frac))
	_otext(_font, Vector2(cx, cy + 96.0),
		"versus %s" % _show(ai_side.label if net_active() else difficulty), 16,
		Color("#8d99bd"))


## The key art, laid out the way the engine's boot splash lays it out — same fit,
## same backdrop — so the hand-off from engine to scene has nothing to show. It
## then dissolves off the menu that has been assembling underneath it.
func _draw_splash(size: Vector2) -> void:
	# Whichever cut matches the screen. This is the third place the art appears —
	# after the iOS launch storyboard and the engine's own boot splash — and all
	# three have to agree, or the opening of the game is three different pictures
	# in half a second.
	var art_tex: Texture2D = _splash
	if portrait and _splash_tall != null:
		art_tex = _splash_tall
	if art_tex == null:
		return
	var a := 1.0
	if splash_time > SPLASH_HOLD:
		a = 1.0 - clampf((splash_time - SPLASH_HOLD) / SPLASH_FADE, 0.0, 1.0)
		a = a * a * (3.0 - 2.0 * a)

	var art := Vector2(art_tex.get_width(), art_tex.get_height())
	var s: float = minf(size.x / art.x, size.y / art.y)
	_overlay.draw_rect(Rect2(-SHAKE_MARGIN, -SHAKE_MARGIN,
		size.x + SHAKE_MARGIN * 2.0, size.y + SHAKE_MARGIN * 2.0),
		Color(SPLASH_MATTE, a), true)
	_overlay.draw_texture_rect(art_tex, Rect2((size - art * s) * 0.5, art * s),
		false, Color(1.0, 1.0, 1.0, a))


func _draw_title(size: Vector2) -> void:
	var cx := size.x * 0.5
	_overlay.draw_rect(Rect2(-SHAKE_MARGIN, -SHAKE_MARGIN,
		size.x + SHAKE_MARGIN * 2.0, size.y + SHAKE_MARGIN * 2.0), Color(bg_top, 0.90), true)
	_draw_decor()

	# Wordmark, with the tail of WARS picked out — the whole game in one gag.
	# This is the one place the display face is used; a glitch font is a logo,
	# not something anyone should have to read a menu in. It sets wider than the
	# plain one, so the size is fitted rather than fixed, and the rule beneath is
	# measured off whatever size that came out as instead of being nailed down.
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 700.0)
	var title_size := 82
	while title_size > 40 and _font_title.get_string_size(
			"WORD WARS", HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > size.x - 140.0:
		title_size -= 2
	# The whole header hangs off the safe area. A Dynamic Island is about 104
	# units deep in this design space, and the wordmark sits at 96 — so without
	# this the first thing on the screen is behind the notch.
	var hy := safe_top
	_otext(_font_title, Vector2(cx, hy + 96), "WORD WARS", title_size, Color("#e6ecff"))
	var wm := _font_title.get_string_size("WORD WARS", HORIZONTAL_ALIGNMENT_LEFT,
		-1, title_size)
	_overlay.draw_rect(Rect2(cx - wm.x * 0.5, hy + 96.0 + wm.y * 0.5 - 8.0, wm.x, 3),
		Color(PLAYER_ACCENT, 0.25 + 0.35 * pulse), true)
	_otext(_font, Vector2(cx, hy + 162), "your endings become their beginnings",
		17, Color("#8d99bd"))

	# Who you are, above the door. This is the entire payoff for the mastery
	# system, so it goes where the eye already is rather than behind a menu.
	var who := Profile.title_text()
	var badge := "LEVEL %d" % Profile.level()
	if who != "":
		badge += "  ·  " + who.to_upper()
	_otext(_font_bold, Vector2(cx, hy + 186), badge, 13, Color("#ffd166"))

	# The full rules take the whole screen, opponent cards included. There is
	# nowhere to put the power words otherwise, and somebody reading the rules is
	# not picking an opponent in the same breath. `_menu_buttons` returns nothing
	# while this is up, so what is drawn and what is clickable still agree.
	if show_rules:
		_draw_rules_panel(size)
		# In portrait the way out is the chevron in the corner, which is sitting
		# right there and needs no caption. Printing three keys that the phone
		# does not have would only be telling somebody to press what they cannot.
		if not portrait:
			_otext(_font, Vector2(cx, 646), "H — back to the menu", 14, Color("#5d6a92"))
			_otext(_font, Vector2(cx, 674), "F1 — %s      ESC — quit" % [
				"sound on" if Sfx.muted else "mute"], 13, Color("#4d5878"))
		return

	# The explainer cards are for somebody who has not been taught yet. Shown to
	# everyone on every launch they were three more generic cards between the
	# player and the game, which is most of what made this screen feel like a
	# template rather than a title.
	if not portrait and not bool(Profile.pref("taught")):
		_draw_how_cards(cx)

	_draw_title_bands()
	for b: Dictionary in _menu_buttons():
		_draw_title_plate(b)

	# The number keys still work and nothing else says so. Kept to one line and
	# set quietly, because it is a power-user affordance rather than the way in.
	if not portrait:
		# Hung off the last thing drawn rather than recomputed, which is how it
		# ended up under the bottom edge when a seventh plate arrived.
		var plates := _title_plates()
		var last: Rect2 = plates[plates.size() - 1]["rect"]
		_otext(_font, Vector2(cx, last.end.y + 18.0),
			"1 – 7 jumps straight in      F1 %s      ESC quits"
			% ["unmutes" if Sfx.muted else "mutes"], 11, Color("#3d4666"))




## Three worked examples instead of a wall of instructions. Each one shows the
## actual thing it is describing, drawn with the same routines the game uses.
func _draw_how_cards(cx: float) -> void:
	var card_w := 356.0
	var card_h := 178.0
	var top := 194.0
	for i in 3:
		var x: float = cx + (i - 1) * (card_w + 18.0) - card_w * 0.5
		var r := Rect2(x, top, card_w, card_h)
		_panel(r, Color("#141b33"), Color(PLAYER_ACCENT, 0.16), 12.0)
		var mid := r.position.x + card_w * 0.5
		var caption := top + 158.0

		match i:
			0:
				_otext(_font_bold, Vector2(mid, top + 24), "BRAND", 14, PLAYER_ACCENT)
				_draw_split_word(mid, top + 64, "FRIEND", "SHIP", 26)
				_draw_arrow(mid, top + 86, 24.0, Color("#5d6a92"))
				_mini_block(Vector2(mid, top + 130), Vector2(66, 34), 2, "SHIP")
				_otext(_font, Vector2(mid, caption), "your word's tail brands their block",
					12, Color("#8d99bd"))
			1:
				_otext(_font_bold, Vector2(mid, top + 24), "SMASH", 14, Color("#ffd166"))
				# A burst of shards, the way it actually looks in play.
				var at := Vector2(mid, top + 76)
				for s in 10:
					var a := TAU * s / 10.0 + Time.get_ticks_msec() / 900.0
					var d := 26.0 + 5.0 * sin(Time.get_ticks_msec() / 260.0 + s)
					_overlay.draw_rect(Rect2(at + Vector2(cos(a), sin(a)) * d
						- Vector2(2.5, 2.5), Vector2(5, 5)),
						Color(WWBoard.TIER_COLORS[2], 0.5), true)
				_mini_block(at, Vector2(66, 34), 2, "SHIP")
				_draw_split_word(mid, top + 128, "SHIP", "MENTS", 24, true)
				_otext(_font, Vector2(mid, caption), "longer words smash more at once",
					12, Color("#8d99bd"))
			2:
				_otext(_font_bold, Vector2(mid, top + 24), "CHAIN", 14, Color("#f8961e"))
				var seg := 46.0
				var lit := 1 + int(Time.get_ticks_msec() / 420.0) % 6
				for k in 6:
					var sx := mid - (6 * seg + 5 * 4.0) * 0.5 + k * (seg + 4.0)
					_overlay.draw_rect(Rect2(sx, top + 50, seg, 9),
						WWBoard.TIER_COLORS[k] if k < lit else Color("#1a2140"), true)
				# Bottom-aligned so the escalation reads at a glance.
				var shapes := [Vector2(22, 22), Vector2(46, 22), Vector2(46, 46)]
				var base := top + 136.0
				for k in 3:
					var sz: Vector2 = shapes[k]
					_mini_block(Vector2(mid - 76.0 + k * 76.0, base - sz.y * 0.5), sz, k * 2, "")
				_otext(_font, Vector2(mid, caption), "a run hits harder, then detonates",
					12, Color("#8d99bd"))


## Sound, effects, and the name you play under. Every row is either a slider or
## a switch, and every one of them writes straight through to the profile — there
## is no apply button, because a settings screen that can be wrong until you
## confirm it is a settings screen that will be left wrong.
func _draw_settings(size: Vector2) -> void:
	var cx := size.x * 0.5
	_overlay.draw_rect(Rect2(-SHAKE_MARGIN, -SHAKE_MARGIN,
		size.x + SHAKE_MARGIN * 2.0, size.y + SHAKE_MARGIN * 2.0),
		Color(bg_top, 0.94), true)
	_draw_decor()

	_otext(_font_bold, Vector2(cx, safe_top + 78.0), "SETTINGS", 32, Color("#e6ecff"))

	for row: Dictionary in _settings_rows():
		var r: Rect2 = row["rect"]
		var hot: bool = String(_hover_action).begins_with(String(row["action"]))
		_panel(r, Color("#141b33"), Color(PLAYER_ACCENT, 0.3 if hot else 0.14), 10.0,
			2.0 if hot else 1.0)
		_otext(_font_bold, Vector2(r.position.x + 150.0, r.get_center().y),
			String(row["label"]), 15, Color("#e6ecff"))
		_otext(_font, Vector2(r.position.x + 150.0, r.get_center().y + 20.0),
			String(row["note"]), 11, Color("#5d6a92"))

		match String(row["kind"]):
			"slider":
				var track := _settings_track(r)
				_panel(track, Color("#0e142a"), Color(PLAYER_ACCENT, 0.2), 4.0, 1.0)
				var v: float = float(row["value"])
				_overlay.draw_rect(Rect2(track.position + Vector2(2, 2),
					Vector2((track.size.x - 4.0) * v, track.size.y - 4.0)),
					Color(PLAYER_ACCENT), true)
				_overlay.draw_circle(
					Vector2(track.position.x + 2.0 + (track.size.x - 4.0) * v,
						track.get_center().y), 7.0, Color("#e6ecff"))
				_otext(_font_bold, Vector2(r.end.x - 44.0, r.get_center().y),
					"%d%%" % int(round(v * 100.0)), 14, Color("#8d99bd"))
			"toggle":
				var on: bool = bool(row["value"])
				var sw := Rect2(r.end.x - 132.0, r.get_center().y - 14.0, 92.0, 28.0)
				_panel(sw, Color("#1f8a70") if on else Color("#2a3355"),
					Color(PLAYER_ACCENT if on else Color("#4d5878"), 0.8), 14.0, 1.0)
				_overlay.draw_circle(Vector2(sw.position.x + (68.0 if on else 24.0),
					sw.get_center().y), 10.0, Color("#e6ecff"))
				_otext(_font_bold, Vector2(sw.position.x + (26.0 if on else 66.0),
					sw.get_center().y), "ON" if on else "OFF", 11,
					Color("#e6ecff") if on else Color("#7c88ad"))
			"buy":
				# Two states before it is owned, because a purchase that goes
				# through on the first tap is a purchase somebody made by
				# accident. Once owned the same control hands it back, which is
				# the only way to test the flow more than once.
				var got2: bool = bool(row["value"])
				var armed: bool = _buy_armed and not got2
				var label := "OWNED" if got2 else (
					"CONFIRM?" if armed else "BUY  ·  TEST")
				var bw2 := 168.0
				var br := Rect2(r.end.x - bw2 - 36.0, r.get_center().y - 17.0, bw2, 34.0)
				_panel(br,
					Color("#1f8a70") if got2 else (
						Color("#5a2233") if armed else Color("#241626")),
					Color("#ffd166") if (got2 or armed) else Color("#c77dff"),
					9.0, 2.0)
				_otext(_font_bold, br.get_center(), label, 13, Color("#e6ecff"))
			"text":
				var field := Rect2(r.end.x - 336.0, r.get_center().y - 18.0, 300.0, 36.0)
				var editing: bool = settings_editing
				_panel(field, Color("#111730"),
					Color(PLAYER_ACCENT, 0.7 if editing else 0.25), 8.0,
					2.0 if editing else 1.0)
				var caret := "_" if editing and fmod(
					Time.get_ticks_msec() / 1000.0, 1.0) < 0.55 else ""
				_text_fit_overlay(_font_bold, field.get_center(),
					String(row["value"]) + caret, 18, field.size.x - 20.0,
					Color("#e6ecff"))

	for b: Dictionary in _menu_buttons():
		_draw_menu_button(b)

	var rows := _settings_rows()
	var sfoot := _grid_bottom(
		[(rows[rows.size() - 1] as Dictionary)["rect"]], 502.0) + 66.0
	_text_fit_overlay(_font, Vector2(cx, sfoot),
		"tap a slider or switch · tap your name to change it" if portrait
		else "click a slider or switch · click your name to change it · ESC back",
		12, size.x - GRID_MARGIN * 2.0, Color("#5d6a92"), 10)

	# Where the record lives, so it can be backed up or moved between machines
	# without anyone having to guess at Godot's user directory. Loud and red if
	# something is wrong with it, because the one thing worse than losing a
	# profile is not being told until it is too late to rescue.
	if Profile.read_failed:
		_text_fit_overlay(_font_bold, Vector2(cx, sfoot + 20.0),
			"YOUR PROFILE COULD NOT BE READ — NOTHING IS BEING SAVED THIS SESSION",
			13, size.x - GRID_MARGIN * 2.0, Color("#ff6b6b"), 10)
	else:
		_text_fit_overlay(_font, Vector2(cx, sfoot + 20.0),
			ProjectSettings.globalize_path(Profile.save_path), 11, size.x - 80.0,
			Color("#3d4666"), 9)


## One table for drawing and hit-testing both, so a control that is on screen is
## always a control that responds.
func _settings_rows() -> Array:
	var cx := get_viewport_rect().size.x * 0.5
	var defs := [
		["music", "slider", "Music", "the bed under everything",
			float(Profile.pref("music"))],
		["sfx", "slider", "Sound effects", "typing, impacts, power words",
			float(Profile.pref("sfx"))],
		["texture", "toggle", "Screen texture", "film grain and vignette",
			bool(Profile.pref("texture"))],
		["hitstop", "toggle", "Impact freeze", "the pause on a heavy hit",
			bool(Profile.pref("hitstop"))],
		["censor", "toggle", "Profanity filter", "masks rude words on screen",
			bool(Profile.pref("censor"))],
	]
	# A phone is already fullscreen and has no window to make one of, so the
	# switch would be a control that does nothing whichever way it was thrown.
	# The reverse is true of haptics: no desktop has the hardware.
	if portrait:
		defs.append(["haptics", "toggle", "Haptics", "the buzz on hits and keys",
			bool(Profile.pref("haptics"))])
	else:
		defs.append(["fullscreen", "toggle", "Fullscreen", "",
			bool(Profile.pref("fullscreen"))])
	defs.append(["name", "text", "Your name", "shown to other players",
		Link.my_name])
	# The store, such as it is. One row, and the same `Profile.grant` a real
	# purchase callback would call once a receipt validated — so what is being
	# tested here is the thing that will ship, minus the receipt.
	var got: bool = Profile.owns(Profile.PACK_PREMIUM)
	defs.append(["premium", "buy", "Premium pack",
		"no ads · FOUNDER · Prism board · Supernova win", got])
	var out: Array = []
	# 720 was the row width and 720 is also the whole of a portrait screen, so
	# the rows ran edge to edge with no margin at all. Capped by the screen now.
	var rw: float = minf(720.0, get_viewport_rect().size.x - GRID_MARGIN * 2.0)
	for i in defs.size():
		var d: Array = defs[i]
		out.append({
			"rect": Rect2(cx - rw * 0.5, 124.0 + safe_top + i * 66.0, rw, 54.0),
			"action": "set:" + String(d[0]),
			"kind": String(d[1]), "label": String(d[2]), "note": String(d[3]),
			"value": d[4],
		})
	return out


## The slider's track. One definition, because the drawing and the click that
## sets the value have to agree about where it starts and how long it is — and
## it is no longer a constant now that the row width follows the screen.
func _settings_track(r: Rect2) -> Rect2:
	var x := r.position.x + 300.0
	return Rect2(x, r.get_center().y - 4.0, maxf(120.0, r.end.x - 100.0 - x), 8.0)


## A click on a settings row. Sliders take their new value from where along the
## track you clicked, which is one gesture rather than the drag-and-release a
## real handle would need — and for six rows of preferences, a handle is more
## machinery than the job is worth.
func _change_setting(key: String) -> void:
	if key == "name":
		settings_editing = not settings_editing
		if settings_editing:
			_show_keyboard(Link.my_name)
		else:
			_hide_keyboard()
		Sfx.play("key", 1.2)
		return
	if key == "premium":
		# Two taps, because a purchase that happens on the first one is a
		# purchase somebody made by accident. The second tap is where a real
		# store sheet would open instead.
		if Profile.owns(Profile.PACK_PREMIUM):
			# Owned already — the row becomes a way to hand it back, which is the
			# only way to test the flow more than once.
			Profile.revoke(Profile.PACK_PREMIUM)
			_buy_armed = false
			_say("premium pack removed", Color("#8d99bd"))
			Sfx.play("reject", 1.1)
			return
		if not _buy_armed:
			_buy_armed = true
			_say("tap again to confirm", Color("#ffd166"))
			Sfx.play("count", 1.2)
			return
		_buy_armed = false
		Profile.grant(Profile.PACK_PREMIUM)
		_apply_theme()
		_say("premium unlocked — three cosmetics in Mastery", Color("#ffd166"))
		Sfx.play("salvo", 1.15)
		Haptics.fire("level")
		return
	if key == "texture" or key == "hitstop" or key == "fullscreen" or key == "censor" \
			or key == "haptics":
		Profile.set_pref(key, not bool(Profile.pref(key)))
		_apply_prefs()
		Sfx.play("count", 1.3 if bool(Profile.pref(key)) else 0.9)
		# Switching it on demonstrates itself. There is no other way to find out
		# what the setting does than to feel it.
		if key == "haptics" and bool(Profile.pref(key)):
			Haptics.fire("power")
		return

	for row: Dictionary in _settings_rows():
		if String(row["action"]) != "set:" + key:
			continue
		var track := _settings_track(row["rect"])
		var at := get_viewport().get_mouse_position().x
		var v := clampf((at - track.position.x - 2.0) / maxf(1.0, track.size.x - 4.0),
			0.0, 1.0)
		Profile.set_pref(key, v)
		_apply_prefs()
		# Audible on the way past, or a volume slider is set blind.
		Sfx.play("key", 1.0 + v * 0.5)


## Push every stored preference at the thing that owns it. Called on boot and
## after any change, so there is one path from the saved value to the effect and
## no chance of the screen and the game disagreeing.
func _apply_prefs() -> void:
	Music.set_gain(float(Profile.pref("music")))
	Sfx.set_gain(float(Profile.pref("sfx")))
	fx_texture = bool(Profile.pref("texture"))
	fx_hitstop = bool(Profile.pref("hitstop"))
	fx_censor = bool(Profile.pref("censor"))
	if not fx_hitstop:
		_clear_hitstop()
	# Deliberately not applied in portrait. A phone window is already the whole
	# screen, and forcing a mode there resizes the window, which re-runs the
	# orientation check against the size the resize just produced — the two ended
	# up flipping each other back and forth.
	if not portrait:
		var full := bool(Profile.pref("fullscreen"))
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if full \
			else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want:
			DisplayServer.window_set_mode(want)


## Tutorial and Training, side by side or stacked.
const PRACTICE_NATURAL := 2.0 * 104.0 + 16.0 + 84.0 + 62.0 + 74.0


func _practice_fill() -> float:
	return _menu_fill(PRACTICE_NATURAL)


func _practice_spread() -> float:
	return _menu_spread(PRACTICE_NATURAL)


## Everything on the screen, once the fill and spread have had their say.
func _practice_laid() -> float:
	var f := _practice_fill()
	var sp := _practice_spread()
	var rows: float = 2.0 if portrait else 1.0
	return rows * 104.0 * f + (rows - 1.0) * 16.0 * sp + 84.0 * sp \
		+ 62.0 * f + 74.0


func _practice_door_rects() -> Array:
	var f := _practice_fill()
	return _grid_rects(2, 214.0 + safe_top + _menu_offset(_practice_laid()), 2,
		320.0, 104.0 * f, 20.0, 340.0, 16.0 * _practice_spread())


## The three pace cards. They wrap on a phone, which is the right answer here —
## three across at 720 leaves each of them too narrow for its own note.
func _practice_pace_rects() -> Array:
	return _grid_rects(TRAINING_PACE.size(), _practice_pace_top(), 3, 214.0,
		62.0 * _practice_fill(), 12.0, 200.0, 10.0)


func _practice_pace_top() -> float:
	return _grid_bottom(_practice_door_rects(), 318.0) + 84.0 * _practice_spread()


## Learn it or drill it. Two doors, and a pace for the second one.
func _draw_practice(size: Vector2) -> void:
	var cx := size.x * 0.5
	_overlay.draw_rect(Rect2(-SHAKE_MARGIN, -SHAKE_MARGIN,
		size.x + SHAKE_MARGIN * 2.0, size.y + SHAKE_MARGIN * 2.0),
		Color(bg_top, 0.93), true)
	_draw_decor()

	# The header travels with the block. Centring the content and leaving the
	# title pinned to the top left it orphaned, with a band of nothing between
	# the two — the screen has to move as one composition or not at all.
	var hy := safe_top + _menu_offset(_practice_laid())
	_otext(_font_bold, Vector2(cx, hy + 78.0), "PRACTICE", 32, Color("#e6ecff"))
	if not bool(Profile.pref("taught")):
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 420.0)
		_otext(_font_bold, Vector2(cx, hy + 118.0), "START WITH THE TUTORIAL", 14,
			Color("#90be6d") * Color(1, 1, 1, pulse))
	else:
		_text_fit_overlay(_font, Vector2(cx, hy + 118.0),
			"nothing here is scored, and nothing here can be lost", 13,
			size.x - GRID_MARGIN * 2.0, Color("#8d99bd"), 11)

	_otext(_font_bold, Vector2(cx, _practice_pace_top() - 30.0), "TRAINING PACE", 13,
		Color("#7c88ad"))

	for b: Dictionary in _menu_buttons():
		_draw_menu_button(b)

	var foot := _grid_bottom(_practice_pace_rects(), 464.0) + 36.0
	_text_fit_overlay(_font, Vector2(cx, foot),
		"training has no opponent, no lives and no end%s" % [
			"" if portrait else " — ESC when you are done"],
		13, size.x - GRID_MARGIN * 2.0, Color("#5d6a92"), 11)
	# Said plainly, because somebody will otherwise practise for an hour and
	# wonder where their level went.
	_text_fit_overlay(_font, Vector2(cx, foot + 22.0),
		"neither mode earns XP, so neither can be farmed", 12,
		size.x - GRID_MARGIN * 2.0, Color("#4d5878"), 10)


## The lesson card, and the live readout a practice run is for. Both sit in the
## centre column, which is empty in these modes because there is no rival.
func _draw_coaching(size: Vector2) -> void:
	var band := _center_band()
	var cx := (band.x + band.y) * 0.5
	var wide := maxf(300.0, band.y - band.x - 20.0)

	# The daily borrows the empty centre column the same way training does, and
	# for the same reason — there is no rival board to be in the way. It gets its
	# own readout rather than falling through to the tutorial card, which is what
	# it did on its first run: a daily board that opened on "STEP 1 OF 7".
	if mode == Mode.DAILY:
		var left := daily_left()
		_otext(_font_bold, Vector2(cx, 300.0), "DAILY BOARD", 16, Color("#ffd166"))
		_otext(_font, Vector2(cx, 322.0), daily_key(), 11, Color("#5d6a92"))
		var rows2 := [
			["TIME LEFT", "%d:%02d" % [int(left) / 60, int(left) % 60]],
			["SCORE", _commas(player.score)],
			["BEST CHAIN", "x%d" % player.best_chain],
			["LIVES", str(player.lives)],
		]
		var y2 := 356.0
		for r: Array in rows2:
			_otext_pair(_font, _font_bold, Vector2(cx, y2), r[0], r[1], 11, 16,
				Color("#5d6a92"),
				Color("#ff6b6b") if (r[0] == "TIME LEFT" and left <= 15.0)
					else Color("#e6ecff"), 30.0)
			y2 += 28.0
		_otext(_font, Vector2(cx, y2 + 14.0), "one run — no second go", 11,
			Color("#4d5878"))
		return

	if mode == Mode.TRAINING:
		_otext(_font_bold, Vector2(cx, 300.0), "TRAINING", 16, Color("#7bdff2"))
		var rows := [
			["CLEARED", str(player.blocks_cleared)],
			["BEST CHAIN", "x%d" % player.best_chain],
			["WPM", str(int(round(_wpm())))],
			["PACE", String(TRAINING_PACE[train_pace]["name"]).to_upper()],
		]
		var y := 332.0
		for r: Array in rows:
			_otext_pair(_font, _font_bold, Vector2(cx, y), r[0], r[1], 11, 16,
				Color("#5d6a92"), Color("#e6ecff"), 30.0)
			y += 28.0
		_otext(_font, Vector2(cx, y + 14.0), "ESC to stop", 11, Color("#4d5878"))
		return

	var step: Dictionary = Tutorial.step(lesson)
	if step.is_empty():
		return

	# The card is placed where the rival board would be, because that is the one
	# part of the screen a lesson can occupy without hiding anything that matters.
	var r := Rect2(cx - wide * 0.5, 236.0, wide, 214.0)
	_panel(r, Color("#111730"), Color("#90be6d", 0.4), 12.0, 2.0)
	_otext(_font, Vector2(cx, 262.0), "STEP %d OF %d" % [lesson + 1, Tutorial.count()],
		11, Color("#5d6a92"))
	_text_fit_overlay(_font_bold, Vector2(cx, 290.0), String(step["title"]), 21,
		wide - 40.0, Color("#e6ecff"))

	var y := 326.0
	for line: String in String(step["body"]).split("\n"):
		_text_fit_overlay(_font, Vector2(cx, y), line, 14, wide - 36.0,
			Color("#aab4d4"))
		y += 22.0

	if lesson_done or String(step["id"]) == "done":
		var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 200.0)
		_otext(_font_bold, Vector2(cx, r.end.y - 26.0), "SPACE TO CONTINUE", 15,
			Color("#90be6d") * Color(1, 1, 1, pulse))
	else:
		_otext(_font, Vector2(cx, r.end.y - 26.0), String(step["hint"]), 12,
			Color("#7c88ad"))

	# A row of pips, so seven steps reads as a short thing with an end to it.
	var pip := 10.0
	var span := Tutorial.count() * pip + (Tutorial.count() - 1) * 6.0
	for i in Tutorial.count():
		_overlay.draw_rect(Rect2(cx - span * 0.5 + i * (pip + 6.0), r.end.y + 14.0,
			pip, 4.0),
			Color("#90be6d") if i <= lesson else Color("#2a3355"), true)


## Who you are lining up against. Deliberately shaped like the versus lobby:
## seats along the top, and a roster underneath that fills whichever seat you
## have picked. Choosing an opponent was the title screen's job until it had
## seven of them on it — and it never let you choose more than one at a time,
## which made a free-for-all three copies of the same personality.
func _draw_solo(size: Vector2) -> void:
	var cx := size.x * 0.5
	_overlay.draw_rect(Rect2(-SHAKE_MARGIN, -SHAKE_MARGIN,
		size.x + SHAKE_MARGIN * 2.0, size.y + SHAKE_MARGIN * 2.0),
		Color(bg_top, 0.93), true)
	_draw_decor()

	var hy := safe_top + _menu_offset(_solo_laid())
	_otext(_font_bold, Vector2(cx, hy + 62.0), "SINGLE PLAYER", 32, Color("#e6ecff"))
	_otext(_font, Vector2(cx, hy + 96.0), "add up to three, and pick who they are", 14,
		Color("#8d99bd"))

	# The table, you included, so the size of the match is visible rather than
	# inferred from how many seats happen to be filled.
	var seats := _solo_seat_rects()
	for i in seats.size():
		var r: Rect2 = seats[i]
		var mine := i == 0
		var who: String = "" if mine else String(solo_seats[i - 1])
		var picked: bool = not mine and solo_pick == i - 1
		var accent: Color = SLOT_ACCENTS[i]
		var filled: bool = mine or who != ""

		_panel(r, Color("#1b2444") if picked else Color("#141b33"),
			Color(accent, 0.95 if picked else (0.4 if filled else 0.16)), 10.0,
			3.0 if picked else 2.0)
		_otext(_font, Vector2(r.get_center().x, r.position.y + 20.0),
			"YOU" if mine else "SEAT %d" % i, 10, Color("#7c88ad"))

		var label := Profile.title_text().to_upper() if mine else "EMPTY"
		if mine and label == "":
			label = "READY"
		elif not mine and who == "?":
			label = "RANDOM"
		elif not mine and who != "":
			label = who.to_upper()
		_text_fit_overlay(_font_bold, Vector2(r.get_center().x, r.position.y + 44.0),
			label, 17, r.size.x - 16.0,
			Color("#e6ecff") if filled else Color("#4d5878"))

		if not mine and who != "" and who != "?":
			_otext(_font, Vector2(r.get_center().x, r.position.y + 64.0),
				"%d wpm" % int(AiOpponent.spec(who)["wpm"]), 11, accent)
		elif not mine and who == "?":
			_otext(_font, Vector2(r.get_center().x, r.position.y + 64.0),
				"rolled each match", 11, Color("#7c88ad"))

	_otext(_font, Vector2(cx, _solo_roster_top() - 24.0),
		"%s a seat, then pick below · %d opponent%s" % [
			"tap" if portrait else "click",
			_solo_filled(), "" if _solo_filled() == 1 else "s"], 12, Color("#5d6a92"))

	for c: Dictionary in _solo_cards():
		var r: Rect2 = c["rect"]
		var hot: bool = _hover_action == String(c["action"])
		var on: bool = String(solo_seats[solo_pick]) == String(c["id"])
		if hot:
			r = Rect2(r.position - Vector2(0, 3), r.size)
		var accent: Color = c["accent"]
		_panel(r, Color("#1b2444") if hot else Color("#141b33"),
			Color("#ffd166") if on else Color(accent, 0.9 if hot else 0.28), 10.0,
			3.0 if on else 2.0)
		_text_fit_overlay(_font_bold, Vector2(r.get_center().x, r.position.y + 26.0),
			String(c["name"]).to_upper(), 17, r.size.x - 20.0,
			Color.WHITE if hot else Color("#e6ecff"))
		_text_fit_overlay(_font, Vector2(r.get_center().x, r.position.y + 48.0),
			String(c["note"]), 11, r.size.x - 14.0, Color("#8d99bd"), 9)

	_draw_kind_cards(_solo_kinds_top(), true)

	for b: Dictionary in _menu_buttons():
		_draw_menu_button(b)

	if not portrait:
		# Clear of the Back button, which ends at foot + 110.
		_otext(_font, Vector2(cx, _solo_foot() + 132.0),
			"1 / 2 / 3 select a seat · ENTER starts · ESC back", 12, Color("#5d6a92"))


## The special-block switches. The same row of cards serves single-player setup
## and the versus room, so the two can never drift apart or explain themselves
## differently.
func _kind_cards(top: float) -> Array:
	var out: Array = []
	var kf: float = _solo_fill() if phase == Phase.SOLO else 1.0
	var rects := _grid_rects(KIND_ORDER.size(), top, 3, 254.0, 56.0 * kf, 10.0,
		240.0, 8.0 * kf)
	for i in KIND_ORDER.size():
		var id: String = KIND_ORDER[i]
		out.append({
			"rect": rects[i],
			"id": id,
			"name": String(KIND_BLURB[id][0]),
			"note": String(KIND_BLURB[id][1]),
			"action": "kind:" + id,
		})
	return out


## Draws them, and reports how tall the block was so the caller can lay out
## underneath it without guessing.
func _draw_kind_cards(top: float, editable: bool) -> float:
	var cx := get_viewport_rect().size.x * 0.5
	_otext(_font_bold, Vector2(cx, top - 16.0), "SPECIAL BLOCKS", 13, Color("#7c88ad"))
	var bottom := top
	for c: Dictionary in _kind_cards(top):
		var r: Rect2 = c["rect"]
		var on: bool = block_kinds.has(String(c["id"]))
		var hot: bool = editable and _hover_action == String(c["action"])
		_panel(r, Color("#1b2444") if hot else Color("#141b33"),
			Color("#ffd166") if on else Color(PLAYER_ACCENT, 0.5 if hot else 0.14),
			10.0, 2.0 if on else 1.0)
		# Centred in what is left after the switch has taken the right-hand end,
		# rather than at a fixed offset — on a phone these cards are half again
		# as wide and the text was hugging the left edge of them.
		var tx: float = r.position.x + (r.size.x - 70.0) * 0.5
		var tw: float = r.size.x - 90.0
		_otext(_font_bold, Vector2(tx, r.get_center().y - 8.0),
			String(c["name"]).to_upper(), 14,
			Color("#e6ecff") if on else Color("#5d6a92"))
		_text_fit_overlay(_font, Vector2(tx, r.get_center().y + 11.0),
			String(c["note"]), 10, tw, Color("#7c88ad") if on else Color("#3d4666"), 8)
		# A switch rather than a tick: these are settings, and a tick reads as
		# "done" where a switch reads as "on".
		var sw := Rect2(r.end.x - 62.0, r.get_center().y - 11.0, 46.0, 22.0)
		_panel(sw, Color("#1f8a70") if on else Color("#2a3355"),
			Color(PLAYER_ACCENT if on else Color("#4d5878"), 0.7), 11.0, 1.0)
		_overlay.draw_circle(Vector2(sw.position.x + (33.0 if on else 13.0),
			sw.get_center().y), 8.0, Color("#e6ecff"))
		bottom = maxf(bottom, r.end.y)
	return bottom


const SOLO_NATURAL := 76.0 + 40.0 + 3.0 * 76.0 + 42.0 + 3.0 * 64.0 + 90.0


func _solo_fill() -> float:
	return _menu_fill(SOLO_NATURAL, 1.2)


func _solo_spread() -> float:
	return _menu_spread(SOLO_NATURAL, 2.0)


func _solo_laid() -> float:
	var f := _solo_fill()
	var sp := _solo_spread()
	var roster: float = 3.0 if portrait else 2.0
	var kinds: float = 3.0 if portrait else 2.0
	return 76.0 * f + 40.0 * sp + roster * 66.0 * f + (roster - 1.0) * 10.0 * sp \
		+ 42.0 * sp + kinds * 56.0 + 90.0


func _solo_seat_rects() -> Array:
	# Four across at whatever width fits, never wrapped: the point of the row is
	# that it is the table, and a table that goes 3 + 1 stops reading as one.
	# `min_w` of zero is what forbids the wrap.
	return _grid_rects(4, 118.0 + safe_top + _menu_offset(_solo_laid()), 4, 168.0,
		76.0 * _solo_fill(), 12.0, 0.0, 10.0)


## Everything that can go in a seat: nothing, a random pick, or one of the
## roster. Built from `AiOpponent.ROSTER`, so a new personality appears here the
## moment it exists.
func _solo_cards() -> Array:
	var list: Array = [
		{"id": "", "name": "Empty", "note": "leave the seat open",
			"accent": Color("#5d6a92")},
		{"id": "?", "name": "Random", "note": "rolled at the start of each match",
			"accent": Color("#ffd166")},
	]
	for name: String in AiOpponent.ROSTER:
		var d: Dictionary = AiOpponent.spec(name)
		list.append({"id": name, "name": name, "note": String(d["style"]),
			"accent": Color(String(d["tint"]))})

	var out: Array = []
	var rects := _grid_rects(list.size(), _solo_roster_top(), 5, 202.0,
		66.0 * _solo_fill(), 10.0, 190.0, 10.0 * _solo_spread())
	for i in list.size():
		var e: Dictionary = list[i]
		e["rect"] = rects[i]
		e["action"] = "seat:%s" % String(e["id"])
		out.append(e)
	return out


## Under the seats and the line of instructions beneath them.
func _solo_roster_top() -> float:
	return _grid_bottom(_solo_seat_rects(), 194.0) + 40.0 * _solo_spread()


## Under the roster. The special-block switches are the last thing on the screen
## before the start button, and how far down they start depends on how many rows
## the roster took — which is three on a desktop and six on a phone.
func _solo_kinds_top() -> float:
	var out := _solo_roster_top()
	for c: Dictionary in _solo_cards():
		out = maxf(out, (c["rect"] as Rect2).end.y)
	return out + 42.0 * _solo_spread()


## The bottom of the last thing on the single-player screen, which the Start and
## Back buttons sit under.
func _solo_foot() -> float:
	var top := _solo_kinds_top()
	var out := top
	for c: Dictionary in _kind_cards(top):
		out = maxf(out, (c["rect"] as Rect2).end.y)
	return out


func _solo_filled() -> int:
	var n := 0
	for w in solo_seats:
		if String(w) != "":
			n += 1
	return n


## Turn the seats into the lineup a match actually runs. Random seats roll here,
## once, so a "random" opponent is a surprise rather than a thing that changes
## under you between the menu and the countdown.
func _solo_lineup() -> Array:
	var out: Array = []
	for w in solo_seats:
		var id := String(w)
		if id == "":
			continue
		out.append(AiOpponent.ROSTER.pick_random() if id == "?" else id)
	if out.is_empty():
		out.append("Duelist")
	return out


## Everything you have ever done, what it earned, and what you are wearing.
##
## Locked entries are shown with what would unlock them and how close you are,
## because a lock that will not say what it wants is just a taunt. Nothing here
## affects play — that is what makes it safe to hand out for showing off.
func _draw_mastery(size: Vector2) -> void:
	var cx := size.x * 0.5
	_overlay.draw_rect(Rect2(-SHAKE_MARGIN, -SHAKE_MARGIN,
		size.x + SHAKE_MARGIN * 2.0, size.y + SHAKE_MARGIN * 2.0),
		Color(bg_top, 0.94), true)
	_draw_decor()

	var hy := safe_top + _menu_offset(_mastery_laid())
	var prog := Profile.level_progress()
	_otext(_font_bold, Vector2(cx, hy + 58.0), "MASTERY", 34, Color("#e6ecff"))
	var title := Profile.title_text()
	_otext(_font_bold, Vector2(cx, hy + 96.0),
		"LEVEL %d%s" % [int(prog["level"]), ("  ·  " + title.to_upper()) if title != "" else ""],
		20, Color("#ffd166"))

	var bw: float = minf(600.0, size.x - GRID_MARGIN * 2.0)
	var bar := Rect2(cx - bw * 0.5, hy + 116.0, bw, 12.0)
	_panel(bar, Color("#141b33"), Color("#ffd166", 0.25), 6.0, 1.0)
	_overlay.draw_rect(Rect2(bar.position + Vector2(2, 2),
		Vector2((bar.size.x - 4.0) * float(prog["frac"]), bar.size.y - 4.0)),
		Color("#ffd166"), true)
	_otext(_font, Vector2(cx, hy + 144.0), "%s / %s xp to level %d" % [
		_commas(int(prog["into"])), _commas(int(prog["need"])), int(prog["level"]) + 1],
		12, Color("#7c88ad"))

	# The record. With cosmetics moved out this screen is only about what you
	# have done, so it can afford to say all of it rather than a strip of eight.
	var stats := [
		["MATCHES", str(Profile.matches)],
		["WINS", str(Profile.wins)],
		["FLAWLESS", str(Profile.flawless)],
		["WORDS", _commas(Profile.words)],
		["BEST WPM", str(int(Profile.best_wpm))],
		["BEST CHAIN", "x%d" % Profile.best_chain],
		["BEST COMBO", "x%d" % Profile.best_combo],
		["MULTI-CLEARS", str(Profile.multi_clears)],
		["SALVOS", str(Profile.salvos)],
		["BEST SCORE", _commas(Profile.best_score)],
		["LONGEST", _show(Profile.longest_word.to_upper())
			if Profile.longest_word != "" else "—"],
		["DAILY BEST", _commas(Profile.daily_best)],
	]
	var strip := _mastery_stat_rects(stats.size())
	for i in stats.size():
		var r: Rect2 = strip[i]
		_panel(r, Color("#141b33"), Color(PLAYER_ACCENT, 0.16), 8.0, 1.0)
		_otext(_font, Vector2(r.get_center().x, r.position.y + 18.0), stats[i][0], 10,
			Color("#7c88ad"))
		_text_fit_overlay(_font_bold, Vector2(r.get_center().x, r.position.y + 41.0),
			stats[i][1], 18, r.size.x - 20.0, Color("#e6ecff"))

	# Power words earned, which is the one part of the record that says how you
	# play rather than how much. It had nowhere to live before.
	var pfoot := _grid_bottom(strip, 222.0 + safe_top) + 40.0
	_otext(_font_bold, Vector2(cx, pfoot), "POWER WORDS EARNED", 11, Color("#5d6a92"))
	var pw := _grid_rects(POWER_ORDER.size(), pfoot + 22.0, 4, 150.0,
		52.0 * _mastery_fill(), 10.0, 120.0, 10.0 * _mastery_fill())
	for i in POWER_ORDER.size():
		var name: String = POWER_ORDER[i]
		var r2: Rect2 = pw[i]
		var tintp := Color(String(POWERS[name]["tint"]))
		var got := int(Profile.powers.get(name, 0))
		_panel(r2, Color("#141b33"), Color(tintp, 0.35 if got > 0 else 0.12), 8.0, 1.0)
		_otext(_font_bold, Vector2(r2.get_center().x, r2.position.y + 17.0), name, 11,
			tintp if got > 0 else Color("#4d5878"))
		_otext(_font_bold, Vector2(r2.get_center().x, r2.position.y + 37.0), str(got), 17,
			Color("#e6ecff") if got > 0 else Color("#3d4666"))

	for b: Dictionary in _menu_buttons():
		_draw_menu_button(b)

	if Profile.daily_streak > 1:
		_otext(_font, Vector2(cx, _grid_bottom(pw, pfoot) + 34.0),
			"%d daily boards running" % Profile.daily_streak, 12, Color("#ffd166"))


## What a cosmetic actually looks like, before you commit to it.
##
## Drawn with the same functions the game uses rather than with an illustration
## of them, so the panel cannot drift from the thing it is advertising — the
## victory effects are the real effects, the block face is the real face, and a
## theme is previewed by building a small board out of its own colours.
##
## `id` is whatever is under the cursor, falling back to what is equipped, so
## the panel answers "what am I about to pick" and "what am I wearing" with one
## control.
func _draw_cosmetic_preview(box: Rect2, slot: String, id: String) -> void:
	_panel(box, Color("#0e142a"), Color(PLAYER_ACCENT, 0.18), 10.0, 1.0)
	var t := Time.get_ticks_msec() / 1000.0
	var mid := box.get_center()

	match slot:
		"theme":
			# A board in miniature: the theme's wash, its bloom, its panel at
			# its own alpha, its ruling and its nodes.
			var top := Cosmetics.theme_color(id, "top")
			var bot := Cosmetics.theme_color(id, "bottom")
			for i in 12:
				var f := float(i) / 12.0
				_overlay.draw_rect(Rect2(box.position.x + 2.0,
					box.position.y + 2.0 + f * (box.size.y - 4.0),
					box.size.x - 4.0, box.size.y / 12.0 + 1.0),
					top.lerp(bot, f), true)
			var ga: float = float(Cosmetics.theme_opt(id, "glow_a"))
			if ga > 0.0:
				var gcol := Cosmetics.theme_tint(id, "glow", Color.BLACK)
				for i in 5:
					var f2 := float(i) / 4.0
					_overlay.draw_circle(mid, box.size.x * (0.16 + f2 * 0.42),
						Color(gcol, ga * 0.13 * (1.0 - f2)))
			# Taller than wide, because that is the shape of a playfield — a
			# landscape rectangle reads as a swatch rather than as a board.
			var ph2: float = box.size.y * 0.76
			var pan := Rect2(mid - Vector2(ph2 * 0.30, ph2 * 0.5),
				Vector2(ph2 * 0.60, ph2))
			_overlay.draw_rect(pan, Color(Cosmetics.theme_color(id, "panel"),
				float(Cosmetics.theme_opt(id, "panel_a"))), true)
			var grid := Color(Cosmetics.theme_color(id, "grid"),
				float(Cosmetics.theme(id)["grid_a"]))
			var step: float = pan.size.x / 3.0
			var rows := int(pan.size.y / step)
			for i in range(1, 3):
				_overlay.draw_rect(Rect2(pan.position.x + step * i, pan.position.y,
					1.0, pan.size.y), grid, true)
			for i in range(1, rows + 1):
				_overlay.draw_rect(Rect2(pan.position.x, pan.position.y + step * i,
					pan.size.x, 1.0), grid, true)
			if bool(Cosmetics.theme_opt(id, "nodes")):
				for a in range(1, 3):
					for b2 in range(1, rows + 1):
						_overlay.draw_circle(pan.position + Vector2(step * a, step * b2),
							1.6, Color(grid, minf(1.0, grid.a * 3.4)))
			# Two blocks sitting in it, so the theme is judged against the thing
			# it has to stay readable behind.
			for i in 2:
				var br := Rect2(pan.position.x + step * float(i) + 3.0,
					pan.end.y - step * float(2 - i) - step + 3.0,
					step - 6.0, step - 6.0)
				var bink := Cosmetics.draw_block_face(_overlay, br,
					WWBoard.TIER_COLORS[i * 3], Profile.worn("blocks"), false)
				_text_fit_overlay(_font_bold, br.get_center(), ["AL", "ENT"][i], 11,
					br.size.x - 4.0, bink)
			_overlay.draw_rect(pan, Cosmetics.theme_tint(id, "frame",
				PLAYER_ACCENT), false, 1.5)
		"blocks":
			# Three tiers, so a style is judged on more than one swatch.
			var w: float = box.size.x / 4.2
			for i in 3:
				var rr := Rect2(mid.x - w * 1.65 + float(i) * (w + 8.0),
					mid.y - w * 0.4, w, w * 0.8)
				var ink := Cosmetics.draw_block_face(_overlay, rr,
					WWBoard.TIER_COLORS[i * 2], id, false)
				_text_fit_overlay(_font_bold, rr.get_center(),
					["AL", "SHIP", "ENT"][i], 15, rr.size.x - 8.0, ink)
		"victory":
			match id:
				"confetti":
					Cosmetics.victory_confetti(_overlay, box.size, t, Color("#ffd166"))
				"rays":
					Cosmetics.victory_rays(_overlay, mid, t, Color("#ffd166"))
				"shatter":
					Cosmetics.victory_shatter(_overlay, mid, t, Color("#ffd166"))
				"supernova":
					Cosmetics.victory_supernova(_overlay, box.size, mid, t,
						Color("#ffd166"))
				_:
					_otext(_font, mid, "no effect", 13, Color("#5d6a92"))
		"title":
			var e := Profile.entry("title", id)
			var name := String(e.get("name", ""))
			_otext(_font, Vector2(mid.x, mid.y - 16.0), "shown under your name",
				11, Color("#5d6a92"))
			_otext(_font_bold, Vector2(mid.x, mid.y + 10.0),
				"LEVEL %d%s" % [Profile.level(),
					("  ·  " + name.to_upper()) if name != "—" else ""],
				18, Color("#ffd166"))
		_:
			# typing, attack and cursor are motion inside a match and cannot be
			# shown honestly in a still box, so the panel says what it is rather
			# than faking a demonstration.
			var e2 := Profile.entry(slot, id)
			_otext(_font_bold, Vector2(mid.x, mid.y - 10.0),
				String(e2.get("name", "")).to_upper(), 20, Color("#e6ecff"))
			_otext(_font, Vector2(mid.x, mid.y + 16.0), "seen in play", 11,
				Color("#5d6a92"))


## Everything you are wearing, and everything you could be.
##
## Split out of Mastery because the two were doing different jobs on one screen:
## one is a record of what you have done, the other is a wardrobe. Reading your
## best chain and choosing a victory animation are not the same errand, and the
## grid was pushing the record down to a strip of eight tiles.
func _draw_cosmetics(size: Vector2) -> void:
	var cx := size.x * 0.5
	_overlay.draw_rect(Rect2(-SHAKE_MARGIN, -SHAKE_MARGIN,
		size.x + SHAKE_MARGIN * 2.0, size.y + SHAKE_MARGIN * 2.0),
		Color(bg_top, 0.94), true)
	_draw_decor()

	var hy := safe_top + _menu_offset(_cosmetics_laid())
	_otext(_font_bold, Vector2(cx, hy + 58.0), "COSMETICS", 34, Color("#e6ecff"))
	var worn_title := Profile.title_text()
	_otext(_font, Vector2(cx, hy + 92.0),
		"wearing %s" % (worn_title.to_upper() if worn_title != "" else "no title"),
		13, Color("#7c88ad"))

	var slot: String = Profile.SLOTS[mastery_slot]
	_otext(_font_bold, Vector2(cx, _mastery_grid_top() - 25.0),
		String(Profile.SLOT_NAMES[slot]), 15, Color("#7c88ad"))

	# What is under the cursor, or what is on. Answering both with one panel
	# means it is never blank and never lying about what you are wearing.
	var showing := Profile.worn(slot)
	for e: Dictionary in _mastery_cards():
		if _hover_action == String(e["action"]) and Profile.meets(e["need"]):
			showing = String(e["id"])
	var pw: float = minf(330.0, size.x - GRID_MARGIN * 2.0)
	_draw_cosmetic_preview(Rect2(cx - pw * 0.5, _preview_top(), pw,
		_preview_height()), slot, showing)

	for b: Dictionary in _menu_buttons():
		_draw_menu_button(b)

	var worn := Profile.worn(slot)
	for c: Dictionary in _mastery_cards():
		var r: Rect2 = c["rect"]
		var got: bool = Profile.meets(c["need"])
		var on: bool = got and String(c["id"]) == worn
		var hot: bool = _hover_action == String(c["action"])
		if hot:
			r = Rect2(r.position - Vector2(0, 3), r.size)

		var edge := Color("#2a3355")
		if on:
			edge = Color("#ffd166")
		elif got:
			edge = Color(PLAYER_ACCENT, 0.9 if hot else 0.4)
		_panel(r, Color("#1b2444") if hot else Color("#141b33"), edge, 10.0,
			3.0 if on else 2.0)

		_text_fit_overlay(_font_bold, Vector2(r.get_center().x, r.position.y + 30.0),
			String(c["name"]).to_upper(), 19, r.size.x - 30.0,
			Color("#e6ecff") if got else Color("#4d5878"))

		if on:
			_otext(_font_bold, Vector2(r.get_center().x, r.position.y + 55.0),
				"EQUIPPED", 11, Color("#ffd166"))
		elif got:
			_otext(_font, Vector2(r.get_center().x, r.position.y + 55.0),
				"tap to wear" if portrait else "click to wear", 11, Color("#7c88ad"))
		else:
			var st := Profile.standing(c["need"])
			_text_fit_overlay(_font, Vector2(r.get_center().x, r.position.y + 55.0),
				String(st["what"]), 11, r.size.x - 20.0, Color("#5d6a92"), 9)
			var frac: float = clampf(float(st["have"]) / float(maxi(1, int(st["want"]))),
				0.0, 1.0)
			_overlay.draw_rect(Rect2(r.position.x + 8.0, r.end.y - 7.0,
				(r.size.x - 16.0) * frac, 3.0), Color("#ffd166", 0.55), true)

	# Under the Back button rather than on top of it.
	var foot := _mastery_bottom()
	var below := foot + (34.0 if portrait else 92.0)
	_otext(_font, Vector2(cx, below),
		"‹ › change category" if portrait
		else "← → change category · click to equip · ESC back", 13, Color("#5d6a92"))

	var hint := ""
	for e: Dictionary in _mastery_cards():
		if _hover_action == String(e["action"]):
			var need: Dictionary = e["need"]
			if not need.is_empty() and not Profile.meets(need):
				var st2 := Profile.standing(need)
				hint = "%s — %s / %s" % [String(st2["what"]).capitalize(),
					_commas(int(st2["have"])), _commas(int(st2["want"]))]
	if hint != "":
		_otext(_font, Vector2(cx, foot + 12.0), hint, 14, Color("#ffd166"))


## The unlock grid for the category on show. Doubles as the hit-test source, so
## a card that is drawn is always a card that can be clicked.
func _mastery_cards() -> Array:
	var slot: String = Profile.SLOTS[mastery_slot]
	var list: Array = Profile.entries(slot)
	var out: Array = []
	var rects := _grid_rects(list.size(), _mastery_grid_top(), 5, 202.0,
		70.0 * _cosmetics_fill(), 10.0, 190.0, 10.0 * _cosmetics_spread())
	for i in list.size():
		var e: Dictionary = list[i]
		out.append({
			"rect": rects[i],
			"id": String(e["id"]),
			"name": String(e["name"]),
			"need": e.get("need", {}),
			"action": "wear:%s:%s" % [slot, String(e["id"])],
		})
	return out


## The record strip above the grid, which is itself a grid and wraps first.
const MASTERY_NATURAL := 3.0 * 64.0 + 40.0 + 22.0 + 2.0 * 62.0 + 120.0


func _mastery_fill() -> float:
	return _menu_fill(MASTERY_NATURAL, 1.3)


func _mastery_spread() -> float:
	return _menu_spread(MASTERY_NATURAL, 2.2)


func _mastery_laid() -> float:
	var f := _mastery_fill()
	var sp := _mastery_spread()
	var rows: float = 3.0 if portrait else 2.0
	var prows: float = 2.0 if portrait else 1.0
	return rows * 56.0 * f + (rows - 1.0) * 8.0 * sp + 62.0 + 22.0 \
		+ prows * 52.0 * f + 120.0


func _mastery_stat_rects(count: int) -> Array:
	return _grid_rects(count, 166.0 + safe_top + _menu_offset(_mastery_laid()), 8,
		138.0, 56.0 * _mastery_fill(), 8.0, 140.0, 8.0 * _mastery_spread())


## The bottom of the record screen — the stat grid, then the power tallies. The
## buttons hang off it, so both have to be measured rather than guessed.
func _mastery_stats_foot() -> float:
	var strip := _mastery_stat_rects(12)
	var pfoot := _grid_bottom(strip, 222.0 + safe_top) + 40.0
	var pw := _grid_rects(POWER_ORDER.size(), pfoot + 22.0, 4, 150.0,
		52.0 * _mastery_fill(), 10.0, 120.0, 10.0 * _mastery_fill())
	return _grid_bottom(pw, pfoot) + 56.0


## Where the unlock grid starts, once the record strip above it has taken as many
## rows as it needs. On a desktop that is one row and this is the old constant.
## The preview sits under the category label, and the grid under the preview.
const COSMETICS_NATURAL := 150.0 + 46.0 + 4.0 * 80.0 + 110.0


func _cosmetics_fill() -> float:
	return _menu_fill(COSMETICS_NATURAL, 1.25)


func _cosmetics_spread() -> float:
	return _menu_spread(COSMETICS_NATURAL, 1.9)


func _preview_height() -> float:
	return (132.0 if portrait else 150.0) * _cosmetics_fill()


func _cosmetics_laid() -> float:
	var f := _cosmetics_fill()
	var sp := _cosmetics_spread()
	var rows: float = 4.0 if portrait else 3.0
	return _preview_height() + 46.0 + rows * 70.0 * f + (rows - 1.0) * 10.0 * sp \
		+ 110.0


func _preview_top() -> float:
	return 186.0 + safe_top + _menu_offset(_cosmetics_laid())


func _mastery_grid_top() -> float:
	# Under the preview panel. It used to be measured off the record strip because the
	# two shared a screen; the wardrobe has the screen to itself now, so the grid
	# sits under its own header instead of under somebody else's stats.
	return _preview_top() + _preview_height() + 46.0


## The bottom of the unlock grid. Everything below it — the back button, the
## hints — hangs off this rather than off a constant, because the grid is a
## different height per category and a different height again in portrait.
func _mastery_bottom() -> float:
	var cards := _mastery_cards()
	var out := _mastery_grid_top()
	for c: Dictionary in cards:
		out = maxf(out, (c["rect"] as Rect2).end.y)
	return out


## Out of the match but not out of the room. The screen greys so it is obvious
## the words you type would go nowhere, and they no longer can.
func _draw_spectating(size: Vector2) -> void:
	_overlay.draw_rect(Rect2(-SHAKE_MARGIN, -SHAKE_MARGIN,
		size.x + SHAKE_MARGIN * 2.0, size.y + SHAKE_MARGIN * 2.0),
		Color(bg_top, 0.5), true)
	# Sit the notice low and centre, clear of the boards you are here to watch.
	# In portrait "low" is not the bottom of the screen — the keyboard is there,
	# and the notice was landing across the FIRE key.
	var cx := size.x * 0.5
	var y: float = size.y - 108.0
	if portrait:
		y = _portrait_board_bottom() - 96.0
	_text_fit_overlay(_font_bold, Vector2(cx, y), "ELIMINATED", 44,
		size.x - GRID_MARGIN * 2.0, Color("#ff6b6b"), 24)
	var left := _living().size()
	_text_fit_overlay(_font, Vector2(cx, y + 34.0),
		"%d still standing — watching until it is over" % left, 15,
		size.x - GRID_MARGIN * 2.0, Color("#aab4d4"), 11)
	_otext(_font, Vector2(cx, y + 58.0),
		"tap the corner to leave" if portrait else "ESC — menu", 12, Color("#5d6a92"))


func _draw_pause(size: Vector2) -> void:
	_overlay.draw_rect(Rect2(-SHAKE_MARGIN, -SHAKE_MARGIN,
		size.x + SHAKE_MARGIN * 2.0, size.y + SHAKE_MARGIN * 2.0),
		Color(bg_top, 0.86), true)
	var cx := size.x * 0.5
	_otext(_font_bold, Vector2(cx, 230.0), "PAUSED", 64, Color("#e6ecff"))
	# Be honest about what pausing does when other people are involved.
	var note := "the match is frozen"
	if net_active():
		note = "the others are still playing — this only pauses your screen"
	elif not player.alive:
		note = "you are out; the match is still running"
	_otext(_font, Vector2(cx, 286.0), note, 15,
		Color("#ffd166") if net_active() else Color("#8d99bd"))

	for b: Dictionary in _menu_buttons():
		_draw_menu_button(b)
	_otext(_font, Vector2(cx, 492.0), "F1 — sound      CTRL+BACKSPACE clears your line",
		12, Color("#4d5878"))


func _draw_lobby(size: Vector2) -> void:
	var cx := size.x * 0.5
	_overlay.draw_rect(Rect2(-SHAKE_MARGIN, -SHAKE_MARGIN,
		size.x + SHAKE_MARGIN * 2.0, size.y + SHAKE_MARGIN * 2.0), Color(bg_top, 0.92), true)
	_draw_decor()

	var hy := safe_top
	_text_fit_overlay(_font_bold, Vector2(cx, hy + 104), "VERSUS", 66,
		size.x - GRID_MARGIN * 2.0, Color("#e6ecff"))
	_otext(_font, Vector2(cx, hy + 150), "two keyboards, one word chain", 16,
		Color("#8d99bd"))

	if Link.connected:
		_draw_room(cx)
	else:
		_draw_lobby_setup(cx)

	if Link.connected:
		# Everyone sees the house rules, but only the host can change them: a
		# switch a client could flip would be a lie about the match they are
		# about to play.
		if not Link.is_host:
			block_kinds = Link.kinds.duplicate()
			_otext(_font, Vector2(cx, _lobby_kinds_top() - 32.0), "the host sets these", 11,
				Color("#5d6a92"))
		_draw_kind_cards(_lobby_kinds_top(), Link.is_host)

	for b: Dictionary in _menu_buttons():
		_draw_menu_button(b)

	if Link.status != "":
		var waiting := Link.active and not Link.connected
		var tint := Color("#ffd166") if waiting else Color("#8d99bd")
		if Link.status.begins_with("could not") or Link.status.contains("failed") \
				or Link.status.contains("not installed") or Link.status.contains("not wired"):
			tint = Color("#ff6b6b")
		var dots := ".".repeat(1 + int(Time.get_ticks_msec() / 400.0) % 3) if waiting else ""
		# Pinned near the bottom rather than measured off the rest: this is the
		# line that says whether the connection is going anywhere, and it should
		# not move about as rooms fill up and the layout above it grows.
		_text_fit_overlay(_font_bold, Vector2(cx, size.y - safe_bottom - 28.0),
			Link.status + dots, 14, size.x - GRID_MARGIN * 2.0, tint, 10)


## Before anyone has connected: who you are, where they are, which backend.
func _draw_lobby_setup(cx: float) -> void:
	var caret := "_" if fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.55 else " "

	for i in 2:
		var is_name := i == 0
		var r: Rect2 = _lobby_field_rect(i)
		var focused: bool = lobby_field == i
		_panel(r, Color("#111730"), Color(PLAYER_ACCENT, 0.55 if focused else 0.2), 10.0,
			2.0 if focused else 1.0)
		var hosting_code: bool = Link.is_host and Link.room_code != ""
		var label := "YOUR NAME"
		if not is_name:
			label = "YOUR ROOM CODE" if hosting_code else (
				"THEIR ROOM CODE" if _backend_uses_codes() else "THEIR ADDRESS")
		_otext(_font, Vector2(r.get_center().x, r.position.y - 14.0), label, 11,
			Color("#7c88ad"))

		var body: String = Link.my_name if is_name else join_ip
		var tint := Color("#e6ecff")
		var body_size := 22
		if not is_name and hosting_code:
			# Show the code to read out, not the field you type into. A short one
			# has room to be set large, which is most of the point of shortening
			# it — this is the thing somebody is squinting at over a call.
			body = _chunk_code(Link.room_code)
			tint = Color("#ffd166")
			focused = false
			if Link.short_codes():
				body_size = 34
		_text_fit_overlay(_font_bold, r.get_center(), body + (caret if focused else ""),
			body_size, r.size.x - 24.0, tint)

	var hint := "click a field to type in it · TAB switches · CTRL+V pastes"
	if Link.is_host and Link.room_code != "":
		hint = "click the code to copy it · they paste with CTRL+V"
	elif lobby_backend == Link.Backend.ROOM and not Link.short_codes(lobby_backend):
		# Worth the line while codes are 21 mixed-case characters: getting the
		# case wrong is the most likely reason a join goes nowhere.
		hint = "codes are case-sensitive · CTRL+V pastes · TAB switches field"
	if portrait:
		# TAB and CTRL+V are not on the drawn keyboard, so the only true half of
		# any of those lines is the tapping.
		hint = "tap the code to copy it" if (Link.is_host and Link.room_code != "") \
			else "tap a field to type in it"
	_otext(_font, Vector2(cx, _lobby_backend_rect(0).position.y - 38.0), hint, 12,
		Color("#5d6a92"))

	# Backend picker. Room codes go through the lobby server; direct dials an address.
	var slots := _backend_slots()
	var labels := {
		Link.Backend.EOS: "ROOM CODE",
		Link.Backend.ROOM: "ROOM CODE",
		Link.Backend.DIRECT: "DIRECT",
	}
	var subs := {
		Link.Backend.EOS: "five letters, works anywhere",
		Link.Backend.ROOM: "works anywhere, no port forwarding",
		Link.Backend.DIRECT: "LAN or a forwarded port",
	}
	var tints := {
		Link.Backend.EOS: Color("#c77dff"),
		Link.Backend.ROOM: Color("#c77dff"),
		Link.Backend.DIRECT: PLAYER_ACCENT,
	}
	for i in 2:
		var be: int = slots[i]
		var r: Rect2 = _lobby_backend_rect(i)
		var picked: bool = lobby_backend == be
		_panel(r, Color("#1b2444") if picked else Color("#141b33"),
			Color(tints[be], 0.9 if picked else 0.25), 10.0, 2.0)
		_otext(_font_bold, Vector2(r.get_center().x, r.get_center().y - 8.0),
			labels[be], 16, tints[be])
		_otext(_font, Vector2(r.get_center().x, r.get_center().y + 14.0), subs[be], 11,
			Color("#7c88ad"))


## Once connected: everyone in the room and who has readied up.
func _draw_room(cx: float) -> void:
	var ids := Link.peer_ids()
	var count := 1 + ids.size() + Link.bot_count
	var w := 250.0 if count > 2 else 320.0
	var seats := _room_seat_rects(count, w)

	for i in count:
		var mine := i == 0
		var is_bot := i > ids.size()
		var who: String = _show_name(Link.my_name) if mine else _show_name(
			"CPU %d" % (i - ids.size()) if is_bot else String(Link.roster[ids[i - 1]]["name"]))
		var set_up: bool = true if is_bot else (
			Link.my_ready if mine else bool(Link.roster[ids[i - 1]]["ready"]))
		var dev: int = Link.Device.KEYS
		if mine:
			dev = Link.my_device()
		elif not is_bot:
			dev = int(Link.roster[ids[i - 1]].get("device", Link.Device.KEYS))
		var tint: Color = SLOT_ACCENTS[i % SLOT_ACCENTS.size()]
		var r: Rect2 = seats[i]
		_panel(r, Color("#141b33"), Color(tint, 0.7 if set_up else 0.25), 12.0,
			3.0 if set_up else 2.0)
		_otext(_font, Vector2(r.get_center().x, r.position.y + 26.0),
			"YOU" if mine else ("COMPUTER" if is_bot else "CHALLENGER"), 11, Color("#7c88ad"))
		_text_fit_overlay(_font_bold, Vector2(r.get_center().x, r.position.y + 60.0),
			who.to_upper(), 26, r.size.x - 26.0, Color("#e6ecff"))
		_otext(_font_bold, Vector2(r.get_center().x, r.position.y + 98.0),
			"READY" if set_up else "not ready", 15,
			tint if set_up else Color("#5d6a92"))
		# What they are playing on, said before the match rather than worked out
		# thirty seconds into it. A CPU has no device worth naming.
		if not is_bot:
			var touch: bool = dev == Link.Device.TOUCH
			_text_fit_overlay(_font, Vector2(r.get_center().x, r.position.y + 116.0),
				Link.device_label(dev), 10, r.size.x - 20.0,
				Color("#7bdff2") if touch else Color("#5d6a92"), 8)

	var note := "ready up when you are"
	if Link.my_ready:
		var waiting: Array = []
		for id in ids:
			if not Link.roster[id]["ready"]:
				waiting.append(_show_name(String(Link.roster[id]["name"]).to_upper()))
		note = "waiting for %s" % ", ".join(waiting) if not waiting.is_empty() else "starting"
	var foot := _grid_bottom(seats, 360.0)
	_otext(_font, Vector2(cx, foot + 32.0), note, 14, Color("#8d99bd"))
	_text_fit_overlay(_font, Vector2(cx, foot + 54.0),
		"up to four boards — the host starts when everyone is ready", 12,
		get_viewport_rect().size.x - GRID_MARGIN * 2.0, Color("#5d6a92"), 10)


## Where everyone in the room sits. Four across on a desktop; on a phone they
## wrap to two rows rather than shrinking to a width a name cannot be read at.
func _room_seat_rects(count: int, w: float) -> Array:
	return _grid_rects(count, 232.0 + safe_top, count, w, 128.0, 16.0, 240.0, 12.0)


## The bottom of the seat grid, which everything else in a connected room hangs
## off. Recomputed rather than remembered, because `_menu_buttons` is called
## from the hit test as well as from the draw.
func _room_foot() -> float:
	var ids := Link.peer_ids()
	var count := 1 + ids.size() + Link.bot_count
	var w := 250.0 if count > 2 else 320.0
	return _grid_bottom(_room_seat_rects(count, w), 360.0 + safe_top)


## Where the house-rule switches start, under the buttons.
func _lobby_kinds_top() -> float:
	return _room_foot() + 196.0 if not portrait else _lobby_portrait_kinds_top()


## In portrait the buttons stack instead of flanking, so the switches start below
## whatever that came to rather than a fixed distance down.
func _lobby_portrait_kinds_top() -> float:
	var low := _room_foot() + 196.0
	for b: Dictionary in _menu_buttons():
		low = maxf(low, (b["rect"] as Rect2).end.y + 60.0)
	return low


## Both lobby fields go through here: names take anything printable, addresses
## only what an address can contain.
func _lobby_edit(ch: String, backspace: bool) -> void:
	if Link.connected:
		return
	if lobby_field == 0:
		var n := Link.my_name
		if backspace:
			n = n.substr(0, maxi(0, n.length() - 1))
		elif ch.length() == 1 and n.length() < 14 and ch.unicode_at(0) >= 32:
			n += ch.to_upper()
		else:
			return
		Link.set_name_and_save(n)
	else:
		if backspace:
			join_ip = join_ip.substr(0, maxi(0, join_ip.length() - 1))
		elif ch.length() == 1 and join_ip.length() < 40 and (
				ch.is_valid_int() or ch == "." or ch == ":" or ch == "-"
				or (ch.to_lower() >= "a" and ch.to_lower() <= "z")):
			# On a single-case alphabet the field can show what will actually be
			# sent, instead of letting somebody type a code in a case that is
			# about to be corrected out from under them on submit. Addresses are
			# left alone — hostnames are not ours to shout.
			if _backend_uses_codes() and Link.short_codes(lobby_backend):
				join_ip += ch.to_upper()
			else:
				join_ip += ch
		else:
			return
	Sfx.play("back" if backspace else "key", randf_range(0.92, 1.10))


## Groups a code for reading aloud. Short single-case codes split in threes,
## which is how people say them; long mixed-case ones split in fives.
##
## Never change the case here. On the default alphabet codes are case-sensitive,
## and a player reading an upper-cased one off the screen would type something
## that does not exist. On a single-case alphabet there is nothing to change.
func _chunk_code(code: String) -> String:
	var every := 3 if Link.short_codes() else 5
	var out := ""
	for i in code.length():
		if i > 0 and i % every == 0:
			out += " "
		out += code[i]
	return out


## Overlay twin of `_text_fit`, since the lobby draws on the overlay layer.
func _text_fit_overlay(font: Font, center: Vector2, text: String, size: int,
		max_width: float, color: Color, min_size: int = 9) -> void:
	if font == null or text == "":
		return
	var s := size
	while s > min_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > max_width:
		s -= 1
	_otext(font, center, text, s, color)


## Name and room code. `min_w` is set above what a 720px screen can give two of
## them, so portrait stacks rather than squeezing — a room code being read out
## over a call is the one string in this game that has to stay large.
func _lobby_field_rect(i: int) -> Rect2:
	return _grid_rects(2, 234.0 + safe_top, 2, 320.0, 52.0, 20.0, 340.0, 34.0)[i]


## Which backends the picker offers, in slot order.
##
## EOS takes the code slot whenever credentials are present: it is the same
## "share a code" experience, but five readable characters instead of the
## orchestrator's twenty-one, and rooms can be listed. noray stays the fallback
## for an unconfigured checkout, so there are always exactly two slots to draw
## and the existing layout is untouched.
func _backend_slots() -> Array:
	if EOSConfig.is_configured():
		return [Link.Backend.EOS, Link.Backend.DIRECT]
	return [Link.Backend.ROOM, Link.Backend.DIRECT]


## True when the join field holds a room code rather than an address. Both the
## noray and EOS paths are code-based; only DIRECT dials a host.
func _backend_uses_codes() -> bool:
	return lobby_backend == Link.Backend.ROOM or lobby_backend == Link.Backend.EOS


func _lobby_backend_rect(i: int) -> Rect2:
	var top := _lobby_field_rect(1).end.y + 82.0
	return _grid_rects(2, top, 2, 320.0, 56.0, 20.0, 340.0, 14.0)[i]


func _draw_rules_panel(size: Vector2) -> void:
	var cx := size.x * 0.5
	# The panel was 860 wide against a 720 screen, so on a phone its border was
	# off both edges and every line of it overhung. Width and wrapping now come
	# from the screen, which means the paragraphs below are written as sentences
	# and broken by the font rather than by hand at one particular width.
	var pw: float = minf(860.0, size.x - GRID_MARGIN * 2.0)
	var inner: float = pw - 40.0
	var paras := [
		"Type a word, fire with %s. Its LAST letters brand a block on your rival." % [
			"the FIRE key" if portrait else "SPACE or ENTER"],
		"Clear a block by typing a word that STARTS with its letters. Garbage is ONLY ever "
			+ "removed that way — nothing you send blocks it. Answer it while still inbound "
			+ "and it never lands. One word reaches one block per two letters: four AL "
			+ "blocks need ALIGNMENT.",
		"Block size comes only from your chain: 1, 2, 3, 5, 7, 9 words for each step up. "
			+ "A tenth word cashes the run in as a SALVO of single blocks and resets you to "
			+ "nothing. Pause or fire a non-word and the run is gone.",
		"Topping out costs one of THREE LIVES and wipes your board — it does not end the "
			+ "match. Words score by their letters, times your chain, times what they broke. "
			+ "Overfilling somebody's board pays a bonus, and so does winning.",
		"With three or more boards in play, every attacker past the first aiming at "
			+ "the same board hits a tier harder. Ganging up works, and being ganged "
			+ "up on is worth re-aiming over.",
	]

	# Measured before the panel is drawn, so the panel is the height of what is
	# going in it rather than a number that happened to be right at 1280.
	var body := 0.0
	for p: String in paras:
		body += _font.get_multiline_string_size(
			p, HORIZONTAL_ALIGNMENT_CENTER, inner, 14).y + 10.0
	var top: float = 172.0 + safe_top
	_panel(Rect2(cx - pw * 0.5, top, pw, body + _rules_extra() + 40.0),
		Color("#111730"), Color(PLAYER_ACCENT, 0.22), 12.0)

	var y: float = top + 22.0
	for p: String in paras:
		var mh: float = _font.get_multiline_string_size(
			p, HORIZONTAL_ALIGNMENT_CENTER, inner, 14).y
		_overlay.draw_multiline_string(_font,
			Vector2(cx - inner * 0.5, y + _font.get_ascent(14)),
			p, HORIZONTAL_ALIGNMENT_CENTER, inner, 14, -1, Color("#aab4d4"))
		y += mh + 10.0

	# Special blocks only appear in the list when they are switched on. A rules
	# screen listing rules that are not in play is worse than one that is short.
	if not block_kinds.is_empty():
		y += 6.0
		var on: Array = []
		for id: String in KIND_ORDER:
			if block_kinds.has(id):
				on.append("%s — %s" % [String(KIND_BLURB[id][0]).to_upper(),
					String(KIND_BLURB[id][1])])
		# Six of these joined together is far too long for one line at any width,
		# and shrinking the type until it fits produces something nobody reads.
		# Wrapped, like the paragraphs above it.
		var kinds_line := "SPECIAL BLOCKS IN PLAY: " + "  ·  ".join(on)
		var kh: float = _font.get_multiline_string_size(
			kinds_line, HORIZONTAL_ALIGNMENT_CENTER, inner, 12).y
		_overlay.draw_multiline_string(_font,
			Vector2(cx - inner * 0.5, y - 8.0 + _font.get_ascent(12)),
			kinds_line, HORIZONTAL_ALIGNMENT_CENTER, inner, 12, -1, Color("#ffd166"))
		y += kh + 6.0

	# Power words are worth spelling out here, but they are meant to be met in
	# play first: the game announces one the first time you manage it by
	# accident, and this is where you come to find out what happened.
	y += 12.0
	_overlay.draw_rect(Rect2(cx - inner * 0.5, y - 8.0, inner, 1.0),
		Color(PLAYER_ACCENT, 0.2), true)
	y += 16.0
	_otext(_font_bold, Vector2(cx, y), "POWER WORDS", 15, Color("#e6ecff"))
	y += 24.0
	var how := {
		"COUNTER": "shoot down something already inbound     send one straight back",
		"COMBO": "break three blocks at once     your next attack is a tier bigger",
		"PERFECT": "break three WITHOUT dropping your run     a whole extra attack",
		"CLUTCH": "break anything with one row left     the garbage nearly stops",
	}
	# Measured first so the four rows share one column layout: names right-aligned
	# against a common edge, bodies all starting at the same x. Centring each row
	# on its own width reads as four unrelated notes rather than a table.
	var name_w := 0.0
	for name: String in POWER_ORDER:
		name_w = maxf(name_w, _font_bold.get_string_size(
			name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x)
	# The bodies are a trigger and a reward separated by a wide gap, and the gap
	# is what makes them read as two columns. There is no room for a gap that
	# wide at 720, so on a phone the reward goes on its own line under it — two
	# lines that mean something beats one line squeezed until neither does.
	var stacked := portrait
	var body_w := 0.0
	for name: String in POWER_ORDER:
		for part: String in _power_parts(String(how[name]), stacked):
			body_w = maxf(body_w, _font.get_string_size(
				part, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x)
	var left := cx - (name_w + 18.0 + body_w) * 0.5

	for name: String in POWER_ORDER:
		var tint := Color(String(POWERS[name]["tint"]))
		var nm := _font_bold.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		_otext(_font_bold, Vector2(left + name_w - nm.x * 0.5, y), name, 14, tint)
		for part: String in _power_parts(String(how[name]), stacked):
			var bd := _font.get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
			_otext(_font, Vector2(left + name_w + 18.0 + bd.x * 0.5, y), part, 13,
				Color("#8d99bd"))
			y += 19.0
		y += 5.0 if stacked else 5.0


## A power word's line, as one column or two rows.
func _power_parts(text: String, stacked: bool) -> Array:
	if not stacked:
		return [text]
	var out: Array = []
	for part: String in text.split("     ", false):
		out.append(part.strip_edges())
	return out if out.size() > 1 else [text]


## Everything under the paragraphs: the special-block line when there is one,
## the rule, the heading, and a row per power word.
func _rules_extra() -> float:
	var rows: float = float(POWER_ORDER.size()) * (43.0 if portrait else 24.0)
	# The block list wraps, so on a narrow screen it is worth two or three lines.
	var kinds: float = 0.0
	if not block_kinds.is_empty():
		kinds = 25.0 if not portrait else 70.0
	return 12.0 + 16.0 + 24.0 + rows + kinds


func _draw_gameover(size: Vector2) -> void:
	var cx := size.x * 0.5
	# Nearly opaque. The boards used to show faintly through, which was pleasant
	# until the summary grew a score of its own — the live one underneath sits in
	# almost the same place, and two different numbers ghosting through each
	# other reads as a rendering fault.
	_overlay.draw_rect(Rect2(-SHAKE_MARGIN, -SHAKE_MARGIN,
		size.x + SHAKE_MARGIN * 2.0, size.y + SHAKE_MARGIN * 2.0), Color(bg_top, 0.985), true)

	var win := winner == "YOU"
	var tint := Color("#ffd166") if win else Color("#ff6b6b")

	# The earned victory animation, behind everything else on the screen and only
	# ever on a win. Losing gets the plain card: a celebration that fires either
	# way is not a celebration.
	if win:
		var t := Time.get_ticks_msec() / 1000.0
		match Profile.worn("victory"):
			"confetti":
				Cosmetics.victory_confetti(_overlay, size, t, tint)
			"rays":
				Cosmetics.victory_rays(_overlay, Vector2(cx, 150.0), t, tint)
			"shatter":
				Cosmetics.victory_shatter(_overlay, Vector2(cx, 150.0), t, tint)
			"supernova":
				Cosmetics.victory_supernova(_overlay, size, Vector2(cx, 200.0), t, tint)

	_otext(_font_bold, Vector2(cx, 132), "YOU WIN" if win else "YOU LOSE", 68, tint)
	var wm := _font_bold.get_string_size("YOU WIN" if win else "YOU LOSE",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 68)
	_overlay.draw_rect(Rect2(cx - wm.x * 0.5, 170, wm.x, 3), Color(tint, 0.45), true)

	# The score is the headline, above the tiles rather than inside one. Winning
	# is binary and says nothing about how well you played; this is the number
	# worth arguing over afterwards.
	_otext(_font, Vector2(cx, 204), "SCORE", 13, Color("#7c88ad"))
	_otext(_font_bold, Vector2(cx, 248), _commas(player.score), 62, Color("#ffd166"))
	if player.best_word != "":
		_otext(_font, Vector2(cx, 288),
			"best word — %s for %s" % [_show(player.best_word.to_upper()),
				_commas(player.best_word_score)], 14, Color("#8d99bd"))

	# Time and words-per-minute are the two numbers here that are only ever
	# yours: there is no such thing as a CPU's typing speed, and a peer's is not
	# sent. Everything else is comparable, so everything else went into the
	# table below rather than being said twice.
	var subtitle := "%d:%02d  ·  %d wpm  ·  %s" % [
		int(match_time) / 60, int(match_time) % 60, int(round(_wpm())),
		difficulty.to_upper() if not net_active() else "VERSUS"]
	if mode == Mode.DAILY:
		subtitle = "DAILY BOARD  ·  %s  ·  %d wpm" % [daily_key(), int(round(_wpm()))]
	_otext(_font, Vector2(cx, 312), subtitle, 13, Color("#7c88ad"))

	_draw_scoreboard(size, _scoreboard_top(), tint)

	for b: Dictionary in _menu_buttons():
		_draw_menu_button(b)

	if mode == Mode.DAILY:
		var run: Dictionary = Profile.daily_result(daily_key())
		var line := "best ever %s" % _commas(Profile.daily_best)
		if Profile.daily_streak > 1:
			line += "      %d days running" % Profile.daily_streak
		if int(run.get("score", 0)) >= Profile.daily_best and Profile.daily_best > 0:
			line = "a new best      " + line
		_text_fit_overlay(_font_bold, Vector2(cx, _over_foot() + 26.0), line, 14,
			size.x - GRID_MARGIN * 2.0, Color("#ffd166"), 11)

	# Where an ad would go, and the only thing standing in for one is a line
	# saying so. The placement is the part worth having early: it is at the end
	# of a match, on a screen the player is already reading, rather than
	# interrupting anything — and it asks the same `ad_due` a real one would.
	if Profile.ad_due() and mode == Mode.NORMAL:
		_text_fit_overlay(_font, Vector2(cx, _over_foot() + 4.0),
			"[ ad break would play here — Premium pack removes them ]", 12,
			size.x - GRID_MARGIN * 2.0, Color("#4d5878"), 10)

	var strip_bottom := _draw_mastery_strip(cx)

	# Two keys, because there are now two. This used to advertise 1 – 7 for a new
	# opponent and P for mastery, which were exactly the shortcuts that made the
	# summary impossible to read — and it was pinned at 674, which the buttons
	# now sit on top of.
	if not portrait:
		_otext(_font, Vector2(cx, strip_bottom + 26.0),
			"click Rematch to go again      ESC — title", 13, Color("#4d5878"))


const SCORE_ROW_H := 34.0
const SCORE_HEAD_H := 22.0


func _scoreboard_top() -> float:
	return 342.0 + safe_top


## Which columns the table carries. Powers and salvos are the first to go on a
## narrow screen: they are the rarest events in a match and often read 0 across
## every row, where words and clears always say something.
func _scoreboard_cols() -> Array:
	if portrait:
		return ["SCORE", "WORDS", "CLEARED", "CHAIN"]
	return ["SCORE", "WORDS", "CLEARED", "CHAIN", "POWERS", "SALVOS"]


## Everyone who played, best first.
##
## The summary used to print your own eight numbers and "versus Duelist"
## underneath — which told you how you did, and nothing whatever about how you
## did *against them*. In a free-for-all it did not even say who came second.
## Same numbers for every board, sorted, so the screen answers the question the
## match just asked.
func _scoreboard_sides() -> Array:
	var out: Array = []
	for s: SideState in sides:
		if s.in_match:
			out.append(s)
	out.sort_custom(func(a: SideState, b: SideState) -> bool: return a.score > b.score)
	return out


func _draw_scoreboard(size: Vector2, top: float, tint: Color) -> void:
	var rows := _scoreboard_sides()
	if rows.is_empty():
		return
	var cols := _scoreboard_cols()
	var tw: float = minf(760.0, size.x - GRID_MARGIN * 2.0)
	var x0: float = size.x * 0.5 - tw * 0.5
	# The name gets the left third and the numbers share the rest evenly, so the
	# columns line up whether there are four of them or six.
	var name_w: float = tw * 0.32
	var col_w: float = (tw - name_w) / float(cols.size())

	for i in cols.size():
		_otext(_font, Vector2(x0 + name_w + col_w * (float(i) + 0.5), top), cols[i], 10,
			Color("#5d6a92"))

	var y := top + SCORE_HEAD_H
	for s: SideState in rows:
		var mine: bool = s == player
		# Who actually won, not who happened to still be standing — in a
		# free-for-all the match can end with three boards alive, and marking
		# all of them is the same as marking none.
		var won: bool = (winner == "YOU") if mine else (s.label == winner)
		var r := Rect2(x0, y, tw, SCORE_ROW_H)
		# Your own row is picked out because it is the one you are looking for,
		# and the winner's because it is the one the match was about. When they
		# are the same row it simply gets both.
		_panel(r, Color("#1b2444") if mine else Color("#121930"),
			Color(s.accent, 0.85 if mine else 0.28), 8.0, 2.0 if mine else 1.0)
		if won:
			_overlay.draw_rect(Rect2(r.position.x + 3.0, r.position.y + 7.0, 3.0,
				r.size.y - 14.0), Color("#ffd166"), true)

		_text_fit_overlay(_font_bold, Vector2(x0 + name_w * 0.5, r.get_center().y),
			_show(s.label).to_upper(), 15, name_w - 26.0,
			Color("#e6ecff") if (mine or won) else Color("#8d99bd"))

		var vals := {
			"SCORE": _commas(s.score),
			"WORDS": str(s.words_played),
			"CLEARED": str(s.blocks_cleared),
			"CHAIN": "x%d" % s.best_chain,
			"POWERS": str(s.powers_fired),
			"SALVOS": str(s.salvos),
		}
		for i in cols.size():
			var key: String = cols[i]
			var lead: bool = key == "SCORE" and s == rows[0]
			_text_fit_overlay(_font_bold,
				Vector2(x0 + name_w + col_w * (float(i) + 0.5), r.get_center().y),
				String(vals[key]), 17 if key == "SCORE" else 15, col_w - 10.0,
				Color("#ffd166") if lead else Color("#e6ecff"))
		y += SCORE_ROW_H + 6.0

	# The longest word anyone managed, which is the other thing worth arguing
	# over and does not fit in a column.
	var best: SideState = null
	for s: SideState in rows:
		if best == null or s.longest_word.length() > best.longest_word.length():
			best = s
	if best != null and best.longest_word != "":
		_otext(_font, Vector2(size.x * 0.5, y + 12.0),
			"longest word — %s by %s" % [_show(best.longest_word.to_upper()),
				_show(best.label).to_upper()], 12, Color(tint, 0.75))


## The bottom of the table, which the buttons and the mastery strip hang off.
func _over_foot() -> float:
	var n := maxi(1, _scoreboard_sides().size())
	return _scoreboard_top() + SCORE_HEAD_H + float(n) * (SCORE_ROW_H + 6.0) + 20.0


## What the match just did to your record. This is the hook — win or lose, the
## screen has something on it that went up — so it runs under both results, and
## a level-up gets announced rather than left to be noticed.
## Returns the bottom of whatever it drew, so the line under it does not have to
## guess. When there is nothing earned — practice, or a match that banked
## nothing — that is just the bottom of the buttons.
func _draw_mastery_strip(cx: float) -> float:
	var buttons_foot := 570.0
	for b: Dictionary in _menu_buttons():
		buttons_foot = maxf(buttons_foot, (b["rect"] as Rect2).end.y)
	if earned.is_empty():
		return buttons_foot
	var gained := int(earned.get("xp", 0))
	var from_lv := int(earned.get("from", 1))
	var to_lv := int(earned.get("to", 1))
	var fresh: Array = earned.get("new", [])
	var prog := Profile.level_progress()

	# One row: what you earned on the left, the bar in the middle, where it put
	# you on the right. A level-up takes over that right-hand label rather than
	# claiming a line of its own — there is no room above it that the buttons
	# and their shadows are not already using.
	# Under the buttons, which are one row on a desktop and two on a phone. The
	# bar narrows to leave room for the labels either side of it.
	var strip_y: float = maxf(570.0, buttons_foot + 32.0)
	var bw: float = minf(352.0, get_viewport_rect().size.x - 240.0)
	var bar := Rect2(cx - bw * 0.5, strip_y, bw, 9.0)
	_panel(bar, Color("#141b33"), Color("#ffd166", 0.22), 5.0, 1.0)
	_overlay.draw_rect(Rect2(bar.position + Vector2(2, 2),
		Vector2((bar.size.x - 4.0) * float(prog["frac"]), bar.size.y - 4.0)),
		Color("#ffd166"), true)
	# Hung off the bar's own edges rather than at a fixed offset each side: the
	# left label was 56 out and the right one 72, which put the whole row a few
	# units left of the bar it belongs to.
	var xp_text := "+%s XP" % _commas(gained)
	var xp_w := _font_bold.get_string_size(xp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	_otext(_font_bold, Vector2(bar.position.x - 14.0 - xp_w * 0.5, strip_y + 4.0),
		xp_text, 15, Color("#ffd166"))

	if to_lv > from_lv:
		var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 170.0)
		var lv_text := "LEVEL %d" % to_lv
		var lv_w := _font_bold.get_string_size(lv_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		_otext(_font_bold, Vector2(bar.end.x + 14.0 + lv_w * 0.5, strip_y + 4.0),
			lv_text, 19, Color("#ffd166") * Color(1, 1, 1, pulse))
	else:
		var to_text := "%s to level %d" % [
			_commas(int(prog["need"]) - int(prog["into"])), to_lv + 1]
		var to_w: float = minf(120.0,
			_font.get_string_size(to_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x)
		_text_fit_overlay(_font, Vector2(bar.end.x + 14.0 + to_w * 0.5, strip_y + 4.0),
			to_text, 12, 120.0, Color("#8d99bd"), 9)

	if not fresh.is_empty():
		# Two at most. A wall of unlocks reads as a patch note; two reads as a
		# reward, and the rest are waiting on the mastery screen anyway.
		var line := " · ".join(fresh.slice(0, mini(2, fresh.size())))
		if fresh.size() > 2:
			line += "  (+%d more)" % (fresh.size() - 2)
		_text_fit_overlay(_font_bold, Vector2(cx, strip_y + 34.0), "UNLOCKED — " + line, 14,
			minf(980.0, get_viewport_rect().size.x - GRID_MARGIN * 2.0), Color("#7bdff2"), 10)
		return strip_y + 34.0
	return strip_y + 10.0


# ------------------------------------------------------------------ networking
#
# The connection itself lives in the `Link` autoload. This half only translates
# between its signals and the match: incoming packets become garbage on our own
# board, and our own attacks become outgoing packets.

const NET_STATE_HZ := 15.0

var net_typing := ""
var _net_state_timer := 0.0


func net_active() -> bool:
	return Link.active


func _net_setup() -> void:
	Link.match_begin.connect(_on_net_match_begin)
	Link.peer_left.connect(_on_net_peer_left)
	Link.rematch_agreed.connect(_on_net_rematch)
	Link.attack_received.connect(_on_net_attack)
	Link.salvo_received.connect(_on_net_salvo)
	Link.pressure_received.connect(_seed_pressure)
	Link.opponent_topped_out.connect(func(): _end_match(ai_side))
	Link.state_received.connect(_on_net_state)
	Link.topout_credit.connect(_on_topout_credit)


func _on_net_match_begin() -> void:
	var plan: Array = Link.seating
	var me := multiplayer.get_unique_id()
	# You are always your own board 0; the rest keep the host's order.
	var others: Array = []
	for seat: Dictionary in plan:
		if int(seat["id"]) != me:
			others.append(seat)

	# Everyone plays the host's rules. The seating carries them, so this is the
	# last chance for the two machines to disagree — and they do not.
	for seat: Dictionary in plan:
		if seat.has("kinds"):
			block_kinds = (seat["kinds"] as Array).duplicate()
			break
	start_match("Versus", others.size())
	for i in others.size():
		if i + 1 >= SLOTS:
			break
		var s: SideState = sides[i + 1]
		var seat: Dictionary = others[i]
		s.in_match = true
		s.alive = true
		s.peer_id = int(seat["id"])
		s.label = String(seat["name"])
		s.device = int(seat.get("device", Link.Device.KEYS))
		# Only the host actually runs the bots; everyone else just watches them.
		# The seat name IS the personality — the host chose it when it built the
		# seating, so both ends already agree on who this is.
		if s.peer_id < 0 and Link.is_host:
			s.bot = AiOpponent.new()
			s.bot.configure(s.label)
		else:
			s.bot = null
	player.device = Link.my_device()
	_apply_handicap()
	_layout_boards()
	_aim_everyone()


## A phone typist against a keyboard typist is giving away roughly half their
## speed, in a game whose whole currency is speed. So in a room with both, the
## phones get a longer chain window — the run survives a slower gap between
## words.
##
## The window rather than the damage on purpose. The deficit is time, so the
## compensation is time: it buys back the thinking room that thumbs cost you
## without changing what a word is worth, which would make the two players be
## playing different games rather than the same one at different speeds.
##
## Only ever in a mixed room. Everybody on phones is a fair fight already, and
## so is everybody on keys — a handicap there would just be a slower game.
func _apply_handicap() -> void:
	var touch := 0
	var keys := 0
	for s: SideState in sides:
		if not s.in_match:
			continue
		if s.device == Link.Device.TOUCH:
			touch += 1
		else:
			keys += 1
	var mixed: bool = touch > 0 and keys > 0
	for s: SideState in sides:
		s.grace = TOUCH_GRACE if (mixed and s.device == Link.Device.TOUCH) else 1.0
	if mixed and player.grace > 1.0:
		_say("phone handicap — longer chains", Color("#7bdff2"))


func _on_net_peer_left(why: String) -> void:
	if phase == Phase.PLAY or phase == Phase.COUNTDOWN:
		# Whoever is gone is simply out; the rest play on.
		for s: SideState in sides:
			if s.in_match and s.peer_id != 0 and not Link.roster.has(s.peer_id):
				s.alive = false
		_aim_everyone()
		if _living().size() > 1:
			_log(why, Color("#ff6b6b"))
			return
	if phase == Phase.PLAY or phase == Phase.COUNTDOWN:
		_log(why, Color("#ff6b6b"))
		winner = "YOU"
		phase = Phase.OVER
		Sfx.play("win")
	elif phase != Phase.LOBBY:
		phase = Phase.TITLE


## A rematch puts both players back in the room to ready up again, rather than
## silently restarting on one player's say-so.
func _on_net_rematch() -> void:
	phase = Phase.LOBBY
	_hover_action = ""


func _on_net_attack(word: String, tier: int, victim: int) -> void:
	var side := _side_for_entity(victim)
	if side == null:
		return
	var p := Pending.new()
	# Whoever sent the packet. Their machine holds their score, so a topout has
	# to be reported back to them rather than paid here.
	p.from = multiplayer.get_remote_sender_id()
	p.tier = clampi(tier, 0, TIERS.size() - 1)
	p.prefix = _mint_stamp(word, STAMP_WANT, side)
	p.cells = _cells(p.tier)
	p.timer = DROP_DELAY
	side.pending.append(p)
	side.flash = 1.0


func _on_net_salvo(word: String, count: int, victim: int) -> void:
	var side := _side_for_entity(victim)
	if side == null:
		return
	for i in mini(count, 40):
		var p := Pending.new()
		p.tier = 0
		p.prefix = _mint_stamp(word, STAMP_WANT, side)
		p.cells = 1
		p.timer = DROP_DELAY + i * 0.10
		side.pending.append(p)
	side.flash = 1.0
	if side == player:
		Sfx.play("salvo", 1.0, -6.0)


## Whose board a packet is about. Zero means "mine"; a negative id is one of the
## bots this machine is running.
func _side_for_entity(id: int) -> SideState:
	if id == 0:
		return player
	for s: SideState in sides:
		if s.in_match and s.peer_id == id:
			return s
	return null


func _on_net_state(payload: Dictionary) -> void:
	var ai_side := _side_for_entity(int(payload.get("own", 0)))
	if ai_side == null or ai_side == player:
		return
	ai_side.board.mirror_blocks(payload.get("b", []))

	ai_side.pending.clear()
	for spec: Array in payload.get("p", []):
		var p := Pending.new()
		p.tier = clampi(int(spec[0]), 0, TIERS.size() - 1)
		p.prefix = String(spec[1])
		p.cells = _cells(p.tier)
		p.timer = float(spec[2])
		ai_side.pending.append(p)

	ai_side.typing = String(payload.get("t", ""))
	ai_side.chain = int(payload.get("c", 0))
	ai_side.chain_timer = float(payload.get("ct", 0.0))
	ai_side.chain_window = maxf(0.001, float(payload.get("cw", 1.0)))
	ai_side.words_played = int(payload.get("w", 0))
	ai_side.blocks_cleared = int(payload.get("cl", 0))
	# Defaulted to what is already held rather than to zero, so a payload from an
	# older build leaves these alone instead of blanking them every tick.
	ai_side.score = int(payload.get("sc", ai_side.score))
	ai_side.best_chain = int(payload.get("bc", ai_side.best_chain))
	ai_side.best_combo = int(payload.get("bk", ai_side.best_combo))
	ai_side.powers_fired = int(payload.get("pw", ai_side.powers_fired))
	ai_side.salvos = int(payload.get("sv", ai_side.salvos))
	ai_side.longest_word = String(payload.get("lw", ai_side.longest_word))
	ai_side.salvo_flash = float(payload.get("sf", 0.0))
	ai_side.lives = int(payload.get("lv", LIVES))
	ai_side.respite = float(payload.get("rs", 0.0))
	ai_side.life_flash = float(payload.get("lf", 0.0))
	ai_side.alive = bool(payload.get("al", true))


func _push_state(delta: float) -> void:
	_net_state_timer -= delta
	if _net_state_timer > 0.0:
		return
	_net_state_timer = 1.0 / NET_STATE_HZ

	Link.send_state(_state_of(player, multiplayer.get_unique_id()))
	# The host also speaks for every bot at the table.
	for s: SideState in sides:
		if s.bot != null and s.in_match:
			Link.send_state(_state_of(s, s.peer_id))


func _state_of(who: SideState, own: int) -> Dictionary:
	var block_specs: Array = []
	for b in who.board.blocks:
		block_specs.append([b.gx, b.gy, b.w, b.h, b.tier, b.prefix, b.kind, b.hits,
			b.fuse])
	var pend_specs: Array = []
	for p: Pending in who.pending:
		pend_specs.append([p.tier, p.prefix, p.timer])

	return {
		"own": own, "b": block_specs, "p": pend_specs, "t": _typing_of(who),
		"c": who.chain, "ct": who.chain_timer, "cw": who.chain_window,
		"w": who.words_played, "cl": who.blocks_cleared,
		"sf": who.salvo_flash, "lv": who.lives, "rs": who.respite,
		"lf": who.life_flash, "al": who.alive,
		# Everything the end-of-match scoreboard reads. Only words and clears
		# used to be sent, because only words and clears were ever shown live —
		# so against a real person every other column was the local default of
		# zero, and a peer who had just won on score appeared to have scored
		# nothing. A CPU looked right because a CPU is simulated on this machine.
		"sc": who.score, "bc": who.best_chain, "bk": who.best_combo,
		"pw": who.powers_fired, "sv": who.salvos, "lw": who.longest_word,
	}


# ----------------------------------------------------------------- menu pieces

## Menu buttons are built from one description so drawing and hit-testing can
## never disagree about where they are.
func _menu_buttons() -> Array:
	var out: Array = []
	var cx := get_viewport_rect().size.x * 0.5

	if paused and phase == Phase.PLAY:
		var w := 300.0
		out.append({
			"rect": Rect2(cx - w - 10.0, 372.0, w, 84.0), "key": "ESC",
			"label": "Resume", "sub": "", "note": "", "rating": 0,
			"accent": PLAYER_ACCENT, "action": "resume"})
		out.append({
			"rect": Rect2(cx + 10.0, 372.0, w, 84.0), "key": "Q",
			"label": "Leave match", "sub": "", "note": "", "rating": 0,
			"accent": Color("#ff6b6b"), "action": "leave_match"})
		return out

	# SPLASH counts as TITLE here: the menu is being drawn underneath the art as
	# it dissolves, and a screen that snapped its buttons in at the last frame
	# would undo the point of cross-fading at all. Nothing can be clicked yet —
	# input is still swallowed by the splash.
	if phase == Phase.TITLE or phase == Phase.SPLASH:
		# Nothing behind the rules screen is clickable; see `_draw_title`.
		if show_rules and phase == Phase.TITLE:
			return out
		for d: Dictionary in _title_plates():
			out.append(d)
		return out
	elif phase == Phase.SOLO:
		# Under the switches rather than at 596, which the roster now overruns on
		# anything narrower than a desktop.
		var sfoot := _solo_foot() + 26.0
		var sw: float = minf(300.0, get_viewport_rect().size.x - GRID_MARGIN * 2.0)
		out.append({
			"rect": Rect2(cx - sw * 0.5, sfoot, sw, 46.0), "key": "ENTER",
			"label": "Start", "sub": "", "note": "", "rating": 0,
			"accent": Color("#7bdff2"), "action": "solo_start"})
		# Portrait already has the chevron in the corner; a second Back inside the
		# screen is the same button twice.
		if not portrait:
			out.append({
				"rect": Rect2(cx - sw * 0.5, sfoot + 52.0, sw, 32.0), "key": "ESC",
				"label": "Back", "sub": "", "note": "", "rating": 0,
				"accent": Color("#8d99bd"), "action": "title"})
	elif phase == Phase.LOBBY:
		# Restored. A slice-replacement while splitting the title screen into
		# four doors took this whole branch out with it, which left every button
		# in the versus lobby drawn nowhere and clickable nowhere — Host, Join,
		# Ready up, Leave, Add CPU. The keyboard shortcuts still worked, which is
		# exactly why it survived the network testing that came after.
		if Link.connected:
			# All measured off the bottom of the seat grid, which is one row on a
			# desktop and two on a phone. The offsets are chosen to land on the
			# old constants at 1280, so the landscape screen is unmoved.
			var rfoot := _room_foot()
			# The CPU buttons flank the Ready button on a desktop. There is no
			# room to flank anything at 720, so in portrait they go underneath.
			var ready := Rect2(cx - 170.0, rfoot + 48.0, 340.0, 66.0)
			if portrait:
				var rw: float = minf(340.0, get_viewport_rect().size.x - GRID_MARGIN * 2.0)
				ready = Rect2(cx - rw * 0.5, rfoot + 48.0, rw, 66.0)
			var bots: Array = []
			if Link.is_host and Link.bot_count > 0:
				bots.append(["-", "Drop CPU", Color("#8d99bd"), "dropbot"])
			if Link.is_host and Link.free_seats() > 0:
				bots.append(["+", "Add CPU", Color("#ffd166"), "addbot"])
			for i in bots.size():
				var b2: Array = bots[i]
				var br := Rect2(cx - 336.0, ready.position.y, 150.0, 66.0)
				if String(b2[3]) == "addbot" and not portrait:
					br = Rect2(cx + 186.0, ready.position.y, 150.0, 66.0)
				if portrait:
					var half: float = (ready.size.x - 12.0) * 0.5
					br = Rect2(ready.position.x + float(i) * (half + 12.0),
						ready.end.y + 10.0, half, 56.0)
				out.append({
					"rect": br, "key": String(b2[0]), "label": String(b2[1]),
					"sub": "", "note": "", "rating": 0,
					"accent": b2[2], "action": String(b2[3])})
			out.append({
				"rect": ready, "key": "ENTER",
				"label": "Not ready" if Link.my_ready else "Ready up",
				"sub": "", "note": "", "rating": 0,
				"accent": Color("#ffd166") if Link.my_ready else PLAYER_ACCENT,
				"action": "ready"})
			# Leaving a room is not going back a screen — it disconnects other
			# people's lobby — so this one keeps its button in portrait too.
			var lv := rfoot + 124.0
			if portrait:
				lv = ready.end.y + (76.0 if bots.is_empty() else 76.0 + 56.0)
			out.append({
				"rect": Rect2(cx - 90.0, lv, 180.0, 38.0), "key": "ESC",
				"label": "Leave", "sub": "", "note": "", "rating": 0,
				"accent": Color("#8d99bd"), "action": "leave"})
		else:
			var jt := _lobby_backend_rect(1).end.y + 24.0
			var joins := _grid_rects(2, jt, 2, 320.0, 66.0, 20.0, 340.0, 12.0)
			out.append({
				"rect": joins[0], "key": "CTRL+H",
				"label": "Host", "sub": "", "note": "", "rating": 0,
				"accent": PLAYER_ACCENT, "action": "host"})
			out.append({
				"rect": joins[1], "key": "ENTER",
				"label": "Join", "sub": "", "note": "", "rating": 0,
				"accent": Color("#c77dff"), "action": "join"})
			if not portrait:
				out.append({
					"rect": Rect2(cx - 90.0, (joins[1] as Rect2).end.y + 16.0, 180.0, 44.0),
					"key": "ESC", "label": "Back", "sub": "", "note": "", "rating": 0,
					"accent": Color("#8d99bd"), "action": "title"})
	elif phase == Phase.PRACTICE:
		var doors2 := _practice_door_rects()
		out.append({
			"rect": doors2[0], "key": "1",
			"label": "Tutorial", "sub": "seven steps, no opponent", "note": "",
			"rating": 0, "accent": Color("#90be6d"), "action": "tutorial"})
		out.append({
			"rect": doors2[1], "key": "2",
			"label": "Training", "sub": "drill it at your own pace", "note": "",
			"rating": 0, "accent": Color("#7bdff2"), "action": "training"})
		var paces := _practice_pace_rects()
		for i in TRAINING_PACE.size():
			var pace: Dictionary = TRAINING_PACE[i]
			out.append({
				"rect": paces[i],
				"key": "", "label": String(pace["name"]),
				"sub": String(pace["note"]), "note": "", "rating": 0,
				"accent": Color("#ffd166") if train_pace == i else Color("#4d5878"),
				"action": "pace:%d" % i})
		if not portrait:
			out.append({
				"rect": Rect2(cx - 90.0, _grid_bottom(paces, 464.0) + 96.0, 180.0, 40.0),
				"key": "ESC", "label": "Back", "sub": "", "note": "", "rating": 0,
				"accent": Color("#8d99bd"), "action": "title"})
	elif phase == Phase.SETTINGS:
		# Portrait has the chevron, and 598 was landing on top of the name row —
		# the rows start lower once the safe area pushes them down.
		if not portrait:
			var rws := _settings_rows()
			var below: float = ((rws[rws.size() - 1] as Dictionary)["rect"] as Rect2).end.y
			out.append({
				"rect": Rect2(cx - 90.0, below + 24.0, 180.0, 40.0), "key": "ESC",
				"label": "Back", "sub": "", "note": "", "rating": 0,
				"accent": Color("#8d99bd"), "action": "title"})
	elif phase == Phase.MASTERY:
		# Wide enough for a block and a word beside it without crowding either.
		var mw: float = minf(420.0 if portrait else 300.0,
			get_viewport_rect().size.x - GRID_MARGIN * 2.0)
		var mfoot := _mastery_stats_foot()
		out.append({
			"rect": Rect2(cx - mw * 0.5, mfoot, mw, 46.0), "key": "C",
			"label": "Cosmetics", "sub": "", "note": "", "rating": 0,
			"accent": Color("#64dfdf"), "action": "cosmetics"})
		if not portrait:
			out.append({
				"rect": Rect2(cx - 90.0, mfoot + 54.0, 180.0, 40.0), "key": "ESC",
				"label": "Back", "sub": "", "note": "", "rating": 0,
				"accent": Color("#8d99bd"), "action": "title"})
	elif phase == Phase.COSMETICS:
		# The category arrows straddle the label, which sits just above the grid
		# — so they travel with it when the record strip above wraps to two rows.
		var arrow_y := _mastery_grid_top() - 38.0
		# Fatter in portrait: these are the only way to change category without a
		# left and right arrow key, and 30x26 is not a thumb target.
		var aw := 30.0 if not portrait else 56.0
		var ah := 26.0 if not portrait else 48.0
		# The arrowhead is the whole of what these buttons say, and in portrait it
		# has to be the label rather than the key badge — the badges are
		# suppressed there, which left two blank panels either side of the title.
		out.append({
			"rect": Rect2(cx - 128.0 - (aw - 30.0), arrow_y - (ah - 26.0) * 0.5, aw, ah),
			"key": "" if portrait else "<", "label": "<" if portrait else "",
			"sub": "", "note": "", "rating": 0,
			"accent": Color("#8d99bd"), "action": "slot:-1"})
		out.append({
			"rect": Rect2(cx + 98.0, arrow_y - (ah - 26.0) * 0.5, aw, ah),
			"key": "" if portrait else ">", "label": ">" if portrait else "",
			"sub": "", "note": "", "rating": 0,
			"accent": Color("#8d99bd"), "action": "slot:1"})
		# Portrait has the chevron in the corner and does not need this as well.
		if not portrait:
			out.append({
				"rect": Rect2(cx - 90.0, _mastery_bottom() + 30.0, 180.0, 42.0), "key": "ESC",
				"label": "Back", "sub": "", "note": "", "rating": 0,
				"accent": Color("#8d99bd"), "action": "title"})
	elif phase == Phase.OVER:
		# The daily has no rematch. That is the entire shape of it — offering a
		# button that would refuse itself is worse than not offering one.
		if mode == Mode.DAILY:
			var only := _grid_rects(1, _over_foot() + 54.0, 1, 300.0, 96.0, 20.0, 280.0, 14.0)
			out.append({
				"rect": only[0], "key": "ESC",
				"label": "Title", "sub": "a new board at midnight", "note": "",
				"rating": 0, "accent": Color("#ffd166"), "action": "title"})
			return out
		var over := _grid_rects(2, _over_foot() + 54.0, 2, 264.0, 96.0, 20.0, 280.0, 14.0)
		out.append({
			"rect": over[0], "key": "",
			"label": "Rematch", "sub": difficulty, "note": "", "rating": 0,
			"accent": PLAYER_ACCENT, "action": "rematch"})
		out.append({
			"rect": over[1], "key": "ESC",
			"label": "Title", "sub": "pick a new opponent", "note": "", "rating": 0,
			"accent": Color("#8d99bd"), "action": "title"})
	return out


## The seam between bands. A hairline and a word, set in the gutter column so it
## lines up with the stamps rather than floating over the middle of the screen.
func _draw_title_bands() -> void:
	var m := _plate_metrics()
	var x: float = float(m["x"])
	var w: float = float(m["w"])
	var y: float = float(m["top"])
	var last := -1
	for row: Array in _title_modes():
		if int(row[5]) != last:
			y += float(m["band_gap"])
			last = int(row[5])
			var label: String = TITLE_BANDS[last]
			var lw: float = _font_bold.get_string_size(label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 2.0 * float(label.length())
			_draw_tracked_left(_font_bold, Vector2(x, y - 15.0), label, 10, 2.0,
				Color("#7c88ad"))
			# The rule starts after the label and runs to the plate's edge, so
			# the two read as one line rather than as a caption above a divider.
			_overlay.draw_rect(Rect2(x + lw + 10.0, y - 16.0, w - lw - 10.0, 1.0),
				Color("#232c4d"), true)
		y += float(m["h"]) + float(m["gap"])


## The title screen, as the thing the game is actually made of.
##
## It used to be six rounded cards in a row, each with a number badge, which is
## the shape every menu in every engine ships with — and the numbers encoded
## nothing, because the modes are a set and not a sequence. Meanwhile the most
## characteristic object in this game, the letter-stamped block, appeared only in
## the tutorial cards.
##
## So every mode is a branded block now. A coloured stamp gutter carrying a
## three or four letter fragment, with the rest of the word continuing out of it
## — PRAC·TICE, VER·SUS — which is exactly the FRIENDSHIP → SHIPMENTS grammar the
## game already teaches on the same screen. Reading down the menu is reading the
## same artifact you read all match.
##
## The bands are real grouping rather than decoration: one place to learn, three
## to play, two that are about you rather than about a match.
const TITLE_BANDS := ["LEARN", "PLAY", "YOU"]


func _title_modes() -> Array:
	var fresh: bool = not bool(Profile.pref("taught"))
	var dkey := daily_key()
	var spent: bool = Profile.daily_done(dkey)
	var dsub := "One run, the same board for everyone"
	if spent:
		dsub = "Played — %s. New board at midnight." % _commas(
			int(Profile.daily_result(dkey).get("score", 0)))
	# stamp, word, sub, action, tint, band
	#
	# The stamp is the fragment on the block; the word is the whole word that
	# answers it. Splitting the name across the two — PRAC in the gutter and
	# TICE on the plate — was clever and did not read: neither half was a word,
	# and "SUS" and "TINGS" are not what those buttons are called. This is the
	# game's actual loop instead. A block carries a fragment, and the word that
	# clears it starts with those letters.
	return [
		["PRAC", "PRACTICE", "Learn it, or drill it", "practice",
			Color("#90be6d"), 0],
		["DAI", "DAILY", dsub, "daily",
			Color("#5d6a92") if spent else Color("#ffd166"), 1],
		["SOLO", "SOLO", "You against the machines", "solo", Color("#7bdff2"), 1],
		["VER", "VERSUS", "Room codes, up to four", "versus", Color("#c77dff"), 1],
		["MAS", "MASTERY", "Level %d · your record" % Profile.level(), "mastery",
			Color("#f8961e"), 2],
		["COS", "COSMETICS", "Titles, themes, effects", "cosmetics",
			Color("#64dfdf"), 2],
		["SET", "SETTINGS", "Sound, effects, name", "settings",
			Color("#8d99bd"), 2],
	]


## Where the stack starts, and how tall each plate is. Portrait gets the taller
## plate because it is being hit with a thumb.
func _plate_metrics() -> Dictionary:
	var size := get_viewport_rect().size
	var wide: float = minf(560.0 if portrait else 620.0, size.x - GRID_MARGIN * 2.0)
	# Landscape is 720 tall and has to hold six plates, three band rules and the
	# rules line; portrait has half as much again to spend and is being hit with
	# a thumb, so it gets the taller plate.
	var h: float = 80.0 if portrait else 48.0
	var gap: float = 9.0 if portrait else 6.0
	var band_gap: float = 26.0 if portrait else 14.0
	var rows := _title_modes()
	var block: float = 0.0
	var last := -1
	for m: Array in rows:
		if int(m[5]) != last:
			block += band_gap
			last = int(m[5])
		block += h + gap
	var head: float = (196.0 if portrait else 196.0) + safe_top
	# The bottom margin is reserved space, not slack: the shortcut line hangs off
	# the last plate and lives in it.
	var avail: float = size.y - safe_bottom - head - (96.0 if portrait else 46.0)
	# Biased up rather than centred. Centring left a band of nothing between the
	# wordmark and the first plate on a tall screen, which read as a mistake
	# rather than as space.
	var top: float = head + maxf(0.0, (avail - block) * 0.34)
	return {"x": size.x * 0.5 - wide * 0.5, "w": wide, "h": h, "gap": gap,
		"band_gap": band_gap, "top": top}


func _title_plates() -> Array:
	var m := _plate_metrics()
	var out: Array = []
	var y: float = float(m["top"])
	var last := -1
	for row: Array in _title_modes():
		if int(row[5]) != last:
			y += float(m["band_gap"])
			last = int(row[5])
		out.append({
			"rect": Rect2(float(m["x"]), y, float(m["w"]), float(m["h"])),
			"key": "", "label": String(row[1]),
			"sub": String(row[2]), "note": "", "rating": 0,
			"accent": row[4], "action": String(row[3]),
			"stamp": String(row[0]), "word": String(row[1]), "band": int(row[5]),
		})
		y += float(m["h"]) + float(m["gap"])
	# The rules are not a mode, so they are not a plate. A quiet line under the
	# stack, which is also the only way in on a phone — H is not a key it has.
	out.append({
		"rect": Rect2(float(m["x"]), y + 14.0, float(m["w"]), 34.0),
		"key": "", "label": "Full rules", "sub": "", "note": "", "rating": 0,
		"accent": Color("#5d6a92"), "action": "rules", "stamp": "", "word": "",
		"band": -1})
	return out


## The fragment a word would be branded with. Three letters is what most
## garbage carries, so it is what a plate carries when nobody has chosen one.
func _stamp_for(word: String) -> String:
	var clean := word.strip_edges().to_upper()
	var out := ""
	for i in clean.length():
		var c := clean[i]
		if c >= "A" and c <= "Z":
			out += c
		if out.length() >= 3:
			break
	return out if out != "" else "..."


## One plate: a branded block, and the word that answers it.
##
## Lifted out of the title screen because every other menu was still made of
## rounded cards with centred text, and next to a screen built out of the game's
## own blocks they looked like a different product. One renderer, so a change to
## the language reaches all of them at once.
##
## `stamp` empty draws a plain row instead — for the things that are not modes.
func _draw_plate(r: Rect2, stamp: String, word: String, sub: String, tint: Color,
		hot: bool, on: bool = false, locked: bool = false) -> void:
	if stamp == "":
		_draw_tracked(_font, r.get_center(), word.to_upper(), 11, 2.0,
			Color("#aab4d4") if hot else Color("#6b769b"))
		return

	if hot:
		r = Rect2(r.position - Vector2(3.0, 0.0), r.size + Vector2(6.0, 0.0))

	var gw: float = clampf(r.size.x * 0.22, 78.0, 128.0)
	var gutter := Rect2(r.position, Vector2(gw, r.size.y)).grow(-4.0)

	_ui_sb.bg_color = Color("#141b33") if not hot else Color("#1b2444")
	_ui_sb.set_corner_radius_all(4)
	_ui_sb.set_border_width_all(2 if on else 1)
	_ui_sb.border_color = Color("#ffd166") if on else Color(tint, 0.5 if hot else 0.18)
	_ui_sb.shadow_size = 0
	_overlay.draw_style_box(_ui_sb, r)

	# The board's own ruling, at the pitch the playfield uses, plus a wash
	# bleeding out of the block so the two halves belong to each other.
	var body := Rect2(r.position.x + gw, r.position.y, r.size.x - gw, r.size.y)
	var gx := body.position.x + 26.0
	while gx < body.end.x - 2.0:
		_overlay.draw_rect(Rect2(gx, body.position.y + 3.0, 1.0, body.size.y - 6.0),
			Color(tint, 0.055), true)
		gx += 26.0
	for i in 6:
		var f := float(i) / 5.0
		_overlay.draw_rect(Rect2(body.position.x + f * 70.0, body.position.y + 1.0,
			70.0 / 6.0 + 1.0, body.size.y - 2.0), Color(tint, 0.075 * (1.0 - f)), true)

	var face: Color = tint if not locked else Color("#39415f")
	var ink := Cosmetics.draw_block_face(_overlay, gutter, face,
		Profile.worn("blocks"), hot)
	# Continuous with the plate rather than stepping at two thresholds, so a
	# taller row carries bigger type instead of stranding small text in it.
	var size: int = int(clampf(16.0 + (r.size.y - 40.0) * 0.11, 16.0, 26.0))
	_draw_tracked(_font_bold, gutter.get_center(), stamp, maxi(15, size - 2), 3.0,
		ink)
	var head := word.substr(0, stamp.length()) if word.to_upper().begins_with(stamp) else ""
	var tail := word.substr(head.length())
	var tx: float = r.position.x + gw + 20.0
	var hw: float = _font_bold.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT,
		-1, size).x
	var ty: float = r.position.y + r.size.y * (0.37 if sub != "" else 0.5)
	var bright: Color = Color("#4d5878") if locked else (
		Color.WHITE if hot else Color("#e6ecff"))
	var dim: Color = Color("#3d4666") if locked else (
		Color("#8d99bd") if hot else Color("#6b769b"))
	_otext_left(_font_bold, Vector2(tx, ty), head, size, bright)
	_otext_left(_font_bold, Vector2(tx + hw, ty), tail, size, dim)
	if sub != "":
		_otext_left(_font, Vector2(tx, r.position.y + r.size.y * 0.72), sub, 12,
			Color("#aab4d4") if hot else Color("#7c88ad"))


func _draw_title_plate(b: Dictionary) -> void:
	_draw_plate(b["rect"], String(b.get("stamp", "")), String(b["word"])
		if b.has("word") else String(b["label"]), String(b["sub"]), b["accent"],
		_hover_action == String(b["action"]))


## Text with a fixed extra advance between characters. Godot has no tracking, so
## it is drawn a glyph at a time.
func _draw_tracked(font: Font, centre: Vector2, text: String, size: int,
		track: float, color: Color) -> void:
	if font == null or text == "":
		return
	var total := 0.0
	var widths: Array = []
	for i in text.length():
		var w: float = font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT,
			-1, size).x
		widths.append(w)
		total += w + (track if i < text.length() - 1 else 0.0)
	var x: float = centre.x - total * 0.5
	var y: float = centre.y - font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
		-1, size).y * 0.5 + font.get_ascent(size)
	for i in text.length():
		_overlay.draw_string(font, Vector2(x, y), text[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		x += float(widths[i]) + track


## Tracked text hung off a left edge. The band labels get the same letter
## spacing as the stamps, so the two read as the same system.
func _draw_tracked_left(font: Font, at: Vector2, text: String, size: int,
		track: float, color: Color) -> void:
	if font == null or text == "":
		return
	var y: float = at.y - font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
		-1, size).y * 0.5 + font.get_ascent(size)
	var x := at.x
	for i in text.length():
		_overlay.draw_string(font, Vector2(x, y), text[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		x += font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + track


## Left-aligned overlay text, for anything that hangs off an edge rather than a
## centre line.
func _otext_left(font: Font, at: Vector2, text: String, size: int,
		color: Color) -> void:
	if font == null or text == "":
		return
	var m := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	_overlay.draw_string(font, Vector2(at.x, at.y - m.y * 0.5 + font.get_ascent(size)),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw_menu_button(b: Dictionary) -> void:
	# Everything that is not the playfield is a plate now. The rounded card with
	# a key badge and centred text was the generic half of every other screen,
	# and next to a title built out of blocks it read as a different product.
	var r: Rect2 = b["rect"]
	var label := String(b["label"])
	var hot: bool = _hover_action == String(b["action"])

	# Short, wide and wordless — the category arrows and the like. A plate needs
	# a word to brand, so these keep a plain treatment.
	# A plate needs room for a block and a word beside it. Below that it draws
	# the stamp on top of the label — BACK came out as "BAC" and "BACK" at once.
	if label == "" or r.size.y < 38.0 or r.size.x < 230.0:
		_panel(r, Color("#1b2444") if hot else Color("#141b33"),
			Color(b["accent"], 0.9 if hot else 0.26), 8.0, 2.0)
		var key0 := String(b["key"])
		_otext(_font_bold, r.get_center(), label if label != "" else key0,
			15, Color.WHITE if hot else Color("#e6ecff"))
		return

	var stamp := String(b["stamp"]) if b.has("stamp") and String(b["stamp"]) != "" \
		else _stamp_for(label)
	var sub := String(b["sub"])
	# Opponent cards carry a rating rather than a sentence; keep it in the sub.
	if int(b.get("rating", 0)) > 0 and sub == "":
		sub = "%d wpm" % int(b["rating"])
	_draw_plate(r, stamp, label.to_upper(), sub, b["accent"], hot,
		bool(b.get("on", false)), bool(b.get("locked", false)))


func _panel(r: Rect2, bg: Color, border: Color, radius: float, width: float = 2.0) -> void:
	_ui_sb.bg_color = bg
	_ui_sb.set_corner_radius_all(int(radius))
	_ui_sb.set_border_width_all(int(width))
	_ui_sb.border_color = border
	_ui_sb.shadow_size = 7
	_ui_sb.shadow_color = Color(0, 0, 0, 0.35)
	_ui_sb.shadow_offset = Vector2(0, 3)
	_overlay.draw_style_box(_ui_sb, r)


## A block drawn the way the playfield draws them, for use inside the menus.
func _mini_block(center: Vector2, size: Vector2, tier: int, label: String) -> void:
	var col: Color = WWBoard.TIER_COLORS[tier]
	_ui_sb.bg_color = col
	# Scale the rounding with the tile, or a small one reads as a pill.
	_ui_sb.set_corner_radius_all(int(clampf(minf(size.x, size.y) * 0.18, 2.0, 7.0)))
	_ui_sb.set_border_width_all(2)
	_ui_sb.border_color = col.lightened(0.35)
	_ui_sb.shadow_size = 5
	_ui_sb.shadow_color = Color(0, 0, 0, 0.4)
	_ui_sb.shadow_offset = Vector2(0, 2)
	_overlay.draw_style_box(_ui_sb, Rect2(center - size * 0.5, size))
	if label != "":
		_otext(_font_bold, center, label, 15, Color("#0b1020"))


## One word with the significant half picked out, which is the entire mechanic.
func _draw_split_word(cx: float, y: float, head: String, tail: String, size: int,
		lit_head: bool = false) -> void:
	var hw := _font_bold.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var tw := _font_bold.get_string_size(tail, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var hh := _font_bold.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, size).y
	var start := cx - (hw + tw) * 0.5
	var base := y - hh * 0.5 + _font_bold.get_ascent(size)
	var dim := Color("#6c7899")
	var lit := Color("#ffd166")
	_overlay.draw_string(_font_bold, Vector2(start, base), head,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, lit if lit_head else dim)
	_overlay.draw_string(_font_bold, Vector2(start + hw, base), tail,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, dim if lit_head else lit)


func _draw_arrow(cx: float, y: float, length: float, color: Color) -> void:
	_overlay.draw_line(Vector2(cx, y), Vector2(cx, y + length - 7.0), color, 2.0)
	var tip := Vector2(cx, y + length)
	_overlay.draw_colored_polygon(PackedVector2Array([
		tip, tip + Vector2(-5.5, -8.0), tip + Vector2(5.5, -8.0)]), color)


# ----------------------------------------------------------- animated backdrop

class Decor extends RefCounted:
	var pos := Vector2.ZERO
	var size := Vector2.ONE
	var tier := 0
	var speed := 30.0
	var rot := 0.0
	var spin := 0.0


func _seed_decor() -> void:
	decor.clear()
	var size := get_viewport_rect().size
	for i in 18:
		var d := Decor.new()
		d.size = Vector2(randi_range(1, 3), randi_range(1, 3)) * 26.0
		d.pos = Vector2(randf_range(0.0, size.x), randf_range(-140.0, size.y))
		d.tier = randi_range(0, 5)
		d.speed = randf_range(12.0, 44.0)
		d.rot = randf_range(-0.35, 0.35)
		d.spin = randf_range(-0.22, 0.22)
		decor.append(d)


func _step_decor(delta: float) -> void:
	var size := get_viewport_rect().size
	for d: Decor in decor:
		d.pos.y += d.speed * delta
		d.rot += d.spin * delta
		if d.pos.y > size.y + 90.0:
			d.pos.y = -90.0
			d.pos.x = randf_range(0.0, size.x)
			d.tier = randi_range(0, 5)


func _draw_decor() -> void:
	for d: Decor in decor:
		var col: Color = WWBoard.TIER_COLORS[d.tier]
		_overlay.draw_set_transform(d.pos, d.rot, Vector2.ONE)
		_overlay.draw_rect(Rect2(-d.size * 0.5, d.size), Color(col, 0.07), true)
		_overlay.draw_rect(Rect2(-d.size * 0.5, d.size), Color(col, 0.15), false, 1.5)
		_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ----------------------------------------------------------------- mouse input

func _unhandled_input(event: InputEvent) -> void:
	# Before anything else, and before the splash swallows input: the back button
	# is the only way off most of these screens on a phone, so nothing else is
	# allowed to sit on top of it.
	if portrait and event is InputEventMouseButton:
		var back := event as InputEventMouseButton
		if back.pressed and back.button_index == MOUSE_BUTTON_LEFT \
				and _back_action() != "" \
				and _back_rect().grow(6.0).has_point(get_viewport().get_mouse_position()):
			_press_back()
			return

	# The drawn keyboard takes priority over everything else a click could mean
	# while it is up, because it covers the bottom third of the screen.
	if portrait and phase == Phase.PLAY and not paused and player.alive:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				var hit := _key_at(get_viewport().get_mouse_position())
				if mb.pressed:
					if hit != "":
						_press_key(hit)
						return
				elif _key_down != "":
					_key_down = ""
					return
	if phase == Phase.SPLASH:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_skip_splash()
		return
	# The same hold as the keys. On a phone the last thing you did was hammer
	# FIRE, and the release of that tap should not pick a button off the summary
	# that has just appeared under your thumb.
	if phase == Phase.OVER and over_age < OVER_LOCKOUT:
		return
	if phase == Phase.PLAY and not paused:
		if not player.alive:
			return
		# In play the mouse only does one thing: pick who you are hitting.
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				var at := get_viewport().get_mouse_position()
				for s: SideState in sides:
					if s.slot > 0 and s.in_match and s.alive \
							and _board_rect(s).grow(16.0).has_point(at):
						_target_slot(s.slot)
						break
		return
	if event is InputEventMouseMotion:
		var was := _hover_action
		_hover_action = _action_at(get_viewport().get_mouse_position())
		if _hover_action != "" and _hover_action != was:
			Sfx.play("key", 1.3, -6.0)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var act := _action_at(get_viewport().get_mouse_position())
			if act != "":
				_activate(act)


func _action_at(p: Vector2) -> String:
	for b: Dictionary in _menu_buttons():
		if (b["rect"] as Rect2).has_point(p):
			return String(b["action"])
	if phase == Phase.SOLO:
		var seats := _solo_seat_rects()
		for i in range(1, seats.size()):
			if (seats[i] as Rect2).has_point(p):
				return "pick:%d" % (i - 1)
		for c: Dictionary in _solo_cards():
			if (c["rect"] as Rect2).has_point(p):
				return String(c["action"])
		for c: Dictionary in _kind_cards(_solo_kinds_top()):
			if (c["rect"] as Rect2).has_point(p):
				return String(c["action"])
	if phase == Phase.LOBBY and Link.connected and Link.is_host:
		for c: Dictionary in _kind_cards(_lobby_kinds_top()):
			if (c["rect"] as Rect2).has_point(p):
				return String(c["action"])
	if phase == Phase.SETTINGS:
		for row: Dictionary in _settings_rows():
			if (row["rect"] as Rect2).has_point(p):
				return String(row["action"])
	if phase == Phase.COSMETICS:
		for c: Dictionary in _mastery_cards():
			if (c["rect"] as Rect2).has_point(p):
				return String(c["action"])
	# The lobby's fields and backend tiles are clickable too.
	if phase == Phase.LOBBY and not Link.connected:
		for i in 2:
			if _lobby_field_rect(i).has_point(p):
				return "field:%d" % i
			if _lobby_backend_rect(i).has_point(p):
				return "backend:%d" % i
	return ""


func _activate(action: String) -> void:
	# Anything that is not picking a field is leaving the one you were in, so the
	# keyboard comes down. Doing it here rather than in each branch means a new
	# action cannot forget to, and leave a phone with a keyboard up over a match.
	if not action.begins_with("field:") and action != "set:name":
		_hide_keyboard()
	# Every menu action is a tap, so it is acknowledged here rather than in
	# thirty branches. The weighting means a heavier event fired in the same
	# breath — a match ending, a level going up — swallows it.
	Haptics.fire("tap")
	if action.begins_with("diff:"):
		Link.leave()
		start_match(action.substr(5), 1)
	elif action == "resume":
		paused = false
		_hover_action = ""
		Sfx.play("back", 0.9)
	elif action == "leave_match":
		paused = false
		Link.leave()
		phase = Phase.TITLE
		_hover_action = ""
		Sfx.play("back")
	elif action == "rematch":
		# Still connected? Both players go back to the room and ready up again.
		if Link.connected:
			Link.request_rematch()
		elif net_active() or difficulty == "Versus":
			_activate("versus")
		else:
			# Straight from the seats, so a random opponent is genuinely rolled
			# again rather than quietly becoming whoever it was last time.
			var again := _solo_lineup()
			start_match(again[0], again.size(), again)
	elif action == "versus":
		Link.leave()
		Link.status = ""
		phase = Phase.LOBBY
		_hover_action = ""
		Sfx.play("back", 1.2)
	elif action == "host":
		Link.host(lobby_backend)
		Link.set_kinds(block_kinds)
		Sfx.play("count")
	elif action == "join":
		Link.join(lobby_backend, join_ip)
		Sfx.play("count")
	elif action == "addbot":
		Link.set_bots(Link.bot_count + 1)
		Sfx.play("count", 1.2)
	elif action == "dropbot":
		Link.set_bots(Link.bot_count - 1)
		Sfx.play("back")
	elif action == "ready":
		Link.set_ready(not Link.my_ready)
		Sfx.play("count", 1.2 if Link.my_ready else 0.9)
	elif action == "leave":
		Link.leave()
		Link.status = ""
		_hover_action = ""
		Sfx.play("back")
	elif action.begins_with("backend:"):
		# The action carries the picker slot, not the enum value — which backend
		# owns slot 0 depends on whether EOS is configured.
		lobby_backend = _backend_slots()[int(action.substr(8))]
		Sfx.play("key", 1.2)
	elif action.begins_with("field:"):
		var which := int(action.substr(6))
		# While hosting, that field is the code to read out — clicking copies it.
		if which == 1 and Link.is_host and Link.room_code != "":
			DisplayServer.clipboard_set(Link.room_code)
			Link.status = "code copied to your clipboard"
			Sfx.play("count", 1.3)
		else:
			lobby_field = which
			_show_keyboard(Link.my_name if which == 0 else join_ip)
	elif action == "solo":
		phase = Phase.SOLO
		_hover_action = ""
		Sfx.play("count", 1.1)
	elif action == "practice":
		phase = Phase.PRACTICE
		_hover_action = ""
		Sfx.play("count", 1.1)
	elif action == "tutorial":
		Link.leave()
		start_match("Rookie", 0, [], Mode.TUTORIAL)
	elif action == "training":
		Link.leave()
		start_match("Rookie", 0, [], Mode.TRAINING)
	elif action.begins_with("pace:"):
		train_pace = clampi(int(action.substr(5)), 0, TRAINING_PACE.size() - 1)
		Sfx.play("key", 1.2)
	elif action == "settings":
		phase = Phase.SETTINGS
		settings_editing = false
		_buy_armed = false
		_hover_action = ""
		Sfx.play("count", 1.1)
	elif action == "daily":
		if Profile.daily_done(daily_key()):
			# Said rather than silently ignored, or the door looks broken.
			_say("today's board is spent — a new one at midnight",
				Color("#8d99bd"))
			Sfx.play("reject", 1.2)
			return
		Link.leave()
		start_match("Daily", 0, [], Mode.DAILY)
	elif action == "cosmetics":
		phase = Phase.COSMETICS
		_hover_action = ""
		Sfx.play("count", 1.1)
	elif action == "rules":
		show_rules = not show_rules
		_hover_action = ""
		Sfx.play("back", 1.2)
	elif action == "solo_start":
		var lineup := _solo_lineup()
		Link.leave()
		start_match(lineup[0], lineup.size(), lineup)
	elif action.begins_with("pick:"):
		solo_pick = clampi(int(action.substr(5)), 0, solo_seats.size() - 1)
		Sfx.play("key", 1.2)
	elif action.begins_with("seat:"):
		solo_seats[solo_pick] = action.substr(5)
		# Filling a seat moves you on to the next empty one, so setting up three
		# opponents is three clicks rather than six.
		if String(solo_seats[solo_pick]) != "":
			for i in solo_seats.size():
				var at := (solo_pick + 1 + i) % solo_seats.size()
				if String(solo_seats[at]) == "":
					solo_pick = at
					break
		Profile.set_pref("solo", solo_seats.duplicate())
		Sfx.play("count", 1.25)
	elif action.begins_with("kind:"):
		var id := action.substr(5)
		if block_kinds.has(id):
			block_kinds.erase(id)
			Sfx.play("back")
		else:
			block_kinds.append(id)
			Sfx.play("count", 1.3)
		Profile.set_pref("kinds", block_kinds.duplicate())
		if Link.is_host and Link.connected:
			Link.set_kinds(block_kinds)
	elif action.begins_with("set:"):
		_change_setting(action.substr(4))
	elif action == "mastery":
		phase = Phase.MASTERY
		_hover_action = ""
		Sfx.play("count", 1.1)
	elif action.begins_with("slot:"):
		mastery_slot = posmod(mastery_slot + int(action.substr(5)), Profile.SLOTS.size())
		_hover_action = ""
		Sfx.play("key", 1.2)
	elif action.begins_with("wear:"):
		var bits := action.split(":")
		if bits.size() == 3:
			# Equipping something you have not earned is a no-op rather than an
			# error: the card said so, and the click was a question.
			if Profile.equip(bits[1], bits[2]):
				Sfx.play("count", 1.3)
			else:
				Sfx.play("reject", 1.3)
	elif action == "title":
		Link.leave()
		Link.status = ""
		phase = Phase.TITLE
		_hover_action = ""
		Sfx.play("back")


# ---------------------------------------------------------------- text helpers

## Thousands separators. A five-figure score is meant to be read at a glance in
## the middle of a match, and 14820 is not.
func _commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return ("-" + out) if n < 0 else out


func _text_centered(font: Font, center: Vector2, text: String, size: int, color: Color) -> void:
	if font == null or text == "":
		return
	var m := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	draw_string(font, Vector2(center.x - m.x * 0.5, center.y - m.y * 0.5 + font.get_ascent(size)),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## A label and a value either side of a centre line, the label ending just left
## of it and the value starting just right of it.
##
## Written because the alternative kept going wrong. Pairs like these were laid
## out by centring each half at a hand-picked offset — the clock at cx - 96 and
## the score at cx + 62 — which centres each piece on its own guess and leaves
## the pair as a whole sitting off to one side. Seventeen units off, in that
## case, on a screen 720 wide. Measuring puts the gap in the middle where it
## belongs and does it for any string.
func _text_pair(left_font: Font, right_font: Font, centre: Vector2,
		left_text: String, right_text: String, left_size: int, right_size: int,
		left_color: Color, right_color: Color, gap: float = 26.0) -> void:
	var lw: float = left_font.get_string_size(
		left_text, HORIZONTAL_ALIGNMENT_LEFT, -1, left_size).x if left_text != "" else 0.0
	var rw: float = right_font.get_string_size(
		right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, right_size).x if right_text != "" else 0.0
	var total := lw + gap + rw
	var left := centre.x - total * 0.5
	if left_text != "":
		_text_centered(left_font, Vector2(left + lw * 0.5, centre.y), left_text,
			left_size, left_color)
	if right_text != "":
		_text_centered(right_font, Vector2(left + lw + gap + rw * 0.5, centre.y),
			right_text, right_size, right_color)


## Overlay twin of the above.
func _otext_pair(left_font: Font, right_font: Font, centre: Vector2,
		left_text: String, right_text: String, left_size: int, right_size: int,
		left_color: Color, right_color: Color, gap: float = 26.0) -> void:
	var lw: float = left_font.get_string_size(
		left_text, HORIZONTAL_ALIGNMENT_LEFT, -1, left_size).x if left_text != "" else 0.0
	var rw: float = right_font.get_string_size(
		right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, right_size).x if right_text != "" else 0.0
	var total := lw + gap + rw
	var left := centre.x - total * 0.5
	if left_text != "":
		_otext(left_font, Vector2(left + lw * 0.5, centre.y), left_text, left_size,
			left_color)
	if right_text != "":
		_otext(right_font, Vector2(left + lw + gap + rw * 0.5, centre.y), right_text,
			right_size, right_color)


## Same, but shrinks the type until the line sits inside `max_width`. Words like
## MISUNDERSTANDING are exactly what this game rewards, so they must still fit.
func _text_fit(font: Font, center: Vector2, text: String, size: int, max_width: float,
		color: Color, min_size: int = 11) -> void:
	if font == null or text == "":
		return
	var s := size
	while s > min_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > max_width:
		s -= 1
	_text_centered(font, center, text, s, color)


func _otext(font: Font, center: Vector2, text: String, size: int, color: Color) -> void:
	if font == null or text == "":
		return
	var m := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	_overlay.draw_string(font,
		Vector2(center.x - m.x * 0.5, center.y - m.y * 0.5 + font.get_ascent(size)),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
