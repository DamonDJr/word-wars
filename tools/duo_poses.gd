extends RefCounted
## The iPhone Duo's poses as geometry, shared by `duoshots.gd` and `duoprobe.gd`.
##
## Its own file, and a `RefCounted` rather than a `SceneTree`, for two reasons.
## The shared-table one is `ad_words.gd`'s: two copies of these numbers means the
## render and the measurement can drift apart, and the one nobody is looking at
## is the one that goes stale. The `RefCounted` one is mechanical — a
## `preload` of a script that `extends SceneTree` stops the preloading script's
## `_init` from ever running, silently and with no error, which cost an
## afternoon.
##
## ## Where the viewport sizes come from
##
## `expand` stretching pins whichever axis runs out first against the design
## space, so each pose's viewport is the panel divided by the pinned axis's
## scale factor:
##
##   folded  1398x2034px  2034/1440 = 1.4125 pins height ->  990 x 1440
##   open    1878x2670px  2670/1440 = 1.8542 pins height -> 1013 x 1440
##   iPad    1640x2360px  2360/1440 = 1.6389 pins height -> 1001 x 1440
##   open, landscape, against the 1280x720 space:
##           2670x1878px  1878/720  = 2.6083 pins height -> 1280 x 900
##
## The three portrait figures are the whole problem in one place: 990 and 1013
## against an iPad's 1001. Three devices, one of them 5.4 inches across, all
## landing within 2% of each other — which is why `_measure_device`'s single
## aspect threshold cannot separate them.
##
## ## What is guessed here and what is not
##
## The viewport sizes are arithmetic and are as good as the published panel
## dimensions. The App Store pixel sizes are Apple's own: 1398x2034 for the outer
## display and 2007x2853 for the inner one, each in both orientations. The inner
## display's panel is 1878x2670 — the system renders at 2007x2853 and scales down
## — and the two have the same aspect to the fourth decimal, so every viewport
## below is the same either way.
##
## The **insets and the fold are invented**. Apple publishes neither as numbers:
## they come from the system at run time (`safeAreaInsets` and the reserved
## regions). What is known from the Duo design guide is the *shape* — the Dynamic
## Island and status bar stand in a column down the trailing edge on the outer
## display and in landscape on the inner one, the inner display in portrait keeps
## horizontal bars, and a partly folded inner display is divided by a band across
## its middle. The numbers here are plausible sizes for those shapes, chosen so a
## layout that respects them respects the real ones with room to spare. They are
## in design units, the unit the game measures them in.

