# Game Center setup

Everything the game submits to Apple, and what has to exist in App Store Connect
for it to land. The ids below are not suggestions — they are compiled into the
build, and Apple rejects a submission to an id that does not exist.

Source of truth: `scripts/achievements.gd` (`AWARDS`, `PREFIX`) and
`scripts/leaderboards.gd` (`DAILY_ID`, `SURVIVAL_ID`).

Nothing here can break the game. Every failure path is silent and local — a
missing leaderboard costs a rank row on the summary, a missing achievement is
refused and logged. The game plays identically either way, which is also why
none of this announces itself when it is wrong. See **Checking it worked**.

## Where it lives

App Store Connect → **My Apps** → Word Wars → the **Game Center** section
(under Services, or on the app's General page depending on the ASC revision).
Leaderboards and Achievements are configured at the *app* level, not per
version.

New entries work in the **sandbox immediately** — a TestFlight or development
build signed with your account will submit to them right away, so you can verify
all of this before shipping. They go public with the next released version.

---

## 1. The survival leaderboard

| Field | Value |
| --- | --- |
| **Leaderboard ID** | `com.damonj.wordwars.survival` |
| Type | **Classic** (not recurring) |
| Reference Name | `Survival — Best Score` |
| Score Format Type | **Integer** |
| Sort Order | **High to Low** |
| Score Range | leave empty |
| Localisation | English, Display Name `Survival` |

The game submits the score from a finished survival run, best-of held if you are
signed out at the time (`Boards.submit_survival`). It never reads a rank back —
no screen shows one yet — so a display name and the id are the whole of it.

## 2. The daily leaderboard

Set this up too if it is not already there. `leaderboards.gd` still carries a
comment saying it may not be, and the daily summary silently drops its two rank
rows when it is missing, which looks exactly like a device with no Game Center
account.

| Field | Value |
| --- | --- |
| **Leaderboard ID** | `com.damonj.wordwars.daily` |
| Type | **Classic** |
| Score Format Type | **Integer** |
| Sort Order | **High to Low** |

**Classic, not recurring, and that is deliberate.** A classic board keeps every
score forever and GameKit filters it to `TODAY` for us, which is exactly the
daily's ranking at no configuration cost. A recurring board would also work but
its occurrences have to line up with local midnight, and the daily's midnight is
the *player's* — there is no one schedule that matches.

---

## 3. Achievements

Seventeen of them. Every id is `com.damonj.wordwars.ach.` + the suffix below —
the `.ach.` segment is part of it and is the easiest thing to drop.

For all seventeen: **Achievable More Than Once = No**, **Hidden = No**. The game
reports *progress* (`percent_complete`), so Apple shows a progress banner as
each one fills; hiding them would waste that.

Points must total 1000 across the app. The column below is exactly 1000 — if you
change one, take it from another.

| ID suffix | Title | Points | Pre-earned description | Earned description |
| --- | --- | --: | --- | --- |
| `first_win` | First Win | 10 | Win a match. | You won your first match. |
| `ten_matches` | Getting Started | 15 | Play 10 matches. | Ten matches played. |
| `four_at_once` | Four at Once | 25 | Break four blocks with a single word. | Four blocks, one word. |
| `flawless` | No Looking Back | 40 | Win a match without losing a life. | You won without losing a life. |
| `six_hundred_words` | Dictionary | 50 | Type 600 words. | Six hundred words typed. |
| `wordsmith` | Wordsmith | 50 | Play a 12-letter word. | Twelve letters, one word. |
| `speed_demon` | Speed Demon | 60 | Reach 65 words per minute. | Sixty-five words a minute. |
| `chainbreaker` | Chainbreaker | 60 | Reach a x8 chain. | Eight in a row, no mistakes. |
| `salvo_king` | Salvo King | 60 | Land 12 salvos. | Twelve salvos landed. |
| `fifteen_wins` | Undefeated | 60 | Win 15 matches. | Fifteen wins. |
| `ice_water` | Ice Water | 60 | Earn 10 CLUTCH power words — clear a block with one row of headroom left. | Ten times one row from the top. |
| `level_ten` | Level 10 | 75 | Reach level 10. | Level 10. |
| `perfectionist` | Perfectionist | 75 | Earn 25 PERFECT power words — break three at once without dropping your run. | Twenty-five perfect breaks. |
| `counterpuncher` | Counterpuncher | 75 | Earn 30 COUNTER power words — shoot down an attack already inbound. | Thirty attacks sent back. |
| `flawless_three` | Untouchable | 75 | Win three matches without losing a life. | Three flawless wins. |
| `hundred_matches` | Centurion | 100 | Play 100 matches. | One hundred matches. |
| `level_sixteen` | Level 16 | 110 | Reach level 16. | Level 16. |

Titles are the cosmetic names wherever one exists — `Centurion`, `Undefeated`,
`Dictionary`, `Chainbreaker`, `Salvo King`, `Ice Water` and the rest are the same
strings the mastery screen shows, so an achievement and the thing it unlocks
read as one reward rather than two.

### The images

**App Store Connect requires an image on every achievement** — 512×512, no
alpha, sRGB. Seventeen of them, and it is the bulk of the work here; the text
above is twenty minutes of typing and the art is not.

#### The palette, out of the code

Everything below is what the game actually draws with, so an icon built from it
sits next to the app rather than beside it.

| Role | Values |
| --- | --- |
| Backgrounds (`THEMES`, `cosmetics.gd`) | `#0b1020` `#141a36` · `#170a09` `#2f1611` · `#07150f` `#0f2a1d` · `#140a1f` `#291340` · `#11100c` `#262019` · `#04030c` `#160a33` |
| Boot splash | `#01061a` |
| **Block tiers** (`TIER_COLORS`, `board.gd`) | `#5390d9` `#48bfe3` `#64dfdf` `#f9c74f` `#f8961e` `#f94144` |
| Power words (`POWERS`, `game.gd`) | COUNTER `#7bdff2` · COMBO `#ffd166` · CLUTCH `#90be6d` · PERFECT `#c77dff` |

Every theme is near-black. An icon set on a light ground will read as somebody
else's app, which is the single biggest thing separating a native-looking sheet
from a stock one.

#### An idea worth stealing: let the tier colour carry the difficulty

`TIER_COLORS` runs blue → teal → yellow → orange → red, and in the game that
ramp already *means* something: a block's colour is its weight, and red is the
one that ends runs. Players learn it in the first match without being told.

Spending the same ramp on achievement difficulty gets that reading for free —
somebody scanning the Game Center grid sees at a glance which ones are the hard
ones, in a code they already know. It lines up with the point values almost
exactly:

| Points | Tier colour | Achievements |
| --: | --- | --- |
| 10–25 | `#5390d9` | first_win, ten_matches, four_at_once |
| 40–50 | `#48bfe3` | flawless, six_hundred_words, wordsmith |
| 60 | `#64dfdf` | speed_demon, chainbreaker, salvo_king, fifteen_wins, ice_water |
| 75 | `#f9c74f` | level_ten, perfectionist, counterpuncher, flawless_three |
| 100 | `#f8961e` | hundred_matches |
| 110 | `#f94144` | level_sixteen |

#### What each one has to say

Every achievement here is a **threshold**, and an icon that states its threshold
does the job an icon that gestures at a mood does not. Put the number on
anything that has one — the strongest icons in any draft are the ones carrying
their target.

| ID suffix | Must be legible at a glance |
| --- | --- |
| `first_win` | Your first win. The only one with no number worth showing. |
| `ten_matches` | **10** matches played — not a finish line, a count. |
| `four_at_once` | **4** blocks broken by one word. |
| `flawless` | A win with no life lost. Not combat — the game has no swords. |
| `six_hundred_words` | **600** words typed. No lettering that reads as real text. |
| `wordsmith` | A **12**-letter word. Letters, not stationery. |
| `speed_demon` | **65** wpm. |
| `chainbreaker` | A **x8** chain, unbroken. |
| `salvo_king` | **12** salvos landed — a barrage arriving. |
| `fifteen_wins` | **15** wins. |
| `ice_water` | **10** CLUTCH — one row of headroom left, garbage slowed. |
| `level_ten` | Level **10**. |
| `perfectionist` | **25** PERFECT — three at once without dropping the run. |
| `counterpuncher` | **30** COUNTER — an attack sent back the way it came. |
| `flawless_three` | **3** flawless wins. Square, like the rest. |
| `hundred_matches` | **100** matches. "Centurion" is the title it unlocks. |
| `level_sixteen` | Level **16**. |

The titles above are the cosmetic names, so `Centurion`, `Ice Water`,
`Chainbreaker` and the others already have a look on the mastery screen worth
being consistent with.

---

## Checking it worked

None of this reports success, so verify it by the absence of complaints. With
the phone attached:

```bash
idevicesyslog -p WordWars | grep --line-buffered "\[Awards\]\|\[Boards\]\|Cloud"
```

Then launch the game and play one match. What you are looking for:

| Line | Meaning |
| --- | --- |
| *(nothing from `[Awards]`)* | Every achievement id resolved. This is success. |
| `[Awards] report refused: …` | At least one id does not exist in ASC, or is misspelled. Apple refuses the whole batch, so one bad id hides the other sixteen. |
| `Boards: no survival leaderboard com.damonj.wordwars.survival` | The leaderboard id is missing or misspelled. |
| `[Boards] survival submit refused: …` | The board exists but Apple rejected the score. |

`achievements.gd` clears its `_sent` cache on a refusal and retries on the next
profile change, so fixing an id in ASC takes effect on the next match without a
rebuild.

To see them as a player does, open the Game Center dashboard from the OS — the
game has no achievements screen of its own, by design. The mastery screen is the
game's own record and does not need Apple to be reachable.
