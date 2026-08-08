#!/usr/bin/env python3
"""Regenerate data/words.txt and data/common.txt.

Two lists serve two different jobs:

  words.txt   Permissive validity set. Decides whether what the player typed
              counts as a word. Generous on purpose — knowing an obscure word
              should be rewarded, not rejected.

  common.txt  Frequency-ordered vocabulary. Drives what the CPU reaches for and
              decides whether a prefix is fair to stamp on a block. Scrubbed of
              the transcription noise and given names that ride along in a
              subtitle corpus, because the CPU playing "OOOO" reads as a bug.

Usage:  python3 tools/build_wordlists.py     (needs network; writes ../data)
"""

import re
import sys
import urllib.request
from pathlib import Path

SOURCES = {
    "words_alpha": "https://raw.githubusercontent.com/dwyl/english-words/master/words_alpha.txt",
    "freq": "https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/en/en_50k.txt",
    "names": "https://raw.githubusercontent.com/dominictarr/random-name/master/first-names.txt",
    "top10k": "https://raw.githubusercontent.com/first20hours/google-10000-english/master/google-10000-english-usa-no-swears.txt",
}

MIN_LEN = 3
MAX_LEN = 14

# The subtitle corpus strips apostrophes, so contractions arrive as fragments.
# Several land in the top few hundred entries, which is exactly where the CPU
# looks — "CPU: SHOULDN" reads as a bug in the same way "CPU: OOOO" did.
CONTRACTION_FRAGMENTS = {
    "ain", "aren", "couldn", "didn", "doesn", "hadn", "hasn", "isn", "mustn",
    "needn", "shan", "shouldn", "wasn", "weren", "wouldn", "dont", "doesnt",
    "didnt", "cant", "isnt", "arent", "wasnt", "werent", "hasnt", "havent",
    "hadnt", "shouldnt", "wouldnt", "couldnt", "mustnt", "youre", "youve",
    "youll", "theyre", "theyve", "thats", "whats", "hes", "shes", "theres",
    "heres", "aint", "yall", "cmon", "til", "gimme", "lemme",
}

# Spoken-register spellings that are not words a duel should accept from the CPU.
COLLOQUIAL = {"gonna", "wanna", "gotta", "kinda", "sorta", "outta", "dunno", "lotta"}

INTERJECTIONS = {
    "aah", "aha", "ahem", "ahh", "argh", "aww", "blah", "doh", "duh", "eek",
    "eep", "erm", "gah", "grr", "hah", "heh", "hey", "hmm", "hmmm", "huh",
    "mmm", "mmmm", "nah", "naw", "oof", "ooh", "oooh", "ooo", "oops", "ow",
    "phew", "pff", "psst", "shh", "shhh", "tsk", "ugh", "uh", "uhh", "uhm",
    "um", "umm", "ummm", "wah", "whoa", "woo", "woah", "yay", "yeah", "yep",
    "yikes", "yo", "yup", "aye", "gee", "hee", "hoo", "doo", "boo", "mwah",
    "nope", "meh", "ha", "haha", "hahaha", "la", "lalala", "na", "tada",
}


def fetch(url: str) -> list[str]:
    with urllib.request.urlopen(url, timeout=120) as r:
        return r.read().decode("utf-8", "ignore").splitlines()


def typeable(w: str) -> bool:
    return MIN_LEN <= len(w) <= MAX_LEN and w.isalpha() and w.isascii()


def main() -> int:
    data_dir = Path(__file__).resolve().parent.parent / "data"
    data_dir.mkdir(exist_ok=True)

    valid = {w.strip().lower() for w in fetch(SOURCES["words_alpha"])}
    valid = {w for w in valid if typeable(w)}

    names = {n.strip().lower() for n in fetch(SOURCES["names"]) if n.strip()}
    top10k = {w.strip().lower() for w in fetch(SOURCES["top10k"]) if w.strip()}

    def clean(w: str) -> bool:
        if re.search(r"(.)\1\1", w):        # oooo, aaah
            return False
        if not re.search(r"[aeiouy]", w):   # shh, mrs, gps
            return False
        if w in INTERJECTIONS or w in CONTRACTION_FRAGMENTS or w in COLLOQUIAL:
            return False
        # Short given names only, so long words that double as names survive.
        if len(w) <= 6 and w in names and w not in top10k:
            return False
        return True

    common, seen = [], set()
    for line in fetch(SOURCES["freq"]):
        parts = line.split()
        if not parts:
            continue
        w = parts[0].strip().lower()
        if w in seen or not typeable(w) or w not in valid or not clean(w):
            continue
        seen.add(w)
        common.append(w)

    (data_dir / "words.txt").write_text("\n".join(sorted(valid)) + "\n")
    (data_dir / "common.txt").write_text("\n".join(common) + "\n")
    print(f"words.txt  {len(valid):>7} words")
    print(f"common.txt {len(common):>7} words (frequency order)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
