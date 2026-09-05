extends Node
## Autoload `Notify`. Local notifications, behind one door and behind a promise.
##
## The door is the pattern `share.gd` and `review.gd` use: the only file that
## names the addon, found through the global class list, refused unless the
## native singleton is in the build.
##
## The promise is that this game will only ever send a notification about
## something the player already has. There are exactly two, and both are about
## something of theirs that is about to change:
##
##   * **The daily board.** It rolls at local midnight and there is one run in
##     it. That is a real event on a real schedule, not an invented reason.
##   * **A streak about to lapse.** The strongest of the two by a distance,
##     because it is the only one where doing nothing costs the player something
##     they built. It is only ever sent to somebody who *has* a streak.
##
## What is deliberately not here: "we miss you", "come back", anything fired at
## a player with nothing waiting for them, and anything at all on a device that
## has not opted in. A game with fifty players cannot afford to be the app
## somebody deletes because it nagged.
##
## ## Permission is asked late, on purpose
##
## iOS gives one chance at the permission dialog, ever. Asked on first launch —
## before the player knows what the daily board is, or has a streak worth
## protecting — it is a dialog about nothing, and "Don't Allow" is permanent
## short of a trip to Settings. So it is asked after the first daily run is
## finished, which is the first moment there is a true sentence to put next to
## it, and never asked twice.
##
## ## Everything is scheduled, nothing is live
##
## There is no server and no push certificate. These are local notifications
## queued on the device with a delay, which means they must be re-queued every
## time the game learns something new — see `refresh`. Scheduling is therefore
## cancel-then-schedule rather than additive, or a week of launches leaves seven
## copies of the same reminder in the queue.

const PLUGIN_CLASS := "NotificationScheduler"
const PLUGIN_SINGLETON := "NotificationSchedulerPlugin"

## Stable ids, so a reschedule replaces rather than stacks.
const ID_DAILY := 1001
const ID_STREAK := 1002

## When the daily reminder lands. Late enough that it is not competing with an
## alarm clock, early enough to leave the whole day to act on it.
const DAILY_HOUR := 10

## And when the streak warning does. Evening, because it is a last call — sent
## only if the board is still unplayed by then, with time left to do something
## about it.
const STREAK_HOUR := 19

## How long to wait when the streak hour has already passed, and how much of the
## evening has to be left for that to be worth doing at all. A warning that lands
## with ten minutes of the day on it is a warning about something already lost.
const LATE_NUDGE := 1800
const LATE_FLOOR := 900

const SECONDS_PER_DAY := 86400

var _node: Node = null
var _ready_to_send := false
var _why_not := "not started"


func _ready() -> void:
	_wire()


func _wire() -> void:
	var script := _find_plugin_script()
	if script == null:
		_why_not = "the notification addon is not installed"
		print("[Notify] off — %s" % _why_not)
		return
	if not Engine.has_singleton(PLUGIN_SINGLETON):
		_why_not = "the %s native plugin is not in this build" % PLUGIN_SINGLETON
		print("[Notify] off — %s" % _why_not)
		return

	var made: Variant = script.new()
	if not (made is Node):
		_why_not = "the addon's %s is not a Node" % PLUGIN_CLASS
		push_warning("[Notify] off — %s" % _why_not)
		return
	_node = made as Node
	_node.name = "NotificationSchedulerNode"
	add_child(_node)

	for needed in ["initialize", "schedule", "cancel",
			"has_post_notifications_permission",
			"request_post_notifications_permission"]:
		if not _node.has_method(needed):
			_why_not = "the addon has no %s()" % needed
			push_warning("[Notify] off — %s" % _why_not)
			_node.queue_free()
			_node = null
			return

	if _node.has_signal("post_notifications_permission_granted"):
		_node.connect("post_notifications_permission_granted", _on_granted)
	if _node.has_signal("post_notifications_permission_denied"):
		_node.connect("post_notifications_permission_denied", _on_denied)

	_node.call("initialize")
	_ready_to_send = true
	_why_not = ""
	print("[Notify] ready")


func _find_plugin_script() -> Script:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if String(entry.get("class", "")) != PLUGIN_CLASS:
			continue
		var path := String(entry.get("path", ""))
		if path == "" or not ResourceLoader.exists(path):
			continue
		return load(path) as Script
	return null


func available() -> bool:
	return _ready_to_send


func why_unavailable() -> String:
	return _why_not


## Whether iOS itself is willing. Distinct from the player's own switch below —
## a player can turn ours off with permission granted, and can revoke permission
## in Settings with ours still on.
func permitted() -> bool:
	if not available():
		return false
	return bool(_node.call("has_post_notifications_permission"))


## The switch in our settings. Off until there is a permission to back it.
func enabled() -> bool:
	return available() and bool(Profile.pref("notify")) and permitted()


