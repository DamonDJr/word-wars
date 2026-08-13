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

const STEPS := [
	{
		"id": "fire",
		"title": "TYPE A WORD",
		"body": "Anything you like. Press SPACE to fire it.",
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
		"body": "Blocks you send get bigger the longer you go without pausing.\n"
			+ "Nothing to do with how long your words are — only the rhythm.",
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
		"body": "Everything else — power words, salvos, special blocks —\n"
			+ "is built on those four rules.",
		"hint": "press SPACE to finish",
	},
]


static func step(i: int) -> Dictionary:
	if i < 0 or i >= STEPS.size():
		return {}
	return STEPS[i]


static func count() -> int:
	return STEPS.size()
