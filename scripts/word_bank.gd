extends Node
## Autoload. Owns the two word lists and every lookup the game needs.
##
## words.txt  - large validity set, decides whether typed input counts as a word.
##              Stored sorted so prefix ranges come out of a binary search.
## common.txt - frequency-ordered subset. Drives the AI's vocabulary, and is the
##              second half of the test for whether a stamp is fair: a stamp
##              needs enough answers a person would actually think of, not just
##              enough answers that exist.

## The draws that decide what a board looks like.
##
## Kept apart from the engine's global generator on purpose. Cosmetic randomness
## — sparks, grain, decor — draws from the global one every frame, at a rate
## that depends on framerate and on what is on screen, so anything sharing it
## can never be reproduced. The daily board needs the same letters for everyone
## who plays it, so the letters come from here and here alone, and `seed_run`
## makes a day repeatable.
var rng := RandomNumberGenerator.new()


## Fix the run to a seed, so two machines deal the same board.
func seed_run(value: int) -> void:
	rng.seed = value


## Back to unpredictable, for everything that is not the daily.
func free_run() -> void:
	rng.randomize()



const VALID_PATH := "res://data/words.txt"
const COMMON_PATH := "res://data/common.txt"
const MAX_INDEXED_PREFIX := 4

## Sorts above every lowercase letter, so `p + HI` bounds the prefix range.
const HI := "~"

var _valid: PackedStringArray = PackedStringArray()
var _common: PackedStringArray = PackedStringArray()
var _prefix_index: Dictionary = {}

var ready_to_play := false


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	_load_valid()
	_load_common()
	ready_to_play = true
	print("WordBank: %d valid / %d common words in %d ms" % [
		_valid.size(), _common.size(), Time.get_ticks_msec() - t0])


func _load_valid() -> void:
	var f := FileAccess.open(VALID_PATH, FileAccess.READ)
	if f == null:
		push_error("WordBank: cannot open %s" % VALID_PATH)
		return
	var text := f.get_as_text()
	f.close()
	if text.contains("\r"):
		text = text.replace("\r", "")
	_valid = text.split("\n", false)
	# The build script writes it sorted and bsearch depends on that, so verify in
	# one pass and only pay for a sort if someone hand-edited the file.
	for i in range(1, _valid.size()):
		if _valid[i] < _valid[i - 1]:
			push_warning("WordBank: %s was not sorted; sorting at load" % VALID_PATH)
			_valid.sort()
			break


func _load_common() -> void:
	var f := FileAccess.open(COMMON_PATH, FileAccess.READ)
	if f == null:
		push_error("WordBank: cannot open %s" % COMMON_PATH)
		return
	var text := f.get_as_text()
	f.close()
	_common = text.split("\n", false)
	for i in _common.size():
		var w: String = _common[i]
		var upto: int = mini(MAX_INDEXED_PREFIX, w.length())
		for n in range(1, upto + 1):
			var p := w.substr(0, n)
			if not _prefix_index.has(p):
				_prefix_index[p] = []
			_prefix_index[p].append(i)


func is_valid(word: String) -> bool:
	var w := word.to_lower()
	var i := _valid.bsearch(w, true)
	return i < _valid.size() and _valid[i] == w


## How many words in the full dictionary start with `p`. The sorted list makes
## this a pair of binary searches rather than a scan.
func valid_prefix_count(p: String) -> int:
	if p == "":
		return 0
	return _valid.bsearch(p + HI, true) - _valid.bsearch(p, true)


## How many common words start with `p`. Used to keep inflicted prefixes fair.
func prefix_count(p: String) -> int:
	if p.length() <= MAX_INDEXED_PREFIX:
		return (_prefix_index.get(p, []) as Array).size()
	var seed_list: Array = _prefix_index.get(p.substr(0, MAX_INDEXED_PREFIX), [])
	var n := 0
	for i: int in seed_list:
		if _common[i].begins_with(p):
			n += 1
	return n


## Cut a stamp off the END of `word` — the tail of the attacker's word becomes
## the head of the word the defender has to find. FRIENDSHIP bites with SHIP, but
## not every time: taking the longest answerable tail on every single attack is
## what turned every board into a wall of ING and LY. Longer stamps stay
## favoured, they just no longer win automatically.
##
## `avoid` holds stamps the defender is already dealing with plus the last few
## thrown by either side; those are heavily discounted, and if they are all this
## word can offer, the search widens to look for something fresher.
func stamp_from_tail(word: String, desired_len: int, min_valid: int, min_common: int,
		avoid: Dictionary = {}) -> String:
	var w := word.to_lower()
	var want: int = mini(desired_len, w.length())

	# True suffixes, plus single letters held back as a last-ditch pool.
	var pool: Array = []
	var weak: Array = []
	for n in range(want, 0, -1):
		var s := w.substr(w.length() - n)
		if not is_answerable(s, min_valid, min_common):
			continue
		if n >= 2:
			pool.append({"s": s, "n": n, "tail": true})
		else:
			weak.append({"s": s, "n": n, "tail": true})

	# Always gather a few windows just off the end too. RUNNING's tail offers
	# nothing but ING — a pool of one, which no amount of weighting can vary —
	# so the near-tail letters are what stop every board reading the same. This
	# is also what rescues SHIPMENTS (bare S) and FIX (unanswerable X).
	# Never start at the front: MUSIC must not brand a block MUS. Short words are
	# exempt because a three-letter word has no meaningful middle.
	var min_start: int = 0 if w.length() <= 4 else 1
	for shift in range(1, mini(3, w.length())):
		for n in range(mini(want, w.length() - shift), 1, -1):
			var start := w.length() - shift - n
			if start < min_start:
				continue
			var s := w.substr(start, n)
			# A shifted stamp is harsher than a true suffix, so it has to be
			# comfortably answerable rather than merely legal.
			if is_answerable(s, min_valid, min_common * 2):
				pool.append({"s": s, "n": n, "tail": false})

	pool.append_array(weak)
	if pool.is_empty():
		pool = weak
	if pool.is_empty():
		return _easiest_letter(w)
	return _weighted_stamp(pool, avoid)


