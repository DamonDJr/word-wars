#!/usr/bin/env python3
"""Build the HTML5 playable — one self-contained file, for ad networks.

    tools/playable.py

Writes build/ads/playable/word-wars-playable.html and reports its size.

## Why this is not a Godot web export

The obvious move is `--export-release "Web"` and ship that. It cannot work here
for two separate reasons, either of which is fatal on its own.

**Size.** A Godot 4 web export is the engine wasm plus the pack — tens of
megabytes before the 350,000-word dictionary is counted. Google's playable slot
is 5MB for the whole thing, and PixelPicked embeds it in a page somebody is
expected to wait for. The dictionary alone is 3.5MB.

**The build does not run there.** The game links Game Center, StoreKit, AdMob and
the EOS runtime. A web build has none of those, and the parts of `game.gd` that
ask about them are not optional paths — they are the match, the store and the
save.

So this is a separate, tiny implementation of the one mechanic, written to be
honest about what the real game does rather than to be the real game. Same rule,
same palette, same board furniture, same keyboard. It is an advert that happens
to be playable, and it says so at the end.

## Self-contained, literally

No fonts, no images, no network. Ad networks serve a playable into a sandboxed
iframe that may have no outbound access at all, and a Google Fonts link that
fails leaves the type falling back mid-session. Everything here is a system font
stack and CSS-drawn furniture, so the file works opened from disk with the wifi
off — which is also how it should be tested.

## The opponent is scripted, and that is the honest simplification

In the real game the stamp on an incoming block is minted from the attacker's
word by `WordBank.stamp_from_tail`, which needs the dictionary to guarantee the
fragment is answerable. There is no dictionary here, so the three stamps the
player is asked to answer are fixed, chosen for having the most common answers
in the real word list, and their answer sets are embedded.

What is *not* faked: the player's own word genuinely determines the stamp that
lands on the rival's board. Type CARPET and the rival gets PET. That is the rule
the ad is selling, so that is the part that had to be real.
"""

import os
import re
import subprocess
import sys

OUT_DIR = "build/ads/playable"
OUT = os.path.join(OUT_DIR, "word-wars-playable.html")

# Where the game is, for the call to action.
STORE_URL = "https://apps.apple.com/us/app/word-wars-typing-battle/id6802900966"

# The three stamps, in the order they are asked.
#
# Picked by counting answers in the real common list rather than by taste: STA,
# CAR and TRA are three of the richest three-letter prefixes in the top 14,000
# words, and all three are concrete and everyday. STA goes first because START
# is the most obvious word in English and the first round of a playable must not
# be a puzzle — it has to be a success.
STAMPS = ["STA", "CAR", "TRA"]

# Answers are 5-10 letters and well inside the frequency list, so nobody is
# asked for vocabulary they do not have.
MIN_LEN, MAX_LEN, MAX_RANK = 5, 10, 14000
# Per stamp. Enough that anything reasonable is accepted, few enough to stay small.
PER_STAMP = 90


def editorial_filter():
    """The substring list from tools/ad_words.gd, read rather than restated.

    A playable is published ad content exactly as much as a video is, so it gets
    the same editorial line — and gets it from the same file, so there is one
    copy of the policy rather than a fourth that goes stale."""
    src = open("tools/ad_words.gd").read()
    body = src[src.index("const NOT_IN_AN_AD"):]
    body = body[body.index("["):body.index("]")]
    return [m.group(1) for m in re.finditer(r'"([^"]+)"', body)]


# A stamp has to be answerable, which is the whole subject of the first devlog
# and the one rule this file cannot cheat on. The real game asks the dictionary;
# there is no dictionary here, so every stamp the playable can possibly mint is
# worked out now and embedded as a lookup.
#
# Same floor as the game's own `STAMP_MIN_COMMON`.
STAMP_MIN_COMMON = 6


def prefix_counts(common):
    counts = {}
    for w in common:
        for n in (1, 2, 3, 4):
            if len(w) > n:
                counts[w[:n]] = counts.get(w[:n], 0) + 1
    return counts


