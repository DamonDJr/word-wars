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

**[Download the launcher](https://github.com/DamonDJr/word-wars/releases/latest)**
— it fetches the game and keeps it current, so players download once and never
again. The game is also there as a plain zip if you would rather not.

## Running it

Open the folder in Godot 4.7 and press F5, or from a terminal:

```bash
godot --path "$(pwd)"
```

The title screen has four doors: **single player**, **multiplayer**, **mastery**
and **settings**, on `1` – `4`. Every match opens with a shared 3-2-1 before anyone can type. Type letters,
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

## The launcher

`launcher/` is a separate Godot project that checks the GitHub releases API,
downloads the build for the current platform if it is newer than what is
installed, unpacks it and runs it. Players keep the launcher; everything after
that updates itself.

It has to be a separate program. Nothing can overwrite a running executable on
Windows, so the thing doing the updating must not be the thing being updated —
which also means the launcher cannot update *itself*. It is deliberately dumb and
stable for that reason: it knows a repo name, an asset naming convention and
nothing else, so it should never need to change.

- The game installs to the launcher's own `user://` folder, so there are no
  permissions to fight and nothing to tidy up.
- An update replaces the install rather than merging into it, so a file that
  disappears upstream does not linger.
- Zips carry no permission bits worth trusting, so the executable bit is set
  explicitly after unpacking.
- Losing the network is not a reason to stop somebody playing: if the API cannot
  be reached and a version is already installed, it says so and launches that.

`tools/build.sh` builds and zips it alongside the game.

## Up to four boards

Single-player setup seats up to three CPUs and lets you name each one; Versus
seats up to four humans in one room. Yours is drawn full size on the left, rivals shrink into
a row on the right — same board, scaled by the node transform, so every effect
and label keeps working on them.

**You choose who you are hitting.** `TAB` cycles your aim (shift-TAB goes back),
`1`/`2`/`3` pick a board outright, and clicking one aims at it. The board you are
pointed at gets a pulsing ring and an arrow, and the centre column names it. Bots
wander their own aim every few seconds, so a four-way does not turn into three
guns pointed at you.

Running out of lives knocks you out rather than ending the match — the rest play
on, and the last board standing wins. While you are out the screen greys and your
typing does nothing; you are watching, not playing.

`ESC` opens a pause menu with Resume and Leave match. Solo, that genuinely
freezes the match. It cannot freeze a networked one — everyone else is still
playing — so there the match runs on underneath and the menu says as much rather
than pretending otherwise. `SPACE` and `ENTER` deliberately do not resume, for
the same reason they no longer rematch: your hands are already on them. Clearing
your line moves to `CTRL+BACKSPACE`, which always did it anyway. Aim retargets itself automatically when
whoever you were hitting drops out.

A duel still looks exactly like it did: two full-size boards facing each other,
no aim marker, because with one rival there is nothing to choose between.

**A versus room can be topped up with CPUs.** If only two people show up, the
host adds bots with `+` until the table is full, and everyone plays the same
free-for-all. Bots show in the room as COMPUTER seats, already ready.

Every board needs exactly one machine in charge of it, so the **host owns the
bots**: it runs their word search, simulates their boards and broadcasts their
state like any other player. Boards are identified by an *entity id* — a real
peer id for a person, a negative number for a bot — and attacks are addressed to
that, so a human hitting a bot posts to the host, which delivers it. Anything
aimed at a board the sending machine already owns skips the network entirely.

The host also lays out the seating once and tells everyone, because clients can
no longer work it out for themselves: bots have no peer id to sort by. Each
client then places itself at board 0 and keeps the host's order for the rest.

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
scripts/ai_opponent.gd   CPU personalities: word choice, pace, strategy
scripts/scoring.gd       Scrabble letter values plus chain/combo multipliers
scripts/word_bank.gd     autoload; word lists, prefix index, fairness lookups
scripts/audio.gd         autoload; synthesises the whole sound bank at startup
data/words.txt           ~350k words, sorted — what counts as valid input
data/common.txt          ~36k frequency-ordered words — CPU vocabulary
tools/build_wordlists.py regenerates both data files from source corpora
tools/selftest.gd        headless check of stamp fairness and length spread
tools/audiocheck.gd      dumps the sound bank to .wav and verifies playback
splashScreen.png         key art; engine boot splash and the in-game splash
fonts/                   Rubik Glitch, used for the wordmark and nothing else
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
for testing. [Run your own][norayserver] before shipping — see
[`deploy/`](deploy/README.md), which has a compose file and the checklist.

#### How long a code is, and why

The code's shape comes from the server, not the game. The public one hands out
nanoid's default — 21 characters of mixed case, `eYQ43-0zsuCDyirJScs1M` — which
is about 126 bits of entropy for something two people read to each other over a
call, and is the reason the lobby has to warn that codes are case-sensitive. A
server you own can be told `NORAY_OID_LENGTH=6` and a single-case alphabet, and
the same room becomes `K7Q M4X`.

`CODE_ALPHABET` in `net_link.gd` is the client half of that, and **must** match
the server's `NORAY_OID_CHARSET`. Empty means "the server's codes are
case-sensitive, so pass them through exactly as typed" — the only safe default,
because only the server knows whether it issued `k` or `K`. Fill it in and the
lobby starts upper-casing what the player types, stripping the hyphens and
spaces people add when reading a code aloud, grouping the code in threes rather
than fives, and setting it large enough to read off a screen. Setting it against
a mixed-case server would break every join, confidently.

Six characters of a 32-letter alphabet carries the same entropy as the five
upstream suggest on their 64-letter one, and codes only exist while their host is
connected — noray drops them from its registry the moment the socket closes — so
the space only has to cover rooms open at once, not rooms ever opened.

Hosting is **CTRL+H**, not `H`. A bare letter cannot be a shortcut while a text
field owns the keyboard: `H` is an ordinary character in a room code, and about
half of the public server's codes contain one, so the old binding quietly made
those codes impossible to type by hand. It went unnoticed because the
instructions tell people to paste.

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

### Attacks travel

An attack used to teleport: you fired, and a number appeared under somebody
else's board. Now it flies there — a comet on a lobbed curve, drawn as a wide
soft pass for the glow and a narrow bright one for the filament inside it,
carrying the stamp it is about to brand. With four boards this is the difference
between knowing you were hit and knowing *who* hit you, and the moment it spends
in the air is the moment the hit actually feels like it lands.

Everyone's tracers carry their letters, not just yours. Watching `ING` cross the
screen towards you is a second of warning about what you are going to have to
answer. It arrives on the target board as its own debris burst — `WWBoard.splash`
— because an attack that crossed the whole screen and then simply stopped was
failing at the one moment it most needed to sell.

The whole thing is cosmetic: the rules resolved the instant the word was fired,
which is exactly why it is free to take its time.

### Hit stop

The world freezes for a fortieth of a second on a heavy landing, a power word or
a salvo. It is the cheapest trick available and the one that does the most — a
moment of nothing is what makes an impact feel like it has weight rather than
merely happening.

It scales `Engine.time_scale`, which means it also scales the clock the netcode
runs on, so **a networked match does without it** rather than risk two machines
disagreeing about how much time has passed. The timer is measured against the
wall clock rather than `delta`, since `delta` is the thing being slowed and a
freeze timed with it would never end.

### Screen texture

Film grain and a vignette, both pitched just at the edge of noticing. The grain
is one 96px tile of squared noise, re-offset every frame — a per-pixel effect
done honestly in `_draw` would cost more than the rest of the game put together,
and in motion nobody can tell.

The vignette does double duty. It frames the picture, and it is where the board's
danger is *felt* rather than read: past halfway to the ceiling it reddens and
starts beating, faster the closer you get, so the screen itself gets nervous.
That is a thing you notice without having to look at anything.

Scanlines were tried here and cut. At any strength you could actually see they
claimed a CRT this game is not pretending to be, and below that they were a draw
call doing nothing.

## The menus

### Starting up

Launching the game shows the key art twice, and you are not meant to notice the
seam. The engine paints `splashScreen.png` as `boot_splash` before a single
script runs, which covers the second or so `WordBank` spends reading 350k words;
the scene then draws the *same* image with the same fit against the same
backdrop, holds it for `SPLASH_HOLD`, and dissolves it off the title screen that
has been assembling underneath. Any key or click cuts the hold short — it drops
straight to the start of the dissolve rather than snapping, and it does nothing
else, so an impatient press cannot also land on a menu button behind the art.

The art is 3:2 against a 16:9 screen, so it is framed rather than cropped: it is
a composed picture, and trimming its edges costs more than two side bars. Those
bars are `SPLASH_MATTE`, sampled from the artwork's own border rather than taken
from the UI palette, which is why they do not read as letterboxing.
`boot_splash/bg_color` is set to the same value.

### The title screen

The title screen shows three worked examples instead of a wall of instructions,
each drawn with the same routines the playfield uses: `FRIENDSHIP` splitting into
a branded `SHIP` block, that block coming apart under `SHIPMENTS`, and a live
chain meter with escalating block sizes. The full rules are still one keypress
away on `H`. Blocks drift down behind it all.

The wordmark is the one thing set in Rubik Glitch; everything else stays on the
plain face. A display font is a logo, not something anyone should have to read a
menu in. Because it sets much wider than the default face, the wordmark's size is
fitted to the window rather than fixed, and the rule beneath it is measured off
whatever size that came out as — so swapping the font again cannot push the title
off-screen or leave the underline stranded.

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

## Music

Six tracks in `music/`, driven by `scripts/music.gd` from whatever is happening:

| Track | When |
|:--|:--|
| `menuBGM` | title screen and lobby |
| `mainTheme` | a match in progress |
| `critcalTheme` | your stack reaches row 6 — over half full |
| `cluchMoment` | row 3 — one bad drop from topping out |
| `deathSound` | your last life goes |
| `victoryTheme` | you win the match |

It is meant to sit **under** the game, not compete with it. The keystrokes and
block impacts are the feedback you actually play on, so the bed runs at
`MUSIC_DB` (-17) with a per-track `TRIM`, because the files are not mastered to
matching loudness and a sting arriving hot is exactly the jolt worth avoiding.
Two players crossfade in `FADE` (0.8s) so the new track is simply there — a long
crossfade between two beds that are both playing sounds indecisive, and you spend
it hearing neither properly. Stings use `STING_FADE`.

Escalation is instant — the music should arrive *with* the danger. Calming back
down has to wait out `MUSIC_HOLD` (4s), because a board that dips below the line
for half a second has not really recovered, and swapping straight back just
sounds indecisive.

Being knocked out of a match that is still running plays the death sting and then
hands back to the main theme, since you are still watching.

`F1` silences music and effects together. To check the bank loads, loops and
crossfades:

```bash
godot --headless --script res://tools/musiccheck.gd
```

Two files carry typos from when they were added — `cluchMoment.mp3` and
`critcalTheme.mp3`. The lookup table in `music.gd` maps clean keys onto the real
filenames, so renaming them later is a one-line edit.

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

## The menus

Four doors on the title screen and nothing else: **single player**,
**multiplayer**, **mastery**, **settings**. It used to carry the entire opponent
roster plus two mode buttons plus a rules toggle, which meant the first thing
anybody saw was fourteen choices at once. Choosing an opponent is a decision
that belongs *inside* single player rather than in front of it.

**Single-player setup** is shaped like the versus lobby on purpose — seats along
the top, a roster underneath that fills whichever seat is selected. Each of the
three rival seats can be empty, a named personality, or **random**, which is
rolled once at the start of each match rather than re-rolled between the menu and
the countdown. Filling a seat advances the selection to the next empty one, so
setting up three opponents is three clicks rather than six. A rematch rebuilds
from the seats, which means a random seat is genuinely rolled again instead of
quietly becoming whoever it was last time. The lineup is remembered between
sessions.

**Settings** covers music and effects volume, the screen texture and impact
freeze toggles, fullscreen, and the name you play under — which previously only
existed inside the versus lobby, where somebody playing alone would never find
it. Everything writes straight through to the profile with no apply button: a
settings screen that can be wrong until you confirm it is a settings screen that
will get left wrong.

The volume sliders are a trim on top of the existing mix rather than a
replacement for it. The relative loudness of a keystroke against a block landing
is a design decision, and a slider should not be able to flatten it.

## The profanity filter

The dictionary is 350k words and does not omit the rude ones, so anything the
game echoes back at you can be masked. Two rules keep it from becoming a
nuisance.

**It never changes what a word does.** A rude word is still a real word: it
still clears blocks, still scores, still counts toward your record. Only the
display is masked. A filter that silently made some words stop working would
arrive as a bug report about the dictionary rather than as a filter.

**It matches whole words only.** Substring matching is how you end up refusing
to print `classic`, `assassin`, `shuttlecock` and `Scunthorpe` — and in a game
whose entire subject is the letters inside words, that failure mode would fire
constantly. Inflections come from expanding a stem list at load time rather than
from stemming at match time, so everything caught is something somebody wrote
down deliberately. `tools/censortest.gd` checks both directions, and the
Scunthorpe half of it is the longer list.

Masking happens inside `_say` and `_log` rather than at their call sites, because
there are dozens of those and a new one must not be able to forget.

Two things are handled differently:

- **Stamps are never minted rude in the first place**, filter or no filter.
  Masking a stamp would be worse than showing one — the stamp is the thing you
  have to type, and you cannot answer what you cannot read. `WordBank` refuses
  the fragment and the search moves on, which it was going to do for a dozen
  other reasons anyway.
- **Names get their own pass.** They are the only free text in the game —
  everything else has to be a dictionary word, and the typing input only accepts
  `a` to `z` — so `S.H.I.T` is possible there and nowhere else. A name is one
  token however it was punctuated. A log line cannot be treated that way, since
  collapsing a sentence across its punctuation would join words that were never
  one word.

Off in Settings for anyone who would rather not have it.

## Opponents

Seven of them, and speed is only one axis. The interesting one is that this game
has a real strategic tension built in: **block size comes from rhythm, and how
many blocks a word clears comes from length.** Fire short words and your chain
climbs, so the slabs you send get bigger. Reach for long words and each answer
sweeps several blocks off your own board, but the run keeps lapsing. You cannot
have both, and every personality is a different answer to that trade.

| | WPM | Words | Vocabulary | Focus | Combo | Rhythm | Plays like |
|:--|--:|:--|--:|--:|--:|--:|:--|
| Rookie | 26 | 3–7 | 2,500 | 45% | 10% | 30% | no plan yet |
| Magpie | 26 | 7–13 | 9,000 | 70% | 45% | 5% | hoards letters, clears in sweeps |
| Metronome | 34 | 3–6 | 4,000 | 45% | 20% | 95% | short words, relentless tempo |
| Duelist | 40 | 4–9 | 6,000 | 65% | 35% | 50% | no weakness, no specialty |
| Bulwark | 38 | 4–10 | 20,000 | 97% | 85% | 20% | all defence, soft punches |
| Berserker | 52 | 3–7 | 5,000 | 12% | 15% | 90% | all offence, drowns itself |
| Wordsmith | 58 | 5–12 | 25,000 | 90% | 80% | 65% | does everything, and quickly |

Magpie is the clearest illustration: Rookie's hands, nothing like Rookie's head.
It types no faster than the easiest opponent on the list and still answers almost
everything, because a nine-letter word takes four blocks off its board at once.
What it never does is build a chain, so it barely hits back.

The CPU spends real time entering each word at its WPM, which is why you can
watch an attack forming under its board and race to answer it.

### The dials

- **Vocabulary** is how deep into the frequency list it may look. A hard stamp
  like `DING` only has answers buried deep, so a shallow CPU cannot find one and
  has to eat the block.
- **Focus** is the chance it hunts for a defensive word at all, and that it goes
  after the most dangerous block rather than whichever one it noticed.
- **Combo sense** is the chance it looks for the word clearing *several* blocks
  at once, rather than the first answer that comes to mind. This was the real
  damage back when the CPU was too strong: a perfect multi-clear counterattack
  every single time.
- **Rhythm** is how much it protects a run in progress. A high-rhythm bot works
  out what it can finish before the chain window shuts and deliberately picks
  something that short; a low one swings regardless and eats the lapse.
- **Grudge** is how long it stays pointed at one rival in a four-way. Without it
  everybody re-aims at the same rate, which is three identical guns.

Two things stop a personality from being a suicide note. Every bot reads its own
**peril** — how full its board is, counting inbound garbage — and starts
defending regardless of temperament once the stack nears the ceiling, which is
the only reason Berserker is worth playing twice. And a long-word bot that finds
no answer at its preferred length searches again with no floor, because a bot
sitting on a block it could have cleared reads as broken rather than as
characterful.

A free-for-all deals **different** personalities to the other three boards,
drawn from near your pick on the roster so the table stays roughly the level you
asked for. Three copies of one opponent is one opponent with more boards. They
are named on screen for what they are, so you can tell at a glance that the board
on the right is a Berserker and the one beside it is a Bulwark. Networked CPUs
work the same way — the host picks the personalities when it builds the seating
and sends the names, so the label *is* the configuration and both ends agree
without a second packet.

Tune all of it in `AiOpponent.DIFFICULTIES`. Adding an entry there and to
`ROSTER` puts it on the menu; the picker builds itself from the roster.

## Special blocks

Six kinds of garbage that do more than sit there. **All off by default** — the
base game stays the base game — and switched on per match in the lobby, in
single player and in the versus room alike. Roughly three blocks in ten are
special when anything is enabled, which is often enough to matter and rare
enough to stay an event.

| | What it does | The decision it forces |
|:--|:--|:--|
| **Bomb** | clears everything it touches, and chains into other bombs | worth setting off, but its stamp is longer than anything else on the board |
| **Armoured** | eats a matching word without dying; the second one takes it | two words for one block, and the first still costs you reach |
| **Volatile** | drops a fresh block on you when its fuse runs out | it does *not* clear itself — ignoring it costs you |
| **Split** | breaks into two smaller blocks instead of vanishing | one big problem or two small ones, and you choose when |
| **Frozen** | cannot be answered at all until something else breaks | it is not a stamp problem, so it is excluded from matching entirely |
| **Cursed** | re-brands itself every few seconds | answer it now, or wait for a stamp you can actually use |

Every one is readable off the block itself — a lit fuse, plating with a rivet
per hit remaining, a countdown ring that flashes in its last seconds, a seam
with arrows, ice, a moving scribble. There is no legend, because a rule you have
to look up is a rule that is not carrying its weight.

A few decisions worth knowing:

- **Bomb chains are capped.** Uncapped, one lucky arrangement clears an entire
  board off a three-letter word.
- **A frozen block is not a match**, rather than a match that is refused. That
  has to be true at the point the board is *queried*, or the highlight lights it
  up and promises a clear that cannot happen.
- **Armour still costs reach.** Otherwise it is free to chip at, and "needs two
  words" quietly becomes "needs one word and a spare letter".
- **Volatile blocks do not clear themselves.** Detonating into a free clear
  would reward ignoring them, which is the opposite of the point.
- **The board mints nothing.** It has the blocks; `game.gd` has the dictionary.
  Curses re-brand and split children get stamped through a `mint` callable
  handed in at startup, rather than a signal round-trip per letter.
- **Over a network, everybody plays the host's rules.** They are pushed when
  they change, again when somebody joins, and carried in the seating so the
  countdown is the last possible moment for two machines to disagree — and they
  do not. Each board still rolls its own blocks, which is safe because every
  board is simulated by exactly one machine.

`tools/blocktest.gd` builds the exact board each rule needs and checks it does
that and only that — including that nothing special appears at all with the
switches off, since the base game has to stay the base game.

## Power words

Four situations the rules already allowed and the game never bothered to notice.
That is the whole design: none of them asks anything new of you, so the first one
you trigger is always an accident — the game names it, pays for it, and you spend
the next match trying to do it again on purpose.

| | When | What you get |
|:--|:--|:--|
| **COUNTER** | you shoot down something already inbound | one goes straight back |
| **COMBO** | you break three blocks at once | your **next** attack is a tier bigger |
| **PERFECT** | you break three *without* dropping your run | a whole extra attack, now |
| **CLUTCH** | you break anything with one row of headroom left | the garbage nearly stops |

They stack. One word that intercepts, breaks three and keeps the run going fires
COUNTER, COMBO and PERFECT together, and the banners pile up the board rather
than landing on each other.

A few decisions worth knowing:

- **COMBO pays forward, PERFECT pays now.** That is the only difference in their
  timing and it is deliberate: COMBO is a promise you have to survive long enough
  to cash, so it changes how you play the *next* word. The tier it owes is spent
  the moment you attack again, and the match log says `(+1 tier)` so it never
  cashes in invisibly.
- **PERFECT is the hard version of COMBO**, not a separate trick — same three
  blocks, but you had to already be mid-run. The two firing together is the
  crescendo, not a bug.
- **COUNTER is one for one.** It sends back exactly what it shot down, so it can
  never pay out more than was aimed at you in the first place.
- **CLUTCH slows the garbage rather than stopping it** — `CLUTCH_RATE`, about a
  third speed — and suppresses the next ambient pressure seed on that board. A
  stay of execution, not a pardon; you still have to type your way out. Note its
  threshold is stricter than the music's: the soundtrack escalates at three rows
  of headroom as a warning, the power word pays at one.
- **Everyone can earn them**, CPUs included. They are rules, not a player perk.
  Only your own get a banner, for the same reason only your own score is drawn.
- **A salvo swallows them.** Cashing a maxed chain is already the biggest thing
  in the game and does not need power words stacked on top.

Each pays a flat bonus — 150 to 500 — announced on the banner itself rather than
as a second floating number, so one thing arrives saying both what happened and
what it was worth.

### Testing them

They fire on situations that are hard to reach by playing: COMBO wants three
identically stamped blocks and a word long enough to reach all three, CLUTCH
wants a board one row from the ceiling. Waiting for those to happen by accident
is not a test, so `tools/powertest.gd` builds the board to order and plays the
word straight into `_play_word`, then reads the match log — the same evidence the
player gets. It checks the negative cases too: PERFECT must stay quiet when the
chain has lapsed, and an ordinary word on a quiet board must trip nothing at all.
A power word that fires constantly is not a power word.

`tools/build.sh` will not produce a build if that check fails.

## Scoring

Letter values are Scrabble's, unchanged, because everybody already knows them —
a `Q` is worth reaching for and an `E` is not, and nobody has to be taught that.
Everything above that is this game's own, and it pays for different things than
Scrabble does. Scrabble rewards rare letters and lucky squares; Word Wars rewards
**rhythm and damage**, so the multipliers come from the chain you are holding and
the blocks you just broke.

```
word    = sum of Scrabble letter values
bonus   = 15 + 10 per letter past 7      (long words only)
mult    = (1 + 0.20 x chain-1) x (1 + 0.60 x blocks broken)
total   = (word + bonus) x mult x 5
```

Clearing is deliberately worth more per unit than chaining: it is the harder
thing to do and the one you have to plan for rather than merely keep up with.
The long-word bonus is Scrabble's bingo in spirit, and it is paid twice over
because a long word is also what clears several blocks at once.

The whole thing is scaled by five at the end. Raw Scrabble scores are small — a
good word is twenty — and a counter creeping from 9 to 34 over a minute does not
feel like anything. Scaling changes no letter's worth relative to any other.

For scale: `CAT` cold is 25, `QUIZ` cold is 110, `FRIENDSHIP` is 320 — and the
same `FRIENDSHIP` on a five-chain that breaks two blocks is 1,267. Cashing a
salvo pays a flat 1,000 on top of the word that earned it.

The number lands where your eyes already are: a `+1,267 x3.96` leaps off the
bottom of your own board and eases to a stop, and the running total in the centre
column chases the real one rather than snapping to it, so you watch it climb.
Only your own arithmetic is ever drawn — four sets of numbers flying about is
noise, not feedback. Rivals still score, and their totals sit under their boards,
because in a four-way that is the only quick answer to "am I winning".

`tools/selftest.gd` checks the shape rather than the exact numbers: rare letters
beat common ones, long beats short, the multipliers compound instead of
replacing each other, and one great word beats eight poor ones.

## Mastery

Everything you have ever done is kept in `user://profile.cfg` and turned into a
level, and the level unlocks cosmetics. **None of it touches how the game
plays.** That is the point rather than a limitation: a level 30 player and a
level 1 player meet on exactly the same terms, which is what makes the level
worth showing off — it is a claim about the person, not the loadout.

### The level

XP is a pure function of the record, the level is a pure function of XP, and
what is unlocked is a pure function of the record. Nothing is stored that can
drift out of step with anything else, and changing a weight re-grades every
existing profile on the next boot rather than stranding it.

| Pays for | Weight |
|:--|--:|
| a match played | 90 |
| a match won | 240 |
| a win costing no lives | 350 |
| each word typed | 4 |
| each salvo landed | 130 |
| each multi-clear | 22 |
| best WPM | 4 each |
| best chain | 12, **squared** |
| best multi-clear | 30, **squared** |
| longest word | 5 per letter, **squared** |

The `best_` figures are peaks rather than totals, so they pay once and pay well
— a claim about your ceiling rather than your patience — and the squared ones
are squared because the difference between a five-chain and a nine-chain is not
four more words, it is four more words without a single mistake. A bad match can
never pull a peak back down.

Levels get further apart forever: `1 + sqrt(xp / 300)`. `tools/masterytest.gd`
prints the resulting curve rather than asserting on it, because the pacing is
the whole feel of the system and is the thing most likely to be wrong:

```
  1 match  -> level 3        50 matches -> level 10
 10 matches -> level 5      100 matches -> level 14
 25 matches -> level 7      200 matches -> level 19
```

### The unlocks

Seven slots — **titles, board themes, block styles, typing effects, attack
effects, cursor effects and victory animations** — all declared in one table in
`profile.gd`. The mastery screen builds itself from it and the unlock check
reads the same rows, so there is nowhere for a "shown but not obtainable" entry
to hide.

Each entry names **one** requirement, never a combination. "Reach a x8 chain" is
something a person can go and do; "reach a x8 chain and 400 words and level 12"
is a wall. Titles are earned by deeds rather than by level, which is what makes
them worth wearing — `Chainbreaker` wants a x8 chain, `Speed Demon` wants 65
wpm, `No Looking Back` wants a win that cost no lives, `SALVO KING` wants twelve
salvos.

Locked cards show what they want, how close you are, and a sliver of progress
along the bottom edge, because a lock that will not say what it wants is a
taunt rather than a target.

### What the cosmetics actually do

- **Board themes** repaint the backdrop wash, the board panel and the grid
  ruling. They deliberately do **not** touch tier colours: those carry meaning —
  a 4x3 is always red — and recolouring them would trade readability for
  decoration.
- **Block styles** change how garbage draws: solid, wireframe, glass, circuit.
  Each picks its own stamp colour rather than assuming dark-on-bright, or the
  letters stop being legible on half of them.
- **Typing, cursor and victory** effects are local flourishes — a flourish per
  keystroke, the shape of the caret, and what happens behind a win.
- **Attack effects** restyle the tracer, and **only your own**. A rival's shot
  has to keep reading as a rival's shot, or the one thing tracers were added to
  make clear — who is hitting whom — goes back to being a guess.

### Not losing it

The profile is somebody's entire history with the game, and the failure that
actually costs them it is not *"the save was lost"* — it is **"the save was lost
and then written over"**.

`ConfigFile.save` is not atomic. A crash, a power cut or a kill signal partway
through a write leaves a truncated file, and a truncated file does not parse.
The first version of this returned quietly when a load failed, leaving every
field at its default — and the next autosave then replaced a profile it had
merely failed to *read* with a blank one. That turns a recoverable problem into
a permanent one, and it is the shape of nearly every "my save reset" bug.

Four things now stand between a bad write and a lost history:

- **Saves are written whole and moved into place.** A new file is written
  alongside, and only then does anything existing get touched.
- **The previous save is kept as `.bak`**, and a failed load falls back to it.
  You lose the last match rather than the last month.
- **Parsing is not treated as validating.** ConfigFile shrugs at lines it does
  not recognise, so a file full of rubbish "loads" and then every field falls
  back to its default — the silent reset again, wearing a different hat. A file
  that parses but has no `record/matches` key is treated as damaged.
- **If nothing readable is found, saving is switched off for the session.** A
  profile that cannot be parsed may still be one that can be rescued by hand,
  and the game will not overwrite something it did not understand. The settings
  screen says so in red rather than letting you play on unaware.

Settings also prints the profile's full path, so it can be backed up or carried
to another machine without anyone having to guess at Godot's user directory.

`masterytest` covers all of it — a round trip, a truncated main file recovering
from the backup, both files damaged leaving the disk untouched, and a missing
file still being treated as a new player rather than a failure. `tools/build.sh`
will not produce a build if any of that fails.

Matches are banked at the end, not as they run, so a match abandoned halfway
earns nothing — the level has to mean matches played through.

## Not done yet

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

## Credits

- **Rubik Glitch** by the Rubik Filtered Project Authors, used for the wordmark.
  Licensed under the SIL Open Font License 1.1 — the full text travels with the
  font in [`fonts/OFL.txt`](fonts/OFL.txt).
- Networking rides on [netfox.noray](https://github.com/foxssake/netfox) (MIT)
  for NAT punchthrough and relay.
- Everything else — art, music, the synthesised sound bank, the word lists — is
  the project's own.
