extends Node
## Autoload `Profile`. What the player has done across every match they have
## ever played, what that has earned them, and what they are wearing.
##
## Nothing in here touches how the game plays. That is the whole point: mastery
## is worth showing off precisely because it cannot be cashed in for an
## advantage, so a level 30 player and a level 1 player meet on the same terms
## and the level is a claim about the person rather than the loadout.
##
## Everything is derived. XP is a pure function of the record, the level is a
## pure function of XP, and what is unlocked is a pure function of the record —
## so nothing can drift out of step, and changing a formula re-grades every
## existing profile on the next boot instead of stranding it.

## A variable rather than a constant purely so the tests can point it at a
## scratch file: a suite that overwrites the player's actual record to prove the
## record works would be a poor trade.
var save_path := "user://profile.cfg"

signal changed


# ------------------------------------------------------------------- the record

var matches := 0
var wins := 0
var flawless := 0          ## wins that cost no lives at all
var words := 0
var chars := 0
var salvos := 0
var multi_clears := 0      ## words that broke three or more at once
var best_wpm := 0.0
var best_chain := 0
var best_combo := 0
var best_score := 0
var longest_word := ""
## Power word name -> times earned.
var powers: Dictionary = {}

## Slot -> cosmetic id.
var equipped: Dictionary = {}

# ------------------------------------------------------------------ purchases
#
# What has been bought, as a set of pack ids. Kept as its own thing rather than
# as another unlock rule because it is not earned and never will be: no amount
# of play reaches it, and no change to the XP formula should ever hand it out by
# accident.
#
# There is no store here yet. `grant` is what a real purchase callback would
# call once a receipt validated, and the test button in settings calls the same
# function — so the thing being tested is the thing that will ship.

const PACK_PREMIUM := "premium"

var owned: Dictionary = {}
## Matches played since the last ad break. Counted here rather than in the match
## so it survives a restart — otherwise quitting to the title is a way to never
## see one.
var since_ad := 0

## How many matches this gap is worth, rolled fresh after every break.
##
## A number rather than a constant, because a break that lands on exactly every
## third match is a rhythm players learn to feel coming — and the match they
## learn to feel it on is the one they stop before. Three to five, rolled once
## per gap, is frequent enough to be worth selling against and irregular enough
## not to be counted.
##
## Saved alongside the counter. A gap re-rolled at every launch would let a
## restart shop for a longer one, which is the same hole as counting matches in
## the match rather than here.
var ad_gap := 0

## Two to three, down from three to five.
##
## A tester reported two breaks in twenty minutes of play, which is the clock
## budget below working exactly as written and being far too patient about it.
## The old numbers were chosen before there was any revenue to weigh them
## against; they are gentler than anything else in the category, and gentle is
## only a virtue while somebody is still playing.
##
## Two is the floor on purpose. One would put a break after every single match,
## which is the rhythm players learn to feel coming — and the match they learn to
## feel it on is the one they stop before.
const ADS_EVERY_MIN := 2
const ADS_EVERY_MAX := 3

## Seconds of counted play since the last break, and how many this gap is worth.
##
## Counting matches was the whole rule until survival arrived, and survival broke
## it in the one way a counter of matches can be broken: it is a single match
## that can run for half an hour. A player who only plays survival would see one
## break a session, which is neither what the game needs nor what they expect
## from a free game — and the fix cannot be to count survival as several matches,
## because then a run that ends in ninety seconds is charged for five.
##
## So there are two budgets and a break is due when *either* is spent. Normal
## play keeps the match count it was tuned on and almost always trips that one
## first; survival feeds the clock and trips this one. Nothing has to know which
## mode it is in — every mode that counts hands over the seconds it took, and the
## arithmetic is the same everywhere.
##
## Five to eight minutes, down from nine to fourteen.
##
## The two budgets are kept in step deliberately: the clock is meant to be the
## one survival trips and the match count the one everything else trips, and that
## only holds while a gap costs about the same measured either way. Nine to
## fourteen was what three to five matches cost; five to eight is what two to
## three costs. Moving one without the other would have made the clock the rule
## everywhere, which is the opposite of what it is for.
##
## Still conservative against the category, which mostly runs interstitials every
## two to four minutes. There is room to go further if the numbers ask for it —
## but retention is harder to win back than an impression is to lose.
var play_since_ad := 0.0
var ad_gap_seconds := 0.0

const ADS_MINUTES_MIN := 5.0
const ADS_MINUTES_MAX := 8.0


## The next gap. Inclusive of both ends, so five is as reachable as three.
##
## Both budgets are rolled together and spent together. Rolling only one of them
## at a break would leave the other carrying a number chosen for a gap that has
## already been paid for.
func roll_ad_gap() -> void:
	ad_gap = randi_range(ADS_EVERY_MIN, ADS_EVERY_MAX)
	ad_gap_seconds = randf_range(ADS_MINUTES_MIN, ADS_MINUTES_MAX) * 60.0


## Whether a break is due. Asked at the end of a match — and, in survival, at the
## end of a life — so the answer is about the play that just happened.
func ad_due() -> bool:
	if ads_removed():
		return false
	# A profile written before gaps existed, or a brand new one, has never rolled
	# one. Done here rather than at load so there is exactly one place that can
	# leave a gap at zero — and zero would make every match a break.
	#
	# Filled in one at a time rather than as a pair, which `roll_ad_gap` would do.
	# Every profile written before the clock budget existed carries a perfectly
	# good match gap and no seconds at all, so rolling both on the first question
	# would throw away a gap the player is already part-way through: every
	# existing save would have its cadence quietly reset by the upgrade, and the
	# match after it would be as likely to break as any other.
	if ad_gap <= 0:
		ad_gap = randi_range(ADS_EVERY_MIN, ADS_EVERY_MAX)
	if ad_gap_seconds <= 0.0:
		ad_gap_seconds = randf_range(ADS_MINUTES_MIN, ADS_MINUTES_MAX) * 60.0
	return since_ad >= ad_gap or play_since_ad >= ad_gap_seconds


func note_match_for_ads() -> void:
	if ads_removed():
		return
	since_ad += 1
	save()


## Time that counts towards a break, in seconds.
##
## Saved, like the match count, so quitting to the title is not a way to never
## see one. Called with the length of a match that has just finished, or of a
## life that has just been spent — never with a running total, so the same
## seconds cannot be handed over twice.
func note_time_for_ads(seconds: float) -> void:
	if ads_removed() or seconds <= 0.0:
		return
	play_since_ad += seconds
	save()


func clear_ad() -> void:
	since_ad = 0
	play_since_ad = 0.0
	roll_ad_gap()
	save()


func owns(pack: String) -> bool:
	return bool(owned.get(pack, false))


## Ads are the other half of the pack. Nothing here shows one — this is the flag
## the ad break asks before it decides to exist.
func ads_removed() -> bool:
	return owns(PACK_PREMIUM)


## Hand over a pack. Idempotent, because a restore-purchases flow will call it
## again for something already owned and that must not be an error.
func grant(pack: String) -> void:
	if owns(pack):
		return
	owned[pack] = true
	save()
	changed.emit()


## For testing the flow more than once.
func revoke(pack: String) -> void:
	if not owns(pack):
		return
	owned.erase(pack)
	# Anything worn from that pack has to come off, or a revoked purchase stays
	# on screen until something else happens to re-equip.
	for slot: String in SLOTS:
		var id := String(equipped.get(slot, ""))
		if id != "" and not is_unlocked(slot, id):
			equipped.erase(slot)
	save()
	changed.emit()

## Settings and remembered choices. Kept in the same file as the record because
## it is all "this player's stuff", and one file is one thing that can go wrong.
var prefs: Dictionary = {}

