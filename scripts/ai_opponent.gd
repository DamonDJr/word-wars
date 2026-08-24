extends RefCounted
class_name AiOpponent
## A CPU duelist that "types". It picks a word, then spends real time entering it
## at a human words-per-minute rate, so the player can watch an attack forming
## and race to answer it.
##
## Speed is only one axis. Two opponents can type at the same rate and still play
## nothing alike, because this game has a real strategic tension in it: a run
## without pausing lifts everything you throw, while a long word clears more of
## your own board and now hits harder on its own. A bot that fires short words
## keeps its chain climbing; one that reaches for long words sweeps its board and
## keeps letting the run lapse. Every personality below is a different answer to
## that trade.
##
## That paragraph used to end "you cannot have both", which was true until word
## length started setting a floor on block size. It does not any more: the
## long-word bots got a quiet buff out of that rule and the ceilings below came
## down to pay for it. Worth remembering the next time the scoring moves — these
## numbers are balanced against it, not independent of it.
##
## ## Pace is not the same on a phone
##
## Every rate here was tuned against a keyboard. The game ships to thumbs, where
## finding a word and entering it is far slower — so a Duelist that was a fair
## fight on a desktop is a losing one on a phone, and Wordsmith is not a fight at
## all. The rates are scaled at `configure` rather than rewritten, so the ladder
## keeps its shape and a desktop build stays honest about what it is.

## The dials, and what each one actually changes:
##
##   wpm/reaction/typo/ramp
##          pace. How fast it types, how long it thinks, how often it fumbles,
##          and how much it speeds up over a long match.
##   len    the word lengths it reaches for. This is the strategy axis: `reach`
##          is length/2, so a long-word bot clears more per answer.
##   vocab  how far into the 36k frequency list it may look. A hard stamp like
##          DING only has answers deep in the list, so a shallow bot cannot find
##          one and has to eat the block.
##   focus  chance it looks for a defensive word at all, and that it goes after
##          the most dangerous block rather than whichever one it noticed.
##   combo  chance it hunts for the word that clears SEVERAL blocks at once,
##          rather than taking the first answer that comes to mind.
##   rhythm how much it protects a run in progress. High rhythm deliberately
##          picks a word it can finish before the chain window closes, and
##          almost never swings for a haymaker.
##   grudge how long it stays pointed at one rival in a four-way.
## What a bot keeps of its desktop pace when the player is using a touch
## keyboard, and how much longer it stops to think. Measured against thumbs
## rather than guessed at a round number: a good phone typist runs about seven
## tenths of their own keyboard speed, and the word-finding on top of that is
## slower again.
const TOUCH_PACE := 0.7
const TOUCH_THINK := 1.25

const DIFFICULTIES := {
	"Rookie": {
		"wpm": 26.0, "reaction": 1.5, "typo": 0.22, "ramp": 0.35,
		"len": Vector2i(3, 7), "vocab": 2500, "focus": 0.45, "combo": 0.10,
		"rhythm": 0.30, "grudge": 0.2,
		"tint": "#64dfdf", "rating": 1,
		"blurb": "learning the ropes", "style": "no plan yet",
	},
	# Rookie's hands, nothing like Rookie's head. Every word is a mouthful, so it
	# is slow to land anything — but each one sweeps its own board clean.
	"Magpie": {
		"wpm": 26.0, "reaction": 1.3, "typo": 0.20, "ramp": 0.35,
		"len": Vector2i(7, 11), "vocab": 9000, "focus": 0.70, "combo": 0.45,
		"rhythm": 0.05, "grudge": 0.5,
		"tint": "#90be6d", "rating": 1,
		"blurb": "slow hands, long words", "style": "hoards letters, clears in sweeps",
	},
	# Never lets the run lapse. Short words, no hesitation, and the tier ladder
	# does the damage instead of the vocabulary.
	"Metronome": {
		"wpm": 34.0, "reaction": 0.45, "typo": 0.12, "ramp": 0.5,
		"len": Vector2i(3, 6), "vocab": 4000, "focus": 0.45, "combo": 0.20,
		"rhythm": 0.95, "grudge": 0.8,
		"tint": "#f9c74f", "rating": 2,
		"blurb": "never breaks its chain", "style": "short words, relentless tempo",
	},
	"Duelist": {
		"wpm": 40.0, "reaction": 0.9, "typo": 0.14, "ramp": 0.6,
		"len": Vector2i(4, 9), "vocab": 6000, "focus": 0.65, "combo": 0.35,
		"rhythm": 0.50, "grudge": 0.4,
		"tint": "#f8961e", "rating": 2,
		"blurb": "a fair fight", "style": "no weakness, no specialty",
	},
	# Answers nearly everything and sends almost nothing. Beating it means
	# out-lasting it, because you will not out-defend it.
	"Bulwark": {
		"wpm": 38.0, "reaction": 0.8, "typo": 0.10, "ramp": 0.5,
		"len": Vector2i(4, 10), "vocab": 20000, "focus": 0.97, "combo": 0.85,
		"rhythm": 0.20, "grudge": 0.9,
		"tint": "#4cc9f0", "rating": 3,
		"blurb": "answers everything", "style": "all defence, soft punches",
	},
	# Refuses to defend. It will drown eventually — the question is whether it
	# buries you first.
	"Berserker": {
		"wpm": 52.0, "reaction": 0.35, "typo": 0.18, "ramp": 0.8,
		"len": Vector2i(3, 7), "vocab": 5000, "focus": 0.12, "combo": 0.15,
		"rhythm": 0.90, "grudge": 1.0,
		"tint": "#f94144", "rating": 3,
		"blurb": "never blocks, only swings", "style": "all offence, drowns itself",
	},
	"Wordsmith": {
		"wpm": 58.0, "reaction": 0.5, "typo": 0.07, "ramp": 0.9,
		"len": Vector2i(5, 10), "vocab": 25000, "focus": 0.9, "combo": 0.8,
		"rhythm": 0.65, "grudge": 0.6,
		"tint": "#c77dff", "rating": 3,
		"blurb": "brutal", "style": "does everything, and quickly",
	},
}

