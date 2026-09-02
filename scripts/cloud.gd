extends Node
## Autoload `Cloud`. The profile, kept on Game Center so it outlives the phone.
##
## A player who uninstalls, upgrades, or drops their phone in a river should come
## back to their level, their cosmetics, their streak and their purchase. Nothing
## else here is worth much on its own — the record screen is the reward for a
## hundred matches, and a hundred matches is a lot to ask somebody to play twice.
##
## ## Why Game Center saved games and not something else
##
## Because the player is already signed in. `MultiplayerManager` authenticates
## Game Center at launch for matchmaking, and `GKLocalPlayer.save_game_data`
## writes to that account's iCloud storage — so there is no login screen, no
## email, no password and no account of ours to run, and the save follows the
## Apple ID onto the next device by itself. The alternative on the table was EOS,
## which this game signs into with a **Device ID** (see `net_link._ensure_eos`) —
## an identity that dies with exactly the install we are trying to survive.
##
## The cost is that this is an Apple feature and works on Apple devices. Desktop
## builds keep their local save and this file does nothing at all, which is the
## same bargain `Boards`, `Awards` and `Store` already make.
##
## ## The two rules that matter
##
## Everything below is arranged around two failures, both of which turn "your
## progress is safe" into "your progress is gone":
##
## 1. **Never upload before downloading.** A fresh install has a blank profile.
##    Push it first and the blank overwrites the only copy of the record. So
##    `push` refuses to run until a `pull` has completed this session — that is
##    what `_pulled` is for, and it is the single most important line in here.
## 2. **Never resolve a difference by choosing.** Two devices that both played
##    are both right. The merge in `Profile.merge_from` only ever moves numbers
##    up, so no sync can cost a player something they had before it — see the
##    reasoning above it for why that is maxed rather than summed.
##
## Everything else is silent. A sync that fails costs the player nothing today —
## the local save is untouched and authoritative — so there is no error path a
## player can be interrupted by, only a line in Settings if they go looking.
##
## ## Setting it up (this needs more than code)
##
## Saved games are iCloud-backed, so the app has to carry the iCloud entitlement
## and the App ID has to have iCloud enabled with the container
## `iCloud.com.damonj.wordwars`. Both are in `export_presets.cfg` and
## `docs/cloud-saves.md`. Without them everything here reports `FAILED` on the
## first fetch and the game carries on locally.

signal changed

## The saved game's name. One save, one name, overwritten in place — this game
## has a single profile and no save slots, so a name per device would be a way to
## accumulate conflicts rather than a feature.
const SAVE_NAME := "wordwars"

## How long the profile has to sit still before an upload.
##
## `Profile.changed` fires on nearly every word typed, so uploading on the signal
## would mean a network write per keystroke. Nothing here is urgent — the local
## save already happened, synchronously, before the signal — so the upload waits
## for the player to stop, and the moments that cannot wait (backgrounding the
## app, closing the window) push immediately regardless.
const QUIET := 8.0

## The shortest gap between two downloads. Resuming from the background asks for
## one, and iOS sends that notification liberally.
const PULL_EVERY := 60.0

## OFF     — not an Apple device, or the plugin is missing. Resting state on
##           every desktop build, and not a fault.
## WAITING — signed out, or Game Center has not finished authenticating.
## SYNCING — talking to Apple.
## READY   — the cloud and this device agree, as of `last_sync`.
## FAILED  — Apple said no, or there is no iCloud entitlement. `status` says.
enum State { OFF, WAITING, SYNCING, READY, FAILED }

var state: int = State.OFF
var status := ""

## Unix time of the last *confirmed* sync, or 0 if this session has not had one.
##
## Confirmed means Apple has been asked afterwards and says the save is there —
## not merely that a call returned without an error. 0.42.0 set this on any
## round trip that completed, including one that read nothing and wrote nothing,
## so a device that was quietly failing to back anything up reported the time of
## day and looked healthy. A backup that lies about being a backup is worse than
## no backup, because it is the reason somebody stops making their own.
var last_sync := 0