const PREF_DEFAULTS := {
	"music": 0.7,
	"sfx": 0.8,
	"texture": true,     ## film grain and vignette
	"hitstop": true,     ## the freeze-frame on heavy hits
	"censor": true,      ## mask profanity wherever a word is echoed back
	"fullscreen": false,
	"haptics": true,     ## the taptic engine; no-op on anything without one
	## Rival seats for a single-player match. "" is an empty seat, "?" is a
	## random personality rolled at the start of each match, anything else names
	## one from the roster.
	"solo": ["Duelist", "", ""],
	## Split the on-screen keyboard into two thumb-sized halves pinned to the
	## edges of the screen. Only reachable, and only offered, on a tablet — see
	## `_kb_form` in `game.gd`. On by default there, because a foot-wide
	## keyboard has a middle neither thumb can get to, and the players who set
	## the thing on a table and use more fingers are the ones who will go
	## looking for the switch.
	"split_keys": true,
	## Set once the tutorial has been finished, so the game only nags once.
	"taught": false,
	## Set the first time the game opens the tutorial by itself. Separate from
	## `taught` on purpose: a first-time player who backs out of the lesson has
	## answered the offer, and re-offering it on every launch would be a loop
	## they cannot leave. Offered once, then the title screen's own nag takes
	## over — which is a plate they can choose rather than a screen they land in.
	"tutorial_offered": false,
	## The player's own switch for the daily reminders. Off by default and turned
	## on only where it is asked for — see `notify.gd`. It is not the same
	## question as whether iOS has granted permission, and `Notify.enabled()`
	## wants both.
	"notify": false,
	## Whether the system permission dialog has been put up. iOS offers it once
	## per install and never again, so this is what stops a second attempt that
	## could only ever be a no-op.
	"notify_asked": false,
	## Whether the player has ever worked the switch above themselves. Set by
	## `Notify.set_enabled` and never cleared.
	##
	## `notify` being false is three different situations — never asked, asked and
	## refused, deliberately turned off — and the offer after a daily run must
	## only be made in the first. This is the half of that question `notify_asked`
	## cannot answer: somebody who found the row in settings and turned it on and
	## off again has answered, even though no iOS dialog was involved.
	"notify_touched": false,
	## The daily key whose banked score has already been resent to a running
	## challenge, so it is sent once rather than on every frame of the title
	## screen. A date rather than a bool: tomorrow's board is a new question.
	## See `_maybe_send_banked_to_challenge`.
	"challenge_sent_for": "",
	## The rating prompt's budget. iOS allows three displays a year and reports
	## nothing about whether any of them happened, so these are counted at the
	## moment of asking rather than on a confirmation that never comes.
	"review_asks": 0,
	"review_last": 0,
	## The last content drop whose pitch this player has seen, and the last one
	## whose new cosmetics they have gone and looked at. Both are numbers rather
	## than bools so that the next batch of boards can announce itself without
	## anything new being written; see `PROMO_DROP`.
	"promo_seen": 0,
	"cosmetics_seen": 0,
	## The same idea as `promo_seen`, for the share ladder. Its own counter
	## rather than sharing one, because the two pitches are owed to different
	## people: the premium card is for anybody who has not bought the pack, and
	## this one is for anybody missing Waddles or Nexus — which includes buyers,
	## since no amount of money reaches either.
	"share_promo_seen": 0,
	## The local date the share card was last shown, so it can come back.
	"share_promo_day": "",
}

## Which batch of paid content is current.
##
## Bumped by hand, once, in the commit that adds the content. Everything that
## announces new cosmetics compares against it: a player whose `promo_seen` is
## behind is owed the pitch, a player whose `cosmetics_seen` is behind gets the
## badge on the door. Seeing it writes the number back, and both go quiet until
## the next bump.
##
## A number rather than a "has seen the premium pitch" bool because the bool
## only works once. The eight painted boards are the second thing this pack has
## ever gained, and on the day there is a ninth, a bool would have to be renamed
## or hand-cleared on every install in the world.
##
## 0 is "before any of this existed", which is what every save written before
## this version reads back as — so the drop below is owed to exactly the people
## who have not seen it, including everyone upgrading.
##
##   1  the eight painted boards and the block faces drawn for them
const PROMO_DROP := 1

## The same, for the share rewards. Bumped when the ladder gains a rung.
##
##   1  the Herald title, the Nexus board and Waddles
const SHARE_DROP := 1


## How many days before the share card is shown again to somebody still
## climbing the ladder.
##
## It used to be shown once, ever — and a ladder you are told about once and
## then never see again is a ladder nobody climbs past the first rung, because
## the rewards are fifteen separate days apart and nothing on any of those days
## says they exist. Every few days is often enough to be remembered and rare
## enough not to be the thing a player sees instead of the game.
const SHARE_PROMO_EVERY := 4


## Whether this player is owed the share-rewards pitch today.
##
## Unlike `owes_promo` this is not about money — a premium buyer is shown it
## too, because the three rewards on it are the only things in the game their
## purchase does not reach. It stops being owed once they are all in hand,
## which is the point at which the card would be advertising things the player
## is already wearing — and on a day they have already shared, when it has
## nothing to ask for.
func owes_share_promo(today: String) -> bool:
	if share_rewards_complete() or share_days.has(today):
		return false
	if int(pref("share_promo_seen")) < SHARE_DROP:
		return true
	var last := String(pref("share_promo_day"))
	return last == "" or _days_between(last, today) >= SHARE_PROMO_EVERY


static func _days_between(a: String, b: String) -> int:
	var ta := Time.get_unix_time_from_datetime_string(a)
	var tb := Time.get_unix_time_from_datetime_string(b)
	return int(round(float(tb - ta) / 86400.0))


## Whether every rung of the ladder has been climbed.
func share_rewards_complete() -> bool:
	for slot: String in SLOTS:
		for e: Dictionary in entries(slot):
			if (e.get("need", {}) as Dictionary).has("shares") \
					and not meets(e["need"]):
				return false
	return true


func note_share_promo_seen(today: String) -> void:
	if int(pref("share_promo_seen")) < SHARE_DROP:
		set_pref("share_promo_seen", SHARE_DROP)
	set_pref("share_promo_day", today)


## Whether this player is owed the pitch for the current drop.
##
## Owning the pack is the first question and not the only one: somebody who
## bought it already has the boards and does not need to be sold them, and
## somebody who has seen this drop's pitch has answered it.
func owes_promo() -> bool:
	if owns(PACK_PREMIUM):
		return false
	return int(pref("promo_seen")) < PROMO_DROP


## Whether the cosmetics door should be wearing a NEW badge.
##
## Deliberately not gated on owning the pack. The premium badge is an offer and
## belongs only to people who have not taken it; this one says "the wardrobe has
## things in it you have not seen", which is true for a buyer as well — more so,
## since they are the ones who can wear them.
func cosmetics_are_new() -> bool:
	return int(pref("cosmetics_seen")) < PROMO_DROP


## Mark a drop's announcement as delivered. Separate calls because the two are
## answered by different acts: the pitch by being shown, the badge by the player
## opening the screen it points at.
func note_promo_seen() -> void:
	if int(pref("promo_seen")) < PROMO_DROP:
		set_pref("promo_seen", PROMO_DROP)


func note_cosmetics_seen() -> void:
	if int(pref("cosmetics_seen")) < PROMO_DROP:
		set_pref("cosmetics_seen", PROMO_DROP)


func pref(key: String):
	return prefs.get(key, PREF_DEFAULTS.get(key))


func set_pref(key: String, value) -> void:
	prefs[key] = value
	save()
	changed.emit()


# ------------------------------------------------------------------------- xp
#
# Every line the request asked for is in here, weighted by how much work it
# represents rather than how big the number gets. Words typed is the grind and
# pays least per unit; a salvo is a nine-word run cashed in and pays like it.
# The `best_` figures are peaks rather than totals, so they pay once and pay
# well — they are a claim about your ceiling, not your patience.