## Longer is better, quadratically, but never certain — that spread is what keeps
## the same three suffixes off every block.
func _weighted_stamp(pool: Array, avoid: Dictionary) -> String:
	var weights: Array = []
	var total := 0.0
	for c: Dictionary in pool:
		var n: int = c["n"]
		var wgt := float(n * n)
		if not c["tail"]:
			wgt *= 0.6
		if n == 1:
			wgt *= 0.5  # the merciful one-letter stamp stays a rarity
		if avoid.has(c["s"]):
			wgt *= 0.15
		weights.append(wgt)
		total += wgt
	if total <= 0.0:
		return pool[0]["s"]

	var roll := rng.randf() * total
	for i in pool.size():
		roll -= weights[i]
		if roll <= 0.0:
			return pool[i]["s"]
	return pool[pool.size() - 1]["s"]


## Last resort when nothing else was answerable. Single letters cannot be rude,
## so there is nothing to filter here — but the caller may have handed us a word
## whose every fragment was refused, and one letter is always something.
func _easiest_letter(w: String) -> String:
	var best := w.right(1)
	for i in w.length():
		if prefix_count(w[i]) > prefix_count(best):
			best = w[i]
	return best


## Dropping to a single letter is the merciful end of the search, so that letter
## has to be genuinely easy to open a word with. Only X fails this in practice —
## without it, FIX would brand a block X and nobody could answer it.
const SINGLE_LETTER_MIN_COMMON := 30


## A stamp is fair only if enough words exist to answer it AND enough of those
## are words a person would actually reach for.
##
## A rude fragment is never fair, and that holds whether or not the player has
## the profanity filter on. Masking a stamp would be worse than showing it: the
## stamp is the thing you have to type, and you cannot answer what you cannot
## read. So it is refused at the source and the search moves on to the next
## candidate, which it was going to do anyway for a dozen other reasons.
func is_answerable(stamp: String, min_valid: int, min_common: int) -> bool:
	if Censor.is_profane(stamp):
		return false
	if valid_prefix_count(stamp) < min_valid:
		return false
	var floor_common := min_common
	if stamp.length() == 1:
		floor_common = maxi(min_common, SINGLE_LETTER_MIN_COMMON)
	return prefix_count(stamp) >= floor_common


## Up to `limit` common words starting with `p`, frequency-biased toward the
## front of the list so the AI reaches for words a person would actually know.
##
## `max_rank` is how deep into the frequency list the caller is allowed to see.
## The index lists are built in ascending frequency order, so this is a clean cut:
## it is the difference between a CPU that answers every stamp and one that only
## knows the words its skill level should know.
func candidates(p: String, min_len: int, max_len: int, exclude: Dictionary, limit: int,
		max_rank: int = 0) -> Array:
	var pool: Array = _prefix_index.get(p.substr(0, mini(p.length(), MAX_INDEXED_PREFIX)), [])
	var out: Array = []
	for i: int in pool:
		if max_rank > 0 and i >= max_rank:
			break
		var w: String = _common[i]
		if w.length() < min_len or w.length() > max_len:
			continue
		if not w.begins_with(p):
			continue
		if exclude.has(w):
			continue
		out.append(w)
		if out.size() >= limit:
			break
	return out


## A common word of the requested length, ignoring anything already spent.
func pick_any(min_len: int, max_len: int, exclude: Dictionary, bias: float = 1.7,
		max_rank: int = 0) -> String:
	var n := _common.size()
	if max_rank > 0:
		n = mini(n, max_rank)
	if n == 0:
		return ""
	for _attempt in 200:
		var i := int(pow(rng.randf(), bias) * n)
		var w: String = _common[mini(i, n - 1)]
		if w.length() >= min_len and w.length() <= max_len and not exclude.has(w):
			return w
	# Fall back to a linear sweep rather than returning nothing.
	for i in n:
		var w: String = _common[i]
		if w.length() >= min_len and w.length() <= max_len and not exclude.has(w):
			return w
	return ""


## A random common word, used to seed ambient garbage prefixes.
func random_common(bias: float = 1.4) -> String:
	var n := _common.size()
	if n == 0:
		return "s"
	return _common[mini(int(pow(rng.randf(), bias) * n), n - 1)]
