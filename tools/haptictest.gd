extends SceneTree
## Haptics are the one part of this game nobody here can check by looking at it.
##
## There is no taptic engine on a desktop, `vibrate_handheld` reports nothing,
## and a call naming an event that does not exist fails by doing precisely what a
## correct call does on this machine — nothing at all. So a misspelt event would
## ship silent and stay silent, and the only way anyone would find out is by
## noticing that hitting something no longer feels like hitting something.
##
## Hence this: the table and the call sites are checked against each other, and
## the two rules that decide what actually reaches the hand are exercised.
##
##   godot --headless --script tools/haptictest.gd

var fails := 0
## Reached through the root rather than by name. In a `--script` run the
## autoload globals are not bound at compile time, which is why every suite in
## here fetches its singletons this way.
var H: Node


func _init() -> void:
	await process_frame
	H = get_root().get_node("Haptics")
	_every_call_site_names_a_real_event()
	_the_fight_outranks_the_typing()
	_a_weaker_event_does_not_interrupt()
	_off_means_off()

	print("--- %s ---" % ("haptics behave" if fails == 0 else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)


## The check that matters most, and the only one that catches a typo.
func _every_call_site_names_a_real_event() -> void:
	print("--- every call site names an event that exists ---")
	var src := FileAccess.get_file_as_string("res://scripts/game.gd")
	# Every quoted lowercase word on a line that fires one, rather than just the
	# first. Several call sites choose between two events with a ternary —
	# `fire("win" if won else "lose")` — and reading only the first argument
	# reported the second half of each of them as dead code.
	var re := RegEx.new()
	re.compile('"([a-z]+)"')
	var seen: Dictionary = {}
	var bad: Array = []
	for line in src.split("\n"):
		var at := String(line).find("Haptics.fire(")
		if at < 0:
			continue
		for m: RegExMatch in re.search_all(String(line).substr(at)):
			var name := m.get_string(1)
			seen[name] = true
			if not H.EVENTS.has(name):
				bad.append(name)
	_expect("game.gd has haptics in it at all", not seen.is_empty())
	_expect("every event fired is in the table", bad.is_empty())
	if not bad.is_empty():
		print("      unknown: %s" % ", ".join(bad))

	# The other direction is a warning rather than a failure — an entry with no
	# call site is dead weight, but it is not broken.
	var unused: Array = []
	for name in H.EVENTS:
		if not seen.has(name):
			unused.append(String(name))
	if not unused.is_empty():
		print("  note: defined but never fired: %s" % ", ".join(unused))


## Typing is the floor and the fight is above it. If this ever inverts, a
## keystroke would be able to swallow the block that just landed on you.
func _the_fight_outranks_the_typing() -> void:
	print("--- the fight outranks the typing ---")
	var key: int = int((H.EVENTS["key"] as Array)[2])
	for name in ["clear", "land", "life", "salvo", "power", "reject", "win", "lose"]:
		var w: int = int((H.EVENTS[name] as Array)[2])
		_expect("%s outranks a keystroke" % name, w > key)
	_expect("losing a life is heavier than clearing",
		int((H.EVENTS["life"] as Array)[2])
			> int((H.EVENTS["clear"] as Array)[2]))
	# Nothing may be long enough to still be running when the next one is due.
	# There is no way to cancel one, so an over-long pulse cannot be taken back.
	for name in H.EVENTS:
		_expect("%s is within the ceiling" % name,
			float((H.EVENTS[name] as Array)[0]) <= H.MAX_MS)

	# Godot only emits continuous haptic events — there is no transient one in
	# the iOS template — and a continuous event too short to spin the actuator up
	# is silence. This is the check that would have caught the first draft of
	# this table, every event of which was tuned as though it were a tap.
	for name in H.EVENTS:
		_expect("%s is long enough to be felt at all" % name,
			int((H.EVENTS[name] as Array)[0]) >= 25)


func _a_weaker_event_does_not_interrupt() -> void:
	print("--- a weaker event does not interrupt a stronger one ---")
	H.enabled = true

	H._last_ms = 0.0
	H._last_weight = 0
	_expect("a life lost fires", H.fire("life"))
	_expect("a keystroke on top of it is dropped", not H.fire("key"))

	# ...and the reverse, because the rule is about weight and not about order.
	H._last_ms = 0.0
	H._last_weight = 0
	_expect("a keystroke fires", H.fire("key"))
	_expect("a life lost still gets through", H.fire("life"))

	# Once the window has passed, anything goes again.
	H._last_ms = float(Time.get_ticks_msec()) - H.MERGE_MS - 5.0
	H._last_weight = 9
	_expect("after the window a keystroke fires again", H.fire("key"))


func _off_means_off() -> void:
	print("--- off means off ---")
	H.enabled = false
	H._last_ms = 0.0
	H._last_weight = 0
	var any := false
	for name in H.EVENTS:
		if H.fire(String(name)):
			any = true
	_expect("nothing fires with haptics switched off", not any)
	H.enabled = true

	H._last_ms = 0.0
	H._last_weight = 0
	_expect("an event that does not exist is refused", not H.fire("nonsense"))


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-52s %s" % [what, "ok" if ok else "FAILED"])
