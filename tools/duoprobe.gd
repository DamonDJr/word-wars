extends SceneTree
## The geometry behind `duoshots.gd`, in numbers rather than pixels.
##
##     godot --script tools/duoprobe.gd -- cover-phone
##     tools/duoshots.sh --probe     # every pose, as a table
##
## Renders nothing. Lays the game out in one pose and prints what the board and
## the keyboard actually came out as — in design units, and then in inches,
## because design units are exactly the thing that hides the problem. A unit is
## 0.0036" on an iPhone 15, 0.0031" on the Duo's cover screen and 0.0043" on its
## inner one, so two layouts that measure the same can be a third apart under a
## thumb.
##
## One pose per invocation, the way `shots.gd` takes one shot per invocation.
## Looping over the poses in a single process hangs — `start_match` is not built
## to be called seven times into the same tree, and proving that was not worth
## the time when a shell loop costs nothing.

const Poses = preload("res://tools/duo_poses.gd")

const WWKeyboard = preload("res://scripts/keyboard.gd")


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var pose := String(args[0]) if args.size() > 0 else "cover-phone"
	var spec: Dictionary = Poses.POSES[pose]
	var units: Vector2i = spec["units"]
	var px: Vector2i = spec["px"]

	var stage := SubViewport.new()
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.size = px
	stage.size_2d_override = units
	stage.size_2d_override_stretch = true
	get_root().add_child(stage)
	var game: Node = load("res://scenes/main.tscn").instantiate()
	stage.add_child(game)
	await process_frame
	await process_frame
	game._skip_splash()
	await process_frame
	if get_root().size_changed.is_connected(game._apply_orientation):
		get_root().size_changed.disconnect(game._apply_orientation)
	game.portrait = bool(spec["portrait"])
	game.tablet = bool(spec["tablet"])
	var safe: Vector2 = spec["safe"]
	game.safe_top = safe.x
	game.safe_bottom = safe.y
	game.start_match("Magpie", 1)
	game.phase = game.Phase.PLAY
	game._layout_boards()
	await process_frame

	for i in 6:
		await process_frame
	var u := Poses.unit_inches(pose)
	var board: Rect2 = game._board_rect(game.player)
	# Asked of the keyboard class directly rather than of the game, which would
	# hand back rectangles for whichever form the dev profile happens to have
	# saved. FULL in every pose, so the column compares like with like.
	var size := Vector2(units)
	var bottom: float = game._keyboard_bottom()
	# `keys` returns one flat array of key dictionaries, not rows of rows, so the
	# top of the block is the smallest y in it rather than the head of a list.
	var rows: Array = WWKeyboard.keys(size, bottom, WWKeyboard.Form.FULL)
	var top: float = INF
	var kw := 0.0
	var kh := 0.0
	for k: Dictionary in rows:
		var r: Rect2 = k["rect"]
		top = minf(top, r.position.y)
		if String(k["id"]) == "q":
			kw = r.size.x
			kh = r.size.y

	print("[probe] %s|%dx%d|%.5f|%.2f|%.2f|%.3f|%.2f|%.2f|%.2f|%.2f" % [
		pose, units.x, units.y, u,
		board.size.x * u, board.size.y * u,      # your playfield, inches
		(board.size.x / 6.0) * u,                # one cell, inches
		kw * u, kh * u,                          # one key, inches
		(bottom - top) * u,                      # keyboard block, inches
		(top - game.safe_top) * u])              # everything above it, inches
	quit(0)