## How many saved games the last fetch found, and how big ours was. Reported on
## the Settings row, because "backed up" with no number behind it is the claim
## that turned out to be untrue.
var cloud_saves := 0
var cloud_bytes := 0

## Whether this session actually brought something down. What a player on a new
## phone is waiting to be told.
var restored := false

## Whether this session has read the cloud. Nothing uploads until it has — see
## the rules above; this is rule one.
var _pulled := false

## Set when the profile changes, cleared when it has been sent.
var _dirty := false
var _quiet := 0.0
var _since_pull := 0.0

## One call to Apple at a time. Every entry point checks it, so a manual sync
## during an automatic one is a no-op rather than two writes racing.
var _busy := false

## How long the current call has been outstanding, and how long is too long.
##
## Everything here is gated on `_busy`, which is cleared by a callback — so a
## callback that never arrives does not fail one sync, it switches syncing off
## for the rest of the session, silently, with the row in Settings stuck on
## "checking your cloud save" forever. These are Apple's callbacks arriving
## through a plugin, and "it always calls back" is an assumption rather than a
## guarantee. Thirty seconds is far longer than a few kilobytes can honestly
## take and short enough that the next sync is still this session.
var _busy_for := 0.0
const GIVE_UP := 30.0

## The saved games currently being read, held for exactly as long as that takes.
##
## Not an optimisation — the reason this array exists is that without it the
## restore does not work at all.
##
## `fetch_saved_games` hands back an array of `GKSavedGame`, which are reference
## counted. `load_data` on one of them is asynchronous. So the obvious shape —
## take the array the callback was given, start a load on each, return — drops
## the last reference to every one of those objects the moment the callback
## returns, while their loads are still in the air. They are freed underneath
## Apple, the completion handlers never arrive, `_loading` never reaches nought,
## and the restore hangs until the watchdog gives up on it thirty seconds later.
##
## Which is exactly what shipped in 0.42.0: the *first* install worked, because
## an empty cloud never loads anything and goes straight to the upload, and every
## install after it — the ones where there was something to restore — silently
## brought back nothing.
var _fetched: Array = []

## Saves whose bytes are still on their way, and what came back so far.
var _loading := 0
var _cloud_behind := false
## Whether this pull actually brought something home, so the save and the
## repaint happen once at the end rather than per downloaded copy.
var _gained := false
## The conflicting versions being resolved, empty during an ordinary pull. Held
## because `resolve_conflicting_saved_games` needs them back after every one has
## been read and merged.
var _conflicts: Array = []


## Whether this build can reach Game Center saved games at all.
##
## Platform first, for the reason `leaderboards.available()` gives: the desktop
## stub registers every class and then refuses to construct one, so asking
## `ClassDB` alone would answer yes on Linux.
func available() -> bool:
	if not (OS.get_name() in ["iOS", "macOS"]):
		return false
	return ClassDB.class_has_method("GKLocalPlayer", "save_game_data", true)


func _ready() -> void:
	if not available():
		_set_state(State.OFF, "cloud saves need an Apple device")
		set_process(false)
		return
	_log("on, waiting for Game Center")
	_set_state(State.WAITING, "waiting for Game Center")
	MultiplayerManager.state_changed.connect(_on_gc_state_changed)
	Profile.changed.connect(_on_profile_changed)
	# Already authenticated by the time we got here — the autoloads race, and
	# `MultiplayerManager` may well have won. Without this the first launch of a
	# session never syncs and the second one does, which is the hardest kind of
	# bug to be told about.
	if _signed_in():
		_wake()


func _signed_in() -> bool:
	return MultiplayerManager.local_player != null


