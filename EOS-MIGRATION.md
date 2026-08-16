# Moving Word Wars onto Epic Online Services — scope

Written after reading the current netfox/noray implementation, the working EOS
integration in `veil-of-echoes`, and upstream EOSG.

**Verdict: worth doing, and cheaper than expected.** The migration is contained
to one file, and the two features you actually want — lobby browsing and short
room codes — are native EOS behaviour rather than things that need building.

---

## Why EOS genuinely fits (not just "it's newer")

Both of your asks are structurally impossible on the current stack:

| Want | On noray | On EOS |
|---|---|---|
| Short room codes | `room_code = Noray.oid` — the code *is* the orchestrator's ID. Shortening it needs a bespoke short-code→OID mapping service you'd have to run and keep alive. | Code is just a lobby attribute you choose. Free. |
| Lobby browsing | No discovery mechanism exists. Noray brokers a punchthrough between two parties who already know the code. | `search_by_attribute_async` over a shared tag. Free. |

So this isn't a lateral move for its own sake — the current transport
architecturally cannot do what you're asking for.

---

## The migration surface is one file

This is the finding that matters most for cost.

- All **12 `@rpc` functions live in `net_link.gd`**. `game.gd` has zero.
- `game.gd` (5,641 lines) touches networking only through ~28 members of the
  `Link` facade: `Link.host`, `Link.join`, `Link.roster`, `Link.send_attack`,
  `Link.match_begin`, and so on.

Because EOSG ships **`EOSGMultiplayerPeer`**, a real `MultiplayerPeer`, the
high-level API keeps working untouched:

```gdscript
var peer := EOSGMultiplayerPeer.new()
peer.create_server(EOS_SOCKET)
multiplayer.multiplayer_peer = peer
```

**Every existing RPC, signal and seating handshake survives as-is.** The job is
to swap what `host()` and `join()` construct inside `net_link.gd` while keeping
the `Link` API byte-identical. `game.gd` needs no changes at all.

That is the best possible shape for this kind of migration, and it's largely
because the existing code already isolated the transport behind a facade.

---

## Most of it is already written, in veil-of-echoes

`scripts/systems/network_manager.gd` has solved this exact problem. Directly
portable:

- **5-character codes** on an unambiguous alphabet (`_generate_code`, no
  `0`/`O`/`1`/`I` — built for reading aloud). Exactly your "much smaller codes".
- **Code as `bucket_id`**, found with `search_by_bucket_id_async`, with a retry
  loop because a fresh lobby takes a few seconds to be indexed. That retry is
  hard-won knowledge — without it, joining your own just-made room fails.
- **Browser via a shared attribute** on every lobby, so one attribute search
  lists them all while `bucket_id` stays the private code.
- **`HAuth.login_anonymous_async`** — Device ID auth. No Epic account, no login
  UI, no friction. Right call for a casual word game.
- Publish throttling so lobby updates don't spam EOS.

---

## Blocker status: resolved

I previously flagged that veil-of-echoes' `bin/` has **only linux and windows**
binaries while Word Wars ships macOS. That's true of your vendored copy — but
upstream EOSG **2.3.0 publishes macOS (universal) and iOS arm64** builds.

So this is a *download*, not a compile. No Mac needed to obtain them.

Two caveats that remain real:

1. **The addon is 141 MB.** Committing it straight into git will bloat the repo
   permanently. Use Git LFS for `addons/**/bin/**`, or gitignore the binaries and
   fetch them in CI.
2. **iOS is the one genuine unknown.** You have a working unsigned arm64 IPA
   built by CI on Linux. EOSG's iOS instructions say to export from Godot then
   *build the generated project in Xcode* — which your Linux CI pipeline doesn't
   do. Whether Godot's Linux-side iOS export correctly embeds the EOS
   `.xcframework` is the single thing I can't determine without trying it.

---

## Work breakdown

| Task | Estimate | Notes |
|---|---|---|
| Epic Dev Portal product + credentials | 1–2 h | Own product for Word Wars — do **not** reuse the Veil of Echoes IDs |
| Vendor addon (incl. mac/ios bins) + LFS | 1–2 h | 141 MB; decide LFS vs CI fetch first |
| `eos_config.gd` + init/auth | 2–3 h | Near-copy of veil-of-echoes |
| EOS backend inside `net_link.gd` | 1–2 days | Keep `Link` API identical; `Backend.EOS` alongside existing `Backend.ROOM` |
| Short codes | ~0 | Falls out of `bucket_id` |
| Lobby browser UI | ~1 day | Search is trivial; the list/refresh/join UI is the work |
| Desktop testing (Linux/Win/Mac) | 1 day | Mac needed to verify macOS |
| iOS | 0–3 days | Unknown until attempted; see caveat above |

**Realistic: about a week for Linux/Windows/macOS**, iOS separately and
uncertain.

Keep noray as a fallback backend rather than deleting it. `Backend` is already
an enum, the self-hosted orchestrator in `deploy/` already works, and having a
path that doesn't depend on Epic being up is worth the small maintenance cost.

---

## One thing you may not need EOS for

You asked for "a leaderboard at the end so you can compare stats." If that means
**a post-match scoreboard comparing the players in that match**, it's a local UI
job — a few hours, no EOS, and it can ship before any of this.

EOS also has `hleaderboards.gd` / `hstats.gd` for *global persistent* rankings,
which is a much bigger piece: stat definitions in the Dev Portal, an ingest
pipeline, and cheat considerations. Worth being explicit about which you meant
before anyone builds the expensive one.

---

## Credentials note

`veil-of-echoes/scripts/systems/eos_config.gd` holds live Product/Sandbox/
Deployment/Client IDs **and a client secret**, committed. Its own header already
flags this. These are EOS game-client credentials, intended to ship inside
builds, so it isn't a server-secret leak — but if that repo ever goes public,
they're in the history forever. Word Wars should get its own product, and the
same decision should be made deliberately rather than by default.

---

## Suggested order

1. Post-match scoreboard + remove the end-screen shortcuts — independent, cheap,
   fixes an annoyance today.
2. Dev Portal product, addon vendoring, auth. Prove `login_anonymous_async`
   works on Linux.
3. `Backend.EOS` in `net_link.gd`, host/join by code, `Link` API unchanged.
4. Lobby browser.
5. macOS verification, then iOS as its own investigation.