## `units` is the design-space viewport the game is handed, `px` the panel behind
## it, `safe` the insets in design units as (top, bottom, left, right).
##
## `wide` is the window being wider than it is tall; `regular` is Apple's width
## class; `fold` is whether the device is partly open — the crease itself is
## `fold_band` in `game.gd`, and empty when the device is flat — so a pose is everything the layout reads and
## nothing it does not.
const POSES := {
	# --- the five a player can actually be in -------------------------------
	"iphone": {
		"units": Vector2i(720, 1561), "px": Vector2i(1179, 2556),
		"portrait": true, "tablet": false, "regular": false, "wide": false,
		"safe": Vector4(108.0, 62.0, 0.0, 0.0), "fold": false,
		"ppi": 460.0, "label": "iPhone 15 — 6.1in"},
	# The cover display is tablet-*shaped* and compact, and gets the one board of
	# the phone layout: two boards side by side on five inches came out too small
	# to read on the first Duo the game met (2026-10-30).
	"outer-portrait": {
		"units": Vector2i(990, 1440), "px": Vector2i(1398, 2034),
		"portrait": true, "tablet": false, "regular": false, "wide": false,
		"safe": Vector4(0.0, 44.0, 0.0, 100.0), "fold": false,
		"ppi": 460.0, "label": "Duo closed, outer display — 5.4in"},
	"inner-portrait": {
		"units": Vector2i(1013, 1440), "px": Vector2i(2007, 2853),
		"portrait": true, "tablet": true, "regular": true, "wide": false,
		"safe": Vector4(30.0, 44.0, 0.0, 0.0), "fold": false,
		"ppi": 459.0, "label": "Duo open, portrait — 7.6in"},
	"inner-landscape": {
		"units": Vector2i(1280, 900), "px": Vector2i(2853, 2007),
		"portrait": true, "tablet": true, "regular": true, "wide": true,
		"safe": Vector4(0.0, 40.0, 0.0, 84.0), "fold": false,
		"ppi": 459.0, "label": "Duo open, landscape — 7.6in"},
	# --- partly folded: the same panel with a band down or across it --------
	"inner-portrait-laptop": {
		"units": Vector2i(1013, 1440), "px": Vector2i(2007, 2853),
		"portrait": true, "tablet": true, "regular": true, "wide": false,
		"safe": Vector4(30.0, 44.0, 0.0, 0.0),
		# Across the middle of the long side, like a laptop's hinge: the top
		# half stands up and the bottom half lies on the table.
		"fold": true,
		"ppi": 459.0, "label": "Duo as a laptop — portrait, folded"},
	"inner-landscape-book": {
		"units": Vector2i(1280, 900), "px": Vector2i(2853, 2007),
		"portrait": true, "tablet": true, "regular": true, "wide": true,
		"safe": Vector4(0.0, 40.0, 0.0, 84.0),
		# Down the middle, like the spine of a book held open in two hands.
		"fold": true,
		"ppi": 459.0, "label": "Duo as a book — landscape, folded"},
	# --- the shapes the first cut of this table compared ---------------------
	# Kept so `duoshots.sh` and the sheets in docs/duo still mean what they did.
	"cover-phone": {
		"units": Vector2i(990, 1440), "px": Vector2i(1398, 2034),
		"portrait": true, "tablet": false, "regular": false, "wide": false,
		"safe": Vector4(0.0, 44.0, 0.0, 0.0), "fold": false,
		"ppi": 460.0, "label": "Duo folded, phone layout — 5.4in"},
	"cover-tablet": {
		"units": Vector2i(990, 1440), "px": Vector2i(1398, 2034),
		"portrait": true, "tablet": true, "regular": false, "wide": false,
		"safe": Vector4(0.0, 44.0, 0.0, 0.0), "fold": false,
		"ppi": 460.0, "label": "Duo folded, tablet layout — 5.4in"},
	"open-tablet": {
		"units": Vector2i(1013, 1440), "px": Vector2i(1878, 2670),
		"portrait": true, "tablet": true, "regular": true, "wide": false,
		"safe": Vector4(0.0, 44.0, 0.0, 0.0), "fold": false,
		"ppi": 430.0, "label": "Duo open, tablet layout — 7.6in"},
	"open-phone": {
		"units": Vector2i(1013, 1440), "px": Vector2i(1878, 2670),
		"portrait": true, "tablet": false, "regular": false, "wide": false,
		"safe": Vector4(0.0, 44.0, 0.0, 0.0), "fold": false,
		"ppi": 430.0, "label": "Duo open, phone layout — 7.6in"},
	"open-land": {
		"units": Vector2i(1280, 900), "px": Vector2i(2670, 1878),
		"portrait": false, "tablet": true, "regular": true, "wide": true,
		"safe": Vector4(0.0, 44.0, 0.0, 0.0), "fold": false,
		"ppi": 430.0, "label": "Duo open, landscape — 7.6in"},
	# --- compact, held wide -----------------------------------------------------
	# An iPhone never gets here, being held to portrait, and is in the table so
	# the claim "a wide layout is no better there" is a number that can be run. A
	# Duo does: a phone with a hinge is never locked, because iOS honours a lock
	# on the inner display by scaling the game down.
	"iphone-landscape": {
		"units": Vector2i(1558, 720), "px": Vector2i(2556, 1179),
		"portrait": true, "tablet": true, "regular": false, "wide": true,
		"safe": Vector4(0.0, 38.0, 0.0, 0.0), "fold": false,
		"ppi": 460.0, "label": "iPhone 15, landscape — 6.1in"},
	"outer-landscape": {
		"units": Vector2i(1280, 880), "px": Vector2i(2034, 1398),
		"portrait": true, "tablet": true, "regular": false, "wide": true,
		"safe": Vector4(0.0, 40.0, 0.0, 84.0), "fold": false,
		"ppi": 460.0, "label": "Duo closed, landscape — 5.4in"},
	# --- the desktop, which is not a touch device -----------------------------
	# The one pose with no fingers: it is here so that "nothing about the desktop
	# changed" is a render rather than a belief.
	"desktop": {
		"units": Vector2i(1280, 720), "px": Vector2i(1280, 720),
		"portrait": false, "tablet": true, "regular": true, "wide": false,
		"touch": false,
		"safe": Vector4(0.0, 0.0, 0.0, 0.0), "fold": false,
		"ppi": 110.0, "label": "Desktop window — 1280x720"},
	"ipad": {
		"units": Vector2i(1001, 1440), "px": Vector2i(1640, 2360),
		"portrait": true, "tablet": true, "regular": true, "wide": false,
		"safe": Vector4(0.0, 24.0, 0.0, 0.0), "fold": false,
		"ppi": 264.0, "label": "iPad Air — 10.9in"},
	"ipad-landscape": {
		"units": Vector2i(1280, 959), "px": Vector2i(2360, 1640),
		"portrait": true, "tablet": true, "regular": true, "wide": true,
		"safe": Vector4(0.0, 24.0, 0.0, 0.0), "fold": false,
		"ppi": 264.0, "label": "iPad Air, landscape — 10.9in"},
	# A window dragged wide and short: iPad Stage Manager, or Split View given the
	# larger half. 16:9 is the design space itself, so this is the shortest glass
	# the wide layout is ever asked to fill — 720 tall, with every summary and
	# menu that is laid out for 960 having to scroll rather than shrink.
	"ipad-window-wide": {
		"units": Vector2i(1280, 716), "px": Vector2i(2388, 1336),
		"portrait": true, "tablet": true, "regular": true, "wide": true,
		"safe": Vector4(0.0, 0.0, 0.0, 0.0), "fold": false,
		"ppi": 264.0, "label": "iPad window, 16:9 — 10.9in"},
}


