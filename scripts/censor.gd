extends RefCounted
class_name Censor
## Masks profanity anywhere the game echoes a word back at you.
##
## Two rules keep this from becoming a nuisance:
##
## **It never changes what a word does.** A rude word is still a real word, so it
## still clears blocks, still scores and still counts toward your record. Only
## the display is masked. A filter that silently made some words stop working
## would be a bug report about the dictionary, not a filter.
##
## **It matches whole words only.** Substring matching is how you end up refusing
## to print `classic`, `assassin`, `shuttlecock` and `Scunthorpe` — and in a game
## whose entire subject is the letters inside words, that failure mode would fire
## constantly. Inflections are handled by expanding the list at load time rather
## than by stemming at match time, so what is caught is always something somebody
## wrote down on purpose.
##
## Stamps are handled elsewhere and differently: `WordBank` refuses to *mint* a
## rude fragment at all, filter or no filter. Masking a stamp would be worse than
## showing it, because the stamp is the thing you have to type — you cannot
## answer what you cannot read.

## Stems. Inflections are generated from these, so `SUFFIXES` below does the work
## that would otherwise mean listing every form by hand.
##
## Masked on screen, and *playable* — a rude word is still a real word, so it
## still clears blocks and still scores. Slurs are handled separately below and
## are not playable at all.
const STEMS := [
	"anus", "arse", "arsehole", "ass", "asshat", "asshole", "ballsack", "bastard",
	"bellend", "bitch", "bollock", "boner", "bugger", "bullshit", "cock",
	"cocksucker", "cracker", "cum", "cunt", "damn", "dick", "dickhead",
	"dildo", "douche", "douchebag", "dyke", "fanny", "fuck",
	"fucker", "fuckwit", "gash", "goddamn", "hell", "hoe", "jackass", "jerkoff",
	"jism", "jizz", "knob", "knobhead", "minge", "motherfucker", "muff",
	"nonce", "pillock", "piss", "prick", "pussy", "queer",
	"retard", "rimjob", "scrote", "shag", "shit", "shite", "shithead", "skank",
	"slag", "slut", "spastic", "spunk", "tit", "titty", "tosser", "turd",
	"twat", "wank", "wanker", "whore",
]

## Endings that make an inflection rather than a different word. Anchored to the
## end of a stem, so `ass` + `es` is caught while `ass` + `ess` (assess) and
## `ass` + `ign` (assign) are not.
const SUFFIXES := ["", "s", "es", "ed", "ing", "er", "ers", "y", "ies", "in", "a"]

## What a masked word is replaced with, one per letter. Length is kept — this is
## a word game, and "it was a seven-letter word" is information the player is
## entitled to without being shown which one.
const MASK := "*"


## Slurs, which are a different thing from profanity and are treated differently.
##
## These are stripped from the dictionary at load, so they cannot be typed for
## points, cannot be minted onto a block, and are not words this game knows. The
## `STEMS` list above is masked on screen and still playable, because a rude word
## is a real word and refusing to score one would be a bug report about the
## dictionary. Paying somebody points for a slur is not the same trade.
##
## Written out in full, every form, with no suffix expansion — unlike `STEMS`.
## Running `SUFFIXES` over these is how `spic` deletes `spicy` and `spices`, and
## a word game that has quietly lost two ordinary words is worse than one that
## never refused anything. Eighteen entries typed out is cheap; a rule that can
## surprise you is not.
##
## Only terms with no ordinary meaning left to lose are here. `cracker`, `queer`,
## `retard`, `spastic` and `dyke` all have everyday senses — a biscuit, strange,
## to slow down, a muscle spasm, an embankment — so they stay in `STEMS`:
## maskable, playable, and no worse than the rest of that list.
const SLURS := [
	"coon", "coons",
	"fag", "fags",
	"faggot", "faggots",
	"kike", "kikes",
	"nigger", "niggers",
	"paki", "pakis",
	"spic", "spics",
	"wog", "wogs",
	"wop", "wops",
]

static var _slurs: Dictionary = {}


static func _build_slurs() -> void:
	if not _slurs.is_empty():
		return
	for word: String in SLURS:
		_slurs[word] = true


## Is this word one the game refuses to know? Asked by `WordBank` once per
## dictionary entry at load, so it is a hash lookup and not a scan.
static func is_slur(word: String) -> bool:
	_build_slurs()
	return _slurs.has(word.to_lower())


static var _blocked: Dictionary = {}


static func _build() -> void:
	if not _blocked.is_empty():
		return
	for stem: String in STEMS:
		for suffix: String in SUFFIXES:
			_blocked[stem + suffix] = true


## Is this single token one of them? Punctuation and case are ignored; anything
## that is not a letter is stripped before the comparison, which is what stops
## `f.u.c.k` and `FUCK!` walking straight past.
static func is_profane(token: String) -> bool:
	_build()
	var bare := ""
	for c in token.to_lower():
		if c >= "a" and c <= "z":
			bare += c
	return bare != "" and _blocked.has(bare)


## Safe to print. Whole words are masked; everything between them — spaces,
## punctuation, the rest of a log line — is left exactly as it was, so this can
## be run over a whole sentence rather than only over a bare word.
static func clean(text: String) -> String:
	if text == "":
		return text
	_build()
	var out := ""
	var word := ""
	for i in text.length():
		var c := text[i]
		var letter: bool = (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") \
			or c == "'" or c == "-"
		if letter:
			word += c
		else:
			out += _mask(word) + c
			word = ""
	return out + _mask(word)


## A name is one token however somebody punctuated it, so `S.H.I.T` and `s h i t`
## are the same claim as `shit`. Log lines cannot be treated this way — collapsing
## a sentence across its punctuation would join words that were never one word —
## which is why this is separate from `clean` rather than folded into it.
##
## Names are the only free text in the game: everything else the player can put
## on screen has to be a dictionary word, and the input only accepts a to z.
static func clean_name(text: String) -> String:
	if is_profane(text):
		return MASK.repeat(clampi(text.strip_edges().length(), 1, 14))
	return clean(text)


static func _mask(word: String) -> String:
	if word == "" or not is_profane(word):
		return word
	return MASK.repeat(word.length())