## Everything a player can see about this, in one line. For the Settings row.
##
## Says what actually happened rather than that something did. The version this
## replaces said "saved to your Apple ID at 00:58" whether it had uploaded a
## profile, downloaded one, or completed a round trip that moved nothing at all
## — and the third of those is the one that was happening.
func note() -> String:
	match state:
		State.READY:
			if last_sync == 0:
				# Signed in, nothing confirmed yet. Should be a blink; if it
				# sticks, something is wrong and this must not read as success.
				return "checking…"
			var t := Time.get_datetime_dict_from_unix_time(last_sync)
			var when := "%02d:%02d" % [int(t["hour"]), int(t["minute"])]
			if restored:
				return "restored from your Apple ID at %s" % when
			return "backed up at %s · %d KB on iCloud" % [when,
				maxi(1, cloud_bytes / 1024)]
		State.SYNCING:
			return status
		State.WAITING:
			return "sign in to Game Center to back up your progress"
		State.FAILED:
			return status
	return "not available on this device"


## A `GKError` in words. Its `code` is the thing worth having — 21 and 23 are
## "not signed in to iCloud Drive" and "iCloud is unavailable", which are the two
## most likely reasons any of this quietly does nothing, and neither is a bug.
func _describe(error) -> String:
	if error == null:
		return "no error"
	var code := -1
	var message := ""
	if error is Object:
		if (error as Object).has_method("get_code"):
			code = int(error.code)
		if (error as Object).has_method("get_message"):
			message = String(error.message)
	if message == "":
		message = str(error)
	if code < 0:
		return message
	return "%s (GKError %d)" % [message, code]


## The device log. Named like the rest of the subsystems — `[GC]`, `[Store]`,
## `[Ads]` — so a console session filters to one prefix.
##
## Chatty on purpose. Every failure this feature can have is invisible from
## inside the game, and the whole of what went wrong in 0.42.0 would have been
## one line on a console.
func _log(text: String) -> void:
	print("[Cloud] %s" % text)


## Whether the SYNC button should do anything.
func can_sync() -> bool:
	return available() and _signed_in() and not _busy


## A sync the player asked for. Does the full round trip rather than just an
## upload, because somebody pressing this on a new phone wants what is up there
## rather than to send what is down here.
func sync_now() -> void:
	if not can_sync():
		return
	pull()


func _on_gc_state_changed(_text: String) -> void:
	if not available():
		return
	if not _signed_in():
		# A different Apple ID, or none. Whatever is in memory belongs to the
		# previous account and must not be written to this one's storage.
		_pulled = false
		_set_state(State.WAITING, "waiting for Game Center")
		return
	_wake()


func _wake() -> void:
	# The conflict listener. `MultiplayerManager` has already called
	# `register_listener` on this player, which is what makes the signal fire at
	# all; this only asks to hear it.
	var p = MultiplayerManager.local_player
	if p != null and not p.conflicting_saved_games.is_connected(_on_conflicts):
		p.conflicting_saved_games.connect(_on_conflicts)
	if not _pulled:
		pull()
	elif _dirty:
		push()


# ------------------------------------------------------------------ downloading

## Read what Game Center has and fold it in.
func pull() -> void:
	if not available() or not _signed_in() or _busy:
		return
	# A local save we could not parse is the one case where doing nothing is the
	# whole job. `Profile` has already disabled its own writing to protect the
	# file; uploading what is in memory would push the same blank over the copy
	# in the cloud, which is the last one left.
	if Profile.read_failed:
		_set_state(State.FAILED, "the save on this device could not be read")
		return
	_busy = true
	_since_pull = 0.0
	_set_state(State.SYNCING, "checking your cloud save")
	MultiplayerManager.local_player.fetch_saved_games(_on_fetched)


