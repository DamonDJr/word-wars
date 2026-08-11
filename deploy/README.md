# Running your own lobby server

Word Wars ships pointed at `tomfol.io:8890`, the public [noray] instance foxssake
run. It works, but you cannot configure someone else's server — and the room code
it hands out is 21 characters of mixed case:

```
eYQ43-0zsuCDyirJScs1M
```

Running your own turns that into:

```
K7Q M4X
```

Nothing in the game changes to make that happen. noray reads the code format
from its environment, so this is a config change on a box you own, plus one
constant in `net_link.gd`.

## Stand it up

Any small VPS will do — this needs a couple of hundred MB of RAM. It will not
run on most free PaaS tiers, because of the UDP relay port range.

```bash
scp -r deploy/ you@your-box:~/noray
ssh you@your-box 'cd ~/noray && docker compose up -d'
```

Open these in the firewall, and in your provider's security group if it has one:

| Port | Protocol | What for |
|:--|:--|:--|
| 8890 | TCP | clients connect here |
| 8809 | UDP | remote registration |
| 49152–51200 | UDP | relay pool, when punchthrough fails |
| 8891 | TCP | Prometheus metrics — **keep this private** |

The relay range is the part people forget. Without it, punchthrough still works
between friendly networks and everything looks fine, right up until two people
on awkward NATs try to play and the fallback has nowhere to go.

`docker compose logs -f` should show the loaded config on start. Codes come out
of `NORAY_OID_LENGTH` and `NORAY_OID_CHARSET` in [`noray.env`](noray.env).

## Point the game at it

Two constants in [`scripts/net_link.gd`](../scripts/net_link.gd):

```gdscript
const NORAY_HOST := "your-box.example.com"
const CODE_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
```

`CODE_ALPHABET` **must** match `NORAY_OID_CHARSET` exactly, and must stay empty
while `NORAY_HOST` points at a server using the default alphabet. It is what
tells the lobby that upper-casing a typed code is safe. Set it against a
mixed-case server and every join fails, because the client will confidently
correct `eYQ43` to `EYQ43` and the server has never heard of that room.

Setting it also makes the lobby group codes in threes instead of fives, set them
larger on screen, drop the hyphens and spaces people add when reading one out,
and stop warning that codes are case-sensitive.

## The rest of the checklist

Two lines are in plain text files the game cannot correct for itself. When you
flip the switch, drop the case clause from both:

- `packaging/README-linux.txt`
- `packaging/README-windows.txt`

> If a join hangs, check the code is exactly right — codes are case-sensitive.

Then cut a release, so the launcher carries the new server address out to
everyone who already has the game.

## Keeping it

- `ghcr.io/foxssake/noray:main` is a moving tag. Pin it to a release if upstream
  publishes one; otherwise know that `docker compose pull` can change behaviour.
- If you ever move the server or change the alphabet, **every code in flight
  dies** and so does every older build, since the host address is compiled in.
  Worth doing at the same time as a release rather than on its own.

[noray]: https://github.com/foxssake/noray