def stamp_for(word, counts):
    """The fragment `word` brands onto the rival's block.

    A cut-down `WordBank.stamp_from_tail`: true suffixes longest-first, then
    windows one or two letters in from the end, never starting at the front.
    Without it the playable takes the last three letters blindly and CARRY
    brands RRY — a fragment no English word begins with, in an advert whose
    entire claim is that the fragment is answerable."""
    for n in (4, 3, 2):
        if len(word) > n and counts.get(word[-n:], 0) >= STAMP_MIN_COMMON:
            return word[-n:]
    for shift in (1, 2):
        for n in (4, 3, 2):
            start = len(word) - shift - n
            if start < 1:
                continue
            s = word[start:start + n]
            # A shifted window is harsher than an honest suffix, so it has to
            # clear double the floor — exactly as the game does it.
            if counts.get(s, 0) >= STAMP_MIN_COMMON * 2:
                return s
    best = max(word, key=lambda c: counts.get(c, 0))
    return best


def answers():
    bad = editorial_filter()
    common = [w.strip().lower() for w in open("data/common.txt") if w.strip()]
    out = {}
    for stamp in STAMPS:
        s = stamp.lower()
        hits = []
        for w in common[:MAX_RANK]:
            if len(w) < MIN_LEN or len(w) > MAX_LEN or not w.isalpha():
                continue
            if not w.startswith(s):
                continue
            if any(b in w for b in bad):
                continue
            hits.append(w)
            if len(hits) >= PER_STAMP:
                break
        if len(hits) < 12:
            sys.exit("stamp %s only found %d answers — pick another" % (stamp, len(hits)))
        out[stamp] = hits

    counts = prefix_counts(common)
    stamps = {}
    for hits in out.values():
        for w in hits:
            stamps[w] = stamp_for(w, counts).upper()
    return out, stamps


PAGE = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<title>Word Wars</title>
<style>
/* Word Wars' own palette, from scripts/game.gd. */
:root{
  --void:#0b1020; --panel:#101734; --edge:#26305c;
  --ink:#e6ecff; --dim:#7787b5;
  --you:#7bdff2; --them:#ff8fa3; --hit:#ffd166;
}
*{box-sizing:border-box;-webkit-tap-highlight-color:transparent}
html,body{height:100%;margin:0;overflow:hidden}
body{
  background:var(--void);
  background-image:radial-gradient(60rem 30rem at 70% -10%,rgba(123,223,242,.10),transparent 60%),
                   radial-gradient(50rem 30rem at 10% 20%,rgba(255,143,163,.07),transparent 60%);
  color:var(--ink);
  font:700 16px/1.4 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;
  display:flex;align-items:center;justify-content:center;
  user-select:none;
}
#stage{
  width:100%;height:100%;max-width:520px;max-height:940px;
  display:flex;flex-direction:column;padding:10px 12px 12px;gap:8px;
}

/* --- rival ------------------------------------------------------------- */
#rival{display:flex;flex-direction:column;align-items:center;gap:6px;flex:none}
#rivalName{font-size:11px;letter-spacing:.16em;color:var(--them)}
#rivalBoard{
  display:flex;flex-wrap:wrap;gap:4px;justify-content:center;align-items:flex-start;
  min-height:34px;width:100%;max-width:300px;
}

/* --- your board -------------------------------------------------------- */
#well{
  flex:1;min-height:0;border:1px solid var(--edge);border-radius:12px;
  background:linear-gradient(180deg,rgba(20,26,54,.65),rgba(11,16,32,.65));
  padding:10px;display:flex;flex-direction:column-reverse;align-items:center;
  gap:6px;position:relative;overflow:hidden;
}
.blk{
  border:2px solid var(--you);border-radius:9px;background:rgba(123,223,242,.06);
  color:var(--you);padding:10px 14px;font-size:19px;letter-spacing:.08em;
  transition:transform .18s ease,opacity .18s ease;
}
.blk.target{
  border-color:var(--hit);color:var(--hit);background:rgba(255,209,102,.10);
  animation:pulse 1.4s ease-in-out infinite;
}
@keyframes pulse{0%,100%{box-shadow:0 0 0 0 rgba(255,209,102,.35)}50%{box-shadow:0 0 0 7px rgba(255,209,102,0)}}
.blk.gone{transform:scale(.55);opacity:0}
.mini{
  border:2px solid var(--them);border-radius:6px;background:rgba(255,143,163,.08);
  color:var(--them);padding:5px 8px;font-size:12px;letter-spacing:.06em;
}
.mini.in{animation:drop .35s cubic-bezier(.2,.9,.3,1)}
@keyframes drop{from{transform:translateY(-22px);opacity:0}to{transform:none;opacity:1}}