## Every callback below takes its arguments untyped, and that is deliberate.
##
## These are called by Apple, through a plugin nobody here controls, and a
## declared type that the plugin does not honour — a null where an `Array` was
## promised on the error path, say — is not a compile error. It is a runtime
## failure inside a callback, on a device, with the game carrying on as if the
## call had simply never come back. Coerced here instead, where it is visible.
func _on_fetched(games, error) -> void:
	if error != null or games == null:
		_busy = false
		push_warning("Cloud: could not read saved games — %s" % _describe(error))
		_log("fetch refused: %s" % _describe(error))
		_set_state(State.FAILED, _reason(error))
		return

	# Everything that comes back, not just the entries named `SAVE_NAME`. This
	# game writes exactly one name, so anything here is ours; and the plugin's
	# own documentation has `name` and `device_name` described the wrong way
	# round, so filtering on either is a coin toss against a doc comment.
	cloud_saves = (games as Array).size()
	if cloud_saves == 0:
		# Nothing up there yet — a first run on a fresh account. The local
		# profile, whatever it holds, is the best copy in existence.
		_busy = false
		_pulled = true
		_log("iCloud has no saved game yet; uploading this device's profile")
		push()
		return

	_absorb(games)


## What to put on the row when Apple refuses. The two codes worth naming are the
## ones that are not faults at all: a player who is signed into Game Center but
## not into iCloud Drive, which is a common and entirely reasonable state, and
## one whose iCloud is simply unreachable right now. Telling them that is the
## difference between a setting they can fix and a game that seems broken.
func _reason(error) -> String:
	if error is Object and (error as Object).has_method("get_code"):
		match int(error.code):
			21: return "turn on iCloud Drive to back up your progress"
			23: return "iCloud is unavailable on this device"
	return "iCloud is not reachable"


## Load every saved game and merge each into the profile.
##
## The array is held in `_fetched` for the duration. See the note on it: letting
## these go out of scope is what broke the restore in 0.42.0.
func _absorb(games: Array) -> void:
	_fetched = games
	_loading = games.size()
	_cloud_behind = false
	_log("reading %d saved game(s)" % _loading)
	for g in games:
		g.load_data(_on_loaded)


func _on_loaded(data, error) -> void:
	if error != null:
		push_warning("Cloud: a saved game would not open — %s" % _describe(error))
		_log("a saved game would not open: %s" % _describe(error))
	elif data is PackedByteArray and not (data as PackedByteArray).is_empty():
		cloud_bytes = maxi(cloud_bytes, (data as PackedByteArray).size())
		_log("read %d bytes" % (data as PackedByteArray).size())
		_fold(data)
	else:
		# A save that exists and is empty. Not a parse failure and not a
		# transport failure, and worth its own line — it means something wrote a
		# nothing up there, which is the shape of a bug rather than of bad luck.
		_log("a saved game came back empty")
	_loading -= 1
	if _loading > 0:
		return
	_finish_absorb()


## One downloaded save, folded into the live profile.
##
## Parsed into a throwaway instance of the profile script rather than into a
## hand-written reader: `Profile._apply` already knows every field, every clamp
## and every migration, and a second parser is a second place for a field to be
## forgotten. It is never added to the tree, so it never runs `_ready`, never
## touches the disk and never becomes a second opinion about anything.
func _fold(data: PackedByteArray) -> void:
	var them: Node = Profile.get_script().new()
	if not them.from_bytes(data):
		# Corrupt, truncated, or written by something that is not this game.
		# Ignored rather than acted on — and emphatically not treated as "the
		# cloud is empty", which would push over it.
		push_warning("Cloud: a saved game did not parse; leaving it alone")
		them.free()
		return
	if Profile.merge_from(them):
		_gained = true
	# Now that the local profile holds the union, asking the same question the
	# other way round answers "is the copy in the cloud missing anything" — which
	# is exactly the test for whether an upload is worth making.
	if them.merge_from(Profile):
		_cloud_behind = true
	them.free()