const XP := {
	"match": 90,
	"win": 240,
	"flawless": 350,
	"word": 4,
	"salvo": 130,
	"multi_clear": 22,
	"wpm": 4,            ## per point of your best
	"chain": 12,         ## per link of your best, squared below
	"combo": 30,
	"longest": 5,        ## per letter of your longest, squared below
	## A survival run, which is not a match and cannot be won. Worth a shade more
	## than a match is because it takes longer on average and has no win bonus
	## behind it to reach for — without that it would be the one mode where
	## playing well earns less than playing anything else.
	"survival": 120,
}


func xp_total() -> int:
	var n := 0
	n += matches * int(XP["match"])
	n += survival_runs * int(XP["survival"])
	n += wins * int(XP["win"])
	n += flawless * int(XP["flawless"])
	n += words * int(XP["word"])
	n += salvos * int(XP["salvo"])
	n += multi_clears * int(XP["multi_clear"])
	n += int(best_wpm) * int(XP["wpm"])
	# Squared, because the difference between a five-chain and a nine-chain is
	# not four more words, it is four more words without a single mistake.
	n += best_chain * best_chain * int(XP["chain"])
	n += best_combo * best_combo * int(XP["combo"])
	n += longest_word.length() * longest_word.length() * int(XP["longest"])
	for key in powers:
		n += int(powers[key]) * 18
	# The weekly missions, and the one thing in here that is not derived.
	#
	# Everything above is a pure function of the lifetime record, which is a
	# property worth keeping: it means a level can be recomputed from the stats
	# and never drifts. A mission cannot work that way — "reach a x7 chain this
	# week" is not recoverable from a lifetime peak, because the peak does not
	# know which week it happened in. So the payout is banked when it is earned
	# and carried as its own total.
	#
	# It is still part of the record rather than a wallet: it only ever goes up,
	# nothing spends it, and `shoptest` still proves the premium entries cannot
	# be reached by playing — a mission pays XP, and XP has never unlocked the
	# paid pack.
	n += weekly_xp
	return n


## Levels get further apart forever. The first few arrive inside one sitting so
## the system introduces itself; by level 20 you are being asked for real work.
const LEVEL_STEP := 300


func level() -> int:
	return 1 + int(sqrt(float(xp_total()) / float(LEVEL_STEP)))


func xp_for_level(n: int) -> int:
	var m := maxi(0, n - 1)
	return m * m * LEVEL_STEP


## How far through the current level, 0..1, plus the numbers either side of it.
func level_progress() -> Dictionary:
	var lv := level()
	var floor_xp := xp_for_level(lv)
	var next_xp := xp_for_level(lv + 1)
	var have := xp_total()
	return {
		"level": lv,
		"into": have - floor_xp,
		"need": next_xp - floor_xp,
		"frac": clampf(float(have - floor_xp) / float(maxi(1, next_xp - floor_xp)), 0.0, 1.0),
	}


# ------------------------------------------------------------------ cosmetics
#
# One table. The mastery screen builds itself from it, the unlock check reads
# the same rows, and adding a cosmetic means adding a row — there is nowhere for
# a "shown but not obtainable" entry to hide.
#
# `need` is empty for the ones you start with. Otherwise it names a single
# requirement, because "reach a nine-chain" is a thing somebody can go and do
# and "reach a nine-chain and 400 words and level 12" is a wall.

## "emote" was a ninth slot until the art was redrawn as BloqBot. It styled the
## emotes by multiplying white art with a colour, and the new character is
## already coloured, so there was no longer anything for the slot to change.
## A stale `equipped["emote"]` in an older save is left where it is — nothing
## iterates it any more, and rewriting the file to drop one dead key is a worse
## trade than carrying it.
const SLOTS := ["title", "theme", "blocks", "character", "typing", "attack",
	"cursor", "victory"]

const SLOT_NAMES := {
	"title": "TITLE",
	"theme": "BOARD THEME",
	"blocks": "BLOCK STYLE",
	"character": "CHARACTER",
	"typing": "TYPING",
	"attack": "ATTACK",
	"cursor": "CURSOR",
	"victory": "VICTORY",
}

const COSMETICS := {
	"title": [
		{"id": "none", "name": "—", "need": {}},
		{"id": "rookie", "name": "Rookie", "need": {"matches": 3}},
		{"id": "dictionary", "name": "Dictionary", "need": {"words": 600}},
		# Kept in step with the `speed_demon` achievement in `achievements.gd`,
		# which is named after this title and unlocks alongside it. Lowered from
		# 65 with it: that was a desktop pace on a game played with thumbs.
		{"id": "speed_demon", "name": "Speed Demon", "need": {"wpm": 50}},
		{"id": "chainbreaker", "name": "Chainbreaker", "need": {"chain": 8}},
		{"id": "wordsmith", "name": "Wordsmith", "need": {"longest": 12}},
		{"id": "no_looking_back", "name": "No Looking Back", "need": {"flawless": 1}},
		{"id": "counterpuncher", "name": "Counterpuncher", "need": {"power:COUNTER": 30}},
		{"id": "clutch", "name": "Ice Water", "need": {"power:CLUTCH": 10}},
		{"id": "perfectionist", "name": "Perfectionist", "need": {"power:PERFECT": 25}},
		{"id": "salvo_king", "name": "SALVO KING", "need": {"salvos": 12}},
		{"id": "undefeated", "name": "Undefeated", "need": {"wins": 15}},
		{"id": "centurion", "name": "Centurion", "need": {"matches": 100}},
		{"id": "founder", "name": "FOUNDER", "need": {"buy": PACK_PREMIUM}},
		# The first rung of the share ladder, and deliberately the cheapest
		# thing on it. Three days is close enough that somebody finds out the
		# ladder exists by finishing it rather than by reading about it.
		{"id": "herald", "name": "HERALD", "need": {"shares": 3}},
	],
	"theme": [
		{"id": "midnight", "name": "Midnight", "need": {}},
		{"id": "ember", "name": "Ember", "need": {"level": 3}},
		{"id": "chlorophyll", "name": "Chlorophyll", "need": {"level": 6}},
		{"id": "vapor", "name": "Vapour", "need": {"level": 10}},
		{"id": "bone", "name": "Bone", "need": {"level": 16}},
		{"id": "prism", "name": "Prism", "need": {"buy": PACK_PREMIUM}},
		# The painted eight. All in the pack that was already being sold rather
		# than in a second one: there is one product in this game, and a player
		# who bought it last month should find it has got better rather than
		# find a new thing to buy behind the thing they bought.
		{"id": "forest", "name": "Forest", "need": {"buy": PACK_PREMIUM}},
		{"id": "volcano", "name": "Volcano", "need": {"buy": PACK_PREMIUM}},
		{"id": "ocean", "name": "Ocean", "need": {"buy": PACK_PREMIUM}},
		{"id": "space", "name": "Space", "need": {"buy": PACK_PREMIUM}},
		{"id": "cyber", "name": "Cyber", "need": {"buy": PACK_PREMIUM}},
		{"id": "clouds", "name": "Clouds", "need": {"buy": PACK_PREMIUM}},
		{"id": "desert", "name": "Desert", "need": {"buy": PACK_PREMIUM}},
		{"id": "aurora", "name": "Aurora", "need": {"buy": PACK_PREMIUM}},
		# The middle rung. The only board in the game that cannot be bought —
		# which is the point of it, and why it is worth more than the price of
		# the pack to the people who want it.
		{"id": "nexus", "name": "Nexus", "need": {"shares": 8}},
	],
	"blocks": [
		{"id": "solid", "name": "Solid", "need": {}},
		{"id": "outline", "name": "Wireframe", "need": {"level": 4}},
		{"id": "glass", "name": "Glass", "need": {"combo": 4}},
		{"id": "circuit", "name": "Circuit", "need": {"level": 12}},
		# One per painted board, and gated the same way. Kept as ordinary
		# entries in their own slot rather than tied to the theme: equipping
		# Volcano does not touch what you are wearing here, because a slot that
		# another slot can overwrite is a slot that stops meaning anything.
		# `Cosmetics.BLOCK_PAIRING` records which board each was drawn for, and
		# the mastery screen says so — a suggestion rather than a switch.
		{"id": "bark", "name": "Heartwood", "need": {"buy": PACK_PREMIUM}},
		{"id": "magma", "name": "Magma", "need": {"buy": PACK_PREMIUM}},
		{"id": "coral", "name": "Coral", "need": {"buy": PACK_PREMIUM}},
		{"id": "nebula", "name": "Nebula", "need": {"buy": PACK_PREMIUM}},
		{"id": "neon", "name": "Neon", "need": {"buy": PACK_PREMIUM}},
		{"id": "cloud", "name": "Cumulus", "need": {"buy": PACK_PREMIUM}},
		{"id": "sandstone", "name": "Sandstone", "need": {"buy": PACK_PREMIUM}},
		{"id": "ice", "name": "Glacier", "need": {"buy": PACK_PREMIUM}},
		# Arrives with the board it was drawn for, on the same rung.
		{"id": "rune", "name": "Runestone", "need": {"shares": 8}},
	],
	# Who sends your emotes. A whole second set of drawings rather than a filter
	# over one set — see the note in `Cosmetics.CHARACTERS` for why the slot that
	# used to live here died and why this is not it coming back.
	"character": [
		{"id": "bloqbot", "name": "BloqBot", "need": {}},
		# The top of the share ladder, and the only one of the three that is a
		# whole new performer rather than a repaint.
		{"id": "waddles", "name": "Waddles", "need": {"shares": 15}},
	],
	"typing": [
		{"id": "plain", "name": "Plain", "need": {}},
		{"id": "sparks", "name": "Sparks", "need": {"words": 250}},
		{"id": "ripple", "name": "Ripple", "need": {"level": 5}},
		{"id": "ghost", "name": "Afterimage", "need": {"wpm": 55}},
	],
	"attack": [
		{"id": "comet", "name": "Comet", "need": {}},
		{"id": "dart", "name": "Dart", "need": {"level": 2}},
		{"id": "swarm", "name": "Swarm", "need": {"salvos": 5}},
		{"id": "bolt", "name": "Bolt", "need": {"chain": 6}},
	],
	"cursor": [
		{"id": "bar", "name": "Bar", "need": {}},
		{"id": "block", "name": "Block", "need": {"matches": 8}},
		{"id": "pulse", "name": "Pulse", "need": {"level": 7}},
		{"id": "spark", "name": "Ember", "need": {"level": 14}},
	],
	"victory": [
		{"id": "plain", "name": "Plain", "need": {}},
		{"id": "confetti", "name": "Confetti", "need": {"wins": 3}},
		{"id": "rays", "name": "Sunburst", "need": {"wins": 8}},
		{"id": "shatter", "name": "Shatter", "need": {"flawless": 3}},
		{"id": "supernova", "name": "Supernova", "need": {"buy": PACK_PREMIUM}},
	],
}


