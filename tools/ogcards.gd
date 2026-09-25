extends SceneTree
## Renders the link-preview images and writes the share pages that carry them.
##
##     godot --script tools/ogcards.gd
##
## Output lands in `docs/s/`, which is the GitHub Pages site — so what this
## writes is committed and served, rather than being a working file. Run it when
## the copy below changes and commit what falls out.
##
## **Do not pass `--headless`.** These are SubViewport renders and the dummy
## renderer saves them blank, exactly as it does for `tools/cardshots.gd`.
##
## ## Why this exists at all
##
## A share used to go out as the player's sentence with the App Store URL glued
## to the end of it. Facebook, Threads and LinkedIn all do the same thing with
## that: pull the URL out, fetch it, render whatever it says about itself, and
## throw the sentence and the attached picture away. What the App Store says
## about itself is a grey box with an app name in it — so a card that took a
## whole file to compose arrived as a link and nothing else.
##
## The fix is to give them a URL that is worth scraping. These pages are it:
## static files with real `og:` tags, an image sized the way a scraper wants it,
## and a redirect through to the store for anybody who taps.
##
## ## Why the set is this small
##
## One page per mode-and-verdict, and no finer. The player's actual numbers
## cannot be in the preview — see the note in `scripts/og_card.gd` — so the only
## thing a page can vary on is what is knowable before the run happens. Six
## covers it: the two survival-or-daily modes, and won-or-lost across the two
## kinds of match.
##
## The numbers still travel. They go in the query string and the page reads them
## out, so the person who taps the link sees the actual run. `_share_url()` in
## `game.gd` is the other half of this.

const OUT := "res://docs/s"

## The one place the Pages address is written down in the tooling. `share.gd`
## holds the game's copy of it; the two have to agree, and `sharetest.gd`
## checks that they do.
const SITE := "https://damondjr.github.io/word-wars"
const STORE_URL := "https://apps.apple.com/app/id6802900966"

## The set. Each becomes `docs/s/<slug>/index.html` and `docs/s/og/<slug>.png`.
##
## `word` is what the tiles spell. It is a real word every time, chosen to mean
## something about the mode — the tiles are the only part of the picture that
## reads at feed size, and spending them on "SURVIVAL" would waste the one
## element that makes a stranger understand the game.
##
## `title` and `blurb` are the scraped preview's two lines. They are written for
## somebody who has never heard of this game and is not looking for it, which
## rules out every piece of shorthand the game uses about itself.
const PAGES := [
	{
		"slug": "survival",
		"mode": "Survival",
		"accent": "#f94144",
		"word": "ENDURANCE",
		"dare": "how long could you last?",
		"title": "Somebody just posted a Word Wars survival run",
		"blurb": "One board, no opponent, and it never stops coming."
			+ " Think you can last longer?",
	},
	{
		"slug": "daily",
		"mode": "Daily Board",
		"accent": "#ffd166",
		"word": "TODAY",
		"dare": "everybody gets the same board",
		"title": "There is a score to beat on today's Word Wars board",
		"blurb": "One board a day, the same one for everybody, and it is gone"
			+ " tomorrow. Go and beat it.",
	},
	{
		"slug": "versus-won",
		"mode": "Versus",
		"accent": "#c77dff",
		"word": "CHECKMATE",
		"dare": "think you can beat that?",
		"title": "Somebody just won a Word Wars match",
		"blurb": "Type a word and its last letters land on their board."
			+ " Whatever they play comes straight back at you.",
	},
	{
		"slug": "versus-lost",
		"mode": "Versus",
		"accent": "#c77dff",
		"word": "REMATCH",
		"dare": "somebody go and settle it",
		"title": "Somebody just lost a Word Wars match",
		"blurb": "Type a word and its last letters land on their board."
			+ " Somebody go and take them down.",
	},
	{
		"slug": "solo-won",
		"mode": "Solo",
		"accent": "#7bdff2",
		"word": "CHECKMATE",
		"dare": "think you can beat that?",
		"title": "Somebody just beat a Word Wars opponent",
		"blurb": "Type a word and its last letters land on their board."
			+ " Whatever they play comes straight back at you.",
	},
	{
		"slug": "solo-lost",
		"mode": "Solo",
		"accent": "#7bdff2",
		"word": "REMATCH",
		"dare": "somebody go and settle it",
		"title": "Somebody just lost a Word Wars match",
		"blurb": "Type a word and its last letters land on their board."
			+ " Somebody go and take them down.",
	},
]


