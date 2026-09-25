extends RefCounted
## The editorial line for words that end up in footage we publish.
##
## Shared by `adreel.gd` and `trailer.gd` because it is one policy, and a second
## copy of a list like this goes stale — and the copy that goes stale is always
## the one nobody is looking at. It exists at all because the pickers in both
## tools take the *longest* word available on the board, which is a different
## selection pressure from the one the game applies to a player.
##
## Two mechanisms, doing two different jobs.
##
## `MAX_RANK` is the blunt one and does most of the work. `WordBank._common` is
## frequency-ordered, so capping how far down it a picker may reach removes the
## rare tail — and the rare tail of an English frequency list is
## disproportionately clinical, legal and grim. Before the cap, successive takes
## opened on `nymphomaniac`, `manslaughter`, `lymphoma` and `bereavement`; each
## fix was one more substring and the next take found another. Capping the rank
## attacks the reason rather than the instances.
##
## `NOT_IN_AN_AD` is the list of what the cap still lets through. It is an
## editorial line, not a decency one: nearly everything on it is a perfectly
## ordinary English word that is simply wrong beside a keyboard in a shop
## window.
##
## Profanity is not handled here at all. The game's own `Censor` already knows
## the stems and generates the inflections, so it is called rather than copied.


## How far down the common list a picker may reach.
##
## 20,000 of 35,782 keeps 2,634 words of ten letters or more, which is ample for
## a reel that types about twenty of them. It costs a few good long words —
## `assimilation` sits at 31,148 — and that is a fair trade for not having to
## wonder what the next take will say.
const MAX_RANK := 20000

## Substring match, so inflections go with the stem.
const NOT_IN_AN_AD := [
	# Sex, which Censor treats as clinical rather than profane.
	"sex", "lovemak", "nympho", "seduc", "erotic", "porn", "fetish", "orgas",
	"prostitut", "brothel", "incest", "molest", "rape", "rapist", "pedo",
	# `masturb` sits inside the rank cap — a take of the emote reel typed it at
	# four seconds in — which is the case this list is for: common enough that
	# `MAX_RANK` will not thin it out, and wrong beside a keyboard regardless.
	"masturb",
	# Violence and death.
	"kill", "death", "dead", "murder", "slaughter", "massacre", "homicide",
	"suicid", "corpse", "morgue", "funeral", "autops", "torture", "hostage",
	"terror", "shooting", "stabb", "strangl", "lynch", "violen", "assault",
	# Illness, and grief. The rank cap thins these out; it does not empty them.
	"cancer", "oncolog", "tumour", "tumor", "lymphoma", "leukem", "disease",
	"infect", "virus", "appendic", "diabet", "dementia", "alzheim", "paralys",
	"bereave", "grief", "grieving", "mourn", "widow", "orphan",
	"addict", "overdose", "drug", "cocaine", "heroin", "amphetamin", "opioid",
	"methadone", "narcotic", "sedativ", "antidepress",
	# History nobody wants beside a keyboard.
	"nazi", "hitler", "holocaust", "slave", "slaver", "genocide", "apartheid",
	"abort",
	# Identity, politics and religion. Not because there is anything wrong with
	# any of these words, but because this footage shows one word at a time with
	# no sentence around it, and a lone word on screen for half a second reads
	# as a statement rather than as a dictionary entry.
	#
	# `communis` rather than `commun`, which would also take out communication,
	# community and communicate — three of the most ordinary long words in the
	# dictionary and exactly the kind these pickers reach for.
	"lesbian", "transgender", "communis", "fascis", "zionis",
	"islam", "muslim", "christian", "jewish", "atheis",
]


## Whether a word is one the footage must not type.
##
## `Censor` first because it is the game's own answer and the cheaper call. Note
## this rejects the *candidate*, where the game would merely mask it on screen —
## a masked word renders as a row of asterisks, which is a worse thing to put in
## a trailer than the word was.
static func unpostable(word: String) -> bool:
	if Censor.is_profane(word) or Censor.is_slur(word):
		return true
	for bad in NOT_IN_AN_AD:
		if word.contains(bad):
			return true
	return false
