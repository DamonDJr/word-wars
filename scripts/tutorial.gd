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

const STEPS := [
	{
		"id": "fire",
		"title": "TYPE A WORD",
		"body": "Anything you like. Press SPACE to fire it.",
		"body_touch": "Anything you like. Tap FIRE to send it.",
		"hint": "three letters or more",
	},
	{
		"id": "tail",
		"title": "YOUR ENDING IS THEIR BEGINNING",
		"body": "The LAST letters of that word are now stamped on a block —\n"
			+ "and this one has been dropped on you.",
		"hint": "watch the stamp",
	},
	{
		"id": "answer",
		"title": "ANSWER IT",
		"body": "Type a word that STARTS with the letters on the block.\n"
			+ "That is the only way garbage ever leaves your board.",
		"hint": "attacking does not defend you",
	},
	{
		"id": "reach",
		"title": "LONGER WORDS REACH FURTHER",
		"body": "Three blocks, same stamp. One word clears one block per two\n"
			+ "letters — so a short answer only takes one of them.",
		"hint": "clear all three",
	},
	{
		"id": "chain",
		"title": "KEEP FIRING",
		"body": "Blocks you send get bigger two ways: a long word hits hard on\n"
			+ "its own, and a run without pausing lifts everything you throw.",
		"hint": "reach a x4 chain",
	},
	{
		"id": "danger",
		"title": "FILLING UP COSTS A LIFE",
		"body": "Not the match — one of three lives, and the board is wiped.\n"
			+ "Clear this lot before it reaches the top.",
		"hint": "get the stack down",
	},
	{
		"id": "done",
		"title": "THAT IS THE WHOLE GAME",
		"body": "Everything else — power words, salvos, the chain ladder —\n"
			+ "is built on those four rules.",
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