/* --- prompt + input ---------------------------------------------------- */
#ask{text-align:center;font-size:13px;color:var(--dim);flex:none;min-height:18px}
#ask b{color:var(--hit)}
#line{
  flex:none;text-align:center;font-size:24px;letter-spacing:.06em;min-height:34px;
  color:var(--ink);border-bottom:2px solid var(--edge);padding-bottom:4px;
}
#line.bad{animation:shake .3s;border-bottom-color:var(--them)}
@keyframes shake{25%{transform:translateX(-7px)}75%{transform:translateX(7px)}}
#line .ghost{color:#3d486e}

/* --- keyboard ---------------------------------------------------------- */
#kb{flex:none;display:flex;flex-direction:column;gap:5px}
.row{display:flex;gap:4px;justify-content:center}
.key{
  flex:1;max-width:44px;padding:11px 0;border-radius:7px;text-align:center;
  background:var(--panel);border:1px solid var(--edge);color:var(--ink);font-size:15px;
}
.key:active{background:#1b2547}
.key.wide{max-width:64px;font-size:11px;color:var(--dim)}
#fire{
  margin-top:2px;padding:14px;border-radius:10px;text-align:center;font-size:16px;
  letter-spacing:.14em;background:rgba(123,223,242,.12);
  border:1px solid var(--you);color:var(--you);
}
#fire:active{background:rgba(123,223,242,.24)}

/* --- overlay ----------------------------------------------------------- */
#over{
  position:absolute;inset:0;display:none;flex-direction:column;
  align-items:center;justify-content:center;gap:14px;padding:24px;text-align:center;
  background:#070b18;z-index:5;
}
#over.show{display:flex}
#over h1{margin:0;font-size:30px;letter-spacing:-.02em}
#over p{margin:0;color:var(--dim);font-size:14px;max-width:24em;font-weight:400}
#cta{
  margin-top:6px;padding:15px 26px;border-radius:11px;background:var(--you);
  color:#06243b;font-size:17px;letter-spacing:.02em;
}
#cta:active{transform:translateY(1px)}
#sub{font-size:11px;letter-spacing:.14em;color:var(--dim)}
</style>
</head>
<body>
<div id="stage">
  <div id="rival">
    <div id="rivalName">RIVAL</div>
    <div id="rivalBoard"></div>
  </div>
  <div id="well"></div>
  <div id="ask"></div>
  <div id="line"></div>
  <div id="kb"></div>
  <div id="over">
    <h1>Your endings<br>became their problem.</h1>
    <p>That is the whole game. Real matches, three lives, and a board that
       fills faster than you can clear it.</p>
    <div id="cta">Get Word Wars &mdash; Free</div>
    <div id="sub">iPHONE &middot; iPAD</div>
  </div>
</div>

<script>
"use strict";
var WORDS = __WORDS__;
var STAMPS = __STAMPS__;
var STAMP_OF = __STAMPOF__;
var STORE = "__STORE__";

/* The only integration point. Ad networks hand a playable different ways to
   open the store, so all of them are tried in the order they are usually
   available, and the plain link is the floor. Replace or extend this and
   nothing else needs to change. */
function goToStore(){
  try{ if(window.mraid && mraid.open){ mraid.open(STORE); return; } }catch(e){}
  try{ if(window.FbPlayableAd && FbPlayableAd.onCTAClick){ FbPlayableAd.onCTAClick(); return; } }catch(e){}
  try{ if(window.ExitApi && ExitApi.exit){ ExitApi.exit(); return; } }catch(e){}
  window.open(STORE, "_blank");
}

var well = document.getElementById("well"),
    rivalBoard = document.getElementById("rivalBoard"),
    ask = document.getElementById("ask"),
    line = document.getElementById("line"),
    over = document.getElementById("over");

var round = 0, typed = "", target = null, idle = null, locked = false;

function stamp(word){
  /* The player's own ending genuinely decides what the rival gets — that is the
     rule this advert is selling, so it is the part that had to be real. The
     fragment itself was chosen at build time by the same suffix-then-near-tail
     search the game uses, so it is always something words actually start with. */
  return STAMP_OF[word] || word.slice(-3).toUpperCase();
}