func entries(slot: String) -> Array:
	return COSMETICS.get(slot, [])


func entry(slot: String, id: String) -> Dictionary:
	for e: Dictionary in entries(slot):
		if String(e["id"]) == id:
			return e
	var list: Array = entries(slot)
	return list[0] if not list.is_empty() else {}


## What the player is wearing in a slot, falling back to the first entry if the
## saved one has been renamed away or is not earned yet.
func worn(slot: String) -> String:
	var id := String(equipped.get(slot, ""))
	if id != "" and is_unlocked(slot, id):
		return id
	var list: Array = entries(slot)
	return String(list[0]["id"]) if not list.is_empty() else ""


func equip(slot: String, id: String) -> bool:
	if not is_unlocked(slot, id):
		return false
	equipped[slot] = id
	save()
	changed.emit()
	return true


func is_unlocked(slot: String, id: String) -> bool:
	return meets(entry(slot, id).get("need", {}))


## Where the player currently stands against a requirement, as have/want. The
## mastery screen shows this on locked entries so a lock is a target rather than
## a shrug.
func standing(need: Dictionary) -> Dictionary:
	if need.is_empty():
		return {"have": 1, "want": 1, "what": ""}
	var key := String(need.keys()[0])
	var want := int(need[key])
	var have := 0
	var what := ""
	match key:
		"level": have = level(); what = "reach level %d" % want
		"matches": have = matches; what = "play %d matches" % want
		"wins": have = wins; what = "win %d matches" % want
		"flawless": have = flawless; what = "win %d without losing a life" % want
		"words": have = words; what = "type %d words" % want
		"salvos": have = salvos; what = "land %d salvos" % want
		"wpm": have = int(best_wpm); what = "hit %d wpm" % want
		"chain": have = best_chain; what = "reach a x%d chain" % want
		"combo": have = best_combo; what = "break %d blocks with one word" % want
		"longest": have = longest_word.length(); what = "play a %d-letter word" % want
		"buy":
			# `want` is unused here; owning it is the whole test.
			have = 1 if owns(String(need[key])) else 0
			want = 1
			what = "in the premium pack"
		"shares":
			have = shares()
			what = "share the game on %d days" % want
		_:
			if key.begins_with("power:"):
				var name := key.substr(6)
				have = int(powers.get(name, 0))
				what = "earn %d %s" % [want, name]
	return {"have": have, "want": want, "what": what}


func meets(need: Dictionary) -> bool:
	if need.is_empty():
		return true
	var s := standing(need)
	return int(s["have"]) >= int(s["want"])


## Everything currently earned, as slot -> [ids]. Used to work out what a match
## has just unlocked by diffing against the same call from before it.
func unlocked_set() -> Dictionary:
	var out := {}
	for slot: String in SLOTS:
		var got: Array = []
		for e: Dictionary in entries(slot):
			if meets(e.get("need", {})):
				got.append(String(e["id"]))
		out[slot] = got
	return out


# --------------------------------------------------------------------- recording

## Fold one finished match into the lifetime record. Peaks only move up.
func record_match(r: Dictionary) -> void:
	matches += 1
	if bool(r.get("won", false)):
		wins += 1
		if bool(r.get("flawless", false)):
			flawless += 1
	words += int(r.get("words", 0))
	chars += int(r.get("chars", 0))
	salvos += int(r.get("salvos", 0))
	multi_clears += int(r.get("multi_clears", 0))
	best_wpm = maxf(best_wpm, float(r.get("wpm", 0.0)))
	best_chain = maxi(best_chain, int(r.get("chain", 0)))
	best_combo = maxi(best_combo, int(r.get("combo", 0)))
	best_score = maxi(best_score, int(r.get("score", 0)))
	var lw := String(r.get("longest", ""))
	if lw.length() > longest_word.length():
		longest_word = lw
	for key in r.get("powers", {}):
		powers[key] = int(powers.get(key, 0)) + int(r["powers"][key])
	save()
	changed.emit()


# ------------------------------------------------------------------------ disk
#
# This file is somebody's entire history with the game, so the writing is more
# careful than the amount of data would suggest.
#
# The failure that matters is not "the save was lost", it is "the save was lost
# and then written over". `ConfigFile.save` is not atomic: a crash, a power cut
# or a kill signal partway through leaves a truncated file, and a truncated file
# does not parse. The old code returned quietly when a load failed, leaving every
# field at its default — and the next autosave then replaced a profile we had
# merely failed to *read* with a blank one. That turns a recoverable problem into
# a permanent one.
#
# So: writes go to a temp file and are moved into place, the previous file is
# kept as a backup, a failed load falls back to that backup, and if both are
# unreadable the profile refuses to save at all for the rest of the session
# rather than overwrite something it did not understand.

