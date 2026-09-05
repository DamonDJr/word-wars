extends Node
## Autoload `Sharing`. The share sheet, behind one door.
##
## Everything the rest of the game knows about sharing is the four things below:
## whether a share can be offered at all, send an image with some text, a signal
## when it is over, and why it failed. Which plugin is behind that is
## deliberately not the scoreboard's business — this file is the only one in the
## project that knows the addon's class name, so swapping it is rewriting one
## file rather than auditing every screen that offers a share.
##
## Same bargain `ads.gd` makes with AdMob, and for the same reason.
##
## ## Why the plugin is never named in code
##
## `godot-share` is an addon that registers a global class called `Share`. If it
## is not installed, a script that says `Share.new()` does not return null — it
## fails to *compile*, with "Identifier not found", and takes the whole game down
## with it. That is not a hypothetical: it is the same trap the tools scripts hit
## reaching for autoloads by name.
##
## So the class is found by looking through the global class list for its name at
## runtime. With the addon absent the lookup returns null, `available()` answers
## false, and every screen that offers a share simply does not offer one.
##
## ## What has to be true on the far side
##
## The addon is documented as exposing a `Share` node with, among others:
##
##     share_image(path, title, subject, content)
##     share_text(title, subject, content)
##
## and the signals `share_completed(activity_type)`, `share_canceled` and
## `share_failed(error_message)`. The image has to be saved somewhere under
## `user://` — an iOS app cannot hand out a path inside its own bundle, and
## `res://` in an exported build is inside the pck rather than on disk at all.
##
## Every one of those is checked before it is used rather than assumed, because
## this file was written against the addon's documentation rather than against
## the installed addon. `_wire` reports anything missing once, loudly, instead of
## failing silently at the moment a player presses the button.

## Emitted once per attempt, whatever the outcome. `ok` is true only if the sheet
## reported a completed share — a cancel is not a failure and neither is worth
## an error to the player, but the two are different events and the scoreboard
## may want to say different things about them.
signal finished(ok: bool, detail: String)

## The addon's global class name. The one string in the project that knows it.
const PLUGIN_CLASS := "Share"

## Where the card is written. Under `user://` because that is the only place the
## share sheet can reach — see the note above.
const CARD_DIR := "user://share"

## The link that goes out with every share, and the whole reason a share is worth
## having: a picture of somebody's score is a nice picture, and a picture with a
## way to go and beat it is a install.
##
## Built from the App Store Connect app id in `tools/ship-ios.sh` rather than
## copied from a browser, so there is one number to change and it is the same one
## the upload uses. Worth opening once on a phone before trusting it — a listing
## that is not yet public redirects, and the redirect is what people would see.
const STORE_APP_ID := "6802900966"
const STORE_URL := "https://apps.apple.com/app/id" + STORE_APP_ID

var _node: Node = null
var _ready_to_share := false
## Set once, so a missing method is reported at boot rather than on the press.
var _why_not := "not started"
## Guards against a second sheet being asked for while one is up. The signals
## come back from a native view controller and a double press is a real thing on
## a scoreboard with one button on it.
var _in_flight := false


func _ready() -> void:
	_wire()