function layout(){
  well.innerHTML = "";
  var filler = ["ED","ION","LY"];
  for(var i=0;i<2;i++){
    var b = document.createElement("div");
    b.className = "blk"; b.textContent = filler[(round+i)%filler.length];
    well.appendChild(b);
  }
  target = document.createElement("div");
  target.className = "blk target";
  target.textContent = STAMPS[round];
  well.appendChild(target);
  ask.innerHTML = 'Type a word that <b>starts with ' + STAMPS[round] + '</b>';
  typed = ""; draw(); armHint();
}

function draw(){
  line.textContent = typed;
  if(!typed){
    var g = document.createElement("span");
    g.className = "ghost"; g.textContent = STAMPS[round] + "…";
    line.appendChild(g);
  }
}

function armHint(){
  clearTimeout(idle);
  /* A playable must not be losable. After five seconds of nothing, it shows a
     word that works — the point is the mechanic landing, not the vocabulary
     test. */
  idle = setTimeout(function(){
    var pool = WORDS[STAMPS[round]];
    ask.innerHTML = 'Try <b>' + pool[0].toUpperCase() + '</b>';
  }, 5000);
}

function press(ch){
  if(locked) return;
  if(typed.length < 12){ typed += ch; draw(); armHint(); }
}
function del(){ if(!locked){ typed = typed.slice(0,-1); draw(); } }

function fire(){
  if(locked) return;
  var w = typed.toLowerCase();
  var pool = WORDS[STAMPS[round]];
  if(pool.indexOf(w) === -1){
    line.className = "bad";
    setTimeout(function(){ line.className = ""; }, 320);
    return;
  }
  locked = true; clearTimeout(idle);

  target.classList.add("gone");
  var out = stamp(w);
  ask.innerHTML = 'You sent them <b>' + out + '</b>';

  setTimeout(function(){
    var m = document.createElement("div");
    m.className = "mini in"; m.textContent = out;
    rivalBoard.appendChild(m);
    round++;
    setTimeout(function(){
      locked = false;
      if(round >= STAMPS.length){ finish(); } else { layout(); }
    }, 700);
  }, 260);
}

function finish(){ over.classList.add("show"); }

/* --- keyboard ---------------------------------------------------------- */
var rows = ["QWERTYUIOP","ASDFGHJKL","ZXCVBNM"];
var kb = document.getElementById("kb");
rows.forEach(function(r, i){
  var row = document.createElement("div"); row.className = "row";
  if(i === 2){
    var d = document.createElement("div");
    d.className = "key wide"; d.textContent = "DEL";
    d.addEventListener("click", del); row.appendChild(d);
  }
  r.split("").forEach(function(c){
    var k = document.createElement("div");
    k.className = "key"; k.textContent = c;
    k.addEventListener("click", function(){ press(c); });
    row.appendChild(k);
  });
  kb.appendChild(row);
});
var f = document.createElement("div");
f.id = "fire"; f.textContent = "FIRE";
f.addEventListener("click", fire); kb.appendChild(f);

document.addEventListener("keydown", function(e){
  if(over.classList.contains("show")) return;
  if(e.key === "Enter"){ fire(); e.preventDefault(); return; }
  if(e.key === "Backspace"){ del(); e.preventDefault(); return; }
  if(/^[a-zA-Z]$/.test(e.key)) press(e.key.toUpperCase());
});
document.getElementById("cta").addEventListener("click", goToStore);

layout();
</script>
</body>
</html>
"""


def main():
    if not os.path.exists("data/common.txt"):
        sys.exit("run from the repo root")
    os.makedirs(OUT_DIR, exist_ok=True)
    data, stamps = answers()

    import json
    page = (PAGE
            .replace("__STAMPOF__", json.dumps(stamps, separators=(",", ":")))
            .replace("__WORDS__", json.dumps(data, separators=(",", ":")))
            .replace("__STAMPS__", json.dumps(STAMPS, separators=(",", ":")))
            .replace("__STORE__", STORE_URL))
    with open(OUT, "w") as fh:
        fh.write(page)

    kb = os.path.getsize(OUT) / 1024.0
    print("--- %s" % OUT)
    for s in STAMPS:
        print("    %s: %d answers" % (s, len(data[s])))
    print("    %.1f KB  (Google's playable limit is 5120 KB)" % kb)
    if kb > 5120:
        sys.exit("over the 5MB playable limit")


if __name__ == "__main__":
    main()