## Put a pose's whole device model onto a game node, the way `_apply_orientation`
## and its two measuring functions would have on the real thing.
##
## One function for every tool that renders or probes a pose, so the renders and
## the measurements cannot disagree about what a pose *is*: it used to be four
## lines copied into each of them, and the day `wide` was added was the day the
## copies stopped agreeing.
static func apply(game: Node, spec: Dictionary) -> void:
	var safe: Vector4 = spec["safe"]
	game._wide_window = bool(spec["wide"])
	game.touch = bool(spec.get("touch", true))
	# `portrait` is the touch family of layouts, which is true for every pose here
	# except the desktop one: every pose in this table has fingers on it.
	game.portrait = bool(spec["portrait"])
	game.tablet = bool(spec["tablet"])
	game.regular = bool(spec["regular"])
	game.safe_top = safe.x
	game.safe_bottom = safe.y
	game.safe_left = safe.z
	game.safe_right = safe.w
	# The crease comes from the game's own function, so a render and the running
	# game agree about where it is.
	game.fold = game.fold_band(Vector2(spec["units"])) if bool(spec["fold"]) else Rect2()


## One design unit, in inches: the panel pixels it is worth, over the panel's
## density. The number that makes the rest of the comparison honest — a unit is
## 0.0036" on an iPhone 15, 0.0031" on the cover screen and 0.0043" on the inner
## one, so two layouts measuring the same in units are a third apart on glass.
static func unit_inches(pose: String) -> float:
	var s: Dictionary = POSES[pose]
	var px: Vector2i = s["px"]
	var units: Vector2i = s["units"]
	return (float(px.x) / float(units.x)) / float(s["ppi"])