func set_enabled(on: bool) -> void:
	Profile.set_pref("notify", on)
	if on and not permitted():
		request_permission()
		return
	refresh()


## Ask iOS. Once, ever — the dialog does not come back, and a second call on a
## device that said no is a call that does nothing.
func request_permission() -> void:
	if not available():
		return
	if bool(Profile.pref("notify_asked")):
		refresh()
		return
	Profile.set_pref("notify_asked", true)
	print("[Notify] requesting permission")
	_node.call("request_post_notifications_permission")


## The moment there is something true to say. Called when a daily run finishes,
## which is the first point the player has seen the board, knows it rolls, and
## may have a streak worth defending.
func offer_after_daily() -> void:
	if not available() or bool(Profile.pref("notify_asked")):
		return
	# Turned on as it is asked for. If iOS says no, `permitted()` stays false and
	# `enabled()` with it, so the switch reads off and nothing is ever sent.
	Profile.set_pref("notify", true)
	request_permission()


## Cancel everything and re-queue from what is true right now.
##
## Cancel-then-schedule rather than additive: these are queued on the device with
## a delay, so a week of launches would otherwise leave seven copies of the same
## reminder waiting.
func refresh() -> void:
	if not available():
		return
	_node.call("cancel", ID_DAILY)
	_node.call("cancel", ID_STREAK)
	if not enabled():
		return

	var today: String = _today_key()
	var played: bool = Profile.daily_done(today)
	var streak: int = Profile.daily_streak(today)

	# Tomorrow's board, once today's is done. Sent to somebody who has played
	# rather than to somebody who has not — the unplayed case is the streak
	# warning below, and sending both would be two notifications about one board.
	if played:
		_send(ID_DAILY, "Today's board is up",
			"A new Word Wars daily is waiting. One run at it.",
			_seconds_until(DAILY_HOUR, 1))
	elif streak >= 2:
		# The one worth sending. Only ever to a player with something to lose,
		# and only while there is still time to lose it.
		var wait := _seconds_until(STREAK_HOUR, 0)
		if wait <= 0:
			# The hour has gone but the day has not. Dropping it here was the
			# first version and it was wrong: somebody who opens the game at
			# eight in the evening with the board unplayed is exactly who this
			# is for, and they would have been the one player never reminded.
			#
			# So it slides to a short delay instead — unless midnight is close
			# enough that the reminder would arrive with no time to act on it,
			# which is worse than silence.
			var to_midnight := _seconds_until(24, 0)
			wait = LATE_NUDGE if to_midnight > LATE_NUDGE + LATE_FLOOR else 0
		if wait > 0:
			_send(ID_STREAK, "Your %d-day streak ends tonight" % streak,
				"Today's board is still unplayed. One run keeps it.", wait)


func _send(id: int, title: String, body: String, delay_seconds: int) -> void:
	if delay_seconds <= 0:
		return
	var data_script := _model_script("NotificationData")
	if data_script == null:
		push_warning("[Notify] no NotificationData in the addon")
		return
	var data: Object = data_script.new()
	data.set_id(id)
	data.set_title(title)
	data.set_content(body)
	data.set_delay(delay_seconds)
	_node.call("schedule", data)
	print("[Notify] queued %d in %ds — %s" % [id, delay_seconds, title])


## The addon's model classes, looked up the same way its node is and for the same
## reason: naming one that is not installed does not compile.
func _model_script(what: String) -> Script:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if String(entry.get("class", "")) != what:
			continue
		var path := String(entry.get("path", ""))
		if path == "" or not ResourceLoader.exists(path):
			continue
		return load(path) as Script
	return null


## Local, matching the board.
##
## `daily_key` in `game.gd` reads the system clock with UTC off, so the board
## rolls at local midnight — and a reminder computed in UTC would arrive at the
## wrong end of the day for most of the world. Kept here rather than called out
## of `game.gd` so this file works with no match in progress.
func _today_key() -> String:
	var d := Time.get_datetime_dict_from_system(false)
	return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]


## Seconds from now until `hour` local, `days_ahead` days from today. Returns a
## negative number if that moment has already passed today and `days_ahead` is
## zero, which is the caller's signal that there is no point sending it.
func _seconds_until(hour: int, days_ahead: int) -> int:
	var d := Time.get_datetime_dict_from_system(false)
	var now: int = int(d["hour"]) * 3600 + int(d["minute"]) * 60 + int(d["second"])
	return hour * 3600 - now + days_ahead * SECONDS_PER_DAY


func _on_granted(_permission: String = "") -> void:
	print("[Notify] permission granted")
	refresh()


func _on_denied(_permission: String = "") -> void:
	# Nothing to say and nothing to retry. The switch reads off because
	# `permitted()` is false, which is the honest state.
	print("[Notify] permission denied")