## Bumped only when the on-disk shape changes in a way that needs migrating.
## Stored so a future version can convert an old file instead of ignoring it.
##
## 2: the premium pack stopped being something a button in Settings could hand
##    out. Saves written before that may carry a grant nobody paid for, and one
##    of the things it buys is silence from the ad break — so a forgotten test
##    tap reads, forever after, as a game whose ads are broken. See `_migrate`.
## 3: the daily streak stopped being stored and started being counted from the
##    history. The number that used to be on disk was the live streak; there is
##    now a best-streak record instead, and the old value is the only evidence
##    of it that an existing save carries.
const SCHEMA := 3

## The streak an older file had on disk, held between `_read` and `_migrate`.
## Nothing outside those two should look at it — after a migration it is a number
## about a schema that no longer exists.
var _legacy_streak := 0

# ---------------------------------------------------------------- the daily
#
# One run a day, and the record of it is what stops a second one. Kept as a map
# of date -> result rather than just "today", so the streak survives and there
# is something to look back at.

## How many days of history to keep. The streak is counted out of this, so it is
## also the longest streak that can be *proved* from the file — see
## `daily_best_streak`, which is what remembers anything longer.
# ------------------------------------------------------------- sharing rewards
#
# Three things earned by telling somebody about the game, in a fixed order: a
# title, then the Nexus board, then Waddles.
#
# ## Why a day is the unit and not a share
#
# iOS reports that the share sheet completed. It does not report where the
# share went, whether it arrived, or whether a human ever looked at it — so a
# raw count of completions is a number anybody can run up to fifteen in two
# minutes by sharing to themselves, and the rewards would cost nothing and
# bring nobody.
#
# Counting at most one a day turns fifteen shares into fifteen separate days on
# which somebody chose to pass the game on. That is still not proof anyone
# installed it, and it cannot be — there is no server and no attribution. But
# it is the difference between a ladder that measures fifteen taps and one that
# measures a fortnight of actually doing the thing.
#
# The honest limitation, written down so nobody is surprised by it later: a
# determined person still gets all three in fifteen days of tapping share and
# cancelling into a note to self. That is an acceptable floor for three
# cosmetics, and the alternative is an attribution backend for a word game.

## Days on which at least one share completed, newest last. Dates rather than a
## count so that "already counted today" is answerable after a restart, and so
## the streak is auditable if anybody ever asks why a reward has not arrived.
var share_days: Array = []
## Kept short. The ladder tops out at 15 and nothing reads further back, so
## there is no reason to carry a year of dates in the save.
const SHARE_DAYS_KEPT := 40


## How many qualifying days are on file. This is what the `shares` requirement
## in the catalogue is measured against.
func shares() -> int:
	return share_days.size()


## Record a completed share. Returns true if it counted — the caller uses that
## to decide whether to say so.
##
## `today` is passed in rather than read here, so the one clock this game
## agrees on stays `game.gd`'s and a test can walk days without touching the
## system time.
func note_share(today: String) -> bool:
	if today == "" or share_days.has(today):
		return false
	share_days.append(today)
	share_days.sort()
	while share_days.size() > SHARE_DAYS_KEPT:
		share_days.remove_at(0)
	save()
	changed.emit()
	return true


## Whether a share today would still count for anything, for the copy on the
## share button. False once every reward is in hand, or once today is spent.
func share_counts_today(today: String) -> bool:
	if share_days.has(today):
		return false
	return shares() < share_top()


## The last rung of the ladder. Derived rather than written twice — the
## catalogue below is what decides the thresholds, and a constant here that
## drifted from it would make the share button lie about whether it is worth
## pressing.
static func share_top() -> int:
	var top := 0
	for slot: String in SLOTS:
		for e: Dictionary in (COSMETICS.get(slot, []) as Array):
			var need: Dictionary = e.get("need", {})
			if need.has("shares"):
				top = maxi(top, int(need["shares"]))
	return top


# --------------------------------------------------------- the weekly missions
#
# Four jobs a week, reset every Sunday. `Missions` owns which four and what they
# ask for; this owns how far along you are and what has been paid out.
#
# ## Why progress is keyed by the week
#
# A single "progress" dictionary would be a week behind the moment the clock
# rolled over, and clearing it on rollover needs something to notice the
# rollover — which is a thing that only runs when the game is open. Keyed by
# the Sunday, a new week simply has no entry yet and reads as all zeros, and the
# old week's numbers sit there harmlessly until they are trimmed. Nothing has to
# fire at midnight for the reset to be correct.

## Sunday key -> {"progress": {metric: number}, "paid": [mission ids]}.
var weekly: Dictionary = {}
## XP banked from finished missions, ever. Folded into `xp_total`.
var weekly_xp := 0
## How many whole weeks have been cleared — all four, in one week.
var weekly_cleared := 0
## Weeks of history kept. Eight is two months, which is enough to show a run of
## them and not enough to turn the save into a log file.
const WEEKS_KEPT := 8


func _week_row(key: String) -> Dictionary:
	if not weekly.has(key):
		weekly[key] = {"progress": {}, "paid": []}
	return weekly[key]


## How far along a metric is this week.
func weekly_progress(key: String, metric: String) -> int:
	var row: Dictionary = weekly.get(key, {})
	var p: Dictionary = row.get("progress", {})
	return int(p.get(metric, 0))


func weekly_paid(key: String, id: String) -> bool:
	var row: Dictionary = weekly.get(key, {})
	return (row.get("paid", []) as Array).has(id)


## This week's four, each with where the player has got to.
##
## Built by asking `Missions` for the set and the save for the numbers, rather
## than by storing the set — so retuning a target changes what an unfinished
## week is asking for, and a week already paid out stays paid.
func weekly_state(key: String) -> Array:
	var out: Array = []
	for m: Dictionary in Missions.for_week(key):
		var have := weekly_progress(key, String(m["metric"]))
		var target := int(m["target"])
		var row := m.duplicate()
		row["have"] = mini(have, target)
		row["done"] = have >= target
		row["paid"] = weekly_paid(key, String(m["id"]))
		out.append(row)
	return out


func weekly_done_count(key: String) -> int:
	var n := 0
	for m: Dictionary in weekly_state(key):
		if bool(m["done"]):
			n += 1
	return n


## Move a metric along, and pay for anything that just finished.
##
## `kind` decides how: a count adds, a peak takes the better of the two. The
## caller does not have to know which — it reports what happened and this works
## out what that means for the four jobs currently running.
##
## Returns the XP just paid, so the summary screen can say so.
func note_mission_progress(key: String, metric: String, amount: int) -> int:
	if amount <= 0:
		return 0
	var row := _week_row(key)
	var p: Dictionary = row["progress"]
	# A peak metric is reported as "this run reached N", a count as "N more
	# happened". Which one this metric is, is a property of the catalogue, so
	# it is read from there rather than passed in and possibly disagreed about.
	var peak := false
	for m: Dictionary in Missions.CATALOGUE:
		if String(m["metric"]) == metric:
			peak = String(m["kind"]) == "peak"
			break
	if peak:
		p[metric] = maxi(int(p.get(metric, 0)), amount)
	else:
		p[metric] = int(p.get(metric, 0)) + amount

	# Anything that just crossed its line gets paid once. `paid` is what makes
	# it once: without it, every subsequent word typed would pay for the same
	# finished mission again.
	var gained := 0
	var paid: Array = row["paid"]
	var before := weekly_cleared
	for m: Dictionary in weekly_state(key):
		if bool(m["done"]) and not paid.has(String(m["id"])):
			paid.append(String(m["id"]))
			gained += Missions.MISSION_XP
	if gained > 0:
		weekly_xp += gained
		if paid.size() >= Missions.PER_WEEK and before == weekly_cleared:
			weekly_cleared += 1
	return gained


