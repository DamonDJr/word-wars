extends RefCounted
class_name Tutorial
## The lesson, as data.
##
## Word Wars has one rule that has to land before anything else makes sense —
## *your endings become their beginnings* — and it is a rule that reads as
## nonsense written down and as obvious the first time it happens to you. So the
## tutorial does not explain it. It sets up the exact situation, says the one
## sentence that names what is about to happen, and then waits.
##
## Nothing here advances on a timer. Every step ends because the player did the
## thing, which means nobody can be carried past a rule they have not got yet.
## It costs a first-time player nothing to be slow.
##
## Steps are data rather than closures so the whole lesson can be read in one
## screenful and reordered without touching the machinery. `game.gd` matches on
## `id` to set each one up and to decide when it is done.
##
## Two of them named SPACE, which is not a key a phone has — and the phone is
## what the game ships to. Where the control matters to the instruction, the step
## carries a `_touch` variant and `step()` picks. Substituting "SPACE" for "FIRE"
## in the string would have been shorter and would have read as a translation
## rather than as a sentence; "tap FIRE to send it" is not the same sentence as
## "press SPACE to fire it" and should not pretend to be.
##
## Bodies are written as sentences with no line breaks in them. They used to
## carry their own `\n`, broken by hand at the width the landscape card happened
## to be — which on a phone, where the card is wider and the type is now half
## again bigger, put the break in the middle of a clause. `game.gd` wraps them to
## whatever the card actually is, so the copy can be judged as copy.
##
## Every one of them was also cut. A first-time player reads this card while a
## board they do not understand is sitting under it, and a second clause
## qualifying the first is a clause they will not get to: the sentences here say
## the rule and stop. What was cut was never the rule — it was the aside about
## the rule, which is what the game itself is about to demonstrate anyway.

## Five steps, down from seven, and the two that went were the two a first-time
## player was most likely to stop on.
##
## LONGER WORDS REACH FURTHER asked for a six-letter word to clear three blocks,
## which is a vocabulary test. KEEP FIRING asked for a chain of three inside the
## window each word buys, which is a typing-speed test. Both are real rules and
## neither is a rule you need in order to start playing — they are things the
## game teaches by being played, and putting them in front of somebody who has
## typed four words in their life is how a tutorial becomes the thing between a
## player and the game rather than the way in.
##
## What is left is the shortest path to "I can play this": one word, what it
## does to the other person, what comes back, what happens if you let it pile
## up, and the one habit that makes all of it work.
const STEPS := [
	{
		"id": "fire",
		"title": "TYPE A WORD",
		"body": "Any word at all. Its LAST letters land on your opponent "
			+ "as a block.",
		"body_touch": "Any word at all. Its LAST letters land on your "
			+ "opponent as a block.",
		"hint": "three letters or more — press SPACE to fire",
		"hint_touch": "three letters or more — tap FIRE to send",
	},
	{
		"id": "answer",
		"title": "AND THEIRS COME BACK",
		"body": "Type a word that STARTS with the letters on the block. "
			+ "It is the only way to clear it.",
		"hint": "attacking will not save you",
	},
	{
		"id": "danger",
		"title": "YOU GET THREE CHANCES",
		"body": "Let the stack reach the top and you lose a life and the whole "
			+ "board — but not the match. You have three.",
		"hint": "get the stack down",
	},
	{
		"id": "always",
		"title": "NEVER STOP TYPING",
		"body": "You do not have to wait for blocks. Every word you fire is "
			+ "points, damage, and one less thing to answer.",
		"hint": "keep firing — anything counts",
	},
	{
		"id": "done",
		"title": "THAT IS THE WHOLE GAME",
		"body": "Power words, salvos and chains are all built on those rules. "
			+ "Go and play one.",
		"hint": "press SPACE to start · R to run through it again",
		"hint_touch": "tap FIRE to start · tap RESTART to run it again",
	},
]


## `touch` swaps in the phone wording for any step that has it. The returned
## dictionary always has plain `body` and `hint` keys, so nothing downstream has
## to know which device it is drawing for.
static func step(i: int, touch: bool = false) -> Dictionary:
	if i < 0 or i >= STEPS.size():
		return {}
	var s: Dictionary = STEPS[i]
	if not touch:
		return s
	var out := s.duplicate()
	for key in ["body", "hint", "title"]:
		if out.has(key + "_touch"):
			out[key] = out[key + "_touch"]
	return out


static func count() -> int:
	return STEPS.size()