## Build the addon's node, if the addon is here at all.
func _wire() -> void:
	var script := _find_plugin_script()
	if script == null:
		_why_not = "the share addon is not installed"
		print("[Share] off — %s" % _why_not)
		return

	# The addon is two halves and only one of them is GDScript. `Share.gd` is
	# installed on every platform; the thing that opens an actual sheet is a
	# native singleton that exists only in an iOS export with the plugin ticked
	# in the export preset. With the script present and the singleton absent,
	# every call the addon offers logs an error and returns — so checking only
	# for the script put a Share door on the desktop build that did nothing at
	# all when pressed, which is exactly what this seam exists to prevent.
	#
	# The name comes off the addon's own constant rather than being written out
	# here again, so a rename upstream cannot leave the two disagreeing.
	var singleton := "SharePlugin"
	var consts: Dictionary = script.get_script_constant_map()
	if consts.has("PLUGIN_SINGLETON_NAME"):
		singleton = String(consts["PLUGIN_SINGLETON_NAME"])
	if not Engine.has_singleton(singleton):
		_why_not = "the %s native plugin is not in this build" % singleton
		print("[Share] off — %s" % _why_not)
		return

	var made: Variant = script.new()
	if not (made is Node):
		_why_not = "the addon's %s is not a Node" % PLUGIN_CLASS
		push_warning("[Share] off — %s" % _why_not)
		return
	_node = made as Node
	_node.name = "ShareNode"
	add_child(_node)

	# Checked rather than trusted. This file was written against the addon's
	# README, and a method that has been renamed upstream would otherwise
	# surface as a crash under the player's thumb.
	for needed in ["share_image", "share_text"]:
		if not _node.has_method(needed):
			_why_not = "the addon has no %s()" % needed
			push_warning("[Share] off — %s" % _why_not)
			_node.queue_free()
			_node = null
			return

	# The signals are optional in a way the methods are not: without them the
	# sheet still opens and the player still shares, we simply never hear how it
	# went. So a missing one is a note, not a refusal.
	for sig in ["share_completed", "share_canceled", "share_failed"]:
		if not _node.has_signal(sig):
			print("[Share] note: no %s signal; outcomes will not be reported" % sig)
			continue
		match sig:
			"share_completed":
				_node.connect(sig, _on_completed)
			"share_canceled":
				_node.connect(sig, _on_canceled)
			"share_failed":
				_node.connect(sig, _on_failed)

	_ready_to_share = true
	_why_not = ""
	print("[Share] ready")


## Find the addon's script without naming its class in code.
##
## `get_global_class_list` is the registry `class_name` writes into, so this sees
## exactly what the editor sees, and sees nothing when the addon is absent.
func _find_plugin_script() -> Script:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if String(entry.get("class", "")) != PLUGIN_CLASS:
			continue
		var path := String(entry.get("path", ""))
		if path == "" or not ResourceLoader.exists(path):
			continue
		var res := load(path)
		return res as Script
	return null


## Whether a share can be offered. False on a desktop build, false on a phone
## where the addon was left out of the export, and false while one is already up.
func available() -> bool:
	return _ready_to_share and not _in_flight


## Why not, for a screen that would rather explain than hide a button.
func why_unavailable() -> String:
	return _why_not


## Send an image with some text beside it.
##
## `path` must already exist and must be under `user://`. Returns false if the
## share was not even attempted, in which case `finished` is never emitted and
## the caller keeps whatever it was showing.
func share_image(path: String, title: String, subject: String,
		content: String) -> bool:
	if not available():
		return false
	if not FileAccess.file_exists(path):
		push_warning("[Share] refused — no file at %s" % path)
		return false
	# The absolute path, not the `user://` one. A native view controller has
	# never heard of Godot's virtual filesystem.
	var real := ProjectSettings.globalize_path(path)
	_in_flight = true
	print("[Share] sheet up for %s" % real)
	_node.call("share_image", real, title, subject, content)
	return true


## Text only. The fallback when the card could not be drawn, and the whole of
## what a share is worth on a platform with no image support.
func share_text(title: String, subject: String, content: String) -> bool:
	if not available():
		return false
	_in_flight = true
	_node.call("share_text", title, subject, content)
	return true


## Somewhere under `user://` to put the card, made on first use.
func card_path(name: String = "result.png") -> String:
	DirAccess.make_dir_recursive_absolute(CARD_DIR)
	return "%s/%s" % [CARD_DIR, name]


func _on_completed(activity_type: String = "") -> void:
	_in_flight = false
	print("[Share] shared via %s" % (activity_type if activity_type != "" else "?"))
	finished.emit(true, activity_type)


func _on_canceled() -> void:
	_in_flight = false
	# Not a failure, and must not be reported to the player as one. Backing out
	# of a share sheet is a decision, not an error.
	print("[Share] cancelled")
	finished.emit(false, "cancelled")


func _on_failed(error_message: String = "") -> void:
	_in_flight = false
	push_warning("[Share] failed — %s" % error_message)
	finished.emit(false, error_message)