func _finish_absorb() -> void:
	_pulled = true
	# Released here rather than left lying about: these are Apple's objects and
	# there is no reason to hold them past the load they were held for.
	_fetched = []
	if _gained:
		_gained = false
		restored = true
		_log("restored: level %d, %d matches" % [Profile.level(), Profile.matches])
		Profile.commit_merge()

	# A conflict is only resolved by writing the agreed version back; until that
	# happens Game Center keeps handing back the same argument.
	if not _conflicts.is_empty():
		var conflicts := _conflicts
		_conflicts = []
		_set_state(State.SYNCING, "settling two saves")
		MultiplayerManager.local_player.resolve_conflicting_saved_games(
			conflicts, Profile.to_bytes(), _on_resolved)
		return

	_busy = false
	if _cloud_behind:
		push()
		return
	# A pull that sent nothing. `sent` is false because the profile may have
	# changed while the download was in the air, or in a way the merge treats as
	# ours to keep — a cosmetic swap, say, which the cloud copy is not "behind"
	# on but has still never been told about. Clearing the flag here would
	# swallow that change until the next thing the player did.
	_settled(false)


func _on_resolved(_games, error) -> void:
	_busy = false
	if error != null:
		push_warning("Cloud: could not settle the conflict — %s" % str(error))
		_set_state(State.FAILED, "iCloud could not settle two saves")
		return
	# Resolving writes `Profile.to_bytes()` as the agreed version, so this did
	# send what is in memory.
	_settled(true)


## Both copies now hold the merged version, whichever way that happened.
##
## Only ever reached with the cloud confirmed to hold something — either a fetch
## that found saves, or an upload that was checked afterwards. That is what makes
## `last_sync` a fact rather than an impression.
func _settled(sent: bool) -> void:
	if sent:
		_dirty = false
		_quiet = 0.0
		# A restore is news for as long as it is the last thing that happened.
		# Once this device has written back, "backed up" is the truer line.
		restored = false
	last_sync = int(Time.get_unix_time_from_system())
	_log("in sync (%d saved game(s) on the account)" % cloud_saves)
	_set_state(State.READY, "")


# -------------------------------------------------------------------- uploading

## Send the profile up. Refuses until this session has read what is already
## there — rule one, and the reason a new install cannot erase a record.
func push() -> void:
	if not available() or not _signed_in() or _busy:
		return
	if Profile.read_failed or not _pulled:
		return
	_busy = true
	_dirty = false
	_quiet = 0.0
	_set_state(State.SYNCING, "saving to iCloud")
	var bytes := Profile.to_bytes()
	_log("uploading %d bytes (level %d, %d matches)" % [bytes.size(),
		Profile.level(), Profile.matches])
	MultiplayerManager.local_player.save_game_data(bytes, SAVE_NAME, _on_saved)


func _on_saved(_game, error) -> void:
	_busy = false
	if error != null:
		# Not retried. The local save is already on disk and is the copy that
		# matters today, and a retry loop against a permanent refusal — no
		# entitlement, no iCloud account — would run for the life of the session
		# writing the same line into the log. The next thing the player does
		# re-arms `_dirty` and it tries again then.
		push_warning("Cloud: save refused — %s" % _describe(error))
		_log("upload refused: %s" % _describe(error))
		_set_state(State.FAILED, _reason(error))
		return
	_cloud_behind = false
	# Not believed on its own. `saveGameData` reporting success means the write
	# was accepted, not that anything is now readable from the account — and a
	# write that is accepted and then goes nowhere is precisely the failure that
	# shipped, wearing the word "saved". So the claim is checked before it is
	# made: ask Apple what it has, and only then say the profile is backed up.
	_busy = true
	_set_state(State.SYNCING, "checking it arrived")
	MultiplayerManager.local_player.fetch_saved_games(_on_verified)


