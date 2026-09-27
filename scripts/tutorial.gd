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
##
## ## The fields past title, body and hint
##
## `after` replaces the body once the step is done. Only the first step has one:
## the opponent's board is not drawn in a lesson, so the card is the only place
## the player can find out what their word actually did.
##
## `stuck` replaces the hint when the player looks stuck: a miss, a rejected
## word, FIRE on an empty line, or `LESSON_STUCK_AFTER` seconds with no word
## fired. It still never advances anything. It says what to do next, and where
## there is a block to answer it names a word that answers it. Players who got
## a block they could not answer sat there and never fired a thing, and a word
## on the card is the one thing that gets somebody frozen typing again.
##
## `card: "low"` sits the card on the bottom of the board rather than across
## the middle, for the one step whose blocks are at the top.
##
## Anything in braces is filled in by `game.gd` when the card is drawn: {word}
## and {sent} are the player's word and what it landed, {their} and {stamp} are
## the opponent's word and the block it left, {example} is a word that answers
## it and {left} is how many words the step still wants.
const STEPS := [
	{
		"id": "fire",
		"title": "TYPE A WORD",
		"body": "Any word at all. Its LAST letters land on your opponent "
			+ "as a block.",
		"after": "{word} sent {sent} their way. Now they need a word that "
			+ "starts with {sent} to clear it.",
		"hint": "three letters or more, then SPACE to fire",
		"hint_touch": "three letters or more, then tap FIRE",
		"stuck": "type on your keyboard, then press SPACE",
		"stuck_touch": "tap the letters below, then tap FIRE",
	},
	{
		"id": "answer",
		"title": "AND THEIRS COME BACK",
		"body": "They fired {their} back at you. Type a word that STARTS "
			+ "with {stamp} to clear the block.",
		"hint": "any other word just flies at them",
		"stuck": "stuck? try {example}",
	},
	{
		"id": "danger",
		"title": "YOU GET THREE CHANCES",
		"body": "If the stack reaches the top you lose a life and the whole "
			+ "board, but not the match. You have three.",
		"hint": "clear the block in the red",
		"stuck": "stuck? try {example}",
		"card": "low",
	},
	{
		"id": "always",
		"title": "NEVER STOP TYPING",
		"body": "You don't have to wait for blocks. Every word you fire "
			+ "scores and hits them with a block.",
		"hint": "any word counts · {left} more",
		"stuck": "any word at all, like {example}",
	},
	{
		"id": "done",
		"title": "THAT'S THE WHOLE GAME",
		"body": "Power words, salvos and chains are all built on those rules. "
			+ "Go play a match.",
		"hint": "press SPACE to start · R to run through it again",
		"hint_touch": "tap FIRE to start · tap RESTART to run it again",
	},
]


## What the lesson's opponent fires back in step two. The block it leaves is the
## word's last two letters, so the card can name the word and the player can see
## where the letters came from: the rule from step one, pointed the other way.
##
## Chosen for their endings. Step two used to brand the block with the tail of
## the player's own word, straight off the end with no fairness check at all, so
## HAPPY dealt PPY and HELLO dealt LLO: blocks no word in English answers, on the
## step that cannot be passed without answering one. Every ending here opens
## hundreds of everyday words, and `game.gd` still checks each one before
## using it.
const RETURN_FIRE := ["FAST", "FIRE", "FISH", "GAME", "RAIN", "ECHO", "RIDE",
	"PHOTO"]


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
	for key in ["body", "hint", "title", "stuck"]:
		if out.has(key + "_touch"):
			out[key] = out[key + "_touch"]
	return out


static func count() -> int:
	return STEPS.size()
