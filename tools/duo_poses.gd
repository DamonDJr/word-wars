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
## dimensions. The **safe-area insets are invented**: the Dynamic Island sits
## vertically on the *side* of both Duo panels, and the game has no `safe_left` /
## `safe_right` to put that in yet, so these show zero at the top and a
## home-indicator allowance at the bottom. The real thing will have furniture
## down one edge that none of this accounts for. Treat the horizontal margins as
## optimistic.

## `units` is the design-space viewport the game is handed, `px` the panel behind
## it, `safe` the (top, bottom) insets in design units.
##
## `cover-phone` and `cover-tablet` are the same device twice, and that pair is
## the point of the tool: the question is which of them a 5.4-inch cover screen
## should get, and the only honest way to answer it is to put them side by side.
const POSES := {
	"iphone": {
		"units": Vector2i(720, 1561), "px": Vector2i(1179, 2556),
		"portrait": true, "tablet": false, "safe": Vector2(108.0, 62.0),
		"ppi": 460.0, "label": "iPhone 15 — 6.1in"},
	"cover-phone": {
		"units": Vector2i(990, 1440), "px": Vector2i(1398, 2034),
		"portrait": true, "tablet": false, "safe": Vector2(0.0, 44.0),
		"ppi": 460.0, "label": "Duo folded, phone layout — 5.4in"},
	"cover-tablet": {
		"units": Vector2i(990, 1440), "px": Vector2i(1398, 2034),
		"portrait": true, "tablet": true, "safe": Vector2(0.0, 44.0),
		"ppi": 460.0, "label": "Duo folded, tablet layout — 5.4in"},
	"open-tablet": {
		"units": Vector2i(1013, 1440), "px": Vector2i(1878, 2670),
		"portrait": true, "tablet": true, "safe": Vector2(0.0, 44.0),
		"ppi": 430.0, "label": "Duo open, tablet layout — 7.6in"},
	"open-phone": {
		"units": Vector2i(1013, 1440), "px": Vector2i(1878, 2670),
		"portrait": true, "tablet": false, "safe": Vector2(0.0, 44.0),
		"ppi": 430.0, "label": "Duo open, phone layout — 7.6in"},
	"open-land": {
		"units": Vector2i(1280, 900), "px": Vector2i(2670, 1878),
		"portrait": false, "tablet": true, "safe": Vector2(0.0, 44.0),
		"ppi": 430.0, "label": "Duo open, landscape — 7.6in"},
	"ipad": {
		"units": Vector2i(1001, 1440), "px": Vector2i(1640, 2360),
		"portrait": true, "tablet": true, "safe": Vector2(0.0, 24.0),
		"ppi": 264.0, "label": "iPad Air — 10.9in"},
}


## One design unit, in inches: the panel pixels it is worth, over the panel's
## density. The number that makes the rest of the comparison honest — a unit is
## 0.0036" on an iPhone 15, 0.0031" on the cover screen and 0.0043" on the inner
## one, so two layouts measuring the same in units are a third apart on glass.
static func unit_inches(pose: String) -> float:
	var s: Dictionary = POSES[pose]
	var px: Vector2i = s["px"]
	var units: Vector2i = s["units"]
	return (float(px.x) / float(units.x)) / float(s["ppi"])