func _on_verified(games, error) -> void:
	_busy = false
	if error != null or games == null:
		_log("could not confirm the upload: %s" % _describe(error))
		_set_state(State.FAILED, _reason(error))
		return
	cloud_saves = (games as Array).size()
	if cloud_saves == 0:
		# Apple took the write and has no record of it. Nothing local is lost —
		# the profile is on disk and authoritative — but the player must not be
		# told their progress is safe, because it demonstrably is not.
		push_warning("Cloud: the upload was accepted but iCloud has no saved game")
		_log("upload accepted but nothing is on the account")
		_set_state(State.FAILED, "iCloud is not keeping the backup")
		return
	_log("confirmed: %d saved game(s) on the account" % cloud_saves)
	_settled(true)


func _on_profile_changed() -> void:
	if not available():
		return
	_dirty = true
	_quiet = 0.0


func _process(delta: float) -> void:
	_since_pull += delta
	if _busy:
		_busy_for += delta
		if _busy_for >= GIVE_UP:
			_abandon()
		return
	# Until the cloud has been read once, keep asking.
	#
	# Nothing can be uploaded before that happens — `push` refuses, by design —
	# so a single failed download at launch is not one lost sync, it is a whole
	# session with no backup at all. One attempt a minute for as long as that
	# remains true, which costs nothing on a working device because the first
	# one succeeds and this never runs again.
	if not _pulled and _signed_in() and _since_pull >= PULL_EVERY:
		_log("still no answer from iCloud; asking again")
		pull()
		return
	if _dirty:
		_quiet += delta
		if _quiet >= QUIET:
			push()


## The two moments worth interrupting for.
##
## Backgrounding is where a phone save is most likely to be the last thing that
## happens before the app is killed by the system, and a quit is the same on a
## desktop. Both push whatever is outstanding immediately rather than waiting out
## the quiet window that is about to be cut short.
##
## Resuming asks the other question — whether the other device has been played
## since — and is rate-limited because iOS is generous with the notification.
func _notification(what: int) -> void:
	if not available():
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, \
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if _dirty:
				push()
		NOTIFICATION_APPLICATION_RESUMED:
			if _since_pull >= PULL_EVERY:
				pull()


# ------------------------------------------------------------------- conflicts
#
# Two devices that both wrote while offline. Game Center does not pick a winner;
# it hands back every version and waits to be told what the answer is.
#
# The answer is the merge, for the same reason it is everywhere else here: both
# players are the same person and both histories happened. Choosing between them
# would throw away whichever one they were not holding at the time.

func _on_conflicts(_player, conflicting) -> void:
	if conflicting == null or (conflicting as Array).is_empty() or Profile.read_failed:
		return
	if _busy:
		# Mid-sync. The signal fires again after `resolve` if there is still an
		# argument, and forcing it now would mean two writes racing for the same
		# name — which is how a conflict got here in the first place.
		return
	_busy = true
	_conflicts = conflicting
	_set_state(State.SYNCING, "settling two saves")
	_absorb(conflicting)


## Give up on a call that never came back, and let the next one through.
##
## `_pulled` is deliberately left alone. A download that hung may still have
## merged some of what it fetched, and in any case abandoning it says nothing
## about whether the cloud is empty — turning it off here would re-arm the one
## thing that can overwrite a record with a blank.
##
## `_conflicts` is dropped, because the objects belong to a call that is no
## longer in flight. Game Center raises the conflict again on the next fetch.
func _abandon() -> void:
	push_warning("Cloud: iCloud did not answer in %ds; giving up on this sync" % int(GIVE_UP))
	_log("gave up after %ds with %d load(s) outstanding" % [int(GIVE_UP), _loading])
	_busy = false
	_busy_for = 0.0
	_loading = 0
	_fetched = []
	_conflicts = []
	_gained = false
	_set_state(State.FAILED, "iCloud did not answer")


func _set_state(to: int, text: String) -> void:
	state = to
	status = text
	# Every call to Apple is bracketed by one of these, so this is also where the
	# clock that watches for one that never returns gets wound.
	_busy_for = 0.0
	changed.emit()
