extends Node
## The ad network, behind one door.
##
## Everything the rest of the game knows about advertising is the four things
## below: whether a break can be served, serve one, a signal when it is over,
## and go and fetch the next. Which network is behind that is deliberately not
## the match code's business — this file is the only one in the project that
## names AdMob, so changing networks is rewriting one file rather than auditing
## every screen that might have learned something about the last one.
##
## There is no drawing here and there must not be. An interstitial is a native
## view the SDK puts over the whole app; the game does not lay it out, does not
## size it and cannot draw over it. That is also what makes it full screen —
## the mock that stands in off-device is full screen for the same reason.

## Emitted once per attempt. `shown` is true only if an impression actually
## reached the player, which is the difference between a break that was served
## and a break that was asked for and never arrived. The cadence counter is
## spent on the first and must not be on the second.
signal finished(shown: bool)

## Google's own test units. They fill every time, on any bundle id, signed or
## not — which is exactly why they exist and why they are the default here. A
## real unit in a sideloaded build gets no fill and looks identical to a broken
## integration, so testing against one would teach nothing.
##
## Interstitial ids are per platform; the addon's own sample quotes the Android
## one for both, which on an iPhone is a request for a unit that does not exist.
const TEST_UNIT_IOS := "ca-app-pub-3940256099942544/4411468910"
const TEST_UNIT_ANDROID := "ca-app-pub-3940256099942544/1033173712"

## Set these to the real ad units to go live. Left empty, the test unit above is
## used — so a build can never accidentally serve real ads because somebody
## forgot to switch something back.
const LIVE_UNIT_IOS := "ca-app-pub-1141785985592666/8580847493"
const LIVE_UNIT_ANDROID := ""

## Devices that always get a test ad, whatever unit is configured.
##
## Worth filling in before the live unit ships. Tapping your own live ads is how
## an AdMob account gets suspended for invalid traffic — Google does not
## distinguish a developer testing a build from click fraud, and the appeal is
## not quick. A registered device is exempt from that entirely.
##
## The id is printed by the SDK on first request, as a line containing
## `setTestDeviceIds` with a hash in it. Grab it from the device log and paste
## it here.
const TEST_DEVICES: Array[String] = []

## A load that never answers must not leave the loader stuck. With no plugin
## behind the API — a desktop export, or an iOS build where the addon was not
## included — every call is a silent no-op and no callback ever arrives, which
## is indistinguishable from a slow network right up until it never ends.
const LOAD_TIMEOUT := 20.0

## The rescue hatch for a break that goes up and never reports back. Long on
## purpose: a real interstitial can legitimately hold the screen for half a
## minute, and cutting a live one short is worse than the hang this prevents.
const SHOW_TIMEOUT := 60.0

## How long to let the SDK come up before asking it for the first ad.
const INIT_GRACE := 1.0

var _ad: InterstitialAd = null
var _loader: InterstitialAdLoader = null
var _loading := false
var _showing := false

## Bumped on every attempt so a callback or a timer belonging to an older one
## can tell that it has been overtaken and do nothing.
var _load_token := 0
var _show_token := 0


## Whether this install should be asking for ads at all.
##
## Two questions, and the second one is newer than the file. A player who has
## paid to remove ads was already never *shown* one — `Profile.ad_due` refuses
## before the cadence is even consulted — but the requests went out anyway, once
## at launch and once at the start of every match, and were filled, and were
## counted. That is an install fetching inventory it can never display: it pushes
## the request count up and the impression rate down, which is the ratio the
## network prices everything else off, and it does it hardest for the players who
## paid the most.
##
## Asked in `fetch`, which is the only door to the loader, so no caller has to
## remember. Asked again in `_ready`, where the answer also decides whether the
## SDK is started at all — a premium install has no reason to initialise a
## network it will never use.
func wanted() -> bool:
	return available() and not Profile.ads_removed()