func _init() -> void:
	await process_frame

	# The fonts the game builds for itself, built the same way. Cheaper and far
	# less fragile than standing up `main.tscn` to read them off it — this tool
	# draws four shapes and needs nothing else the game knows.
	var font: Font = load("res://scripts/fonts.gd").body()
	var bold: Font = load("res://scripts/fonts.gd").bold()
	var title: Font = load("res://scripts/fonts.gd").display()

	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("%s/og" % OUT))

	var card_script := load("res://scripts/og_card.gd")
	for page: Dictionary in PAGES:
		var slug := String(page["slug"])
		var png := "%s/og/%s.png" % [OUT, slug]
		var painter: Node = card_script.new(font, bold, title)
		get_root().add_child(painter)
		var ok: bool = await painter.render(String(page["mode"]),
			Color(String(page["accent"])), String(page["word"]),
			String(page["dare"]), png)
		painter.queue_free()

		var dir := "%s/%s" % [OUT, slug]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		var html := _page(page)
		var f := FileAccess.open("%s/index.html" % dir, FileAccess.WRITE)
		if f == null:
			push_warning("[og] could not write %s/index.html" % dir)
			continue
		f.store_string(html)
		f.close()
		print("[og] %-12s %s  +  %s/index.html" % [slug,
			png if ok else "IMAGE FAILED", dir])

	print("[og] %d pages under %s — commit them" % [PAGES.size(), OUT])
	quit(0)


