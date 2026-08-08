extends RefCounted
class_name AiOpponent
## A CPU duelist that "types". It picks a word, then spends real time entering it
## at a human words-per-minute rate, so the player can watch an attack forming
## and race to answer it.

## Three separate dials govern how good the CPU is at defense, because "too good"
## turned out to be three different things:
##
##   vocab  - how far into the 36k frequency list it may look. A hard stamp like
##            DING only has answers deep in the list, so a shallow CPU cannot
##            find one and has to eat the block.
##   focus  - chance it looks for a defensive word at all, and that it goes after
##            the most dangerous block rather than whichever one it happened to
##            notice. Without this it never misses an answer that exists.
##   combo  - chance it searches for the word that clears SEVERAL blocks at once.
##            This was the real damage: a perfect multi-clear counterattack every
##            time. Below it, the CPU takes the first answer that comes to mind.
const DIFFICULTIES := {
	"Rookie": {"wpm": 26.0, "reaction": 1.5, "typo": 0.22, "ramp": 0.35,
		"len": Vector2i(3, 7), "vocab": 2500, "focus": 0.45, "combo": 0.10},
	"Duelist": {"wpm": 40.0, "reaction": 0.9, "typo": 0.14, "ramp": 0.6,
		"len": Vector2i(4, 9), "vocab": 6000, "focus": 0.65, "combo": 0.35},
	"Wordsmith": {"wpm": 58.0, "reaction": 0.5, "typo": 0.07, "ramp": 0.9,
		"len": Vector2i(5, 12), "vocab": 25000, "focus": 0.9, "combo": 0.8},
}

var difficulty := "Duelist"
var wpm := 40.0
var reaction := 0.9
var typo_chance := 0.14
var ramp := 0.6
var len_range := Vector2i(4, 9)
var vocab := 6000
var focus := 0.65
var combo_sense := 0.35

var word := ""
var chars_done := 0.0
## Set on the frame a fumble happens; the caller clears it after reacting.
var fumbled := false
var _wait := 0.0
var _elapsed := 0.0


func configure(name: String) -> void:
	difficulty = name
	var d: Dictionary = DIFFICULTIES.get(name, DIFFICULTIES["Duelist"])
	wpm = d["wpm"]
	reaction = d["reaction"]
	typo_chance = d["typo"]
	ramp = d["ramp"]
	len_range = d["len"]
	vocab = d["vocab"]
	focus = d["focus"]
	combo_sense = d["combo"]
	reset()


func reset() -> void:
	word = ""
	chars_done = 0.0
	fumbled = false
	_wait = reaction
	_elapsed = 0.0


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
func update(delta: float, board_prefixes: Array, used: Dictionary) -> String:
	_elapsed += delta

	if word == "":
		_wait -= delta
		if _wait <= 0.0:
			word = _choose(board_prefixes, used)
			chars_done = 0.0
			if word == "":
				_wait = 1.0
		return ""

	chars_done += _chars_per_second() * delta
	if chars_done >= word.length():
		var done := word
		word = ""
		chars_done = 0.0
		_wait = reaction * randf_range(0.6, 1.4)
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


func _choose(board_prefixes: Array, used: Dictionary) -> String:
	# Sometimes it just does not spot the answer and swings instead.
	if not board_prefixes.is_empty() and randf() < focus:
		var answer := _best_clearing_word(board_prefixes, used)
		if answer != "":
			return answer
	var lo := len_range.x
	var hi := len_range.y
	if randf() < 0.3:
		hi = mini(hi + 3, 14)  # occasional haymaker
	return WordBank.pick_any(lo, hi, used, 1.7, vocab)


## Find something to clear. How hard it looks is what separates the difficulties.
func _best_clearing_word(board_prefixes: Array, used: Dictionary) -> String:
	var ordered := board_prefixes.duplicate()
	ordered.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	# Only a sharp opponent reliably goes after the worst block first; a sloppy
	# one answers whichever one caught its eye.
	if randf() > focus:
		ordered.shuffle()

	for p: String in ordered:
		var cands := WordBank.candidates(p, maxi(3, p.length() + 1), len_range.y + 2, used,
			80, vocab)
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