## Fold a finished run into the week. One door for every mode, so a mode cannot
## be added that quietly counts for nothing.
##
## `what` is the mode's own contribution — a match reports `matches`, a daily
## reports `dailies`, survival reports `survivals` — on top of the numbers every
## mode produces.
func record_week(key: String, r: Dictionary, what: String) -> int:
	var gained := 0
	if what != "":
		gained += note_mission_progress(key, what, 1)
	gained += note_mission_progress(key, "words", int(r.get("words", 0)))
	gained += note_mission_progress(key, "salvos", int(r.get("salvos", 0)))
	gained += note_mission_progress(key, "multi_clears",
		int(r.get("multi_clears", 0)))
	if bool(r.get("won", false)):
		gained += note_mission_progress(key, "wins", 1)
	if bool(r.get("flawless", false)):
		gained += note_mission_progress(key, "flawless", 1)
	gained += note_mission_progress(key, "chain", int(r.get("chain", 0)))
	gained += note_mission_progress(key, "combo", int(r.get("combo", 0)))
	gained += note_mission_progress(key, "wpm", int(round(float(r.get("wpm", 0.0)))))
	gained += note_mission_progress(key, "score", int(r.get("score", 0)))
	gained += note_mission_progress(key, "longest",
		String(r.get("longest", "")).length())
	gained += note_mission_progress(key, "survive_seconds",
		int(r.get("seconds", 0.0)))
	_trim_weeks(key)
	save()
	changed.emit()
	return gained


## Drop weeks older than `WEEKS_KEPT`. Sorted as strings, which for ISO dates is
## the same as sorted by date — the one thing that format is for.
func _trim_weeks(current: String) -> void:
	if weekly.size() <= WEEKS_KEPT:
		return
	var keys: Array = weekly.keys()
	keys.sort()
	while keys.size() > WEEKS_KEPT:
		var oldest := String(keys[0])
		keys.remove_at(0)
		# Never the week being played, however the clock has been set.
		if oldest != current:
			weekly.erase(oldest)


const DAILY_KEPT := 60

## "YYYY-MM-DD" -> {"score", "wpm", "words", "chain"}.
var daily: Dictionary = {}
var daily_best := 0
## The longest run of consecutive days ever put together. Stored rather than
## counted, because the history it happened in gets trimmed away.
var daily_best_streak := 0


## Has today's run already been spent?
func daily_done(key: String) -> bool:
	return daily.has(key)


func daily_result(key: String) -> Dictionary:
	return daily.get(key, {})


## How many days in a row are behind you, as of `today`.
##
## Counted from the history every time it is asked for rather than kept as a
## number that `record_daily` increments. A stored streak is only ever corrected
## by playing, which is exactly the case it needs to be right about: miss three
## days and nothing runs, so the menu went on advertising a five-day streak that
## had been dead since Tuesday. The first thing it did on your return was
## congratulate you on a sixth consecutive day.
##
## A streak survives a day you have not played *yet* — today is still ahead of
## you until midnight — so the count starts at today if it is done and yesterday
## if it is not. Two missed days is a streak of nothing.
func daily_streak(today: String) -> int:
	var at := today
	if not daily.has(at):
		at = _day_before(at)
		if not daily.has(at):
			return 0
	var n := 0
	while daily.has(at) and n <= DAILY_KEPT:
		n += 1
		at = _day_before(at)
		if at == "":
			break
	return n


## Bank a finished run. Refuses to overwrite a day that already has one, so a
## crash, a rematch or a reload cannot buy a second attempt at the same board.
func record_daily(key: String, score: int, wpm: int, words: int, chain: int) -> void:
	if daily.has(key):
		return
	daily[key] = {"score": score, "wpm": wpm, "words": words, "chain": chain}
	daily_best = maxi(daily_best, score)
	# Read back out of the history this run has just joined, so the record and
	# the live count can never be two different opinions.
	daily_best_streak = maxi(daily_best_streak, daily_streak(key))
	# Trim, or a year of play turns the profile into a log file.
	_trim_daily()
	save()
	changed.emit()


# --------------------------------------------------------------- survival
#
# Two records rather than one, because the mode asks two different questions and
# the same run rarely answers both. Lasting is a matter of clearing what arrives
# and never getting greedy; scoring is a matter of holding chains together while
# the board fills up underneath them. A player who only ever saw "best score"
# would read survival as the daily with no clock, which is precisely what it is
# not.

## The longest run on file, in seconds, and the highest score any run has made.
var survival_best_time := 0.0
var survival_best_score := 0
## How many have been played through. XP is a pure function of the record, so
## this is what a survival run contributes to a level — see `XP["survival"]`.
var survival_runs := 0


## Bank a finished run, and say which records it took.
##
## Everything a run earned that is *comparable to a match* — words typed, the
## chain it reached, the powers it fired — goes into the same lifetime totals a
## match writes to, because they mean the same thing wherever they happened. What
## it deliberately does not touch is `matches` and `wins`: survival always ends
## in death, so counting it as a match would file every run ever played as a
## loss, and the win rate on the record screen would decay towards zero for
## somebody whose only crime was liking this mode.
func record_survival(r: Dictionary) -> Dictionary:
	survival_runs += 1
	var seconds := float(r.get("seconds", 0.0))
	var score := int(r.get("score", 0))
	var took := {
		"time": seconds > survival_best_time,
		"score": score > survival_best_score,
	}
	survival_best_time = maxf(survival_best_time, seconds)
	survival_best_score = maxi(survival_best_score, score)

	words += int(r.get("words", 0))
	chars += int(r.get("chars", 0))
	salvos += int(r.get("salvos", 0))
	multi_clears += int(r.get("multi_clears", 0))
	best_wpm = maxf(best_wpm, float(r.get("wpm", 0.0)))
	best_chain = maxi(best_chain, int(r.get("chain", 0)))
	best_combo = maxi(best_combo, int(r.get("combo", 0)))
	best_score = maxi(best_score, score)
	var lw := String(r.get("longest", ""))
	if lw.length() > longest_word.length():
		longest_word = lw
	for key in r.get("powers", {}):
		powers[key] = int(powers.get(key, 0)) + int(r["powers"][key])

	save()
	changed.emit()
	return took


## Every run on file, best first, for the leaderboard. Ties go to the older run:
## somebody matching a score they set last week has not beaten it.
##
## Each row is the stored result plus the `day` it belongs to, because the board
## needs to say *when* — a column of scores with no dates is not a history, and
## "today" has to be findable in it to be highlighted.
func daily_ranked() -> Array:
	var rows: Array = []
	for day: String in daily:
		var row: Dictionary = (daily[day] as Dictionary).duplicate()
		row["day"] = day
		rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["score"]) != int(b["score"]):
			return int(a["score"]) > int(b["score"])
		return String(a["day"]) < String(b["day"]))
	return rows


## Where a day sits on that board, 1-based, or 0 if it was never played.
func daily_rank(key: String) -> int:
	var rows := daily_ranked()
	for i in rows.size():
		if String(rows[i]["day"]) == key:
			return i + 1
	return 0


## The day before a "YYYY-MM-DD", by going through unix time so month and year
## ends are somebody else's problem.
func _day_before(key: String) -> String:
	var bits := key.split("-")
	if bits.size() != 3:
		return ""
	var t := Time.get_unix_time_from_datetime_dict({
		"year": int(bits[0]), "month": int(bits[1]), "day": int(bits[2]),
		"hour": 12, "minute": 0, "second": 0,
	})
	var d := Time.get_datetime_dict_from_unix_time(int(t) - 86400)
	return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]

## True when something is on disk that we could not read. Saving stays off while
## this is set, because a profile that cannot be parsed might still be one that
## can be rescued by hand.
var read_failed := false


func _ready() -> void:
	load_profile()


func backup_path() -> String:
	return save_path + ".bak"


