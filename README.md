# Word Wars

A competitive typing puzzler with a Puyo Puyo pulse. You and a rival — the CPU,
or another player over the network — each have a board. Every word you type
stamps its **last** letters onto a block and drops it on the other side. To clear a block, you have to type a word that
*starts* with the letters stamped on it — your endings become their beginnings,
and the bigger the block, the more letters you have to match.

`FRIENDSHIP` brands a block **SHIP**. Answer it with `SHIPMENTS` and that brands
one **MENT**. Answer *that* with `MENTIONING` and back comes **ING**. The duel is
a word chain where every link is also an attack.

How *big* the block is has nothing to do with the word. It comes from rhythm:
keep firing without breaking your chain and the hits climb, up to a 4x3 that
wants nine clean words in a row. Miss once — a pause, or a word that does not
qualify — and you start again from nothing.

Godot 4.7, GDScript. Vendors two small MIT addons for networking.

**[Download a build](https://github.com/DamonDJr/word-wars/releases/latest)** —
Windows and Linux, one self-contained executable each.

## Running it

Open the folder in Godot 4.7 and press F5, or from a terminal:

```bash
godot --path "$(pwd)"
```

Pick a difficulty by clicking a card or pressing `1` / `2` / `3`, or `V` for
versus. Every match opens with a shared 3-2-1 before anyone can type. Type letters,
fire with `Space` or `Enter`. `Backspace` deletes, `Ctrl+Backspace` or `Esc`
clears the line. `H` on the title screen shows the full rules, `R` rematches after a game. `F1` mutes — it is
not a letter key, because every letter is spoken for.

## Building for other people

```bash
tools/build.sh
```

Produces `build/WordWars-linux-x86_64.zip` and `build/WordWars-windows-x86_64.zip`,
each a single self-contained executable plus a short readme. Needs Godot 4.7 on
`PATH` with export templates installed.

Two things in `export_presets.cfg` are load-bearing. `include_filter` names
`data/*.txt` explicitly, because the word lists are plain text rather than
imported resources and Godot leaves them out otherwise — the build would start
and then have no dictionary at all. `embed_pck` bundles everything into the
executable so there is one file to send rather than an exe plus a `.pck` that has
to stay beside it. The build script proves the dictionary shipped by booting the
Linux binary and checking the word count, instead of assuming.

The Windows build is not code-signed, so SmartScreen will warn about an unknown
publisher.

## Up to four boards

`F` on the title starts a free-for-all against three CPUs; Versus seats up to
four humans in one room. Yours is drawn full size on the left, rivals shrink into
a row on the right — same board, scaled by the node transform, so every effect
and label keeps working on them.

**You choose who you are hitting.** `TAB` cycles your aim (shift-TAB goes back),
`1`/`2`/`3` pick a board outright, and clicking one aims at it. The board you are
pointed at gets a pulsing ring and an arrow, and the centre column names it. Bots
wander their own aim every few seconds, so a four-way does not turn into three
guns pointed at you.

Running out of lives knocks you out rather than ending the match — the rest play
on, and the last board standing wins. Aim retargets itself automatically when
whoever you were hitting drops out.

A duel still looks exactly like it did: two full-size boards facing each other,
no aim marker, because with one rival there is nothing to choose between.

Over the network, each peer renders itself as board 0 and sorts everyone else
into the rival slots by peer id, so all four clients agree on who is board 1
without anyone being told. Attacks are addressed to a peer rather than a slot.

## How a turn resolves

Type a valid word and hit fire. In order:

1. **Clearing.** Blocks on your board whose stamp opens your word are destroyed,
   up to how far the word reaches. Everything above them falls.
2. **Interception.** If the word has reach left over, blocks still inbound at you
   whose stamp opens it are shot down before they ever land, soonest first.
3. **Tier.** How far your chain has climbed sets the size of the hit, and every
   block removed in steps 1 and 2 pushes it up further.
4. **Attack.** The whole hit goes out, stamped with the closing letters of the
   word you just played. Nothing is held back to defend with.

### Lives

Filling your board to the ceiling does **not** end the match. It costs one of
three lives, blows the whole board apart and hands it back empty, with a couple
of seconds of respite before anything lands again.

What does not reset is the ambient pressure clock, which keeps climbing across
lives — so the board you get back for your third life is played under conditions
the first never saw. Run out of lives and you lose.

Lives show as pips above each board; the last one pulses.

### Letters are the only defence

Garbage is removed by **answering its letters and nothing else**. There is no
cancelling attack power against an incoming block — firing a big word at a
rival does not shrink what is falling on you. If you want the block gone, you
open a word with its stamp, whether it has landed or is still in the queue.

### Reach

One word does not wipe every block it matches. It takes out **one block per two
letters**, so against four blocks all stamped `AL`:

| Word | Letters | Reach | Blocks removed |
|:-----|--------:|------:|---------------:|
| `ALL` | 3 | 1 | 1 |
| `ALARM` | 5 | 2 | 2 |
| `ALIGNMENT` | 9 | 4 | 4 |

Landed blocks are consumed first, hardest stamp first and then whichever sits
highest, since that is the one crowding your ceiling. Only leftover reach goes to
the queue. The HUD shows this as you type: only the blocks the word can actually
take are highlighted, and the readout says `takes out 2 of 4 — a longer word
reaches further` when your word falls short.

`WWBoard.reach()` is the single definition, used by the board, the HUD and the
CPU's word choice alike — the CPU scores a candidate by what it would really
clear, not by everything it merely opens.

### The chain

Keep landing words without pausing and your hits grow. The early steps come fast
so a short run still pays; the top of the ladder has to be earned.

| Tier | Shape | Cells | Chain needed |
|-----:|:------|------:|-------------:|
| 1 | 1x1 | 1 | 1 |
| 2 | 2x1 | 2 | 2 |
| 3 | 2x2 | 4 | 3 |
| 4 | 3x2 | 6 | 5 |
| 5 | 3x3 | 9 | 7 |
| 6 | 4x3 | 12 | 9 |

Clearing blocks stacks on top, so a word that wipes two blocks mid-chain jumps
two extra tiers. That is the shortcut to a 4x3 without grinding out nine words.

**A tenth word detonates the run.** Past the top of the ladder the chain does not
keep paying out a 4x3 forever — one flawless run would simply end the match. The
tenth word instead fires a **salvo**: ten single cells, staggered so they rain in
one after another, and your chain drops to nothing.

That trade is the point. A 4x3 is twelve cells in one tidy slab that a single
word removes. A salvo is the same weight scattered across ten separate stamps
that land in the gaps around whatever is already there, packing the stack upward
unevenly. Individually trivial; collectively a mess. Stamps within one salvo vary
(the recent-stamp memory applies inside the burst too) but do repeat, which is
the defender's counter — one good word can take several out at once.

A salvo is pure offence — like every other attack it does nothing about what is
falling on you.

**A run ends the moment you break it.** Pausing past the window drops you to
nothing, and so does firing anything that does not qualify — too short, not a
word, or one you have already spent. The longer your run, the more expensive a
wild guess becomes. Firing an empty line is treated as a slip and costs nothing.

The CPU plays by the same rule: its fumbles (see `typo` in the difficulty table)
break its chain exactly the way a rejected word breaks yours.

Each word buys the time for the next one: `CHAIN_BASE` (1.8s) plus
`CHAIN_PER_CHAR` (0.2s) per letter. A three-letter word grants 2.4 seconds, a
ten-letter word 3.8. That is deliberate — long words take longer to type, so they
earn proportionally more time, but they buy no extra block size. **Word length
does not size the block.** Nothing about how big a hit lands depends on
vocabulary, only on rhythm.

The meter under each board shows it: one segment per tier, lit up to what your
run has earned, the next segment filling gradually as you close on it, and a thin
bar underneath draining with your window.

Both sides play by these rules. The CPU's natural gap between words — reaction
plus typing time — sits right around the window, so it chains sometimes but not
reliably. Out-typing it is the whole point.

### Why stamps are the length they are

Stamp length is **independent of block size**. Every block, from a 1x1 to a 4x3,
aims for the same `STAMP_WANT` (4) letters and takes whatever the word's tail can
fairly support — so a 1x1 can carry `SHIP` and a 4x3 can carry `AP`. Size is
earned by rhythm; difficulty of the answer is a separate axis.

Word *endings* make terrible word *beginnings*, so a stamp has to be a tail both
sides can actually answer. `WordBank.stamp_from_tail` collects every candidate
with at least `STAMP_MIN_VALID` (40) answers in the full dictionary and
`STAMP_MIN_COMMON` (6) in the common list, then picks one at random weighted by
length squared.

That weighting is deliberate. Taking the *longest* answerable tail every single
time is correct in isolation and miserable in practice — it turned every board
into a wall of `ING`, `ED` and `LY`, because those are simply the most common
ways English words end. Longer stamps stay favoured; they just no longer win
automatically.

Four rules keep it honest:

- **Single letters must be genuinely easy.** Dropping to one letter is the
  merciful end of the search, so that letter needs 30 common answers. Only `X`
  fails; without this, `FIX` would brand a block `X` and nobody could answer it.
- **Near-tail windows widen the pool.** `RUNNING` has exactly one answerable
  suffix — `ING` — and a pool of one cannot be varied no matter how you weight
  it. So windows sitting one or two letters off the end join the pool. This is
  also what rescues `SHIPMENTS`, whose only true suffix is a toothless `S`, into
  `MENT`.
- **Those windows never touch the front.** Otherwise `MUSIC` brands a block `MUS`
  and the whole "your endings become their beginnings" idea falls apart. Words of
  four letters or fewer are exempt — a three-letter word has no middle — which is
  what lets `FIX` become `FI`.
- **Recent stamps go stale.** The last `RECENT_STAMP_MEMORY` (8) stamps thrown by
  either side, plus everything already on the defender's board, are discounted to
  15%, so the same block does not land twice in a row.

Measured over 4000 attacks, no stamp exceeds 2.6% of the total and 900+ distinct
stamps appear; before the weighting, `ING` and `ED` alone took 6.7% each. Average
length is 2.5 letters. Re-measure any time:

```bash
godot --headless --script res://tools/selftest.gd
```

Both boards also get seeded with a small block on a timer that speeds up as the
match runs, so a stalemate is not an option.

## Layout

```
project.godot            autoloads WordBank, 1280x720, gl_compatibility
scenes/main.tscn         one Node2D running scripts/game.gd
scripts/game.gd          match flow, attack resolution, all HUD drawing
scripts/board.gd         WWBoard — grid, rectangle gravity, block rendering
scripts/ai_opponent.gd   CPU word choice and its wpm-paced "typing"
scripts/word_bank.gd     autoload; word lists, prefix index, fairness lookups
scripts/audio.gd         autoload; synthesises the whole sound bank at startup
data/words.txt           ~350k words, sorted — what counts as valid input
data/common.txt          ~36k frequency-ordered words — CPU vocabulary
tools/build_wordlists.py regenerates both data files from source corpora
tools/selftest.gd        headless check of stamp fairness and length spread
tools/audiocheck.gd      dumps the sound bank to .wav and verifies playback
```

Boards are drawn with `_draw()` and `StyleBoxFlat` rather than a scene tree of
sprites, so tuning the look means editing `board.gd`, not clicking through the
inspector.

### The two word lists

`words.txt` is deliberately permissive — if you know an obscure word, you should
be rewarded for it. It is stored sorted, so `WordBank` answers "how many words
start with these letters?" with a pair of binary searches instead of a 350k-entry
index.

`common.txt` is the curated one, and it does two jobs: it is everything the CPU
knows, and it is the second half of the fairness test. A stamp needs enough
answers that *exist* (measured against `words.txt`) and enough that a person
would actually reach for (measured against `common.txt`) — `DING` passes on 42
and 9, while `NESS` fails on 12 and 1.

It is scrubbed of what rides along in a subtitle frequency corpus, because a CPU
that plays `OOOO` reads as a bug: repeated-letter noise, vowel-less fragments,
interjections, most given names, spoken-register spellings (`gonna`, `wanna`),
and contraction fragments. That last group matters most — the corpus strips
apostrophes, so `didn` sat at rank 70 and `gonna` at 63, right where the CPU
looks.

Regenerate both (needs network):

```bash
python3 tools/build_wordlists.py
```

## Versus — two players over a network

`V` on the title screen opens the lobby. Set your name (it is remembered), pick a
backend, then **host** or **join**. Once both players are in the room they each
**ready up**; the match only starts when both have. `127.0.0.1` plays a second
window on the same machine, which is how the mode is tested.

After a match, Rematch puts both players back in the room to ready up again
rather than restarting on one player's say-so.

### How it is put together

The connection, the lobby protocol and every packet live in the `Link` autoload
(`scripts/net_link.gd`). `game.gd` talks to `Link` and never touches a peer.

The architecture is deliberately lopsided, because a word game does not need
lockstep:

- **Each peer owns its own board outright.** Nothing about your board is decided
  anywhere but on your machine.
- **Attacks travel as events** — "I played WORD for a tier-3 hit" — sent
  reliably. Crucially the **defender** mints the stamp, not the attacker: only
  the defender knows what is already on their board, which is what keeps the
  recent-stamp memory working and the stamps varied.
- **Boards travel as plain state at 15 Hz**, unreliably, purely so each player
  can watch the other half of the screen. A dropped packet costs one frame of
  cosmetics. `WWBoard.mirror_blocks()` reuses matching block objects so the
  mirror keeps its falling motion, and shatters whatever vanished — a rival's
  clear reads as a clear on your screen too.
- **The host calls the tempo** for ambient pressure. Both peers run the clock so
  both HUDs agree, but only the host decides when it fires.

Two timeouts exist because the defaults strand people. ENet waits the better part
of a minute before calling a silent peer dead, so the peer timeout is tightened
to a few seconds and a rival who quits or crashes forfeits. ENet also retries a
dead address for a long time, so a join gives up after `JOIN_TIMEOUT` (8s) and
says so rather than showing "connecting" forever.

### Room codes, and why not Epic

Joining is by **room code**, not IP. The host clicks Host, gets a code, and the
challenger pastes it in — nobody types an address and nobody forwards a port.

That runs on [netfox.noray][noray], vendored into `addons/` along with its one
dependency, `netfox.internals`. Both are MIT and pure GDScript — no compiled
GDExtension, so nothing to break when Godot updates. A noray server hands each
host a code, then brokers a UDP punchthrough between the two players, falling
back to relaying through itself when their networks refuse to cooperate. The
result is an ordinary `ENetMultiplayerPeer`, so nothing downstream changed.

`NORAY_HOST` in `net_link.gd` points at foxssake's public server, which is fine
for testing. [Run your own][norayserver] before shipping.

**Epic was the wrong tool here.** EOS lobbies are not reachable from a game
client without the SDK — the Lobby Interface needs a handle from the Platform
Interface, and the Lobby Web API authenticates with `client_credentials`, a
server-side secret that must not ship inside a client. Doing it properly would
have meant a backend you host, purely to hand out codes. noray does that job with
no accounts, no credentials and no infrastructure, and solves NAT as well. If you
later want Epic accounts, friends or achievements, that is a separate feature
from the transport and can sit alongside this.

`DIRECT` mode is still there for a LAN or a forwarded port, and needs no third
party at all.

[noray]: https://github.com/foxssake/netfox/tree/main/addons/netfox.noray
[norayserver]: https://github.com/foxssake/noray

## Feel

Everything that happens to a block throws debris, all of it in `board.gd`:

- **Shattering.** A cleared block breaks into quarter-cell shards thrown outward
  from its middle, each tumbling under gravity, plus a spray of sparks, a
  shockwave ring, and its stamp drifting up as a ghost. A 4x3 produces 48 shards.
- **Impact.** Landing throws dust along the block's underside and sparks
  skittering off the surface, with a shockwave sized by the block.
- **Motion.** Blocks squash on impact proportional to how hard they hit, and
  trail a streak while falling fast so a drop reads as speed.
- **Shake.** Each board jolts on its own, and `game.gd` shakes the *whole scene*
  when a 2x2 or larger lands — scaled by tier, so a 1x1 tapping down does not
  rattle the room. The background is drawn `SHAKE_MARGIN` past the viewport so
  the edges never show, and the menus counter-offset so they hold still.
- **Bloom.** A tier-5 landing or a 2+ combo washes the screen in its colour.

Particle count is capped at `MAX_BITS` (900) — a big combo can ask for a lot at
once.

## The menus

The title screen shows three worked examples instead of a wall of instructions,
each drawn with the same routines the playfield uses: `FRIENDSHIP` splitting into
a branded `SHIP` block, that block coming apart under `SHIPMENTS`, and a live
chain meter with escalating block sizes. The full rules are still one keypress
away on `H`. Blocks drift down behind it all.

Menus are mouse-driven: hover lifts a card and brightens its border, clicking
starts the match. `_menu_buttons()` is the single source for both drawing and
hit-testing, so the two can never disagree about where a button is. Hit-testing
uses `get_viewport().get_mouse_position()`, which is in the stretched 1280x720
space and therefore immune to the shake transform.

The end-of-match screen breaks the result into stat tiles — time, words, blocks
cleared, best chain, best combo, salvos — with Rematch and Title as clickable
buttons.

Reaching chain nine swaps the status line for a pulsing `NEXT HIT IS A SALVO`,
and firing it whites out the chain meter before it empties. A payoff that big
should not arrive unannounced.

## Audio

There are no sound files in this project. Every effect is synthesised in
`scripts/audio.gd` at startup — a pitch glide blending sine, square and noise
under an exponential decay, plus an arpeggiator for the match jingles.

That is not just to avoid binary assets. These sounds need to be
*parameterised*: firing pitches up with your chain, clears pitch up with your
combo, and garbage thuds lower and louder the bigger the block. Baking that in
would mean a dozen near-identical files; one waveform per event driven by
`pitch_scale` gives the whole game an audible scale. A run that climbs to a 4x3
sounds like it is climbing.

The CPU's actions play about 9 dB down — you want to hear that it acted without
it competing with your own typing. Keystrokes are deliberately tiny and pitch-
jittered, because anything with body to it becomes unbearable within a sentence.

Waveforms are faded a few milliseconds at each end; without that, every sound
starts and stops on a discontinuity and you hear a click instead of a note.

To check the bank — it writes every sound out as a `.wav` you can listen to, and
verifies playback and mute:

```bash
godot --headless --script res://tools/audiocheck.gd
```

## Difficulty

| | WPM | Reaction | Fumble | Vocabulary | Focus | Combo sense |
|:--|----:|---------:|-------:|-----------:|------:|------------:|
| Rookie | 26 | 1.5s | 22% | top 2,500 | 45% | 10% |
| Duelist | 40 | 0.9s | 14% | top 6,000 | 65% | 35% |
| Wordsmith | 58 | 0.5s | 7% | top 25,000 | 90% | 80% |

The CPU spends real time entering each word at its WPM, which is why you can
watch an attack forming under its board and race to answer it.

The last three columns govern defense, and they exist because "the CPU is too
good at defending" turned out to be three separate problems:

- **Vocabulary** is how deep into the frequency list it may look. A hard stamp
  like `DING` only has answers buried deep, so a shallow CPU cannot find one and
  has to eat the block.
- **Focus** is the chance it hunts for a defensive word at all, and that it goes
  after the most dangerous block rather than whichever one it noticed. Below it,
  the CPU answers a random block or just swings back.
- **Combo sense** is the chance it looks for the word clearing *several* blocks
  at once. This was the real damage — a perfect multi-clear counterattack every
  time, which is how it turned your best attack into a 4x3 in its favour. Below
  it, the CPU grabs the first answer that comes to mind.

Against a fixed eight-word assault, Duelist went from clearing 6 to clearing 3,
and its counterattacks fell from a 4x3 haymaker to mostly 1x1s and 2x1s. Tune all
of it in `AiOpponent.DIFFICULTIES`.

## Not done yet

- No music, only effects. A generated ambient bed that tightens as your board
  fills would fit the synthesis approach already in `audio.gd`.
- **Given names still leak into the CPU's vocabulary** — it will occasionally
  play `JOEL` or `SARAH`. The build script drops names absent from a curated
  common-word list, which catches `ABAGAEL` but keeps the frequent ones, and
  those are exactly the ones you see. Telling `SARAH` from `GRACE` automatically
  needs a corpus that preserves capitalization; dwyl's `words.txt` looks like one
  but omits ordinary words (`for`, `are`, `hope`) while listing `Joel`, so it is
  unusable for this. A real fix means either a better source list or a curated
  blacklist.
- Versus has no matchmaking or lobby browser — you share a code out of band, and
  there is no spectating or reconnect.
- Cross-NAT play is **untested**: both peers here were on one machine, so
  punchthrough was trivial. The relay fallback exists but has not been exercised
  against a real hostile network.
- The used-word rule is per side and per match, so nobody can spam one word.
  There is no scoring beyond the end-of-match summary.