func _ready() -> void:
	if not available():
		print("[Ads] no ad plugin on this platform — the game runs without breaks")
		return
	# Connected whether or not the SDK is started: a purchase can land mid-session
	# and everything already in the air has to be dropped when it does.
	Profile.changed.connect(_on_profile_changed)
	if not wanted():
		print("[Ads] premium — the SDK is not started and nothing is requested")
		return
	MobileAds.set_request_configuration(_request_config())
	MobileAds.initialize(OnInitializationCompleteListener.new())
	print("[Ads] initialising, unit %s" % unit_id())
	# The first fetch is kicked off from a timer rather than from the SDK's own
	# initialisation callback, and the listener handed to `initialize` is a bare
	# one that closes over nothing.
	#
	# That callback is retained by the plugin object in a one-shot connection,
	# and the plugin is reached through a static — so a lambda capturing this
	# autoload kept a reference to it alive past the scene tree's own teardown,
	# and the node was released a second time on the way out. Every headless run
	# ended in `double free or corruption`, after the tests had all passed, which
	# is the most ignorable form a real memory bug can take. A SceneTreeTimer
	# dies with the tree, so nothing here outlives anything else.
	get_tree().create_timer(INIT_GRACE).timeout.connect(fetch)


## The profile changed, which for this file means one thing: somebody may have
## just bought their way out of ads.
##
## `changed` fires on every save, so this has to be cheap and has to be safe to
## run when nothing relevant happened. It is one-directional — premium cannot be
## given back — so there is no branch here that starts the SDK late.
func _on_profile_changed() -> void:
	if wanted():
		return
	_drop()


## Let go of anything in hand or in flight, without showing it.
##
## The request that fetched it has already been counted and cannot be taken back.
## What this prevents is the impression: an ad loaded a second before the purchase
## completed must not be sitting there waiting for the next match to end. Bumping
## the load token is what turns an in-flight callback into one that destroys its
## own ad instead of keeping it — the same mechanism an overtaken fetch uses.
func _drop() -> void:
	_load_token += 1
	_loading = false
	if _ad != null:
		_ad.destroy()
		_ad = null


## What the SDK is allowed to serve, and to whom.
##
## Sent before `initialize` rather than after, because a configuration applied
## late applies to the *next* request — and the first interstitial is fetched a
## few seconds in.
##
## The same three answers are settable in the AdMob console, and setting them in
## both places is deliberate: the console is a login somebody else can change
## and this is in version control next to the rating it has to match.
func _request_config() -> RequestConfiguration:
	var cfg := RequestConfiguration.new()
	# The App Store rating is 13+, so Teen is the ceiling — level with the game's
	# own rating rather than above it. Left unspecified entirely, the SDK will
	# serve ads written for adults, which is a bad look on its own and something
	# Apple has pulled apps over.
	cfg.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_T
	# Not a children's app and not in the Kids Category. Said explicitly rather
	# than left unspecified: "we did not say" and "we said no" are different
	# answers to COPPA, and only one of them is a decision.
	cfg.tag_for_child_directed_treatment = \
		RequestConfiguration.TagForChildDirectedTreatment.FALSE
	cfg.tag_for_under_age_of_consent = \
		RequestConfiguration.TagForUnderAgeOfConsent.FALSE
	cfg.test_device_ids = TEST_DEVICES.duplicate()
	return cfg


## Whether there is anything behind the API at all.
##
## Mirrors how the addon picks its own backend: a registered native singleton on
## a phone, a full-screen mock when running under the editor binary, and nothing
## whatever in an exported desktop build. Asked before the SDK is touched, so a
## Linux build does not spend its first frames talking to an absent plugin.
func available() -> bool:
	if Engine.has_singleton("PoingGodotAdMobInterstitialAd"):
		return true
	return OS.has_feature("editor")