## Display order for the picker — read as a difficulty ramp, not alphabetical.
const ROSTER := ["Rookie", "Magpie", "Metronome", "Duelist", "Bulwark",
	"Berserker", "Wordsmith"]

var difficulty := "Duelist"
var wpm := 40.0
var reaction := 0.9
var typo_chance := 0.14
var ramp := 0.6
var len_range := Vector2i(4, 9)
var vocab := 6000
var focus := 0.65
var combo_sense := 0.35
var rhythm := 0.5
var grudge := 0.4

var word := ""
var chars_done := 0.0
## Set on the frame a fumble happens; the caller clears it after reacting.
var fumbled := false
var _wait := 0.0
var _elapsed := 0.0


## Names come back from the network as display labels, which are upper-cased, and
## from the menu as roster keys. Match either without caring how it was cased —
## anything unrecognised (a networked lobby's "Versus", say) lands on Duelist.
static func resolve(name: String) -> String:
	if DIFFICULTIES.has(name):
		return name
	for key: String in DIFFICULTIES:
		if key.to_lower() == name.to_lower():
			return key
	return "Duelist"


static func spec(name: String) -> Dictionary:
	return DIFFICULTIES[resolve(name)]


## The rate a bot will actually type at, for a screen that wants to advertise it.
##
## The roster shows a wpm next to every name and it has to be the truth: a phone
## quoting a bot's desktop pace is promising a fight it is not going to have.
static func paced_wpm(name: String, touch: bool) -> int:
	return int(round(float(spec(name)["wpm"]) * (TOUCH_PACE if touch else 1.0)))


## `touch` is the player's input, not the bot's — a CPU has no hands. It scales
## the pace to what the person opposite can actually manage, which is the only
## thing "difficulty" has ever meant here.
func configure(name: String, touch: bool = false) -> void:
	difficulty = resolve(name)
	var d: Dictionary = spec(name)
	wpm = float(d["wpm"]) * (TOUCH_PACE if touch else 1.0)
	reaction = float(d["reaction"]) * (TOUCH_THINK if touch else 1.0)
	typo_chance = d["typo"]
	ramp = d["ramp"]
	len_range = d["len"]
	vocab = d["vocab"]
	focus = d["focus"]
	combo_sense = d["combo"]
	rhythm = d["rhythm"]
	grudge = d["grudge"]
	reset()


func reset() -> void:
	word = ""
	chars_done = 0.0
	fumbled = false
	_wait = reaction
	_elapsed = 0.0


## How long this one sits on a single rival before wandering its aim, in seconds.
## A four-way where everybody re-aims at the same rate is three identical guns.
func attention_span() -> float:
	return randf_range(4.0, 9.0) + grudge * 14.0


## What the player sees the AI has entered so far.
func visible_text() -> String:
	if word == "":
		return ""
	return word.substr(0, int(chars_done))


