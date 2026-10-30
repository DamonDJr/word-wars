extends SceneTree
## The iPhone Duo's poses, rendered, so the layout argument can be settled by
## looking rather than by arithmetic.
##
##     godot --script tools/duoshots.gd -- cover-phone
##     godot --script tools/duoshots.gd -- cover-tablet
##     godot --script tools/duoshots.gd -- open-tablet
##     godot --script tools/duoshots.gd -- open-land
##     godot --script tools/duoshots.gd -- iphone        # the reference
##
##     tools/duoshots.sh    # all of them, into build/duo/
##
## Same seam as `shots.gd` — a `SubViewport` sized in panel pixels with
## `size_2d_override` holding the design-space viewport behind it — and the same
## three lines of layout forcing as `demoreel.gd`. See either for why each is
## there. **Do not pass `--headless`**; the dummy renderer saves a blank image.
##
## The pose table, and where each viewport size comes from, is
## `tools/duo_poses.gd`.

const Poses = preload("res://tools/duo_poses.gd")

const OUT_DIR := "res://build/duo"
## Frames to let the layout settle before the grab. Below about six the board is
## still mid-relayout and the grab catches it half-placed. Same as `shots.gd`.
const SETTLE := 10

## Letters left on the input line. A word part-typed is when the HUD says most —
## the blocks it can reach are lit and the readout under the line is populated —
## and an idle line renders as a blank strip. Same reasoning as `shots.gd`'s
## `_half_type`, without the candidate picking: the layout is what is under
## examination here, not the word.
const TYPED := "star"

var stage: SubViewport
var game: Node
var split := false


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var pose := String(args[0]) if args.size() > 0 else "cover-phone"
	if not Poses.POSES.has(pose):
		push_error("unknown pose: %s (have %s)" % [pose, ", ".join(Poses.POSES.keys())])
		quit(1)
		return
	# The split keyboard is a tablet default, and a split keyboard on a 5.4-inch
	# cover screen is its own separate argument. Off unless asked for, so the
	# pair of cover renders differ in one thing only.
	split = args.has("--split")
	# `--mode survival` (or `daily`) renders that mode's board instead of a duel:
	# the modes with nobody to play against lay their board out differently.
	var how := "duel"
	var mi := args.find("--mode")
	if mi >= 0 and mi + 1 < args.size():
		how = String(args[mi + 1])

	var spec: Dictionary = Poses.POSES[pose]
	stage = SubViewport.new()
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.size = spec["px"]
	stage.size_2d_override = spec["units"]
	stage.size_2d_override_stretch = true
	get_root().add_child(stage)

	# Before anything can save: a render must not write its pose over the dev
	# profile. See `tools/shots.gd`.
	get_root().get_node("Profile").save_path = "user://profile-duoshots.cfg"
	game = load("res://scenes/main.tscn").instantiate()
	stage.add_child(game)
	await process_frame
	await process_frame
	game._skip_splash()
	await process_frame

	# The resize hook is the only thing that would undo the three lines below.
	# See the long note in `demoreel.gd` for what each one is fighting.
	if get_root().size_changed.is_connected(game._apply_orientation):
		get_root().size_changed.disconnect(game._apply_orientation)
	Poses.apply(game, spec)
	get_root().get_node("Profile").prefs["split_keys"] = split

	if how == "survival":
		game.start_match("Survival", 0, [], game.Mode.SURVIVAL)
	elif how == "daily":
		game.start_match("Daily", 0, [], game.Mode.DAILY)
	else:
		game.start_match("Magpie", 1)
	game.phase = game.Phase.PLAY
	# A match opens on an empty board, which renders as a grid of nothing. The
	# daily's opening pile is the fix — a board that already means something on
	# frame one — and it is borrowed here the way `demoreel.gd` borrows it.
	game._deal_daily_opening()
	game._deal_daily_opening()
	game._layout_boards()
	for c in TYPED.length():
		game._press_key(TYPED[c])
	game.queue_redraw()
	game._overlay.queue_redraw()

	for i in SETTLE:
		await process_frame
	_save(pose, "" if how == "duel" else "-" + how)
	quit(0)


func _save(pose: String, suffix := "") -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var img := stage.get_texture().get_image()
	var tag := "-split" if split else ""
	var path := "%s/%s%s%s.png" % [OUT_DIR, pose, tag, suffix]
	img.save_png(path)
	print("[duo] %s  %dx%d  units=%s tablet=%s portrait=%s" % [
		path, img.get_width(), img.get_height(),
		stage.size_2d_override, game.tablet, game.portrait])