func unit_id() -> String:
	if OS.get_name() == "iOS":
		return LIVE_UNIT_IOS if LIVE_UNIT_IOS != "" else TEST_UNIT_IOS
	return LIVE_UNIT_ANDROID if LIVE_UNIT_ANDROID != "" else TEST_UNIT_ANDROID


## Is there an impression in hand, right now, to put on the screen?
##
## Asked before the game commits to a break rather than after. An interstitial
## takes seconds to fetch, so `show` on a cold loader shows nothing — and a
## break that was announced and then did not happen is worse than one that never
## came, because the player has already been made to wait for it.
func has_ad() -> bool:
	return _ad != null and not _showing


## Is a break on the screen? The game stops taking input while this is true: the
## native view swallows everything on a phone, but the desktop mock is a canvas
## layer inside our own window, and a keystroke that lands on the menu behind it
## would move a screen nobody can see.
func showing() -> bool:
	return _showing


## Go and get one. Safe to call whenever — already loading, already holding one,
## currently showing, or bought out of ads entirely all decline quietly, so this
## can sit at the start of a match without any of the callers having to know the
## state. `game.gd` calls it once per match and must keep being allowed to.
func fetch() -> void:
	if not wanted() or _loading or _showing or _ad != null:
		return
	_loading = true
	_load_token += 1
	var token := _load_token

	var cb := InterstitialAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: InterstitialAd) -> void:
		if token != _load_token:
			# Overtaken by a newer fetch. Destroyed rather than kept, because a
			# second live ad is native memory nobody is going to free.
			ad.destroy()
			return
		_loading = false
		_ad = ad
		_arm(ad)
	cb.on_ad_failed_to_load = func(err: LoadAdError) -> void:
		if token != _load_token:
			return
		_loading = false
		# Not an error. Having nothing to serve is the ordinary state of an ad
		# network several times a day, and the game's answer is to carry on.
		print("[Ads] no fill: %s" % err.message)

	# Held on the object, not a local: the loader has to outlive this function
	# or it is collected before the callback it is waiting for can arrive.
	_loader = InterstitialAdLoader.new()
	_loader.load(unit_id(), AdRequest.new(), cb)

	get_tree().create_timer(LOAD_TIMEOUT).timeout.connect(func() -> void:
		if token == _load_token and _loading:
			_loading = false
			print("[Ads] load timed out"))


## Wire up what the ad does once it is on screen. Every exit — dismissed,
## refused, or timed out — has to end at `_done`, or the game sits forever
## waiting for a break that is already over.
func _arm(ad: InterstitialAd) -> void:
	var fcb := FullScreenContentCallback.new()
	fcb.on_ad_showed_full_screen_content = func() -> void:
		_showing = true
	fcb.on_ad_dismissed_full_screen_content = func() -> void:
		_done(true)
	fcb.on_ad_failed_to_show_full_screen_content = func(err: AdError) -> void:
		print("[Ads] refused to show: %s" % err.message)
		_done(false)
	ad.full_screen_content_callback = fcb


## Put one on the screen. Returns false if there was nothing to put there, in
## which case `finished` never fires and the caller carries on as it was.
func show() -> bool:
	if not has_ad():
		return false
	_showing = true
	_show_token += 1
	var token := _show_token
	_ad.show()
	get_tree().create_timer(SHOW_TIMEOUT).timeout.connect(func() -> void:
		if token == _show_token and _showing:
			push_warning("Ads: the break never reported back — letting the player through")
			_done(false))
	return true


func _done(shown: bool) -> void:
	# Once only. Both the SDK and the rescue timer can arrive here for the same
	# break, and the second one must not emit a second `finished`.
	if not _showing:
		return
	_showing = false
	# Retires the timer belonging to this attempt.
	_show_token += 1
	if _ad != null:
		# Native memory, and the addon is explicit that this is ours to free.
		_ad.destroy()
		_ad = null
	finished.emit(shown)
	# Straight into fetching the next, so the gap between breaks is spent
	# loading rather than the moment the next one is due.
	fetch()