func progress() -> float:
	if word == "":
		return 0.0
	return clampf(chars_done / float(word.length()), 0.0, 1.0)


## Advance one frame. Returns a finished word, or "" if still working.
##
## `chain_left` is how long it has to fire again before its run lapses, and
## `peril` is how full its own board is — 0 calm, 1 about to top out. Both are
## what let a personality be a tendency rather than a script.
func update(delta: float, board_prefixes: Array, used: Dictionary,
		chain_left: float = 0.0, peril: float = 0.0) -> String:
	_elapsed += delta

	if word == "":
		_wait -= delta
		if _wait <= 0.0:
			word = _choose(board_prefixes, used, chain_left, peril)
			chars_done = 0.0
			if word == "":
				_wait = 1.0
		return ""

	chars_done += _chars_per_second() * delta
	if chars_done >= word.length():
		var done := word
		word = ""
		chars_done = 0.0
		# A bot that cares about its rhythm does not dawdle between words.
		_wait = reaction * randf_range(0.6, 1.4) * lerpf(1.0, 0.45, rhythm)
		# Occasional fumble: the AI "mistypes" and has to start over. This is its
		# version of the player firing a word that does not qualify, so it costs
		# the CPU its chain the same way.
		if randf() < typo_chance:
			_wait += done.length() * 0.09
			fumbled = true
			return ""
		return done
	return ""


func _chars_per_second() -> float:
	# Warms up over the match so long games keep escalating.
	var boosted: float = wpm + ramp * minf(_elapsed, 180.0) * 0.12
	return boosted * 5.0 / 60.0


func _choose(board_prefixes: Array, used: Dictionary, chain_left: float,
		peril: float) -> String:
	# Nobody stays a purist with the stack at the ceiling. Without this the
	# aggressive personalities would simply drown themselves in the first minute
	# and never be worth playing twice.
	var will_defend: float = clampf(focus + peril * peril * 0.75, 0.0, 1.0)
	if not board_prefixes.is_empty() and randf() < will_defend:
		var answer := _best_clearing_word(board_prefixes, used)
		if answer != "":
			return answer

	var lo := len_range.x
	var hi := len_range.y
	if chain_left > 0.0 and randf() < rhythm:
		# A run in progress is worth protecting. Tier comes from rhythm and not
		# from word length, so the rhythm players deliberately reach for
		# something they can finish before the window shuts.
		hi = clampi(int(chain_left * _chars_per_second() * 0.8), lo, hi)
	elif randf() < 0.3 - rhythm * 0.25:
		# The occasional haymaker, and rarer the more this one values tempo.
		hi = mini(hi + 3, 14)
	return WordBank.pick_any(lo, hi, used, 1.7, vocab)


## Find something to clear. How hard it looks is what separates the difficulties;
## how LONG what it finds is separates the personalities, because reach is half
## the word's length — a long answer sweeps several blocks at once.
func _best_clearing_word(board_prefixes: Array, used: Dictionary) -> String:
	var ordered := board_prefixes.duplicate()
	ordered.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	# Only a sharp opponent reliably goes after the worst block first; a sloppy
	# one answers whichever one caught its eye.
	if randf() > focus:
		ordered.shuffle()

	for p: String in ordered:
		# Ask for words this personality would actually reach for first, and only
		# settle for anything at all if that came back empty. Without the second
		# pass a long-word bot would sit there eating blocks it could have
		# answered, which reads as broken rather than as characterful.
		var cands := WordBank.candidates(p, maxi(len_range.x, p.length() + 1),
			len_range.y + 2, used, 80, vocab)
		if cands.is_empty():
			cands = WordBank.candidates(p, maxi(3, p.length() + 1), len_range.y + 2,
				used, 80, vocab)
		if cands.is_empty():
			continue

		if randf() >= combo_sense:
			# Takes the first answer that comes to mind, combo or not.
			var i := int(pow(randf(), 1.6) * cands.size())
			return cands[mini(i, cands.size() - 1)]

		var best := ""
		var best_score := -1
		for c: String in cands:
			var hits := 0
			for q: String in ordered:
				if c.begins_with(q):
					hits += 1
			# A short word cannot cash in every match it finds, so score what it
			# would actually clear rather than what it merely opens.
			hits = mini(hits, WWBoard.reach(c))
			var score := hits * 100 + mini(c.length(), 12)
			if score > best_score:
				best_score = score
				best = c
		if best != "":
			return best
	return ""
