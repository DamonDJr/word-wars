extends RefCounted
class_name Scoring
## What a word is worth.
##
## The letter values are Scrabble's, unchanged, because everybody already knows
## them: a Q is worth reaching for and an E is not, and nobody has to be taught
## that. Everything on top is this game's own, and it pays for different things
## than Scrabble does. Scrabble rewards rare letters and lucky squares. Word Wars
## rewards RHYTHM and DAMAGE — so the multipliers come from the chain you are
## holding and the blocks you just broke, which are the two things the game is
## actually about.
##
## The result is scaled at the end. Raw Scrabble scores are small — a good word
## is twenty — and a counter creeping from 9 to 34 over a minute does not feel
## like anything. Scaling changes no letter's worth relative to any other.

const LETTER := {
	"a": 1, "b": 3, "c": 3, "d": 2, "e": 1, "f": 4, "g": 2, "h": 4, "i": 1,
	"j": 8, "k": 5, "l": 1, "m": 3, "n": 1, "o": 1, "p": 3, "q": 10, "r": 1,
	"s": 1, "t": 1, "u": 1, "v": 4, "w": 4, "x": 8, "y": 4, "z": 10,
}

const SCALE := 5

## Scrabble's bingo, in spirit. Here a long word is not just harder to find, it
## is also what clears several blocks at once, so it is worth paying for twice.
const LONG_WORD_AT := 7
const LONG_WORD_BASE := 15
const LONG_WORD_STEP := 10

## A run is worth +20% a link; breaking blocks is worth +60% each. Clearing is
## deliberately the bigger of the two, because it is the harder thing to do and
## the one a player has to plan for rather than merely keep up with.
const CHAIN_STEP := 0.20
const COMBO_STEP := 0.60

## Flat, on top of the word that cashed the chain in.
const SALVO_BONUS := 200

## Winning and score used to be able to disagree — you could take the match and
## still finish second on points, which makes the scoreboard read like it is
## measuring something other than the game you just played. These are what tie
## them back together.
##
## Overfilling somebody's board is the single hardest thing to do to another
## player and paid nothing at all: the attack that ends a life scored exactly
## what the same attack scores when it lands on an empty board. It is worth more
## than a salvo because it takes everything a salvo takes and has to arrive
## against a board that is already drowning.
const TOPOUT_BONUS := 400

## And taking the match. Flat, plus what is left of your own boards — a win with
## all three lives intact is a different win from one that came down to the wire,
## and the score should be able to say which it was.
const WIN_BONUS := 900
const LIFE_BONUS := 250


static func letters(word: String) -> int:
	var n := 0
	for c in word.to_lower():
		n += int(LETTER.get(c, 0))
	return n


## `combo` is blocks cleared plus attacks shot down — everything that word broke.
## Returns the parts as well as the total, because the popup shows the working:
## seeing "34 x3.4" is what teaches the multipliers without a tutorial.
static func award(word: String, chain: int, combo: int) -> Dictionary:
	var base := letters(word)
	var bonus := 0
	if word.length() >= LONG_WORD_AT:
		bonus = LONG_WORD_BASE + (word.length() - LONG_WORD_AT) * LONG_WORD_STEP
	var mult := (1.0 + CHAIN_STEP * float(maxi(0, chain - 1))) \
		* (1.0 + COMBO_STEP * float(maxi(0, combo)))
	return {
		"base": base,
		"bonus": bonus,
		"mult": mult,
		"total": int(round(float(base + bonus) * mult * SCALE)),
	}