func load_profile() -> void:
	read_failed = false
	var main := _read(save_path)
	if main == OK:
		return

	# The backup exists for exactly this: a half-written main file.
	if _read(backup_path()) == OK:
		push_warning("Profile: %s was unreadable; recovered from the backup" % save_path)
		save()
		return

	if main == ERR_FILE_NOT_FOUND:
		return  # A new player. Defaults are correct, and saving is safe.

	read_failed = true
	push_error(("Profile: %s exists but could not be read (%d), and neither could "
		+ "the backup. Saving is disabled this session so the file is left alone "
		+ "— move it somewhere safe if you want it looked at.") % [save_path, main])


## Reads a file into this object. Returns OK, ERR_FILE_NOT_FOUND for a new
## player, or whatever went wrong.
func _read(path: String) -> Error:
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err != OK:
		return err
	return _apply(cfg)


## The same bytes a save writes, for handing to somewhere that is not a disk.
##
## Deliberately the file format rather than a second, cloud-shaped encoding of
## the same numbers: two serialisers for one object is two places to forget a
## field, and the one that would get forgotten is the one nobody can see.
func to_bytes() -> PackedByteArray:
	return _encode().encode_to_text().to_utf8_buffer()


## Parse bytes written by `to_bytes` into this object, replacing everything.
##
## Meant for a *scratch* instance of this script rather than for the autoload —
## `Cloud` reads a downloaded save into one of these and merges it in, so the
## live profile is never overwritten by something that arrived over a network.
func from_bytes(data: PackedByteArray) -> bool:
	var cfg := ConfigFile.new()
	if cfg.parse(data.get_string_from_utf8()) != OK:
		return false
	return _apply(cfg) == OK


## Everything an already-parsed profile has to say, folded into this object.
func _apply(cfg: ConfigFile) -> Error:
	# Parsing is not the same as being a profile. ConfigFile shrugs at lines it
	# does not recognise, so a file full of rubbish loads "successfully" and then
	# every field falls back to its default — which is the silent reset again,
	# wearing a different hat. A real profile has always written this key.
	if not cfg.has_section_key("record", "matches"):
		return ERR_INVALID_DATA
	matches = int(cfg.get_value("record", "matches", 0))
	wins = int(cfg.get_value("record", "wins", 0))
	flawless = int(cfg.get_value("record", "flawless", 0))
	words = int(cfg.get_value("record", "words", 0))
	chars = int(cfg.get_value("record", "chars", 0))
	salvos = int(cfg.get_value("record", "salvos", 0))
	multi_clears = int(cfg.get_value("record", "multi_clears", 0))
	best_wpm = float(cfg.get_value("record", "best_wpm", 0.0))
	best_chain = int(cfg.get_value("record", "best_chain", 0))
	best_combo = int(cfg.get_value("record", "best_combo", 0))
	best_score = int(cfg.get_value("record", "best_score", 0))
	longest_word = String(cfg.get_value("record", "longest_word", ""))
	powers = cfg.get_value("record", "powers", {})
	owned = cfg.get_value("shop", "owned", {})
	since_ad = int(cfg.get_value("shop", "since_ad", 0))
	# Clamped rather than trusted. A hand-edited or older file could carry a gap
	# of six hundred, and the only symptom would be ads that never appear again.
	ad_gap = int(cfg.get_value("shop", "ad_gap", 0))
	if ad_gap < ADS_EVERY_MIN or ad_gap > ADS_EVERY_MAX:
		ad_gap = 0
	# Same clamp, same reason, on the budget that is measured in seconds. A file
	# from before survival existed has neither key, which reads as zero and rolls
	# a fresh pair on the first `ad_due` — there is nothing to migrate.
	play_since_ad = maxf(0.0, float(cfg.get_value("shop", "play_since_ad", 0.0)))
	ad_gap_seconds = float(cfg.get_value("shop", "ad_gap_seconds", 0.0))
	if ad_gap_seconds < ADS_MINUTES_MIN * 60.0 \
			or ad_gap_seconds > ADS_MINUTES_MAX * 60.0:
		ad_gap_seconds = 0.0
	survival_best_time = maxf(0.0, float(cfg.get_value("survival", "best_time", 0.0)))
	survival_best_score = maxi(0, int(cfg.get_value("survival", "best_score", 0)))
	survival_runs = maxi(0, int(cfg.get_value("survival", "runs", 0)))
	daily = cfg.get_value("daily", "runs", {})
	daily_best = int(cfg.get_value("daily", "best", 0))
	daily_best_streak = int(cfg.get_value("daily", "best_streak", 0))
	# Absent from every save written before the missions existed, and the
	# defaults are exactly right for those: no weeks on file, nothing paid out,
	# nothing cleared. No migration needed — an old save simply starts this
	# week from zero, which is what it should do.
	# Absent from every save written before the rewards existed, and an empty
	# list is exactly right for those: nobody has shared yet as far as this
	# ladder is concerned.
	share_days = cfg.get_value("share", "days", [])
	weekly = cfg.get_value("weekly", "runs", {})
	weekly_xp = int(cfg.get_value("weekly", "xp", 0))
	weekly_cleared = int(cfg.get_value("weekly", "cleared", 0))
	# Schema 2 and older kept the *live* streak here and had no record of the
	# best one. Read into the record: it is the only number in the old file that
	# says anything about a streak, and the alternative is telling somebody who
	# has played forty days running that their best is zero. `_migrate` decides
	# whether to keep it.
	_legacy_streak = int(cfg.get_value("daily", "streak", 0))
	equipped = cfg.get_value("worn", "equipped", {})
	prefs = cfg.get_value("worn", "prefs", {})
	# Last, so everything a migration might have to rewrite has been read first.
	# `equipped` in particular is loaded below `owned`, and dropping a pack means
	# taking off what was worn from it.
	_migrate(int(cfg.get_value("meta", "schema", 1)))
	return OK


## Bring an older file up to the current shape.
##
## Does not save. The next thing to write the profile stamps the new schema and
## the migration stops running; until then it re-runs on every launch, which is
## harmless because every step here has to be idempotent anyway — a half-applied
## migration and a twice-applied one are the same file.
func _migrate(from: int) -> void:
	if from >= SCHEMA:
		return

	# The premium pack used to be reachable from a two-tap test button in
	# Settings. Nobody ever paid for one, so every grant on disk is a tap
	# somebody made while looking at something else — and it silently switches
	# off the ad break, which is exactly how it was found.
	#
	# Written against `owned` directly rather than through `revoke`, which saves
	# and emits `changed` — neither is safe from inside a load, and the second
	# would repaint the board off a profile that is not finished reading itself.
	if from < 2 and owned.has(PACK_PREMIUM):
		owned.erase(PACK_PREMIUM)
		# And take off anything that was only wearable because of it, or a pack
		# that is gone stays on the screen until something re-equips.
		for slot: String in SLOTS:
			var id := String(equipped.get(slot, ""))
			if id != "" and not is_unlocked(slot, id):
				equipped.erase(slot)

	# The streak on an old file was the live one, which means it is a lower bound
	# on the best one and the only evidence the file has. Taken as the record if
	# it beats what the history can prove — a forty-day streak that has since
	# been trimmed out of `daily` is otherwise simply forgotten.
	if from < 3:
		daily_best_streak = maxi(daily_best_streak, _legacy_streak)
		for day: String in daily:
			daily_best_streak = maxi(daily_best_streak, daily_streak(day))


func save() -> void:
	if read_failed:
		return

	var cfg := _encode()

	# Written whole, somewhere else, before anything existing is touched.
	var tmp := save_path + ".tmp"
	if cfg.save(tmp) != OK:
		push_error("Profile: could not write %s — leaving the old save alone" % tmp)
		return

	var dir := DirAccess.open(save_path.get_base_dir())
	if dir == null:
		return
	var main := save_path.get_file()
	var back := backup_path().get_file()
	if dir.file_exists(main):
		dir.remove(back)
		dir.rename(main, back)
	dir.rename(tmp.get_file(), main)


