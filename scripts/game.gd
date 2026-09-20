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
## The same chip in a phone's gutter, where it is read out of the corner of an
## eye rather than looked at. Taller than the landscape one so the prefix can be
## set at a size that survives that — see `_draw_rail`. A phone board leaves room
## for thirteen down each side, and no queue that long has ever been survivable,
## so the height comes out of slack nobody was using.
const RAIL_CHIP_H := 42.0
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

## How far above its top row the keyboard starts claiming taps. Everything from
## there down belongs to some key — see `_key_at` — so this is the only edge of
## the thing that has to be decided by a number.
const KEY_BAND_PAD := 10.0
## Fingers land low. The hardware reports the middle of the contact patch and the
## typist means the top of it, so the sample is lifted by this much before it is
## matched against a key. Deliberately far smaller than a key: it is a nudge
## against a bias that runs one direction, not a correction that can move a hit
## from one row into another on its own.
##
## Was 6, which is 0.6mm on a phone — smaller than the gap between two keys, and
## so small it could not have been correcting anything. The offset between where
## a thumb is aimed and where its contact patch is reported runs a couple of
## millimetres. 14 is about 1.4mm: still well under a fifth of a key's height, so
## a tap in the middle of a key cannot be walked off it, but now the same order
## of magnitude as the thing it exists to cancel. Wants a real device and real
## thumbs to settle properly — it is the one number here that is a judgement
## rather than a measurement.
const TOUCH_LIFT := 14.0
## How far a letter that can still finish the word may pull the boundary with a
## neighbour that cannot — see `_key_at`. The gap between two keys is 7 of this,
## so the boundary itself moves about 15: a quarter of a key's width sideways,
## and a sixth of its height up or down, since keys are taller than they are
## wide and the same number buys proportionally less of it.
const KEY_LEAN := 22.0
const DEBUG_TOUCH_HITBOXES := false
## Block shapes by tier. Which one you send is decided by your chain and by how
## long the word was — see `_length_tier`.
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

## What length alone is worth, before the chain says anything.
##
## Length used to reach the board only through the ladder: a long word filled
## more of the chain, and the chain picked the block. Which meant ONOMATOPOEIA
## thrown from a standing start hit exactly as hard as ONE — the same 1x1 — and
## the game read as though it did not care what you found. It should. Finding a
## twelve-letter answer is the hardest thing the game asks for, and it now has a
## floor of its own that no amount of not-finding one can reach.
##
## Two steps at 7 and 10 was the first attempt at that and it only half worked.
## It fixed the standing start and left two holes either side of it:
##
##   * **Everything under seven letters was one block.** CAT, SHIP, BEACH and
##     PLANET all sent the same 1x1. Four letters of extra effort bought
##     nothing, which is most of the words anybody actually plays.
##   * **Everything over ten was one block too.** The ladder stopped at 2x2, so
##     ONOMATOPOEIA sent what UNDERSTAND sent. The hardest thing the game asks
##     for had a ceiling two tiers below what a chain can reach.
##
## Three steps, and the spacing was measured rather than chosen. Sampling four
## thousand words the bank actually deals — which are mostly six to eight
## letters, not the evenly spread lengths a ladder looks balanced against on
## paper — a step every two letters from five upwards more than *doubled* the
## damage an average word throws from a standing start. That is not a gradient,
## it is a different game.
##
## At 6/9/12 the same sample throws about a quarter more at a standing start and
## a seventh more mid-run, while still doing both jobs: six letters now beats
## five, and twelve now beats ten. Held deliberately coarse at the short end —
## three, four and five letters stay one block — because the chain is meant to
## be the bigger lever and most words played are short ones.
##
## If play says this is too gentle, the next step out is [6, 8, 11, 14], which
## measured at +45% cold and +26% mid-run against the same sample.
const LENGTH_TIER_AT := [6, 9, 12]

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

## `solo` is what the same power did in a run with nobody to hit — see `_strike`.
## Saying "sent it back" on a board with no opponent was the daily's other quiet
## lie, alongside the LESSON chip: the rule fired, the banner named a thing that
## did not happen, and the points arrived unexplained.
const POWERS := {
	"COUNTER": {"tint": "#7bdff2", "bonus": 150, "note": "sent it back",
		"solo": "shot down, paid out"},
	"COMBO": {"tint": "#ffd166", "bonus": 250, "note": "next hit is bigger",
		"solo": "next hit pays more"},
	"PERFECT": {"tint": "#c77dff", "bonus": 500, "note": "free attack",
		"solo": "paid twice"},
	"CLUTCH": {"tint": "#90be6d", "bonus": 300, "note": "garbage slowed",
		"solo": "garbage slowed"},
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
## The painted boards. `_art` is null for every theme that is a wash, which is
## the flag the whole backdrop path checks — there is no separate "is this a
## premium board" question anywhere, because a theme either brought a picture
## or it did not.
var _art: Texture2D = null
var _art_a := 1.0
var _art_dim := 0.0
var _motion := ""
## What the motion layer is tinted with — the theme's own accent, so the embers
## belong to Volcano rather than to whichever board slot the player happens to
## be sitting in.
var _motion_tint := Color("#7bdff2")
## theme id -> its backdrop texture, or null for the ones that are a wash. Only
## the shop preview uses it; see `_theme_art`.
var _art_cache := {}

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
	COUNTDOWN, PLAY, OVER, COSMETICS, BOARDS, WEEKLY }

## What a match is for. A tutorial and a training run use the whole machine —
## real board, real typing, real rules — and differ only in what is switched off
## around them. Neither can be lost, and neither banks anything: a mode with no
## opponent and no death would be an XP farm, and the level has to keep meaning
## matches played through.
enum Mode { NORMAL, TUTORIAL, TRAINING, DAILY, SURVIVAL }

## The daily board: one run, everybody gets the same one, and it is over when
## the clock runs out rather than when somebody wins.
##
## There is no opponent, and no second board pretending to be one. A shared
## board only means anything if the thing being compared is the same for
## everyone, and an opponent — human or CPU — makes every run diverge on its
## second word. So the pressure is the ambient clock and nothing else, and what
## is being measured is how much you can wring out of it.
##
## Seventy-five seconds, not three minutes. Three minutes of solitaire against a
## clock that starts at twenty-two seconds a block is not a contest, it is a
## warm-up that outlasts its own interest — and the score it produces is mostly
## a measure of patience. A run this length is short enough that the whole of it
## is the interesting part, and short enough to want another go at tomorrow.
##
## It was sixty, and the extra quarter-minute is a scoring decision rather than a
## pacing one. A minute is barely twenty words at the speed this is played at,
## which is not enough room for the back half of the ramp to be *played* — the
## board goes under and the run ends on the same handful of seconds. Fifteen
## more is one more dig-out, and the ramp below is stretched to match so the
## difficulty curve is the same shape over a longer run rather than the same
## curve with a harder tail bolted on.
const DAILY_SECONDS := 75.0
## When the clock turns red. Lands on the last size step, so the alarm and the
## thing it is warning about are the same moment.
const DAILY_ALARM := 12.0
## How hard the run leans on you.
##
## Built around a phone typist at 36-38 wpm, which is the speed that actually
## turns up: at that rate a word is found and fired about every three seconds,
## and each one takes out one or two blocks. So garbage arriving every ~1.6
## seconds by the end is meant to be faster than anyone can answer. Losing
## ground is the shape of the last fifteen seconds; the three lives are what
## make that a scoring decision rather than a death.
##
## The step is what got retuned when the run went from sixty seconds to
## seventy-five. Start and floor are both physical claims — how long the first
## block takes to arrive, and the fastest rate a thumb can be asked to answer —
## and neither of those changed. What changed is how long the run spends at the
## floor: at 0.14 a step the rate bottomed out around thirty seconds in, which
## was half of a sixty-second run and would have been well under half of this
## one. 0.11 puts the floor at about forty seconds, which is the same fraction
## of the run it always was. Without it the extra quarter-minute would have been
## fifteen more seconds of the hardest part of the board, which is the opposite
## of more room to score.
const DAILY_PRESSURE_START := 3.4
const DAILY_PRESSURE_MIN := 1.6
const DAILY_PRESSURE_STEP := 0.11
## Seconds elapsed at which ambient garbage steps up a size. Rate alone runs out
## of room — below about a second and a half the blocks arrive faster than the
## eye reads them — so the back half of the run escalates by weight instead.
##
## Stretched with the run rather than left where they were. The second one is
## also what `DAILY_ALARM` is measured against: the clock turning red and the
## last size step are meant to be the same moment, so `DAILY_SECONDS` minus the
## last entry here has to stay `DAILY_ALARM`.
const DAILY_TIER_AT := [31.0, 63.0]

## How full the board is before the first word is typed, as a fraction of its
## cells, rolled from the day's seed.
##
## An empty board asks nothing for the first twenty seconds, which in a
## sixty-second run is a third of it spent waiting. Starting a quarter to a half
## buried means the first word already matters, and it is one more thing the
## seed fixes: everybody digs out of the same hole.
const DAILY_OPEN_MIN := 0.25
const DAILY_OPEN_MAX := 0.45
## Sizes the opening pile is built from. No 3x3 or 4x3 — a slab that big in the
## first second is a wall, not a starting position.
const DAILY_OPEN_TIERS := [0, 0, 1, 1, 2, 3]

# ------------------------------------------------------------------ survival
#
# The daily's solitaire with the clock taken off the front of it and put on the
# scoreboard instead. Same board, same rules, same three lives — what changes is
# what is being asked. The daily asks how much you can wring out of sixty fixed
# seconds. Survival asks how long you can hold on, and answers it by never
# stopping.
#
# There is no seed and no once-a-day. A shared board only means anything when
# every run is the same length, and these are not — so survival is dealt fresh
# every time and can be played until you are sick of it.
#
# It opens on an empty board, which the daily deliberately does not. A minute
# cannot afford twenty seconds of nothing happening; a run with no end can, and
# needs it: the whole shape of the mode is a calm opening that becomes
# unplayable, and starting a third buried skips the first act of it.

## The ramp, which is the entire design of the mode.
##
## Slower to start and much further to fall than the daily's. Blocks open 4.6
## seconds apart — calmer than the daily's 3.4, because there are minutes to fill
## rather than one — and close on 1.15, which is below the daily's floor of 1.6
## and is meant to be. 1.6 is "faster than anyone can answer" for the last
## fifteen seconds of a sprint; the floor here has to be somewhere a good player
## eventually drowns rather than somewhere they can hold forever, or the mode has
## no ending and the scoreboard measures patience.
##
## At 0.055 a step it takes about three minutes of play to reach the floor, which
## is roughly where a competent run is by then. Nobody meets the hardest version
## of this in their first thirty seconds.
const SURVIVAL_PRESSURE_START := 4.6
const SURVIVAL_PRESSURE_MIN := 1.15
const SURVIVAL_PRESSURE_STEP := 0.055
## Seconds elapsed at which the ambient block steps up a size.
##
## Four gates rather than the daily's two, and the last two are past the point
## where the rate has stopped falling. That is what actually ends a run: once the
## interval is flat, weight is the only thing left to escalate, and a 3x2 slab
## every 1.15 seconds is not survivable by anybody. The mode has to have a
## ceiling somewhere or the best players never finish a run.
const SURVIVAL_TIER_AT := [70.0, 165.0, 300.0, 460.0]
## The mode's colour, everywhere it is drawn: the title plate, the centre column
## during a run, the Again button, and the summary of a run that took no record.
## Red because the whole of survival is a board getting away from you, and this
## palette already uses gold for the thing worth having and red for the thing
## about to cost you.
const SURVIVAL_ACCENT := Color("#f94144")

## Under this, a run is not worth writing down. Quitting out of the countdown or
## topping out in the first few seconds should not be able to take a record, and
## `record_survival` counts runs for XP — so without a floor, starting and
## abandoning is a way to farm levels.
const SURVIVAL_MIN_RUN := 10.0

## What an attack is worth. One cell of block, this many points.
##
## Everything the game builds towards — the tier a chain earns, the block a
## COUNTER sends straight back, the free attack a PERFECT buys, a salvo — has no
## target in a solo run. Switching those rules off would leave the daily a
## thinner game than the one it is drawn from, so instead each one is paid in
## score, priced by the damage it would have done.
##
## It is paid in a match too, and that is newer than it sounds. It used not to
## be: with a rival in the room the block was thrown and the attack scored
## nothing at all. Which means offence paid zero in the only mode that has an
## opponent, and every point in a match came from clearing your own board —
## where the combo multiplier pays +60% a block. The more garbage you are buried
## under, the more each answer is worth, so the player being beaten had the
## richer board and out-scored the player doing the beating. You could take a
## match three lives to none and finish fifty thousand points down.
##
## A cell of block is a cell of block. It is worth the same whether it lands on
## a real board or is cashed because there is no board to land on.
const STRIKE_PAY := 80

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
	# There was a `typing` field here, holding what a peer had entered so far so
	# it could be printed under their board. Both the display and the packet
	# that fed it are gone — see `_typing_of` — and the field went with them
	# rather than being left set-but-unread, which is how a leak grows back.

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
	## Cells of block this side has delivered, all match. The one honest measure
	## of offence in the game: a match is won by burying somebody, and this is
	## how much burying was done. Counted in cells rather than attacks so a 4x3
	## is worth twelve times a 1x1, which is what it costs to answer.
	var dealt := 0
	## Owed by a COMBO to the NEXT attack, and spent there.
	## Power word name -> times earned this match, and the longest word played.
	var power_tally: Dictionary = {}
	var longest_word := ""
	## Only ever set for a peer, from their own machine. See `_wpm_of`.
	var wpm := 0.0
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
# ------------------------------------------------------------- scrolling menus
#
# A phone screen is a window onto a menu, not a box a menu has to fit inside.
# Squeezing six rows into 1500 units so nothing ever scrolls is what made these
# screens small; letting them run past the bottom and be dragged is what lets
# them be the size a thumb wants.
#
# Only the menus. The match is a fixed composition with a keyboard nailed to the
# bottom, and a board that could be dragged out of view would be a bug.

var _scroll := 0.0
var _scroll_max := 0.0
var _drag_from := 0.0
var _drag_scroll := 0.0
var _dragging := false


## True on the screens that are a list rather than a composition.
func _scrollable() -> bool:
	if not portrait:
		return false
	match phase:
		Phase.TITLE, Phase.PRACTICE, Phase.SOLO, Phase.MASTERY, Phase.COSMETICS, \
				Phase.SETTINGS, Phase.LOBBY, Phase.BOARDS, Phase.WEEKLY:
			return true
	return false


## How tall the current screen wants to be, header and footer included.
func _screen_laid() -> float:
	match phase:
		Phase.TITLE:
			var m := _plate_metrics()
			# Counted, not assumed. This was a hardcoded eight — seven modes and
			# the rules line under them — and the premium plate comes and goes
			# with whether it has been bought, so a fixed number would be a
			# scroll limit that is wrong for whichever half of the players is not
			# the half it was written for.
			var rows := float(_title_modes().size() + 1)
			return float(m["top"]) + rows * (float(m["h"]) + float(m["gap"])) \
				+ 3.0 * float(m["band_gap"]) + 80.0
		Phase.PRACTICE:
			return 214.0 + _practice_laid()
		Phase.SOLO:
			# Portrait's `_solo_laid` already counts from the top of the header, so
			# adding the landscape header allowance again would invent 118 units of
			# scroll under a screen that ends at the Start button.
			return _solo_laid() if portrait else 118.0 + _solo_laid()
		Phase.MASTERY:
			return 166.0 + _mastery_laid()
		Phase.COSMETICS:
			return 186.0 + _cosmetics_laid()
		Phase.SETTINGS:
			return 124.0 + float(_settings_rows().size()) * 66.0 * _settings_fill() + 150.0
		Phase.LOBBY:
			return _lobby_laid()
		Phase.BOARDS:
			return _boards_laid()
		Phase.WEEKLY:
			return _weekly_laid()
	return 0.0


## Called every frame a menu is up, so the limit tracks a screen that grew — a
## drawer opening, a category with more entries in it.
func _tick_scroll() -> void:
	if not _scrollable():
		_scroll = 0.0
		_scroll_max = 0.0
		return
	var view: float = get_viewport_rect().size.y - safe_top - safe_bottom
	_scroll_max = maxf(0.0, _screen_laid() - view + 40.0)
	_scroll = clampf(_scroll, 0.0, _scroll_max)


## The bar down the right, drawn only when there is somewhere to go.
func _draw_scrollbar(size: Vector2) -> void:
	if _scroll_max <= 1.0:
		return
	var view: float = size.y - safe_top - safe_bottom
	var track := Rect2(size.x - 10.0, safe_top + 10.0, 3.0, view - 20.0)
	_overlay.draw_rect(track, Color("#ffffff", 0.06), true)
	var frac: float = clampf(view / (view + _scroll_max), 0.15, 1.0)
	var at: float = (_scroll / _scroll_max) * (track.size.y * (1.0 - frac))
	_overlay.draw_rect(Rect2(track.position.x, track.position.y + at, 3.0,
		track.size.y * frac), Color(PLAYER_ACCENT, 0.5), true)


## What Game Center last said it was doing. Shown on the title screen, because
## matchmaking happens behind a native sheet and the moment it closes the player
## is looking at a menu with no explanation of what is going on.
var net_status := ""
## Screen furniture to keep clear of, in design units. See `_measure_safe_area`.
var safe_top := 0.0
var safe_bottom := 0.0
## Whether the glass is big enough to be a tablet. Measured in `_measure_device`
## and false on a desktop and on anything that will not say.
##
## Nothing here asks what platform it is on, in keeping with the rest of the
## layout: a tablet is something the game *measures*, which is why the whole
## iPad layout can be brought up on a desktop with a command-line flag instead
## of a device.
##
## `points_per_unit` used to sit beside this, because the keyboard was laid out
## at a fixed physical size and needed to know how big a design unit was in
## points. It is not any more — see the note at the top of `keyboard.gd` — and
## nothing else in the layout ever wanted the number, so it went with it.
var tablet := false
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
## How a score pop gets out of the way of the one before it. See `_pop_score`.
##
## `FRESH` is how much life a pop has to have left to still count as occupying
## the bottom of the stack — past that it has floated far enough that a new one
## underneath it reads as a second number rather than as part of the first.
## `STEP` has to clear the `note` line under the pop below it, which is drawn at
## `size * 0.72` and where `size` tops out at 58 — so anything under 42 puts the
## new number through the old one's caption, which is the same smear one step up.
## `MAX` is three of those, which stops a salvo's worth marching off the board.
const POP_STACK_FRESH := 0.62
const POP_STACK_STEP := 44.0
const POP_STACK_MAX := 132.0
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
## What is left of the first-word prompt's exit, once a word has been typed.
##
## A countdown rather than a flag, so the prompt leaves on a fade instead of
## vanishing on the frame the word lands — which would read as the prompt being
## part of what just happened rather than as it having been answered.
var _first_word_fade := 0.0
## The player's word count when the current lesson step arrived, so a step can
## ask for "three more" rather than for a total that carries the whole tutorial's
## typing into it.
var _lesson_mark := 0
## Where the last step's RUN IT AGAIN button was drawn, or an empty rect when it
## is not on screen. Set by `_draw_coaching` and read by the input handler, so a
## button that was never drawn can never be pressed.
var _lesson_restart := Rect2()
## Training pace, as an index into TRAINING_PACE.
var train_pace := 1

## How much of this survival run has already been charged to the ad budget.
##
## A run is one match that can last half an hour, so its time is handed over a
## life at a time rather than all at once at the end — see `_bank_survival_time`.
## Held as a mark on `match_time` rather than as a running total, because the
## thing that must never happen is the same seconds being counted twice.
var survival_banked := 0.0
## Which records the run that just finished took, from `Profile.record_survival`.
## Read by the summary, which is the only place it means anything.
var survival_took: Dictionary = {}

## The challenge this match is being played for, or `{}` for an ordinary run.
##
## Copied off `Boards` when the run starts rather than read live at the end.
## Submitting a score is what makes Apple move the challenge out of `pending`,
## so by the time the summary wants to say whether it was beaten, the thing it
## would be reading has already gone. The target has to be held here.
##
## Same shape as `Boards.challenge`: board, score, formatted, from, issued.
var challenge_run: Dictionary = {}

## How often ambient garbage arrives in training, and what to call it. Practice
## is worthless if it is not at a speed you would actually meet.
const TRAINING_PACE := [
	{"name": "Calm", "note": "room to think", "every": 9.0},
	{"name": "Steady", "note": "about a real match", "every": 5.5},
	{"name": "Relentless", "note": "faster than anyone plays", "every": 2.8},
]

## Single-player setup: the three rival seats, and which one the roster fills.
var solo_seats: Array = ["Duelist", "", ""]
var solo_pick := 0
## True while the settings screen has the keyboard for the name field.
## Set when a finished match is folded into the profile, so the end screen can
## show what it earned. Cleared when a new match starts.
var earned: Dictionary = {}
var decor: Array = []
var join_ip := "127.0.0.1"

var countdown := 0.0
var paused := false
var _last_count_beep := -1
var _music_key := ""
var _music_hold := 0.0

var _font: Font
var _font_bold: Font
var _font_title: Font
## The face on the keycaps.
##
## Its own font because the keyboard is the one place where the size and the
## weight have to be argued about separately. Everything else in the game that
## wants a letter to carry sets it bold and is right to — but a keycap is already
## the largest, highest-contrast glyph on the screen, sitting alone on a plate
## with nothing to compete with, and emboldening it on top of that reads as
## cheap rather than as emphatic. Thinner than the body face, not merely
## un-bolded: at this size the strokes can afford it, and iOS sets its own
## keycaps lighter than its body text for the same reason.
var _font_key: Font
var _splash: Texture2D
var _splash_tall: Texture2D
var _overlay: Node2D
var _chip_sb: StyleBoxFlat
var _ui_sb: StyleBoxFlat
var _hover_action := ""
## Which menu action the finger went down on, held until it comes back up.
##
## Buttons used to fire on the press. On a desktop that is merely unusual; on a
## phone it made the scrolling menus unscrollable, because every one of them is
## wall-to-wall buttons and there is nowhere on the screen a drag can *begin*
## that is not already a button. Touching a row to scroll opened it instead, and
## the drag handling below — which is careful to decide "this was a drag, not a
## tap" — never got a say, because by the time it could the screen had changed.
##
## So a press only remembers, and the release decides: same action under the
## finger at both ends and no drag in between, or nothing happens. That is also
## how every button on the phone in your hand already behaves, including the
## right to slide off one and have it not fire.
var _press_action := ""


## The app going away with a daily run still open.
##
## This is the bigger half of the reroll the pause menu's Leave button used to
## offer, and it was the one nobody had to find: swipe the app away mid-run and
## nothing was banked, so the same board could be played again from a cold
## start. Closing the button and leaving this open would only have taught people
## to force-quit instead, which is a worse version of the same exploit and one
## the game cannot even see happen.
##
## So a suspend banks the run exactly as an ending does — quietly, because there
## is no screen to report it on and iOS is about to take the frame. See
## `_end_daily`, whose `quiet` argument is this call and nothing else.
##
## Only the daily. Survival already pays as it goes through
## `_bank_survival_time`, a versus match is ended by the peer noticing the
## connection drop, and neither practice nor the tutorial banks anything at all.
##
## `NOTIFICATION_APPLICATION_PAUSED` rather than `FOCUS_OUT`: focus is lost to a
## notification banner or the control centre, which is not leaving the game, and
## banking a run for a pulled-down notification shade would be a far worse bug
## than the one this fixes. `cloud.gd` takes both because writing a save file
## twice costs nothing; this ends a run and has to be sure.
func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_PAUSED:
		return
	if phase != Phase.PLAY or mode != Mode.DAILY:
		return
	print("[Daily] suspended mid-run — banking %d" % player.score)
	_end_daily(true, true)


func _ready() -> void:
	MultiplayerManager.match_started.connect(_on_match_started)
	MultiplayerManager.match_ended.connect(_on_match_ended)
	MultiplayerManager.state_changed.connect(_on_net_status)
	MultiplayerManager.data_received.connect(_on_multiplayer_data)
	MultiplayerManager.invite_offered.connect(_on_invite_offered)
	Ads.finished.connect(_on_ad_finished)
	# Re-queue the reminders from what is true now.
	#
	# On every launch, not only after a daily run. These are local notifications
	# sitting on the device with a delay on them, so the queue is a snapshot of
	# what was true when it was written — and without this the only thing that
	# ever rewrote it was finishing a daily. Somebody who played yesterday, opened
	# the game today and did not play would keep a stale reminder and never get
	# the one about the streak they are in the middle of dropping.
	#
	# `refresh` cancels before it schedules, so launching ten times does not
	# leave ten copies, and it is a no-op with no plugin behind it.
	Notify.refresh()

	randomize()
	_font = ThemeDB.fallback_font
	var fv := FontVariation.new()
	fv.base_font = _font
	fv.variation_embolden = 0.6
	_font_bold = fv

	var kv := FontVariation.new()
	kv.base_font = _font
	kv.variation_embolden = KEY_WEIGHT
	_font_key = kv

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

	_net_setup()

## Both ends have shaken hands, so both start now.
##
## This used to run the moment the match object arrived, which is before the
## other player has attached — one device would count down into an empty game
## while the other was still connecting, and neither could see why.
func _on_match_started() -> void:
	net_status = ""
	start_match("Versus", 0, [], Mode.NORMAL)


## Matchmaking was cancelled, refused, or the opponent left.
func _on_match_ended(reason: String) -> void:
	if phase == Phase.PLAY or phase == Phase.COUNTDOWN:
		# Mid-match: you win by default rather than being dumped to the title
		# with nothing to show for it.
		net_status = ""
		winner = "YOU"
		_log(reason, Color("#ff6b6b"))
		_end_match(ai_side)
		return
	# Kept, not cleared. `_fail` sets the reason as the status one line before it
	# emits this, and clearing here wiped it in the same frame — so a handshake
	# that timed out walked back to the versus screen reading "signed in to Game
	# Center", with the one sentence explaining what went wrong thrown away. The
	# `_say` that was supposed to carry it never showed either: the message
	# banner is drawn by the playfield HUD, and a menu has no playfield.
	#
	# "cancelled" is the exception — you already know, and `cancel_find` has put
	# a better sentence in the status than this reason string is.
	# Whoever we were negotiating with has gone, so neither flag means anything
	# any more. `_rematch_possible` will have dropped the button by now, and a
	# flag left set would make it reappear mid-negotiation on the next match.
	rematch_asked = false
	rematch_offered = false
	if reason != "cancelled":
		net_status = reason


## What Game Center is doing, so the title screen can say so instead of looking
## frozen behind a sheet that has closed.
func _on_net_status(text: String) -> void:
	net_status = text if MultiplayerManager.state != MultiplayerManager.State.PLAYING \
		else ""


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
	_measure_device(want)
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


## Whether this is a tablet.
##
## Decided by the shape of the design-space viewport rather than by
## asking iOS what it is running on. With `expand` stretching, a phone pins its
## width and overflows vertically — the viewport comes out 720x1561, a ratio of
## 0.46. A tablet is the other way round: 4:3 glass pins the height and the
## viewport widens to about 1000x1440, a ratio of 0.70. Nothing else lands
## between those, so one threshold separates them, and the same rule that names
## an iPad also names a desktop window dragged to roughly that shape — which is
## the only reason any of this could be built and looked at without one.
const TABLET_RATIO := 0.58

func _measure_device(base: Vector2i) -> void:
	tablet = false
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0 or base.x <= 0 or base.y <= 0:
		return
	var k: float = minf(float(win.x) / float(base.x), float(win.y) / float(base.y))
	if k <= 0.0:
		return

	# Measured off the viewport the game will actually draw into, which is the
	# window divided by that same factor — not off the window, whose pixel
	# dimensions say nothing about shape once the scale factor is in play.
	var vp := Vector2(float(win.x) / k, float(win.y) / k)
	tablet = vp.y > 0.0 and (vp.x / vp.y) > TABLET_RATIO

	# `godot -- --ipad` brings the whole tablet layout up in a desktop window,
	# the way `--safe=` brings up a notch. Without it none of this could be seen
	# before an App Store build, and a layout nobody can look at is a layout
	# nobody can fix.
	if OS.get_cmdline_user_args().has("--ipad"):
		tablet = true


## Which keyboard this screen gets.
##
## Split is a tablet-only shape — the whole point of it is that the two halves
## are further apart than one hand can span, which on a phone describes a
## keyboard nobody can reach the middle of. So a phone is never offered it and
## never asked about it, and the preference below only does anything on glass
## where both answers are usable.
func _kb_form() -> int:
	if tablet and bool(Profile.pref("split_keys")):
		return Keyboard.Form.SPLIT
	return Keyboard.Form.FULL


# `Keyboard`'s statics all want the same extra argument, and every caller in
# this file has the same answer for it. These are that answer, applied once, so
# the ten callsites read the way they did before the keyboard grew a second
# shape — and so a new one cannot be added that forgets to ask.

func _kb_height(size: Vector2) -> float:
	return Keyboard.height(size, _kb_form())


## The multiplier for anything sized to match the keys: the type on the caps,
## the pad above the top row, and the two touch corrections in `_key_at`. All of
## those are sized to the keys rather than to the screen, so that a cap stays the
## same fraction of the key it is printed on wherever this is being played.
func _kb_type_scale(size: Vector2) -> float:
	return Keyboard.type_scale(size, _kb_form())


func _kb_emote_rect(size: Vector2, bottom: float) -> Rect2:
	return Keyboard.emote_rect(size, bottom, _kb_form())


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
			float(Cosmetics.theme_opt(id, "frame_a")),
			float(Cosmetics.theme_opt(id, "frame_pulse")))

	# The keyboard is the largest single surface on a phone and was hardcoded, so
	# a change of theme left forty percent of the screen untouched.
	_key_bg = Cosmetics.theme_tint(id, "key_bg", Color("#141b33"))
	_key_edge = Cosmetics.theme_tint(id, "key_edge", PLAYER_ACCENT)
	_key_ink = Cosmetics.theme_tint(id, "key_ink", Color("#e6ecff"))
	_fire_bg = Cosmetics.theme_tint(id, "fire_bg", Color("#1b2f4a"))
	_fire_edge = Cosmetics.theme_tint(id, "fire_edge", PLAYER_ACCENT)
	_glow = Cosmetics.theme_tint(id, "glow", Color.BLACK)
	_glow_a = float(Cosmetics.theme_opt(id, "glow_a"))

	# The backdrop picture, if this theme has one. Through `_load_or_null` like
	# every other piece of art in here: a build that somehow shipped without the
	# file falls back to the theme's own wash, which is a duller board rather
	# than a crash on the one screen the player cannot leave.
	var art_path := String(Cosmetics.theme_opt(id, "art"))
	_art = _load_or_null(art_path) as Texture2D if art_path != "" else null
	_art_a = float(Cosmetics.theme_opt(id, "art_a"))
	_art_dim = float(Cosmetics.theme_opt(id, "art_dim"))
	_motion = String(Cosmetics.theme_opt(id, "motion")) if _art != null else ""
	_motion_tint = Cosmetics.theme_tint(id, "accent", PLAYER_ACCENT)
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


## A theme's backdrop picture, for the shop preview.
##
## Cached by id rather than fetched each frame. `load` is itself cached by the
## engine, but `ResourceLoader.exists` underneath `_load_or_null` is a
## filesystem question, and the mastery screen would be asking it sixty times a
## second while somebody scrolls the list. A miss is stored as `null` so an
## absent file is asked about once and not once per frame forever after.
func _theme_art(id: String) -> Texture2D:
	if _art_cache.has(id):
		return _art_cache[id]
	var path := String(Cosmetics.theme_opt(id, "art"))
	var tex: Texture2D = null
	if path != "":
		tex = _load_or_null(path) as Texture2D
	_art_cache[id] = tex
	return tex


## Yours is drawn at full size on the left; rivals are the same board scaled down
## by the node transform, which keeps every effect and label working on them.
func _layout_boards() -> void:
	var size := get_viewport_rect().size
	var bw := WWBoard.COLS * WWBoard.CELL
	var duel := slots_in_play <= 2

	if portrait and tablet:
		_layout_tablet_boards(size)
		return

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

	_layout_landscape_boards(size, bw, duel)


## How big your own board is allowed to get on a tablet, and how big a rival's
## is against it.
##
## The cap is the interesting one. There is room on an iPad for a playfield half
## again as tall as the one this is capped at — the arithmetic allows 1.63 —
## and taking it would leave nothing beside it worth showing. A board you can
## read at a glance from a foot away is the whole requirement, and 1.45 clears
## that with most of a rival's board left over, which is what the extra glass is
## actually for.
##
## Rivals at two thirds. Big enough that the shape of somebody else's trouble is
## legible across the screen; small enough that yours is plainly the board the
## game is about. Equal boards would read as a split-screen game, which this is
## not — you play your own board and glance at theirs.
const TABLET_BOARD_MAX := 1.75
const TABLET_RIVAL_SCALE := 0.68
## Clear space between your rail and the nearest rival board, and the margin
## outside the rivals.
const TABLET_GUTTER := 40.0
const TABLET_MARGIN := 28.0
## How much room each of your two rails needs. The rails carry the attack chips
## — see `_draw_portrait_rails` — and a chip narrower than this sets its prefix
## at a size that cannot be read from tablet distance, which is the whole reason
## the chips exist. So this is a floor the board is sized *against* rather than
## whatever happens to be left once the board has taken what it wants.
const TABLET_MIN_RAIL := 130.0


## Portrait on a tablet: your board on the left with both its rails, every live
## rival stacked down the right.
##
## This is the layout the port exists for. A phone reduces rivals to a name, a
## life count and a number — see `_portrait_rival_cards` — not because that is
## the right amount to know about somebody but because a phone has room for one
## playfield and it had better be yours. A tablet has room for both, so both are
## drawn, and the thing you have been told about all match is finally a thing
## you can watch.
##
## What is deliberately *not* restored along with their board is their
## half-typed word. See `_typing_of`: seeing where somebody's blocks are is
## reading the position, and seeing what they are about to type is reading their
## hand. This layout gives the first and still refuses the second.
##
## Your board sits centred in whatever is left after the rivals have taken the
## right-hand side, rather than pinned to the left margin, so its two rails come
## out the same width as each other — `_draw_portrait_rails` measures the left
## gutter and assumes the right one matches.
func _layout_tablet_boards(size: Vector2) -> void:
	var bw := WWBoard.COLS * WWBoard.CELL
	var bh := WWBoard.ROWS * WWBoard.CELL
	var top := _portrait_board_top()
	var room := _portrait_board_bottom() - top

	var rivals: Array = []
	for s: SideState in sides:
		if s.slot > 0 and s.in_match:
			rivals.append(s)

	# How big your board can be is a question about width, not height, and it
	# was worth solving rather than capping. Everything across the screen scales
	# with the same number — your board, both rails, the rival column beside it,
	# because a rival is a fixed fraction of you — so the whole row is one
	# inequality with one unknown, and this is it solved for the largest board
	# that still leaves the rails their floor.
	#
	# Capping it at a hand-picked 1.45 instead, which is what this did first,
	# was leaving two hundred units of height unused on every iPad while the
	# constraint that actually binds went unstated. Height only wins in the
	# modes with nobody to play against, where there is no column to fit and the
	# board grows until it runs out of screen.
	#
	# `per_scale` is the width that grows with the scale — your board, plus a
	# rival's if there is one. `fixed` is what does not: the two rails, and the
	# gutter and margin either side of the rival column. The 22 is what
	# `_draw_rail` spends before its chips start, ten of clearance off the board
	# edge and twelve of its own inset. Budgeting the chip width alone left the
	# rails 98 wide against a floor of 130, and the word INCOMING — which is
	# centred on the rail rather than clipped to it — ran off the left of the
	# screen.
	var per_scale: float = bw
	var fixed: float = (TABLET_MIN_RAIL + 22.0) * 2.0
	if not rivals.is_empty():
		per_scale += bw * TABLET_RIVAL_SCALE
		fixed += TABLET_GUTTER + TABLET_MARGIN
	var scale: float = clampf(
		minf((size.x - fixed) / per_scale, room / bh), 0.7, TABLET_BOARD_MAX)

	var rscale: float = scale * TABLET_RIVAL_SCALE
	var rw: float = bw * rscale
	# A rival column only as wide as it has to be, so the space it does not use
	# goes back to your side of the screen rather than being reserved for it.
	var used: float = 0.0 if rivals.is_empty() else rw + TABLET_GUTTER + TABLET_MARGIN
	var mine: float = size.x - used

	player.board.scale = Vector2(scale, scale)
	# Centred in the playfield band rather than hung off the top of it. Where
	# the two constraints disagree — the daily, where width is no object and the
	# board is as tall as it can be — this changes nothing, and where width wins
	# it puts the slack above and below the board instead of all of it below.
	player.board.position = Vector2((mine - bw * scale) * 0.5,
		top + (room - bh * scale) * 0.5)

	# Rivals share the right-hand column top to bottom. One rival — which is
	# every networked match and most single-player ones — gets the whole of it
	# and is simply placed at its natural size; three have to shrink to stack,
	# and shrink together so they stay comparable with each other.
	if rivals.is_empty():
		return
	var rx: float = size.x - TABLET_MARGIN - rw
	# Room for the name and lives above each board and the chain meter below —
	# `_draw_rival_panel` hangs those off the board rect at fixed offsets, and
	# stacked boards have to leave space for them between one and the next.
	var furniture := 96.0
	var each: float = room / float(rivals.size())
	var fit: float = clampf((each - furniture) / bh, 0.4, rscale)
	if rivals.size() > 1:
		rscale = fit
		rw = bw * rscale
		rx = size.x - TABLET_MARGIN - rw

	for i in rivals.size():
		var s3: SideState = rivals[i]
		s3.board.scale = Vector2(rscale, rscale)
		# Down from the top of the playfield area, each one below the last, with
		# the furniture gap between them. A single rival is nudged down so its
		# board is vertically centred against yours instead of hanging off the
		# top, which is where a lone panel otherwise floats.
		var y: float = top + float(i) * (bh * rscale + furniture)
		if rivals.size() == 1:
			y = top + (room - bh * rscale) * 0.5
		s3.board.position = Vector2(rx, y)


func _layout_landscape_boards(size: Vector2, bw: float, duel: bool) -> void:
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
## Where the rival chips sit in the portrait header, paired with whose they are.
##
## Pulled out of `_draw_portrait_hud` because the emote bubbles hang off these
## rectangles and are drawn from a different canvas item — see
## `_draw_portrait_emotes` for why they have to be. Two functions deriving the
## same rectangle from the same four numbers is how a bubble ends up with its
## tail pointing at where a card used to be.
## `size` is passed in rather than read here, the way `_draw_portrait_hud` takes
## it, so the layout can be asked about a phone from a headless run — where the
## viewport is the 1280x720 desktop one and every rectangle would come back the
## wrong shape.
func _portrait_rival_cards(size: Vector2) -> Array:
	var out: Array = []
	# A tablet draws the rivals' actual boards instead — see
	# `_layout_tablet_boards` — so there are no cards, and everything that hangs
	# off one has to hang off something else. Returning empty rather than
	# leaving the rectangles computed-but-unused is what makes that a compile-
	# time-ish fact: the emote anchors below check for empty and take the other
	# path, and anything new that asks for a card gets nothing rather than a
	# plausible rectangle over the middle of somebody's playfield.
	if tablet:
		return out
	var rivals: Array = []
	for s: SideState in sides:
		if s.slot > 0 and s.in_match:
			rivals.append(s)
	if rivals.is_empty():
		return out
	var cw: float = minf(196.0, (size.x - 24.0) / float(rivals.size()) - 8.0)
	var span: float = float(rivals.size()) * cw + float(rivals.size() - 1) * 8.0
	for i in rivals.size():
		out.append({"side": rivals[i], "rect": Rect2(
			size.x * 0.5 - span * 0.5 + float(i) * (cw + 8.0),
			safe_top + 112.0, cw, 84.0)})
	return out


## The pair of emote bubbles, hung off the rival chip in the portrait header.
##
## Drawn from `_draw_overlay` rather than from `_draw_portrait_hud`, where they
## used to live and where they never once appeared. A bubble is made of
## `_panel`, which paints on `_overlay`; `_draw_portrait_hud` runs in *this*
## node's draw pass, and a `draw_*` call aimed at another canvas item outside
## its own pass is refused outright. So for four builds the key opened, the
## packet went out, the packet arrived, both ends set their slot — and neither
## end drew anything. The same trap `_draw_overlay` warns about a few lines
## further down, sprung in the one place nobody looked.
##
## Both hang off the first rival. `_emote_in` carries no sender, so there is
## nothing to attach it to in a three-rival match — and there is never a
## three-rival match here, because emotes need `net_active` and Game Center
## matches are one against one.
func _draw_portrait_emotes(size: Vector2) -> void:
	if _emote_in.is_empty() and _emote_out.is_empty():
		return
	var at := _portrait_emote_anchors(size)
	if at.is_empty():
		return
	_draw_emote_bubble(at[0], _emote_in, false)
	_draw_emote_bubble(at[1], _emote_out, true)


## Where the two bubbles are centred, as `[theirs, yours]` — or empty when
## there is no rival chip to hang them off.
##
## Split out from the drawing so the placement can be asserted. It is the half
## of this that can be got wrong silently: a bubble drawn off the side of the
## screen and a bubble not drawn at all look identical from the sofa, and the
## bug this replaced went four builds without anybody being able to say which
## of the two it was.
func _portrait_emote_anchors(size: Vector2) -> Array:
	var cards := _portrait_rival_cards(size)
	if cards.is_empty() and tablet:
		# No cards on a tablet, but there is something better to hang them off:
		# the rival's own board. Theirs floats to its left, yours to the left of
		# your own board, so each bubble sits beside the playfield it came from
		# and the two cannot be mixed up.
		var rivals := _living_rivals()
		if rivals.is_empty():
			return []
		var them := _board_rect(rivals[0])
		var you := _board_rect(player)
		return [Vector2(them.position.x - 58.0, them.get_center().y),
			Vector2(you.position.x - 58.0, you.get_center().y)]
	if cards.is_empty():
		return []
	var r: Rect2 = (cards[0] as Dictionary)["rect"]
	# One either side of the name, rather than theirs above it. Above put the
	# bubble over the clock and the pressure countdown for the two and a half
	# seconds it was up — the two readings you are steering by — and the point
	# of anchoring an emote to somebody is that it sits *by* them, which beside
	# the card does just as well as on top of it.
	var mid: float = r.get_center().y
	return [Vector2(r.end.x + 58.0, mid), Vector2(r.position.x - 58.0, mid)]


func _draw_portrait_hud(size: Vector2) -> void:
	# Centred on your own board rather than on the screen. On a phone those are
	# the same point. On a tablet your board sits left of centre to make room
	# for the rivals, and a screen-centred header hangs over the gap between the
	# two boards belonging to neither — while the rivals have names and life
	# counts of their own hung off theirs. Anchoring it here makes your side of
	# the screen read as one column: clock, score, lives, board, the word you
	# are typing.
	var cx: float = size.x * 0.5
	if tablet:
		cx = _board_rect(player).get_center().x
	# The header hangs off the top of the safe area rather than the top of the
	# screen, so the clock does not sit behind the Dynamic Island.
	var top := safe_top

	var daily: bool = mode == Mode.DAILY
	var clock: float = daily_left() if daily else match_time
	var kick := score_kick * score_kick
	_text_pair(_font_bold, _font_bold, Vector2(cx, top + 32.0),
		_daily_clock(clock) if daily else "%d:%02d" % [int(clock) / 60, int(clock) % 60],
		_commas(int(round(score_shown))), 34, int(34 + 10.0 * kick),
		Color("#ff6b6b") if (daily and clock <= DAILY_ALARM) else Color("#e6ecff"),
		Color("#ffd166").lerp(Color.WHITE, kick * 0.7), 40.0)
	# The countdown to the next row of pressure is the reading this whole header
	# exists for — it is the only thing up here that changes what you do next —
	# and it was set at 16, under nine points on the device. Dimmed rather than
	# small now, so it is legible without competing with the clock above it.
	_text_centered(_font, Vector2(cx, top + 72.0),
		"pressure in %ds" % int(ceil(pressure_timer)), 26, Color("#7787b5"))

	# Your lives, as the same pips the landscape header uses. Everything from here
	# to the board top is packing four rows into 208 units, so the gaps are as
	# tight as they can be and still read as separate things — the rival card
	# starts eight below these, which at a glance is the difference between your
	# lives and theirs.
	for i in LIVES:
		var lit: bool = i < player.lives
		draw_rect(Rect2(cx - 40.0 + i * 29.0, top + 92.0, 21.0, 12.0),
			player.accent if lit else Color("#2a3355"), true)

	for card: Dictionary in _portrait_rival_cards(size):
		var s2: SideState = card["side"]
		var r: Rect2 = card["rect"]
		var aimed: bool = player.target == s2.slot
		_panel_here(r, Color("#141b33"), Color(s2.accent, 0.9 if aimed else 0.25), 8.0,
			2.0 if aimed else 1.0)
		_text_fit(_font_bold, Vector2(r.get_center().x, r.position.y + 21.0),
			_show(s2.label), 22, r.size.x - 12.0,
			s2.accent if s2.alive else Color("#4d5878"))
		for k in LIVES:
			draw_rect(Rect2(r.get_center().x - 26.0 + k * 19.0, r.position.y + 42.0,
				14.0, 10.0), s2.accent if k < s2.lives else Color("#2a3355"), true)
		# "3 incoming" is a warning about a board you may be about to lose the
		# race against. At 10 it was five and a half points — smaller than the
		# copyright line on a cereal box, in the one place the game tells you a
		# rival is in trouble.
		var inbound := s2.pending_cells()
		_text_centered(_font, Vector2(r.get_center().x, r.end.y - 18.0),
			("%d incoming" % inbound) if inbound > 0 else _commas(s2.score), 20,
			Color("#ffd166") if inbound > 0 else Color("#7c88ad"))

	# Everything below the board: what is falling on you, the run you are on,
	# and the line you are typing, stacked into the gap above the keyboard.
	_draw_portrait_rails()

	# On a tablet the rivals get their real boards down the right-hand side
	# rather than a row of cards under the clock. Same panel the landscape
	# layout draws, because it is the same thing: a board with a name, a life
	# count and a chain meter arranged around it.
	if tablet:
		for s3: SideState in sides:
			if s3.slot > 0 and s3.in_match:
				_draw_rival_panel(s3)

	var below := _portrait_board_bottom()
	# The band under the board is `104 * band` tall — see
	# `_portrait_board_bottom` — so the three things stacked in it are placed as
	# fractions of that height rather than at fixed offsets. They were fixed,
	# which was invisible while every screen was a phone and the scale never
	# left 1.0 to 1.15, and put the commentary line twenty-six units inside the
	# top row of keys the moment a tablet made the band shorter than the numbers
	# written into it.
	var band := _kb_type_scale(size)
	var bw := WWBoard.COLS * WWBoard.CELL * player.board.scale.x
	var meter := Rect2(cx - bw * 0.5, below + 30.0 * band, bw, 6.0)
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

	# Something for the type to sit on, when there is a photograph behind it.
	#
	# The typed word and the line under it are the two most important pieces of
	# text in the game — what you are holding, and what it will do — and they
	# sit in the strip between the board and the keyboard, which is the one part
	# of a painted board that neither dim band reaches. On Clouds that put gold
	# type on a white sky and it could not be read at all. Soft-edged rather
	# than a panel: it has to stop being a sky without starting to be a widget.
	if _art != null:
		var iw: float = _input_width(size)
		var ink_top: float = below + 66.0 * band - 30.0
		for i in 5:
			var f := float(i) / 4.0
			var g: float = f * 12.0
			draw_rect(Rect2(cx - iw * 0.5 - g, ink_top - g,
				iw + g * 2.0, 78.0 * band + g * 2.0),
				Color(bg_top, 0.24 * (1.0 - f)), true)

	_text_fit(_font_bold, Vector2(cx, below + 66.0 * band), typed.to_upper(), 34,
		_input_width(size), col)

	var note := ""
	if hits > 0:
		note = "takes out %d block%s" % [hits, "" if hits == 1 else "s"]
	elif player.chain + 1 >= SALVO_AT:
		note = "NEXT HIT IS A SALVO"
	elif player.chain >= 2:
		note = "chain x%d" % player.chain
	elif message_life > 0.0:
		note = message
	# The one line of running commentary a phone player gets — what the word in
	# front of them is about to do, and what the game just said back. It was 12,
	# which on the device is under seven points, and it is the last thing anybody
	# has spare attention for mid-word. The band under the board was widened by
	# the same amount it grew, so it is not sitting on the keyboard.
	if note != "":
		_text_fit(_font, Vector2(cx, below + 96.0 * band), note, 17,
			_input_width(size),
			Color("#ffd166") if hits > 0 else Color("#8d99bd"))


## How wide the typed line and the commentary under it are allowed to run.
##
## The whole screen minus a margin on a phone, where the board is the only thing
## on it. On a tablet the rivals are sitting in the right-hand third and a long
## word set at 34 would run straight across them, so it is held to your own
## side of the screen — which is where it belongs anyway, being your word.
func _input_width(size: Vector2) -> float:
	if not tablet:
		return size.x - 40.0
	var rivals := _living_rivals()
	if rivals.is_empty():
		return size.x - 40.0
	var mine: float = _board_rect(rivals[0]).position.x - TABLET_GUTTER
	return maxf(240.0, mine - 40.0)


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
	# 9 was four and a half points — a smudge, not a word, and the two rails are
	# mirror images of each other so the one thing telling you which is which was
	# the one thing nobody could read. There is nothing to compete with out here:
	# the gutters are empty and the label sits clear of both the board and the
	# rival card, so it can simply be the size a label should be.
	_text_centered(_font_bold, Vector2(box.get_center().x, box.position.y - 14.0),
		label, 22, Color(tint, 0.55 if queue.is_empty() else 0.95))
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
		if y + RAIL_CHIP_H > box.end.y:
			# Whatever did not fit, said as a number rather than not said at all.
			_text_centered(_font, Vector2(box.get_center().x, y + 12.0),
				"+%d more" % (queue.size() - int((y - box.position.y) / (RAIL_CHIP_H + CHIP_GAP))),
				20, Color(tint, 0.8))
			return
		var rect := Rect2(box.position.x, y, box.size.x, RAIL_CHIP_H)
		var locked: bool = budget > 0 and p.prefix != "" and aiming.begins_with(p.prefix)
		if locked:
			budget -= 1

		_chip_sb.bg_color = Color(WWBoard.TIER_COLORS[p.tier], 0.92)
		_chip_sb.border_color = Color.WHITE if locked else Color(0, 0, 0, 0.35)
		_chip_sb.set_border_width_all(3 if locked else 1)
		draw_style_box(_chip_sb, rect)

		# The prefix is the single most important string on the screen — it is the
		# question the whole game is asking you — and it was being drawn at nine
		# points on a chip you are reading out of the corner of your eye while
		# typing. `min_size` was 8, low enough that a long prefix could shrink
		# itself back into illegibility rather than admit it did not fit; the chip
		# is taller now, so it does not have to.
		_text_fit(_font_bold, Vector2(rect.position.x + rect.size.x * 0.38,
			rect.get_center().y - 3.0), p.prefix.to_upper(), 22,
			rect.size.x * 0.6, Color("#0b1020"), 14)
		_draw_shape_pip(Vector2(rect.end.x - 20.0, rect.get_center().y - 2.0), p.tier)

		# The fuse is the only part of a chip that is worth watching second to
		# second, so it gets the full width of the chip rather than a corner.
		var fuse := 1.0 - clampf(p.timer / DROP_DELAY, 0.0, 1.0)
		draw_rect(Rect2(rect.position.x + 4.0, rect.end.y - 7.0,
			(rect.size.x - 8.0) * fuse, 3.0), Color("#0b1020"), true)

		y += RAIL_CHIP_H + CHIP_GAP


## Where the board has to stop, so the typed line and the keyboard both fit.
## The band under the board carries the chain meter, the word being typed and the
## one line of commentary under it. 92 was cut for that line set at 12; the line
## is 17 now, and without the extra it would be drawn over the top row of keys.
func _portrait_board_bottom() -> float:
	var size := get_viewport_rect().size
	return _keyboard_bottom() - _kb_height(size) - 104.0 * _kb_type_scale(size)


## Where the board starts, below the status header and whatever the phone has
## parked at the top of the screen.
## `PORTRAIT_BOARD_TOP` is 208 because that is what the phone header needs:
## clock, pressure countdown, your lives, and then a row of rival cards under
## them. A tablet has no rival cards — the rivals are boards down the side now —
## so the header ends after the life pips and the playfield starts where the
## cards used to, which is most of a hundred units earlier.
const TABLET_BOARD_TOP := 132.0

func _portrait_board_top() -> float:
	return (TABLET_BOARD_TOP if tablet else PORTRAIT_BOARD_TOP) + safe_top


## The baseline the keyboard's last row sits on. Held off the very bottom edge
## by the home indicator, which otherwise takes swipes meant for the FIRE key.
## `height` overrides the viewport's own, and exists so the keyboard and the
## emote column can be asked about a phone from a headless run — where the
## viewport is the 1280x720 desktop one and a seven-tall fan would appear to fit
## in places it does not. Every real caller leaves it alone.
func _keyboard_bottom(height := -1.0) -> float:
	var h: float = height if height > 0.0 else get_viewport_rect().size.y
	return h - 18.0 - safe_bottom


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
	# Asked for at the start of the match it will interrupt the end of, which
	# buys the fetch the whole match to finish in. Called cold at the moment a
	# break is due, an interstitial simply is not there yet.
	Ads.fetch()
	mode = how
	lesson = 0
	lesson_age = 0.0
	lesson_done = false
	_first_word_fade = FIRST_WORD_OUT
	difficulty = diff
	# Cleared here rather than only where a rematch is agreed, so a request that
	# arrived while the last summary was up cannot carry into the next match and
	# start a third one nobody asked for.
	rematch_asked = false
	rematch_offered = false
	# A fact about the last run's ending, and it outlives the summary it was
	# drawn on: left standing, the next daily would report itself as walked out
	# of before a word had been typed in it.
	daily_quit = false
	# And the question about that ending, in case the run ended underneath it.
	# `_confirm_up` already refuses to draw a card outside PLAY, so this is the
	# second of the two guards rather than the only one.
	confirm_action = ""
	# Every run starts unchallenged. `_start_challenge` sets this immediately
	# after calling through here — the order matters, and this is why: a run
	# started from the DAILY door on a day somebody happens to have challenged
	# you is not that challenge, and must not report itself as one.
	challenge_run = {}
	# A lesson, a practice run and the daily are played alone. There is nobody to
	# lose to and nothing to be distracted by, which is the entire point.
	if mode != Mode.NORMAL:
		bots = 0
		lineup = []
	# Fix the deal before a single block is minted, or the seed is meaningless.
	if mode == Mode.DAILY:
		WordBank.seed_run(daily_seed())
	else:
		WordBank.free_run()
	# The daily is one board and says so. Every other mode keeps a second seat in
	# the match so the layouts and draw routines have the two sides they were
	# written for, but the daily was paying for that with a rival chip labelled
	# LESSON along the top of a phone and a LESSON row on its own summary — a
	# solo run that looked for all the world like a match against the tutorial
	# bot. Nothing here is sent anywhere, so there is nothing for the seat to do.
	slots_in_play = 1 if single_board() else clampi(1 + bots, 2, SLOTS)
	if lineup.is_empty():
		lineup = _bot_lineup(diff, slots_in_play - 1)

	for s: SideState in sides:
		s.in_match = s.slot < slots_in_play
		s.alive = s.in_match
		if s.slot == 0:
			s.label = "YOU"
		elif s.in_match and MultiplayerManager.current_match != null:
			s.bot = null
			s.is_local = false
			# Their Game Center name, which every other board in the game already
			# has: a CPU is called Duelist and you are called YOU, and the one
			# board belonging to an actual person was the anonymous one. Falls
			# back only if Apple gave us nothing to call them.
			var who := _show_name(MultiplayerManager.peer_name)
			s.label = who if who.strip_edges() != "" else "OPPONENT"
			s.peer_id = 1
		elif s.in_match:
			var who: String = lineup[s.slot -1]
			s.label = who.to_upper() if slots_in_play > 2 else "CPU"
			s.bot = AiOpponent.new()
			# Without this the bot keeps its defaults — no words per minute, no
			# vocabulary, no reaction — and sits there for the whole match.
			s.bot.configure(who, portrait)
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
		s.dealt = 0
		s.tier_bonus = 0
		s.slowdown = 0.0
		s.powers_fired = 0
		s.power_tally = {}
		s.longest_word = ""
		s.in_danger = false
		s.flash = 0.0
		s.target = 0
	if mode == Mode.TUTORIAL or mode == Mode.TRAINING:
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
	elif mode == Mode.DAILY:
		pressure_interval = DAILY_PRESSURE_START
		pressure_timer = DAILY_PRESSURE_START
		# Last, because it is the only thing here that touches the board, and it
		# has to survive the `reset()` every side just took.
		_deal_daily_opening()
	elif mode == Mode.SURVIVAL:
		pressure_interval = SURVIVAL_PRESSURE_START
		pressure_timer = SURVIVAL_PRESSURE_START
		# No opening pile, unlike the daily. A run with no end has time to build
		# its own, and being handed one skips the calm the ramp is measured from.
		survival_banked = 0.0
		survival_took = {}
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


## What a given board is mid-way through typing — which, for anybody but you, is
## nothing at all.
##
## A half-typed word is the one piece of state in this game that is genuinely
## private. It is somebody's plan several seconds before they commit to it, and
## whoever can read it knows which of their blocks are about to go and roughly
## how much is about to come back. None of that is a thing you are meant to be
## able to find out by looking.
##
## It leaked three separate ways, none of them ever a deliberate feature: drawn
## as text under the rival's board in landscape, fed to `highlight_word` so the
## blocks their word would reach lit up on their own playfield, and sent over
## the wire in every state packet as "t". Fixing it at each callsite would have
## fixed it until somebody added a fourth, so it is fixed here instead — every
## reader of an opponent's word now reads an empty string, and the ones that
## already handled "nothing typed yet" gracefully needed no change at all.
##
## Bots are covered by the same rule, though there is plainly no fairness
## argument for hiding a CPU's word from you. A rule with an exception in it
## gets forgotten at exactly the callsite that matters; "nobody's word but yours
## is ever drawn" is a rule that can be checked by reading one function.
func _typing_of(s: SideState) -> String:
	return typed if s.is_local else ""


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
## Fold a finished run into this week's missions, and remember what it paid so
## the summary can say so.
##
## One function for all three modes rather than three calls to `Profile`: the
## week key has to be computed the same way every time, and a mode added later
## that worked it out for itself would be a mode whose runs quietly counted for
## a different week.
func _bank_week(r: Dictionary, what: String) -> int:
	var gained := Profile.record_week(Missions.week_key(), r, what)
	weekly_earned = gained
	return gained


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


## How long is left of the daily run.
func daily_left() -> float:
	return maxf(0.0, DAILY_SECONDS - match_time)


## The sprint clock, as the player reads it.
##
## Not `m:ss`. A run this short spends all but its first fifteen seconds showing
## a leading "0:", which is a whole digit of nothing, and the last ten seconds are
## the ones being counted — so they get tenths, and the readout visibly speeds up
## exactly when the run does.
func _daily_clock(left: float) -> String:
	if left <= DAILY_ALARM:
		return "%.1f" % left
	return "%d" % int(ceil(left))


## True while nothing you fire has anywhere to go. One test, read by everything
## that would otherwise send a block, so there is exactly one place to look when
## asking why a daily does not attack.
func solo_run() -> bool:
	return mode == Mode.DAILY or mode == Mode.SURVIVAL


## The two modes played on one board against nothing but the clock. They share
## every layout decision that follows from having no rival — one seat in the
## match, no rival column, no chips along the top of a phone.
func single_board() -> bool:
	return mode == Mode.DAILY or mode == Mode.SURVIVAL


## How long a survival run has lasted, as the player reads it. `m:ss` up to an
## hour, and an hour is not a number this mode is going to see.
func _survival_clock(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]


## How big the ambient blocks are in survival. Same idea as `_daily_tier` and
## deliberately a separate function: the two ramps are tuned against runs of
## completely different lengths, and folding them together is how one of them
## quietly gets retuned by a change meant for the other.
func _survival_tier() -> int:
	var t := 0
	for at: float in SURVIVAL_TIER_AT:
		if match_time >= at:
			t += 1
	return mini(t, TIERS.size() - 1)


## Deal the pile the day starts on.
##
## Every draw here comes off `WordBank.rng` — the sizes, the stamps and, inside
## `add_garbage`, the column each block falls down. That is the whole promise of
## a daily: two machines that agree on the date sit down in
## front of the identical mess.
func _deal_daily_opening() -> void:
	var room := WWBoard.COLS * WWBoard.ROWS
	var target := int(round(float(room)
		* WordBank.rng.randf_range(DAILY_OPEN_MIN, DAILY_OPEN_MAX)))
	# The pile is built out of whole blocks, so it lands near the target rather
	# than on it. The guard is against the one case that does not terminate: a
	# board too congested to place anything, where `cell_count` stops moving.
	var guard := 0
	while player.board.cell_count() < target and guard < room:
		guard += 1
		var tier: int = int(DAILY_OPEN_TIERS[
			WordBank.rng.randi_range(0, DAILY_OPEN_TIERS.size() - 1)])
		var spec: Dictionary = TIERS[tier]
		var stamp := _mint_stamp(WordBank.random_common(), STAMP_WANT, player)
		if not player.board.add_garbage(stamp, tier, spec["w"], spec["h"]):
			break
	player.board.snap_to_grid()
	_log("today's board is already %d%% full" %
		int(round(float(player.board.cell_count()) / float(room) * 100.0)),
		Color("#ffd166"))


## How big the ambient blocks are right now. The run escalates by weight as well
## as by rate, because rate alone runs out of room: much under a second and a
## half apart and the blocks arrive faster than they can be read, which is not
## pressure, it is noise.
func _daily_tier() -> int:
	var t := 0
	for at: float in DAILY_TIER_AT:
		if match_time >= at:
			t += 1
	return mini(t, TIERS.size() - 1)


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
	var paid := Scoring.flat(Scoring.TOPOUT_BONUS)
	if _owned_here(who):
		who.score += paid
		if who == player:
			_pop_score("+%s" % _commas(paid), "TOPPED THEM OUT", paid)
			score_kick = 1.0
			Sfx.play("salvo", 1.1)
			Haptics.fire("salvo")
			_say("TOPPED OUT %s — +%s" % [_show(victim.label),
				_commas(paid)], Color("#ffd166"))
		_log("%s overfilled %s — +%s" % [_show(who.label), _show(victim.label),
			_commas(paid)], Color("#ffd166"))
	elif net_active():
		MultiplayerManager.send_event("topout", {})


## Their attack ended one of our lives, and they are owed for it.
func _on_topout_credit(_culprit: int) -> void:
	var paid := Scoring.flat(Scoring.TOPOUT_BONUS)
	player.score += paid
	_pop_score("+%s" % _commas(paid), "TOPPED THEM OUT", paid)
	score_kick = 1.0
	Sfx.play("salvo", 1.1)
	Haptics.fire("salvo")
	_say("TOPPED THEM OUT — +%s" % _commas(paid), Color("#ffd166"))


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

	# Nothing reaches the game while a break is up. On a phone the native view
	# has already swallowed it, but the stand-in used off-device is a canvas
	# layer inside our own window — and a keystroke landing on the summary behind
	# it would walk to a screen the player cannot see.
	#
	# The curtain either side of it counts for the same reason: it is opaque, and
	# a key pressed at something you cannot see is not a decision.
	if _ad_paused():
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

	if phase == Phase.LOBBY:
		# The keys the doors advertise. ENTER is quick match while there is one
		# to start and Stop once there is — the same swap the first door makes,
		# so the key and the plate never disagree about what they do.
		match k.keycode:
			KEY_ENTER, KEY_KP_ENTER:
				_activate("versus_cancel" if _versus_busy() else "versus_quick")
			KEY_I: _activate("versus_invite")
			KEY_C: _activate("versus_cpu")
			KEY_ESCAPE:
				_activate("versus_cancel" if _versus_busy() else "title")
		return

	if phase == Phase.SETTINGS:
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

	if phase == Phase.WEEKLY:
		match k.keycode:
			KEY_ESCAPE, KEY_W: _activate("title")
		return

	if phase == Phase.BOARDS:
		# Left and right move between the two boards; up and down between the two
		# crowds. Same shape as the cosmetics screen's slot arrows, and it means
		# all four tabs are reachable without the mouse the way the buttons are.
		match k.keycode:
			KEY_LEFT, KEY_A: _activate("btab:0")
			KEY_RIGHT, KEY_D: _activate("btab:1")
			KEY_UP, KEY_W: _activate("bscope:%d" % Boards.GLOBAL)
			KEY_DOWN, KEY_S: _activate("bscope:%d" % Boards.FRIENDS)
			KEY_C: _activate("challenges")
			KEY_G: _activate("gcboard")
			KEY_R: _open_board_view()
			KEY_ESCAPE, KEY_B: _activate("title")
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
		# The card answers first. It is a question, so ENTER takes it and ESC
		# declines — and declining hangs up as well as leaving, so they stop
		# waiting on somebody who has gone.
		if over_age < OVER_LOCKOUT:
			return
		# The card answers first. It is a question, so ENTER takes it and ESC
		# declines — and declining hangs up as well as leaving, so they stop
		# waiting on somebody who has gone.
		#
		# Behind the lockout with everything else, deliberately: ENTER is the key
		# that fires a word, so it is the single most likely keystroke to still
		# be in flight when a match ends. Accepting a rematch with it a
		# millisecond after the scoreboard appears is the same accident the
		# lockout exists to prevent, and a worse one — it starts a whole match.
		if _rematch_popup():
			match k.keycode:
				KEY_ENTER, KEY_KP_ENTER: _activate("rematch")
				KEY_ESCAPE: _activate("title")
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
			# The daily's two boards, on the arrows. Safe to add to a screen that
			# deliberately refuses letters: an arrow reports unicode 0, so it is
			# not a key anybody's hands are still typing a word with.
			KEY_LEFT, KEY_A when mode == Mode.DAILY: _activate("dtab:0")
			KEY_RIGHT, KEY_D when mode == Mode.DAILY: _activate("dtab:1")
		return

	# The pitch owns the keyboard while it is up, for the same reason it owns
	# the mouse: the title screen's own shortcuts are live underneath it, and a
	# stray 2 would start the daily out from under a card still being read.
	# Escape closes it rather than quitting the game, which is what that key
	# does on the title screen one branch down.
	if _promo_up():
		match k.keycode:
			KEY_ESCAPE, KEY_SPACE: _close_promo()
			KEY_ENTER, KEY_KP_ENTER: _activate("promo_buy")
			KEY_LEFT: _promo_step(-1)
			KEY_RIGHT: _promo_step(1)
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
			# Eight rather than renumbering. The plates carry no number badges, so
			# these are a desktop convenience rather than something read off the
			# screen — and shuffling 3 through 7 under somebody who has learnt
			# them costs more than the new door being last in the list.
			KEY_8: _activate("survival")
			# Nine for the same reason eight is eight: appended rather than
			# renumbered, so nobody's fingers have to be retrained for a door
			# that was added after they learnt the others.
			KEY_9: _activate("boards")
			# Appended like eight and nine were, rather than renumbering under
			# fingers that have already learnt the others.
			KEY_0: _activate("weekly")
			KEY_W: _activate("weekly")
			KEY_V: _activate("versus")
			KEY_S: _activate("survival")
			KEY_P: _activate("mastery")
			KEY_B: _activate("boards")
			KEY_H:
				show_rules = not show_rules
				Sfx.play("back", 1.2)
			KEY_ESCAPE:
				get_tree().quit()
		return

	# Nothing to type until GO.
	if phase == Phase.COUNTDOWN:
		return

	# The leave card owns the keyboard while it is up. Two keys and nothing else
	# — every letter is swallowed rather than falling through to the typing arm
	# underneath, which would have the player building a word into a board they
	# have just been asked whether they are leaving.
	if _confirm_up():
		match k.keycode:
			KEY_ENTER, KEY_KP_ENTER: _activate("confirm_yes")
			KEY_ESCAPE: _activate("confirm_no")
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
			if not paused:
				_fire_pressed()
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
		# Guarded three ways for the reason the arm above is guarded at all: an
		# unguarded `KEY_R:` would claim the letter R for the whole game, and R
		# is in rather a lot of words. This only takes it on the tutorial's last
		# step, while the button is actually drawn, and only with an empty line —
		# which is the same condition SPACE finishes on, so the two keys offered
		# by that step behave alike.
		KEY_R when mode == Mode.TUTORIAL and _lesson_restart.has_area() \
				and typed.is_empty():
			_restart_lesson()
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
	# In a solo run there is nobody to aim at, and `_pick_target_for` answers an
	# empty room by handing back the shooter. Left to run, that points every word
	# you fire at your own board. Nothing is sent in a solo run — see
	# `_strike` — but the aim is settled here rather than relying on the send
	# being skipped further down.
	var defender: SideState = null
	if not solo_run():
		defender = sides[attacker.target]
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
	attacker.blocks_cleared += cleared
	budget -= cleared

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
	# The lesson gets a longer window than the game does. See `LESSON_CHAIN_GRACE`
	# — the step that teaches the chain was failing people on their typing speed
	# rather than on the rule it exists to show them.
	if mode == Mode.TUTORIAL:
		attacker.chain_window *= LESSON_CHAIN_GRACE
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
	var out_tier := clampi(_base_tier(attacker.chain, word) + combo + spent + focus,
		0, TIERS.size() - 1)

	earned += _strike(attacker, defender, word, out_tier, DROP_DELAY,
		word.substr(maxi(0, word.length() - 3)))

	earned += _fire_powers(attacker, defender, word, powers, out_tier, intercepted)
	_note_best(attacker, word, earned)
	_voice_attack(attacker, cleared, intercepted, out_tier)
	_report(attacker, word, cleared, intercepted, out_tier, spent)


## The best word of the match is what that word was worth all in — its own score
## plus anything it triggered — since that is the one you would want to tell
## somebody about afterwards.
func _note_best(side: SideState, word: String, earned: int) -> void:
	if earned > side.best_word_score:
		side.best_word_score = earned
		side.best_word = word


## An attack going out, whether or not there is anyone out there.
##
## Every hit in the game funnels through here, which is the point: the rules
## that decide how big a hit is — the chain ladder, the combo, a tier owed by an
## earlier COMBO — are the same rules in a solo run as in a match, and only the
## delivery differs. With a rival the block is sent and thrown; without one there
## is nothing to send it to. Either way it is paid at `STRIKE_PAY` a cell, so the
## ladder pays for exactly what it always paid for and the daily is the same game
## rather than a defanged copy of it.
##
## Returns what it was worth in points.
func _strike(attacker: SideState, defender: SideState, word: String, tier: int,
		delay: float, text: String = "") -> int:
	if tier < 0:
		return 0
	if not solo_run():
		_send_block(defender, word, tier, delay, attacker)
		_throw(attacker, defender, tier, text)
	var cells := _cells(tier)
	attacker.dealt += cells
	var pay := cells * STRIKE_PAY
	attacker.score += pay
	if attacker == player:
		_pop_score("+%s" % _commas(pay), _tier_name(tier), pay)
		score_kick = minf(1.0, score_kick + 0.30)
	return pay


## One block on its way. The defender mints its own stamp over a network,
## because only they can see what their board is already holding.
func _send_block(
	defender: SideState, 
	word: String, 
	tier: int, 
	delay: float,
	from: SideState = null
) -> void:
	if net_active() and not _owned_here(defender):
		MultiplayerManager.send_event(
			"attack",
			{
				"word": word,
				"tier": tier
			}
		)
		defender.flash = 1.0
		return
	var p := Pending.new()
	p.from = _entity_of(from)
	p.tier = tier
	p.prefix = _mint_stamp(word, STAMP_WANT, defender)
	p.cells = _cells(tier)
	p.timer = delay
	defender.pending.append(p)
	defender.flash = 1.0

## Everything the other player sends, once the handshake has finished.
##
## This took a second `player: GKPlayer` argument, which `data_received` does not
## send — so Godot dropped every emit and with it every attack, salvo, pressure
## tick and board mirror. Two players connected and then sat in silence. The
## sender is not needed anyway: a 1v1 has exactly one of them.
func _on_multiplayer_data(packet: Dictionary) -> void:
	# Every message the match needs, in one place. Only `attack` was wired
	# before, so a connected game had no salvos, no ambient pressure, no mirror
	# of the opponent's board and no way to end — which is most of what "it
	# connects and then nothing happens" was.
	var payload: Dictionary = packet.get("payload", {})
	match String(packet.get("type", "")):
		"attack":
			_on_net_attack(String(payload.get("word", "")),
				int(payload.get("tier", 0)))
		"salvo":
			_on_net_salvo(String(payload.get("word", "")),
				int(payload.get("count", 0)))
		"pressure":
			# Ambient pressure is minted from a word both ends agree on, so the
			# clock stays in step rather than drifting apart.
			_seed_pressure(String(payload.get("word", "")))
		"state":
			_on_net_state(payload)
		"topout":
			_on_topout_credit(0)
		"topped_out":
			# They lost their last board, so the match is over and we took it.
			if phase == Phase.PLAY or phase == Phase.COUNTDOWN:
				winner = "YOU"
				_end_match(ai_side)
		"final":
			_on_net_final(payload)
		"rematch":
			_on_net_rematch()
		"emote":
			_on_net_emote(int(payload.get("i", -1)))


# ------------------------------------------------------------------ rematch
#
# Rematch used to walk back to the versus screen and start a fresh search,
# which threw away the one opponent you had just proved you could reach and
# went looking for a stranger. The match is still open when a game ends —
# nobody has disconnected — so the person who beat you is right there, and
# asking them is a packet rather than a fresh forty-second matchmaking round.

## True once this device has asked. Held so the button can say it is waiting
## rather than doing nothing visible on a second press.
var rematch_asked := false
## True once the other end has asked us.
var rematch_offered := false


## Whether a rematch can be asked for at all, which is only true while the
## opponent is still connected. A Game Center match ends the moment somebody
## leaves — `net_active()` goes false with it — and offering a button that can
## only fail is worse than offering nothing.
func _rematch_possible() -> bool:
	if not net_active():
		# A CPU match has no one to ask and can always be re-run.
		return difficulty != "Versus"
	return MultiplayerManager.in_match()


## Both ends have to want it. Whoever asks second is the one who starts the
## match, and the other is started by the packet — so there is no vote to lose
## and no host to elect.
##
## This name was taken by a netfox-era handler that put both players back in the
## dead `Phase.LOBBY` to ready up again. Nothing had been able to call it since
## `_net_setup` became a no-op, and it collided with this one — so it is gone
## rather than renamed around, which would have left two rematch handlers and
## one silent trap.
func _on_net_rematch() -> void:
	rematch_offered = true
	if rematch_asked:
		_begin_rematch()


## Whether the "they want a rematch" card is up.
##
## A subtitle change on a button was too quiet to notice — the whole event is
## somebody else asking you a question, and the summary screen is busy. So it
## gets a card over the top, which is also what makes Yes and No a pair of real
## choices rather than one button that has quietly changed meaning.
##
## Only ever raised for a request that arrived, never for one we sent: if this
## device asked first there is nothing to decide, and the match starts by itself
## the moment they agree.
func _rematch_popup() -> bool:
	# `net_active` as well as the flag. Only a packet can set `rematch_offered`
	# and only a peer sends one, so the two cannot disagree today — but the card
	# is a person asking a question, and nothing about a CPU match should ever be
	# able to raise one.
	return phase == Phase.OVER and net_active() and rematch_offered \
		and not rematch_asked and _rematch_possible()


## The card, and the two answers under it.
func _rematch_popup_buttons() -> Array:
	if not _rematch_popup():
		return []
	var size := get_viewport_rect().size
	var w: float = minf(560.0, size.x - GRID_MARGIN * 2.0)
	var cx := size.x * 0.5
	var card := _rematch_popup_rect()
	var bw: float = (w - 60.0 - 16.0) * 0.5
	var by: float = card.end.y - 30.0 - 66.0
	return [
		{"rect": Rect2(cx - w * 0.5 + 30.0, by, bw, 66.0), "key": "",
			"label": "Play again", "sub": "", "note": "", "rating": 0,
			"accent": PLAYER_ACCENT, "action": "rematch"},
		{"rect": Rect2(cx - w * 0.5 + 30.0 + bw + 16.0, by, bw, 66.0), "key": "ESC",
			"label": "No thanks", "sub": "", "note": "", "rating": 0,
			"accent": Color("#8d99bd"), "action": "title"},
	]


func _rematch_popup_rect() -> Rect2:
	var size := get_viewport_rect().size
	var w: float = minf(560.0, size.x - GRID_MARGIN * 2.0)
	var h: float = 250.0
	return Rect2(size.x * 0.5 - w * 0.5, size.y * 0.5 - h * 0.5, w, h)


func _draw_rematch_popup(size: Vector2) -> void:
	if not _rematch_popup():
		return
	# Everything behind it is dimmed and unclickable, because this is a question
	# and the screen under it is the answer to the last one.
	_overlay.draw_rect(Rect2(-SHAKE_MARGIN, -SHAKE_MARGIN,
		size.x + SHAKE_MARGIN * 2.0, size.y + SHAKE_MARGIN * 2.0),
		Color(bg_top, 0.82), true)
	var r := _rematch_popup_rect()
	_panel(r, Color("#111730"), Color(PLAYER_ACCENT, 0.75), 14.0, 3.0)
	var cx := r.get_center().x
	var who := _show(ai_side.label).to_upper() if net_active() else "THEY"
	var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() / 320.0)
	_otext(_font, Vector2(cx, r.position.y + 40.0), "REMATCH", 14,
		Color(PLAYER_ACCENT, pulse))
	_text_fit_overlay(_font_bold, Vector2(cx, r.position.y + 84.0),
		"%s WANT ANOTHER" % who, 30, r.size.x - 50.0, Color("#e6ecff"), 17)
	_text_fit_overlay(_font, Vector2(cx, r.position.y + 120.0),
		"same opponent, straight into it", 16, r.size.x - 50.0,
		Color("#8d99bd"), 12)
	for b: Dictionary in _rematch_popup_buttons():
		_draw_menu_button(b)


func _begin_rematch() -> void:
	rematch_asked = false
	rematch_offered = false
	start_match("Versus", 0, [], Mode.NORMAL)


## What the rematch button says under its name. Against a person this is the
## only place the negotiation is visible, so it has to carry all three states:
## nobody has asked, you have asked, they have asked.
func _rematch_sub() -> String:
	if not net_active():
		return difficulty
	if rematch_asked:
		return "waiting for them"
	if rematch_offered:
		return "they want to go again"
	return "ask for another"


# ------------------------------------------------------------- leaving a run
#
# Leave is the one button on the pause menu that cannot be taken back, and until
# now it was also the one with nothing between the press and the consequence.
# What the press actually costs depends on the mode, and in one of them it was
# not a cost at all — it was a loophole:
#
#   * **Versus.** The opponent is told you have gone and the match is over for
#     both of you.
#   * **Survival.** The run banks no record. The time is still charged.
#   * **The daily.** Nothing was banked, so `daily_done` stayed false and the
#     same board could be played again. Leave was the fastest way to reroll a
#     bad run, which is the exact thing `_end_daily` exists to prevent — and the
#     prevention only ever covered the clock running out.
#
# So there is a card in front of it now, and it names which of those is about to
# happen rather than asking "are you sure" about nothing in particular. It is
# deliberately built out of the same pieces as the rematch card: a question over
# a dimmed screen with two answers under it, because that is an object a player
# of this game has already learnt to read.
#
# Practice and the tutorial get no card. Nothing is banked in either, so there is
# nothing to warn about, and a confirmation over an empty consequence is how a
# player learns to dismiss the one that matters without reading it.

## What the card is standing in front of: the action `_activate` will be handed
## if the answer is yes. Empty when no card is up.
var confirm_action := ""


# ------------------------------------------------------- the premium slideshow
#
# The one screen in this game that exists to sell something, and the rules it is
# kept to.
#
# It is shown once per content drop and never again — see `Profile.PROMO_DROP`.
# Not once per launch: a full-screen advert on every cold start is the thing
# that turns a paid pack somebody was going to buy into a reason to delete the
# app, and the close button becomes the most-pressed control in the game. A
# player who has seen it has been told, and telling them again is not new
# information, it is nagging.
#
# It is never raised over a match, only over the title screen, and it is never
# raised for somebody who already owns the pack.
#
# The slides are the real boards. Each one draws the actual backdrop texture
# with the actual motion layer running on it and the actual block faces on top,
# through the same functions the game uses — so this cannot advertise something
# the game does not render. The alternative is a folder of marketing stills that
# go stale the first time a colour is tweaked.

## What the run that just ended paid in mission XP, for the summary to report.
## Zero for the overwhelming majority of runs, which finish nothing.
var weekly_earned := 0

var promo_open := false
var promo_slide := 0
## How long the current slide has been up, for the auto-advance.
var promo_age := 0.0
## Stops the carousel once the player has taken hold of it. Somebody using the
## arrows is reading at their own pace, and a slide that jumps out from under
## them mid-read is the carousel arguing with them.
var promo_held := false

## How long each slide sits before the next one, in seconds.
const PROMO_DWELL := 3.2

## What the slideshow is made of: the eight boards in the order they were drawn,
## then the one thing in the pack that is not a board.
##
## The ad break is last rather than first on purpose. It is the most valuable
## thing in the pack for a lot of people and the least interesting to look at,
## and leading with it would open the pitch on a slide with nothing moving.
func _promo_slides() -> Array:
	var out: Array = []
	for id: String in ["forest", "volcano", "ocean", "space",
			"cyber", "clouds", "desert", "aurora"]:
		out.append({
			"theme": id,
			"title": String(Profile.entry("theme", id).get("name", id)).to_upper(),
			"note": PROMO_TAGLINES.get(id, ""),
		})
	out.append({
		"theme": "", "title": "NO AD BREAKS",
		"note": "every run, start to finish, uninterrupted",
	})
	return out


## Three words a board, in the voice the concept art used. Kept here rather than
## in `Cosmetics` because this is ad copy and that file is art direction — one
## gets rewritten when the picture changes and the other when the marketing does.
const PROMO_TAGLINES := {
	"forest": "calm · natural · alive",
	"volcano": "hot · intense · unstoppable",
	"ocean": "deep · serene · mysterious",
	"space": "infinite · otherworldly · epic",
	"cyber": "neon · fast · electric",
	"clouds": "bright · dreamy · limitless",
	"desert": "warm · bold · endless",
	"aurora": "cool · focused · hypnotic",
}


## Phase-guarded as well as flag-guarded, like every other card here. The title
## screen is the only place this may sit: a promo that survived into a match
## would be an advert over a running clock.
func _promo_up() -> bool:
	return promo_open and (phase == Phase.TITLE or phase == Phase.SPLASH)


## Raise it, if this player is owed it.
##
## Called off the splash rather than from `_ready`, so the first thing anybody
## sees is still the game's own front door resolving into the title — a pitch
## that beat the splash to the screen would be an advert before the app.
##
## `note_promo_seen` fires here, at the moment it goes up, rather than when it
## is closed. Closing is not guaranteed: the app can be killed from the switcher
## with the card still open, and a pitch that only counts as delivered when it
## is dismissed would come back every launch for anybody who does that.
func _raise_promo() -> void:
	if not Profile.owes_promo():
		return
	promo_open = true
	promo_slide = 0
	promo_age = 0.0
	promo_held = false
	Profile.note_promo_seen()
	Sfx.play("count", 1.1)


func _close_promo() -> void:
	promo_open = false
	promo_held = false
	Sfx.play("back", 1.2)


## Phase-guarded as well as flag-guarded, the way `_rematch_popup` is.
##
## The card is raised from the pause menu and answered there, but the run
## underneath it can end while it is up: a versus opponent leaves, or the clock
## runs out on a match that was only paused on this screen. Left to the flag
## alone the card would still be swallowing every press on the summary that
## replaced it, which is a frozen screen with no way off it.
func _confirm_up() -> bool:
	return confirm_action != "" and phase == Phase.PLAY


## Whether walking out of this run costs anything worth stopping for. Empty
## means it does not, and the press goes straight through.
func _leave_costs() -> bool:
	return mode == Mode.DAILY or mode == Mode.SURVIVAL or mode == Mode.NORMAL


## What the card says, per mode. Three keys: the question, the sentence under it
## naming the cost, and what the yes button is called.
##
## The daily's yes says "Post and leave" rather than "Leave" because posting is
## the part that is not obvious and is the part that cannot be undone. A button
## that says only "Leave" next to a sentence about posting is a button somebody
## presses having read the first word.
func _confirm_lines() -> Dictionary:
	if mode == Mode.DAILY:
		return {
			"title": "LEAVE THE DAILY?",
			"note": "%s goes to the board as it stands — there is one run a day"
				% _commas(player.score),
			"yes": "Post and leave",
		}
	if mode == Mode.SURVIVAL:
		return {
			"title": "END THE RUN?",
			"note": "a run walked out of takes no record, however long it lasted",
			"yes": "End it",
		}
	if net_active():
		return {
			"title": "FORFEIT THE MATCH?",
			"note": "%s is told you left, and the match is over" % (
				_show(ai_side.label).to_upper() if ai_side != null else "THEY"),
			"yes": "Forfeit",
		}
	return {
		"title": "LEAVE THE MATCH?",
		"note": "an unfinished match banks no score and no XP",
		"yes": "Leave",
	}


func _confirm_rect() -> Rect2:
	var size := get_viewport_rect().size
	var w: float = minf(560.0, size.x - GRID_MARGIN * 2.0)
	var h: float = 250.0
	return Rect2(size.x * 0.5 - w * 0.5, size.y * 0.5 - h * 0.5, w, h)


func _confirm_buttons() -> Array:
	if not _confirm_up():
		return []
	var card := _confirm_rect()
	var bw: float = (card.size.x - 60.0 - 16.0) * 0.5
	var by: float = card.end.y - 30.0 - 66.0
	# The destructive one on the left and lit in the warning colour, with the way
	# out beside it in grey. Same seats as the rematch card's pair, so the button
	# under the thumb is in the place the last card put it.
	return [
		{"rect": Rect2(card.position.x + 30.0, by, bw, 66.0), "key": "ENTER",
			"label": String(_confirm_lines()["yes"]), "sub": "", "note": "",
			"rating": 0, "accent": Color("#ff6b6b"), "action": "confirm_yes"},
		{"rect": Rect2(card.position.x + 30.0 + bw + 16.0, by, bw, 66.0),
			"key": "ESC", "label": "Keep playing", "sub": "", "note": "",
			"rating": 0, "accent": PLAYER_ACCENT, "action": "confirm_no"},
	]


func _promo_rect() -> Rect2:
	var size := get_viewport_rect().size
	var w: float = minf(600.0, size.x - GRID_MARGIN * 2.0)
	# Tall in portrait, because the thing being sold is a portrait picture and a
	# letterbox preview of a phone wallpaper sells nothing.
	var h: float = minf(size.y - 120.0, 940.0 if portrait else 560.0)
	return Rect2(size.x * 0.5 - w * 0.5, size.y * 0.5 - h * 0.5, w, h)


## The button row's top edge. Everything in the footer is placed off this rather
## than off a stack of offsets from the picture: the name, the tagline and the
## dots all hang upward from it, so no amount of fiddling with the card's height
## can slide the dots under the buttons — which is exactly what a first pass of
## offsets-from-the-top did, and it hid the one control that says how many
## boards are in the pack.
const PROMO_BTN_H := 62.0


func _promo_button_top() -> float:
	return _promo_rect().end.y - 22.0 - PROMO_BTN_H


## Where the picture goes inside the card: the whole of it above the copy and
## the controls.
func _promo_stage() -> Rect2:
	var r := _promo_rect()
	var pad := 18.0
	# Room for a name, a tagline, nine dots and the buttons, with air between
	# the dots and the buttons.
	var foot: float = 196.0 if portrait else 182.0
	return Rect2(r.position.x + pad, r.position.y + 54.0,
		r.size.x - pad * 2.0, r.size.y - 54.0 - foot)


func _promo_buttons() -> Array:
	if not _promo_up():
		return []
	var r := _promo_rect()
	var out: Array = []
	var bh := PROMO_BTN_H
	var by := _promo_button_top()

	# The price comes off Apple rather than out of a string here, and the button
	# is only a buy button while there is something to buy. On a desktop, or
	# while the product list is still loading, it says so instead of offering a
	# purchase that would silently do nothing.
	var buyable := Store.can_buy()
	if buyable:
		var bw: float = (r.size.x - 36.0 - 14.0) * 0.58
		out.append({
			"rect": Rect2(r.position.x + 18.0, by, bw, bh), "key": "ENTER",
			"label": "Unlock · %s" % Store.price, "sub": "", "note": "",
			"rating": 0, "accent": Color("#ffd166"), "action": "promo_buy"})
		out.append({
			"rect": Rect2(r.position.x + 18.0 + bw + 14.0, by,
				r.size.x - 36.0 - 14.0 - bw, bh), "key": "ESC",
			"label": "Not now", "sub": "", "note": "", "rating": 0,
			"accent": Color("#5d6a92"), "action": "promo_close"})
	else:
		# Centred and only as wide as it needs to be. Stretched across the card
		# it is a plate three-quarters empty, which reads as something failing
		# to load rather than as a button.
		var cw: float = minf(320.0, r.size.x - 36.0)
		out.append({
			"rect": Rect2(r.get_center().x - cw * 0.5, by, cw, bh),
			"key": "ESC", "label": "Close", "sub": "", "note": "", "rating": 0,
			"accent": Color("#5d6a92"), "action": "promo_close"})

	# The two arrows, sat over the picture at its vertical middle where a thumb
	# reaching round the phone already is.
	var stage := _promo_stage()
	var aw := 46.0
	var ay: float = stage.get_center().y - 26.0
	out.append({
		"rect": Rect2(stage.position.x + 4.0, ay, aw, 52.0), "key": "",
		"label": "", "sub": "", "note": "", "rating": 0,
		"accent": Color("#8d99bd"), "action": "promo_prev"})
	out.append({
		"rect": Rect2(stage.end.x - aw - 4.0, ay, aw, 52.0), "key": "",
		"label": "", "sub": "", "note": "", "rating": 0,
		"accent": Color("#8d99bd"), "action": "promo_next"})
	return out


func _promo_step(by: int) -> void:
	var n: int = _promo_slides().size()
	promo_slide = posmod(promo_slide + by, n)
	promo_age = 0.0
	# Touched, so it stops moving on its own. See `promo_held`.
	promo_held = true
	Sfx.play("count", 1.15)


func _tick_promo(delta: float) -> void:
	if not _promo_up():
		return
	# It has been bought, so there is nothing left to sell. Checked here rather
	# than wired to `Profile.changed` because ownership arrives by four
	# different routes — a purchase, a restore, an entitlement found at launch,
	# an Ask to Buy approved days later — and one poll catches all of them where
	# four signal handlers would eventually miss one.
	if Profile.owns(Profile.PACK_PREMIUM):
		promo_open = false
		return
	if promo_held:
		return
	promo_age += delta
	if promo_age >= PROMO_DWELL:
		promo_age = 0.0
		promo_slide = posmod(promo_slide + 1, _promo_slides().size())


## The pitch.
##
## Everything inside the picture frame is drawn with the game's own functions —
## `Cosmetics.draw_motion` for the weather, `Cosmetics.draw_premium_face` for
## the blocks — so what is being advertised is what will actually arrive. A
## folder of marketing stills would be one colour tweak away from being a lie.
func _draw_promo(size: Vector2) -> void:
	if not _promo_up():
		return
	var t := Time.get_ticks_msec() / 1000.0
	# Heavier than the other cards' 0.86. Those stand in front of a playfield,
	# which is dark; this one stands in front of the title screen, which is a
	# stack of lit plates, and at 0.86 the menu read straight through the pitch
	# and made it look like a window rather than a card.
	_overlay.draw_rect(Rect2(-SHAKE_MARGIN, -SHAKE_MARGIN,
		size.x + SHAKE_MARGIN * 2.0, size.y + SHAKE_MARGIN * 2.0),
		Color(bg_top, 0.96), true)

	var r := _promo_rect()
	_panel(r, Color("#0c1226"), Color("#ffd166", 0.55), 16.0, 2.0)
	var cx := r.get_center().x
	_draw_tracked(_font_bold, Vector2(cx, r.position.y + 30.0), "PREMIUM PACK",
		13, 3.0, Color("#ffd166"))

	var slides := _promo_slides()
	var slide: Dictionary = slides[clampi(promo_slide, 0, slides.size() - 1)]
	var stage := _promo_stage()
	var theme := String(slide["theme"])

	if theme != "":
		_draw_promo_board(stage, theme, t)
	else:
		_draw_promo_no_ads(stage, t)

	# The name and its three words, under the picture rather than over it —
	# over it, every slide needs its own answer to "is the type readable on
	# this one", and Clouds does not have one.
	#
	# Hung upward off the button row rather than downward off the picture, so
	# the dots cannot end up underneath the buttons. See `_promo_button_top`.
	var by := _promo_button_top()
	var tint: Color = Cosmetics.theme_tint(theme, "accent", Color("#ffd166")) \
		if theme != "" else Color("#ffd166")
	_text_fit_overlay(_font_bold, Vector2(cx, by - 74.0),
		String(slide["title"]), 30, r.size.x - 60.0, tint, 18)
	_text_fit_overlay(_font, Vector2(cx, by - 46.0),
		String(slide["note"]), 14, r.size.x - 60.0, Color("#aab4d4"), 11)

	# Dots. The count is the whole point — "there are nine of these" is the
	# argument, and a carousel with no dots hides it.
	var dy: float = by - 20.0
	var gap := 15.0
	var x0: float = cx - (float(slides.size()) - 1.0) * gap * 0.5
	for i in slides.size():
		var on: bool = i == promo_slide
		_overlay.draw_circle(Vector2(x0 + float(i) * gap, dy), 4.5 if on else 3.0,
			Color("#ffd166") if on else Color("#3d4666"))

	for b: Dictionary in _promo_buttons():
		_draw_menu_button(b)
	# The arrows' glyphs, drawn after the plates they sit on.
	var stage_mid: float = stage.get_center().y
	_otext(_font_bold, Vector2(stage.position.x + 27.0, stage_mid), "‹", 34,
		Color("#e6ecff"))
	_otext(_font_bold, Vector2(stage.end.x - 27.0, stage_mid), "›", 34,
		Color("#e6ecff"))


## One board, as it would actually look: its picture, its weather, its frame and
## two of its blocks wearing the face drawn for it.
func _draw_promo_board(stage: Rect2, id: String, t: float) -> void:
	var pic := _theme_art(id)
	var top := Cosmetics.theme_color(id, "top")
	if pic != null:
		var asz := Vector2(pic.get_width(), pic.get_height())
		var want: float = stage.size.x / stage.size.y
		var src := Rect2(Vector2.ZERO, asz)
		if asz.x / asz.y > want:
			src.size.x = asz.y * want
			src.position.x = (asz.x - src.size.x) * 0.5
		else:
			src.size.y = asz.x / want
			src.position.y = (asz.y - src.size.y) * 0.5
		_overlay.draw_texture_rect_region(pic, stage, src,
			Color(1, 1, 1, float(Cosmetics.theme_opt(id, "art_a"))))
	else:
		_overlay.draw_rect(stage, top, true)

	var mk := String(Cosmetics.theme_opt(id, "motion"))
	if mk != "":
		# `bound`, because there is no scissor here and the card's edge is six
		# pixels from the gutter of the title screen behind it.
		_overlay.draw_set_transform(stage.position, 0.0, Vector2.ONE)
		Cosmetics.draw_motion(_overlay, mk, stage.size, t,
			Cosmetics.theme_tint(id, "accent", PLAYER_ACCENT), true)
		_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# A playfield in miniature, translucent at the theme's own alpha, with its
	# ruling and a short stack in it. Same shape as the real one: taller than
	# wide, because that is what a board is.
	var ph: float = stage.size.y * 0.62
	var pw: float = ph * 0.52
	var pan := Rect2(stage.get_center().x - pw * 0.5,
		stage.get_center().y - ph * 0.5, pw, ph)
	_overlay.draw_rect(pan, Color(Cosmetics.theme_color(id, "panel"),
		float(Cosmetics.theme_opt(id, "panel_a"))), true)
	var grid := Color(Cosmetics.theme_color(id, "grid"),
		float(Cosmetics.theme(id)["grid_a"]))
	var step: float = pw / 4.0
	for i in range(1, 4):
		_overlay.draw_rect(Rect2(pan.position.x + step * i, pan.position.y,
			1.0, pan.size.y), grid, true)
	var rows := int(pan.size.y / step)
	for i in range(1, rows + 1):
		_overlay.draw_rect(Rect2(pan.position.x, pan.position.y + step * i,
			pan.size.x, 1.0), grid, true)

	# Five blocks in the face this board was drawn with, across two rows, so the
	# tier colours and the material are both on show.
	var face := Cosmetics.face_for_board(id)
	var stamps := ["AL", "ENT", "STR", "ING", "RE"]
	var tiers := [0, 4, 2, 5, 1]
	for i in 5:
		var col := i % 3
		var row := i / 3
		var br := Rect2(pan.position.x + step * float(col) + 3.0,
			pan.end.y - step * float(2 - row) + 3.0,
			step * (2.0 if i == 1 else 1.0) - 6.0, step - 6.0)
		if br.end.x > pan.end.x:
			br.size.x = pan.end.x - br.position.x - 3.0
		var ink := Cosmetics.draw_premium_face(_overlay, br,
			WWBoard.TIER_COLORS[tiers[i]], face, false)
		_text_fit_overlay(_font_bold, br.get_center(), stamps[i], 13,
			br.size.x - 5.0, ink, 8)

	# The frame, which on these boards is the lit neon edge.
	_overlay.draw_rect(pan, Cosmetics.theme_tint(id, "frame", PLAYER_ACCENT),
		false, 2.0)


## The one slide with no photograph behind it, which therefore has to be built
## out of something.
##
## A first pass drew ten faint rows with a thin bar across the middle, and the
## rows read as an empty list rather than as anything — the slide before it is a
## waterfall, and following that with a mostly-blank panel says the pack runs
## out of things to show. So this fills the stage: the thing being taken away,
## struck out at the size the boards are shown at, and underneath it the thing
## you are left with — one unbroken run.
func _draw_promo_no_ads(stage: Rect2, t: float) -> void:
	_overlay.draw_rect(stage, Color("#0b1020"), true)
	# A wash out of the middle, so the panel has a centre to hang the mark on
	# rather than being a flat rectangle.
	var mid := stage.get_center()
	for i in 6:
		var f := float(i) / 5.0
		_overlay.draw_circle(mid, stage.size.x * (0.16 + f * 0.46),
			Color("#1b2444", 0.30 * (1.0 - f)))

	var beat: float = 0.5 + 0.5 * sin(t * 1.5)
	var r: float = minf(stage.size.x, stage.size.y) * 0.24
	var mark := Vector2(mid.x, mid.y - stage.size.y * 0.10)
	var red := Color("#ff6b6b")

	# The circle-slash, breathing. Drawn rather than set as a character because
	# the fallback font has no glyph for it and a missing glyph on the one slide
	# that has no picture would be a blank panel.
	for i in 3:
		var f := float(i) / 2.0
		_overlay.draw_arc(mark, r * (1.0 + f * 0.10), 0.0, TAU, 64,
			Color(red, (0.30 - f * 0.09) * (0.55 + 0.45 * beat)), 2.0, true)
	_overlay.draw_arc(mark, r, 0.0, TAU, 72, Color(red, 0.95), 6.0, true)
	var d: float = r * 0.7071
	_overlay.draw_line(mark + Vector2(-d, -d), mark + Vector2(d, d),
		Color(red, 0.95), 6.0)
	_text_fit_overlay(_font_bold, mark, "ADS", int(r * 0.62), r * 1.15,
		Color(red, 0.80), 14)

	# And what is left: a run that runs. No gap in it, because the positive
	# half is the part worth selling — "uninterrupted" is the product, "you
	# lose thirty seconds" is just the complaint it answers.
	var bar := Rect2(stage.position.x + stage.size.x * 0.12,
		mid.y + stage.size.y * 0.24, stage.size.x * 0.76, 34.0)
	_overlay.draw_rect(bar, Color("#141b33"), true)
	_overlay.draw_rect(bar, Color("#64dfdf", 0.35), false, 1.0)
	var run: float = fmod(t * 0.22, 1.0)
	_overlay.draw_rect(Rect2(bar.position,
		Vector2(bar.size.x * run, bar.size.y)), Color("#64dfdf", 0.70), true)
	# The head of it, so the bar reads as filling rather than as a static
	# fraction somebody chose.
	_overlay.draw_rect(Rect2(bar.position.x + bar.size.x * run - 2.0,
		bar.position.y - 3.0, 3.0, bar.size.y + 6.0), Color("#b8f0ff", 0.9), true)
	_otext(_font, Vector2(bar.position.x + 46.0, bar.position.y - 20.0),
		"YOUR RUN", 11, Color("#64dfdf", 0.9))
	_otext(_font, Vector2(bar.get_center().x, bar.end.y + 24.0),
		"start to finish, nothing in the way", 12, Color("#7c88ad"))


func _draw_confirm(size: Vector2) -> void:
	if not _confirm_up():
		return
	_overlay.draw_rect(Rect2(-SHAKE_MARGIN, -SHAKE_MARGIN,
		size.x + SHAKE_MARGIN * 2.0, size.y + SHAKE_MARGIN * 2.0),
		Color(bg_top, 0.86), true)
	var r := _confirm_rect()
	_panel(r, Color("#111730"), Color("#ff6b6b", 0.75), 14.0, 3.0)
	var cx := r.get_center().x
	var lines := _confirm_lines()
	_otext(_font, Vector2(cx, r.position.y + 40.0), "HOLD ON", 14,
		Color("#ff6b6b", 0.85))
	_text_fit_overlay(_font_bold, Vector2(cx, r.position.y + 84.0),
		String(lines["title"]), 30, r.size.x - 50.0, Color("#e6ecff"), 17)
	_text_fit_overlay(_font, Vector2(cx, r.position.y + 122.0),
		String(lines["note"]), 16, r.size.x - 50.0, Color("#ffd166"), 11)
	for b: Dictionary in _confirm_buttons():
		_draw_menu_button(b)


## Bank whatever the open run owes before it is walked away from.
##
## Split out of `_do_leave_match` because leaving is not the only way a run gets
## abandoned — taking an invitation mid-daily is the other, and it must post the
## score for exactly the same reason. One function, so a third exit cannot be
## added that quietly forgets.
##
## `quiet` is passed straight through to `_end_daily`: the invite path is on its
## way into somebody else's match, and an ad break or a permission dialog
## arriving over the top of that is worse than not having it.
func _bank_open_run(quiet: bool) -> void:
	if mode == Mode.SURVIVAL:
		_bank_survival_time()
	elif mode == Mode.DAILY:
		_end_daily(true, quiet)


# ---------------------------------------------------------- an invite arriving
#
# The banner an invitation raises mid-run, and the two answers under it. Why it
# appears after iOS's own banner rather than instead of it — and why the game is
# never told an invitation arrived, only that one was accepted — is written out
# in `multiplayer_manager.gd`, which holds the invite this draws.
#
# Deliberately a banner and not a card. The rematch and leave cards are
# questions the game asked, so they own the screen; this one is an interruption
# from outside, arriving over a run the player is in the middle of. Taking the
# screen away from them to relay somebody else's message is the same rudeness as
# joining the match without asking, one step smaller.

## How tall the banner is, and how far in from the edges it sits.
const INVITE_BANNER_H := 92.0
const INVITE_BANNER_PAD := 14.0


## A name to put a banner up for with no Apple device behind it, so the layout
## can be looked at from Linux. Same purpose and same rules as `demo_emotes`:
## nothing in the game sets it, and the two buttons under it still go through
## `MultiplayerManager`, where they find no invitation and do nothing.
##
## Worth having rather than testing this on a phone only. `GKInvite` cannot be
## constructed off an Apple platform — the stub refuses — so without a way in
## from outside, the one screen in this game that arrives unannounced over a
## live board could never be looked at until it turned up in front of a player.
var demo_invite := ""


## Whether the banner is up. The invitation lives in `MultiplayerManager`, so
## this is a read rather than a flag of our own — there is no second copy to go
## stale when it expires on its own clock.
func _invite_banner_up() -> bool:
	return MultiplayerManager.invite_waiting() or demo_invite != ""


## Who is asking, and how much of the hold is left as a fraction. Both fall back
## to the demo so the drawing has one source rather than two branches.
func _invite_who() -> String:
	if demo_invite != "":
		return demo_invite
	return MultiplayerManager.invite_from


func _invite_fraction() -> float:
	if demo_invite != "":
		return 0.62
	return MultiplayerManager.invite_left() / MultiplayerManager.INVITE_HOLD


func _invite_banner_rect() -> Rect2:
	var size := get_viewport_rect().size
	var w: float = minf(660.0, size.x - GRID_MARGIN * 2.0)
	# Near the top, which is where a notification would have been and therefore
	# where somebody is already looking for one — but under the back button
	# rather than over it. At full width this banner spans the whole phone, and
	# parked at `safe_top` it covered the corner chevron completely: a button
	# still live underneath a panel that hides it, which is the one arrangement
	# worse than a button that does nothing.
	var y: float = _back_rect().end.y + INVITE_BANNER_PAD if portrait \
		else safe_top + INVITE_BANNER_PAD
	return Rect2(size.x * 0.5 - w * 0.5, y, w, INVITE_BANNER_H)


## Join on the left, dismiss on the right — the same seats the leave card uses,
## so the button under the thumb does not move between the two things that
## interrupt a run.
func _invite_banner_buttons() -> Array:
	if not _invite_banner_up():
		return []
	var r := _invite_banner_rect()
	var bw: float = 118.0
	var bh: float = 44.0
	var by: float = r.get_center().y - bh * 0.5
	return [
		{"rect": Rect2(r.end.x - bw * 2.0 - 20.0, by, bw, bh), "key": "",
			"label": "Join", "sub": "", "note": "", "rating": 0,
			"accent": PLAYER_ACCENT, "action": "invite_join"},
		{"rect": Rect2(r.end.x - bw - 10.0, by, bw, bh), "key": "",
			"label": "Not now", "sub": "", "note": "", "rating": 0,
			"accent": Color("#8d99bd"), "action": "invite_no"},
	]


func _draw_invite_banner(size: Vector2) -> void:
	if not _invite_banner_up():
		return
	var r := _invite_banner_rect()
	_panel(r, Color("#141d3c"), Color(PLAYER_ACCENT, 0.85), 12.0, 2.0)

	# Apple hands over a sender with no display name often enough to plan for —
	# a player who never set one — and "invited you" with a blank in front of it
	# reads as a bug rather than as a person. Stripped as well as tested for
	# empty, the way `Boards._view_row` handles the same field: a name that is
	# one space leaves the same gap as a name that is nothing.
	var who := _invite_who().strip_edges()
	var line := "%s invited you to a match" % who if who != "" \
		else "somebody invited you to a match"
	var text_w: float = r.size.x - 270.0
	_otext_left(_font, Vector2(r.position.x + 16.0, r.position.y + 28.0),
		"GAME CENTER", 11, Color(PLAYER_ACCENT, 0.8))
	_otext_left(_font_bold, Vector2(r.position.x + 16.0, r.position.y + 54.0),
		line, _fitted_size(_font_bold, line, 18, text_w, 12), Color("#e6ecff"))

	# The hold, as a bar rather than a number. It is not a countdown the player
	# is supposed to race — it is there so a banner that vanishes on its own is
	# visibly about to, rather than appearing to have been dismissed by a
	# mis-tap. See `INVITE_HOLD`.
	var bar := Rect2(r.position.x + 16.0, r.end.y - 12.0,
		(r.size.x - 32.0) * _invite_fraction(), 3.0)
	if bar.size.x > 0.0:
		_overlay.draw_rect(bar, Color(PLAYER_ACCENT, 0.45), true)

	for b: Dictionary in _invite_banner_buttons():
		_draw_menu_button(b)


## Whether an invitation can simply be taken without asking.
##
## True everywhere there is nothing to interrupt, which is every screen that is
## not a run in progress — and also a run that banks nothing, because a
## confirmation protecting a practice board is a confirmation that teaches
## people to tap through the one protecting a daily.
func _invite_is_free() -> bool:
	if phase != Phase.PLAY and phase != Phase.COUNTDOWN:
		return true
	return not _leave_costs()


func _on_invite_offered(_who: String) -> void:
	if _invite_is_free():
		_take_invite()
		return
	# Left for the banner to carry. Loud enough to notice over a board being
	# typed at, which is the whole difficulty with an interruption that is not
	# allowed to take the screen.
	Sfx.play("count", 1.4)
	Haptics.fire("tap")


## Take the invitation, banking whatever the abandoned run owes on the way.
func _take_invite() -> void:
	_bank_open_run(true)
	confirm_action = ""
	paused = false
	_hover_action = ""
	Link.leave()
	# `accept_invite` drops the Game Center match itself, so there is no window
	# where the old match is gone and the invite has not been acted on.
	MultiplayerManager.accept_invite()
	net_status = ""
	_lobby_search = 0.0
	# The lobby rather than the title: it is the screen that says what
	# matchmaking is doing, and joining an invite is matchmaking.
	phase = Phase.LOBBY
	Sfx.play("count", 1.2)


## Actually go, once the card has been answered or found unnecessary.
##
## The daily does not walk back to the title from here. It banks the run and
## opens its own summary, the same one the clock produces — leaving is an ending
## now, and an ending this game reports is an ending the player gets to see. It
## is also the only way the score they are being told about is a score they can
## check.
func _do_leave_match() -> void:
	paused = false
	_hover_action = ""
	# Charged and banked first, while there is still a run to charge for — and
	# through the one function both exits share, so the survival clock and the
	# daily's score cannot drift apart. It is also what puts the daily's summary
	# up, which is why the branch at the bottom has nothing left to do.
	_bank_open_run(false)
	Link.leave()
	# `Link` is the dead netfox transport, so on its own this walked back to
	# the title with the Game Center match still open: the opponent never
	# heard you go, and `net_active()` stayed true so the next match refused
	# to start.
	MultiplayerManager.leave_match()
	if mode == Mode.DAILY:
		return
	phase = Phase.TITLE
	Sfx.play("back")


# ------------------------------------------------------------------ the break
#
# An ad break, served by whatever network `Ads` is talking to.
#
# The game does not draw it. An interstitial is a native view the SDK throws
# over the whole app: full screen because it is not inside our window at all,
# with its own close button on its own schedule. Off a device the addon puts a
# full-screen mock in the same place, so the one thing there is never a reason
# to build here is a picture of an ad.
#
# It plays *at the end of the match*, before the summary. The earlier version
# ran it on the way out of the summary instead, on the reasoning that the
# scoreboard is the payoff and should not be covered — but from the player's
# side that is not what it reads as. You press Rematch, and the ad is the thing
# standing between you and the match you just asked for, so the break belongs to
# the match you are trying to start rather than the one that ended. Firing it as
# the match ends puts it where it actually belongs: the match is over, the break
# is the punctuation, and the summary and Rematch are on the far side of it.
#
# What is on screen is `ads.gd`'s business. What is left here is only when.

## Whether a match of this shape may be interrupted at all.
##
## Versus counts now. It used to be excluded outright, and the reason was sound
## but was about *when* rather than about versus: the rematch handshake is two
## packets between two people, and a peer who has already said yes sits on a
## "waiting for them" card until the second one lands, so a break between the
## whistle and the summary is dead air on somebody else's phone. Versus is also
## where most of this game is going to be played, which makes excluding it a
## decision to forgo most of the impressions.
##
## So the break moved rather than the rule: a versus match takes its break when
## the summary is *left*, by which point the rematch has been answered one way or
## the other and nobody is waiting on anybody. See `_end_match` and the title
## action, which are the two halves of that.
##
## Survival counts too, and it is the reason the cadence grew a second budget.
## It banks a run, it feeds the clock, and it is the one mode long enough that a
## break can land inside it rather than only after it — see `_lose_life`.
##
## The daily counts now too, and it is the one that had to be argued for rather
## than measured. It does not bank a match, which is what the old rule was really
## about — a break paid for out of a counter the mode never moved. So it pays the
## clock budget instead, the way survival does: `_finish_daily` hands over the
## seconds the run took before it asks for a break, and the break is charged for
## play that actually happened.
##
## The stronger argument is about where the daily sits. It is the mode with the
## most sessions and the fewest seconds in it — somebody who only plays the daily
## opens this game once a day for a minute and has, until now, never seen an
## advert at all. One break at the end of that, with the scoreboard behind it, is
## the whole of what that session is asked to pay, and the cadence in `profile.gd`
## still decides whether it is due: a daily run alone moves the clock by seventy-
## five seconds against a five-to-eight minute gap, so this is a break every few
## days rather than every day.
##
## Still never in a lesson or a training run: neither banks anything, neither
## moves either counter, and neither is play somebody chose to sit down for.
func _ad_allowed() -> bool:
	return mode == Mode.NORMAL or mode == Mode.SURVIVAL or mode == Mode.DAILY


## Whether the match that just ended should be followed by a break.
##
## `Ads.has_ad` is asked here, with everything else, rather than trusted to fail
## gracefully later. An ad takes seconds to fetch and networks have nothing to
## serve several times a day, so "the cadence says yes" and "there is an ad in
## hand" are different questions — and the counter must only be spent on the
## second, or a run of empty nights silently resets the cadence and the player
## goes hours without a break.
##
## `Reviews.asking` is the other veto, and it is about a collision rather than a
## cadence. Both of the moments that take a break — the end of a survival run and
## the end of a daily — are also moments that may spend a rating ask, and the
## rating sheet is the system's, arriving a second or two later on its own
## schedule. Without this the sheet lands on top of the advert. The break is
## dropped rather than delayed: the counter keeps its place, and the next run
## takes it.
func _break_due() -> bool:
	return _ad_allowed() and not Reviews.asking() \
		and Profile.ad_due() and Ads.has_ad()


# ------------------------------------------------------------------ the curtain
#
# An interstitial arrives as a native full-screen view with no warning and no
# animation of ours: one frame you are playing, the next you are looking at an
# advert. At the end of a match that is merely abrupt. In survival it lands
# mid-run, a second after a life is lost, and "the game vanished and something
# else opened" is indistinguishable from a crash — which is what it was reported
# as.
#
# So the game closes its own curtain first. It fades up over whatever is on
# screen, says what is happening and what will still be there afterwards, and
# only then is the break asked for. Coming back it fades off rather than cutting,
# for the same reason in reverse.
#
# The curtain is not only decoration, it is also the pause. Nothing underneath it
# ticks and nothing underneath it can be tapped — see `_ad_paused`, which the
# process loop and both input handlers read. Without that, the survival board
# would keep dealing blocks behind a screen the player cannot see through.

enum Curtain { NONE, CLOSING, HOLDING, WAITING, OPENING }

## Long enough to be read as deliberate, short enough not to be a toll charged on
## every break. The hold is what makes it read as an announcement rather than a
## glitch: a curtain that closes and instantly becomes an advert has not actually
## told anybody anything.
const CURTAIN_CLOSE := 0.7
const CURTAIN_HOLD := 0.6
const CURTAIN_OPEN := 0.5
## If the network never reports back, lift anyway. `Ads` has its own rescue timer
## and always emits `finished`, so this should be unreachable — but the failure it
## covers is a permanently opaque screen with a live game behind it, which is the
## worst thing on this list by a distance and costs three lines to rule out.
const CURTAIN_GIVE_UP := 90.0

var _curtain := Curtain.NONE
var _curtain_t := 0.0
## What is on the far side of the break, decided when the curtain starts closing.
## By the time it lifts the phase may have moved on, and a line promising a
## scoreboard that is no longer coming is worse than no line at all.
var _curtain_note := ""


## True while a break is being announced, shown, or cleared away.
func _ad_paused() -> bool:
	return _curtain != Curtain.NONE or Ads.showing()


## What to promise the player on the way out. Written as what they get back
## rather than as what is about to happen: the advert is the obvious part.
func _ad_note() -> String:
	if mode == Mode.SURVIVAL and phase == Phase.PLAY:
		return "your run picks up where it left off"
	if phase == Phase.OVER:
		return "your scoreboard is waiting behind this"
	return "back in a moment"


## Try to put one up. Called as the match ends, with the summary already built
## behind it, so there is nothing to hand back when it finishes — closing the ad
## reveals the scoreboard that was there all along. Called mid-run in survival
## too, where what is behind it is the run.
##
## The break is not shown from here any more; the curtain is started and shows it
## when it is fully closed. `_break_due` still answers first, so a break that was
## never going to happen does not get a curtain drawn for it.
func _try_ad_break() -> void:
	if not _break_due():
		return
	if _curtain != Curtain.NONE:
		return
	_curtain = Curtain.CLOSING
	_curtain_t = 0.0
	_curtain_note = _ad_note()


## Move the curtain along. Ticked from `_process` whether or not the rest of the
## frame is, because it is the thing that has to keep moving when nothing else
## does.
func _tick_curtain(delta: float) -> void:
	match _curtain:
		Curtain.CLOSING:
			_curtain_t += delta / CURTAIN_CLOSE
			if _curtain_t >= 1.0:
				_curtain_t = 0.0
				_curtain = Curtain.HOLDING
		Curtain.HOLDING:
			_curtain_t += delta / CURTAIN_HOLD
			if _curtain_t < 1.0:
				return
			_curtain_t = 0.0
			# Fully covered, so whatever the SDK does with the screen now happens
			# behind something rather than instead of something.
			if Ads.show():
				_curtain = Curtain.WAITING
				# Sound and music belong to whatever is on screen, and from here
				# that is no longer us.
				Music.stop()
			else:
				# Refused at the last moment. Nothing was shown, the counter keeps
				# its place, and the curtain lifts on the game it never left.
				_curtain = Curtain.OPENING
		Curtain.WAITING:
			_curtain_t += delta
			if _curtain_t >= CURTAIN_GIVE_UP:
				push_warning("Ads: the break never lifted the curtain — opening it anyway")
				_curtain_t = 0.0
				_curtain = Curtain.OPENING
		Curtain.OPENING:
			_curtain_t += delta / CURTAIN_OPEN
			if _curtain_t >= 1.0:
				_curtain_t = 0.0
				_curtain = Curtain.NONE
				_curtain_note = ""


## How much of the screen the curtain is covering, 0 to 1.
func _curtain_alpha() -> float:
	match _curtain:
		Curtain.CLOSING:
			return clampf(_curtain_t, 0.0, 1.0)
		Curtain.HOLDING, Curtain.WAITING:
			return 1.0
		Curtain.OPENING:
			return clampf(1.0 - _curtain_t, 0.0, 1.0)
	return 0.0


## The break is over. `shown` is false when the network refused at the last
## moment, and a break that never reached the player is not one they have had —
## so the counter keeps its place and the next match tries again.
func _on_ad_finished(shown: bool) -> void:
	if shown:
		Profile.clear_ad()
	# Whatever happened, the screen is ours again — and it is still covered, so
	# there is something to take away rather than a cut back to the game.
	if _curtain == Curtain.WAITING or _curtain == Curtain.HOLDING:
		_curtain = Curtain.OPENING
		_curtain_t = 0.0
	_music_key = ""
	_music_hold = 0.0
	_tick_music(0.0)


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

		# Each of these is a rule about damage, and `_strike` is what decides
		# whether damage means a block or means points. So all four survive a
		# solo run intact: COUNTER still pays for shooting something down before
		# it lands, COMBO still promises the next word is bigger, PERFECT is
		# still worth the whole hit twice. CLUTCH is the one that needs no
		# translation — a reprieve is a reprieve whether or not anyone is
		# shooting at you.
		match name:
			"COUNTER":
				# Literally back where it came from: one for one, so it can never
				# pay out more than was aimed at you in the first place.
				for i in intercepted:
					paid += _strike(attacker, defender, word, 0,
						DROP_DELAY + 0.25 + i * 0.12)
			"COMBO":
				attacker.tier_bonus = 1
			"PERFECT":
				paid += _strike(attacker, defender, word, out_tier, DROP_DELAY + 0.4)
			"CLUTCH":
				attacker.slowdown = CLUTCH_TIME

		# Flat, and announced on the banner itself rather than as a second
		# floating number — one thing arriving that says both what happened and
		# what it paid, instead of two things competing.
		var bonus := int(spec["bonus"])
		attacker.score += bonus
		paid += bonus
		_log("%s: %s — %s" % [attacker.label, name,
			String(spec["solo"] if solo_run() else spec["note"])], tint)
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
	# Stepped up past whatever is still sitting near the board, rather than
	# started in the same place as it.
	#
	# `_draw_score_pops` floats a pop upward on an ease-out, which is front
	# loaded — but "front loaded" still means a pop is within a few units of
	# where it started for the first tenth of a second, and two scoring events
	# that close together are routine rather than exotic. A strike and the salvo
	# it completed resolve in the same frame; a fast typist lands two words
	# inside a tenth of a second. Both used to be drawn at one height, over a
	# ±40 horizontal jitter that is narrower than the numbers are wide, and the
	# result was one unreadable smear of digits with two `note` lines through it.
	#
	# Found in a store preview, where it is on screen for most of the video —
	# but it is a thing that happens in ordinary play, to everybody, and the
	# preview only made it impossible to keep ignoring.
	var lift := 0.0
	for old: Dictionary in score_pops:
		if float(old["life"]) > POP_STACK_FRESH:
			lift += POP_STACK_STEP
	score_pops.append({
		"text": text,
		"note": note,
		"at": Vector2(player.board.position.x + bw * 0.5 + randf_range(-40.0, 40.0),
			BOARD_TOP + WWBoard.ROWS * WWBoard.CELL + 4.0
			- minf(lift, POP_STACK_MAX)),
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
## The stamps a salvo lands under, all minted before the first one falls.
##
## A salvo is ten or more blocks and they are single cells on purpose —
## individually trivial, collectively a mess. That only holds if they are a mess
## of *different* things. Branded the same they are not ten problems, they are
## one word typed once, which is the easiest thing on the board rather than the
## hardest.
##
## The cashing word is the first source, because a salvo should still read as
## having come from the word that earned it. But a word's answerable fragments
## run out fast — CAT offers about four — and past that the choice is a repeat
## or somebody else's word. Repeats are what this exists to stop, so once the
## word is spent the rest are minted from fresh common words.
##
## `used` is threaded through rather than relying on `defender.pending`, which
## the caller has not appended to yet: the whole flight is decided here, before
## a single block exists to be seen by the avoid check inside `_mint_stamp`.
func _salvo_stamps(word: String, count: int, defender: SideState) -> Array:
	var out: Array = []
	var used := {}
	for i in count:
		var s := _mint_stamp(word, STAMP_WANT, defender, used)
		# `_mint_stamp` refuses a used stamp while it has any other candidate, so
		# getting one back means the word is spent rather than unlucky. One
		# retry, then a different word — retrying the same exhausted pool is how
		# a loop like this turns into a stutter.
		if used.has(s):
			s = _mint_stamp(WordBank.random_common(), STAMP_WANT, defender, used)
		if used.has(s):
			s = _mint_stamp(WordBank.random_common(), STAMP_WANT, defender, used)
		used[s] = true
		out.append(s)
	return out


func _fire_salvo(attacker: SideState, defender: SideState, word: String, combo: int) -> void:
	var power := SALVO_BLOCKS + combo

	# Ten cells of damage is ten cells of damage. A salvo pays for all of them at
	# the same rate every other hit is paid at, which makes riding a chain to the
	# top of the ladder the single biggest thing you can do in a minute — as it
	# should be, since it costs nine clean words in a row. It is worth that
	# whether the cells rain on somebody or there is nobody to rain on.
	var rain := power * STRIKE_PAY
	if not solo_run():
		if net_active() and not _owned_here(defender):
			MultiplayerManager.send_event("salvo", {"word": word, "count": power})
			defender.flash = 1.0
		else:
			var stamps := _salvo_stamps(word, power, defender)
			for i in power:
				var p := Pending.new()
				p.from = _entity_of(attacker)
				p.tier = 0
				p.prefix = String(stamps[i])
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
	var bounty: int = Scoring.flat(Scoring.SALVO_BONUS) + rain
	attacker.score += bounty
	if attacker == player:
		_pop_score("SALVO +%s" % _commas(bounty), "", bounty)
		score_kick = 1.0
	attacker.chain = 0
	attacker.chain_fill = 0.0
	attacker.chain_timer = 0.0

	_log("%s: %s — SALVO (%d %s)" % [attacker.label, word.to_upper(), power,
		"blocks paid" if solo_run() else "blocks"], Color("#ffd166"))

	var mine := attacker == player
	Sfx.play("salvo", 1.0, 0.0 if mine else -8.0)
	if mine:
		Haptics.fire("salvo")
		_say("SALVO — %s, chain spent" % [("+%s" % _commas(bounty)) if solo_run()
			else ("%d blocks away, +%s" % [power, _commas(bounty)])], Color("#ffd166"))
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
		var how := "%s %dx%d" % ["banked" if solo_run() else "sent",
			TIERS[out_tier]["w"], TIERS[out_tier]["h"]]
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
		_say("%s %s" % ["banked" if solo_run() else "sent", _tier_name(out_tier)],
			PLAYER_ACCENT)
	else:
		_say("absorbed", Color("#8892b0"))


## What a word adds to the chain meter.
func _chain_gain(word: String) -> float:
	return 1.0 + CHAIN_GAIN_PER_CHAR * float(maxi(0, word.length() - MIN_WORD_LEN))


## The tier a word earns on its own length, ignoring everything else.
func _length_tier(word: String) -> int:
	var n := word.length()
	var t := 0
	for at in LENGTH_TIER_AT:
		if n >= int(at):
			t += 1
	return t


## What a word throws before combos, owed tiers and focus are added: the better
## of the two ladders, plus half of the other one.
##
## It used to be the bigger of the two and nothing else, to stop a long word
## inside a long run stacking into an instant 4x3. That guard worked and it cost
## the thing it was guarding. The chain ladder overtakes the length one by the
## third word, so from chain 3 onwards `maxi` returned the chain's tier for every
## word — and CAT and ONOMATOPOEIA sent the identical block. Length only ever
## mattered from a standing start, which is the one moment nobody has a long word
## ready.
##
## Half, rounded down, so the two still do not simply add: a good word inside a
## good run is worth more than either alone and less than both, and reaching the
## top needs a twelve-letter answer *and* a five-word run rather than one of them
## twice.
##
## Named rather than left inline because it is the whole of what "how hard did
## that hit" means, and it was previously three lines in the middle of `_attack`
## that nothing could ask a question of.
func _base_tier(chain: int, word: String) -> int:
	var chain_t := _chain_tier(chain)
	var len_t := _length_tier(word)
	return maxi(chain_t, len_t) + mini(chain_t, len_t) / 2


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
func _mint_stamp(word: String, want: int, defender: SideState,
		also_avoid: Dictionary = {}) -> String:
	var avoid := {}
	for s: String in defender.board.prefixes():
		avoid[s] = true
	for p: Pending in defender.pending:
		avoid[p.prefix] = true
	for s: String in recent_stamps:
		avoid[s] = true
	# Whatever the caller is part-way through handing out and has not attached to
	# anything yet. A salvo mints its whole flight before the first block lands,
	# so without this the run is invisible to the check above until it is over.
	for s: String in also_avoid:
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
	# The curtain moves whatever else is or is not happening — it is the one thing
	# on screen while everything under it is stopped, so it cannot be inside the
	# part that stops.
	if _curtain != Curtain.NONE:
		_tick_curtain(delta)

	# A break stops the run underneath it.
	#
	# Until survival there was no such thing as an ad over a live match — every
	# break landed on a summary, where there was nothing left to tick. Survival
	# takes one when a life is lost, mid-run, and without this the clock would
	# keep running and the pressure would keep dealing for the whole thirty
	# seconds of it: you would come back from an advert to a board you had no
	# hand in burying, having also been charged the time on your own record.
	#
	# The curtain counts, not just the advert: the second and a bit it spends
	# closing and opening is time the player cannot see the board through either.
	if _ad_paused() and phase == Phase.PLAY:
		_tick_music(delta)
		queue_redraw()
		_overlay.queue_redraw()
		return

	# Measured against the wall clock, not `delta` — `delta` is the thing being
	# slowed, so a freeze timed with it would never end.
	if Time.get_ticks_msec() < _hitstop_until:
		Engine.time_scale = HITSTOP_SCALE
	elif Engine.time_scale != 1.0:
		Engine.time_scale = 1.0

	_tick_emotes(delta)

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
			# A brand new player goes straight into the lesson rather than being
			# left to find it. The rule this game turns on — your endings become
			# their beginnings — reads as nonsense written down and as obvious the
			# first time it happens to you, so the tutorial is not optional
			# content, it is the game explaining itself.
			#
			# Offered once and only once. It can be left at any point by the back
			# chevron, and backing out is an answer: re-offering on every launch
			# would be a screen the player cannot get out of. After that the title
			# plate's own pulse is the reminder, which is a door they choose.
			if not bool(Profile.pref("taught")) \
					and not bool(Profile.pref("tutorial_offered")):
				Profile.set_pref("tutorial_offered", true)
				start_match("Rookie", 0, [], Mode.TUTORIAL)
			else:
				phase = Phase.TITLE
				# And only then the pitch, which is why it is in this branch and
				# not the one above. A brand new player goes to the lesson, and
				# selling a cosmetic pack to somebody who has not yet been told
				# what the game is is both rude and useless. They will be owed
				# it the next time they reach the title, which is when it makes
				# sense to them.
				_raise_promo()

	if phase == Phase.OVER:
		over_age += delta
	# The search clock. Ticked wherever the player is rather than only on the
	# lobby, because a search survives walking back to the title — the plate
	# there reads `net_status` and would otherwise be counting from a number
	# that stopped moving the moment the screen changed.
	if _versus_busy():
		_lobby_search += delta
	elif _lobby_search != 0.0:
		_lobby_search = 0.0
	_tick_challenges(delta)
	_tick_scroll()
	_tick_promo(delta)

	# The playfields have nothing to say on the front-of-house screens.
	var showing_boards := phase != Phase.SPLASH and phase != Phase.TITLE \
		and phase != Phase.LOBBY and phase != Phase.MASTERY \
		and phase != Phase.SOLO and phase != Phase.SETTINGS \
		and phase != Phase.PRACTICE and phase != Phase.COSMETICS
	for s: SideState in sides:
		# There is no rival in a lesson or a practice run, so its board is not
		# drawn at all — an empty playfield sitting there reads as an opponent
		# who is somehow doing nothing.
		# Portrait hides everybody else's playfield because a phone has room for
		# exactly one and it had better be yours — the rivals become cards under
		# the clock instead. A tablet is portrait too and has room for both, so
		# it is excused: `_layout_tablet_boards` has already put theirs down the
		# right-hand side, and this is the line that was leaving that space
		# occupied by a board with `visible` still false.
		s.board.visible = showing_boards and s.in_match \
			and (mode == Mode.NORMAL or s.slot == 0) \
			and (not portrait or tablet or s.slot == 0)
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
		# Only once there is a word to have answered it. Before that the prompt
		# is on the clock in `_draw_first_word_prompt` instead.
		if player.words_played > 0 and _first_word_fade > 0.0:
			_first_word_fade = maxf(0.0, _first_word_fade - delta)
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
			var fit: bool = side.board.add_garbage(p.prefix, p.tier, spec["w"], spec["h"])
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
	elif mode == Mode.DAILY:
		# Its own ramp, an order of magnitude tighter than a match's. A match
		# has an opponent supplying most of the pressure and can afford to open
		# at twenty-two seconds a block; a solo minute cannot afford to open at
		# anything, and the whole run would be over before the standard ramp had
		# taken its third step.
		pressure_interval = maxf(DAILY_PRESSURE_MIN,
			pressure_interval - DAILY_PRESSURE_STEP)
		pressure_timer = pressure_interval
	elif mode == Mode.SURVIVAL:
		# Gentler per step and a lower floor than the daily. See the constants:
		# this ramp is tuned against a run of minutes rather than of one minute,
		# and it has to end somewhere the best players actually drown.
		pressure_interval = maxf(SURVIVAL_PRESSURE_MIN,
			pressure_interval - SURVIVAL_PRESSURE_STEP)
		pressure_timer = pressure_interval
	else:
		pressure_interval = maxf(PRESSURE_MIN, pressure_interval - PRESSURE_STEP)
		pressure_timer = pressure_interval

	# Both peers run the clock so both HUDs agree, but only one of them decides
	# when it actually fires — otherwise the two boards drift apart.
	#
	# That used to be the host. Game Center has no host, and `Link.is_host` is
	# now false on both devices, so this read `not false` at both ends and both
	# returned: ambient pressure stopped firing at all in a versus match, and the
	# only symptom was a game that felt strangely easy. `is_first` is the
	# replacement — both ends sort the two player ids and reach the same answer.
	if net_active() and not MultiplayerManager.is_first():
		return
	var source := WordBank.random_common()
	if net_active():
		MultiplayerManager.send_event("pressure", {"word": source})
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
		# In a match the ambient block is always the smallest one there is — it is
		# a metronome under a fight somebody else is supplying. In the daily it is
		# the entire fight, so it is the one thing that has to escalate.
		if mode == Mode.DAILY:
			p.tier = _daily_tier()
		elif mode == Mode.SURVIVAL:
			p.tier = _survival_tier()
		else:
			p.tier = 0
		p.prefix = _mint_stamp(source, STAMP_WANT, side)
		p.cells = _cells(p.tier)
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


# ------------------------------------------------------------------- the lesson
#
# Nothing here advances on a timer. Every step ends because the player did the
# thing, so nobody is ever carried past a rule they have not got yet — and being
# slow costs a first-time player nothing.

## How many words the NEVER STOP TYPING step wants to see.
##
## Three, counted from wherever the player's total stood when the step arrived —
## which is what `_lesson_mark` is for. Any three words: they do not have to
## answer anything, they do not have to be fast, and there is no window.
##
## That is the whole difference between this step and the KEEP FIRING step it
## replaced. That one asked for a chain, which is three words inside the window
## each one buys — about two and a half seconds apiece — and a first-time player
## who has typed four words in their life cannot reliably do it. Players stopped
## there, and stopping there costs the rest of the tutorial to teach a rule the
## game teaches by itself within one real match.
const LESSON_KEEP_WORDS := 3
## How much longer the chain window is held open during the lesson.
##
## Only during the lesson. The window is the game's core rhythm and this is not
## the place to teach it slack — but the step before a first-time player has
## typed a dozen words in their life is not the place to enforce it either, and
## a window they can actually hit is what makes the rule visible at all.
const LESSON_CHAIN_GRACE := 2.0

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

	_lesson_mark = player.words_played

	match String(step["id"]):
		"answer":
			player.board.reset()
			# Branded with the tail of the word they just played, rather than
			# with an example. This is the one rule the game turns on and it is
			# the one that reads as nonsense written down, so it is never
			# written down — it is dealt onto the board with their own letters
			# on it, one step after they typed them.
			#
			# It used to have a step of its own, YOUR ENDING IS THEIR BEGINNING,
			# which said the rule and then waited a beat with nothing to do.
			# Folded into this one, the block that demonstrates the rule is the
			# same block they have to answer, so reading it and using it are the
			# same action.
			var tail := _lesson_word.substr(maxi(0, _lesson_word.length() - 3))
			player.board.add_garbage(tail if tail != "" else "ship", 2, 2, 2)
		"always":
			# A clean board. This step is about the habit rather than about
			# anything on the screen, and leaving rubble on it would make it
			# look like another answering exercise.
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
		"answer":
			return player.board.blocks.is_empty()
		"danger":
			return player.board.stack_top() >= WWBoard.ROWS - 3
		"always":
			# Words, not a chain and not a clock. The habit being taught is
			# "keep typing", and the moment it is checked against a window the
			# step stops being about the habit and starts being about speed —
			# which is what the KEEP FIRING step was, and what players stopped
			# on. Three words at any pace, answering anything or nothing.
			return player.words_played - _lesson_mark >= LESSON_KEEP_WORDS
		"done":
			return false     # ends on the key, not on a condition
	return false


## The line under the lesson body.
##
## Fixed copy for every step now. It used to compute the chain step's target,
## which moved as that step was waited out — but the step it was written for is
## gone, and a counter is the one thing the remaining steps do not need: every
## one of them ends on something the player can see happen on the board.
func _lesson_hint(step: Dictionary) -> String:
	return String(step.get("hint", ""))


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
## What firing means, wherever it was pressed from.
##
## The keyboard checked whether a lesson was waiting to be advanced and the
## on-screen FIRE key did not — it went straight to `_submit_player`. So on a
## phone, every lesson that ends with "press SPACE to continue" could not be
## continued at all: the only fire control the device has submitted an empty word
## and did nothing. The tutorial was unfinishable on the platform the game ships
## to, and had been for as long as there has been a touch keyboard.
##
## One decision in one place now, so the two ways of firing cannot drift again.
func _fire_pressed() -> void:
	if paused:
		return
	if mode == Mode.TUTORIAL and typed.is_empty() and (lesson_done
			or String(Tutorial.step(lesson).get("id", "")) == "done"):
		# The same control that fires a word. A lesson that needed its own button
		# would be teaching the button as well as the game.
		_lesson_next()
		return
	_submit_player()


## Back to step one, without leaving the tutorial.
##
## A fresh `start_match` rather than setting `lesson` to zero, because the steps
## build boards and the first one assumes an empty playfield — rewinding the
## counter over the pile the last step dealt would open the tutorial on a screen
## the tutorial never produces.
func _restart_lesson() -> void:
	_lesson_restart = Rect2()
	Sfx.play("count", 1.2)
	start_match("Rookie", 0, [], Mode.TUTORIAL)


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
	_end_daily(false, false)


## True while the summary is reporting a run that was given up rather than
## played out. Read by the headline and by the sound the summary arrives under —
## a walkout is not a loss and is certainly not "TIME", and calling it either
## would be the screen lying about what just happened.
var daily_quit := false


## The daily, banked and closed, whichever of the three ways it ended.
##
## `quit` is a run walked out of — the pause menu, or the app going away — and it
## is the reason this function exists at all. Until it did, the only path that
## banked a daily was the clock running out, so quitting at forty seconds left
## `daily_done` false and the same board could be played again for a better
## score. The docstring above claimed otherwise for months. It is true now
## because every exit routes through here.
##
## `quiet` is the app suspending under us, where there is a run to bank and no
## screen to report it on. It skips the two things that need somebody looking:
## the permission dialog, which iOS only ever offers once and would spend on a
## backgrounded app, and the ad break, which would be an interstitial thrown at
## a player who has already put the phone in their pocket. The score is banked
## and sent exactly as it would have been; only the theatre is dropped.
func _end_daily(quit: bool, quiet: bool) -> void:
	daily_quit = quit
	phase = Phase.OVER
	over_age = 0.0
	typed = ""
	_hover_action = ""
	paused = false
	_clear_hitstop()
	tracers.clear()
	# There is nobody to beat, so this is not "did you win" — it is "did you last
	# the minute". Everything downstream reads it: the tint, the confetti, the
	# music the summary comes up under. A run that burned all three lives with
	# twenty seconds still on the clock used to get the victory fanfare.
	#
	# A walkout is never survival, however many lives were still in hand. The
	# whole point of banking it is that leaving is an ending, and an ending that
	# arrives under the victory fanfare is an invitation to do it again.
	var survived: bool = player.lives > 0 and not quit
	winner = "YOU" if survived else ""
	Profile.record_daily(daily_key(), player.score, int(round(_wpm())),
		player.words_played, player.best_chain)
	# And into the week. A daily is a run like any other for mission purposes —
	# the words, the salvos and the chain all count — plus the one thing only it
	# can report.
	_bank_week({
		"words": player.words_played, "salvos": player.salvos,
		"multi_clears": int(player.power_tally.get("COMBO", 0)),
		"chain": player.best_chain, "combo": player.best_combo,
		"wpm": _wpm(), "score": player.score,
		"longest": player.longest_word,
	}, "dailies")
	# After the run is banked, never before: the local board is the one the
	# summary is about to draw, and it must not be waiting on Apple to do it.
	# `submit_daily` is a no-op off an Apple device and holds the score when
	# signed out, so there is nothing to check here.
	Boards.submit_daily(player.score)
	# And ask for the page the summary now draws, rather than only the one-line
	# rank it used to. `submit_daily` is still in flight at this point, so this
	# first page can come back without today's run on it — `Boards` re-asks when
	# the submission lands, and the summary repaints from whatever is in hand.
	Boards.open_view(Boards.DAILY_ID, Boards.GLOBAL, Boards.TODAY)
	earned = {}
	if not quiet:
		Sfx.play("win" if survived else "lose")
		Haptics.fire("win" if survived else "life")
	WordBank.free_run()
	# The first moment a reminder has anything true to say. The player has now
	# seen the board, knows there is one a day, and — after this run is banked —
	# may have a streak worth defending. Asked here rather than at launch because
	# iOS offers the permission dialog once per install and never again, and a
	# dialog put up before any of that is a dialog about nothing. `offer_after_daily`
	# is a no-op on every call after the first.
	var asked_to_notify: bool = false if quiet else Notify.offer_after_daily()
	Notify.refresh()
	# Finishing today's board with a streak going is one of the three good moments
	# in this game. See `review.gd` for why the bar is this high.
	if survived and Profile.daily_streak(daily_key()) >= 3:
		Reviews.maybe_ask("a %d-day daily streak" % Profile.daily_streak(daily_key()))

	# What the run cost, handed over before the break that may follow it. The
	# daily banks no match, so the count budget never moves for it and the clock
	# budget is the only one it can pay into — see `_ad_allowed`. `match_time`
	# rather than `DAILY_SECONDS`, because a run that topped out at forty seconds
	# is forty seconds of play and should be billed as such.
	Profile.note_time_for_ads(match_time)
	# Last, and after the rating ask above: `_break_due` stands the break down
	# when an ask is in flight, which it cannot know about until the ask has been
	# made. The summary is already built underneath — the break covers it and
	# uncovers it, and `_ad_note` promises exactly that on the curtain.
	#
	# Stood down outright on the one run that asks for notification permission.
	# That is the first daily somebody ever finishes, it is the only chance iOS
	# will ever give us to ask, and an advert arriving over the top of the dialog
	# would cost the answer as well as the frame. The counter keeps its place and
	# the next run takes the break.
	#
	# And never on a suspend. The app is on its way to the background; an
	# interstitial fired at it either arrives over the home screen or is waiting
	# on top of the summary whenever the player comes back, neither of which is
	# a break in anything.
	if not asked_to_notify and not quiet:
		_try_ad_break()


## Hand the ad budget whatever this run has played since it was last asked.
##
## A survival run is a single match that can outlast a dozen ordinary ones, so
## charging it at the end would let somebody play for half an hour and be billed
## as though they had played once. It pays as it goes instead, a life at a time,
## with `survival_banked` marking how far up the clock the meter has been read.
func _bank_survival_time() -> void:
	var owed := match_time - survival_banked
	if owed <= 0.0:
		return
	survival_banked = match_time
	Profile.note_time_for_ads(owed)


## All three lives are gone, which is the only way a survival run ends.
##
## There is no winning it, so `winner` is not about the run — it is about the
## record. Beating your own best is the thing worth a fanfare here, and it is the
## only thing on this screen a player can actually have done better than last
## time. A run that took neither record gets the summary without the confetti,
## which is the honest report of a middling run.
func _finish_survival() -> void:
	phase = Phase.OVER
	over_age = 0.0
	typed = ""
	_hover_action = ""
	_clear_hitstop()
	tracers.clear()

	var was_xp := Profile.xp_total()
	var was_level := Profile.level()
	var was_unlocked := Profile.unlocked_set()

	# Short runs are not runs. Below the floor nothing is banked and nothing is
	# claimed — otherwise starting and immediately topping out is both a way to
	# farm XP and a way to put a ten-second entry on your own record.
	survival_took = {}
	if match_time >= SURVIVAL_MIN_RUN:
		survival_took = Profile.record_survival({
			"seconds": match_time,
			"score": player.score,
			"wpm": _wpm(),
			"words": player.words_played,
			"chars": chars_typed,
			"salvos": player.salvos,
			# Same derivation as a match's: COMBO fires on exactly "three or
			# more broken by one word", so it already is the multi-clear count.
			"multi_clears": int(player.power_tally.get("COMBO", 0)),
			"chain": player.best_chain,
			"combo": player.best_combo,
			"longest": player.longest_word,
			"powers": player.power_tally,
		})
		_bank_week({
			"words": player.words_played, "salvos": player.salvos,
			"multi_clears": int(player.power_tally.get("COMBO", 0)),
			"chain": player.best_chain, "combo": player.best_combo,
			"wpm": _wpm(), "score": player.score,
			"longest": player.longest_word,
			# The one metric only survival can report.
			"seconds": match_time,
		}, "survivals")
	earned = _earned_since(was_xp, was_level, was_unlocked)
	# Inside the floor check's shadow on purpose: `survival_took` is empty for a
	# run too short to bank, and a ten-second death has no business on a global
	# board either. Held and sent later if Game Center is not there yet.
	if not survival_took.is_empty():
		Boards.submit_survival(player.score)
	var beat: bool = bool(survival_took.get("time", false)) \
		or bool(survival_took.get("score", false))
	winner = "YOU" if beat else ""
	Sfx.play("win" if beat else "lose")
	Haptics.fire("win" if beat else "life")
	# A record that just fell is the best moment this mode has to offer, and
	# every survival run otherwise ends in death — so this is the only version
	# of "something good happened" survival can produce. All that is decided
	# here is that it was a high point; the budget and the how-often live in
	# `review.gd`.
	if beat:
		Reviews.maybe_ask("a survival record")

	# Whatever the last life cost, before the break that follows it is decided:
	# the seconds a player has just spent are the ones that should be paying for
	# the ad they are about to see.
	_bank_survival_time()
	_try_ad_break()


func _finish_lesson() -> void:
	Sfx.play("win")
	_say("lesson complete", Color("#ffd166"))
	# The title, not practice. Practice was where the lesson used to be started
	# from, so going back there was going back where you came from — but a first
	# launch opens the lesson straight from the splash, and dropping a brand new
	# player into a submenu they have never seen is the worst possible first view
	# of the game. Everybody lands on the front door.
	phase = Phase.TITLE
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
	if solo_run():
		side.lives -= 1
		side.chain = 0
		side.chain_fill = 0.0
		side.chain_timer = 0.0
		side.pending.clear()
		side.in_danger = false
		# Taken apart rather than blinked out, the same as a match. `reset()`
		# left a board's worth of blocks simply ceasing to exist, which on a
		# sixty-second run is the single most expensive moment in it going by
		# unremarked.
		side.board.detonate()
		shake = maxf(shake, 0.7)
		side.respite = RESPITE
		side.life_flash = 1.0
		Sfx.play("lose")
		Haptics.fire("life")
		if side.lives <= 0:
			if mode == Mode.SURVIVAL:
				_finish_survival()
			else:
				_finish_daily()
		elif side == player:
			_say("topped out — %d %s left" % [side.lives,
				"life" if side.lives == 1 else "lives"], Color("#ff6b6b"))
			# The one moment in a survival run where a break is not an
			# interruption. The board has just come apart, the player is holding
			# nothing, and `RESPITE` is already a pause the mode built in — so an
			# ad here lands in a gap that exists anyway.
			#
			# Never on the last life: that one goes straight to the summary, and
			# the summary takes its own break a second later. Two in a row is how
			# a game gets uninstalled.
			if mode == Mode.SURVIVAL:
				_bank_survival_time()
				_try_ad_break()
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
			MultiplayerManager.send_event("topped_out", {})
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


## Which side actually won, as an object rather than as the label `winner` holds.
##
## Decided the same way `_draw_scoreboard` decides which row to put the winner's
## stripe on, and deliberately so: the row that is marked as having won and the
## row that gets paid for winning have to be the same row, and two pieces of
## code answering that question separately is how they stop being.
##
## Null is a real answer. `_end_match` can set `winner` to the literal "CPU"
## when a match ends with nobody standing — a simultaneous topout — and no side
## is called that. Nobody is paid in that case, which is what happened before
## any of this existed, so it degrades to the old behaviour rather than to a
## crash.
func _champion() -> SideState:
	for s: SideState in sides:
		if not s.in_match:
			continue
		if (s == player) if winner == "YOU" else (s.label == winner):
			return s
	return null


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
	#
	# Paid to whoever won, which is newer than it sounds. It used to be gated on
	# `winner == "YOU"`, so the bonus existed only for the player and every other
	# board on the scoreboard was quoted without one. That is not a scoreboard —
	# it is two different scoring systems printed in one table, and it is why a
	# player could lose and still be top of it. Measured before it was changed:
	# the loser finished ahead on points in six of eighteen losses.
	#
	# The winning side is found the same way `_draw_scoreboard` decides which row
	# to mark, so the row with the winner's stripe on it is always the row that
	# got paid.
	win_spoils = 0
	var champion := _champion()
	if mode == Mode.NORMAL and champion != null and champion.alive:
		var lives_left: int = maxi(0, champion.lives)
		var spoils: int = Scoring.flat(
			Scoring.WIN_BONUS + lives_left * Scoring.LIFE_BONUS
			+ champion.dealt * Scoring.WIN_DAMAGE_STEP)
		champion.score += spoils
		if champion == player:
			win_spoils = spoils
			_pop_score("+%s" % _commas(spoils), "VICTORY", spoils)
			score_kick = 1.0
		_log("%s wins — +%s (%d %s left, %d cells dealt)" % [
			champion.label if champion != player else "you", _commas(spoils),
			lives_left, "life" if lives_left == 1 else "lives", champion.dealt],
			Color("#ffd166"))

	# The numbers this device is the authority on, sent once the bonus above has
	# been applied to them.
	#
	# Live state travels at `NET_STATE_HZ`, which is a sampling rate and not a
	# guarantee: the last packet before the whistle can be most of a frame-time
	# old, so the far end's copy of a score is behind by whatever was earned in
	# that window. Live that is invisible and correct enough — a mirrored score
	# ticking a sixteenth of a second late is not a thing anybody can see. On the
	# scoreboard it is a different number next to somebody's name, on two phones,
	# being compared by two people sitting next to each other.
	#
	# So the end of a match stops being sampled and becomes a statement. Each end
	# sends its own finished row and the other assigns it verbatim — see
	# `_on_net_final`. Nothing is recomputed from it, which is the point: the
	# bonus is already in the number, so there is no second opinion to disagree
	# with.
	if net_active():
		MultiplayerManager.send_event("final", _final_of(player))
	Sfx.play("win" if winner == "YOU" else "lose")
	Haptics.fire("win" if winner == "YOU" else "lose")
	_log("%s wins" % winner, Color("#ffd166"))
	if mode == Mode.NORMAL:
		_record_mastery()
	# Last, and after the record: `_record_mastery` is what moves the counter, so
	# asking before it would always be a match behind. The summary is already
	# built underneath — the break covers it and uncovers it.
	#
	# Not in versus, where it waits for the summary to be left instead. An ad
	# here would sit between two people mid-rematch, and the one who has already
	# said yes cannot see what the delay is.
	if not net_active():
		_try_ad_break()


## Fold the finished match into the lifetime record, and keep what it earned so
## the end screen can show it. Done here rather than as the match runs, so a
## match abandoned halfway banks nothing — the level has to mean matches played
## through, or it means nothing.
func _record_mastery() -> void:
	# Counted alongside the record, so it moves for exactly the matches that
	# count as matches — a tutorial or a practice run is not an ad break.
	#
	# Both budgets, because a break is due when either is spent and a match that
	# only moved one of them would be half free. In practice a match trips the
	# count long before four of them add up to the clock, which is the point: the
	# clock is there for survival, where the count barely moves at all.
	Profile.note_match_for_ads()
	Profile.note_time_for_ads(match_time)
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
	_bank_week({
		"won": winner == "YOU",
		"flawless": winner == "YOU" and player.lives >= LIVES,
		"words": player.words_played, "salvos": player.salvos,
		"multi_clears": int(player.power_tally.get("COMBO", 0)),
		"chain": player.best_chain, "combo": player.best_combo,
		"wpm": _wpm(), "score": player.score,
		"longest": player.longest_word,
	}, "matches")

	# Measured after the week is banked, so mission XP lands in the same "you
	# earned this" readout as everything else the run paid for. Before it, the
	# level bar on the summary would animate to a number three hundred XP short
	# of where the profile actually is, and the missing chunk would appear out
	# of nowhere the next time a screen was opened.
	earned = _earned_since(was_xp, was_level, was_unlocked)

	# The best moment the game has: beating another person. Rare enough at this
	# population to be worth one of three yearly slots on its own, and the one
	# result nobody can put down to an easy bot.
	#
	# Only a real opponent, and only a win. A CPU match is not the same feeling
	# and there are unlimited numbers of them; a loss is not a moment to ask
	# anybody anything.
	if winner == "YOU" and net_active() and difficulty == "Versus":
		Reviews.maybe_ask("beating a person in versus")


## What banking a run just bought, for the summary's mastery strip.
##
## Shared by matches and survival runs, which earn differently and report
## identically: the level is a pure function of the record either way, so "what
## changed" is the same three questions whatever moved it. The fanfare is here
## rather than at the call sites for the same reason — a level gained in survival
## should sound like a level gained anywhere else.
func _earned_since(was_xp: int, was_level: int, was_unlocked: Dictionary) -> Dictionary:
	var fresh: Array = []
	var now := Profile.unlocked_set()
	for slot: String in Profile.SLOTS:
		for id in now[slot]:
			if not (was_unlocked[slot] as Array).has(id):
				fresh.append("%s: %s" % [String(Profile.SLOT_NAMES[slot]),
					String(Profile.entry(slot, String(id))["name"]).to_upper()])
	if not fresh.is_empty() or Profile.level() > was_level:
		Sfx.play("salvo", 1.15)
		Haptics.fire("level")
	return {
		"xp": Profile.xp_total() - was_xp,
		"from": was_level,
		"to": Profile.level(),
		"new": fresh,
	}


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

## The painted boards' backdrop: the picture, the wash that keeps type readable
## on top of it, and whatever that theme has moving.
##
## Does nothing at all for the five wash themes, which is why this sits behind a
## single null check rather than behind a "premium?" question — the wash themes
## are not a lesser case of this, they simply never brought a picture.
##
## ## Why the crop is done by region rather than by stretching
##
## The art is drawn for a phone held upright. Stretching it to fill a landscape
## iPad would make a waterfall three times as wide as it is tall, so a centre
## crop matching the screen's own aspect is taken out of the texture instead and
## drawn at full size. A tablet in landscape sees a band through the middle of
## the picture; a phone sees very nearly all of it. Neither sees it distorted.
##
## ## Why the dim is heaviest at the ends
##
## The clock, the pressure warning and the INCOMING/SENT labels sit in the top
## strip with nothing behind them, and a white number on a sunlit waterfall is
## a white number nobody can read. The middle — where the board is, and where
## the board brings its own translucent panel — keeps its brightness, because
## that is the part somebody paid to look at.
func _draw_board_art(size: Vector2, m: float) -> void:
	if _art == null:
		return
	var full := Rect2(-m, -m, size.x + m * 2.0, size.y + m * 2.0)
	var art := Vector2(_art.get_width(), _art.get_height())
	var want: float = full.size.x / full.size.y
	var have: float = art.x / art.y
	var src := Rect2(Vector2.ZERO, art)
	if have > want:
		src.size.x = art.y * want
		src.position.x = (art.x - src.size.x) * 0.5
	else:
		src.size.y = art.x / want
		src.position.y = (art.y - src.size.y) * 0.5
	draw_texture_rect_region(_art, full, src, Color(1, 1, 1, _art_a))

	if _art_dim > 0.0:
		draw_rect(full, Color(bg_top, _art_dim * 0.45), true)
		# The two ramps are not scaled by `art_dim`, and that is deliberate.
		#
		# `art_dim` is an art decision — how much of this particular picture the
		# board wants to give up. Legibility is not: the clock, the pressure
		# warning and the INCOMING/SENT labels sit on bare picture in the top
		# strip, and the word readout sits on it just above the keys. Those have
		# to be readable on all eight boards, including the two whose art is a
		# sunlit waterfall and a white sky, and a theme tuned a little light
		# should come out slightly brighter rather than illegible.
		#
		# So the ends get a fixed floor with the theme's own dim added on top.
		# Ocean and Clouds are what set the floor: at `art_dim * 0.85` the
		# header on both of them was white type on white water.
		var top_peak: float = minf(0.62 + _art_dim * 0.25, 0.92)
		var bot_peak: float = minf(0.46 + _art_dim * 0.25, 0.85)
		# Sixteen steps each end. Eight was enough over the old wash themes and
		# is not enough over a photograph: a 36px step is invisible against a
		# gradient of the same colour and plainly visible against Clouds' smooth
		# sky, where it reads as banding in the art rather than as the dim it
		# is. Sixteen draw calls is still cheaper than a shader.
		const STEPS := 16
		var top_band: float = size.y * 0.16
		var bot_band: float = size.y * 0.22
		# Eased rather than linear. A straight ramp is already half spent by the
		# time it reaches the INCOMING/SENT labels a sixth of the way down, and
		# those are the two that were hardest to read on Clouds. The curve holds
		# the wash near full for the strip the type actually occupies and then
		# drops away quickly, so the picture loses less than a linear ramp of
		# the same strength would take.
		for i in STEPS:
			var f := float(i) / float(STEPS)
			var ease: float = pow(1.0 - f, 0.55)
			draw_rect(Rect2(full.position.x, -m + f * (top_band + m),
				full.size.x, (top_band + m) / float(STEPS) + 1.0),
				Color(bg_top, top_peak * ease))
			draw_rect(Rect2(full.position.x,
				size.y - bot_band + (1.0 - f) * (bot_band + m),
				full.size.x, (bot_band + m) / float(STEPS) + 1.0),
				Color(bg_top, bot_peak * ease))

	if _motion != "":
		Cosmetics.draw_motion(self, _motion, size,
			Time.get_ticks_msec() / 1000.0, _motion_tint)


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
	_draw_board_art(size, m)

	_draw_keyboard_hitboxes()

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

## Which keys are held, for the pressed look, as `touch index -> key id`.
## Cleared on release, so a finger slid off a key does not leave it looking
## stuck. A dictionary rather than one string because two thumbs hold two keys —
## the mouse, which cannot, uses index -1.
var _keys_down: Dictionary = {}

## Set once real touch events start arriving, after which the mouse is no longer
## allowed to work the keyboard. See `_unhandled_input`.
var _touch_input := false


# -------------------------------------------------------------------- emotes
#
# Hold the key above P, the seven of them fan out upwards, drag to the one you
# mean and let go. Hold rather than tap because the key sits in the reach of a
# thumb that is mostly aiming at letters: a tap that misses P and lands here
# would open a menu over the board mid-word, whereas a *hold* that misses P is
# nothing at all — the finger is gone before the menu ever opens.
#
# Drag-and-release rather than tap-to-open-then-tap-to-pick for the same reason
# in reverse: one gesture, one finger, no state left behind on the screen if you
# change your mind. Sliding back to the key and letting go cancels.
#
# The menu opens upward and is allowed to cover the board. That is a deliberate
# trade — for the third of a second it is up you cannot read your own stack, and
# the alternative is a menu that opens over the keyboard and hides the letters
# you are about to need.

## In wire order. The index is what crosses the network, so this is an on-disk
## format: append only, and never reorder. `emotetest` pins it against the files.
##
## `huh` and `think` are no longer offered — see `EMOTE_MENU`. They stay named
## here because a phone running an older build can still send index 5, and a
## hole in this array would turn that into an emote that arrives as nothing.
##
## `hype` and `dead` are appended rather than folded onto those two free slots.
## The index is what crosses the wire and the *name* is what the receiver draws,
## so reusing 5 for hype would make a 0.36.0 phone answer a star-eyed cheer with
## the old shrug sticker — the wrong feeling, permanently, in a format that
## cannot be corrected later. Appended, that phone clamps 7 and 8 in
## `_on_net_emote` and shows nothing, which is the honest failure.
const EMOTES := ["cheer", "cry", "shock", "angry", "nice", "huh", "think",
	"hype", "dead"]

## The wire indices the fan offers, in the order they are stacked — nearest the
## thumb first.
##
## Wire order for the first five, because that is the order the fan has always
## had and thumbs learn positions rather than pictures. The two new feelings go
## on the end, where they cost nobody their muscle memory: hype and dead are the
## ones with no older counterpart, so they are also the two that will show up as
## silence on a phone that has not updated, and the top of the column is the
## least surprising place for that to happen.
const EMOTE_MENU := [0, 1, 2, 3, 4, 7, 8]

## Wire index -> the sheet that animates it, for those that have one. Anything
## not in here falls back to the single still in `res://emotes/<name>.png`,
## which is what `huh` or `think` from an older build lands on.
##
## `frames` and `cols` describe the grid `tools/build_emotes.py` packed. They
## are duplicated between the two on purpose — the script prints them, and the
## alternative was a manifest file to parse at load for fourteen integers.
const EMOTE_ANIM := {
	0: {"sheet": "bot_excited", "frames": 24, "cols": 6},
	1: {"sheet": "bot_cry", "frames": 18, "cols": 6},
	2: {"sheet": "bot_shocked", "frames": 18, "cols": 6},
	3: {"sheet": "bot_mad", "frames": 18, "cols": 6},
	4: {"sheet": "bot_love", "frames": 18, "cols": 6},
	7: {"sheet": "bot_hype", "frames": 18, "cols": 6},
	8: {"sheet": "bot_dead", "frames": 18, "cols": 6},
}
## One cell of a sheet, and the transparent margin inside it. The game draws the
## inner square: bilinear filtering reaches a texel past the region it is given,
## and without the margin the frame beside it bleeds down the edge.
const EMOTE_CELL := 160.0
const EMOTE_GUTTER := 2.0
## Hand-animation rate. The cycles are 24 frames for cheer and 18 for the rest,
## so at twelve a side they run 2.0s and 1.5s against an `EMOTE_SHOW` of 2.4 —
## the long one plays through once and the short ones come round again, which is
## what they were drawn for.
const EMOTE_FPS := 12.0
## What the key's legend shows, in fractions of a frame: BloqBot's head.
##
## The key is about thirty pixels tall on a phone. The old character was a
## square with a face on it and read at that size by construction; BloqBot is a
## whole body, and measured off the packed sheet its helmet is barely half the
## frame — so three quarters of those thirty pixels went on limbs nobody can
## resolve, and the legend came out a smudge. Cropped to the head it is a face
## again, which is the only job the legend has.
const EMOTE_KEY_HEAD := Rect2(0.24, 0.10, 0.54, 0.54)

## The halo behind the character, and the only colour the emotes have left now
## that nothing tints them.
##
## Taken off BloqBot's own visor. It has to be *its* blue rather than the UI's
## purple, because the thing this is separating is a navy character whose ink is
## `#0b1220` from a panel that bottoms out at `#0b1020` — near enough the same
## colour that the outline disappears into the bubble without it.
const EMOTE_GLOW := Color("#68c4e0")

## How long the key must be held before the menu appears. Short enough not to
## feel like a wait, long enough that a brush past it on the way to P does not
## trigger it.
const EMOTE_HOLD := 0.16
## Gap between two of your own emotes. Not a punishment — a rate limit, so a
## held finger cannot flood the other player's screen.
const EMOTE_COOLDOWN := 2.5
## How long a received emote stays up.
const EMOTE_SHOW := 2.4
## One tile in the fan. Briefly 78 while the column was three tall and height
## was free; back to 62 now that seven feelings are drawn, because at seven the
## height is the constraint again — a column of 78s reaches most of the way up
## a phone and covers the board it is supposed to be answering.
const EMOTE_TILE := 62.0
const EMOTE_TILE_GAP := 8.0

# ------------------------------------------------- emotes on the scoreboard
#
# The one screen in this game where there is something to say and nothing to do.
#
# In a match an emote is a risk: sending one costs a hold, a slide and a
# release, and the board carries on without you. So they are used less than they
# are enjoyed, and the moment they are most wanted is the moment they were least
# available — the end, when the result is in and one of you has something to be
# unbearable about.
#
# The summary has the room and no clock. The whole set is laid out along the
# bottom, one tap each, drawn larger than the fan's tiles because nothing here
# is competing with a playfield for attention.
#
# The name tag is what makes it a conversation rather than a decoration. Two
# emotes can be on screen at once — yours and theirs, which is the interesting
# case and the whole reason `_emote_in` and `_emote_out` are separate slots —
# and a pair of dancing robots with nobody's name on them is a screensaver.

## One tile in the summary row, and the gap between them. Bigger than
## `EMOTE_TILE`: that one is sized against a column that must not cover the
## board, and this row has a footer to itself.
const EMOTE_SUMMARY_TILE := 92.0
const EMOTE_SUMMARY_GAP := 10.0
## How many times a sent emote plays before it leaves, and how long it takes to
## go once it has.
##
## Three, rather than a number of seconds, because the cycles are different
## lengths — 24 frames for cheer and 18 for the rest — and a fixed duration
## either cuts the long one off mid-gesture or leaves the short ones looping an
## awkward two-and-a-bit times. Counting loops means every one of them finishes
## on the frame it was drawn to finish on.
const EMOTE_SUMMARY_LOOPS := 3
const EMOTE_SUMMARY_FADE := 0.6
## How big a sent one is drawn. Twice the row's tile, which is what "show it
## bigger" is for — the row is a set of buttons and this is somebody talking.
const EMOTE_SUMMARY_BUBBLE := 190.0


## How long one cycle of an emote's animation takes, in seconds.
func _emote_cycle(idx: int) -> float:
	if not EMOTE_ANIM.has(idx):
		# A still from an older build. It has no cycle, so it is given the
		# length of the short ones and simply sits there for it.
		return 1.5
	return float(int(EMOTE_ANIM[idx]["frames"])) / EMOTE_FPS


## How long a freshly sent emote should stay up.
##
## In a match that is `EMOTE_SHOW`, which is tuned against a board that is still
## moving underneath it. On the summary nothing is moving, so it plays out its
## three loops and fades.
func _emote_life(idx: int) -> float:
	if _summary_emotes_live():
		return _emote_cycle(idx) * float(EMOTE_SUMMARY_LOOPS) + EMOTE_SUMMARY_FADE
	return EMOTE_SHOW


## Whether the summary is showing the emote row.
##
## Versus only, and a live one: the row is a thing you say to somebody, and the
## daily, survival and a CPU match have nobody on the other end of it. The
## rematch card is a question over the top of the screen and takes every press
## while it is up, so the row stands down rather than sitting under it.
func _summary_emotes_live() -> bool:
	if phase != Phase.OVER or mode != Mode.NORMAL:
		return false
	if _rematch_popup():
		return false
	return net_active() or demo_emotes


## How solid an emote is when it is decoration rather than a message.
##
## The art is the only illustration in a UI otherwise made of rectangles and
## text, and at full opacity it sits in front of the panel instead of on it.
## Letting a little of the panel through is what puts it back in the same plane
## as everything around it.
##
## Deliberately not baked into the files. Alpha in the source would apply
## everywhere at once and could not be taken back, and the one place an emote
## must *not* be faded is the bubble — that one is a thing another player said,
## and a message you can see through reads as a message that failed to arrive.
const EMOTE_MENU_ALPHA := 0.88

var _emote_tex: Dictionary = {}
## Which touch is working the emote key, or -1. The mouse uses -1 as everywhere
## else, so this is -2 when nothing is happening rather than -1.
var _emote_touch := -2
var _emote_held := 0.0
var _emote_open := false
## Which tile of the fan is under the finger, or -1 for none — which is what
## sliding back down to the key gives you, and is how the gesture is cancelled.
##
## A position in `EMOTE_MENU`, not a wire index. The two were the same thing
## until the menu stopped offering all seven, and the conversion happens once,
## in `_emote_release`, so nothing else has to know which kind it is holding.
var _emote_pick := -1
## Seconds until another can be sent.
var _emote_cool := 0.0
## What the opponent last sent: `{"i": int, "left": float}`. Empty when nothing
## is on screen.
var _emote_in: Dictionary = {}
## The same, for the one you just sent.
##
## Kept separate rather than sharing a slot, because the two can be on screen at
## once and the interesting moment is exactly when they are — somebody answering
## an emote with another one is the whole point, and a single slot would have the
## reply delete the thing it was replying to.
var _emote_out: Dictionary = {}

## Draw the emote UI without a live match behind it. Off, and nothing in the
## game ever turns it on.
##
## It exists because emotes cannot otherwise be filmed. `net_active()` is
## `MultiplayerManager.current_match != null` and that is a `GKMatch` — a Game
## Center type whose plugin is a stub on Linux and refuses to instantiate. So on
## the only machine that can record footage, the one state in which emotes are
## drawn is a state that cannot be entered, and the trailer would have to either
## leave the feature out or paint fake bubbles over the gameplay in the editor.
##
## Painting them on is the option worth refusing. A trailer that shows a screen
## the build cannot produce is the one kind of trailer that is actually
## dishonest, so the recorder is given a way to reach the real UI instead. See
## `tools/trailer.gd`, which sets this for one scene and clears it after.
##
## Sending still requires a real match — `_send_emote` returns early without one
## — so with this on and no network the key is a button that does nothing. That
## is fine for a recorder driving the dictionaries directly, and is why nothing
## in the game turns it on.
var demo_emotes := false


## The hold that opens the menu, the cooldown, and the life of an incoming
## bubble. Run every frame from `_process` rather than on timers, because all
## three have to stop dead when the match does — a `SceneTreeTimer` outliving a
## match is how an emote arrives on the summary screen.
func _tick_emotes(delta: float) -> void:
	if _emote_cool > 0.0:
		_emote_cool = maxf(0.0, _emote_cool - delta)
	if not _emote_in.is_empty():
		var left := float(_emote_in["left"]) - delta
		if left <= 0.0:
			_emote_in = {}
		else:
			_emote_in["left"] = left
	if not _emote_out.is_empty():
		var mine := float(_emote_out["left"]) - delta
		if mine <= 0.0:
			_emote_out = {}
		else:
			_emote_out["left"] = mine

	if _emote_touch == -2:
		return
	# A gesture cannot outlive the thing it is aimed at. Losing the match, or
	# pausing, with the column open would leave it on screen over a dead board.
	if not _emotes_live():
		_emote_touch = -2
		_emote_open = false
		_emote_pick = -1
		return
	if _emote_open:
		return
	_emote_held += delta
	if _emote_held >= EMOTE_HOLD:
		_emote_open = true
		Haptics.fire("tap", 0.8)
		Sfx.play("key", 0.78)


## A finger has landed on the key. Nothing opens yet — `_process` decides that
## once the hold has lasted, which is what makes a brush past it harmless.
func _emote_begin(index: int) -> void:
	_emote_touch = index
	_emote_held = 0.0
	_emote_open = false
	_emote_pick = -1


func _emote_drag(at: Vector2) -> void:
	if not _emote_open:
		return
	var was := _emote_pick
	_emote_pick = _emote_at(at)
	# One tick per tile crossed, so the column can be worked without looking at
	# it. Silent when sliding off the end, because leaving is not a choice.
	if _emote_pick != was and _emote_pick >= 0:
		Haptics.fire("tap", 0.5)
		Sfx.play("key", 1.18)


## Finger up. Sends whatever is under it, or nothing if the menu never opened or
## the finger came back down to the key.
func _emote_release() -> void:
	var pick := _emote_pick if _emote_open else -1
	_emote_touch = -2
	_emote_held = 0.0
	_emote_open = false
	_emote_pick = -1
	if pick >= 0 and pick < EMOTE_MENU.size():
		_send_emote(int(EMOTE_MENU[pick]))


## Out, and shown on your own screen at the same moment.
##
## The sender sees their own emote in the same bubble the receiver will, which
## is the only feedback that the thing left the device — there is no delivery
## receipt on a GameKit broadcast, and a control that looks identical whether it
## worked or not is a control people press twice.
func _send_emote(idx: int) -> void:
	if idx < 0 or idx >= EMOTES.size() or _emote_cool > 0.0:
		return
	if not net_active():
		return
	_emote_cool = EMOTE_COOLDOWN
	MultiplayerManager.send_event("emote", {"i": idx})
	# The local echo, which this went to build 2 without. The comment above
	# claimed it and the body did not do it, so picking an emote spent the
	# cooldown, made a noise and put nothing on the screen — indistinguishable
	# from a control that is simply broken, and the first thing reported.
	_emote_out = {"i": idx, "left": _emote_life(idx), "span": _emote_life(idx)}
	Haptics.fire("power", 0.7)
	Sfx.play("zap", 1.12)


## In. Clamped rather than trusted: the index arrives from another device, and a
## build that ships one more emote than this one would otherwise index off the
## end of the array on the older phone.
func _on_net_emote(idx: int) -> void:
	if idx < 0 or idx >= EMOTES.size():
		return
	_emote_in = {"i": idx, "left": _emote_life(idx), "span": _emote_life(idx)}
	Haptics.fire("tap", 0.4)


## The summary's emote row, laid out along the bottom of the screen.
##
## Returned in `EMOTE_MENU` order, which is the order the fan uses — a player who
## has learned where ANGRY is in a match should not have to find it again here.
##
## Sized down to fit rather than wrapped. Seven tiles at the full size need 700
## units and a phone has 720 minus margins, so on the narrowest screens this
## comes out a little under `EMOTE_SUMMARY_TILE` and stays one row. Two rows
## would push the buttons off the bottom of a screen that does not scroll.
##
## Placed under the summary's own buttons rather than pinned to the bottom of
## the screen, and this is the part that was wrong first. Pinned, it overlapped
## Rematch and Title in landscape — and `_action_at` answers with the buttons
## before it reaches this row, so the overlapping tiles were not merely ugly,
## they were four emotes that quietly pressed Rematch. Measured off the buttons
## it cannot collide with them whatever the summary above it grows to.
##
## Returns nothing at all when there is no room left. A row squeezed to a size
## no thumb can hit is worse than a row that is not offered: on the screens
## where that happens the buttons are the thing that matters, and they are the
## thing this would be sitting on.
const EMOTE_SUMMARY_MIN := 44.0

func _summary_emote_rects(size: Vector2) -> Array:
	var n := EMOTE_MENU.size()
	var floor_y := 0.0
	for b: Dictionary in _menu_buttons():
		floor_y = maxf(floor_y, (b["rect"] as Rect2).end.y)
	var top: float = floor_y + 16.0
	var bottom: float = size.y - safe_bottom - 14.0
	var usable: float = size.x - GRID_MARGIN * 2.0
	var tile: float = minf(EMOTE_SUMMARY_TILE,
		(usable - EMOTE_SUMMARY_GAP * float(n - 1)) / float(n))
	tile = minf(tile, bottom - top)
	if tile < EMOTE_SUMMARY_MIN:
		return []
	var span: float = tile * float(n) + EMOTE_SUMMARY_GAP * float(n - 1)
	var x: float = (size.x - span) * 0.5
	# Sat on the floor of whatever room is left rather than floating in the
	# middle of it, so the row reads as the bottom edge of the screen on every
	# shape it is drawn at.
	var y: float = bottom - tile
	var out: Array = []
	for i in n:
		out.append(Rect2(x + float(i) * (tile + EMOTE_SUMMARY_GAP), y, tile, tile))
	return out


## The row, and whatever has been said with it.
##
## Drawn after the summary's own furniture and before the rematch card, which is
## a question and owns the screen while it is up.
func _draw_summary_emotes(size: Vector2) -> void:
	if not _summary_emotes_live():
		return
	var rects := _summary_emote_rects(size)
	var cooling: bool = _emote_cool > 0.0
	for i in rects.size():
		var r: Rect2 = rects[i]
		_panel(r, Color("#111730", 0.85), Color("#2a3355"), 10.0, 1.0)
		# Dimmed as one while the cooldown runs, so the row reads as unavailable
		# rather than as seven buttons that individually did nothing.
		_draw_emote(r.grow(-6.0), int(EMOTE_MENU[i]),
			0.35 if cooling else EMOTE_MENU_ALPHA, false)

	# What has been said, in the band above the scoreboard table.
	#
	# Not above the row it was sent from, which is where this went first and
	# which was wrong for a reason worth writing down: the buttons live between
	# the two, so a five-second emote sat on top of Rematch — the one control on
	# this screen with somebody else waiting at the other end of it. Input was
	# never affected, because `_action_at` answers with the buttons first, but a
	# button you cannot read is a button you do not press.
	#
	# The band over the table is the only large piece of this screen with
	# nothing in it, it is high enough to be the first thing seen, and what it
	# covers when it overflows is a headline that has already been read.
	var feet: float = _scoreboard_top() - 14.0
	var pair: bool = not _emote_in.is_empty() and not _emote_out.is_empty()
	var big: float = minf(EMOTE_SUMMARY_BUBBLE,
		size.x * (0.30 if pair else 0.44))
	if not _emote_out.is_empty():
		var x: float = size.x * (0.28 if pair else 0.5)
		_draw_summary_emote(_emote_out, Vector2(x, feet), big, "YOU")
	if not _emote_in.is_empty():
		var x2: float = size.x * (0.72 if pair else 0.5)
		_draw_summary_emote(_emote_in, Vector2(x2, feet), big,
			_show_name(ai_side.label))


## One sent emote, with the name of whoever sent it over its head.
##
## `bottom` is where the character's feet go, so it grows upward out of the row
## rather than centring on a point and overlapping it.
func _draw_summary_emote(slot: Dictionary, bottom: Vector2, span: float,
		who: String) -> void:
	var left := float(slot.get("left", 0.0))
	if left <= 0.0:
		return
	# Fades only at the end, and only over `EMOTE_SUMMARY_FADE`. Fading across
	# the whole life would have it half gone by its second loop, which is the
	# loop somebody is most likely to be looking at.
	var alpha: float = clampf(left / EMOTE_SUMMARY_FADE, 0.0, 1.0)
	var span_total := float(slot.get("span", left))
	var age: float = maxf(0.0, span_total - left)
	var at := Rect2(bottom.x - span * 0.5, bottom.y - span, span, span)
	_draw_emote(at, int(slot.get("i", 0)), alpha, true, age)
	# The tag. Drawn on a plate rather than as bare text, because it sits over
	# whatever the summary put behind it and a name that is sometimes legible is
	# worse than no name.
	var label := who if who != "" else "THEM"
	var size_pt := _read_size(14)
	var w: float = _font_bold.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER,
		-1, size_pt).x + 22.0
	var tag := Rect2(bottom.x - w * 0.5, at.position.y - 30.0, w, 26.0)
	_panel(tag, Color("#0b1020", 0.88 * alpha), Color(EMOTE_GLOW, 0.5 * alpha),
		8.0, 1.0)
	_otext(_font_bold, Vector2(bottom.x, tag.position.y + 18.0), label, size_pt,
		Color("#e6ecff", alpha))


## Where the tiles sit when the menu is open: straight up from the key, nearest
## the thumb first.
##
## Built from the key's own rect rather than from the screen, so the column
## cannot drift away from the control that opened it.
func _emote_rects(size: Vector2) -> Array:
	var key := _kb_emote_rect(size, _keyboard_bottom(size.y))
	var out: Array = []
	# Pulled back in from the edge. The key sits hard against the right margin
	# because P does, but the column is wider than the key and its rail is wider
	# again — left centred on the key, the rail runs about six pixels off the
	# side of the screen, which is exactly the kind of clipping that only shows
	# up on the device.
	var rail_half: float = EMOTE_TILE * 0.5 + 12.0
	var cx: float = clampf(key.get_center().x, rail_half + 6.0,
		size.x - rail_half - 6.0)
	for i in EMOTE_MENU.size():
		var y: float = key.position.y - EMOTE_TILE_GAP \
			- float(i + 1) * (EMOTE_TILE + EMOTE_TILE_GAP)
		out.append(Rect2(cx - EMOTE_TILE * 0.5, y, EMOTE_TILE, EMOTE_TILE))
	return out


## The emote under a finger, or -1. Generous horizontally on purpose: the column
## is one tile wide and a thumb dragging straight up does not travel straight.
func _emote_at(p: Vector2) -> int:
	var size := get_viewport_rect().size
	var at := p - Vector2(0.0, _touch_lift(size))
	var rects := _emote_rects(size)
	for i in rects.size():
		var r: Rect2 = rects[i]
		if at.y >= r.position.y - EMOTE_TILE_GAP * 0.5 \
				and at.y < r.position.y + r.size.y + EMOTE_TILE_GAP * 0.5 \
				and absf(at.x - r.get_center().x) < EMOTE_TILE * 1.6:
			return i
	return -1


## A sheet or a still, by file name, loaded once. The retired stills are only
## ever asked for when an older build sends one, so this being lazy is what
## keeps four textures nobody will see out of memory in the usual match.
func _emote_texture(name: String) -> Texture2D:
	if _emote_tex.has(name):
		return _emote_tex[name] as Texture2D
	var tex := _load_or_null("res://emotes/%s.png" % name) as Texture2D
	_emote_tex[name] = tex
	return tex


## The cell of `anim`'s sheet showing at time `t`, in pixels.
##
## Inset by the gutter, so the rect handed to `draw_texture_rect_region` is the
## frame and nothing of its neighbours.
func _emote_frame(anim: Dictionary, t: float) -> Rect2:
	var count: int = maxi(1, int(anim["frames"]))
	var cols: int = maxi(1, int(anim["cols"]))
	var i: int = posmod(int(t * EMOTE_FPS), count)
	var inner: float = EMOTE_CELL - EMOTE_GUTTER * 2.0
	return Rect2(float(i % cols) * EMOTE_CELL + EMOTE_GUTTER,
		float(i / cols) * EMOTE_CELL + EMOTE_GUTTER, inner, inner)


## Whether the key is worth drawing at all. Emotes are a thing you send to
## somebody, so they exist only in a live match against a person — a solo run
## would be a button that talks to nobody.
func _emotes_live() -> bool:
	return _keys_live() and (net_active() or demo_emotes)


## Paint one. `alpha` fades the whole thing, glow included, so a bubble can
## leave without the halo outliving it.
##
## `age` is how far into the animation to draw, in seconds. Pass -1 for the
## shared wall clock, which is what makes a column of tiles bop together instead
## of each one running its own cycle from whenever it was first drawn.
##
## Nothing is tinted any more. BloqBot arrived already coloured, and a multiply
## over art that is navy and cyan does not restyle it, it only ever makes it
## darker — so the tint went, and the cosmetic slot that existed to drive it
## went with it.
func _draw_emote(at: Rect2, idx: int, alpha: float, glow: bool,
		age := -1.0) -> void:
	if idx < 0 or idx >= EMOTES.size():
		return
	if glow:
		# A soft disc behind it. Three rings rather than a texture, because the
		# character lands on a dark board and needs seating, not decoration.
		var mid := at.get_center()
		for i in 3:
			var f := 1.0 - float(i) / 3.0
			_overlay.draw_circle(mid, at.size.x * (0.62 + 0.13 * float(i)),
				Color(EMOTE_GLOW, 0.16 * f * alpha))
	var white := Color(1.0, 1.0, 1.0, alpha)
	if EMOTE_ANIM.has(idx):
		var anim: Dictionary = EMOTE_ANIM[idx]
		var sheet := _emote_texture(String(anim["sheet"]))
		if sheet == null:
			return
		var t: float = age if age >= 0.0 else Time.get_ticks_msec() / 1000.0
		_overlay.draw_texture_rect_region(sheet, at, _emote_frame(anim, t), white)
		return
	# `huh` or `think`: no longer offered here, still sendable by an older build.
	var still := _emote_texture(EMOTES[idx])
	if still != null:
		_overlay.draw_texture_rect(still, at, false, white)


## The key's legend: frame zero of the first emote, cropped to the head.
##
## Frozen rather than animated. The key is up for the whole match, directly
## above P, and a character dancing in the corner of the eye of somebody trying
## to type is movement with nothing to say — the animation is the *message*, and
## it should only play where a message is being chosen or read.
func _draw_emote_head(at: Rect2, alpha: float) -> void:
	var idx := int(EMOTE_MENU[0])
	if not EMOTE_ANIM.has(idx):
		return
	var anim: Dictionary = EMOTE_ANIM[idx]
	var sheet := _emote_texture(String(anim["sheet"]))
	if sheet == null:
		return
	var frame := _emote_frame(anim, 0.0)
	_overlay.draw_texture_rect_region(sheet, at,
		Rect2(frame.position + EMOTE_KEY_HEAD.position * frame.size,
			EMOTE_KEY_HEAD.size * frame.size), Color(1.0, 1.0, 1.0, alpha))


## Whether the drawn keyboard is up and listening.
func _keys_live() -> bool:
	return portrait and phase == Phase.PLAY and not paused and player.alive


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
				Phase.COSMETICS, Phase.BOARDS, Phase.WEEKLY:
			return "title"
		Phase.LOBBY:
			# Backing out of a running search stops it rather than leaving it
			# going behind you. The chevron is the only way off this screen in
			# portrait, so if it did not cancel there would be no way to.
			return "versus_cancel" if _versus_busy() else "title"
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

## Room kept under the last settings row for the hint line beneath it. Named
## because `_settings_fill` sizes the rows against it and would otherwise grow
## them straight over the top of it.
const SETTINGS_FOOT := 150.0


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
	# A flat factor now rather than a fit. These screens scroll, so nothing has
	# to be squeezed into the window — and every version of squeezing produced
	# rows sized for the screen instead of for a thumb. `natural` and `cap` are
	# kept so the callers still read as "how tall am I", which is what the
	# scroll limit needs from them.
	if not portrait or natural <= 1.0:
		return 1.0
	return cap


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
	# Once a screen is taller than the window there is nothing to centre — it is
	# a list, and the offset is where the reader has dragged it to.
	if _scroll_max > 1.0:
		return -_scroll
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
func _menu_spread(_natural: float, _cap: float = 3.2) -> float:
	# Gaps grow a little, not a lot. Spreading rows apart was a way of filling a
	# screen that could not scroll; now the rows themselves are the right size,
	# and a big gap between them is just distance.
	return 1.45 if portrait else 1.0


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
## How many columns `_grid_rects` will settle on, without laying anything out.
##
## Split off because every screen that scrolls has to know its own height, that
## height needs a row count, and the rects that would answer it are positioned
## from `_menu_offset` — which is computed *from* the height. Asking the grid is
## circular, so the screens used to guess, and the guesses went stale: the record
## screen said three rows of stats on a phone when thirteen tiles at four columns
## is four, and came up a whole row short.
func _grid_cols(count: int, want_cols: int, gap: float, min_w: float) -> int:
	var usable: float = maxf(120.0,
		get_viewport_rect().size.x - GRID_MARGIN * 2.0)
	var cols: int = maxi(1, mini(want_cols, count))
	while cols > 1 and (usable - gap * float(cols - 1)) / float(cols) < min_w:
		cols -= 1
	return cols


## The row count that follows from it. This is the number a `_laid` function
## wants, and it is never to be typed in by hand.
func _grid_rows(count: int, want_cols: int, gap: float, min_w: float) -> int:
	if count <= 0:
		return 0
	return int(ceil(float(count)
		/ float(_grid_cols(count, want_cols, gap, min_w))))


func _grid_rects(count: int, top: float, want_cols: int, want_w: float, ch: float,
		gap: float = 10.0, min_w: float = 0.0, vgap: float = 10.0) -> Array:
	var size := get_viewport_rect().size
	var usable: float = maxf(120.0, size.x - GRID_MARGIN * 2.0)
	var cols: int = _grid_cols(count, want_cols, gap, min_w)
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
	# This one still fires on the press, because the back chevron is fixed
	# furniture rather than part of the scrollable body — there is no drag it
	# could be the start of. What it must not do is leave a half-finished press
	# behind: its own release goes on to reach the menu handler, and a stale
	# `_press_action` there would be a row on the screen we have just arrived at
	# being activated by a finger that came down on the screen we just left.
	_press_action = ""
	var act := _back_action()
	if act == "":
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
	return Keyboard.keys(get_viewport_rect().size, _keyboard_bottom(),
		_kb_form())


## The letters on the keycaps, and the words on the three action keys.
##
## The keys themselves are as wide as the iOS keyboard's and taller. The letters
## printed on them were not: at 26 an A drew 17 units wide inside a 64-unit key,
## a bit over a quarter of it, where iOS fills about half. So the keyboard
## measured fine and *read* as tiny, and "the keys are too small" turns out to
## have been a complaint about the type rather than about the targets. At 44 an A
## is 30 units — iOS's proportion, on a key that was already the right size.
##
## FIRE was the worst of them, and it is the one key on the screen that is not
## competing with a neighbour for space: a four-letter word at 19 inside a
## 700-unit button, because it shared its size with CLR and DEL, which do have
## neighbours. It gets its own number now.
const CAP_SIZE := 44
const ACTION_SIZE := 32
const FIRE_SIZE := 42
## Stroke weight for `_font_key`. Negative thins; 0.6 is what `_font_bold` uses.
const KEY_WEIGHT := -0.2


func _draw_keyboard() -> void:
	var held := _keys_down.values()
	# Type is a physical size like the keys are, so it travels with them.
	var s := _kb_type_scale(get_viewport_rect().size)
	for k: Dictionary in _keyboard():
		var r: Rect2 = k["rect"]
		var id: String = k["id"]
		var down: bool = held.has(id)
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
			# Reads as a stronger DEL rather than as its own thing, because that
			# is what it is — and it sits at the far end of the same row, where
			# nothing you are aiming at is next to it except Z.
			"clear":
				bg = _key_bg.darkened(0.25) if not down else _key_bg.lightened(0.10)
				edge = Color("#c77dff", 0.32)
				ink = Color(_key_ink, 0.72)
		if down:
			bg = bg.lightened(0.12)
		_panel(r, bg, edge, 9.0, 2.0)
		# FIRE keeps the bold face. It is a button with a word on it rather than a
		# keycap with a letter on it, and it is the one thing on the keyboard that
		# is supposed to shout.
		var cap: int = CAP_SIZE
		var face: Font = _font_key
		if id == "fire":
			cap = FIRE_SIZE
			face = _font_bold
		elif id.length() > 1:
			cap = ACTION_SIZE
		_otext(face, r.get_center(), String(k["label"]), int(float(cap) * s), ink)

## The emote key, and the fan when it is open.
##
## Drawn after the keyboard so the open column sits over the board rather than
## under it, and on `_overlay` like everything else that must not move with the
## screen shake — an emote menu that jitters while you are trying to pick from it
## is a menu you will pick the wrong thing from.
func _draw_emote_key() -> void:
	if not _emotes_live():
		return
	var key := _kb_emote_rect(get_viewport_rect().size, _keyboard_bottom())
	var cooling: bool = _emote_cool > 0.0
	var down: bool = _emote_touch != -2

	var edge := Color("#c77dff", 0.5 if not cooling else 0.18)
	var bg := _key_bg.darkened(0.25) if not down else _key_bg.lightened(0.10)
	_panel(key, bg, edge, 9.0, 2.0 if down else 1.0)

	# The face on the key doubles as the legend: there is no room for the word
	# "emote" at this size and a smiley needs no word. Padded tighter than the
	# 0.16 the old square wanted, because a head is round and a square with a
	# face on it was not — the same margin round a helmet reads as a gap.
	var pad := key.size.y * 0.10
	_draw_emote_head(Rect2(key.position
		+ Vector2((key.size.x - key.size.y) * 0.5 + pad, pad),
		Vector2(key.size.y - pad * 2.0, key.size.y - pad * 2.0)),
		0.30 if cooling else 0.95)

	if cooling:
		# The wedge that says when, rather than a number nobody will read while
		# a board is falling on them.
		var f: float = 1.0 - _emote_cool / EMOTE_COOLDOWN
		_overlay.draw_arc(key.get_center(), key.size.y * 0.42, -PI * 0.5,
			-PI * 0.5 + TAU * f, 24, Color("#c77dff", 0.55), 2.0)

	if not _emote_open:
		return

	# The column. A rail behind it so the stickers over a moving board still read
	# as one list rather than as three things that happened to line up.
	var rects := _emote_rects(get_viewport_rect().size)
	var first: Rect2 = rects[rects.size() - 1]
	var last: Rect2 = rects[0]
	var rail := Rect2(first.position.x - 12.0, first.position.y - 10.0,
		first.size.x + 24.0,
		last.position.y + last.size.y - first.position.y + 20.0)
	_panel(rail, Color("#0b1020", 0.93), Color("#c77dff", 0.35), 14.0, 2.0)

	for i in rects.size():
		var r: Rect2 = rects[i]
		var on: bool = i == _emote_pick
		if on:
			_panel(r.grow(6.0), Color("#c77dff", 0.20), Color("#c77dff", 0.85),
				10.0, 2.0)
		# The picked one lifts and the rest sit back, so the choice is legible
		# from the corner of an eye that is mostly on the board. Neither reaches
		# full: this column is sitting on top of a board somebody is still
		# reading, and letting a little of it through is the difference between
		# covering the stack and hiding it.
		_draw_emote(r.grow(4.0 if on else 0.0), int(EMOTE_MENU[i]),
			EMOTE_MENU_ALPHA if on else 0.70, on)


## One emote, in a bubble, centred on `at`.
##
## Anchored to somebody rather than to the middle of the screen: an emote is
## *from* a person, and one floating free is a decoration. Yours sits beside the
## rival card and theirs sits over it, so the top bar reads as two people rather
## than as one notification area that sometimes lies about who spoke.
##
## `mine` only changes the border colour. The position is what says whose it is,
## and a second visual language for the same object would be one more thing to
## learn during a match.
func _draw_emote_bubble(at: Vector2, entry: Dictionary, mine: bool) -> void:
	if entry.is_empty():
		return
	var left := float(entry.get("left", 0.0))
	# Fades out over the last half second, and pops in over the first tenth.
	var age: float = EMOTE_SHOW - left
	var alpha: float = clampf(left / 0.5, 0.0, 1.0)
	var pop: float = clampf(age / 0.10, 0.0, 1.0)
	var size: float = 78.0 * (0.72 + 0.28 * pop)
	var box := Rect2(at - Vector2(size, size) * 0.5, Vector2(size, size))

	# The bubble behind it, with a tail pointing at whose it is.
	var pad := 9.0
	var bub := box.grow(pad)
	var edge := PLAYER_ACCENT if mine else Color("#c77dff")
	_panel(bub, Color("#0b1020", 0.90 * alpha), Color(edge, 0.45 * alpha),
		12.0, 2.0)
	var tip := Vector2(at.x, bub.position.y + bub.size.y + 9.0)
	_overlay.draw_colored_polygon(PackedVector2Array([
		tip, tip + Vector2(-9.0, -10.0), tip + Vector2(9.0, -10.0)]),
		Color("#0b1020", 0.90 * alpha))
	# Driven by the bubble's own age, so the cycle starts on the frame it was
	# drawn to start on. On the shared clock a shrug would arrive halfway
	# through its own shrug, which is the difference between a reaction and a
	# loop that happened to be passing.
	_draw_emote(box, int(entry.get("i", 0)), alpha, true, age)


## The keys as they are drawn, plus the line above which the keyboard stops
## claiming taps. There is nothing else left to draw: inside the band every pixel
## belongs to the nearest key, so the boundaries are simply the midlines between
## neighbours and the only edge that is a decision is the top one.
func _draw_keyboard_hitboxes() -> void:
	if not DEBUG_TOUCH_HITBOXES:
		return

	var size := get_viewport_rect().size
	var top: float = _key_band_top(size)
	draw_rect(Rect2(0.0, top, size.x, size.y - top), Color(0.2, 0.8, 1.0, 0.08), true)
	draw_line(Vector2(0.0, top), Vector2(size.x, top), Color(1.0, 0.5, 0.2, 0.6), 2.0)
	for k: Dictionary in _keyboard():
		draw_rect(k["rect"] as Rect2, Color(0.2, 0.8, 1.0, 0.5), false, 1.0)
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


## The line above which the keyboard stops claiming taps. Scaled with everything
## else, so the band keeps the same physical reach on a phone whose units are
## smaller than the design space's.
func _key_band_top(size: Vector2) -> float:
	return _keyboard_bottom() - _kb_height(size) \
		- KEY_BAND_PAD * _kb_type_scale(size)


## `TOUCH_LIFT` against this screen. A correction for where a finger sits is a
## physical distance, not a number of design units, so it travels with the same
## scale the keys do.
func _touch_lift(size: Vector2) -> float:
	return TOUCH_LIFT * _kb_type_scale(size)


## Which key is under a point, or "" if the point is not on the keyboard at all.
##
## Not a hit test. Padding every key by a few pixels — which is what this used to
## do — looks like generosity and is not: the padded rects overlap, and in the
## overlap the winner is whichever key came first out of `_keyboard()`, which is
## always the one further left and further up. Every near miss resolved the same
## direction, so the keyboard was not merely imprecise, it was imprecise with a
## grain, and a typist cannot learn their way around that.
##
## So the keyboard owns a band of the screen outright, and inside it there is no
## such thing as a gap: every point belongs to whichever key it is nearest the
## edge of, and the boundaries are the midlines between neighbours.
##
## That is the best a keyboard can do while it refuses to know what you are
## typing, and it is not enough. The reported misses are sideways — the letter
## next door in the same row — and a sideways miss lands *inside* the wrong key,
## not in the gap, so no amount of nearest-edge generosity can catch it. Midlines
## are only the right answer if every neighbour is equally likely, and after two
## or three letters they are nowhere near equally likely: most of the alphabet
## cannot continue the word at all.
##
## So the midline is allowed to move, by `KEY_LEAN` and no further. A letter that
## can still begin a word pulls the boundary that much towards its neighbour that
## cannot. Three things keep this from becoming the unlearnable grain above:
##
##   - The shift is bounded and small. `KEY_LEAN` less the gap is about a quarter
##     of a key's width, so the middle half of every key types itself whatever
##     the dictionary thinks, and the letter you are aiming at is never the one
##     that moves.
##   - It is legality, not likelihood. A letter either can continue the word or
##     cannot; rare letters are not discounted for being rare. Q and Z score ten
##     apiece, so a keyboard that quietly shrank the improbable would be shrinking
##     exactly the plays worth making.
##   - It only ever settles an argument between two letters. Land inside CLR, DEL
##     or FIRE and you get it, full stop — losing a whole typed word to a boosted
##     Z is a far worse trade than the mistyped letter this is fixing.
##
## When the dictionary has no opinion — an empty line, where all 26 letters begin
## words, or a line already misspelt, where none of them do — every pull is equal
## and this is exactly the geometry it was before.
func _key_at(p: Vector2) -> String:
	var size := get_viewport_rect().size
	var at := p - Vector2(0.0, _touch_lift(size))
	if at.y < _key_band_top(size):
		return ""

	var lean: float = KEY_LEAN * _kb_type_scale(size)

	# How far a tap may be from a key and still count as that key.
	#
	# Unlimited on a phone, which is deliberate and has to stay that way: the
	# keyboard spans the full width, so the nearest key is always the adjacent
	# one, and the unlimited search is what lets a thumb that lands just below
	# the bottom row still get the letter it was aiming at.
	#
	# A split keyboard breaks that assumption in the most damaging way available.
	# There is now a sixth of the screen's width of nothing between the halves —
	# the part you rest a thumb on, and the part you tap when you meant to tap
	# nothing at all — and every point of it has a nearest key several key-widths
	# away on one side or the other. Left unlimited, resting a thumb in the middle
	# of the keyboard types a letter. So in SPLIT a tap has to land within a key's
	# width of a key, and the dead gap goes back to being dead.
	#
	# Asked of `Keyboard` rather than worked out here. The gap and the keys are
	# both fractions of the screen now, so a limit written as a constant would be
	# the right distance on one device and the wrong one on every other.
	#
	# FIRE is unaffected: it still spans the whole width along the bottom, and a
	# tap inside any action key returns from the loop before this is consulted.
	var limit := INF
	if _kb_form() == Keyboard.Form.SPLIT:
		limit = Keyboard.key_width(size, Keyboard.Form.SPLIT)

	var best := ""
	var best_score := INF
	var best_dist := INF
	for k: Dictionary in _keyboard():
		var r: Rect2 = k["rect"]
		var id: String = k["id"]
		# Distance to the rectangle rather than to its centre, because the keys
		# are not all the same size — measuring to centres would let FIRE, being
		# the widest thing on the screen, pull taps off the letters beside it.
		var dx := maxf(maxf(r.position.x - at.x, at.x - r.end.x), 0.0)
		var dy := maxf(maxf(r.position.y - at.y, at.y - r.end.y), 0.0)
		var d := sqrt(dx * dx + dy * dy)
		# Inside an action key is the end of the discussion.
		if d == 0.0 and id.length() > 1:
			return id
		var score := d
		if id.length() == 1 and _letter_lives(id):
			score -= lean
		if score < best_score:
			best_score = score
			best_dist = d
			best = id
	# Tested against the true distance, not the leaned score — `lean` exists to
	# break ties between two keys a thumb is genuinely between, and letting it
	# also decide whether the tap was near the keyboard at all would put the
	# reach back by most of a key on exactly the letters that can finish a word.
	return "" if best_dist > limit else best


## The `typed` that `_lean_set` was built against. Starts as something no line
## can ever equal, so the first lookup always builds.
var _lean_for := "￿"
var _lean_set := {}


## Could `typed + ch` still turn into a word?
##
## The whole alphabet is swept once per change to the line and reused across the
## keys, rather than asked per key per tap. Two binary searches over a sorted
## 350k list is cheap, fifty-two of them on every finger-down is a waste.
func _letter_lives(ch: String) -> bool:
	if _lean_for != typed:
		_lean_for = typed
		_lean_set = {}
		for c in "abcdefghijklmnopqrstuvwxyz":
			if WordBank.valid_prefix_count(typed + c) > 0:
				_lean_set[c] = true
	return _lean_set.has(ch)


## A tap on a key does exactly what the matching physical key does, so there is
## one set of rules about what typing means and the keyboard is only an input
## device rather than a second implementation of the game.
func _press_key(id: String) -> void:
	if id == "":
		return
	if id == "fire":
		_fire_pressed()
		return
	if id == "back":
		if player.alive and not paused:
			typed = typed.substr(0, maxi(0, typed.length() - 1))
			Sfx.play("back", randf_range(0.94, 1.06))
			Haptics.fire("back")
		return
	# What Ctrl+Backspace has always done on a desktop. A word you have decided
	# against is a word you have decided against, and getting rid of it one letter
	# at a time is six taps of pure tax while the board is filling up.
	if id == "clear":
		if player.alive and not paused and typed != "":
			typed = ""
			# Pitched well under DEL and felt as a stop rather than as a tap, so
			# the difference between losing a letter and losing the word is
			# something you hear and feel without looking up from the board.
			Sfx.play("back", 0.72)
			Haptics.fire("reject", 0.6)
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

	# Something for the type to sit on, when there is a photograph behind it.
	#
	# The input line and the readout under it are the two most important pieces
	# of text in the game — what you are typing, and what it will do — and they
	# live in the gap between the board and the keyboard, which is the one strip
	# a painted board covers and neither dim band reaches. On Clouds that put
	# gold type on a white sky. Soft-edged rather than a panel: it has to stop
	# being a sky without starting to be a widget.
	if _art != null:
		for i in 5:
			var f := float(i) / 4.0
			var g: float = f * 11.0
			draw_rect(Rect2(cx - bw * 0.5 - 26.0 - g, base_y - 32.0 - g,
				bw + 52.0 + g * 2.0, 88.0 + g * 2.0),
				Color(bg_top, 0.26 * (1.0 - f)), true)

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
		# What the rhythm alone guarantees. A long enough word beats it on its
		# own, so this is a floor rather than a forecast — said as "at least".
		var next_tier := _chain_tier(player.chain + 1)
		_text_centered(_font_bold, Vector2(cx, status_y),
			"CHAIN x%d · next hit at least %s" % [
				player.chain, _tier_name(next_tier)], 13,
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

	# Their half-typed word used to be printed here, and is not any more — see
	# `_typing_of`. The line is gone rather than blanked: `_typing_of` would now
	# feed it an empty string forever, which drew a permanent grey ellipsis that
	# looked like a rival who had stopped playing.
	#
	# The panel does not read as dead without it. What is left is everything you
	# are entitled to know and every part of it moves: the chain meter fills and
	# times out, the incoming count changes, the lives go.

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
			if net_active() or demo_emotes:
				_draw_portrait_emotes(size)
			_draw_emote_key()
			_draw_back_button()
		_draw_score_pops()
		_draw_power_pops()
		# Drawn here rather than in `_draw`, because everything it uses paints on
		# this canvas item and `draw_*` outside its own draw pass silently does
		# nothing at all.
		if mode != Mode.NORMAL:
			_draw_coaching(size)
		# After the coaching card, so a tutorial step wins the middle of the
		# board outright — the lesson is already telling them what to type.
		_draw_first_word_prompt()
		if paused:
			_draw_pause(size)
		elif not player.alive:
			_draw_spectating(size)
		# Over the pause menu, because it is a question about the button on it.
		# Outside the `paused` branch on purpose: the card outlives nothing, but
		# drawing it from inside would tie it to a menu it is meant to cover.
		_draw_confirm(size)
	else:
		if phase == Phase.SPLASH:
			# The menu assembles underneath while the art dissolves off the top of
			# it, so the two never trade places against an empty screen.
			_draw_title(size)
			_draw_splash(size)
		elif phase == Phase.TITLE:
			_draw_title(size)
		elif phase == Phase.SOLO:
			_draw_solo(size)
		elif phase == Phase.LOBBY:
			_draw_lobby(size)
		elif phase == Phase.PRACTICE:
			_draw_practice(size)
		elif phase == Phase.MASTERY:
			_draw_mastery(size)
		elif phase == Phase.COSMETICS:
			_draw_cosmetics(size)
		elif phase == Phase.BOARDS:
			_draw_boards(size)
		elif phase == Phase.WEEKLY:
			_draw_weekly(size)
		elif phase == Phase.SETTINGS:
			_draw_settings(size)
		elif phase == Phase.COUNTDOWN:
			_draw_countdown(size)
		elif phase == Phase.OVER:
			_draw_gameover(size)
			# Between the two on purpose: over the scoreboard, which it sits
			# below anyway, and under the rematch card, which is a question and
			# owns the screen while it is up.
			_draw_summary_emotes(size)
			# Over the summary rather than inside it, and last, so nothing the
			# scoreboard draws lands on top of the question.
			_draw_rematch_popup(size)

		# Last, so it sits over whatever the screen drew — several of these paint
		# a full-width header straight through the corner it lives in.
		if portrait:
			_draw_scrollbar(size)
			_draw_back_button()

		# Over the title screen and its scrollbar, because it is a card and the
		# title screen is what it is standing in front of. Inside this branch
		# rather than beside the invite banner below: `_promo_up` already refuses
		# any phase but TITLE and SPLASH, and a pitch that could be drawn over a
		# match would be one `_promo_up` edit away from being drawn over one.
		_draw_promo(size)

	# Over every screen, for the same reason the curtain is: an invitation can
	# arrive on any of them, and a banner drawn per-branch is a banner missing
	# from whichever branch nobody thought of. Under the curtain, because an ad
	# break covers the game and the banner is part of the game.
	_draw_invite_banner(size)

	# Over absolutely everything, playfield and menus alike. The `return` that
	# used to end the PLAY branch is an `else` now for exactly this: the curtain
	# has to be the last thing drawn on every screen a break can arrive on, and
	# two call sites is how one of them ends up forgotten.
	_draw_ad_curtain(size)


## The curtain an ad break arrives behind.
##
## Deliberately plain. This is the one screen in the game whose whole job is to
## say "this was on purpose and you have not lost anything" — a busy card would
## be read as another part of the advert, and the wordmark would be the game
## appearing to introduce it. A heading, a promise about what is behind it, and a
## bar that visibly fills so the wait reads as a countdown rather than a hang.
func _draw_ad_curtain(size: Vector2) -> void:
	var a := _curtain_alpha()
	if a <= 0.0:
		return
	var cx := size.x * 0.5
	var cy := size.y * 0.5
	# Eased, so the cover arrives fastest in the middle rather than creeping in
	# and out at the ends where it is most visible as a fade.
	var cover: float = a * a * (3.0 - 2.0 * a)
	_overlay.draw_rect(Rect2(-SHAKE_MARGIN, -SHAKE_MARGIN,
		size.x + SHAKE_MARGIN * 2.0, size.y + SHAKE_MARGIN * 2.0),
		Color(bg_top, cover * 0.99), true)

	# The words only once it is dark enough for them to be the brightest thing on
	# screen; printed over a half-faded playfield they read as an overlay bug.
	var ink: float = clampf((a - 0.55) / 0.45, 0.0, 1.0)
	if ink <= 0.0:
		return
	_otext(_font_bold, Vector2(cx, cy - _read_size(16)), "AD BREAK",
		_read_size(20), Color("#e6ecff", ink))
	_text_fit_overlay(_font, Vector2(cx, cy + _read_size(10)), _curtain_note,
		_read_size(13), size.x - GRID_MARGIN * 4.0, Color("#8d99bd", ink))

	# How far through the announcement we are. Full by the time the break is
	# asked for, and held there while it is up — a bar that restarts or empties
	# would be claiming to know how long an advert lasts, which nothing here does.
	var bw: float = minf(260.0, size.x - GRID_MARGIN * 4.0)
	var by: float = cy + _read_size(34)
	var fill := 1.0
	if _curtain == Curtain.CLOSING:
		fill = clampf(_curtain_t * 0.5, 0.0, 1.0)
	elif _curtain == Curtain.HOLDING:
		fill = clampf(0.5 + _curtain_t * 0.5, 0.0, 1.0)
	_overlay.draw_rect(Rect2(cx - bw * 0.5, by, bw, 3.0),
		Color("#2a3355", ink), true)
	_overlay.draw_rect(Rect2(cx - bw * 0.5, by, bw * fill, 3.0),
		Color(PLAYER_ACCENT, ink), true)


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
	# A painted board is allowed to show through here.
	#
	# At the flat 0.90 every menu wears, Clouds' sky and Forest's waterfall
	# arrived as a uniform navy rectangle — the board somebody paid for was
	# visible during a match and nowhere else, and the front door of the game
	# was the one screen that never showed it. 0.66 is as far as it goes: the
	# plates are opaque and stay readable at any wash, but the band labels
	# above them are small grey type sitting directly on the backdrop, and they
	# are what sets the floor.
	#
	# Only the title. The dense screens — mastery, cosmetics, settings — keep
	# their heavier wash, because those are read rather than looked at and a
	# waterfall behind a table of numbers is a worse table.
	_overlay.draw_rect(Rect2(-SHAKE_MARGIN, -SHAKE_MARGIN,
		size.x + SHAKE_MARGIN * 2.0, size.y + SHAKE_MARGIN * 2.0),
		Color(bg_top, 0.66 if _art != null else 0.90), true)
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


## Sound, effects, and the receipt. Every row is a slider, a switch or a button,
## and every one of them writes straight through to the profile — there
## is no apply button, because a settings screen that can be wrong until you
## confirm it is a settings screen that will be left wrong.
func _draw_settings(size: Vector2) -> void:
	var cx := size.x * 0.5
	_overlay.draw_rect(Rect2(-SHAKE_MARGIN, -SHAKE_MARGIN,
		size.x + SHAKE_MARGIN * 2.0, size.y + SHAKE_MARGIN * 2.0),
		Color(bg_top, 0.94), true)
	_draw_decor()

	_otext(_font_bold, Vector2(cx, safe_top + 78.0 + _menu_offset(_settings_laid())),
		"SETTINGS", 32, Color("#e6ecff"))

	for row: Dictionary in _settings_rows():
		var r: Rect2 = row["rect"]
		var hot: bool = String(_hover_action).begins_with(String(row["action"]))
		_panel(r, Color("#141b33"), Color(PLAYER_ACCENT, 0.3 if hot else 0.14), 10.0,
			2.0 if hot else 1.0)
		# Left-aligned off the row's own edge rather than centred on a fixed 150px
		# inset. Centring a label inside the left half is a desktop habit: on a
		# phone it floats in the middle of nothing, and the longer notes had to
		# fight the control for the same pixels.
		var pad := r.position.x + 24.0
		# Type grows with the row, or a 15px label sits marooned in the middle of
		# a row two and a half times its natural height. Gentler than the row's
		# own factor on purpose: the row is a touch target and wants every unit
		# it can get, while the text only has to stay in proportion to it.
		var ts: float = clampf(_settings_fill() / 1.35, 1.0, 1.4)
		# A row with nothing under the label centres the label instead of leaving
		# it hanging above the gap where a note would have been. Fullscreen has
		# always been one of these, and Cloud save is one whenever it is working.
		var has_note: bool = String(row["note"]) != ""
		_otext_left(_font_bold,
			Vector2(pad, r.get_center().y - (10.0 * ts if has_note else 0.0)),
			String(row["label"]), int(round(15.0 * ts)), Color("#e6ecff"))
		if has_note:
			_otext_left(_font, Vector2(pad, r.get_center().y + 13.0 * ts),
				String(row["note"]), int(round(11.0 * ts)), Color("#5d6a92"))

		# Sized for a thumb in portrait and a cursor otherwise. The row has always
		# been the hit area, so this is about the control looking like something
		# worth aiming at rather than about whether it can be hit.
		var touch := portrait

		match String(row["kind"]):
			"slider":
				var track := _settings_track(r)
				_panel(track, Color("#0e142a"), Color(PLAYER_ACCENT, 0.2),
					track.size.y * 0.5, 1.0)
				var v: float = float(row["value"])
				_overlay.draw_rect(Rect2(track.position + Vector2(2, 2),
					Vector2((track.size.x - 4.0) * v, track.size.y - 4.0)),
					Color(PLAYER_ACCENT), true)
				_overlay.draw_circle(
					Vector2(track.position.x + 2.0 + (track.size.x - 4.0) * v,
						track.get_center().y), (13.0 * ts) if touch else 7.0,
					Color("#e6ecff"))
				_otext(_font_bold, Vector2(r.end.x - 44.0, r.get_center().y),
					"%d%%" % int(round(v * 100.0)), int(round(14.0 * ts)),
					Color("#8d99bd"))
			"toggle":
				var on: bool = bool(row["value"])
				# Scaled with the row for the same reason the type is: a switch at
				# its natural size looks stranded in a row two and a half times
				# taller than the one it was drawn for.
				var sh: float = (40.0 * ts) if touch else 28.0
				var swid: float = (104.0 * ts) if touch else 92.0
				var sw := Rect2(r.end.x - swid - 40.0, r.get_center().y - sh * 0.5,
					swid, sh)
				_panel(sw, Color("#1f8a70") if on else Color("#2a3355"),
					Color(PLAYER_ACCENT if on else Color("#4d5878"), 0.8),
					sh * 0.5, 1.0)
				# Knob and word are derived from the pill rather than written out,
				# so the two sizes cannot drift apart the way three hardcoded
				# offsets did.
				var knob := sh * 0.5 - 6.0
				_overlay.draw_circle(Vector2(
					sw.end.x - knob - 6.0 if on else sw.position.x + knob + 6.0,
					sw.get_center().y), knob, Color("#e6ecff"))
				var lane := (swid - knob * 2.0 - 12.0) * 0.5
				_otext(_font_bold, Vector2(
					sw.position.x + lane + 6.0 if on else sw.end.x - lane - 6.0,
					sw.get_center().y), "ON" if on else "OFF",
					int(round(11.0 * ts)),
					Color("#e6ecff") if on else Color("#7c88ad"))
			"action":
				# A button rather than a switch, because these do something once
				# rather than hold a state. Greyed when there is nothing to press —
				# the store still loading, or the pack already owned — so the row
				# stays where it is instead of appearing and disappearing.
				var live: bool = bool(row["value"])
				var btn := Rect2(r.end.x - 176.0, r.get_center().y - 18.0, 140.0, 36.0)
				_panel(btn, Color("#1b2444") if live else Color("#121930"),
					Color(PLAYER_ACCENT if live else Color("#4d5878"),
						0.8 if live else 0.3), 8.0, 2.0 if live else 1.0)
				_text_fit_overlay(_font_bold, btn.get_center(),
					String(row.get("action_label", "")), 15, btn.size.x - 16.0,
					Color("#e6ecff") if live else Color("#4d5878"))

	for b: Dictionary in _menu_buttons():
		_draw_menu_button(b)

	var rows := _settings_rows()
	var sfoot := _grid_bottom(
		[(rows[rows.size() - 1] as Dictionary)["rect"]], 502.0) + 66.0
	_text_fit_overlay(_font, Vector2(cx, sfoot),
		"tap a slider or switch" if portrait
		else "click a slider or switch · ESC back",
		12, size.x - GRID_MARGIN * 2.0, Color("#5d6a92"), 10)

	# Where the record lives, so it can be backed up or moved between machines
	# without anyone having to guess at Godot's user directory. Loud and red if
	# something is wrong with it, because the one thing worse than losing a
	# profile is not being told until it is too late to rescue.
	#
	# The path is desktop-only. On a phone it globalizes to a sandbox container —
	# an unreadable UUID under /var/mobile that the player cannot open, copy or
	# do anything else with — so it was a line of noise under the last row on the
	# one platform where screen space is scarce. The failure warning stays on
	# both: losing a profile in silence is worth shouting about anywhere.
	if Profile.read_failed:
		_text_fit_overlay(_font_bold, Vector2(cx, sfoot + 20.0),
			"YOUR PROFILE COULD NOT BE READ — NOTHING IS BEING SAVED THIS SESSION",
			13, size.x - GRID_MARGIN * 2.0, Color("#ff6b6b"), 10)
	elif not portrait:
		_text_fit_overlay(_font, Vector2(cx, sfoot + 20.0),
			ProjectSettings.globalize_path(Profile.save_path), 11, size.x - 80.0,
			Color("#3d4666"), 9)

func _settings_defs() -> Array:
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
	# Tablets only, for the same reason: a phone cannot usefully split a
	# keyboard it can already reach across, so the row would be a switch between
	# one layout and one that does not fit. On a tablet both answers are real —
	# thumbs at the edges if you are holding it, ten fingers if you have set it
	# down — and which one a player wants is a fact about their hands that the
	# game has no way to measure.
	if tablet:
		defs.append(["split_keys", "toggle", "Split keyboard",
			"two halves at the edges, for thumbs",
			bool(Profile.pref("split_keys"))])
	else:
		defs.append(["fullscreen", "toggle", "Fullscreen", "",
			bool(Profile.pref("fullscreen"))])
	# Only where there is something to switch. On a build with no notification
	# plugin this row could not do anything either way, and a dead switch in
	# settings is worse than a setting that is not offered.
	#
	# The note is `Notify.status()` rather than a fixed line. When everything is
	# working it says what will actually arrive, because "Reminders" on its own
	# is a promise of unknown size and the honest answer is a better argument for
	# leaving it on than anything vaguer. When it is *not* working it says which
	# of the four reasons it is — and the two most likely are fixed by the player
	# in iOS Settings, which is a thing they can only do if somebody tells them.
	if Notify.available():
		defs.append(["notify", "toggle", "Daily reminders", Notify.status(),
			Notify.enabled()])
	# There was a name field here, labelled "shown to other players". It was not
	# shown to anybody. It belonged to the netfox lobby, where a typed name was
	# sent in the handshake; the Game Center path never sends it and never did —
	# an opponent's board carries their Apple display name, which they set once
	# for every game they own and cannot be asked for again here.
	#
	# So it was a text field asking for something the game had no use for, and
	# the only on-screen keyboard outside a match, for a value nobody would ever
	# see. `Link.my_name` and its save are untouched, because `net_link.gd` is
	# still compiled in.
	# The store rows, which used to be one test button that handed the pack over
	# for free. There is a receipt in front of them now.
	#
	# Both are shown on any device with a store, including when the pack is
	# already owned — Apple requires a restore control to be reachable, and a row
	# that vanishes once bought is a row somebody on a new phone cannot find.
	if Store.available():
		var owned: bool = Profile.owns(Profile.PACK_PREMIUM)
		defs.append(["buy", "action",
			"Premium pack" if not owned else "Premium pack — owned",
			"no ad break, and three things you cannot earn" if not owned
				else "thank you", Store.can_buy(),
			Store.price if Store.can_buy() else _store_note(owned)])
		defs.append(["restore", "action", "Restore purchases",
			"if you have bought it before, or on a new phone", true, "RESTORE"])

	# The cloud save. A button and nothing else while it is working.
	#
	# The row used to report when it last synced and how much was up there. Both
	# went: the size was a number nobody can act on, and the time was UTC, so it
	# was confidently wrong for most of the people reading it. Reporting the
	# wrong hour is worse for trust than reporting nothing, on the one feature
	# whose entire job is to be trusted.
	#
	# `Cloud.note` still speaks when the button cannot work — not signed in, or
	# failed — because a dead control with no reason beside it is the confusing
	# version of this row.
	if Cloud.available():
		defs.append(["cloud", "action", "Cloud save", Cloud.note(), Cloud.can_sync(),
			"SYNC" if Cloud.state != Cloud.State.SYNCING else "…"])

	# The old test button is gone and stays gone:
	#
	# It cost more than it was worth the moment ads became real. One of the three
	# things the pack buys is no ad break, and the button is two taps away from
	# the volume sliders — so a tap made months ago, while looking for something
	# else, presents later as a game whose ads have quietly stopped working, with
	# nothing on any screen to say why. That is not a hypothetical; it is how the
	# first play-test of the break went.
	#
	# Everything behind it stays: `PACK_PREMIUM`, `grant`, `revoke`, `owns`,
	# `ads_removed` and the three cosmetics are untouched, so wiring StoreKit up
	# is adding this row back with a receipt in front of it.
	return defs

## One table for drawing and hit-testing both, so a control that is on screen is
## always a control that responds.
## The word on the premium button when there is nothing to press: owned already,
## or the store still deciding. Never blank — a dead button with no label reads
## as a rendering fault rather than as a state.
func _store_note(owned: bool) -> String:
	if owned:
		return "OWNED"
	match Store.state:
		Store.State.LOADING:
			return "…"
		Store.State.BUYING:
			return "…"
		Store.State.FAILED:
			return "N/A"
	return "N/A"


func _settings_rows() -> Array:
	var cx := get_viewport_rect().size.x * 0.5
	var defs := _settings_defs()
	var out: Array = []
	# 720 was the row width and 720 is also the whole of a portrait screen, so
	# the rows ran edge to edge with no margin at all. Capped by the screen now.
	var rw: float = minf(720.0, get_viewport_rect().size.x - GRID_MARGIN * 2.0)
	for i in defs.size():
		var d: Array = defs[i]
		out.append({
			"rect": Rect2(cx - rw * 0.5,
				124.0 + safe_top + _menu_offset(_settings_laid())
					+ float(i) * 66.0 * _settings_fill(),
				rw, 54.0 * _settings_fill()),
			"action": "set:" + String(d[0]),
			"kind": String(d[1]), "label": String(d[2]), "note": String(d[3]),
			"value": d[4],
			# Only the `action` rows carry a sixth: the word on the button.
			"action_label": String(d[5]) if d.size() > 5 else "",
		})
	return out


## Settings is a plain list, so it scales and scrolls like one.
##
## The factor is measured against the screen rather than fixed, which is the one
## place this screen should differ from `_menu_fill`. That returns a flat 1.3
## because the screens using it can overflow and scroll, so growing rows to fit
## would size them for the window instead of for a thumb. Settings cannot
## overflow — six rows on a 1440-tall phone is the whole of it, ever — so there
## is a known amount of room and no reason to leave it empty.
##
## A flat 1.35 left the list ending around 55% down the screen with a band of
## nothing under it, and made each row 73 units tall. At the 720-unit portrait
## design width that is about 39pt on a 390pt phone, under Apple's 44pt floor.
## Filling the space fixes both at once.
func _settings_fill() -> float:
	if not portrait:
		return 1.0
	var n := float(_settings_defs().size())
	if n <= 0.0:
		return 1.35
	# Measured from where the rows actually start, not from `_menu_offset`'s
	# notion of a top — this screen puts its title at 78 and its first row at
	# 124, and the two have never agreed.
	var avail: float = get_viewport_rect().size.y - safe_bottom \
		- (124.0 + safe_top) - SETTINGS_FOOT
	# The floor is what it used to be, so nothing can come out smaller than it
	# was. The cap stops a two-row list from becoming two slabs the size of a
	# hand, which is the failure `_menu_fill` was written to avoid.
	return clampf(avail / ((n - 1.0) * 66.0 + 54.0), 1.35, 2.6)


func _settings_laid() -> float:
	return float(_settings_defs().size()) * 66.0 * _settings_fill() + 150.0


## The slider's track. One definition, because the drawing and the click that
## sets the value have to agree about where it starts and how long it is — and
## it is no longer a constant now that the row width follows the screen.
func _settings_track(r: Rect2) -> Rect2:
	# The label column is a proportion of the row now rather than a flat 300px.
	# Fixed, it ate most of a narrow phone row and pushed the track onto its
	# 120px floor, which is a slider you cannot set accurately with a thumb.
	var x := r.position.x + minf(300.0, r.size.x * 0.44)
	# Thickens with the row, matching the thumb and the type.
	var h: float = (12.0 * clampf(_settings_fill() / 1.35, 1.0, 1.4)) \
		if portrait else 8.0
	return Rect2(x, r.get_center().y - h * 0.5, maxf(120.0, r.end.x - 100.0 - x), h)


## A click on a settings row. Sliders take their new value from where along the
## track you clicked, which is one gesture rather than the drag-and-release a
## real handle would need — and for six rows of preferences, a handle is more
## machinery than the job is worth.
func _change_setting(key: String) -> void:
	# Everything past this point belongs to Apple until its sheet comes down.
	# Both are no-ops off a device, so a desktop build can walk over the rows
	# without pretending anything happened.
	if key == "buy":
		if Store.can_buy():
			Store.buy()
			Sfx.play("count", 1.3)
		else:
			Sfx.play("reject", 1.2)
		return
	if key == "restore":
		Store.restore()
		Sfx.play("key", 1.2)
		return
	if key == "cloud":
		if Cloud.can_sync():
			Cloud.sync_now()
			Sfx.play("key", 1.2)
		else:
			Sfx.play("reject", 1.2)
		return
	if key == "notify":
		# Not a plain pref flip. Switching this on for the first time is what
		# raises the iOS permission dialog, and the row must read off until that
		# comes back granted — `Notify.enabled()` wants both our switch and the
		# system's, so a player who says "Don't Allow" sees the toggle stay off
		# rather than a switch that claims to be on and sends nothing.
		Notify.set_enabled(not Notify.enabled())
		Sfx.play("count", 1.3 if Notify.enabled() else 0.9)
		return
	if key == "texture" or key == "hitstop" or key == "fullscreen" or key == "censor" \
			or key == "haptics" or key == "split_keys":
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
		# Only a press on the track moves a slider.
		#
		# The whole row is the hit area, and the value was clamped from wherever
		# the press landed — so a tap on the word "Music", which is most of the
		# left half of the row on a phone, resolved to zero and silently muted
		# the game. There was no way to tell that from the slider simply not
		# working. Missing the track now does nothing at all, which is what every
		# other settings list on the platform does.
		var grab := 28.0 if portrait else 12.0
		if at < track.position.x - grab or at > track.end.x + grab:
			return
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
	return _menu_fill(PRACTICE_NATURAL, 1.7)


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


# ----------------------------------------------------------------- versus
#
# Versus has no screen of its own any more, and the reason is that Apple's does
# the job better. Its matchmaking sheet carries quick match *and* invite-a-friend
# on one screen, and the invite half texts a link to any contact — reaching
# people who are not Game Center friends, which nothing else in the API can do.
#
# What kept us off it was that the sheet would not close: the plugin never
# dismissed it when a match was found, so the game started underneath where
# nobody could see it. That is fixed upstream and verified on a device, so the
# door goes straight there. Our own screen was three doors, two of which were
# Apple's two doors done worse, and a friend picker Apple returns almost nobody
# for.
#
# What is left here is the one line the title plate says about itself, because a
# search can still be running while the player is back on the title screen and
# nothing else would say so.

## Anything Game Center is in the middle of.
func _versus_busy() -> bool:
	return MultiplayerManager.state in [
		MultiplayerManager.State.MATCHMAKING,
		MultiplayerManager.State.CONNECTING,
		MultiplayerManager.State.HANDSHAKING]


# ------------------------------------------------------- the first word
#
# The single most common thing a new player gets wrong, and it is not a rule
# they got backwards — it is a rule they invented. They watch the board, wait
# for a block with letters on it, and type a word that answers it. Which works,
# and is a third of the game played at a third of the speed, and reads as a game
# that is mostly waiting.
#
# Nothing on the screen ever told them otherwise. The board is the only thing
# with letters on it, so the board looks like the input. That the whole
# dictionary is available at every moment, blocks or no blocks, is the premise
# the rest of the scoring is built on and it was never said out loud anywhere
# except in a tutorial step that talks about something else.
#
# So it is said, once, in the middle of the board where it cannot be missed.

## How long the prompt takes to arrive and to leave.
##
## It fades in rather than appearing, because the first second of a match is
## already a countdown clearing and a board dealing, and one more thing snapping
## into existence in the middle of that is noise. It leaves faster than it
## arrives: by then it has either worked or been read.
const FIRST_WORD_IN := 0.45
const FIRST_WORD_OUT := 0.35
## How long it stays if nothing is typed at all.
##
## Long enough to be read twice by somebody who is reading it, short enough that
## it is gone before it becomes part of the furniture. A player who never types
## has a bigger problem than this prompt can fix.
const FIRST_WORD_HOLD := 6.0


## The prompt over the middle of the board, while the player has yet to type.
##
## Self-limiting by construction, which is what makes it safe to show on every
## match rather than only to somebody the profile thinks is new. It is keyed to
## `words_played == 0`: a player who knows what they are doing types inside the
## first second and never finishes reading it, and one who is waiting for
## permission gets the sentence they were waiting for. Nobody is counted, nobody
## is graduated, and there is no setting to get wrong.
##
## Never in the tutorial, which is a screen already dedicated to saying what to
## do next and does not need a second voice over the top of it.
func _draw_first_word_prompt() -> void:
	if mode == Mode.TUTORIAL or not player.alive or paused:
		return
	if player.words_played > 0 and _first_word_fade <= 0.0:
		return

	var age := match_time
	var alpha := clampf(age / FIRST_WORD_IN, 0.0, 1.0)
	if player.words_played > 0:
		# Typed. It goes on the word rather than on a clock, which is the whole
		# point: the thing it was asking for has happened.
		alpha = clampf(_first_word_fade / FIRST_WORD_OUT, 0.0, 1.0)
	elif age > FIRST_WORD_HOLD:
		alpha = clampf(1.0 - (age - FIRST_WORD_HOLD) / FIRST_WORD_OUT, 0.0, 1.0)
	if alpha <= 0.01:
		return

	# Faded on purpose and faded twice over: the copy is under half opacity even
	# at full strength, because this is drawn across a live playfield and a
	# legible instruction is not worth a board you cannot read behind it.
	var r := _board_rect(player)
	var mid := r.get_center()
	var wide: float = r.size.x * 1.25
	var big := _read_size(22)
	var small := _read_size(14)
	_text_fit_overlay(_font_bold, Vector2(mid.x, mid.y - 12.0),
		"TYPE ANY WORD", big, wide, Color("#e6ecff", 0.62 * alpha))
	_text_fit_overlay(_font, Vector2(mid.x, mid.y + 18.0),
		"you do not have to wait for blocks", small, wide,
		Color("#7bdff2", 0.55 * alpha))


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
		# The centre column exists in landscape because the rival board is not
		# using it. On a phone there is no centre column — the board is in the
		# middle of the screen — and this card was being painted straight across
		# the playfield, over the stack it is reporting on. The portrait header
		# already carries the clock, the score and the lives, which is all of
		# this card that is not the date.
		if portrait:
			return
		var left := daily_left()
		_otext(_font_bold, Vector2(cx, 300.0), "DAILY SPRINT", 16, Color("#ffd166"))
		_otext(_font, Vector2(cx, 322.0), daily_key(), 11, Color("#5d6a92"))
		var rows2 := [
			["TIME LEFT", _daily_clock(left)],
			["SCORE", _commas(player.score)],
			["BEST CHAIN", "x%d" % player.best_chain],
			["LIVES", str(player.lives)],
		]
		var y2 := 356.0
		for r: Array in rows2:
			_otext_pair(_font, _font_bold, Vector2(cx, y2), r[0], r[1], 11, 16,
				Color("#5d6a92"),
				Color("#ff6b6b") if (r[0] == "TIME LEFT" and left <= DAILY_ALARM)
					else Color("#e6ecff"), 30.0)
			y2 += 28.0
		_otext(_font, Vector2(cx, y2 + 14.0), "one run — no second go", 11,
			Color("#4d5878"))
		return

	if mode == Mode.SURVIVAL:
		# Same reasoning as the daily's, one screen up: in portrait the header
		# already carries the clock, the score and the lives, and this card would
		# be painted across the playfield it is reporting on.
		if portrait:
			return
		_otext(_font_bold, Vector2(cx, 300.0), "SURVIVAL", 16, SURVIVAL_ACCENT)
		_otext(_font, Vector2(cx, 322.0), "no clock — last as long as you can", 11,
			Color("#5d6a92"))
		var rows3 := [
			["SURVIVED", _survival_clock(match_time)],
			["SCORE", _commas(player.score)],
			["BEST CHAIN", "x%d" % player.best_chain],
			["LIVES", str(player.lives)],
		]
		var y3 := 356.0
		for r: Array in rows3:
			_otext_pair(_font, _font_bold, Vector2(cx, y3), r[0], r[1], 11, 16,
				Color("#5d6a92"), Color("#e6ecff"), 30.0)
			y3 += 28.0
		# What there is to beat, while there is still time to beat it. A record
		# you are only told about afterwards is not something you can play towards.
		if Profile.survival_best_time > 0.0:
			_otext(_font, Vector2(cx, y3 + 14.0),
				"best %s" % _survival_clock(Profile.survival_best_time), 11,
				Color("#ffd166") if match_time > Profile.survival_best_time
					else Color("#4d5878"))
		return

	if mode == Mode.TRAINING:
		# In portrait this is floating over the top of the board rather than in a
		# centre column, which is a reason for it to be readable at a glance and
		# not a reason for it to be small — a drill you cannot read your own
		# figures on is not a drill.
		var lab := _read_size(11)
		var num := _read_size(16)
		_otext(_font_bold, Vector2(cx, 300.0), "TRAINING", num, Color("#7bdff2"))
		var rows := [
			["CLEARED", str(player.blocks_cleared)],
			["BEST CHAIN", "x%d" % player.best_chain],
			["WPM", str(int(round(_wpm())))],
			["PACE", String(TRAINING_PACE[train_pace]["name"]).to_upper()],
		]
		var y: float = 332.0 if not portrait else 348.0
		for r: Array in rows:
			_otext_pair(_font, _font_bold, Vector2(cx, y), r[0], r[1], lab, num,
				Color("#5d6a92"), Color("#e6ecff"), 30.0)
			y += 28.0 if not portrait else 42.0
		_otext(_font, Vector2(cx, y + 14.0),
			"tap the corner to stop" if portrait else "ESC to stop", lab,
			Color("#4d5878"))
		return

	var step: Dictionary = Tutorial.step(lesson, portrait)
	if step.is_empty():
		return

	# Two settings for the same card, not one setting scaled.
	#
	# A phone draws in a 720-wide design space against the desktop's 1280, so
	# every size here was worth a little over half as much on the device the game
	# actually ships to: the lesson body, set at 14, came out at about seven
	# points on an iPhone — under half what Apple calls a readable minimum, and
	# the first thing anybody said about the tutorial. Portrait gets its own
	# numbers rather than a multiplier, because the card has to grow to hold them
	# and the two have to be chosen together.
	var t_size: int = 30 if portrait else 21
	var b_size: int = 24 if portrait else 14
	var h_size: int = 21 if portrait else 12
	var s_size: int = 17 if portrait else 11
	var c_size: int = 24 if portrait else 15
	var step_off: float = 34.0 if portrait else 26.0
	var title_off: float = 78.0 if portrait else 54.0
	var body_off: float = 122.0 if portrait else 90.0
	var foot: float = 36.0 if portrait else 26.0

	# The body is wrapped by the font to the card it is actually in, so the copy
	# in `tutorial.gd` is written as sentences rather than as lines broken by hand
	# at whatever width the landscape card used to be.
	var body := String(step["body"])
	var body_w: float = wide - (72.0 if portrait else 36.0)
	var body_h: float = _font.get_multiline_string_size(
		body, HORIZONTAL_ALIGNMENT_CENTER, body_w, b_size).y

	# Tall enough for what is in it. The card was a fixed 214 and the type it now
	# carries does not fit in that on a phone.
	var h: float = body_off + body_h + foot * 2.0 + (14.0 if portrait else 10.0)
	# Straight across the middle of the board, which is a deliberate reversal.
	#
	# It used to be tucked wherever it could go without covering anything: the
	# rival column in landscape, the gap under the header on a phone. That is
	# the polite arrangement and it is the wrong one. A first-time player is
	# looking at the board — it is the only thing on the screen that moves — and
	# a lesson parked beside it is a lesson in their peripheral vision, being
	# read second if at all. Several people worked out what to do by
	# experimenting on the board while the card that said it sat unread above.
	#
	# There is nothing under this card worth protecting. Every step builds the
	# board it wants in `_lesson_begin`, so what is hidden is a pile the lesson
	# put there and is about to talk about; and the step ends when the player
	# acts, which means they have to have read it.
	var br := _board_rect(player)
	var mid := br.get_center()
	cx = mid.x
	# Wider than the board, because a board is six cells across and a sentence is
	# not. Held inside the screen with a margin either side.
	wide = clampf(wide, br.size.x, size.x - GRID_MARGIN * 2.0)
	var top: float = mid.y - h * 0.5
	var r := Rect2(cx - wide * 0.5, top, wide, h)
	_panel(r, Color("#111730"), Color("#90be6d", 0.4), 12.0, 2.0)
	_otext(_font, Vector2(cx, top + step_off),
		"STEP %d OF %d" % [lesson + 1, Tutorial.count()], s_size, Color("#5d6a92"))
	_text_fit_overlay(_font_bold, Vector2(cx, top + title_off), String(step["title"]),
		t_size, wide - 40.0, Color("#e6ecff"))

	_overlay.draw_multiline_string(_font,
		Vector2(cx - body_w * 0.5, top + body_off + _font.get_ascent(b_size)),
		body, HORIZONTAL_ALIGNMENT_CENTER, body_w, b_size, -1, Color("#aab4d4"))

	if lesson_done or String(step["id"]) == "done":
		var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 200.0)
		_otext(_font_bold, Vector2(cx, r.end.y - foot),
			"TAP FIRE TO CONTINUE" if portrait else "SPACE TO CONTINUE", c_size,
			Color("#90be6d") * Color(1, 1, 1, pulse))
	else:
		_text_fit_overlay(_font, Vector2(cx, r.end.y - foot), _lesson_hint(step),
			h_size, wide - 36.0, Color("#7c88ad"))

	# A row of pips, so five steps reads as a short thing with an end to it.
	var pip: float = 16.0 if portrait else 10.0
	var pgap: float = 8.0 if portrait else 6.0
	var span := Tutorial.count() * pip + (Tutorial.count() - 1) * pgap
	for i in Tutorial.count():
		_overlay.draw_rect(Rect2(cx - span * 0.5 + i * (pip + pgap), r.end.y + 16.0,
			pip, 6.0 if portrait else 4.0),
			Color("#90be6d") if i <= lesson else Color("#2a3355"), true)

	# The way back to the start, on the last step only.
	#
	# A tutorial is read once and understood at whatever rate it is understood,
	# and the player who most needs a second run is exactly the one least likely
	# to go looking for the door: they have just been told this is the whole
	# game and they are not sure it was. Offering it here costs one button on one
	# step, and the alternative is finding PRACTICE from a title screen you have
	# not learned yet.
	#
	# Stored rather than recomputed for the hit test. The rect depends on where
	# the body happened to wrap, and the one thing worse than a button that is
	# hard to find is a button whose target is not where it is drawn.
	_lesson_restart = Rect2()
	if String(step["id"]) != "done":
		return
	var bw: float = minf(wide * 0.62, 420.0)
	var bh: float = 64.0 if portrait else 40.0
	var bar := Rect2(cx - bw * 0.5, r.end.y + 34.0, bw, bh)
	_lesson_restart = bar
	# No hover state: `_hover_action` is a menu idea and this is drawn during
	# PLAY, where `_action_at` is never consulted. A steady border rather than
	# one that pretends to respond.
	_panel(bar, Color("#141b33"), Color("#7bdff2", 0.45), 10.0, 2.0)
	_text_fit_overlay(_font_bold, bar.get_center() + Vector2(0.0, 6.0),
		"RUN IT AGAIN" if portrait else "R — RUN IT AGAIN",
		_read_size(15), bw - 24.0, Color("#7bdff2"))


## Who you are lining up against. Deliberately shaped like the versus lobby:
## seats along the top, and a roster underneath that fills whichever seat you
## have picked. Choosing an opponent was the title screen's job until it had
## seven of them on it — and it never let you choose more than one at a time,
## which made a free-for-all three copies of the same personality.
##
## On a phone it is none of that. A four-seat table, a seat you have to select
## before the roster means anything, and six special-block switches under it was
## a desktop control panel scaled down — three separate things to understand
## before a one-handed player could start a match. Portrait keeps the one
## question worth asking (who) and answers it with cards big enough for a thumb;
## see `_solo_cards` and `_solo_seat_rects`.
func _draw_solo(size: Vector2) -> void:
	var cx := size.x * 0.5
	_overlay.draw_rect(Rect2(-SHAKE_MARGIN, -SHAKE_MARGIN,
		size.x + SHAKE_MARGIN * 2.0, size.y + SHAKE_MARGIN * 2.0),
		Color(bg_top, 0.93), true)
	_draw_decor()

	var hy := safe_top + _menu_offset(_solo_laid())
	_otext(_font_bold, Vector2(cx, hy + 62.0), "SINGLE PLAYER", 32, Color("#e6ecff"))
	_otext(_font, Vector2(cx, hy + 96.0),
		"pick who you are up against" if portrait
			else "add up to three, and pick who they are", 14,
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
				"%d wpm" % AiOpponent.paced_wpm(who, portrait), 11, accent)
		elif not mine and who == "?":
			_otext(_font, Vector2(r.get_center().x, r.position.y + 64.0),
				"rolled each match", 11, Color("#7c88ad"))

	# No header over the roster in portrait: with the seats gone the roster is the
	# only thing on the screen, and the subtitle four lines up already named it.
	if not portrait:
		_otext(_font, Vector2(cx, _solo_roster_top() - 24.0),
			"click a seat, then pick below · %d opponent%s" % [
				_solo_filled(), "" if _solo_filled() == 1 else "s"], 12,
			Color("#5d6a92"))

	for c: Dictionary in _solo_cards():
		var r: Rect2 = c["rect"]
		var hot: bool = _hover_action == String(c["action"])
		var on: bool = String(solo_seats[0 if portrait else solo_pick]) \
			== String(c["id"])
		if hot:
			r = Rect2(r.position - Vector2(0, 3), r.size)
		var accent: Color = c["accent"]
		_panel(r, Color("#1b2444") if hot else Color("#141b33"),
			Color("#ffd166") if on else Color(accent, 0.9 if hot else 0.28),
			14.0 if portrait else 10.0, 3.0 if on else 2.0)
		# Placed off the card's own height rather than at +26/+48, so the taller
		# portrait card carries the pair down with it instead of leaving them
		# huddled at the top. `_text_fit_overlay` shrinks to fit, so raising the
		# starting sizes can only help a card that has the room and costs nothing
		# to one that does not.
		var ny: float = 0.30 if portrait else 0.38
		var oy: float = 0.56 if portrait else 0.72
		_text_fit_overlay(_font_bold,
			Vector2(r.get_center().x, r.position.y + r.size.y * ny),
			String(c["name"]).to_upper(), 26 if portrait else 20, r.size.x - 20.0,
			Color.WHITE if hot else Color("#e6ecff"), 14)
		_text_fit_overlay(_font, Vector2(r.get_center().x, r.position.y + r.size.y * oy),
			String(c["note"]), 15 if portrait else 14, r.size.x - 14.0,
			Color("#8d99bd"), 10)
		# The pace, which used to live on the seat the card filled. With the seat
		# row gone this is the only place left that says how hard a name is going
		# to be, and it is the thing a player is actually choosing between.
		var id := String(c["id"])
		if portrait and id != "?":
			_text_fit_overlay(_font, Vector2(r.get_center().x,
				r.position.y + r.size.y * 0.82),
				"%d wpm" % AiOpponent.paced_wpm(id, portrait), 14, r.size.x - 20.0,
				accent, 10)

	for b: Dictionary in _menu_buttons():
		_draw_menu_button(b)

	if not portrait:
		# Clear of the Back button, which ends at foot + 110.
		_otext(_font, Vector2(cx, _solo_foot() + 132.0),
			"1 / 2 / 3 select a seat · ENTER starts · ESC back", 12, Color("#5d6a92"))


const SOLO_NATURAL := 76.0 + 40.0 + 3.0 * 76.0 + 42.0 + 3.0 * 64.0 + 90.0


func _solo_fill() -> float:
	return _menu_fill(SOLO_NATURAL, 1.45)


func _solo_spread() -> float:
	return _menu_spread(SOLO_NATURAL, 2.0)


## How tall the screen is once it is laid out, measured from the header down to
## the bottom of the Start button.
##
## Counted rather than estimated, because a guess that came out high would put a
## scrollbar on a screen that has nowhere to go. The 176 is `_solo_roster_top`'s
## header block, and the 26 plus the door height is the Start button and its
## lead-in from `_menu_buttons`.
func _solo_laid() -> float:
	var f := _solo_fill()
	var sp := _solo_spread()
	if portrait:
		var rows := ceilf(float(_solo_roster().size()) / 2.0)
		return 176.0 + rows * SOLO_CARD_H + (rows - 1.0) * SOLO_CARD_GAP \
			+ 42.0 * sp + 26.0 + PORTRAIT_DOOR_H
	return 76.0 * f + 40.0 * sp + 2.0 * 66.0 * f + 10.0 * sp \
		+ 42.0 * sp + 2.0 * 56.0 + 90.0


func _solo_seat_rects() -> Array:
	# No table on a phone: one opponent means the row would be you and one other,
	# which says nothing the roster below does not already say.
	if portrait:
		return []
	# Four across at whatever width fits, never wrapped: the point of the row is
	# that it is the table, and a table that goes 3 + 1 stops reading as one.
	# `min_w` of zero is what forbids the wrap.
	return _grid_rects(4, 118.0 + safe_top + _menu_offset(_solo_laid()), 4, 168.0,
		76.0 * _solo_fill(), 12.0, 0.0, 10.0)


## How tall one opponent card is in portrait, and the gap between rows.
##
## Sized off the thumb rather than off the screen — two columns of these at 720
## wide come out around 317 across, so a card is comfortably past Apple's 44pt
## floor in both directions. Four rows of them plus the header and the Start door
## also happen to reach about three quarters of the way down a phone, which is
## what stops the screen looking like it stopped early.
const SOLO_CARD_H := 140.0
const SOLO_CARD_GAP := 16.0


## Everything that can go in a seat: nothing, a random pick, or one of the
## roster. Built from `AiOpponent.ROSTER`, so a new personality appears here the
## moment it exists.
##
## Portrait drops Empty. With one seat instead of four, "leave the seat open" is
## a button for starting a match against nobody — `_solo_lineup` would only put
## the Duelist back in anyway.
func _solo_roster() -> Array:
	var list: Array = []
	if not portrait:
		list.append({"id": "", "name": "Empty", "note": "leave the seat open",
			"accent": Color("#5d6a92")})
	list.append({"id": "?", "name": "Random",
		"note": "rolled at the start of each match", "accent": Color("#ffd166")})
	for name: String in AiOpponent.ROSTER:
		var d: Dictionary = AiOpponent.spec(name)
		list.append({"id": name, "name": name, "note": String(d["style"]),
			"accent": Color(String(d["tint"]))})
	return list


func _solo_cards() -> Array:
	var list := _solo_roster()
	var out: Array = []
	# Two fat columns on a phone against five narrow ones on a desktop. The old
	# portrait grid asked for five columns and a 190 floor, which wrapped to three
	# cards of 190 across — a target the width of a fingertip carrying two lines
	# of text.
	var rects := _grid_rects(list.size(), _solo_roster_top(), 2, 320.0,
		SOLO_CARD_H, SOLO_CARD_GAP, 260.0, SOLO_CARD_GAP) if portrait \
		else _grid_rects(list.size(), _solo_roster_top(), 5, 202.0,
			66.0, 10.0, 190.0, 10.0)
	for i in list.size():
		var e: Dictionary = list[i]
		e["rect"] = rects[i]
		e["action"] = "seat:%s" % String(e["id"])
		out.append(e)
	return out


## Under the seats and the line of instructions beneath them — or, with no seats,
## under the header.
func _solo_roster_top() -> float:
	if portrait:
		return safe_top + _menu_offset(_solo_laid()) + 176.0
	return _grid_bottom(_solo_seat_rects(), 194.0) + 40.0 * _solo_spread()


## The bottom of the last thing on the single-player screen, which the Start and
## Back buttons sit under — the opponent roster, in both orientations.
func _solo_foot() -> float:
	var out := _solo_roster_top()
	for c: Dictionary in _solo_cards():
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
##
## One seat on a phone. The other two are left in `solo_seats` untouched rather
## than cleared, so a player who set up a three-way on a desktop still has it
## when they go back — the phone simply does not read past the first.
func _solo_lineup() -> Array:
	var out: Array = []
	var seats: Array = [solo_seats[0]] if portrait else solo_seats
	for w in seats:
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
## Everything the record says, in one place.
##
## Lifted out of the draw so the layout can count it. The two used to disagree:
## `_mastery_stats_foot` measured twelve tiles against a list of thirteen, so
## the buttons hung off a bottom edge a whole row above the real one.
func _mastery_stats() -> Array:
	return [
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
		# The record rather than the live count. This screen is the record, and a
		# number that goes down when you miss a day does not belong on it.
		["BEST STREAK", "%d day%s" % [Profile.daily_best_streak,
			"" if Profile.daily_best_streak == 1 else "s"]],
	]


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

	var stats := _mastery_stats()
	var strip := _mastery_stat_rects(stats.size())
	for i in stats.size():
		var r: Rect2 = strip[i]
		_panel(r, Color("#141b33"), Color(PLAYER_ACCENT, 0.16), 8.0, 1.0)
		# Proportional in portrait, where the tile is half again as tall and two
		# fixed offsets left the label and value huddled against the top edge
		# with a third of the tile empty under them. Desktop keeps the constants
		# it was drawn with rather than being re-tuned by proportion.
		var mts: float = 1.45 if portrait else 1.0
		var ly: float = (r.size.y * 0.32) if portrait else 18.0
		var vy: float = (r.size.y * 0.66) if portrait else 41.0
		_otext(_font, Vector2(r.get_center().x, r.position.y + ly), stats[i][0],
			int(round(10.0 * mts)), Color("#7c88ad"))
		_text_fit_overlay(_font_bold, Vector2(r.get_center().x, r.position.y + vy),
			stats[i][1], int(round(18.0 * mts)), r.size.x - 20.0, Color("#e6ecff"))

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

	var streak: int = Profile.daily_streak(daily_key())
	if streak > 1:
		_otext(_font, Vector2(cx, _grid_bottom(pw, pfoot) + 34.0),
			"%d daily boards running" % streak, 12, Color("#ffd166"))


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
			# And its picture, and its weather. A painted board previewed as a
			# gradient would be the shop lying about the only thing that makes
			# it worth the money.
			var inner := box.grow(-2.0)
			var pic := _theme_art(id)
			if pic != null:
				var asz := Vector2(pic.get_width(), pic.get_height())
				var want: float = inner.size.x / inner.size.y
				var src := Rect2(Vector2.ZERO, asz)
				if asz.x / asz.y > want:
					src.size.x = asz.y * want
					src.position.x = (asz.x - src.size.x) * 0.5
				else:
					src.size.y = asz.x / want
					src.position.y = (asz.y - src.size.y) * 0.5
				_overlay.draw_texture_rect_region(pic, inner, src,
					Color(1, 1, 1, float(Cosmetics.theme_opt(id, "art_a"))))
				_overlay.draw_rect(inner,
					Color(top, float(Cosmetics.theme_opt(id, "art_dim")) * 0.5), true)
				var mk := String(Cosmetics.theme_opt(id, "motion"))
				if mk != "":
					# Drawn in the box's own space, so an effect written against
					# a whole screen lands inside a preview panel unchanged.
					_overlay.draw_set_transform(inner.position, 0.0, Vector2.ONE)
					Cosmetics.draw_motion(_overlay, mk, inner.size, t,
						Cosmetics.theme_tint(id, "accent", PLAYER_ACCENT), true)
					_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
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
			# Three tiers, so a style is judged on more than one swatch — and so
			# it is obvious that the tier colour survives whatever the style
			# does to it, which is the rule the whole slot lives under.
			var paired := String(Cosmetics.BLOCK_PAIRING.get(id, ""))
			var w: float = box.size.x / 4.2
			var row_y: float = mid.y - w * 0.4 + (8.0 if paired != "" else 0.0)
			for i in 3:
				var rr := Rect2(mid.x - w * 1.65 + float(i) * (w + 8.0),
					row_y, w, w * 0.8)
				var ink := Cosmetics.draw_block_face(_overlay, rr,
					WWBoard.TIER_COLORS[i * 2], id, false)
				_text_fit_overlay(_font_bold, rr.get_center(),
					["AL", "SHIP", "ENT"][i], 15, rr.size.x - 8.0, ink)
			# Said rather than done. The eight premium styles were each drawn
			# against a board, and knowing which one turns eight names into a
			# set — but it stays a note, because the slot is independent and
			# nothing here is going to reach over and change what you equipped.
			if paired != "":
				_otext(_font, Vector2(mid.x, box.end.y - 16.0),
					"drawn for the %s board" % String(
						Profile.entry("theme", paired).get("name", paired)).to_upper(),
					11, Color("#5d6a92"))
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


## This week's four, and how far along each one is.
##
## Deliberately a list and not a grid. Four rows with a bar apiece is a thing
## somebody reads top to bottom in three seconds; a grid of tiles would fit more
## on the screen and there is nothing more to fit — four is the whole set, and
## the screen's job is to make the one that is nearly done obvious.

## Row height and the gap under the header, shared by the layout and the draw so
## the two cannot disagree about where row three is.
const WEEK_ROW_H := 92.0
const WEEK_ROW_GAP := 12.0


func _weekly_head() -> float:
	return safe_top + _menu_offset(_weekly_laid()) + 150.0


func _weekly_laid() -> float:
	return 150.0 + float(Missions.PER_WEEK) * (WEEK_ROW_H + WEEK_ROW_GAP) + 190.0


func _weekly_row_rect(i: int) -> Rect2:
	var size := get_viewport_rect().size
	var w: float = minf(600.0, size.x - GRID_MARGIN * 2.0)
	return Rect2(size.x * 0.5 - w * 0.5,
		_weekly_head() + float(i) * (WEEK_ROW_H + WEEK_ROW_GAP), w, WEEK_ROW_H)


func _draw_weekly(size: Vector2) -> void:
	var cx := size.x * 0.5
	_overlay.draw_rect(Rect2(-SHAKE_MARGIN, -SHAKE_MARGIN,
		size.x + SHAKE_MARGIN * 2.0, size.y + SHAKE_MARGIN * 2.0),
		Color(bg_top, 0.94), true)
	_draw_decor()

	var key := Missions.week_key()
	var hy := safe_top + _menu_offset(_weekly_laid())
	_otext(_font_bold, Vector2(cx, hy + 58.0), "WEEKLY", 34, Color("#e6ecff"))
	# The deadline, said once at the top rather than on every row.
	_otext(_font, Vector2(cx, hy + 92.0),
		"four missions · new set Sunday · %s left" % _weekly_left_text(key),
		13, Color("#7c88ad"))

	var rows := Profile.weekly_state(key)
	var done := 0
	for i in rows.size():
		if bool((rows[i] as Dictionary)["done"]):
			done += 1
		_draw_weekly_row(_weekly_row_rect(i), rows[i])

	# The footer: what the week has paid and what is left to take. A total is
	# the one thing four separate bars cannot say.
	var fy: float = _weekly_head() + float(rows.size()) \
		* (WEEK_ROW_H + WEEK_ROW_GAP) + 26.0
	var owed: int = (Missions.PER_WEEK - done) * Missions.MISSION_XP
	if done >= Missions.PER_WEEK:
		_otext(_font_bold, Vector2(cx, fy), "WEEK CLEARED", 20, Color("#90be6d"))
		_otext(_font, Vector2(cx, fy + 26.0),
			"+%s XP banked · come back Sunday" % _commas(
				Missions.PER_WEEK * Missions.MISSION_XP),
			13, Color("#7c88ad"))
	else:
		_otext(_font_bold, Vector2(cx, fy),
			"%d of %d done" % [done, Missions.PER_WEEK], 20, Color("#ffd166"))
		_otext(_font, Vector2(cx, fy + 26.0),
			"%s XP still on the table" % _commas(owed), 13, Color("#7c88ad"))
	if Profile.weekly_cleared > 0:
		_otext(_font, Vector2(cx, fy + 50.0),
			"%d week%s cleared all-time" % [Profile.weekly_cleared,
				"" if Profile.weekly_cleared == 1 else "s"],
			12, Color("#5d6a92"))

	for b: Dictionary in _menu_buttons():
		_draw_menu_button(b)


## One mission: what it asks, how far along, and whether it is paid.
func _draw_weekly_row(r: Rect2, m: Dictionary) -> void:
	var is_done: bool = bool(m["done"])
	var tint: Color = Color("#90be6d") if is_done else Color("#64dfdf")
	_panel(r, Color("#141b33"), Color(tint, 0.55 if is_done else 0.22), 10.0, 2.0)

	var pad := 18.0
	_otext_left(_font_bold, Vector2(r.position.x + pad, r.position.y + 28.0),
		String(m["text"]), 17, Color("#e6ecff") if not is_done else tint)

	# The bar. Its own numbers under it rather than inside it, because a target
	# of 24,000 does not fit in a bar and the bar is the part that has to be
	# readable at a glance anyway.
	var have := int(m["have"])
	var target: int = maxi(1, int(m["target"]))
	var frac: float = clampf(float(have) / float(target), 0.0, 1.0)
	var bar := Rect2(r.position.x + pad, r.position.y + 46.0,
		r.size.x - pad * 2.0, 12.0)
	_overlay.draw_rect(bar, Color("#0b1020"), true)
	if frac > 0.0:
		_overlay.draw_rect(Rect2(bar.position,
			Vector2(bar.size.x * frac, bar.size.y)), Color(tint, 0.85), true)
	_overlay.draw_rect(bar, Color(tint, 0.30), false, 1.0)

	_otext_left(_font, Vector2(r.position.x + pad, r.position.y + 74.0),
		"%s / %s" % [_commas(have), _commas(target)], 12,
		Color("#7c88ad"))
	# The payout, right-aligned, greyed once it has been taken — a finished
	# mission that still advertises its price reads as unclaimed.
	var tag := "+%d XP" % Missions.MISSION_XP if not is_done else "EARNED"
	var tw: float = _font_bold.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT,
		-1, 13).x
	_otext_left(_font_bold, Vector2(r.end.x - pad - tw, r.position.y + 74.0),
		tag, 13, tint if is_done else Color("#ffd166"))


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
	return _menu_fill(MASTERY_NATURAL, 1.5)


func _mastery_spread() -> float:
	return _menu_spread(MASTERY_NATURAL, 2.2)


func _mastery_laid() -> float:
	var f := _mastery_fill()
	var sp := _mastery_spread()
	# Asked, not assumed. These were 3 and 2 on a phone, written when the record
	# was shorter, and thirteen tiles at four columns is four rows — so the
	# screen reported a height a row short of itself and the last of the record
	# sat below where anything could scroll to.
	var rows := float(_grid_rows(_mastery_stats().size(), 8, 8.0,
		_mastery_stat_min_w()))
	var prows := float(_grid_rows(POWER_ORDER.size(), 4, 10.0, 120.0))
	return rows * 56.0 * f + maxf(0.0, rows - 1.0) * 8.0 * sp + 62.0 + 22.0 \
		+ prows * 52.0 * f + 120.0


## The narrowest a record tile may be before `_grid_rects` drops a column.
##
## 140 on a desktop, where eight across is the point of the strip. On a phone
## that same floor settles on four columns about 156 units wide — roughly 84pt —
## and a tile that narrow cannot hold "MULTI-CLEARS" stacked over a five-figure
## number, never mind the longest word played. Two columns is the readable
## answer in portrait and 300 is the floor that forces it.
##
## One definition because `_mastery_stat_rects` and `_mastery_laid` have to
## settle on the same column count. The note on `_mastery_laid` is about the
## last time those two disagreed and the bottom of the record became unreachable.
func _mastery_stat_min_w() -> float:
	return 300.0 if portrait else 140.0


func _mastery_stat_rects(count: int) -> Array:
	return _grid_rects(count, 166.0 + safe_top + _menu_offset(_mastery_laid()), 8,
		138.0, 56.0 * _mastery_fill(), 8.0, _mastery_stat_min_w(),
		8.0 * _mastery_spread())


## The bottom of the record screen — the stat grid, then the power tallies. The
## buttons hang off it, so both have to be measured rather than guessed.
func _mastery_stats_foot() -> float:
	var strip := _mastery_stat_rects(_mastery_stats().size())
	var pfoot := _grid_bottom(strip, 222.0 + safe_top) + 40.0
	var pw := _grid_rects(POWER_ORDER.size(), pfoot + 22.0, 4, 150.0,
		52.0 * _mastery_fill(), 10.0, 120.0, 10.0 * _mastery_fill())
	return _grid_bottom(pw, pfoot) + 56.0


## Where the unlock grid starts, once the record strip above it has taken as many
## rows as it needs. On a desktop that is one row and this is the old constant.
## The preview sits under the category label, and the grid under the preview.
const COSMETICS_NATURAL := 150.0 + 46.0 + 4.0 * 80.0 + 110.0


func _cosmetics_fill() -> float:
	return _menu_fill(COSMETICS_NATURAL, 1.5)


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
	if not portrait:
		_otext(_font, Vector2(cx, 492.0),
			"F1 — sound      CTRL+BACKSPACE clears your line", 12, Color("#4d5878"))


# ------------------------------------------------------------- the versus lobby
#
# Versus used to be a jump straight to Apple's matchmaking sheet, which carried
# quick match and invite-a-friend on one screen and was therefore better than the
# two doors we would have drawn. That reasoning was sound and it is no longer the
# whole picture: the sheet also owns the entire screen for the length of a
# search, and with nobody else online a search finds nobody. What the player got
# was somebody else's spinner, then nothing, on a mode they never tried twice.
#
# This screen is that missing half. It keeps both of Apple's doors — Invite still
# opens the sheet, in INVITE_ONLY mode, because texting a link to a contact is
# the one route in the whole API that reaches somebody who is not already a Game
# Center friend — and it puts a search we can narrate and a CPU match we can
# offer on the near side of them.
#
# The layout is deliberately a single column of doors rather than a composition,
# so a fourth one can be added without moving the other three.

## How long a fruitless search runs before the screen stops pretending and points
## at the CPU door instead.
##
## Twenty seconds is long enough that a real opponent on a slow network is not
## given up on, and short enough to be inside the patience of somebody who has
## just tapped a button. It does not cancel the search — the offer appears
## alongside one that is still running, because the two are not exclusive and
## the player may still want to wait.
const LOBBY_FALLBACK := 20.0

## How long the current search has been running, or zero when none is. Ticked in
## `_process` so the status line counts up rather than sitting still.
var _lobby_search := 0.0

## Who the CPU door offers. Fixed for the life of the screen rather than rolled
## per frame, because a door whose name changes while you are reading it is a
## door you do not trust.
var _lobby_bot := "Duelist"


## The screen at its landscape size — header block, three doors, the gaps between
## them and the margin under the last. `_menu_fill` wants this to answer "how
## tall am I", the same way every other menu here declares itself.
const LOBBY_NATURAL := 262.0 + 3.0 * 88.0 + 2.0 * 12.0 + 110.0


func _lobby_fill() -> float:
	return _menu_fill(LOBBY_NATURAL, 1.7)


func _lobby_spread() -> float:
	return _menu_spread(LOBBY_NATURAL)


## The header and the status card above the doors.
##
## Not a free choice, and it was 200 in landscape until the render showed why
## that is wrong: the card is drawn at `hy + 124` and is 96 tall, so anything
## below 220 puts the first door through the bottom of it. The extra is the gap
## between the two, and it is the same in both orientations because the card is.
func _lobby_head_h() -> float:
	return 262.0


## One door. The base is a landscape plate and the fill grows it for a thumb,
## which is the same deal the practice and solo screens make.
##
## Both dimensions stay above `_draw_menu_button`'s plate threshold: under 38
## units high or 230 wide it falls back to the plain wordless panel used for
## Back, and these are the primary doors of the screen.
func _lobby_door_h() -> float:
	return 88.0 * _lobby_fill()


func _lobby_door_w() -> float:
	var usable: float = get_viewport_rect().size.x - GRID_MARGIN * 2.0
	# Portrait gives the doors the whole width the way practice's do; landscape
	# caps them, because a plate twelve hundred units across is a horizon.
	return usable if portrait else minf(560.0, usable)


func _lobby_door_gap() -> float:
	return 12.0 * _lobby_spread()


## Under the header and the status card, both of which are always drawn. Nothing
## on this screen appears or disappears with state, so a door cannot move out
## from under a thumb already on its way down.
func _lobby_doors_top() -> float:
	return _lobby_head_h() + safe_top + _menu_offset(_lobby_laid())


func _lobby_door_rects() -> Array:
	return _grid_rects(_lobby_doors().size(), _lobby_doors_top(), 1,
		_lobby_door_w(), _lobby_door_h(), 12.0, 260.0, _lobby_door_gap())


func _lobby_laid() -> float:
	var n := float(_lobby_doors().size())
	# Portrait reserves almost nothing under the last door: the chevron in the
	# corner is the way back, so unlike landscape there is no button down there
	# to leave room for. Over-reserving it would push the whole block up the
	# screen, which is the opposite of what the trailing margin is for.
	return _lobby_head_h() + n * _lobby_door_h() \
		+ (n - 1.0) * _lobby_door_gap() + 70.0 + (20.0 if portrait else 60.0)


## True once a search has gone on long enough to be worth apologising for. Only
## ever true while one is actually running, so the CPU door goes back to its
## ordinary self the moment the search is cancelled or answered.
func _lobby_offering() -> bool:
	return _versus_busy() and _lobby_search >= LOBBY_FALLBACK


## What the CPU door says for itself. After a fruitless search it stops being a
## third option and starts being the answer to the question the player is by then
## actually asking.
func _lobby_cpu_sub() -> String:
	var wpm := AiOpponent.paced_wpm(_lobby_bot, portrait)
	if _lobby_offering():
		return "Nobody about — %s is ready now" % _lobby_bot.to_upper()
	return "%s · %d wpm · starts immediately" % [_lobby_bot.to_upper(), wpm]


## The line under a running search. The count is there because a wait with a
## number on it is a wait; a wait without one is a hang.
func _lobby_search_line() -> String:
	if not _versus_busy():
		return ""
	return "%s · %ds" % [net_status if net_status != "" else "looking for an opponent",
		int(_lobby_search)]


## The doors, in order, without their rectangles.
##
## Split from `_lobby_door_rects` on purpose: the rects are positioned from
## `_lobby_laid`, which counts the doors, so a spec list that needed its own
## rectangles to build would be a loop with no bottom to it.
func _lobby_doors() -> Array:
	var out: Array = []
	var can: bool = MultiplayerManager.available()
	var grey := Color("#4d5878")
	var why := "needs an iPhone signed in to Game Center"

	# The search takes the first slot whether it is idle or running, so cancelling
	# does not shuffle the two doors underneath it.
	# Every label is completed by its own stamp — the block carries a fragment and
	# the word starts with those letters, which is the title screen's rule and the
	# game's own loop. A label the stamp does not prefix draws as a block with an
	# unrelated word next to it.
	if _versus_busy():
		out.append({
			"rect": Rect2(), "key": "ESC", "stamp": "STOP",
			"label": "Stop looking", "sub": _lobby_search_line(), "note": "",
			"rating": 0, "accent": Color("#8d99bd"), "action": "versus_cancel"})
	else:
		out.append({
			"rect": Rect2(), "key": "ENTER", "stamp": "QUICK",
			"label": "Quick Match",
			"sub": "Find anyone else looking right now" if can else why,
			"note": "", "rating": 0,
			"accent": Color("#c77dff") if can else grey,
			"action": "versus_quick"})

	out.append({
		"rect": Rect2(), "key": "I", "stamp": "INV", "label": "Invite a friend",
		"sub": "Text a link to anyone in your contacts" if can else why,
		"note": "", "rating": 0,
		"accent": PLAYER_ACCENT if can else grey,
		"action": "versus_invite"})

	# Always present, and never only a consolation prize behind a failed search.
	# With nobody else online this is the one door in the room that opens, and a
	# player who taps VERSUS to find a dead end and two grey plates does not come
	# back to the mode a second time.
	out.append({
		"rect": Rect2(), "key": "C", "stamp": "CPU", "label": "CPU Match",
		"sub": _lobby_cpu_sub(), "note": "", "rating": 0,
		"accent": Color("#ffd166") if _lobby_offering() else Color("#90be6d"),
		"action": "versus_cpu"})
	return out


## The status card's headline. Three words about what Game Center is doing,
## because the doors underneath say what you can do about it.
## A live search is asked about before availability, not after. The two cannot
## honestly disagree — nothing can be matchmaking on a device Game Center is not
## on — but ordering it the other way meant that if they ever did, the card
## announced the mode was unavailable directly above a door saying it was
## searching. Whichever of the two is wrong, the running search is the one the
## player can see the consequences of.
func _lobby_head() -> String:
	if _versus_busy():
		return "LOOKING FOR SOMEBODY"
	if not MultiplayerManager.available():
		return "NOT AVAILABLE HERE"
	return "READY"


## And the sentence under it. This is where a search that is going nowhere says
## so in as many words — the door below has already turned gold by then, and a
## card still cheerfully saying "looking" would be arguing with it.
func _lobby_note() -> String:
	if not MultiplayerManager.available() and not _versus_busy():
		return "versus needs an iPhone signed in to Game Center"
	if _versus_busy():
		if _lobby_offering():
			return "%ds and nobody yet — the CPU match starts straight away" \
				% int(_lobby_search)
		return _lobby_search_line()
	# `net_status` carries the reason a previous attempt failed, which is worth
	# more than the resting copy: a handshake that timed out has something to
	# say and this is the only screen left to say it on.
	if net_status != "":
		return net_status
	return "quick match finds a stranger · invite reaches anyone you can text"


## The versus screen. A header, one card saying what Game Center is doing, and
## the doors — see the block comment above `LOBBY_FALLBACK` for why it exists.
func _draw_lobby(size: Vector2) -> void:
	var cx := size.x * 0.5
	_overlay.draw_rect(Rect2(-SHAKE_MARGIN, -SHAKE_MARGIN,
		size.x + SHAKE_MARGIN * 2.0, size.y + SHAKE_MARGIN * 2.0),
		Color(bg_top, 0.93), true)
	_draw_decor()

	var hy := safe_top + _menu_offset(_lobby_laid())
	_otext(_font_bold, Vector2(cx, hy + 62.0), "VERSUS", 32, Color("#e6ecff"))
	_otext(_font, Vector2(cx, hy + 96.0),
		"play a person, or a machine that types back", 14, Color("#8d99bd"))

	# Always drawn, in every state. A card that only appears once a search starts
	# would push all three doors down the screen under a thumb already moving.
	var cw := _lobby_door_w()
	var card := Rect2(cx - cw * 0.5, hy + 124.0, cw, 96.0)
	var accent: Color = Color("#ffd166") if _versus_busy() else (
		PLAYER_ACCENT if MultiplayerManager.available() else Color("#4d5878"))
	_panel(card, Color("#141b33"), Color(accent, 0.45), 10.0, 2.0)
	_otext(_font, Vector2(cx, card.position.y + 22.0), "GAME CENTER", 10,
		Color("#7c88ad"))
	_text_fit_overlay(_font_bold, Vector2(cx, card.position.y + 48.0),
		_lobby_head(), 20, card.size.x - 24.0, Color("#e6ecff"), 13)
	_text_fit_overlay(_font, Vector2(cx, card.position.y + 74.0),
		_lobby_note(), 12, card.size.x - 24.0, Color(accent, 0.9), 9)

	for b: Dictionary in _menu_buttons():
		_draw_menu_button(b)

	# The two things about versus that are true whatever the doors are doing, and
	# that a player has no way to find out by trying. The second one is the more
	# important: an invite sends somebody to the App Store, and Game Center does
	# not carry the invitation through an install — so the friend who accepts and
	# then installs arrives to no match and no explanation unless one of you knows
	# to just do it again.
	var foot := _grid_bottom(_lobby_door_rects(), 360.0 + safe_top) + 30.0
	_text_fit_overlay(_font, Vector2(cx, foot),
		"quick match needs somebody else looking at the same moment", 12,
		size.x - GRID_MARGIN * 2.0, Color("#5d6a92"), 9)
	_text_fit_overlay(_font, Vector2(cx, foot + 20.0),
		"an invite reaches anyone you can text — ask again once they have it", 12,
		size.x - GRID_MARGIN * 2.0, Color("#4d5878"), 9)


## Overlay twin of `_text_fit`, since the lobby draws on the overlay layer.
func _text_fit_overlay(font: Font, center: Vector2, text: String, size: int,
		max_width: float, color: Color, min_size: int = 9) -> void:
	if font == null or text == "":
		return
	var s := size
	while s > min_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > max_width:
		s -= 1
	_otext(font, center, text, s, color)


func _draw_rules_panel(size: Vector2) -> void:
	var cx := size.x * 0.5
	# The panel was 860 wide against a 720 screen, so on a phone its border was
	# off both edges and every line of it overhung. Width and wrapping now come
	# from the screen, which means the paragraphs below are written as sentences
	# and broken by the font rather than by hand at one particular width.
	var pw: float = minf(860.0, size.x - GRID_MARGIN * 2.0)
	var inner: float = pw - 40.0
	var body_size := _read_size(14)
	# Shorter sentences than this used to carry. Nothing was dropped — every rule
	# that was here is still here — but each paragraph had a clause explaining the
	# clause before it, and this is the screen somebody opens because they are
	# already lost. The qualifications went; the rules stayed.
	var paras := [
		"Type a word, fire with %s. Its LAST letters brand a block on your rival." % [
			"the FIRE key" if portrait else "SPACE or ENTER"],
		"Clear a block by typing a word that STARTS with its letters. That is the only "
			+ "way — attacking never defends you. Answer one while it is still falling "
			+ "and it never lands. A word clears one block per two letters, so four AL "
			+ "blocks need ALIGNMENT.",
		"The blocks you send grow only with your chain: 1, 2, 3, 5, 7 then 9 words for "
			+ "each step up. A tenth cashes the run in as a SALVO and resets you. Pause, "
			+ "or fire a non-word, and the run is gone.",
		"Topping out costs one of THREE LIVES and wipes your board. It does not end the "
			+ "match. Words score by their letters, times your chain, times what they "
			+ "broke, and every cell you send pays on top. Overfilling a rival pays a "
			+ "bonus, and so does winning.",
		"With three or more boards in play, every attacker past the first aiming at "
			+ "the same board hits a tier harder. Ganging up works, and being ganged "
			+ "up on is worth re-aiming over.",
	]

	# Measured before the panel is drawn, so the panel is the height of what is
	# going in it rather than a number that happened to be right at 1280.
	var body := 0.0
	for p: String in paras:
		body += _font.get_multiline_string_size(
			p, HORIZONTAL_ALIGNMENT_CENTER, inner, body_size).y + 10.0
	var top: float = 172.0 + safe_top
	_panel(Rect2(cx - pw * 0.5, top, pw, body + _rules_extra() + 40.0),
		Color("#111730"), Color(PLAYER_ACCENT, 0.22), 12.0)

	var y: float = top + 22.0
	for p: String in paras:
		var mh: float = _font.get_multiline_string_size(
			p, HORIZONTAL_ALIGNMENT_CENTER, inner, body_size).y
		_overlay.draw_multiline_string(_font,
			Vector2(cx - inner * 0.5, y + _font.get_ascent(body_size)),
			p, HORIZONTAL_ALIGNMENT_CENTER, inner, body_size, -1, Color("#aab4d4"))
		y += mh + 10.0

	# Power words are worth spelling out here, but they are meant to be met in
	# play first: the game announces one the first time you manage it by
	# accident, and this is where you come to find out what happened.
	y += 12.0
	_overlay.draw_rect(Rect2(cx - inner * 0.5, y - 8.0, inner, 1.0),
		Color(PLAYER_ACCENT, 0.2), true)
	y += 16.0
	_otext(_font_bold, Vector2(cx, y), "POWER WORDS", _read_size(15), Color("#e6ecff"))
	y += float(_read_size(15)) + 9.0
	var how := {
		"COUNTER": "shoot down something already inbound     send one straight back",
		"COMBO": "break three blocks at once     your next attack is a tier bigger",
		"PERFECT": "break three WITHOUT dropping your run     a whole extra attack",
		"CLUTCH": "break anything with one row left     the garbage nearly stops",
	}
	# Measured first so the four rows share one column layout: names right-aligned
	# against a common edge, bodies all starting at the same x. Centring each row
	# on its own width reads as four unrelated notes rather than a table.
	var name_size := _read_size(14)
	var part_size := _read_size(13)
	var line_h := _rules_power_line()
	var name_w := 0.0
	for name: String in POWER_ORDER:
		name_w = maxf(name_w, _font_bold.get_string_size(
			name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x)
	# The bodies are a trigger and a reward separated by a wide gap, and the gap
	# is what makes them read as two columns. There is no room for a gap that
	# wide at 720, so on a phone the reward goes on its own line under it — two
	# lines that mean something beats one line squeezed until neither does.
	var stacked := portrait
	var body_w := 0.0
	for name: String in POWER_ORDER:
		for part: String in _power_parts(String(how[name]), stacked):
			body_w = maxf(body_w, _font.get_string_size(
				part, HORIZONTAL_ALIGNMENT_LEFT, -1, part_size).x)
	var left := cx - (name_w + 18.0 + body_w) * 0.5

	for name: String in POWER_ORDER:
		var tint := Color(String(POWERS[name]["tint"]))
		var nm := _font_bold.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size)
		_otext(_font_bold, Vector2(left + name_w - nm.x * 0.5, y), name, name_size, tint)
		for part: String in _power_parts(String(how[name]), stacked):
			var bd := _font.get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, part_size)
			_otext(_font, Vector2(left + name_w + 18.0 + bd.x * 0.5, y), part, part_size,
				Color("#8d99bd"))
			y += line_h
		y += 5.0


## A power word's line, as one column or two rows.
func _power_parts(text: String, stacked: bool) -> Array:
	if not stacked:
		return [text]
	var out: Array = []
	for part: String in text.split("     ", false):
		out.append(part.strip_edges())
	return out if out.size() > 1 else [text]


## One line of a power word's description. Shared with `_rules_extra`, which has
## to predict the height of a table it does not draw.
func _rules_power_line() -> float:
	return float(_read_size(13)) + 6.0


## Everything under the paragraphs: the rule, the heading, and a row per power
## word.
func _rules_extra() -> float:
	# Two lines a row on a phone, where the trigger and the reward are stacked.
	var per: float = _rules_power_line() * (2.0 if portrait else 1.0) + 5.0
	return 12.0 + 16.0 + float(_read_size(15)) + 9.0 + float(POWER_ORDER.size()) * per


## The flourish a win gets when no victory effect has been equipped.
##
## All four in `Cosmetics` are bought or unlocked, so the *default* state of the
## game — somebody winning their first match — was a gold word on the same dark
## screen they had spent the match losing on. That is the one moment the game
## most needs to react, and it was the one moment nothing happened.
##
## Deliberately less than the paid four: a single shockwave on arrival and a
## slow bloom that stays. It reads as the screen responding rather than as an
## effect playing, so `confetti` and `supernova` still have somewhere to go.
func _draw_default_victory(size: Vector2, at: Vector2, tint: Color) -> void:
	var reach: float = maxf(size.x, size.y)
	# One pass outward, easing to a stop, over about a second. Driven by
	# `over_age` rather than the wall clock so it fires on arrival and then is
	# done — a loop would turn it into wallpaper.
	var t: float = clampf(over_age / 1.15, 0.0, 1.0)
	if t < 1.0:
		var e: float = 1.0 - pow(1.0 - t, 3.0)
		for i in 3:
			var lag: float = clampf(e - float(i) * 0.07, 0.0, 1.0)
			if lag <= 0.0:
				continue
			_overlay.draw_arc(at, reach * 0.62 * lag, 0.0, TAU, 48,
				Color(tint, (1.0 - lag) * 0.28), 3.0 - float(i), true)
	# And a bloom that stays, so the screen keeps the colour of the result
	# instead of going back to the dark it had while the match was still in
	# doubt. Very low alpha, stacked — the same trick the playfield's theme glow
	# uses, and for the same reason: it works on the compatibility renderer.
	# Eight steps rather than five, and the alpha taken all the way to zero at
	# the outside. Five left the last circle still faintly visible where it
	# stopped, which drew a hard rim across the screen — a glow with an edge on
	# it reads as a shape, and the shape was a circle nobody asked for.
	var pulse: float = 0.5 + 0.5 * sin(over_age * 2.0)
	for i in 8:
		var f := float(i) / 7.0
		_overlay.draw_circle(at, reach * (0.10 + f * 0.55),
			Color(tint, 0.030 * (1.0 - f) * (0.7 + 0.3 * pulse)))


func _draw_gameover(size: Vector2) -> void:
	var cx := size.x * 0.5
	# Opaque. The boards used to show faintly through, which was pleasant until
	# the summary grew a score of its own — the live one underneath sits in
	# almost the same place, and two different numbers ghosting through each
	# other reads as a rendering fault.
	#
	# 0.985 was the first attempt at that and it did not finish the job: at
	# 1.5% the HUD's clock and score were still legible, and once the headline
	# moved down the phone they were sitting on empty background at the top of
	# the screen with nothing over them. There is nothing behind this worth
	# seeing, so none of it is let through.
	_overlay.draw_rect(Rect2(-SHAKE_MARGIN, -SHAKE_MARGIN,
		size.x + SHAKE_MARGIN * 2.0, size.y + SHAKE_MARGIN * 2.0), bg_top, true)

	var win := winner == "YOU"
	var tint := Color("#ffd166") if win else Color("#ff6b6b")
	# Every survival run ends in death, so the loss red would be the only colour
	# this mode ever wore — and a four-minute run is not a failure, it is the
	# score. Gold still means a record fell; short of that it gets the mode's own
	# accent rather than the colour the game uses to say you were beaten.
	if mode == Mode.SURVIVAL and not win:
		tint = SURVIVAL_ACCENT

	# The earned victory animation, behind everything else on the screen and only
	# ever on a win. Losing gets the plain card: a celebration that fires either
	# way is not a celebration.
	if win:
		var t := Time.get_ticks_msec() / 1000.0
		# Centred on the headline, which has moved a long way down on a phone —
		# the two effects that take a point were pinned at 150 and fired off the
		# top of the screen above it.
		var burst := Vector2(cx, 150.0 * _over_lead())
		match Profile.worn("victory"):
			"confetti":
				Cosmetics.victory_confetti(_overlay, size, t, tint)
			"rays":
				Cosmetics.victory_rays(_overlay, burst, t, tint)
			"shatter":
				Cosmetics.victory_shatter(_overlay, burst, t, tint)
			"supernova":
				Cosmetics.victory_supernova(_overlay, size,
					Vector2(cx, 200.0 * _over_lead()), t, tint)
			_:
				# Nothing equipped, which is every new player and was therefore
				# the default experience of winning: a gold word on the same dark
				# screen you had been losing on. See `_draw_default_victory`.
				_draw_default_victory(size, burst, tint)

	# A sprint has nothing to win. "YOU WIN" over a solo run against a clock is
	# the summary claiming a rival was beaten, which is the same lie the LESSON
	# chip used to tell during the run — and it says it whether the minute ended
	# on the clock or on the last life, so it is not even reporting the run.
	var headline := "YOU WIN" if win else "YOU LOSE"
	if mode == Mode.DAILY:
		# Three endings, not two. "TOPPED OUT" is a run that burned its lives and
		# "TIME" is one that lasted the minute, and a run walked out of is
		# neither — it is a score that stopped. Saying so is the honest half of
		# banking it, and the summary is where the player finds out that leaving
		# posted the number rather than discarding it.
		headline = "LEFT EARLY" if daily_quit else ("TIME" if win else "TOPPED OUT")
	# The clock, because in survival the clock is the score. "YOU LOSE" is true
	# of every run ever played here and says nothing about this one; how long you
	# lasted is the entire result, and it belongs in the biggest type on the
	# screen rather than in a caption under it.
	elif mode == Mode.SURVIVAL:
		headline = _survival_clock(match_time)
	# Sized down past the eight characters the slot was cut for, so the longest
	# of them is no wider on screen than the shortest — 68 was measured against
	# "YOU LOSE" and a phone has no margin to spare.
	var lead := _over_lead()
	# Fitted rather than stepped between two sizes. The headline is the biggest
	# thing on the screen and a phone is 720 wide, so "TOPPED OUT" at a fixed 68
	# ran into both margins; this lets the long ones shrink and leaves the short
	# ones — the ones worth shouting — as large as the width allows.
	var hsize := _fitted_size(_font_bold, headline, _over_size(68),
		size.x - GRID_MARGIN * 2.0, 34)
	_otext(_font_bold, Vector2(cx, 132.0 * lead), headline, hsize, tint)
	var wm := _font_bold.get_string_size(headline, HORIZONTAL_ALIGNMENT_LEFT, -1, hsize)
	_overlay.draw_rect(Rect2(cx - wm.x * 0.5, 170.0 * lead, wm.x,
		3.0 * _over_fill()), Color(tint, 0.45), true)

	# The score is the headline, above the tiles rather than inside one. Winning
	# is binary and says nothing about how well you played; this is the number
	# worth arguing over afterwards.
	_otext(_font, Vector2(cx, 204.0 * lead), "SCORE", _over_size(15),
		Color("#7c88ad"))
	# Counted up rather than printed. The number is the same either way and the
	# difference is entirely in how it lands: a total that arrives already
	# finished is a receipt, and one that runs up to itself is a payout. Eased
	# so it decelerates into the real figure rather than stopping dead, and it
	# settles inside a second so it is never in the way of reading it.
	var tally := player.score
	if over_age < SCORE_TALLY:
		var e: float = over_age / SCORE_TALLY
		tally = int(round(float(player.score) * (1.0 - pow(1.0 - e, 3.0))))
	_otext(_font_bold, Vector2(cx, 248.0 * lead), _commas(tally),
		_over_size(62), Color("#ffd166"))
	var line_y := 288.0 * lead

	# A challenge is the only thing on this screen that somebody else is waiting
	# on, so it is said first and said in bold. Everything below it is a comment
	# on how the run went; this is the one line about whether it counted.
	var chline := _challenge_line()
	if chline != "":
		line_y += 8.0 * _over_fill()
		_text_fit_overlay(_font_bold, Vector2(cx, line_y), chline,
			_over_size(18), size.x - GRID_MARGIN * 2.0,
			Color("#90be6d") if bool(_challenge_verdict().get("beat", false))
				else Color("#ff6b6b"), 12)
		line_y += 30.0 * _over_fill()

	# How close it was, on a loss, in the loss colour and directly under the
	# score it is a comment on. This is the line the Rematch button is arguing
	# with, so it sits above everything else that could dilute it.
	var margin := _over_margin()
	if margin != "":
		# Set larger than the lines under it and therefore needing more room
		# above: at the shared offset it sat in the score's descenders, and a
		# comma touching the sentence below it reads as a layout fault.
		line_y += 8.0 * _over_fill()
		_text_fit_overlay(_font_bold, Vector2(cx, line_y), margin,
			_over_size(18), size.x - GRID_MARGIN * 2.0, tint, 12)
		line_y += 30.0 * _over_fill()
	# The headline jumps at the end of a won match and the reason was on screen
	# for one second, as a pop that has faded by the time anybody reads the
	# total. Two numbers that do not add up look like a bug in the scoring, so
	# the summary shows its working: this is the only place the win bonus is
	# still legible when you are actually looking at the score it changed.
	if win_spoils > 0:
		# Split into what the win was worth and what the damage was worth, once
		# the damage half is big enough to be most of it. One number that large
		# next to "for the win" reads as the game handing it to you; naming the
		# cells says it was paid for, and says what to do more of next time.
		var damage_cut: int = Scoring.flat(player.dealt * Scoring.WIN_DAMAGE_STEP)
		var line := "%s in play  +  %s for the win" % [
			_commas(player.score - win_spoils), _commas(win_spoils)]
		if damage_cut > 0:
			line = "%s in play  ·  +%s won  ·  +%s for %s cells dealt" % [
				_commas(player.score - win_spoils),
				_commas(win_spoils - damage_cut), _commas(damage_cut),
				_commas(player.dealt)]
		_text_fit_overlay(_font, Vector2(cx, line_y), line,
			_over_size(15), size.x - GRID_MARGIN * 2.0, Color("#90be6d"), 11)
		line_y += 26.0 * _over_fill()
	if player.best_word != "":
		_text_fit_overlay(_font, Vector2(cx, line_y),
			"best word — %s for %s" % [_show(player.best_word.to_upper()),
				_commas(player.best_word_score)], _over_size(15),
			size.x - GRID_MARGIN * 2.0, Color("#8d99bd"), 11)

	# Time and words-per-minute are the two numbers here that are only ever
	# yours: there is no such thing as a CPU's typing speed, and a peer's is not
	# sent. Everything else is comparable, so everything else went into the
	# table below rather than being said twice.
	# WPM moved into the table, where it can be compared. Repeating it here
	# would be the same number twice on one screen.
	var subtitle := "%d:%02d  ·  %s" % [
		int(match_time) / 60, int(match_time) % 60,
		difficulty.to_upper() if not net_active() else "VERSUS"]
	if mode == Mode.DAILY:
		subtitle = "DAILY SPRINT  ·  %s  ·  %d wpm" % [daily_key(), int(round(_wpm()))]
		# Said plainly, once, on the screen where it can still be acted on
		# tomorrow. A player who left at forty seconds needs to know the number
		# went to the board — otherwise the first they hear of it is a rank they
		# cannot explain, and the natural conclusion is that the game cheated.
		if daily_quit:
			subtitle = "DAILY SPRINT  ·  posted as it stood  ·  %s" % daily_key()
	elif mode == Mode.SURVIVAL:
		# The headline is already the time, so this carries what to measure it
		# against. A first run has nothing to beat and says so rather than
		# printing "best 0:00", which reads as a bug in the record.
		var mark := "no record yet" if Profile.survival_best_time <= 0.0 \
			else "best %s" % _survival_clock(Profile.survival_best_time)
		subtitle = "SURVIVAL  ·  %s  ·  %d wpm" % [mark, int(round(_wpm()))]
	_text_fit_overlay(_font, Vector2(cx, _scoreboard_top() - 30.0), subtitle,
		_over_size(15), size.x - GRID_MARGIN * 2.0, Color("#7c88ad"), 11)

	_draw_scoreboard(size, _scoreboard_top(), tint)

	# Between the table and the buttons, and `_over_foot` already counts it — so
	# this is drawn before them rather than over them.
	if mode == Mode.DAILY:
		_draw_daily_board(size, _over_foot() - _daily_board_h(), tint)

	for b: Dictionary in _menu_buttons():
		# The daily board's tabs are in this list so they can be pressed, and
		# they are painted by `_draw_daily_board` inside the block they belong
		# to. Drawing them here as well would put two empty plates over them.
		if String(b["action"]).begins_with("dtab:"):
			continue
		_draw_menu_button(b)

	if mode == Mode.DAILY:
		# The board says where today came; this says whether it was the best there
		# has ever been, which is the one thing a ranking of your own history
		# cannot show you at a glance when you have played sixty of them.
		var run: Dictionary = Profile.daily_result(daily_key())
		if int(run.get("score", 0)) >= Profile.daily_best and Profile.daily_best > 0:
			_text_fit_overlay(_font_bold, Vector2(cx, _over_foot() + 26.0),
				"a new best", 14, size.x - GRID_MARGIN * 2.0, Color("#ffd166"), 11)
	elif mode == Mode.SURVIVAL:
		# Which record fell, named. There are two of them and they are taken by
		# different kinds of run — saying "a new best" without saying which would
		# leave a player guessing what they had just done well.
		var beat: Array = []
		if bool(survival_took.get("time", false)):
			beat.append("longest run")
		if bool(survival_took.get("score", false)):
			beat.append("highest score")
		if not beat.is_empty():
			_text_fit_overlay(_font_bold, Vector2(cx, _over_foot() + 26.0),
				"a new best — %s" % " and ".join(beat), _over_size(14),
				size.x - GRID_MARGIN * 2.0, Color("#ffd166"), 11)

	var strip_bottom := _draw_mastery_strip(cx)

	# Two keys, because there are now two. This used to advertise 1 – 7 for a new
	# opponent and P for mastery, which were exactly the shortcuts that made the
	# summary impossible to read — and it was pinned at 674, which the buttons
	# now sit on top of.
	if not portrait:
		# The daily has no Rematch button — that is the whole shape of one run a
		# day — so it must not be told to click one. Survival has one and it is
		# called something else, because there is nobody to have a rematch with.
		var keys := "click Rematch to go again      ESC — title"
		if mode == Mode.DAILY:
			keys = "ESC — title"
			if _daily_tabs_up():
				keys = "LEFT / RIGHT — today's board or your own      ESC — title"
		elif mode == Mode.SURVIVAL:
			keys = "click Again for a fresh run      ESC — title"
		_otext(_font, Vector2(cx, strip_bottom + 26.0), keys, 13, Color("#4d5878"))


## What the win was worth, kept so the summary can reconcile its own headline.
## Zero on a loss, on a daily and on anything that is not a normal match.
var win_spoils := 0

const SCORE_ROW_H := 34.0
const SCORE_HEAD_H := 22.0

## How long the summary's headline score takes to run up to itself. Shorter than
## `OVER_LOCKOUT`, so it has always finished by the time the screen will accept
## a press — nobody ever sees a half-counted number and a live button together.
const SCORE_TALLY := 0.85


## The summary was laid out in the 720-tall landscape design space and then
## handed a phone twice that height, where it kept the same 34px rows and 10px
## column heads — a table built for a monitor, printed small in the middle of a
## screen with room to spare. Both the rows and the type they carry scale now.
func _over_fill() -> float:
	return 1.35 if portrait else 1.0


func _over_size(base: int) -> int:
	return int(round(float(base) * (1.25 if portrait else 1.0)))


## The rows and their type scaled; where they *sit* did not.
##
## Everything above the table — the headline, its rule, the word SCORE, the
## number, and the lines under it — is at a literal Y written for a 720-tall
## landscape window. Handed a phone twice that height they stayed exactly where
## they were, which is why the whole result of a match arrived in the top third
## of the screen with a band of nothing under the buttons. Every Y above the
## table is multiplied by this, and `_scoreboard_top` carries it down to
## everything below.
##
## Chosen so the stack lands the buttons in the bottom third, which is where a
## thumb already is. Landscape is 1.0 and is not touched.
func _over_lead() -> float:
	return 1.9 if portrait else 1.0


## How the match was actually decided, in points. Only on a loss, and only in a
## mode where somebody else was playing.
##
## "YOU LOSE" is a verdict, and it says the same thing whether you were beaten
## by forty points or by forty thousand. The margin is the part that decides
## whether Rematch gets pressed: it is the difference between "I nearly had
## that" and "I know what I am up against", and both send you back in. Neither
## is legible from the table without doing the subtraction yourself.
func _over_margin() -> String:
	if winner == "YOU" or mode == Mode.DAILY or mode == Mode.SURVIVAL:
		return ""
	var best := 0
	for s: SideState in _scoreboard_sides():
		if s != player:
			best = maxi(best, s.score)
	var gap := best - player.score
	if gap <= 0:
		return ""
	return "%s points short" % _commas(gap)


## Prose, at a size a phone can actually be read at.
##
## The two design spaces are 1280 and 720 wide, so anything set at one size is
## worth a little over half as much on a phone as it is on a monitor: the rules
## sheet, set at 14, arrived on an iPhone at roughly seven points. That is half
## Apple's floor for body text, and "the instructions are tiny" was the first
## thing said about this game by somebody who had not built it.
##
## 1.6 rather than the summary screen's 1.25 because these are paragraphs and
## that is a headline — a number you glance at survives being small in a way a
## sentence you have to read does not. Both panels using it size themselves from
## their contents, so raising it moves the panel rather than overflowing it.
func _read_size(base: int) -> int:
	return int(round(float(base) * (1.6 if portrait else 1.0)))


func _score_row_h() -> float:
	return SCORE_ROW_H * _over_fill()


func _scoreboard_top() -> float:
	# The win line only exists on a won match, so the table starts lower only
	# when there is something above it to make room for. The margin line on a
	# loss takes the same row, so the two never both claim it.
	#
	# A challenge verdict is a second row and can ride on top of either, so the
	# rows are counted rather than switched on. Reserving one row for two lines
	# put the table through the bottom of the verdict.
	var rows := 0
	if win_spoils > 0 or _over_margin() != "":
		rows += 1
	if _challenge_line() != "":
		rows += 1
	return 342.0 * _over_lead() + safe_top + 26.0 * _over_fill() * float(rows)


## Which columns the table carries. Powers and salvos are the first to go on a
## narrow screen: they are the rarest events in a match and often read 0 across
## every row, where words and clears always say something.
##
## WPM earns a place in both. It used to be excluded on the grounds that it is
## "only ever yours" — true of the measurement, but the conclusion was wrong:
## typing speed is the most directly comparable number in the game and the whole
## point of the table is comparing. It travels in the state payload now, so a
## peer's is real rather than a local default of zero.
func _scoreboard_cols() -> Array:
	if portrait:
		return ["SCORE", "WPM", "WORDS", "CHAIN"]
	return ["SCORE", "WPM", "WORDS", "CLEARED", "CHAIN", "POWERS", "SALVOS"]


## Typing speed for any row, from whichever of the three places knows it.
##
## Yours is measured from keystrokes on this machine; a peer's arrives in their
## state payload; a CPU has no keystrokes at all and reports the rate it was
## configured to type at, which is the same number the solo screen advertises it
## by. A bot before `configure` and a peer on an older build both read zero, and
## zero is shown as a dash rather than as a claim.
func _wpm_of(s: SideState) -> float:
	if s == player:
		return _wpm()
	if s.bot != null:
		return s.bot.wpm
	return s.wpm


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
		_text_fit_overlay(_font,
			Vector2(x0 + name_w + col_w * (float(i) + 0.5), top), cols[i],
			_over_size(12), col_w - 6.0, Color("#7c88ad"), 9)

	var y := top + SCORE_HEAD_H * _over_fill()
	for s: SideState in rows:
		var mine: bool = s == player
		# Who actually won, not who happened to still be standing — in a
		# free-for-all the match can end with three boards alive, and marking
		# all of them is the same as marking none.
		var won: bool = (winner == "YOU") if mine else (s.label == winner)
		var r := Rect2(x0, y, tw, _score_row_h())
		# Your own row is picked out because it is the one you are looking for,
		# and the winner's because it is the one the match was about. When they
		# are the same row it simply gets both.
		_panel(r, Color("#1b2444") if mine else Color("#121930"),
			Color(s.accent, 0.85 if mine else 0.28), 8.0, 2.0 if mine else 1.0)
		if won:
			_overlay.draw_rect(Rect2(r.position.x + 3.0, r.position.y + 7.0, 3.0,
				r.size.y - 14.0), Color("#ffd166"), true)

		_text_fit_overlay(_font_bold, Vector2(x0 + name_w * 0.5, r.get_center().y),
			_show(s.label).to_upper(), _over_size(17), name_w - 26.0,
			Color("#e6ecff") if (mine or won) else Color("#8d99bd"), 11)

		var rate := _wpm_of(s)
		var vals := {
			"SCORE": _commas(s.score),
			"WPM": "—" if rate <= 0.0 else str(int(round(rate))),
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
				String(vals[key]), _over_size(19 if key == "SCORE" else 17),
				col_w - 8.0, Color("#ffd166") if lead else Color("#e6ecff"), 11)
		y += _score_row_h() + 6.0

	# The longest word anyone managed, which is the other thing worth arguing
	# over and does not fit in a column.
	var best: SideState = null
	for s: SideState in rows:
		if best == null or s.longest_word.length() > best.longest_word.length():
			best = s
	if best != null and best.longest_word != "":
		_text_fit_overlay(_font, Vector2(size.x * 0.5, y + 14.0),
			"longest word — %s by %s" % [_show(best.longest_word.to_upper()),
				_show(best.label).to_upper()], _over_size(14),
			size.x - GRID_MARGIN * 2.0, Color(tint, 0.75), 11)


## The bottom of the score table. Split out from `_over_foot` because the daily
## board sits between the two and has to know where it starts without asking the
## thing that is measuring it.
func _over_table_foot() -> float:
	var n := maxi(1, _scoreboard_sides().size())
	# Measured with the same numbers the table is drawn from. These were the raw
	# constants, so the moment the rows grew for portrait the buttons stayed put
	# and the table grew underneath them.
	return _scoreboard_top() + SCORE_HEAD_H * _over_fill() \
		+ float(n) * (_score_row_h() + 6.0) + 20.0 * _over_fill()


## The bottom of everything the buttons and the mastery strip hang off.
func _over_foot() -> float:
	return _over_table_foot() + _daily_board_h()


## Where the summary's doors go, in order of how much you want them.
##
## Landscape keeps the side-by-side pair it was drawn with — it has 1280 across
## and 720 down, so a row is the shape that fits. Portrait stacks them and gives
## the first one the full width and half again the height, because on a phone
## the thing you almost always want next is not one of two equal choices at the
## bottom of a report. It is the button, and the way out is the small one under
## it.
func _over_button_rects(count: int) -> Array:
	var top := _over_foot() + 54.0
	if not portrait:
		if count < 2:
			return _grid_rects(1, top, 1, 300.0, 96.0, 20.0, 280.0, 14.0)
		# Counted, not fixed at two. The summary grew a Share door, and a
		# hardcoded 2 here handed back two rectangles for three buttons — the
		# third read past the end of the array. `_grid_rects` drops a column of
		# its own accord if three will not fit the width.
		return _grid_rects(count, top, count, 264.0, 96.0, 20.0, 280.0, 14.0)
	var cx: float = get_viewport_rect().size.x * 0.5
	var w: float = minf(654.0, get_viewport_rect().size.x - GRID_MARGIN * 2.0)
	var out: Array = []
	var y := top
	for i in count:
		var h: float = 118.0 if i == 0 else 82.0
		out.append(Rect2(cx - w * 0.5, y, w, h))
		y += h + 14.0
	return out


# ---------------------------------------------------------------- challenges
#
# Apple runs the whole of a challenge except the one part that matters here:
# starting it. Their challenge screen has a Start button, and pressing it tells
# this game nothing at all.
#
# The callback that would is `GKLocalPlayerListener.player(_:wantsToPlay:)`, and
# the plugin does not bridge it — `GKLocalPlayer` publishes `challenge_received`,
# `challenge_completed`, `challenge_other_player_accepted` and
# `challenge_other_player_completed`, and nothing for "they pressed play". The
# dashboard simply dismisses. What that looks like from the sofa is a button
# that did nothing, followed by having to go and find the right mode by hand
# with no sign anywhere that a challenge is running. Which is what it was.
#
# So the game reads what is waiting and offers it as a door of its own, at the
# top of the title screen. That is a tap rather than an automatic start on
# purpose: closing Apple's dashboard is not the same as accepting, and the same
# close arrives from browsing, declining, or backing out. Launching a timed run
# off it would be wrong more often than right.
#
# ## Which leaves the question of when to look
#
# The door can only be drawn from what `Boards.challenge` is holding, and that
# is filled by an asynchronous load. Until this poll existed there were exactly
# three things that triggered one: signing in, opening the BOARDS screen, and —
# on iOS 26 only — the dashboard's own close handler.
#
# The hole in that is the whole feature. A player taps GAME CENTER, accepts a
# challenge on Apple's screen, and closes it. On iOS 26 the close handler fires
# and the row appears. On anything older `show_type` takes no completion handler
# at all, so nothing fires, nothing reloads, and they are returned to a title
# screen with no sign that anything happened — which is the same symptom as the
# feature not existing, and indistinguishable from it from the sofa.
#
# A poll rather than a better callback because there is no better callback to
# have: the plugin publishes no signal for "the dashboard closed" on the old
# path, and there is nothing else to hang this off. It is cheap — one load every
# `CHALLENGE_POLL` seconds, only on the title screen, only while signed in — and
# the title screen is precisely where somebody who just closed that dashboard is
# standing.

## How often to ask, in seconds, while the title screen is up.
##
## Twelve is chosen against a human rather than against a network: it is about
## how long it takes to put a phone down and pick it up again after closing a
## native sheet, which is the gap this is covering. Faster would be a round trip
## to Apple every few seconds for a feature most players never touch.
const CHALLENGE_POLL := 12.0
var _challenge_poll := 0.0

## What just happened to a challenge answered without playing one, and how long
## is left to read it.
##
## `_say` is not available here and it is worth saying why, because it was tried:
## the message banner is drawn by the playfield HUD and a menu has no playfield,
## so every `_say` on the title screen since this feature shipped has gone to a
## line nobody was ever shown. The verdict takes over the row that asked for it
## instead, which is where the player is already looking.
##
## Eight seconds rather than the banner's two. This is a result being reported
## rather than a nudge, there is nothing else moving on the screen, and the row
## is a whole plate of text to read.
const CHALLENGE_SENT_LIFE := 8.0
var challenge_sent := ""
var challenge_sent_hot := false
var challenge_sent_life := 0.0


## Ask Apple again, occasionally, while the player is somewhere the answer would
## change what is on screen.
##
## Only on the title screen. The BOARDS screen asks on the way in and the two
## challenge signals cover everything that happens while the app is open; this
## is for the one case neither of those catches, which is coming back from a
## native screen that does not tell us it closed.
func _tick_challenges(delta: float) -> void:
	if challenge_sent_life > 0.0:
		challenge_sent_life = maxf(0.0, challenge_sent_life - delta)
		if challenge_sent_life == 0.0:
			challenge_sent = ""
	if phase != Phase.TITLE \
			or not (Boards.challenges_available() or Boards.definitions_available()):
		_challenge_poll = 0.0
		return
	_maybe_send_banked_to_challenge()
	_challenge_poll -= delta
	if _challenge_poll > 0.0:
		return
	_challenge_poll = CHALLENGE_POLL
	Boards.refresh_challenges()


## Put today's banked daily score in front of a challenge that started after it
## was set.
##
## The case: you play the daily at breakfast, somebody starts a challenge on that
## board at lunch, and your score is already sitting on the leaderboard. Apple
## scores an active challenge from the board, so in the ordinary case this is
## redundant — and in the case where it is not, there is no other way to close
## it, because the one run in today's board has been used.
##
## Silent, with no row and no verdict, which is a deliberate narrowing of what
## this used to be. The legacy challenge could be answered out loud because it
## carried a number to answer *against*; a definition carries none, so the
## honest report is no report. A resubmission Apple ignores and a resubmission
## that closes a challenge look identical from here, and saying "sent!" about
## the first would be inventing an event.
##
## Once per day, remembered in the profile rather than in a variable: the poll
## that calls this runs every frame the title screen is up, and the guard has to
## survive a relaunch as well as a redraw.
func _maybe_send_banked_to_challenge() -> void:
	if not _daily_is_spent():
		return
	if not bool(Boards.active.get(Boards.DAILY_ID, false)):
		return
	var key := daily_key()
	if String(Profile.pref("challenge_sent_for")) == key:
		return
	Profile.set_pref("challenge_sent_for", key)
	var mine := _banked_daily()
	print("[Game] a challenge is running on today's spent board — resending %d"
		% mine)
	Boards.submit_daily(mine)


## What the challenge door says.
##
## Names whoever sent it. A number on its own is a target; a number with a name
## on it is somebody waiting, which is the whole of why this row is worth a tap.
func _challenge_sub() -> String:
	var ch: Dictionary = Boards.challenge
	if ch.is_empty():
		return ""
	var target := String(ch.get("formatted", ""))
	if target == "":
		target = _commas(int(ch.get("score", 0)))
	var daily: bool = String(ch.get("board", "")) == Boards.DAILY_ID
	# Said on the door rather than found out by pressing it. A daily challenge on
	# a day already spent is not a run, it is a score being posted, and the row
	# has to offer the thing it is actually going to do.
	if daily and _daily_is_spent():
		return "Send your %s against %s — today's board is spent" % [
			_commas(_banked_daily()), target]
	var where := "today's daily board" if daily else "Survival"
	var who := String(ch.get("from", ""))
	if who == "":
		return "Beat %s on %s" % [target, where]
	return "%s says beat %s on %s" % [_show_name(who), target, where]


## What the door says for a challenge that came from a definition rather than
## from the legacy store, or "" when there is no such challenge to offer.
##
## Everything the richer version says — the number, the name, beaten or missed —
## is missing here because the API does not carry it. So this says the two true
## things that are left: that a challenge is running, and which board your score
## has to land on for it to count.
##
## The daily on a day already played returns "". There is nothing to press: the
## score is sent without being asked for — see `_maybe_send_banked_to_challenge`
## — and a door that opens a mode you cannot play is the thing the old spent-day
## rejection already got wrong once.
func _running_challenge_sub() -> String:
	var board := Boards.active_challenge_board()
	if board == Boards.DAILY_ID:
		if _daily_is_spent():
			return ""
		return "A challenge is running — your daily score counts toward it"
	if board == Boards.SURVIVAL_ID:
		return "A challenge is running — your Survival score counts toward it"
	return ""


## Today's daily, already played.
func _daily_is_spent() -> bool:
	return Profile.daily_done(daily_key())


## What today's run scored, or zero if it has not been played.
func _banked_daily() -> int:
	return int(Profile.daily_result(daily_key()).get("score", 0))


## Answer a daily challenge with the run that has already happened.
##
## The case this exists for is the one that made the feature useless to the
## people most likely to use it. A challenge has a clock on it, set by whoever
## sent it, and it can easily be shorter than the wait for tomorrow's board. So
## somebody who plays their daily at breakfast and is challenged at lunch used to
## be told to come back at midnight — by which point the challenge had expired
## unanswered, and from the sender's side the game had simply ignored them.
##
## The rule the daily is built on is "one run a day", and this does not break it:
## nothing is played, nothing is banked, and `record_daily` is not called. The
## score sent is the one already on the board. Apple takes a resubmission of a
## score it has seen without complaint — a classic leaderboard keeps the best
## either way — and routes it into every challenge it is eligible for, which is
## what closes this one.
##
## No summary and no share card. There is no run to draw one of, and a card
## claiming a result for a match that did not just happen is a lie in a picture
## somebody is about to post. The verdict is said on the title screen instead.
func _send_banked_daily(ch: Dictionary) -> void:
	var mine := _banked_daily()
	var target := int(ch.get("score", 0))
	Boards.submit_daily(mine)
	Boards.clear_challenge()
	var who := String(ch.get("from", ""))
	var whose := _show_name(who) if who != "" else "the challenge"
	challenge_sent_life = CHALLENGE_SENT_LIFE
	if mine >= target:
		# `>=` for the same reason `_challenge_verdict` uses it: Apple ranks a tie
		# ahead of the score posted later, so a draw is a win for the defender.
		challenge_sent = "Sent your %s — that beats %s" % [_commas(mine), whose]
		challenge_sent_hot = true
		Sfx.play("win", 1.2)
		Haptics.fire("win")
		return
	challenge_sent = "Sent your %s — %s by %s" % [_commas(mine), whose,
		_commas(target - mine)]
	challenge_sent_hot = false
	Sfx.play("count", 0.9)
	Haptics.fire("life")


## Start the run a waiting challenge is asking for.
##
## Two stores can have put the door there. The legacy one carries a target and a
## name and is the better race when it exists, so it is asked first; a challenge
## from a definition has neither and is just a board to go and play. Either way
## the mode opened is decided by the board, which is the one thing both agree on.
##
## `challenge_run` is only ever set from the legacy dictionary, and that is not
## an oversight. It is what the summary reads to say "CHALLENGE BEATEN — Anna by
## 5,680", and a definition-backed run has no target to have beaten. Left set
## from an empty dictionary the summary would claim a verdict against zero,
## which every run would win.
func _start_challenge() -> void:
	var ch: Dictionary = Boards.challenge
	var board := String(ch.get("board", "")) if not ch.is_empty() else ""
	if board == "":
		board = Boards.active_challenge_board()
	if board == Boards.DAILY_ID:
		if _daily_is_spent():
			# Not a run. See `_send_banked_daily` — and note that this returns
			# before `challenge_run` is set below, which matters: the next run
			# this player starts is not this challenge and must not report
			# itself as one.
			#
			# Only for the legacy challenge, which has a target to report against.
			# The definition-backed one has already had the score sent for it
			# without being asked — `_maybe_send_banked_to_challenge` — and draws
			# no door on a spent day, so this is unreachable rather than silent.
			if ch.is_empty():
				Sfx.play("reject", 1.2)
				return
			_send_banked_daily(ch)
			return
		Link.leave()
		MultiplayerManager.leave_match()
		start_match("Daily", 0, [], Mode.DAILY)
	elif board == Boards.SURVIVAL_ID:
		Link.leave()
		MultiplayerManager.leave_match()
		start_match("Survival", 0, [], Mode.SURVIVAL)
	else:
		# No challenge, or one on a board this build does not know. Either way
		# there is no mode to open and the door should not have been drawn.
		Sfx.play("reject", 1.2)
		return
	# After `start_match`, which clears it. See the note on `challenge_run`.
	challenge_run = ch.duplicate()
	# Dropped now rather than when Apple catches up, or the title screen offers
	# the race again the moment this run ends.
	Boards.clear_challenge()


## How the run that just finished did against the challenge it was played for.
##
## `{}` for an ordinary run, which is every run that did not come through the
## door above. Beating it is `>=` rather than `>`: Apple ranks a tie ahead of
## the later score on a classic leaderboard, and claiming a loss the leaderboard
## is about to disagree with is the one wrong answer here.
func _challenge_verdict() -> Dictionary:
	if challenge_run.is_empty():
		return {}
	var target := int(challenge_run.get("score", 0))
	var mine := player.score
	# Survival challenges race the board they are on, and the survival board is
	# scored — `submit_survival` sends the score, not the clock. So both modes
	# compare the same number.
	return {
		"beat": mine >= target,
		"target": target,
		"by": absi(mine - target),
		"from": String(challenge_run.get("from", "")),
	}


## The badge a challenge earns on the share card, laid over whatever the mode
## had to say for itself.
##
## A beaten challenge outranks a personal best, and it is not close: a record is
## a thing you did, and this is a thing you did to somebody who is about to be
## sent the picture.
func _challenge_badge(c: ShareCard.Card) -> void:
	var v := _challenge_verdict()
	if v.is_empty():
		return
	var who := String(v["from"])
	if bool(v["beat"]):
		c.badge = "challenge beaten" if who == "" \
			else "beat %s's challenge" % _show_name(who)
		c.badge_hot = true
		return
	c.badge = "challenge missed by %s" % _commas(int(v["by"]))
	c.badge_hot = false


## The one line the summary gives a challenge, or "" for an ordinary run.
func _challenge_line() -> String:
	var v := _challenge_verdict()
	if v.is_empty():
		return ""
	var who := String(v["from"])
	var whose := _show_name(who) if who != "" else "the challenge"
	if bool(v["beat"]):
		return "CHALLENGE BEATEN — %s by %s" % [whose, _commas(int(v["by"]))]
	return "CHALLENGE MISSED — %s by %s" % [whose, _commas(int(v["by"]))]


# ------------------------------------------------------------------- sharing
#
# The summary is the one screen in this game worth showing somebody, because it
# is the only one carrying a number that took effort to get. So it is the one
# that grows a Share door.
#
# What goes out is a composed 1080x1920 card rather than a screenshot — see
# `share_card.gd` for why — with a line of text beside it. The text is written
# per mode, because "I scored 12,400" is a different sentence from "I lasted
# 4:12" and neither is "I beat Duelist".
#
# The door only exists where a sheet exists to open. `Sharing.available()` is
# false on desktop and false in an export that left the addon out, and a door
# that cannot work is worse than no door at all.

## Whether the Share door is worth drawing.
func _share_possible() -> bool:
	return Sharing.available()


func _share_sub() -> String:
	if mode == Mode.SURVIVAL:
		return "post your run"
	if mode == Mode.DAILY:
		return "post today's board"
	return "post the result"


## Whoever was in the other seat. Found by walking the seats rather than kept in
## a variable, so it is right for a bot, a person, and the daily's empty chair.
func _share_rival() -> SideState:
	for s: SideState in sides:
		if s != player and s.in_match:
			return s
	return null


## What to call whoever you played, to somebody who was not there.
##
## In a two-seat match the rival's label is the bare word "CPU" — the summary has
## the roster on screen and does not need to repeat the name. A share leaves the
## game, where "CPU beat me" says nothing at all and "BERSERKER beat me" is a
## character somebody might want to go and meet. `difficulty` is the bot that was
## actually dealt, and is the word "Versus" only when the rival is a person.
func _share_rival_name() -> String:
	var rival := _share_rival()
	if difficulty != "Versus" and difficulty != "":
		return difficulty.to_upper()
	return _show_name(rival.label) if rival != null else "the CPU"


## The sentence beside the picture.
##
## Written to be worth reading by somebody who has never heard of this game,
## which rules out the shorthand the summary itself can use — nobody outside
## knows what a stamp is or who Duelist is supposed to be.
func _share_text() -> String:
	# The link is appended once, here, rather than written into four sentences —
	# it is the half of the share that does any work, and the way to ship three
	# of these with a link and the fourth without is to write it out four times.
	return "%s\n%s" % [_share_line(), Sharing.STORE_URL]


## The sentence, without the link.
##
## Every one of these ends by asking for something, because the message body is
## the half of a share that arrives as text in a chat window — the picture may be
## collapsed behind a tap, and a line that only reports a number gives nobody a
## reason to open it. The card asks the same question in bigger letters; this is
## the version that survives being quoted.
func _share_line() -> String:
	var me := _commas(player.score)
	if mode == Mode.SURVIVAL:
		return "I lasted %s in Word Wars Survival — %s points. Think you can last longer?" % [
			_survival_clock(match_time), me]
	if mode == Mode.DAILY:
		var streak: int = Profile.daily_streak(daily_key())
		var line := "I scored %s on today's Word Wars daily board." % me
		if streak > 1:
			line += " %d days running." % streak
		# The daily's own hook, and the only one that is an invitation rather
		# than a boast: the board is the same one for everybody, today only.
		return line + " You get the same board — go and beat it."
	var rival := _share_rival()
	var them := _share_rival_name()
	var theirs: String = _commas(rival.score) if rival != null else "0"
	if winner == "YOU":
		return "I beat %s %s to %s at Word Wars. Your turn." % [them, me, theirs]
	return "%s beat me %s to %s at Word Wars. Somebody go and take them down." % [
		them, theirs, me]


## What the picture says.
##
## Four things, in the order somebody reading it takes them in: the number the
## mode is actually about, a badge saying why that number is worth anything, the
## best word of the match as proof of what kind of game this is, and a question
## aimed at whoever is holding the phone.
##
## The badge is the part that took the most working out, because "is this any
## good" is a different question in each mode and none of them can be answered
## from the score alone. Survival has the run it just banked, the daily has a
## streak, and a match has a margin. Where a mode has nothing to say the badge is
## left empty and the card simply closes up around it.
func _share_card_data() -> ShareCard.Card:
	var c := ShareCard.Card.new()
	var win := winner == "YOU"

	# Every mode produces one, and it is the only thing on the card that tells a
	# stranger this is a word game at all. See `share_card.gd`.
	c.word = player.best_word
	if c.word != "" and player.best_word_score > 0:
		c.word_note = "worth %s" % _commas(player.best_word_score)

	if mode == Mode.SURVIVAL:
		c.mode = "Survival"
		c.accent = SURVIVAL_ACCENT
		c.headline = _survival_clock(match_time)
		c.headline_note = "survived"
		# `survival_took` is the only place the answer is knowable. By the time
		# the summary draws, `survival_best_time` has already been raised to
		# include this run, so comparing against it here would call every run a
		# record.
		if bool(survival_took.get("time", false)):
			c.badge = "new personal best"
			c.badge_hot = true
		elif Profile.survival_best_time > 0.0:
			c.badge = "my record: %s" % _survival_clock(Profile.survival_best_time)
		c.stats = [
			["Score", _commas(player.score)],
			["Best run", _survival_clock(Profile.survival_best_time)],
			["Runs", str(Profile.survival_runs)]]
		c.dare = "can you last %s?" % _survival_clock(match_time)
		c.footer = "one board, no opponent, and it never stops coming"
		_challenge_badge(c)
		return c

	if mode == Mode.DAILY:
		c.mode = "Daily Board"
		c.accent = Color("#ffd166")
		c.headline = _commas(player.score)
		c.headline_note = "on today's board"
		var streak: int = Profile.daily_streak(daily_key())
		# `record_daily` has already folded this run into `daily_best`, so the
		# test is against-or-equal rather than greater — and guarded on a score
		# above zero, or a first-ever blank run would announce itself as a record.
		if player.score > 0 and player.score >= Profile.daily_best:
			c.badge = "new daily best"
			c.badge_hot = true
		elif streak > 1:
			c.badge = "%d day streak" % streak
			c.badge_hot = streak >= 7
		c.stats = [["Date", daily_key()]]
		if streak > 1:
			c.stats.append(["Streak", "%d days" % streak])
		if Profile.daily_best > 0:
			c.stats.append(["My best", _commas(Profile.daily_best)])
		c.dare = "can you beat %s?" % _commas(player.score)
		# The whole reason a daily is worth sharing: it is not a boast about a
		# board nobody else can play, it is an invitation to the same one.
		c.footer = "everybody gets the same board — today only"
		_challenge_badge(c)
		return c

	var rival := _share_rival()
	var them := _share_rival_name()
	c.mode = "Versus" if difficulty == "Versus" else "Solo"
	c.accent = Color("#c77dff") if difficulty == "Versus" else Color("#7bdff2")
	c.verdict = "WON" if win else "LOST"
	c.headline = _commas(player.score)
	c.headline_note = "points"
	var margin: int = absi(player.score - rival.score) if rival != null else 0
	if win and player.lives >= LIVES:
		c.badge = "flawless — never lost a life"
		c.badge_hot = true
	elif rival != null:
		c.badge = "%s by %s" % ["won" if win else "lost", _commas(margin)]
	if rival != null:
		c.stats = [
			[them, _commas(rival.score)],
			["Margin", _commas(margin)],
			["Words", str(player.words_played)]]
	if win:
		c.dare = "can you beat %s?" % _commas(player.score)
		c.footer = "I already put %s down" % them
	else:
		c.dare = "somebody take %s down" % them
		c.footer = "they beat me %s to %s" % [
			_commas(rival.score) if rival != null else "0", _commas(player.score)]
	return c


## Draw the card, then hand it and the text to the sheet.
##
## Async because the card is rendered in a viewport and a viewport does not draw
## on the frame you fill it. The scoreboard stays up throughout — nothing here
## changes the phase — so a slow render looks like a button that took a moment
## rather than a screen that went away.
func _do_share() -> void:
	if not _share_possible():
		Sfx.play("reject", 1.2)
		return
	Sfx.play("count", 1.2)
	# The wordmark on the card wears the same face it wears on the title screen.
	# A share is the first time most people see this game's name and it may as
	# well be the game's own lettering rather than the system's.
	var card := ShareCard.new(_font, _font_bold, _font_title)
	add_child(card)
	var path: String = Sharing.card_path()
	var drew: bool = await card.render(_share_card_data(), path)
	card.queue_free()

	var text := _share_text()
	# The picture is the better share by a distance, but a card that failed to
	# draw is not a reason to offer nothing — the text still carries the result.
	var sent: bool = Sharing.share_image(path, "Word Wars", "Word Wars", text) \
		if drew else Sharing.share_text("Word Wars", "Word Wars", text)
	if not sent:
		Sfx.play("reject", 1.2)


# ------------------------------------------------------------- the daily board
#
# A match summary compares you against whoever you played. A daily summary has
# nobody to compare you against, so it compares you against yourself: every run
# on file, ranked, with today's picked out of it. That is the only comparison
# that means anything in a mode where everybody plays the same board once — and
# unlike a global ranking it is there on the first day, on a plane, and on a
# machine that has never heard of Game Center.
#
# Where a global ranking *is* reachable it is two more lines underneath, from
# `Boards`. Never more than that: it can be missing, stale or signed out, and
# the board above it has to stand on its own.

## How many past runs the board shows at most. Small on purpose — this is the
## tail of the summary, under a table and above the buttons, and a scrolling
## history belongs on a screen of its own rather than in the last third of this
## one. Today's run is drawn on top of this when it did not make the cut, so the
## board is at most one row taller than this says.
const DAILY_BOARD_ROWS := 8
const DAILY_ROW_H := 26.0
const DAILY_HEAD_H := 30.0

## What the board must leave below itself: the buttons, the mastery strip and
## the key hints. The summary does not scroll — `_scrollable` deliberately
## excludes `Phase.OVER`, because it is a composition rather than a list — so
## anything this block takes is taken from something that has nowhere to go.
##
## Not scaled by `_over_fill`, unlike everything else down here, because none of
## what it is reserving for is either: the buttons under the summary are laid out
## at a flat 96 high in both orientations. Scaling it cost the phone — which has
## 1440 to play with and half of it empty — five rows it had room for, while the
## 720-tall desktop window it was meant to protect is the one that actually needs
## every pixel of this.
const DAILY_BOARD_RESERVE := 180.0


## Which half of the board the summary is showing: 0 is today's leaderboard,
## 1 is your own past runs.
##
## Today's board is the default, and that is a change of mind about what this
## screen is for. The comment above still describes what was here before —
## a personal history, chosen because it works on a plane and on a machine that
## has never heard of Game Center — and that reasoning was sound about
## *availability* and wrong about what the player wants to know. The daily is
## the one mode where everybody plays the same board once, which makes it the
## one mode where a ranking against other people means anything at all. Ranking
## somebody against their own last fortnight, on the one screen where a real
## comparison exists, was answering a question nobody had asked.
##
## So the peers come first and the history is a tab away, and the fallback is
## unchanged: no account, no network, no board — the history is all there is and
## it is what gets drawn, with no tabs over it to advertise the half that is
## missing. Held across runs rather than reset per summary, so a player who
## prefers their own history is not made to ask for it every day.
var daily_board_tab := 0


## Whether Game Center has handed over a page of today's board worth drawing.
##
## The board and the window are checked as well as the rows, because `Boards`
## has exactly one set of `view_*` and the board *screen* shares it. Without
## this the summary would happily draw whatever that screen was last looking at
## — survival, all-time — under a heading that says today.
func _daily_peers_ready() -> bool:
	if not _daily_page_is_todays():
		return false
	return not Boards.view_rows.is_empty() or not Boards.view_me.is_empty()


## Whether `Boards` is holding — or fetching — a page of the board this screen
## is about.
func _daily_page_is_todays() -> bool:
	return Boards.view_board == Boards.DAILY_ID and Boards.view_time == Boards.TODAY


## Whether the peers tab is worth offering at all, which is true a beat before
## it has anything on it.
##
## The difference between this and `_daily_peers_ready` is the second or so
## Apple takes to answer, and it is the whole reason both exist. Without it the
## summary draws the history with no tabs, the page lands, and the block
## silently becomes a different board half a row taller — with the buttons
## underneath moving to meet it, under a thumb that was already on its way down.
## Claiming the space up front costs an empty panel for a moment and keeps
## everything below it still.
##
## LOADING only. A desktop build has no Game Center and `open_view` leaves the
## state at OFF; a signed-out phone leaves it FAILED. Neither is a page on its
## way, and neither should put a tab on this screen advertising a board the
## player cannot see.
func _daily_peers_live() -> bool:
	if _daily_peers_ready():
		return true
	return _daily_page_is_todays() \
		and Boards.view_state == Boards.ViewState.LOADING


## What stands in for the rows when the peers tab has none: the wait, or the
## reason there will not be any. Empty when there are rows to draw instead.
func _daily_message() -> String:
	if not _daily_showing_peers() or not Boards.view_rows.is_empty() \
			or not Boards.view_me.is_empty():
		return ""
	if Boards.view_state == Boards.ViewState.LOADING:
		return "reading today's board…"
	if Boards.view_state == Boards.ViewState.EMPTY:
		return "nobody else has played today's board yet"
	return Boards.view_status if Boards.view_status != "" \
		else "today's board is out of reach"


## How much room the peers tab takes when it has a sentence on it rather than
## rows. Two rows' worth: enough for the message to sit in the middle of, and
## enough that the first couple of rows arrive into space that was already
## there.
const DAILY_WAIT_H := 60.0


## Whether the history tab has anything behind it. A first-ever daily has one
## run on file — today's — which is a board of one row and still worth drawing,
## because tomorrow it is two.
##
## Reads the dictionary rather than calling `daily_ranked`, which duplicates
## every row and sorts them. This is asked several times a frame by the layout
## measurements below, and the answer it needs is only "is there anything".
func _daily_mine_ready() -> bool:
	return not Profile.daily.is_empty()


## Whether both halves exist, which is the only case that earns a pair of tabs.
## One half on its own is simply the board, drawn under its own heading.
func _daily_tabs_up() -> bool:
	return _daily_peers_live() and _daily_mine_ready()


func _daily_showing_peers() -> bool:
	if not _daily_peers_live():
		return false
	if not _daily_mine_ready():
		return true
	return daily_board_tab == 0


## The header, which is taller in portrait when it has to carry a pair of tabs
## under the heading. Every height below is measured off this rather than off the
## constant, or the first row lands on the tabs the moment they appear.
##
## Landscape gets no extra height and the tabs go *in* the header line instead —
## see `_daily_tab_rects`. The 720-tall design space has about forty pixels
## spare under the score table once `DAILY_BOARD_RESERVE` has had its share,
## which is one row of board; a tab row of its own took that row and left the
## summary with a heading, two tabs and nothing under them. Portrait has 1440 and
## can afford the cleaner arrangement, so it keeps it.
func _daily_head_h() -> float:
	if not _daily_tabs_up() or not portrait:
		return DAILY_HEAD_H * _over_fill()
	return (DAILY_HEAD_H + 34.0) * _over_fill()


## How many rows fit, with or without a row given up to the footnote. Split from
## the two functions below so neither has to ask the other and recurse.
func _daily_fit_for(with_foot: bool) -> int:
	var fill := _over_fill()
	var avail: float = get_viewport_rect().size.y - safe_bottom \
		- DAILY_BOARD_RESERVE - _over_table_foot() \
		- _daily_head_h() - 16.0 * fill
	if with_foot:
		avail -= DAILY_ROW_H * fill
	return maxi(0, int(floor(avail / ((DAILY_ROW_H + 4.0) * fill))))


## Whether the footnote gets a row of its own, which it only does once there is
## a board above it to be a footnote to.
##
## Landscape has never had room for both, and this is where that showed up. A
## 720-tall window leaves about fifty pixels under the score table once
## `DAILY_BOARD_RESERVE` has taken the buttons' share — one row of board, or one
## line of footnote, and not the two. The footnote used to take it silently, so
## a desktop summary with a Game Center rank on it drew the heading, the rank,
## and no board at all. The rows win now: a comment on a list that is not there
## is not worth the row it is printed on.
func _daily_foot_up() -> bool:
	return _daily_footnote() != "" and _daily_fit_for(true) > 0


## How many rows there is actually room for, which is not the same question as
## how many there are. Zero is a real answer and means the board is left out.
func _daily_board_fit() -> int:
	return _daily_fit_for(_daily_foot_up())


## The rows to draw, whichever tab is up.
##
## Both halves are flattened to the same four keys — `rank`, `label`, `score`,
## `mine` — so there is one draw loop rather than two that have to be kept
## looking alike. They already looked alike: the board screen's rows and this
## one's were the same panel language by design, and the only real difference
## between a peer board and a history is whether the left-hand column is a name
## or a date.
func _daily_rows() -> Array:
	return _daily_peer_rows() if _daily_showing_peers() else _daily_mine_rows()


## Today's board, as far down it as there is room for, with your own row
## appended when the page does not already carry it.
##
## `Boards` has already done the hard half of this — `view_me` is exactly the
## "you are not on this page" case — so this is a trim rather than a ranking.
func _daily_peer_rows() -> Array:
	var room := _daily_board_fit()
	if room <= 0:
		return []
	var page: Array = Boards.view_rows
	var me: Dictionary = Boards.view_me
	# Your own row is the one that must survive the squeeze, the same way today's
	# run does on the history tab: a board that ranks four strangers and leaves
	# out where *you* came has answered the wrong question.
	var top_n := mini(page.size(), room - (1 if not me.is_empty() else 0))
	top_n = maxi(top_n, 0)

	# A Game Center display name is somebody else's free text — the one thing on
	# this screen the game did not write — so it goes through the same filter
	# every other name the game repeats back does. The boards screen has always
	# done this; putting a second list of other people's names on the summary
	# without it would have been a new way for an unfiltered name to reach a
	# player, on the one screen every daily run ends at.
	var out: Array = []
	for i in top_n:
		var row: Dictionary = page[i]
		out.append({
			"rank": int(row["rank"]),
			"label": "YOU" if bool(row.get("me", false))
				else _show_name(String(row["name"])),
			"score": int(row["score"]),
			"mine": bool(row.get("me", false)),
		})
	if not me.is_empty():
		out.append({
			"rank": int(me["rank"]),
			"label": "YOU",
			"score": int(me["score"]),
			"mine": true,
		})
	return out


## The best few runs on file, plus today's wherever it landed.
##
## Today is always on the board even when it was a bad run, because "where did I
## come today" is the question the screen is being asked. A run that missed the
## cut is appended at its real rank rather than promoted into the list, so the
## numbers down the left stay honest and the gap says what it means.
func _daily_mine_rows() -> Array:
	var all := Profile.daily_ranked()
	if all.is_empty():
		return []
	var room := _daily_board_fit()
	if room <= 0:
		return []
	var key := daily_key()
	var here := Profile.daily_rank(key)
	var top_n := mini(mini(DAILY_BOARD_ROWS, all.size()), room)
	# Today's own row is the one that must survive a squeeze. Whether it needs a
	# row of its own depends on how many rows there is room for and not on the
	# cap: at two rows and a run that came eighth, today is outside the list
	# however generous the cap is. Testing against the cap instead dropped it
	# altogether on a landscape window — the summary ranked two old scores and
	# said nothing at all about the run just played.
	if here > top_n:
		top_n = maxi(0, mini(top_n, room - 1))

	var out: Array = []
	for i in top_n:
		var row: Dictionary = all[i]
		var day := String(row["day"])
		out.append({
			"rank": i + 1,
			# TODAY rather than the date, on the one row where the date is a thing
			# the player already knows and the word is what they are looking for.
			"label": "TODAY" if day == key else _daily_short_day(day),
			"score": int(row["score"]),
			"mine": day == key,
		})
	if here > top_n:
		var mine: Dictionary = all[here - 1]
		out.append({
			"rank": here,
			"label": "TODAY",
			"score": int(mine["score"]),
			"mine": true,
		})
	return out


## Whether Game Center has a placing worth printing. A rank of zero is every
## reason at once — no device, signed out, never submitted, Apple said no — and
## all of them come to the same thing on screen: say nothing.
func _daily_has_global() -> bool:
	return Boards.rank > 0 or Boards.friend_rank > 0


## The line under the board, which is a different sentence per tab.
##
## On the history tab it is the two Game Center placings, which are the only
## thing on that tab connecting it to anybody else. On the peers tab those
## placings are the list — you can see where you came by looking — so the line
## carries what it would take to move up instead, which is the number that makes
## a leaderboard a target rather than a verdict. See `_boards_climb`.
func _daily_footnote() -> String:
	if _daily_showing_peers():
		return _boards_climb()
	if not _daily_has_global():
		return ""
	var bits: Array = []
	if Boards.rank > 0:
		bits.append("GLOBAL #%s%s" % [_commas(Boards.rank),
			(" of %s" % _commas(Boards.total)) if Boards.total > 0 else ""])
	if Boards.friend_rank > 0:
		bits.append("FRIENDS #%d%s" % [Boards.friend_rank,
			(" of %d" % Boards.friend_total) if Boards.friend_total > 0 else ""])
	return "      ".join(bits)


## How much room the whole block wants, and zero when it is not on screen. Every
## piece of the summary below the table hangs off `_over_foot`, so this has to
## agree with what `_draw_daily_board` actually draws or the buttons land on it.
func _daily_board_h() -> float:
	if phase != Phase.OVER or mode != Mode.DAILY:
		return 0.0
	var rows := _daily_rows()
	var body := float(rows.size()) * (DAILY_ROW_H + 4.0) * _over_fill()
	if rows.is_empty():
		# No rows and nothing to say about why is a board that is not on this
		# screen at all — a first-ever daily on a desktop build, where there is
		# neither a history nor a Game Center to have one.
		if _daily_message() == "":
			return 0.0
		body = DAILY_WAIT_H * _over_fill()
	var h := _daily_head_h() + body
	if _daily_foot_up():
		h += DAILY_ROW_H * _over_fill()
	return h + 16.0 * _over_fill()


## The tabs, as rectangles, in the order they are drawn. Empty when there is
## only one board to show — see `_daily_tabs_up`.
##
## Built here rather than in `_menu_buttons` so the drawing and the hit-testing
## read off one function, and handed *the same* `top` the board is drawn from.
## The summary's block moves whenever the table above it changes height, and two
## places computing that independently is how a tab ends up a row above the
## thing it selects.
func _daily_tab_rects(size: Vector2, top: float) -> Array:
	if not _daily_tabs_up():
		return []
	var fill := _over_fill()
	var tw: float = minf(760.0, size.x - GRID_MARGIN * 2.0)
	var x0: float = size.x * 0.5 - tw * 0.5
	if not portrait:
		# Inside the header line, centred in the gap between the heading on the
		# left and the streak on the right. Narrower than the portrait pair
		# because it is sharing a row rather than owning one, and the two labels
		# are short enough to survive it.
		var lw := 112.0
		var lx: float = size.x * 0.5 - lw - 4.0
		return [
			Rect2(lx, top + 2.0, lw, 24.0),
			Rect2(lx + lw + 8.0, top + 2.0, lw, 24.0),
		]
	var bw: float = minf(190.0 * fill, (tw - 8.0) * 0.5)
	var y := top + (DAILY_HEAD_H - 4.0) * fill
	return [
		Rect2(x0, y, bw, 28.0 * fill),
		Rect2(x0 + bw + 8.0, y, bw, 28.0 * fill),
	]


## "2026-08-19" as "19 AUG". The year is the same for every row that matters and
## a column of it is four characters of nothing.
func _daily_short_day(key: String) -> String:
	const MONTHS := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
		"JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
	var bits := key.split("-")
	if bits.size() != 3:
		return key
	var m := int(bits[1])
	if m < 1 or m > 12:
		return key
	return "%d %s" % [int(bits[2]), MONTHS[m - 1]]


func _draw_daily_board(size: Vector2, top: float, tint: Color) -> void:
	var rows := _daily_rows()
	var message := _daily_message()
	if rows.is_empty() and message == "":
		return
	var peers := _daily_showing_peers()
	var key := daily_key()
	var fill := _over_fill()
	var tw: float = minf(760.0, size.x - GRID_MARGIN * 2.0)
	var x0: float = size.x * 0.5 - tw * 0.5

	# The header carries the streak, because the streak is a fact about this
	# board rather than about today's run — and because it is the one number on
	# the summary that a player can lose by not coming back tomorrow. It stays on
	# both tabs for that reason: it is about the habit, not about the ranking.
	var heading := "TODAY'S BOARD" if peers else "YOUR DAILY BOARD"
	if peers and Boards.view_total > 0:
		heading = "TODAY'S BOARD  ·  %s PLAYING" % _commas(Boards.view_total)
	_otext_left(_font, Vector2(x0 + 4.0, top + 10.0 * fill), heading,
		_over_size(12), Color("#7c88ad"))
	var streak: int = Profile.daily_streak(key)
	if streak > 0:
		var note := "%d DAY%s RUNNING" % [streak, "" if streak == 1 else "S"]
		if Profile.daily_best_streak > streak:
			note += "   ·   BEST %d" % Profile.daily_best_streak
		var m := _font_bold.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1,
			_over_size(12))
		_otext_left(_font_bold, Vector2(x0 + tw - m.x - 4.0, top + 10.0 * fill),
			note, _over_size(12), Color("#ffd166"))

	# The two tabs, when there are two boards to choose between. Drawn from the
	# same rectangles `_menu_buttons` hit-tests, so a press and a highlight can
	# never disagree about where they are.
	var tabs := _daily_tab_rects(size, top)
	if tabs.size() == 2:
		var labels := ["TODAY", "YOUR RUNS"]
		for i in 2:
			var on: bool = (i == 0) == peers
			var act := "dtab:%d" % i
			var hot: bool = _hover_action == act
			_panel(tabs[i], Color("#1b2444") if (on or hot) else Color("#101733"),
				Color(Color("#ffd166"), 0.95 if on else (0.5 if hot else 0.18)),
				6.0, 2.0 if on else 1.0)
			_otext(_font_bold, (tabs[i] as Rect2).get_center(), labels[i],
				_over_size(12), Color("#e6ecff") if on else Color("#8d99bd"))

	var y := top + _daily_head_h()
	# The wait, or the reason there is nothing to wait for, in the space the rows
	# will land in. `_daily_board_h` has already reserved it — see `DAILY_WAIT_H`.
	if rows.is_empty():
		_text_fit_overlay(_font, Vector2(size.x * 0.5,
			y + DAILY_WAIT_H * fill * 0.5), message, _over_size(13), tw,
			Color("#7c88ad"), 10)
		return
	for row: Dictionary in rows:
		var mine: bool = bool(row["mine"])
		var rank := int(row["rank"])
		var r := Rect2(x0, y, tw, DAILY_ROW_H * fill)
		_panel(r, Color("#1b2444") if mine else Color("#121930"),
			Color(tint if mine else Color("#2b3560"), 0.85 if mine else 0.5),
			6.0, 2.0 if mine else 1.0)

		var cy := r.get_center().y
		# `_commas` on the rank as well as the score. The history tab counts in
		# tens and the global board counts in tens of thousands, and "#14302" in
		# a column of four-character ranks is the one number on this screen a
		# player has to stop and parse.
		_otext_left(_font_bold, Vector2(x0 + 12.0, cy), "#%s" % _commas(rank),
			_over_size(13), Color("#ffd166") if rank == 1 else Color("#7c88ad"))
		# Fitted rather than drawn at a fixed size: a date is five characters and
		# a Game Center display name is whatever somebody typed into it. Cut to
		# the space between the rank and the score, so a long name pushes on
		# nothing and overlaps nothing.
		var name_x := x0 + 58.0 * fill
		var score := _commas(int(row["score"]))
		var sm := _font_bold.get_string_size(score, HORIZONTAL_ALIGNMENT_LEFT, -1,
			_over_size(15))
		var name_w: float = tw - (name_x - x0) - sm.x - 24.0
		_otext_left(_font_bold if mine else _font, Vector2(name_x, cy),
			String(row["label"]),
			_fitted_size(_font_bold if mine else _font, String(row["label"]),
				_over_size(13), name_w, 9),
			Color("#e6ecff") if mine else Color("#8d99bd"))
		_otext_left(_font_bold, Vector2(x0 + tw - sm.x - 12.0, cy), score,
			_over_size(15), Color("#ffd166") if mine else Color("#e6ecff"))
		y += DAILY_ROW_H * fill + 4.0

	# A footnote to the board above rather than a row of it — it is about a
	# different population on one tab and about a gap on the other, and neither
	# is a placing in the list — so it is typed smaller and is not panelled.
	# `_daily_foot_up` rather than the string, because on a short window the row
	# it would need has been given to the board. See there.
	if not _daily_foot_up():
		return
	_text_fit_overlay(_font, Vector2(size.x * 0.5, y + DAILY_ROW_H * fill * 0.5),
		_daily_footnote(), _over_size(12), tw, Color("#64dfdf"), 9)


# --------------------------------------------------------- the board screen
#
# The daily summary's two Game Center rows say where you came. This screen is
# the other half of that sentence: who else is there, and what they scored.
#
# It is the first thing in the game that draws other people's names, and it is
# the first screen that can be *entirely* empty — no account, no network, a
# board with nobody on it yet. So unlike the summary, which hides its Game
# Center rows and still has a board underneath, this one has nothing to fall
# back on and has to say what happened instead. Every one of those sentences is
# in `_boards_message`, and there is a different one for each cause, because
# "sign in to Game Center" and "nobody has played this yet" are not the same
# problem and only one of them is the player's to fix.
#
# Two tabs by two tabs: which board, and which crowd. That is four requests and
# the screen holds one at a time — `Boards.open_view` replaces whatever was
# there, and a reply for a tab you have since left is dropped rather than drawn.

## Which board and which crowd, held across a trip back to the title so
## returning lands where you left rather than resetting to the daily.
var board_tab := 0
var board_scope := 0

const BOARDS_ROW_H := 34.0
const BOARDS_ROW_GAP := 5.0
## Where the list starts, measured from the top of the header. Everything above
## it — title, totals, the two rows of tabs — is fixed, so this is one number
## rather than a running sum.
const BOARDS_LIST_TOP := 232.0


## The same trick every other menu here plays, and this screen shipped without
## it: a layout drawn in the 720-tall landscape design space, handed a phone
## twice that height, keeping its 34-unit rows and 14-point type. It measured
## fine and read as a spreadsheet — small text in the top third with a band of
## nothing under it.
##
## 1.5 rather than the 1.35 the summary uses. A leaderboard row is one line of
## three short things with no second line under it, so it can afford to be
## bigger than a table row, and this is the screen where a name being easy to
## read *is* the content.
func _boards_fill() -> float:
	return 1.5 if portrait else 1.0


## Type on this screen, at a size the phone it is on can be read at.
func _boards_size(base: int) -> int:
	return int(round(float(base) * (1.35 if portrait else 1.0)))


func _boards_row_h() -> float:
	return BOARDS_ROW_H * _boards_fill()


func _boards_row_gap() -> float:
	return BOARDS_ROW_GAP * _boards_fill()


## The top three are drawn taller than the rest.
##
## A leaderboard whose rows are all identical is a table, and a table is a thing
## you read rather than a thing you want to be on. The podium is the only part
## of this screen that says the top is a different place from the middle — so it
## is where the extra height goes, and it is why the ramp below stops at three
## rather than shading the whole list.
func _boards_rank_h(rank: int) -> float:
	if rank > 3:
		return _boards_row_h()
	return _boards_row_h() * (1.30 if rank == 1 else 1.15)


## Gold, silver, bronze — then the ordinary row colour. Read straight out of the
## palette the rest of the game already uses rather than invented here: the gold
## is the same gold DAILY and every "new best" is set in.
func _boards_rank_tint(rank: int) -> Color:
	match rank:
		1: return Color("#ffd166")
		2: return Color("#c8d2e8")
		3: return Color("#e08b4c")
	return Color("#7c88ad")


func _board_id() -> String:
	return Boards.SURVIVAL_ID if board_tab == 1 else Boards.DAILY_ID


## The daily is filtered to today because that is what the word means — every
## run on it is one attempt at one shared board, and yesterday's is a different
## contest. Survival is a lifetime best and its whole history *is* the ranking,
## so it asks for all time; filtering it to today would show an empty board to
## anybody who last played yesterday.
func _board_time() -> int:
	return Boards.ALL_TIME if board_tab == 1 else Boards.TODAY


func _board_tint() -> Color:
	return SURVIVAL_ACCENT if board_tab == 1 else Color("#ffd166")


## Ask for whatever the tabs currently say. Every path onto this screen and
## every tab press goes through here, so there is one place that can be wrong.
func _open_board_view() -> void:
	Boards.open_view(_board_id(), board_scope, _board_time())
	Boards.refresh_challenges()


## The header, offset by however far the screen has been dragged.
func _boards_head() -> float:
	return safe_top + _menu_offset(_boards_laid())


## One button under the list. Door-sized in portrait, because at full width
## `_draw_menu_button` draws these as plates — the same object the title screen
## is built from — and a plate needs the height to carry a stamp and a sub line.
func _boards_button_h() -> float:
	return 76.0 if portrait else 44.0


func _boards_button_gap() -> float:
	return 10.0 if portrait else 8.0


## How tall the block of buttons under the list is.
##
## Counted from the same conditions `_menu_buttons` builds them from, and
## deliberately *not* by asking `_menu_buttons` — that calls `_boards_head`,
## which calls `_boards_laid`, which is what wants this number. Two places that
## have to agree, and the alternative is a stack overflow on a menu.
func _boards_buttons_h() -> float:
	var h := 0.0
	var step := _boards_button_h() + _boards_button_gap()
	if Boards.challenges_available():
		h += step
	if Boards.available():
		h += step
	if not portrait:
		h += 40.0
	return h


## Where the list starts, scaled. Everything above it — the title, the totals
## and the two rows of tabs — grows with the phone too, so the number the list
## hangs off has to grow with them or the tabs land on the first row.
func _boards_list_top() -> float:
	return BOARDS_LIST_TOP * (1.22 if portrait else 1.0)


## How tall the first `n` rows are, podium included. The rows are no longer all
## the same height, so every place that used to multiply by one row height has
## to walk them instead.
func _boards_rows_h(n: int) -> float:
	var h := 0.0
	for i in mini(n, Boards.view_rows.size()):
		h += _boards_rank_h(int((Boards.view_rows[i] as Dictionary)["rank"])) \
			+ _boards_row_gap()
	return h


## How many rows there is actually room for.
##
## Portrait scrolls, so the answer is all of them. Landscape does not —
## `_scrollable` excludes it on every screen in the game — so the list would run
## off the bottom and take the buttons under it off-screen with it. There is
## nowhere to scroll to reach them, so the list is cut instead. Same trade as
## `_daily_board_fit`.
func _boards_fit() -> int:
	var have := Boards.view_rows.size()
	if _scrollable():
		return have
	var avail: float = get_viewport_rect().size.y - safe_top - safe_bottom \
		- _boards_list_top() - _boards_buttons_h() - 40.0
	if not Boards.view_me.is_empty():
		avail -= _boards_row_h() + 14.0
	var used := 0.0
	var n := 0
	while n < have:
		var next: float = _boards_rank_h(int((Boards.view_rows[n] as Dictionary)["rank"])) \
			+ _boards_row_gap()
		if used + next > avail:
			break
		used += next
		n += 1
	return n


## How tall the screen wants to be. Feeds the scroll limit, so it has to count
## the message the list is replaced by when there are no rows — otherwise a
## signed-out phone has a screen it cannot scroll to the buttons on.
func _boards_laid() -> float:
	return _boards_list_top() + _boards_list_h() + _boards_buttons_h() + 60.0


## The list itself, message included. One number, so the three places that need
## it cannot drift.
func _boards_list_h() -> float:
	var rows := _boards_fit()
	var h := _boards_rows_h(rows)
	if not Boards.view_me.is_empty():
		# The gap that detaches your row from the list, and the row.
		h += _boards_row_h() + 14.0
	# The climb line hangs under whichever of the two your row turned out to be.
	if _boards_climb() != "":
		h += 26.0 * _boards_fill()
	if rows == 0:
		h += 64.0
	return h


## The bottom of the list, which is where the buttons start. Built out of
## `_boards_list_h` for the same reason: a button that lands on the last row is
## the failure this screen shares with every other one here.
func _boards_foot() -> float:
	return _boards_head() + _boards_list_top() + _boards_list_h() + 20.0


## Why the list is empty, in the player's terms. Empty string means there are
## rows and nothing needs saying.
##
## The order matters: a signed-out device is also an empty board, and saying
## "nobody has played this yet" to somebody who simply is not signed in sends
## them looking for a problem in the wrong place.
func _boards_message() -> String:
	match Boards.view_state:
		Boards.ViewState.OFF:
			return "Leaderboards need an iPhone signed in to Game Center."
		Boards.ViewState.LOADING:
			return "Reading the leaderboard…"
		Boards.ViewState.FAILED:
			return Boards.view_status if Boards.view_status != "" \
				else "Game Center would not answer."
		Boards.ViewState.EMPTY:
			if board_scope == Boards.FRIENDS:
				return "None of your Game Center friends have posted a score here."
			return "Nobody has posted a score here yet. Be the first."
	return ""


## What is under the title: the size of the field, or the streak, depending on
## which board is up. Both are the reason to come back tomorrow, stated in the
## terms of the board being looked at.
func _boards_subtitle() -> String:
	if Boards.view_total > 0:
		var who := "friends" if board_scope == Boards.FRIENDS else "players"
		var when := "today" if board_tab == 0 else "all time"
		return "%s %s · %s" % [_commas(Boards.view_total), who, when]
	if board_tab == 0:
		var streak: int = Profile.daily_streak(daily_key())
		if streak > 1:
			return "%d days running" % streak
	return ""


## What it would take to move up one place, in points.
##
## This is the line that makes a leaderboard something other than a list of
## strangers. A rank on its own is a verdict — #412 of 9,120, nothing to be
## done about it. The *gap* is a target, and on this board it is almost always
## a small one, because scores cluster: the difference between 412th and 411th
## is usually a single good word.
##
## Only ever computed against rows Apple actually sent. It gives us the page and
## the local entry and nothing in between, so there are two honest answers and
## the good one is only available when you are already on the board.
func _boards_climb() -> String:
	if Boards.view_rows.is_empty():
		return ""
	# Your row is either appended below the page or sitting in it.
	var me: Dictionary = Boards.view_me
	if me.is_empty():
		for r: Dictionary in Boards.view_rows:
			if bool(r.get("me", false)):
				me = r
				break
	if me.is_empty():
		return ""

	var my_rank := int(me.get("rank", 0))
	var mine := int(me.get("score", 0))
	if my_rank == 1:
		return "nobody above you"

	# On the page, so the row directly above is a real player with a real score
	# and the gap is usually one good word. This is the version worth printing.
	for r: Dictionary in Boards.view_rows:
		if int(r["rank"]) == my_rank - 1:
			var gap := int(r["score"]) - mine
			if gap <= 0:
				return ""
			return "%s to take #%s" % [_commas(gap), _commas(my_rank - 1)]

	# Off the page. The bottom of it is the nearest score we were given, so the
	# target is the page itself rather than a rank — "break into the top 25" is
	# a thing to aim at where "reach #25" is a number with no meaning attached.
	var last: Dictionary = Boards.view_rows[Boards.view_rows.size() - 1]
	var far := int(last.get("score", 0)) - mine
	if far <= 0:
		return ""
	return "%s to break into the top %d" % [_commas(far), Boards.view_rows.size()]


func _draw_boards(size: Vector2) -> void:
	var cx := size.x * 0.5
	_overlay.draw_rect(Rect2(-SHAKE_MARGIN, -SHAKE_MARGIN,
		size.x + SHAKE_MARGIN * 2.0, size.y + SHAKE_MARGIN * 2.0),
		Color(bg_top, 0.94), true)
	_draw_decor()

	var hy := _boards_head()
	var tint := _board_tint()
	_otext(_font_bold, Vector2(cx, hy + 58.0), "LEADERBOARDS",
		_boards_size(34), Color("#e6ecff"))
	var sub := _boards_subtitle()
	if sub != "":
		_text_fit_overlay(_font, Vector2(cx, hy + 92.0 * _boards_fill() * 0.72),
			sub, _boards_size(13), size.x - GRID_MARGIN * 2.0,
			Color("#7c88ad"), 10)

	# The tabs are hit-tested out of `_menu_buttons` like everything else, but
	# drawn here: a tab has a selected state and `_draw_menu_button` has no way
	# to show one, so the two kinds of button are told apart by action prefix.
	for b: Dictionary in _menu_buttons():
		var act := String(b["action"])
		if act.begins_with("btab:") or act.begins_with("bscope:"):
			_draw_board_tab(b)
		else:
			_draw_menu_button(b)

	var tw: float = minf(760.0, size.x - GRID_MARGIN * 2.0)
	var x0: float = cx - tw * 0.5
	var y := hy + _boards_list_top()

	if Boards.view_rows.is_empty():
		var msg := _boards_message()
		if msg != "":
			_text_fit_overlay(_font, Vector2(cx, y + 30.0), msg,
				_boards_size(14), tw, Color("#8d99bd"), 10)
		return

	for i in _boards_fit():
		var row: Dictionary = Boards.view_rows[i]
		var rh := _boards_rank_h(int(row["rank"]))
		_draw_board_row(x0, y, tw, rh, row, tint)
		y += rh + _boards_row_gap()

	# Your own row, when the page above does not already carry it. Detached by a
	# gap rather than appended flush, because it is not rank 26 — it is wherever
	# you actually came, and running it on would read as the list continuing.
	if not Boards.view_me.is_empty():
		y += 14.0
		_draw_board_row(x0, y, tw, _boards_row_h(), Boards.view_me, tint)
		y += _boards_row_h()

	# The whole point of drawing your row at all: what it would take to move up.
	# Hangs under the list whether your row was appended below it or was in it.
	var climb := _boards_climb()
	if climb != "":
		_text_fit_overlay(_font_bold, Vector2(cx, y + 15.0 * _boards_fill()),
			climb, _boards_size(12), tw, Color("#64dfdf"), 9)


## One row: rank on the left, score on the right, name in whatever is left
## between them. Same panel language as the daily summary's board, because it is
## the same kind of object and a player has already learned to read that one.
##
## The top three are taller, lit in their own colour and set in bigger type. The
## height arrives as an argument rather than being worked out here, because the
## caller has to walk the same ramp to know where the next row goes.
func _draw_board_row(x0: float, y: float, tw: float, rh: float,
		row: Dictionary, tint: Color) -> void:
	var mine: bool = bool(row.get("me", false))
	var rank := int(row["rank"])
	var podium: bool = rank <= 3
	var medal := _boards_rank_tint(rank)
	var fill := _boards_fill()

	# Your own row wins the border even on the podium — being third is worth
	# less to you than knowing which row is yours.
	var edge: Color = tint if mine else (medal if podium else Color("#2b3560"))
	var width: float = 2.0 if (mine or rank == 1) else (1.5 if podium else 1.0)
	var r := Rect2(x0, y, tw, rh)
	_panel(r, Color("#1b2444") if mine else
		(Color("#161f3d") if podium else Color("#121930")),
		Color(edge, 0.85 if (mine or podium) else 0.5), 6.0, width)

	var cy := r.get_center().y
	# The podium's rank sits in a filled badge rather than being typed like the
	# rest. It is the one element on the screen that has to read as a place
	# rather than a number, and colour alone was not doing it at a glance.
	var rank_text := "#%s" % _commas(rank)
	if podium:
		var bw: float = 44.0 * fill
		var bh: float = 26.0 * fill
		var badge := Rect2(x0 + 10.0, cy - bh * 0.5, bw, bh)
		_panel(badge, Color(medal, 0.16), Color(medal, 0.9), 5.0, 1.0)
		_otext(_font_bold, badge.get_center(), str(rank),
			_boards_size(17 if rank == 1 else 15), medal)
	else:
		_otext_left(_font_bold, Vector2(x0 + 14.0, cy), rank_text,
			_boards_size(14), Color("#ffd166") if mine else Color("#7c88ad"))

	var ssize := _boards_size(19 if rank == 1 else (17 if podium else 16))
	var score := _commas(int(row["score"]))
	var sm := _font_bold.get_string_size(score, HORIZONTAL_ALIGNMENT_LEFT, -1, ssize)
	_otext_left(_font_bold, Vector2(x0 + tw - sm.x - 14.0, cy), score, ssize,
		Color("#ffd166") if mine else (medal if podium else Color("#e6ecff")))

	# A Game Center display name is somebody else's free text — the one thing on
	# this screen the game did not write — so it goes through the same filter as
	# every other name the game repeats back.
	var who := _show_name(String(row.get("name", "")))
	if mine:
		who = "YOU"
	var nx: float = x0 + (68.0 * fill if podium else 84.0)
	var avail: float = (x0 + tw - sm.x - 26.0) - nx
	if avail > 20.0:
		var nfont: Font = _font_bold if (mine or podium) else _font
		var nsize := _boards_size(16 if podium else 14)
		_otext_left(nfont, Vector2(nx, cy), who,
			_fitted_size(nfont, who, nsize, avail, 10),
			Color("#e6ecff") if (mine or podium) else Color("#8d99bd"))


## A tab. Selected is a lit border and a bright label; unselected is neither, so
## the pair reads as one control with a current value rather than two buttons.
func _draw_board_tab(b: Dictionary) -> void:
	var r: Rect2 = b["rect"]
	var on: bool = bool(b.get("on", false))
	var hot: bool = _hover_action == String(b["action"])
	var accent: Color = b["accent"]
	_panel(r, Color("#1b2444") if (on or hot) else Color("#101733"),
		Color(accent, 0.95 if on else (0.55 if hot else 0.18)), 8.0,
		2.0 if on else 1.0)
	var label := String(b["label"])
	_otext(_font_bold, r.get_center(), label,
		_fitted_size(_font_bold, label, 15, r.size.x - 16.0, 10),
		Color("#e6ecff") if on else Color("#8d99bd"))


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
	return MultiplayerManager.current_match != null


## Nothing. Kept as a marker rather than deleted, because the shape of what used
## to be here is the shape of what Game Center still needs.
##
## This wired ten signals from `Link`, the netfox/noray/EOS transport. That stack
## is still autoloaded and still compiled in, but nothing calls `Link.host` or
## `Link.join` any more, so none of those signals can ever fire — the connections
## were live wires to a dead switchboard. Every message they carried has been
## re-pointed at `MultiplayerManager` and arrives through `_on_multiplayer_data`.
##
## `net_link.gd`, the noray addon and the EOS autoloads are all still in the
## project and can go whenever the versus path has been proven on a device.
func _net_setup() -> void:
	pass


func _on_net_match_begin() -> void:
	var plan: Array = Link.seating
	var me := multiplayer.get_unique_id()
	# You are always your own board 0; the rest keep the host's order.
	var others: Array = []
	for seat: Dictionary in plan:
		if int(seat["id"]) != me:
			others.append(seat)

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
			s.bot.configure(s.label, portrait)
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


func _on_net_attack(word: String, tier: int) -> void:
	var side : SideState = player
	if side == null:
		return
	var p := Pending.new()
	# Whoever sent the packet. Their machine holds their score, so a topout has
	# to be reported back to them rather than paid here.
	p.from = 1
	p.tier = clampi(tier, 0, TIERS.size() - 1)
	p.prefix = _mint_stamp(word, STAMP_WANT, side)
	p.cells = _cells(p.tier)
	p.timer = DROP_DELAY
	side.pending.append(p)
	side.flash = 1.0


## A salvo aimed at us. There is no victim to look up in a one-on-one match —
## anything that arrives is arriving here.
func _on_net_salvo(word: String, count: int) -> void:
	var side: SideState = player
	if side == null:
		return
	# Minted here rather than sent over the wire — only the word and the count
	# cross — so the same spread has to be applied on this end. Without it a
	# networked salvo is the one that still arrives under six identical stamps,
	# which is the half of the game nobody testing on one device would see.
	var n := mini(count, 40)
	var stamps := _salvo_stamps(word, n, side)
	for i in n:
		var p := Pending.new()
		p.tier = 0
		p.prefix = String(stamps[i])
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
	# The board on the other end of the match. Routing this by entity id was for
	# a four-way table with peer ids in it; a Game Center match has exactly two
	# boards, and the one arriving is never ours.
	var ai_side: SideState = sides[1] if sides.size() > 1 else null
	if ai_side == null or not ai_side.in_match:
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

	# "t" — their half-typed word — is neither sent nor read any more. An older
	# build on the far end still puts it in the packet; dropping it on the floor
	# here is what makes this end honest regardless of what it is talking to,
	# and is why the change is safe to ship one side at a time.
	ai_side.chain = int(payload.get("c", 0))
	ai_side.chain_timer = float(payload.get("ct", 0.0))
	ai_side.chain_window = maxf(0.001, float(payload.get("cw", 1.0)))
	ai_side.words_played = int(payload.get("w", 0))
	ai_side.blocks_cleared = int(payload.get("cl", 0))
	# Defaulted to what is already held rather than to zero, so a payload from an
	# older build leaves these alone instead of blanking them every tick.
	ai_side.score = int(payload.get("sc", ai_side.score))
	ai_side.dealt = int(payload.get("dl", ai_side.dealt))
	ai_side.best_chain = int(payload.get("bc", ai_side.best_chain))
	ai_side.best_combo = int(payload.get("bk", ai_side.best_combo))
	ai_side.powers_fired = int(payload.get("pw", ai_side.powers_fired))
	ai_side.salvos = int(payload.get("sv", ai_side.salvos))
	ai_side.longest_word = String(payload.get("lw", ai_side.longest_word))
	ai_side.wpm = float(payload.get("wm", ai_side.wpm))
	ai_side.salvo_flash = float(payload.get("sf", 0.0))
	ai_side.lives = int(payload.get("lv", LIVES))
	ai_side.respite = float(payload.get("rs", 0.0))
	ai_side.life_flash = float(payload.get("lf", 0.0))
	ai_side.alive = bool(payload.get("al", true))


## Everything the scoreboard prints about one side, after the match has finished
## with it.
##
## Deliberately the same field names as `_state_of` so the two cannot drift into
## meaning different things, and deliberately a smaller set: no board, no pending
## queue, no chain timers. None of that is drawn on a summary, and sending the
## blocks of a board that has just been detonated would be describing a playfield
## neither player is looking at any more.
func _final_of(who: SideState) -> Dictionary:
	return {
		"sc": who.score, "dl": who.dealt, "w": who.words_played,
		"cl": who.blocks_cleared, "bc": who.best_chain, "bk": who.best_combo,
		"pw": who.powers_fired, "sv": who.salvos, "lw": who.longest_word,
		"wm": _wpm(), "lv": who.lives, "al": who.alive,
	}


## The other end's finished row, taken as read.
##
## Assigned rather than added, which is what makes it safe to arrive at any
## point. This device has usually already applied a victory bonus to its mirror
## of that side by the time this lands — `_end_match` runs the moment a topout is
## known, and this packet is a round trip behind it — and the number in here
## already includes the real one. Assignment replaces a good guess with the
## truth; addition would pay the bonus twice.
##
## Guarded on the phase for the same reason the rematch handshake is: a packet
## that arrives while a *new* match is being played would otherwise overwrite a
## live opponent with the corpse of the last one.
func _on_net_final(payload: Dictionary) -> void:
	if phase != Phase.OVER or ai_side == null:
		return
	ai_side.score = int(payload.get("sc", ai_side.score))
	ai_side.dealt = int(payload.get("dl", ai_side.dealt))
	ai_side.words_played = int(payload.get("w", ai_side.words_played))
	ai_side.blocks_cleared = int(payload.get("cl", ai_side.blocks_cleared))
	ai_side.best_chain = int(payload.get("bc", ai_side.best_chain))
	ai_side.best_combo = int(payload.get("bk", ai_side.best_combo))
	ai_side.powers_fired = int(payload.get("pw", ai_side.powers_fired))
	ai_side.salvos = int(payload.get("sv", ai_side.salvos))
	ai_side.longest_word = String(payload.get("lw", ai_side.longest_word))
	ai_side.wpm = float(payload.get("wm", ai_side.wpm))
	ai_side.lives = int(payload.get("lv", ai_side.lives))
	ai_side.alive = bool(payload.get("al", ai_side.alive))


func _push_state(delta: float) -> void:
	_net_state_timer -= delta
	if _net_state_timer > 0.0:
		return
	_net_state_timer = 1.0 / NET_STATE_HZ

	# One board goes over the wire, because a Game Center match is one on one and
	# the only board the other end cannot see is this one.
	MultiplayerManager.send_state(_state_of(player, 0))


func _state_of(who: SideState, own: int) -> Dictionary:
	var block_specs: Array = []
	for b in who.board.blocks:
		block_specs.append([b.gx, b.gy, b.w, b.h, b.tier, b.prefix])
	var pend_specs: Array = []
	for p: Pending in who.pending:
		pend_specs.append([p.tier, p.prefix, p.timer])

	# No "t". It carried the sender's half-typed word, which is the one thing
	# about a board its owner is entitled to keep — see `_typing_of`. A peer
	# running an older build will still send it and will still expect it; both
	# are fine, because the field was only ever read to be drawn, and the far
	# end reading "" simply draws nothing where it used to draw a secret.
	return {
		"own": own, "b": block_specs, "p": pend_specs,
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
		# Cells this side has dealt, which is not a cosmetic number: the victory
		# bonus is partly `dealt * WIN_DAMAGE_STEP`, and until this was sent the
		# far end computed that term from zero.
		#
		# It cannot be derived at the receiving end either, which is the trap.
		# `_strike` credits `attacker.dealt` on the machine the word was typed
		# on; `_on_net_attack` at the other end only builds the incoming block
		# and never credits the sender. So a mirrored rival dealt nothing all
		# match, and the loser's scoreboard quoted the winner a bonus that was
		# short by the whole damage term.
		"dl": who.dealt,
		# Typing speed is measured from keystrokes, which only exist on the
		# machine they were typed on — so unlike every other column this one
		# cannot be derived at the far end and has to travel.
		"wm": _wpm(),
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
		# A 300x46 button was the same slab a desktop gets, sitting under cards
		# three times its height. In portrait it becomes a door the size of the ones
		# on the title screen — same width as the roster above it — so the last
		# thing on the screen reads as the thing you came to press. The sub line is
		# who you picked, which is both the confirmation and what stops a
		# full-width plate looking half empty.
		var sw: float = minf(654.0 if portrait else 300.0,
			get_viewport_rect().size.x - GRID_MARGIN * 2.0)
		var ssub := ""
		if portrait:
			var who := String(solo_seats[0])
			ssub = "against a name drawn at random" if who == "?" \
				else "against %s" % who
		out.append({
			"rect": Rect2(cx - sw * 0.5, sfoot, sw,
				PORTRAIT_DOOR_H if portrait else 46.0),
			"key": "ENTER",
			"label": "Start", "sub": ssub, "note": "", "rating": 0,
			"accent": Color("#7bdff2"), "action": "solo_start"})
		# Portrait already has the chevron in the corner; a second Back inside the
		# screen is the same button twice.
		if not portrait:
			out.append({
				"rect": Rect2(cx - sw * 0.5, sfoot + 52.0, sw, 32.0), "key": "ESC",
				"label": "Back", "sub": "", "note": "", "rating": 0,
				"accent": Color("#8d99bd"), "action": "title"})
	elif phase == Phase.LOBBY:
		# The doors carry everything about themselves except where they are, so
		# this is a zip rather than a second description of the screen. Anything
		# added to `_lobby_doors` appears here, in the hit test and in the draw
		# without being written down three times.
		var doors := _lobby_doors()
		var drects := _lobby_door_rects()
		for i in doors.size():
			var d: Dictionary = (doors[i] as Dictionary).duplicate()
			d["rect"] = drects[i]
			out.append(d)
		# Portrait already has the chevron in the corner; a second Back inside
		# the screen is the same button twice.
		if not portrait:
			# Below the two footer lines, which hang at +30 and +50 off the same
			# edge. At +22 this sat on top of them.
			out.append({
				"rect": Rect2(cx - 90.0, _grid_bottom(drects, 360.0 + safe_top)
					+ 66.0, 180.0, 38.0),
				"key": "ESC", "label": "Back", "sub": "", "note": "", "rating": 0,
				"accent": Color("#8d99bd"), "action": "title"})
	elif phase == Phase.WEEKLY:
		# One control. Nothing on this screen is pressable — the missions are a
		# report, not a menu — so the only thing it needs is a way out.
		out.append({
			"rect": Rect2(cx - 90.0, _weekly_head() + float(Missions.PER_WEEK)
				* (WEEK_ROW_H + WEEK_ROW_GAP) + 96.0, 180.0, 44.0),
			"key": "ESC", "label": "Back", "sub": "", "note": "", "rating": 0,
			"accent": Color("#8d99bd"), "action": "title"})
	elif phase == Phase.BOARDS:
		var hy := _boards_head()
		# Two rows of two, both centred on the same 304-wide block so the pair of
		# controls reads as one stack rather than two unrelated toolbars.
		var bfill := _boards_fill()
		var tabw: float = minf(148.0 * bfill, (get_viewport_rect().size.x
			- GRID_MARGIN * 2.0 - 8.0) * 0.5)
		var tx: float = cx - tabw - 4.0
		var boards_tabs: Array = [
			[0, "DAILY", Color("#ffd166")],
			[1, "SURVIVAL", SURVIVAL_ACCENT],
		]
		for i in boards_tabs.size():
			var t: Array = boards_tabs[i]
			out.append({
				"rect": Rect2(tx + float(i) * (tabw + 8.0), hy + 112.0 * bfill * 0.86,
					tabw, 40.0 * bfill),
				"key": "", "label": String(t[1]), "sub": "", "note": "", "rating": 0,
				"on": board_tab == int(t[0]), "accent": t[2],
				"action": "btab:%d" % int(t[0])})
		var scopes: Array = [
			[Boards.GLOBAL, "GLOBAL"],
			[Boards.FRIENDS, "FRIENDS"],
		]
		for i in scopes.size():
			var s: Array = scopes[i]
			out.append({
				"rect": Rect2(tx + float(i) * (tabw + 8.0), hy + 164.0 * bfill * 0.86,
					tabw, 36.0 * bfill),
				"key": "", "label": String(s[1]), "sub": "", "note": "", "rating": 0,
				"on": board_scope == int(s[0]), "accent": Color("#7bdff2"),
				"action": "bscope:%d" % int(s[0])})

		# Under the list. `_boards_foot` is measured off the same numbers the
		# rows are drawn with, so these move down as the board fills up.
		var bfoot := _boards_foot()
		# Full width in portrait rather than a 360-wide slab centred in a 720
		# screen. These are the two things you can do from here and they are the
		# lowest things on it, which is where a thumb already is.
		var bw: float = minf(654.0 if portrait else 360.0,
			get_viewport_rect().size.x - GRID_MARGIN * 2.0)
		# Only when there is somewhere to send them. Before a challenge is
		# configured in App Store Connect this opens a dashboard with nothing in
		# it, which is a worse answer than not offering the door.
		var bh := _boards_button_h()
		var bstep := bh + _boards_button_gap()
		if Boards.challenges_available():
			# Waiting challenges are the reason to press it, so they are the sub
			# line rather than a count in brackets after the word.
			#
			# When there are none it says why there are none. "Race a friend on
			# this board" is a fine invitation and a useless answer to the one
			# question somebody actually has at that moment, which is why the
			# challenge they were just sent is nowhere on this screen — and every
			# cause of that except "Apple has nothing" is something they or the
			# build can fix. See `Boards.why_no_challenges`.
			var csub := "race a friend on this board"
			if Boards.pending > 0:
				csub = "%d waiting for you" % Boards.pending
			else:
				var why := Boards.why_no_challenges()
				if why != "":
					csub = why
			out.append({
				"rect": Rect2(cx - bw * 0.5, bfoot, bw, bh), "key": "C",
				"stamp": "CHA", "label": "Challenges", "sub": csub, "note": "",
				"rating": 0,
				"accent": Color("#c77dff") if Boards.pending > 0
					else Color("#8d99bd"),
				"action": "challenges"})
			bfoot += bstep
		# Out to Apple's version of this screen, which has the profiles, the
		# avatars and the button that starts a challenge on it — all of which are
		# Apple's to draw and none of which are worth rebuilding here.
		if Boards.available():
			out.append({
				"rect": Rect2(cx - bw * 0.5, bfoot, bw, bh), "key": "G",
				"stamp": "GAME", "label": "Game Center", "sub": "profiles, and who to challenge",
				"note": "", "rating": 0,
				"accent": Color("#64dfdf"), "action": "gcboard"})
			bfoot += bstep
		if not portrait:
			out.append({
				"rect": Rect2(cx - 90.0, bfoot + 4.0, 180.0, 36.0), "key": "ESC",
				"label": "Back", "sub": "", "note": "", "rating": 0,
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
		# Built as a list and laid out once at the end, rather than four branches
		# each calling `_over_button_rects` with a number it worked out for
		# itself. Share had to appear on all four summaries, and the old shape
		# meant adding it in four places and getting the count right in four
		# places — which is the arrangement that puts a button on three screens
		# and forgets the fourth.
		var specs: Array = []
		if mode == Mode.DAILY:
			# The daily has no rematch. That is the entire shape of it —
			# offering a button that would refuse itself is worse than none.
			specs.append({"key": "ESC", "label": "Title",
				"sub": "a new board at midnight",
				"accent": Color("#ffd166"), "action": "title"})
		elif mode == Mode.SURVIVAL:
			# Survival is the opposite case: there is nothing to wait for and
			# nobody to ask, so the door straight back in is the one that
			# matters. It is not a Rematch — there was nobody to play — and it
			# must not route through the one that is, which would deal a CPU
			# match instead.
			specs.append({"key": "", "label": "Again", "sub": "a fresh board",
				"accent": SURVIVAL_ACCENT, "action": "survival"})
			specs.append({"key": "ESC", "label": "Title", "sub": "",
				"accent": Color("#8d99bd"), "action": "title"})
		elif not _rematch_possible():
			# The opponent has to still be there to be asked. Once they have
			# gone the button cannot do anything but fail, so the screen drops
			# to the doors that still work rather than leaving a dead one on it.
			specs.append({"key": "ESC", "label": "Title",
				"sub": "they left the match",
				"accent": Color("#8d99bd"), "action": "title"})
		else:
			specs.append({"key": "", "label": "Rematch", "sub": _rematch_sub(),
				"accent": Color("#ffd166") if rematch_asked else PLAYER_ACCENT,
				"action": "rematch", "on": rematch_offered})
			specs.append({"key": "ESC", "label": "Title",
				"sub": "pick a new opponent",
				"accent": Color("#8d99bd"), "action": "title"})

		# Last, and only where there is a sheet to open it with. A door that
		# cannot work is worse than no door — and on a desktop build, or a phone
		# whose export left the addon out, `Sharing.available()` is false and
		# this is simply not drawn.
		# No key badge, and deliberately no letter shortcut. This screen removed
		# R for Rematch because a match ends with a word half typed and the rest
		# of it lands here — and opening a share sheet by accident is the same
		# class of mistake as starting a match by accident.
		if _share_possible():
			specs.append({"key": "", "label": "Share", "sub": _share_sub(),
				"accent": Color("#64dfdf"), "action": "share"})

		var rects := _over_button_rects(specs.size())
		for i in specs.size():
			var s2: Dictionary = (specs[i] as Dictionary).duplicate()
			s2["rect"] = rects[i]
			s2["note"] = ""
			s2["rating"] = 0
			out.append(s2)

		# The daily board's two tabs. Appended rather than drawn by
		# `_draw_menu_button` — they are painted inside `_draw_daily_board`,
		# which owns the block they sit in — so this is purely so a press and a
		# hover find them. `_over_foot` minus the block's height is the same top
		# the drawing uses; see `_daily_tab_rects` for why they must be one
		# number rather than two.
		if mode == Mode.DAILY:
			var tabs := _daily_tab_rects(get_viewport_rect().size,
				_over_foot() - _daily_board_h())
			for i in tabs.size():
				out.append({
					"rect": tabs[i], "key": "", "label": "", "sub": "", "note": "",
					"rating": 0, "accent": Color("#ffd166"),
					"action": "dtab:%d" % i})
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
## The bands are real grouping rather than decoration: something somebody else
## is waiting on, one place to learn, three to play, two that are about you
## rather than about a match.
##
## WAITING is empty on almost every launch — a challenge has to have been sent
## and not yet answered — and `_draw_title_bands` only draws the bands the rows
## actually use, so an empty one costs nothing and is never seen. It exists so
## the challenge door does not have to sit under a heading that calls it a
## lesson, which is where putting it in LEARN left it.
const TITLE_BANDS := ["WAITING", "LEARN", "PLAY", "YOU"]


## What the versus door has to say for itself.
##
## The only place any of this is said now. The door opens Apple's screen
## directly, so there is no screen of ours in between to carry a status line —
## and a search can still be in flight while the player is back out here, or have
## just failed, with this plate the only thing that could mention it.
func _versus_sub() -> String:
	if not MultiplayerManager.available():
		# Not "needs an iPhone or a Mac" any more, which was true of the door
		# when the door was Apple's sheet. It now opens our own screen, and the
		# CPU match on it works on anything — so a line reading as "there is
		# nothing for you here" would be turning people away from a mode that
		# is, on this device, entirely playable.
		return "CPU matches now — online needs an iPhone"
	if _versus_busy():
		return net_status
	# "signed in" is the resting state, not news. Saying it forever would turn
	# the door's one line of copy into a status light nobody needs.
	if net_status != "" and MultiplayerManager.state != MultiplayerManager.State.READY:
		return net_status
	return "Quick match, invite a friend, or a CPU"


## What the survival door says for itself.
##
## The record, once there is one. A door that only ever says what the mode is
## stops being read after the second time you see it; a door carrying the number
## you are about to try to beat is a reason to go through it today.
func _survival_sub() -> String:
	if Profile.survival_best_time <= 0.0:
		return "No clock. Last as long as you can."
	var out := "Best %s" % _survival_clock(Profile.survival_best_time)
	if Profile.survival_best_score > 0:
		out += "  ·  %s" % _commas(Profile.survival_best_score)
	return out + "  ·  %d run%s" % [Profile.survival_runs,
		"" if Profile.survival_runs == 1 else "s"]


## The line under the BOARDS door. A waiting challenge is the strongest reason
## to go through it and gets said first; failing that, where today's daily run
## actually put you, which is the number the door is offering to explain.
## What the weekly door says for itself: how many of the four are done, and how
## long is left to do the rest.
##
## The count comes first because it is the part that changes. "3 of 4 done" is a
## reason to go in; "resets Sunday" on its own is a fact about a calendar.
func _weekly_sub() -> String:
	var key := Missions.week_key()
	var done := Profile.weekly_done_count(key)
	if done >= Missions.PER_WEEK:
		return "All %d done — new set on Sunday" % Missions.PER_WEEK
	return "%d of %d missions done  ·  %s left" % [done, Missions.PER_WEEK,
		_weekly_left_text(key)]


func _weekly_all_done() -> bool:
	return Profile.weekly_done_count(Missions.week_key()) >= Missions.PER_WEEK


## Time until Sunday, in the largest unit that still says something useful.
## Hours once it is inside a day, because "0 days" is not an answer.
func _weekly_left_text(key: String) -> String:
	var secs := Missions.seconds_left(key)
	if secs >= 86400.0:
		var days := int(secs / 86400.0)
		return "%d day%s" % [days, "" if days == 1 else "s"]
	var hours := int(secs / 3600.0)
	if hours >= 1:
		return "%d hour%s" % [hours, "" if hours == 1 else "s"]
	return "%d min" % maxi(1, int(secs / 60.0))


func _boards_door_sub() -> String:
	if Boards.pending > 0:
		return "%d challenge%s waiting" % [Boards.pending,
			"" if Boards.pending == 1 else "s"]
	if Boards.rank > 0:
		return "You are #%s on today's daily" % _commas(Boards.rank)
	return "Where today's run puts you"


func _title_modes() -> Array:
	var fresh: bool = not bool(Profile.pref("taught"))
	var dkey := daily_key()
	var spent: bool = Profile.daily_done(dkey)
	var dsub := "%d seconds, one run, the same board for everyone" % int(DAILY_SECONDS)
	if spent:
		dsub = "Played — %s. New board at midnight." % _commas(
			int(Profile.daily_result(dkey).get("score", 0)))
	# The streak belongs on the door rather than only on the summary, because the
	# summary is the one screen you have already earned it on. Here it is a
	# reason to go through — and on the day it is about to lapse, a warning.
	var dstreak: int = Profile.daily_streak(dkey)
	if dstreak > 1:
		dsub += "  ·  %d days running" % dstreak
		if not spent:
			dsub += ", don't drop it"
	# stamp, word, sub, action, tint, band
	#
	# The stamp is the fragment on the block; the word is the whole word that
	# answers it. Splitting the name across the two — PRAC in the gutter and
	# TICE on the plate — was clever and did not read: neither half was a word,
	# and "SUS" and "TINGS" are not what those buttons are called. This is the
	# game's actual loop instead. A block carries a fragment, and the word that
	# clears it starts with those letters.
	var rows: Array = []
	# Above everything, because it is the only row on this screen that somebody
	# else is waiting on — and because it is the answer to a Start button that
	# was pressed on Apple's screen and did nothing. See `_start_challenge`.
	if Boards.challenge_armed():
		rows.append(["VS", "CHALLENGE", _challenge_sub(), "challenge",
			Color("#c77dff"), 0])
	elif _running_challenge_sub() != "":
		# The modern challenge, which is the one that actually turns up. Plainer
		# copy because `GKChallengeDefinition` has no target score and no issuer
		# to put in it — see the note in `leaderboards.gd`. Same door, same band,
		# and the same action: it opens the mode the challenge is scored on.
		rows.append(["VS", "CHALLENGE", _running_challenge_sub(), "challenge",
			Color("#c77dff"), 0])
	elif challenge_sent != "":
		# The same row, holding the answer for a few seconds. Clearing the
		# challenge takes the plate off the screen, and a plate that vanishes on
		# the tap that was meant to do something is the same nothing-happened the
		# whole door exists to fix. The action goes to BOARDS rather than staying
		# inert: "where did that put me" is the only question left, and this
		# screen answers it.
		rows.append(["VS", "SENT", challenge_sent, "boards",
			Color("#90be6d") if challenge_sent_hot else Color("#ffd166"), 0])
	rows += [
		["PRAC", "PRACTICE", "Learn it, or drill it", "practice",
			Color("#90be6d"), 1],
		["DAI", "DAILY", dsub, "daily",
			Color("#5d6a92") if spent else Color("#ffd166"), 2],
		# Next to the daily because it is the same rhythm at a longer wavelength
		# — one is a board a day, this is a set of jobs a week — and somebody
		# who came here for one should see the other. Not a mode: it opens a
		# list rather than a run, which is why it is a door and not a Play.
		["WEEK", "WEEKLY", _weekly_sub(), "weekly",
			Color("#90be6d") if _weekly_all_done() else Color("#64dfdf"), 2],
		["SUR", "SURVIVAL", _survival_sub(), "survival", SURVIVAL_ACCENT, 2],
		["SOLO", "SOLO", "You against the machines", "solo", Color("#7bdff2"), 2],
		["VER", "VERSUS", _versus_sub(), "versus", Color("#c77dff"), 2],
		["MAS", "MASTERY", "Level %d · your record" % Profile.level(), "mastery",
			Color("#f8961e"), 3],
		# Next to MASTERY, and one band down from the modes, because it is the
		# same kind of door: a record rather than a thing to play. Mastery is
		# yours and this one is everybody's.
		#
		# Shown on every platform rather than only where Game Center answers.
		# The screen behind it says why it is empty — see `_boards_message` — and
		# a door that explains itself is worth more than a door that silently
		# is not there on the machine the game is developed on.
		["BOA", "BOARDS", _boards_door_sub(), "boards", Color("#5390d9"), 3],
		["COS", "COSMETICS", "Titles, themes, effects", "cosmetics",
			Color("#64dfdf"), 3],
	]
	# The one thing on this screen with a price on it, and only while there is
	# something to sell — bought, or no store, and it is not a door at all.
	#
	# Next to COSMETICS on purpose: that is the screen where the three things it
	# unlocks are already visible and already locked, so this is the answer to a
	# question the player has just been asked rather than an advert arriving out
	# of nowhere. Gold because gold is what this palette uses for the thing worth
	# having; DAILY borrows the same gold but sits two bands up and spends itself
	# grey most days.
	if Store.can_buy():
		rows.append(["PRE", "PREMIUM",
			"%s · no ad break, and three things you cannot earn" % Store.price,
			"buy", Color("#ffd166"), 3])
	rows.append(["SET", "SETTINGS", "Sound, effects, haptics", "settings",
		Color("#8d99bd"), 3])
	return rows


## Where the stack starts, and how tall each plate is. Portrait gets the taller
## plate because it is being hit with a thumb.
func _plate_metrics() -> Dictionary:
	var size := get_viewport_rect().size
	var wide: float = minf(560.0 if portrait else 620.0, size.x - GRID_MARGIN * 2.0)
	# Landscape is 720 tall and has to hold six plates, three band rules and the
	# rules line; portrait has half as much again to spend and is being hit with
	# a thumb, so it gets the taller plate.
	var h: float = 112.0 if portrait else 48.0
	var gap: float = 12.0 if portrait else 6.0
	var band_gap: float = 34.0 if portrait else 14.0
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
	if portrait and _scroll_max > 1.0:
		top = head - _scroll
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
			"badge": _plate_badge(String(row[3])),
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


## The flag in the corner of a title plate, or "" for the usual case.
##
## Worked out from the action rather than carried in the row tables, because
## those are positional arrays read by three separate loops and a seventh column
## would have to be threaded through all of them to say something only two rows
## will ever have.
##
## The two badges mean different things and clear on different events, which is
## why `Profile` answers them with two calls rather than one:
##
##   COSMETICS  "the wardrobe has things you have not seen." Answered by opening
##              the screen. Shown to owners too — they are the ones who can
##              actually wear the new faces.
##   PREMIUM    "this offer has changed." Answered by buying, and by nothing
##              else. The row only exists while there is something to sell, so
##              a player who already owns the pack never sees it.
func _plate_badge(action: String) -> String:
	if action == "cosmetics" and Profile.cosmetics_are_new():
		return "NEW"
	if action == "buy" and not Profile.owns(Profile.PACK_PREMIUM):
		return "NEW"
	return ""


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
		hot: bool, on: bool = false, locked: bool = false,
		badge: String = "") -> void:
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
	#
	# Both ranges were raised after a phone test: the old 16-26 word and a sub
	# pinned at 12 were legible on a desktop monitor at arm's length and small
	# and hard to read on the device the game is actually played on, which is the
	# only measurement that counts. The sub scales now rather than staying put,
	# because a plate that doubles in height and keeps 12px caption text looks
	# like a mistake at both ends.
	var tx: float = r.position.x + gw + 20.0
	var avail: float = r.end.x - tx - 12.0
	var size := _fitted_size(_font_bold, word,
		int(clampf(18.0 + (r.size.y - 40.0) * 0.12, 18.0, 30.0)), avail, 13)
	_draw_tracked(_font_bold, gutter.get_center(), stamp, maxi(15, size - 2), 3.0,
		ink)
	var head := word.substr(0, stamp.length()) if word.to_upper().begins_with(stamp) else ""
	var tail := word.substr(head.length())
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
		var ss := _fitted_size(_font, sub,
			int(clampf(13.0 + (r.size.y - 40.0) * 0.055, 13.0, 19.0)), avail, 11)
		_otext_left(_font, Vector2(tx, r.position.y + r.size.y * 0.72), sub, ss,
			Color("#aab4d4") if hot else Color("#7c88ad"))
	if badge != "":
		_draw_plate_badge(r, badge)


## The flag itself: a gold pill hanging off the plate's top right corner.
##
## Gold because that is what this palette already uses for the thing worth
## having, and it is the one colour on the title screen not spent on a mode —
## so a gold mark reads as "look here" without having to be big.
##
## It breathes. A static badge on a screen somebody has opened two hundred
## times is furniture, and furniture is invisible; the point of this thing is to
## be noticed exactly once. Slow enough not to be a distraction while the eye is
## somewhere else — the period is over two seconds, where the danger vignette
## beats three times as fast.
func _draw_plate_badge(r: Rect2, text: String) -> void:
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 370.0)
	var gold := Color("#ffd166")
	var pad := 7.0
	var fs := 11
	var tw: float = _font_bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
		-1, fs).x
	var pill := Rect2(r.end.x - tw - pad * 2.0 - 8.0, r.position.y - 7.0,
		tw + pad * 2.0, 18.0)
	# A soft halo under it, which is what carries the pulse — pulsing the pill
	# itself makes the word flicker and the word has to stay readable.
	for i in 3:
		var f := float(i) / 2.0
		_overlay.draw_rect(pill.grow(2.0 + f * 5.0),
			Color(gold, 0.18 * (1.0 - f) * (0.35 + 0.65 * pulse)), true)
	_panel(pill, gold, Color("#fff3d6", 0.9), 9.0, 1.0)
	_otext(_font_bold, pill.get_center(), text, fs, Color("#2a1b00"))


func _draw_title_plate(b: Dictionary) -> void:
	_draw_plate(b["rect"], String(b.get("stamp", "")), String(b["word"])
		if b.has("word") else String(b["label"]), String(b["sub"]), b["accent"],
		_hover_action == String(b["action"]), false, false,
		String(b.get("badge", "")))


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


## The largest size at or below `size` that fits `text` into `max_width`.
##
## Pulled out of `_text_fit_overlay` so the left-aligned plate text can use the
## same rule. Type on the plates is set from the plate's height — a tall row
## carries big type — and height says nothing about how long the word is, so
## without this the generous sizes would run INVITE A FRIEND off the edge of a
## landscape door.
func _fitted_size(font: Font, text: String, size: int, max_width: float,
		min_size: int = 9) -> int:
	if font == null or text == "":
		return size
	var s := size
	while s > min_size and font.get_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > max_width:
		s -= 1
	return s


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
		# Fitted rather than fixed at 15: these are the small ones — Back, the
		# category arrows — and they are the width they are, so the size has to
		# give way instead of the text running over the panel edge.
		var txt := label if label != "" else key0
		_otext(_font_bold, r.get_center(), txt,
			_fitted_size(_font_bold, txt, 18, r.size.x - 18.0, 12),
			Color.WHITE if hot else Color("#e6ecff"))
		return

	var stamp := String(b["stamp"]) if b.has("stamp") and String(b["stamp"]) != "" \
		else _stamp_for(label)
	var sub := String(b["sub"])
	# Opponent cards carry a rating rather than a sentence; keep it in the sub.
	if int(b.get("rating", 0)) > 0 and sub == "":
		sub = "%d wpm" % int(b["rating"])
	_draw_plate(r, stamp, label.to_upper(), sub, b["accent"], hot,
		bool(b.get("on", false)), bool(b.get("locked", false)),
		String(b.get("badge", "")))


func _panel(r: Rect2, bg: Color, border: Color, radius: float, width: float = 2.0) -> void:
	_panel_style(bg, border, radius, width)
	_overlay.draw_style_box(_ui_sb, r)


## The same plate, drawn in *this* node's pass instead of on `_overlay`.
##
## The rival card in the portrait header called `_panel` and so was never drawn
## at all. `_draw_portrait_hud` runs in this node's draw pass; `_panel` paints on
## `_overlay`; a `draw_*` aimed at another canvas item from outside its own pass
## is refused outright — which is the exact trap `_draw_portrait_emotes` has a
## paragraph warning about, sprung thirty lines away from the warning. The plate
## carries the accent border that says which rival you are aiming at, so losing
## it took the targeting indicator with it and left the name and lives floating
## on the background.
func _panel_here(r: Rect2, bg: Color, border: Color, radius: float,
		width: float = 2.0) -> void:
	_panel_style(bg, border, radius, width)
	draw_style_box(_ui_sb, r)


## Set the shared style box up for a plate. Split from the drawing so the two
## canvas items above cannot drift apart in how a panel looks.
func _panel_style(bg: Color, border: Color, radius: float, width: float) -> void:
	_ui_sb.bg_color = bg
	_ui_sb.set_corner_radius_all(int(radius))
	_ui_sb.set_border_width_all(int(width))
	_ui_sb.border_color = border
	_ui_sb.shadow_size = 7
	_ui_sb.shadow_color = Color(0, 0, 0, 0.35)
	_ui_sb.shadow_offset = Vector2(0, 3)


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
	if _ad_paused():
		return

	# The invite banner, before anything else, because everything else is a
	# screen and the banner is over all of them. In particular the PLAY branch
	# further down returns having done nothing but pick a target, so a banner
	# drawn over a live board would be visible, correct, and unpressable.
	#
	# Only the two buttons are taken. A press that lands anywhere else goes
	# through to the board underneath, which is the difference between an
	# interruption and a modal — see `_draw_invite_banner`.
	if _invite_banner_up() and event is InputEventMouseButton:
		var ib := event as InputEventMouseButton
		if ib.button_index == MOUSE_BUTTON_LEFT:
			var at := get_viewport().get_mouse_position()
			for b: Dictionary in _invite_banner_buttons():
				if not (b["rect"] as Rect2).has_point(at):
					continue
				# On the release, like every other button here: a menu that fired
				# on the press could not be scrolled. See `_press_action`.
				if not ib.pressed:
					_activate(String(b["action"]))
				return
	# Two thumbs. Godot turns touches into mouse presses one at a time — the
	# second finger down while the first is still held produces no event at all —
	# and a keystroke that never arrives is indistinguishable, from the typist's
	# side, from one that landed on the wrong key. So the keyboard reads the
	# touches themselves, and once any have arrived the mouse path below stands
	# down for good rather than delivering the same press twice.
	# The emote key is tested before the keyboard and swallows its touch for the
	# whole gesture.
	#
	# Its own rect stops exactly where the keyboard band starts, so the two do not
	# actually fight over any pixel the finger aims at. The forgiveness margin
	# does: `grow(8)` reaches eight pixels into the band, and `_key_at` snaps
	# anything inside the band to the nearest key — which at that corner is P. So
	# the order is what keeps the margin from costing a letter.
	if event is InputEventScreenTouch:
		var et := event as InputEventScreenTouch
		_touch_input = true
		var vp := get_viewport_rect().size
		if et.pressed and _emote_touch == -2 and _emotes_live() \
				and _kb_emote_rect(vp, _keyboard_bottom()).grow(8.0).has_point(
						et.position - Vector2(0.0, _touch_lift(vp))):
			_emote_begin(et.index)
			return
		if not et.pressed and et.index == _emote_touch:
			_emote_release()
			return
	# Sliding is only ever the emote menu. The keyboard deliberately does not
	# track it — a finger sliding across letters types nothing, which is what
	# stops a thumb resting on the glass from writing a word.
	if event is InputEventScreenDrag and _emote_touch != -2:
		var dg := event as InputEventScreenDrag
		if dg.index == _emote_touch:
			_emote_drag(dg.position)
			return

	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		_touch_input = true
		if st.pressed:
			if _keys_live():
				var key := _key_at(st.position)
				if key != "":
					_keys_down[st.index] = key
					_press_key(key)
					return
		elif _keys_down.has(st.index):
			_keys_down.erase(st.index)
			return

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

	# The tutorial's RUN IT AGAIN button, which is the one control this game
	# draws over a live playfield. Taken here because the PLAY branch below
	# returns early and never reaches the menu handling — and taken before the
	# keyboard, though in practice they cannot collide: the rect sits over the
	# board and `_key_at` refuses anything above the key band.
	#
	# Fires on the press rather than the release. It is not in a scrollable menu,
	# there is nothing to drag it out of the way of, and the press is what the
	# rest of this screen's controls answer to.
	# The phase and mode are checked as well as the rect, and not for tidiness.
	# `_draw_coaching` is the only thing that clears this, and it stops being
	# called the moment the tutorial ends — so the rect outlives the screen it
	# was drawn on, and without these two a tap in the middle of the title screen
	# would start the tutorial over.
	if mode == Mode.TUTORIAL and phase == Phase.PLAY \
			and _lesson_restart.has_area() and event is InputEventMouseButton:
		var rb := event as InputEventMouseButton
		if rb.pressed and rb.button_index == MOUSE_BUTTON_LEFT \
				and _lesson_restart.grow(8.0).has_point(
						get_viewport().get_mouse_position()):
			_restart_lesson()
			return

	# Dragging a menu. Taken before anything else a press could mean, and a press
	# only becomes a drag once it has moved far enough that it cannot have been
	# a tap — otherwise every button press would scroll a little.
	if _scrollable() and _scroll_max > 1.0:
		if event is InputEventMouseButton:
			var mbs := event as InputEventMouseButton
			match mbs.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					if mbs.pressed:
						_scroll = clampf(_scroll - 90.0, 0.0, _scroll_max)
						return
				MOUSE_BUTTON_WHEEL_DOWN:
					if mbs.pressed:
						_scroll = clampf(_scroll + 90.0, 0.0, _scroll_max)
						return
				MOUSE_BUTTON_LEFT:
					if mbs.pressed:
						_drag_from = get_viewport().get_mouse_position().y
						_drag_scroll = _scroll
						_dragging = false
					elif _dragging:
						# It was a drag, so it must not also be a tap on
						# whatever happens to be under the finger now.
						_dragging = false
						return
		elif event is InputEventMouseMotion:
			var mm := event as InputEventMouseMotion
			if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
				var moved: float = get_viewport().get_mouse_position().y - _drag_from
				if absf(moved) > 8.0:
					_dragging = true
					# The press this started from is spent. The release is going
					# to be swallowed below, but a drag that ends outside the
					# scrollable region would otherwise leave the row it began
					# on armed for whatever comes up next.
					_press_action = ""
				if _dragging:
					_scroll = clampf(_drag_scroll - moved, 0.0, _scroll_max)
					return

	# The drawn keyboard takes priority over everything else a click could mean
	# while it is up, because it covers the bottom third of the screen. Skipped
	# entirely on a touchscreen, where the block at the top of this function has
	# already dealt with the same press as a touch.
	if _keys_live() and not _touch_input:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				var hit := _key_at(get_viewport().get_mouse_position())
				if mb.pressed:
					if hit != "":
						_keys_down[-1] = hit
						_press_key(hit)
						return
				elif _keys_down.has(-1):
					_keys_down.erase(-1)
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
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		# Down remembers, up decides. See `_press_action` for why a menu whose
		# buttons fired on the press could not be scrolled at all.
		if mb.pressed:
			_press_action = _action_at(get_viewport().get_mouse_position())
			return
		var began := _press_action
		_press_action = ""
		# A release that was a drag never reaches here — the scroll handling
		# above swallows it — so the only thing left to check is that the finger
		# came up on the row it went down on.
		var act := _action_at(get_viewport().get_mouse_position())
		if act != "" and act == began:
			_activate(act)


func _action_at(p: Vector2) -> String:
	# The banner is over everything, on every screen, so it is hit-tested before
	# everything. Unlike the two cards it does *not* swallow presses that miss
	# it: it is an interruption rather than a question, and the run underneath
	# has to stay playable while it is up.
	for b: Dictionary in _invite_banner_buttons():
		if (b["rect"] as Rect2).has_point(p):
			return String(b["action"])
	# The pitch owns the screen while it is up, and swallows presses that miss
	# it — the title screen's plates are directly underneath, and a press that
	# fell through would start a match out from under a card the player was
	# still reading.
	if _promo_up():
		for b: Dictionary in _promo_buttons():
			if (b["rect"] as Rect2).has_point(p):
				return String(b["action"])
		return ""
	# The leave card comes first for the same reason the rematch card does, and
	# with more at stake: the pause menu is directly underneath it, and the
	# button it is asking about is the one a stray press would land on.
	if _confirm_up():
		for b: Dictionary in _confirm_buttons():
			if (b["rect"] as Rect2).has_point(p):
				return String(b["action"])
		return ""
	# The rematch card is a question over the top of the summary, so it takes
	# every press while it is up — including the ones that land outside it, which
	# would otherwise reach the buttons showing through behind.
	if _rematch_popup():
		for b: Dictionary in _rematch_popup_buttons():
			if (b["rect"] as Rect2).has_point(p):
				return String(b["action"])
		return ""
	for b: Dictionary in _menu_buttons():
		if (b["rect"] as Rect2).has_point(p):
			return String(b["action"])
	# The summary's emote row. Routed through `_action_at` rather than hit-tested
	# on its own so it inherits the press-then-release discipline every other
	# button on this screen has — a finger that lands on CHEER and slides off is
	# a finger that changed its mind.
	if _summary_emotes_live():
		var tiles := _summary_emote_rects(get_viewport_rect().size)
		for i in tiles.size():
			if (tiles[i] as Rect2).has_point(p):
				return "emote:%d" % int(EMOTE_MENU[i])
	if phase == Phase.SOLO:
		var seats := _solo_seat_rects()
		for i in range(1, seats.size()):
			if (seats[i] as Rect2).has_point(p):
				return "pick:%d" % (i - 1)
		for c: Dictionary in _solo_cards():
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
	# The lobby needs nothing of its own here: its doors are ordinary menu
	# buttons and were tested with the rest of them at the top.
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
		MultiplayerManager.leave_match()
		start_match(action.substr(5), 1)
	elif action == "resume":
		paused = false
		_hover_action = ""
		Sfx.play("back", 0.9)
	elif action == "leave_match":
		# The press raises a question rather than answering one — except in the
		# modes where there is nothing to ask about, which go straight through.
		# See `_leave_costs`.
		if _leave_costs():
			confirm_action = "leave_match"
			_hover_action = ""
			Sfx.play("count", 0.9)
		else:
			_do_leave_match()
	elif action == "confirm_yes":
		var what := confirm_action
		confirm_action = ""
		if what == "leave_match":
			_do_leave_match()
	elif action == "confirm_no":
		confirm_action = ""
		_hover_action = ""
		Sfx.play("back", 0.9)
	elif action == "invite_join":
		_take_invite()
	elif action == "invite_no":
		MultiplayerManager.decline_invite()
		_hover_action = ""
		Sfx.play("back", 0.9)
	elif action == "versus":
		paused = false
		_hover_action = ""
		# To our own screen rather than straight to Apple's. The sheet is still
		# behind the Invite door — see `versus_invite` — but it is no longer the
		# whole of versus, because it owned the screen for the length of a search
		# and left no room to say that a search had found nobody.
		#
		# A search already running is not restarted or interrupted; the lobby
		# opens showing it, which is the state the player is walking into.
		#
		# Rolled here rather than per frame so the CPU door names the same
		# opponent for as long as the screen is up.
		if not _versus_busy():
			_lobby_bot = AiOpponent.ROSTER.pick_random()
		phase = Phase.LOBBY
		Sfx.play("count", 1.2)
	elif action.begins_with("emote:"):
		# The wire index, not a position in the row — `_action_at` converted it
		# on the way out, so nothing downstream has to know the menu order.
		# `_send_emote` owns the cooldown and the refusal, so a press during one
		# is quietly nothing rather than a second packet.
		_send_emote(int(action.substr(6)))
	elif action == "share":
		# Not awaited. `_activate` is called from the input handler and the card
		# takes a frame to render; blocking here would hold the press open across
		# it. The scoreboard is unchanged either way, so there is nothing waiting
		# on the result.
		_do_share()
	elif action == "versus_quick":
		# The headless matchmaker, so our own status card stays in front instead
		# of Apple's sheet covering the screen for the whole search.
		if _versus_busy() or not MultiplayerManager.available():
			Sfx.play("reject", 1.2)
		else:
			net_status = ""
			_lobby_search = 0.0
			MultiplayerManager.find_match()
			Sfx.play("count", 1.2)
	elif action == "versus_invite":
		# Apple's sheet, narrowed to the one door worth having it for: Invite
		# Friends texts a link to any contact, which is the only route in the
		# whole API that reaches somebody who is not already a Game Center
		# friend. INVITE_ONLY drops the quick match and SharePlay halves, which
		# this screen now does better because it can talk while it waits.
		if _versus_busy() or not MultiplayerManager.available():
			Sfx.play("reject", 1.2)
		else:
			net_status = ""
			MultiplayerManager.open_native_matchmaker(
				MultiplayerManager.Native.INVITE_ONLY)
			Sfx.play("count", 1.2)
	elif action == "versus_cancel":
		# Stops the search and stays put. Walking back to the title as well would
		# take away the three doors at the moment the player has just said they
		# want a different one.
		#
		# `leave_match`, not `cancel_find`. The busy states this button is drawn
		# for are MATCHMAKING, CONNECTING and HANDSHAKING, and `cancel_find`
		# returns without doing anything in the last two — so a search that had
		# found somebody and stalled shaking hands, which is exactly the case
		# worth escaping, had a Stop button that did nothing at all.
		# `leave_match` forwards to `cancel_find` when it is the right call.
		MultiplayerManager.leave_match()
		_lobby_search = 0.0
		Sfx.play("back")
	elif action == "versus_cpu":
		# A real versus match against a local bot: one opponent, normal rules,
		# nothing switched off. Any search still running is dropped first, since
		# a match arriving mid-game would have nowhere to go.
		# `leave_match` rather than `cancel_find`, for the reason spelled out
		# under `versus_cancel`: it is the one that works in all three states.
		if _versus_busy():
			MultiplayerManager.leave_match()
		_lobby_search = 0.0
		start_match(_lobby_bot, 1)
	elif action == "buy":
		# The title plate and the settings row are the same purchase, so they run
		# the same call rather than each keeping its own idea of when it is
		# allowed and what to play when it is not.
		_change_setting("buy")
	elif action == "rematch":
		if net_active():
			# Ask the person who is already here. This used to walk back to the
			# versus screen and start a fresh search, which threw away the one
			# opponent you had just finished a match with and went looking for a
			# stranger — forty seconds of matchmaking to replace somebody who was
			# still connected and, having pressed Rematch themselves, waiting.
			if rematch_offered:
				# They asked first, so this press is the second yes and starts it.
				MultiplayerManager.send_event("rematch", {})
				_begin_rematch()
				Sfx.play("count", 1.3)
			elif not rematch_asked:
				rematch_asked = true
				MultiplayerManager.send_event("rematch", {})
				Sfx.play("count", 1.2)
			else:
				# Already asked and still waiting. Say so rather than sending a
				# second identical packet.
				Sfx.play("reject", 1.2)
		else:
			# Straight from the seats, so a random opponent is genuinely rolled
			# again rather than quietly becoming whoever it was last time.
			var again := _solo_lineup()
			start_match(again[0], again.size(), again)
	elif action == "solo":
		phase = Phase.SOLO
		# Portrait has no Empty card, so an empty first seat left over from a
		# desktop setup would be a screen with nothing selected and a Start button
		# that quietly ran the Duelist anyway. Name it up front instead.
		if portrait:
			solo_pick = 0
			if String(solo_seats[0]) == "":
				solo_seats[0] = "Duelist"
				Profile.set_pref("solo", solo_seats.duplicate())
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
	elif action == "survival":
		# Reachable from the title and from its own summary, which is the whole
		# of what "Again" does — there is nothing to check and nothing to spend,
		# so a run is always available.
		Link.leave()
		MultiplayerManager.leave_match()
		start_match("Survival", 0, [], Mode.SURVIVAL)
	elif action == "promo_close":
		_close_promo()
	elif action == "promo_next":
		_promo_step(1)
	elif action == "promo_prev":
		_promo_step(-1)
	elif action == "promo_buy":
		# Straight into Apple's sheet. The card stays up behind it: the purchase
		# can be cancelled, and dropping the pitch on the way to a sheet that
		# might come back "no" would leave somebody who meant to buy it with no
		# way back to the button. `Profile.changed` takes it down on success —
		# see `_apply_theme`'s neighbour in `_ready`.
		if Store.can_buy():
			Store.buy()
	elif action == "weekly":
		phase = Phase.WEEKLY
		_hover_action = ""
		Sfx.play("count", 1.1)
	elif action == "cosmetics":
		phase = Phase.COSMETICS
		_hover_action = ""
		# The badge on the door has done its job the moment the door is opened.
		# Marked here rather than in the screen's draw so that it is the act of
		# going in that answers it, not a frame of it happening to be rendered.
		Profile.note_cosmetics_seen()
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
		# Portrait only ever fills the first seat — there is no second one to move
		# on to, and advancing would leave the tapped card looking unselected.
		if portrait:
			solo_pick = 0
		solo_seats[solo_pick] = action.substr(5)
		# Filling a seat moves you on to the next empty one, so setting up three
		# opponents is three clicks rather than six.
		if not portrait and String(solo_seats[solo_pick]) != "":
			for i in solo_seats.size():
				var at := (solo_pick + 1 + i) % solo_seats.size()
				if String(solo_seats[at]) == "":
					solo_pick = at
					break
		Profile.set_pref("solo", solo_seats.duplicate())
		Sfx.play("count", 1.25)
	elif action.begins_with("set:"):
		_change_setting(action.substr(4))
	elif action == "mastery":
		phase = Phase.MASTERY
		_hover_action = ""
		Sfx.play("count", 1.1)
	elif action == "boards":
		phase = Phase.BOARDS
		_hover_action = ""
		_scroll = 0.0
		# Asked for on the way in rather than on a timer. The board is stale the
		# moment it is drawn — somebody else is playing right now — and the one
		# refresh that matters is the one that happens because you opened it.
		_open_board_view()
		Sfx.play("count", 1.1)
	elif action.begins_with("dtab:"):
		# The daily summary's own tabs. Held on the node rather than reset per
		# summary, so somebody who prefers their own history is not made to ask
		# for it again every day — see `daily_board_tab`.
		daily_board_tab = int(action.substr(5))
		Sfx.play("count", 1.1)
	elif action.begins_with("btab:"):
		var want := int(action.substr(5))
		if want != board_tab:
			board_tab = want
			_scroll = 0.0
			_open_board_view()
		_hover_action = ""
		Sfx.play("key", 1.2)
	elif action.begins_with("bscope:"):
		var scope := int(action.substr(7))
		if scope != board_scope:
			board_scope = scope
			_scroll = 0.0
			_open_board_view()
		_hover_action = ""
		Sfx.play("key", 1.2)
	elif action == "challenge":
		_start_challenge()
	elif action == "challenges":
		Boards.open_challenges()
	elif action == "gcboard":
		Boards.open_board(_board_id(), board_scope, _board_time())
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
		# Caught before the match is hung up, because leaving it is what makes
		# `net_active` false — and this is the one break that has to know it was
		# a versus match after the fact.
		var versus_over: bool = phase == Phase.OVER and net_active()
		Link.leave()
		Link.status = ""
		# Walking away from a finished match never actually hung up. The Game
		# Center match stayed open, so the opponent still saw us connected and a
		# rematch we had asked for went on standing after we had left — their
		# summary offering "they want to go again" on behalf of somebody already
		# back at the title screen. Leaving is leaving.
		if net_active():
			MultiplayerManager.leave_match()
		rematch_asked = false
		rematch_offered = false
		phase = Phase.TITLE
		_hover_action = ""
		Sfx.play("back")
		# The versus break, taken here rather than at the whistle. The rematch has
		# been answered — this is somebody done with that opponent and on their
		# way out — so there is nobody left to keep waiting. The title is already
		# behind it, the way the summary is for a solo break.
		if versus_over:
			_try_ad_break()


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
