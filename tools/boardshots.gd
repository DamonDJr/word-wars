extends SceneTree
## One still per board theme, posed identically, for looking at the set.
##
##     godot --script tools/boardshots.gd                 every theme
##     godot --script tools/boardshots.gd -- volcano      just the one
##     godot --script tools/boardshots.gd -- --sheet      and a contact sheet
##
## `tools/shots.gd` makes marketing stills of *screens*; this makes stills of
## *paint*. The difference matters because the thing being judged here is
## whether eight boards look like eight boards — which is a question you can
## only answer with them side by side, and which no single screenshot answers at
## all. So the pose is frozen: the same seed, the same opening pile, the same
## half-typed word on the line for every theme, and the only variable left is
## the theme itself.
##
## Blocks are switched with the board, to the face drawn for it. That is not
## how the game behaves — the slot is independent and equipping Volcano does not
## touch your blocks — but it is what the set was drawn as, and a sheet that
## rendered eight boards under Solid blocks would be checking half the work.
##
## **Do not pass `--headless`.** The dummy renderer saves a blank image, exactly
## as it does for `shots.gd`. There is a real display on this machine, so a
## plain `--script` run is what works.

const OUT_DIR := "res://build/boards"
const SHOT_SIZE := Vector2i(720, 1440)
const SETTLE := 10
const KEY_EVERY := 0.02
## Fixed, so the pile and the stamps are the same pile and the same stamps on
## every board in the set. A sheet where each panel has a different board on it
## is a sheet comparing boards rather than comparing paint.
const SEED := 20260920

const AdWords = preload("res://tools/ad_words.gd")

var game: Node
var stage: SubViewport
var _wb: Node
var _profile: Node
var spent: Dictionary = {}


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	_wb = get_root().get_node("WordBank")
	_profile = get_root().get_node("Profile")

	var themes: Array = []
	for a in args:
		if not String(a).begins_with("--"):
			themes.append(String(a))
	if themes.is_empty():
		themes = ["forest", "volcano", "ocean", "space",
			"cyber", "clouds", "desert", "aurora"]

	# The pack, granted in memory only. Nothing here calls `save()`, so whatever
	# is in the real profile on this machine is untouched.
	_profile.grant(_profile.PACK_PREMIUM)

	stage = SubViewport.new()
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.size = SHOT_SIZE
	get_root().add_child(stage)
	game = load("res://scenes/main.tscn").instantiate()
	stage.add_child(game)
	await process_frame
	await process_frame
	game._skip_splash()
	await process_frame
	_force_portrait()

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for id: String in themes:
		await _shoot(id)

	quit(0)


func _force_portrait() -> void:
	if get_root().size_changed.is_connected(game._apply_orientation):
		get_root().size_changed.disconnect(game._apply_orientation)
	game.portrait = true
	game._measure_safe_area(Vector2(SHOT_SIZE))
	game._layout_boards()
	game.queue_redraw()


## One theme, from a clean match.
##
## The match is restarted per theme rather than the theme being swapped under a
## running one, because a board mid-match carries the previous theme's particles
## and a settling stack, and both would show up in the frame as differences the
## theme did not cause.
func _shoot(id: String) -> void:
	print("[boards] --- %s ---" % id)
	_profile.equipped["theme"] = id
	var face := Cosmetics.face_for_board(id)
	_profile.equipped["blocks"] = face if face != "" else "solid"
	game._apply_theme()

	_wb.rng.seed = SEED
	seed(SEED)
	spent.clear()
	game.start_match("Magpie", 1)
	game.phase = game.Phase.PLAY
	game.match_time = 95.0
	game._deal_daily_opening()
	_bury(6)
	await _hold(0.8)
	await _half_type()

	for i in SETTLE:
		await process_frame
	var img := stage.get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, id]
	img.save_png(path)
	print("[boards] %s  %dx%d" % [path, img.get_width(), img.get_height()])


func _bury(n: int) -> void:
	var stalled := 0
	for i in n:
		var tier: int = [1, 2, 3][randi() % 3]
		var spec: Dictionary = game.TIERS[tier]
		var stamp: String = game._mint_stamp(
			_wb.random_common(), game.STAMP_WANT, game.player)
		if not game.player.board.add_garbage(stamp, tier, spec["w"], spec["h"]):
			stalled += 1
			if stalled > 2:
				break
	game.player.board.snap_to_grid()


## A word left part-typed on the line, which lights everything it reaches. The
## same reason `shots.gd` does it: an idle input line is the one state where
## none of the board's highlighting is visible.
func _half_type() -> void:
	var best := ""
	for p in game.player.board.prefixes():
		var pre := String(p)
		if pre == "":
			continue
		for w in _wb.candidates(pre, 5, 13, spent, 24, AdWords.MAX_RANK):
			var cand := String(w)
			if cand.length() > best.length() and not AdWords.unpostable(cand):
				best = cand
		if best != "":
			break
	if best == "":
		return
	var upto: int = maxi(2, best.length() - 3)
	for c in upto:
		game._press_key(best[c])
		await _hold(KEY_EVERY)


func _hold(seconds: float) -> void:
	await create_timer(seconds).timeout