## This object as a `ConfigFile`. What `save` writes and what `to_bytes` sends.
func _encode() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "schema", SCHEMA)
	cfg.set_value("record", "matches", matches)
	cfg.set_value("record", "wins", wins)
	cfg.set_value("record", "flawless", flawless)
	cfg.set_value("record", "words", words)
	cfg.set_value("record", "chars", chars)
	cfg.set_value("record", "salvos", salvos)
	cfg.set_value("record", "multi_clears", multi_clears)
	cfg.set_value("record", "best_wpm", best_wpm)
	cfg.set_value("record", "best_chain", best_chain)
	cfg.set_value("record", "best_combo", best_combo)
	cfg.set_value("record", "best_score", best_score)
	cfg.set_value("record", "longest_word", longest_word)
	cfg.set_value("record", "powers", powers)
	cfg.set_value("shop", "owned", owned)
	cfg.set_value("shop", "since_ad", since_ad)
	cfg.set_value("shop", "ad_gap", ad_gap)
	cfg.set_value("shop", "play_since_ad", play_since_ad)
	cfg.set_value("shop", "ad_gap_seconds", ad_gap_seconds)
	cfg.set_value("survival", "best_time", survival_best_time)
	cfg.set_value("survival", "best_score", survival_best_score)
	cfg.set_value("survival", "runs", survival_runs)
	cfg.set_value("daily", "runs", daily)
	cfg.set_value("daily", "best", daily_best)
	cfg.set_value("daily", "best_streak", daily_best_streak)
	cfg.set_value("share", "days", share_days)
	cfg.set_value("weekly", "runs", weekly)
	cfg.set_value("weekly", "xp", weekly_xp)
	cfg.set_value("weekly", "cleared", weekly_cleared)
	cfg.set_value("worn", "equipped", equipped)
	cfg.set_value("worn", "prefs", prefs)
	return cfg


# ------------------------------------------------------------------- merging
#
# Folding one profile into another, which is what a cloud save actually is once
# a player owns two devices.
#
# ## Why the totals are maxed rather than added
#
# Adding is the obvious answer and it is wrong. The two profiles are not two
# disjoint histories, they are two views of the *same* history that have
# diverged: nearly every match in the cloud copy is also in the local one, so
# adding them counts almost everything twice, and the number climbs every time
# the game is opened. A player who plays on one device would watch their match
# count double each launch.
#
# Max is the conservative alternative and it has one real cost: play forty
# matches on the phone while the tablet plays ten, and the merge keeps forty
# rather than fifty. Ten matches of credit is a genuine loss. It is also the
# *only* loss, it is bounded by how far the two ran apart, and it never invents
# progress that did not happen. Every other option either double-counts or needs
# per-device bookkeeping this game has no reason to carry.
#
# So the rule everywhere below is: nothing here can ever move a number down.
# A merge only adds.

## Lifetime counters. Not "how many times has this happened on this device", so
## the larger of the two is the better answer.
const MERGE_MAX_INT := ["matches", "wins", "flawless", "words", "chars",
	"salvos", "multi_clears", "best_chain", "best_combo", "best_score",
	"survival_runs", "survival_best_score", "daily_best", "daily_best_streak"]

const MERGE_MAX_FLOAT := ["best_wpm", "survival_best_time"]


## Fold `other` into this profile, and say whether anything was gained.
##
## Does not save, and does not emit `changed`. `Cloud` folds in several copies at
## once when a conflict has stacked up, and a save between each would write the
## file three times and repaint the screen off a half-merged record. Call
## `commit_merge` after the last one.
##
## Deliberately not symmetric in what it *keeps*, only in what it takes: run it
## the other way round afterwards and the return value tells you whether the
## other copy is behind and worth writing to.
func merge_from(other: Node) -> bool:
	var gained := false

	for f: String in MERGE_MAX_INT:
		var theirs := int(other.get(f))
		if theirs > int(get(f)):
			set(f, theirs)
			gained = true
	for f: String in MERGE_MAX_FLOAT:
		var theirs := float(other.get(f))
		if theirs > float(get(f)):
			set(f, theirs)
			gained = true

	# Longest by letters, not alphabetically. A tie keeps ours: two words of the
	# same length are the same claim, and rewriting it is a change for nothing.
	if String(other.longest_word).length() > longest_word.length():
		longest_word = String(other.longest_word)
		gained = true

	# Per power word, for the same reason as the totals above.
	for key: String in other.powers:
		var theirs := int(other.powers[key])
		if theirs > int(powers.get(key, 0)):
			powers[key] = theirs
			gained = true

	# Purchases are a union. A pack is owned forever and on every device, so
	# there is no case where the right answer is to drop one — and Apple's own
	# entitlement check will hand it back anyway.
	for pack: String in other.owned:
		if bool(other.owned[pack]) and not owns(pack):
			owned[pack] = true
			gained = true

	# One run per day is the rule, but two devices can each believe they are the
	# one holding today's, so a day present on both keeps the better score.
	var days_changed := false
	for day: String in other.daily:
		var theirs: Dictionary = other.daily[day]
		if not daily.has(day):
			daily[day] = theirs.duplicate()
			days_changed = true
		elif int(theirs.get("score", 0)) > int((daily[day] as Dictionary).get("score", 0)):
			daily[day] = theirs.duplicate()
			days_changed = true
	if days_changed:
		gained = true
		# The union can run past the window, and the trim has to happen here as
		# well as in `record_daily` or a merge is a way to grow the file forever.
		_trim_daily()
		# The best streak is proved out of the history, and the history just
		# grew: two devices each holding half of a run of days is exactly the
		# case where neither copy's stored number is the truth.
		#
		# Only when days actually arrived. Recomputing unconditionally would
		# quietly *correct* a profile whose stored streak was behind its own
		# history — which sounds like a favour, but it makes an otherwise
		# empty merge report a gain, and a gain is what triggers an upload. The
		# cost would be a network write on every launch, forever, for nothing.
		for day: String in daily:
			daily_best_streak = maxi(daily_best_streak, daily_streak(day))

	# What is worn, filled in rather than overwritten.
	#
	# There is no clock in any of this on purpose — device clocks disagree, and a
	# "newest wins" rule decided by an unset phone would silently undress
	# somebody. Empty slots take the other copy's answer, which restores a whole
	# loadout onto a fresh install, and a slot that already has something keeps
	# it, so changing your hat is never undone by a sync.
	for slot: String in SLOTS:
		if String(equipped.get(slot, "")) == "" and String(other.equipped.get(slot, "")) != "":
			equipped[slot] = other.equipped[slot]
			gained = true

	# Settings, same rule and the same reason. A fresh install picks the whole
	# lot up — including `taught`, so the tutorial does not nag somebody who
	# finished it on their old phone — and a setting deliberately changed here is
	# never argued with by the other device.
	for key: String in other.prefs:
		if not prefs.has(key):
			prefs[key] = other.prefs[key]
			gained = true

	# Not merged, on purpose: `since_ad`, `play_since_ad` and the two gaps.
	#
	# They are a cadence, not a record — how much play has happened since the
	# last break — and maxing them would mean a sync could bring an ad break
	# forward, which is the one thing in this file a player would notice and
	# resent. A restored profile starts its cadence fresh, which errs towards
	# fewer breaks, which is the right way to be wrong.

	return gained


## Land a merge: write it, and tell the screen. Separate from `merge_from` so
## several copies can be folded in before either happens.
func commit_merge() -> void:
	save()
	changed.emit()


func _trim_daily() -> void:
	if daily.size() <= DAILY_KEPT:
		return
	var keys: Array = daily.keys()
	keys.sort()
	while keys.size() > DAILY_KEPT:
		daily.erase(keys.pop_front())


## The name to show alongside yours, or "" if none is worn.
func title_text() -> String:
	var id := worn("title")
	if id == "" or id == "none":
		return ""
	return String(entry("title", id).get("name", ""))
