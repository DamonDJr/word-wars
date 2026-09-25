# Word Wars: Press Kit

> **Everything in angle brackets `<like this>` needs your answer before this
> goes out.** They are the handful of facts that are not in the repository:
> mostly dates, the store URL, and your own reasons for making it. Nothing else
> here is invented; the mechanics, numbers and feature list are all read off the
> build.

---

## Fact sheet

| | |
|:--|:--|
| **Title** | Word Wars |
| **Developer** | Damon Drummond, solo |
| **Based in** | <city, country> |
| **Release date** | 29 August 2026 |
| **Latest version** | <current version and headline change> |
| **Platforms** | iOS 17+, iPhone and iPad |
| **Price** | Free, with one optional non-consumable unlock |
| **Store** | https://apps.apple.com/us/app/word-wars-typing-battle/id6802900966 |
| **Engine** | Godot 4.7, GDScript |
| **Bundle ID** | com.damonj.wordwars |
| **Press contact** | damondjr95@icloud.com |
| **Social** | <TikTok / X / Bluesky / Discord> |

---

## The pitch

### One line

> A competitive word game where the last letters of your word become somebody
> else's problem.

### Short (about 40 words)

> Word Wars is a real-time word battler. Type a word and its final letters are
> stamped onto a block and dropped on your opponent's board, and they can only
> clear it with a word that *starts* with those letters. Type FRIENDSHIP, they
> get SHIP.

### Medium (about 90 words)

> Word Wars is a real-time word battler with a Puyo Puyo pulse. Every word you
> type stamps its last letters onto a block and drops it on a rival's board;
> the only way they clear it is with a word that starts with those letters.
> FRIENDSHIP sends SHIP. SHIPMENTS answers it and sends MENT. The duel is a word
> chain where every link is also an attack.
>
> How *big* the block is comes from rhythm and length together. Keep firing
> without breaking your chain and the hits climb. A long word fills that
> chain faster and sets a floor under it, so a good word still pays when your
> run is short. Break the chain and you start again from nothing.

### Long (about 180 words)

> Word Wars is a real-time word battler for phones. It's you against one
> rival, either the CPU or another player online.
>
> Every word you type stamps its **last** letters onto a block and drops it on
> their board. To clear a block, you need a word that **starts** with the
> letters stamped on it. Your endings become their beginnings. FRIENDSHIP
> brands a block SHIP; answer it with SHIPMENTS and that brands one MENT.
>
> How big a block you send is decided by rhythm and by length together. Rhythm
> is the larger lever: keep firing without breaking your chain and the hits
> climb, up to a 4x3 slab that takes nine clean words in a row. A long word is
> never wasted either: it fills the chain faster, reaches further across the board,
> and sets a floor of its own that a short run cannot drag you below. Whichever
> of the two you are doing better decides the size, and every block you clear on
> the way stacks on top of it.
>
> Land a tenth word past the top of the ladder and the run detonates into a
> salvo: ten single cells raining into the gaps. Each one is nothing on its
> own. Together they're a mess.
>
> Filling your board does not end the match. It costs one of three lives and
> hands the board back empty, but the pressure clock never resets, so your last
> life is a lot harder than your first.
>
> The only defence is letters. Firing a big word at someone does nothing about
> what's already falling on you.

---

## Features

- **Your words are the attack.** The last letters of what you type become the
  first letters someone else has to find.
- **Rhythm and length, both.** Chain words without pausing and your hits grow
  from a single cell to a twelve-cell slab. Long words fill that chain faster,
  reach further, and set a floor under a short run, so speed and vocabulary
  both get you there. A tenth
  word past the top detonates the run into a scattered salvo instead.
- **Three lives, and a clock that never resets.** Topping out costs a life and
  clears the board, but the pressure keeps climbing across all three.
- **One against one.** Two boards, and everything you send lands on the other.
  The CPU any time you want it, or another player over the network.
- **Six kinds of special block**, all off by default: bombs that chain,
  armour that eats a word, frozen blocks that cannot be answered at all, and
  blocks that re-brand themselves while you look at them.
- **Four power words** the rules already allowed and the game never used to
  notice: COUNTER, COMBO, PERFECT and CLUTCH. Everyone triggers the first one
  by accident.
- **A daily board everyone shares**, a survival mode, leaderboards, and a
  mastery track with cosmetics.
- **Emotes**, because a word game about beating somebody needs a way to gloat.
- **A 350,000-word dictionary** with a profanity filter that masks rude words on
  screen but still scores them. They're still real words.

---

## Assets

Run `tools/presskit.sh` to build the whole bundle into `build/presskit/`:

```bash
tools/presskit.sh
```

| What | Where |
|:--|:--|
| Trailer (1080x1920, ~50s) | `build/presskit/word-wars-trailer.mp4` |
| Vertical ads (5 x ~11s) | `build/presskit/social/` |
| Screenshots (phone) | `build/presskit/screenshots/` |
| Screenshots (iPad) | `build/presskit/screenshots/` |
| App icon, 1024px | `build/presskit/icon-1024.png` |
| Animated GIF for newsletters | `build/presskit/word-wars.gif` |

**The GIF matters more than you think.** A lot of indie newsletters embed a GIF
rather than a video because their mail template cannot autoplay one, and a
submission that arrives with a ready-made loop is measurably less work for the
person deciding whether to run it.

---

## History

> <Two or three paragraphs, in your own voice. This is the part no repository
> can tell me and the part newsletters actually print. Worth answering:>
>
> - What made you start it? The README's own framing (word *endings* make
>   terrible word *beginnings*) is a good hook if that is where it began.
> - How long has it been going, and was it always this game?
> - What was the hardest thing to get right? Honest answers do well here.
> - Why solo, and why phones?
> - How AI fits into how you build it. You have been open about it, and
>   press will ask, so say it here in your own words before they do.

**Things from the build that are worth telling honestly**, if you want them:

- Every attack is a real word the game itself found. The CPU picks its words out
  of the same dictionary you do and scores a candidate by what it would actually
  clear, not by what it merely matches.
- Stamps are chosen so they can always be answered. A candidate needs at least
  40 answers in the full dictionary and 6 in the common list before it is
  allowed onto a block.
- The rude-word filter masks on screen but still pays you for the word, because
  a rude word is a real word and refusing to score one would be a bug report
  about the dictionary.

---

## Credits

- **Barlow** (Semi Condensed and Condensed) by The Barlow Project Authors, the
  house face for the menus, logo and scores. SIL Open Font License 1.1; the full
  text is in `fonts/OFL.txt`.
- **Board lettering** (Premium boards): Bungee, Orbitron, Chakra Petch,
  Fredoka, Comfortaa, Alfa Slab One, Josefin Sans and Cinzel by their
  respective Project Authors, and Bree Serif by TypeTogether. All SIL Open Font
  License 1.1; each licence, with its copyright line, sits beside its font in
  `fonts/boards/`.
- Networking rides on [netfox.noray](https://github.com/foxssake/netfox) (MIT)
  for NAT punchthrough and relay.
- The splash screens and logo are drawn in code in the repository
  (`tools/splash_art.py`).
- BloqBot and Waddles are hand-drawn.
- <Premium board backdrops: who made them, and how.>
- <Music: who made it, and how.>
- The sound effects are synthesised in code, and the word lists are built by
  `tools/build_wordlists.py`.

---

## Contact

- **Press / business:** damondjr95@icloud.com
- **Store:** https://apps.apple.com/us/app/word-wars-typing-battle/id6802900966
- **Social:** <handles>

Review copies aren't needed. The game is free on the App Store.
