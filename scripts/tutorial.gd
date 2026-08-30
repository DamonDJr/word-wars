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

const STEPS := [
	{
		"id": "fire",
		"title": "TYPE A WORD",
		"body": "Any word at all. Press SPACE to fire it.",
		"body_touch": "Any word at all. Tap FIRE to send it.",
		"hint": "three letters or more",
	},
	{
		"id": "tail",
		"title": "YOUR ENDING IS THEIR BEGINNING",
		"body": "Its LAST letters are now stamped on a block — "
			+ "and that block has been dropped on you.",
		"hint": "watch the stamp",
	},
	{
		"id": "answer",
		"title": "ANSWER IT",
		"body": "Type a word that STARTS with the letters on the block. "
			+ "It is the only way to clear garbage.",
		"hint": "attacking will not save you",
	},
	{
		"id": "reach",
		"title": "LONGER WORDS REACH FURTHER",
		"body": "One word clears one block per two letters. "
			+ "Three blocks need a six-letter word.",
		"hint": "clear all three",
	},
	{
		"id": "chain",
		"title": "KEEP FIRING",
		"body": "Fire again before the bar under your board runs out. "
			+ "A chain makes everything you send bigger.",
		# Replaced at draw time with the goal actually being asked for, which
		# eases off if this step is taking a while — see `_lesson_chain_goal`.
		"hint": "chain three words",
	},
	{
		"id": "danger",
		"title": "FILLING UP COSTS A LIFE",
		"body": "Top out and you lose a life and the whole board — but not the "
			+ "match. Clear this lot before it reaches the top.",
		"hint": "get the stack down",
	},
	{
		"id": "done",
		"title": "THAT IS THE WHOLE GAME",
		"body": "Power words, salvos and the chain ladder are all built on those "
			+ "four rules.",
		"hint": "press SPACE to finish",
		"hint_touch": "tap FIRE to finish",
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
