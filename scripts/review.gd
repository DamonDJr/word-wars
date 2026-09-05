extends Node
## Autoload `Reviews`. The App Store rating prompt, behind one door and behind a
## policy.
##
## The door is the same bargain `share.gd` and `ads.gd` make: this is the only
## file that knows the addon exists, found through the global class list because
## naming an uninstalled `class_name` is a compile error rather than a null, and
## refused unless the native singleton is in the build too.
##
## The policy is the part that matters more.
##
## ## Why this is mostly rules and hardly any code
##
## `SKStoreReviewController` is not a prompt you show, it is a prompt you *ask
## for*. iOS decides whether to display it, silently ignores you if it will not,
## and allows at most three displays per app per 365 days. There is no callback
## and no way to find out which happened.
##
## Three consequences, and they are the whole design:
##
## 1. **Asks are a budget, not a button.** Spending one on somebody who has
##    played twice and lost both is spending a third of the year's allowance on
##    the least likely yes in the game.
## 2. **The moment is everything, because the wording is not ours.** The system
##    dialog says the same thing whenever it appears. All we control is *when* —
##    so it goes after something good happened, never after a loss.
## 3. **Silence is the normal outcome.** Nothing here may assume the prompt
##    appeared. No state advances on the strength of it, nothing is unlocked
##    behind it, and the player is never told it is coming.
##
## Apple is also explicit that this must not be triggered by a button labelled
## "rate us" — that is what `get_app_review_url` is for, and it is not used here.

signal asked

const PLUGIN_CLASS := "InappReview"
const PLUGIN_SINGLETON := "InappReviewPlugin"

## Matches before the question is worth asking at all. Somebody who has not
## finished a handful of games has no opinion yet, and the prompt spends one of
## three yearly slots collecting it.
const MIN_MATCHES := 8

## Our own cap, set to Apple's. Going over cannot show anything — iOS drops the
## fourth silently — so a fourth attempt is only a way of losing track of how
## many are left.
const MAX_ASKS := 3

## And the gap between them. Sixty days rather than the ~120 that three-per-year
## would allow, because the second ask is worth having in the same season as a
## player's best run rather than a third of a year later.
const MIN_DAYS_BETWEEN := 60.0
const SECONDS_PER_DAY := 86400.0

## If the addon never answers `generate_review_info`, stop waiting. Android needs
## that round trip to build a ReviewInfo; iOS does not, and a platform that
## answers neither signal must not leave this armed forever.
const INFO_TIMEOUT := 5.0

var _node: Node = null
var _ready_to_ask := false
var _why_not := "not started"
var _waiting := false
var _wait_age := 0.0


func _ready() -> void:
	set_process(false)
	_wire()


func _process(delta: float) -> void:
	if not _waiting:
		set_process(false)
		return
	_wait_age += delta
	if _wait_age >= INFO_TIMEOUT:
		print("[Review] no answer to generate_review_info — giving up")
		_waiting = false
		set_process(false)


func _wire() -> void:
	var script := _find_plugin_script()
	if script == null:
		_why_not = "the review addon is not installed"
		print("[Review] off — %s" % _why_not)
		return
	if not Engine.has_singleton(PLUGIN_SINGLETON):
		_why_not = "the %s native plugin is not in this build" % PLUGIN_SINGLETON
		print("[Review] off — %s" % _why_not)
		return

	var made: Variant = script.new()
	if not (made is Node):
		_why_not = "the addon's %s is not a Node" % PLUGIN_CLASS
		push_warning("[Review] off — %s" % _why_not)
		return
	_node = made as Node
	_node.name = "InappReviewNode"
	add_child(_node)

	for needed in ["generate_review_info", "launch_review_flow"]:
		if not _node.has_method(needed):
			_why_not = "the addon has no %s()" % needed
			push_warning("[Review] off — %s" % _why_not)
			_node.queue_free()
			_node = null
			return

	if _node.has_signal("review_info_generated"):
		_node.connect("review_info_generated", _on_info_ready)
	if _node.has_signal("review_info_generation_failed"):
		_node.connect("review_info_generation_failed", _on_info_failed)

	_ready_to_ask = true
	_why_not = ""
	print("[Review] ready")


func _find_plugin_script() -> Script:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if String(entry.get("class", "")) != PLUGIN_CLASS:
			continue
		var path := String(entry.get("path", ""))
		if path == "" or not ResourceLoader.exists(path):
			continue
		return load(path) as Script
	return null


## Whether an ask is even possible on this device and in this build.
func available() -> bool:
	return _ready_to_ask


func why_unavailable() -> String:
	return _why_not


## How many of the three have been spent, and when the last one went.
func asks_spent() -> int:
	return int(Profile.pref("review_asks"))


func days_since_last() -> float:
	var last := float(Profile.pref("review_last"))
	if last <= 0.0:
		return 9999.0
	return (Time.get_unix_time_from_system() - last) / SECONDS_PER_DAY


## The budget, with no reference to whether a plugin exists.
##
## Split from `allowed` so it can be checked on a machine the addon will never
## run on — which is every machine this project is developed on. Folded together,
## the whole policy sat behind an `available()` that is false on a desktop and
## none of it could be exercised until it was on a phone.
func within_budget() -> bool:
	if Profile.matches < MIN_MATCHES:
		return false
	if asks_spent() >= MAX_ASKS:
		return false
	return days_since_last() >= MIN_DAYS_BETWEEN


## Everything except the moment. Callers read as "was this a good moment?" and
## the budgeting lives here rather than at three call sites.
func allowed() -> bool:
	return available() and within_budget()


## Ask, if this is a moment worth spending one on.
##
## `reason` is for the log only. Nothing branches on it — the dialog is the
## system's and says the same thing however we got here — but when a build comes
## back having burnt two asks in a week, the log is the only way to find out
## which moment did it.
##
## Returns whether the request went out, which is *not* whether anything was
## shown. Nothing may be built on the return value beyond bookkeeping.
func maybe_ask(reason: String) -> bool:
	if not allowed():
		return false
	if _waiting:
		return false

	# Spent at the moment of asking, not on some confirmation that never comes.
	# iOS may show nothing at all and tells us nothing either way, so an ask that
	# is only counted when it "worked" is an ask that is counted never — and the
	# budget would drain in a single session.
	Profile.set_pref("review_asks", asks_spent() + 1)
	Profile.set_pref("review_last", Time.get_unix_time_from_system())
	print("[Review] asking after %s (%d of %d spent)" % [
		reason, asks_spent(), MAX_ASKS])

	_waiting = true
	_wait_age = 0.0
	set_process(true)
	# Android builds a ReviewInfo first and answers on a signal; iOS has no such
	# step and may answer nothing at all, which is what the timeout above is for.
	_node.call("generate_review_info")
	asked.emit()
	return true


func _on_info_ready() -> void:
	if not _waiting:
		return
	_waiting = false
	set_process(false)
	_node.call("launch_review_flow")


func _on_info_failed() -> void:
	# Nothing to tell the player. They did not ask for this and were never
	# promised it; the only casualty is one of three slots, and refunding it
	# would risk asking twice in a row on a device that fails every time.
	_waiting = false
	set_process(false)
	print("[Review] the addon could not build a review request")