## One share page.
##
## Everything the player's run put in the query string is read and written with
## `textContent`, never `innerHTML`. That is not a style preference: a share URL
## is a string that has been out of our hands and back, and the rival name in it
## is whatever somebody typed into Game Center. `innerHTML` here would be a
## stored-XSS hole on our own domain, reachable by anyone who can talk a player
## into tapping a link.
func _page(p: Dictionary) -> String:
	var slug := String(p["slug"])
	var url := "%s/s/%s/" % [SITE, slug]
	var img := "%s/s/og/%s.png" % [SITE, slug]
	var title := _esc(String(p["title"]))
	var blurb := _esc(String(p["blurb"]))
	var accent := String(p["accent"])

	return """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<meta name="description" content="{blurb}">

<!-- Written by tools/ogcards.gd. Edit that, not this. -->

<meta property="og:type" content="website">
<meta property="og:site_name" content="Word Wars: Typing Battle">
<meta property="og:title" content="{title}">
<meta property="og:description" content="{blurb}">
<meta property="og:url" content="{url}">
<meta property="og:image" content="{img}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:image:alt" content="A Word Wars result card">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="{title}">
<meta name="twitter:description" content="{blurb}">
<meta name="twitter:image" content="{img}">

<!-- So a tap on a phone goes to the store without a second decision, while a
     desktop scraper and a desktop visitor both still get a real page. -->
<meta name="apple-itunes-app" content="app-id=6802900966">

<link rel="stylesheet" href="../../style.css">
<style>
  :root { --accent: {accent}; }
  .result { text-align: center; padding: 1.5rem 1rem 2rem; }
  .result .headline { font-size: 4rem; line-height: 1; font-weight: 700;
    color: var(--ink); margin: .2rem 0; }
  .result .note, .result .badge { text-transform: uppercase;
    letter-spacing: .12em; font-size: .78rem; }
  .result .note { color: var(--dim); }
  .result .badge { display: inline-block; margin-top: .6rem;
    padding: .45rem 1rem; border: 2px solid var(--accent); border-radius: 999px;
    color: var(--accent); }
  .tiles { display: flex; flex-wrap: wrap; gap: .3rem; justify-content: center;
    margin: 1.4rem 0 .4rem; }
  .tiles span { width: 2.6rem; height: 2.6rem; display: grid;
    place-items: center; border-radius: .5rem; font-weight: 700;
    color: #0b1020; background: var(--accent); }
  .cta { display: inline-block; margin-top: 1.6rem; padding: .9rem 2rem;
    border-radius: 999px; background: var(--accent); color: #0b1020;
    font-weight: 700; text-decoration: none; letter-spacing: .06em;
    text-transform: uppercase; }
  .dare { font-size: 1.3rem; font-weight: 700; color: var(--accent);
    text-transform: uppercase; letter-spacing: .04em; margin-top: 1.2rem; }
</style>
</head>
<body>
<main>
<header>
  <div class="mark" aria-hidden="true">
    <span class="blk w1">W</span><span class="blk w2">W</span>
    <span class="blk wide">TYPE</span>
  </div>
  <h1>Word Wars: Typing Battle</h1>
  <p class="meta">{mode}</p>
</header>

<div class="card result">
  <p class="note" id="mode-note">{blurb}</p>
  <p class="headline" id="headline" hidden></p>
  <p class="note" id="headline-note" hidden></p>
  <p class="badge" id="badge" hidden></p>
  <div class="tiles" id="tiles" hidden></div>
  <p class="note" id="word-note" hidden></p>
  <p class="dare" id="dare">{dare}</p>
  <a class="cta" href="{store}">Play free on the App Store</a>
</div>

<p class="lede">Type a word. Its last letters land on your opponent's board, and
they have to answer them. Whatever they play comes straight back at you.</p>

<footer>
  <a href="../../">Support</a> &middot;
  <a href="../../privacy.html">Privacy Policy</a> &middot;
  &copy; 2026 Damon J
</footer>
</main>

<script>
// The run that was shared, as the game put it in the query string. Every value
// lands through textContent — see the note in tools/ogcards.gd for why that is
// load-bearing rather than tidy.
(function () {
  var q = new URLSearchParams(location.search);
  function put(id, value) {
    if (!value) return false;
    var el = document.getElementById(id);
    el.textContent = value.slice(0, 120);
    el.hidden = false;
    return true;
  }
  var any = put('headline', q.get('h'));
  put('headline-note', q.get('n'));
  put('badge', q.get('b'));
  // The run's own dare replaces the mode's, which is already in the element.
  put('dare', q.get('d'));

  // Letters only, and not because of layout: these become elements, and the
  // one rule that keeps that safe is that nothing but A-Z ever gets here.
  var word = (q.get('w') || '').slice(0, 16).toUpperCase();
  if (/^[A-Z]+$/.test(word)) {
    var box = document.getElementById('tiles');
    for (var i = 0; i < word.length; i++) {
      var t = document.createElement('span');
      t.textContent = word[i];
      box.appendChild(t);
    }
    box.hidden = false;
    put('word-note', q.get('v'));
  }
  // With real numbers on the page the mode blurb is repetition, so it goes.
  if (any) document.getElementById('mode-note').hidden = true;
})();
</script>
</body>
</html>
""".format({
		"title": title, "blurb": blurb, "url": url, "img": img,
		"accent": accent, "mode": _esc(String(p["mode"])),
		"dare": _esc(String(p["dare"])).to_upper(), "store": STORE_URL,
	})


## HTML-escape, for the handful of strings above that land in attributes. They
## are ours and none of them currently contains a quote, which is exactly the
## reason to do it here rather than after the first one does.
func _esc(s: String) -> String:
	return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;") \
		.replace("\"", "&quot;")
