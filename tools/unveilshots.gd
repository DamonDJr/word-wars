extends SceneTree
## Frames of the unveilings, rendered rather than screenshotted, for looking at.
##
## A board's (the Subway's, from three versus matches) and the pack's, both the
## version a buyer sees and the one an owner from before sees, each at the
## moments that matter: the seam, the door half open, the name landing, and the
## settled screen with its buttons.
##
##   godot --script tools/unveilshots.gd -- --safe=104,40
##   godot --script tools/unveilshots.gd -- --wide
##   godot --script tools/unveilshots.gd -- --out /some/dir
##
## Not `--headless`: the dummy renderer saves blank images. The profile is a
## scratch one, so nothing here marks the real pack's unveiling as seen.

const DEFAULT_OUT := "res://build/unveil"

var game: Node
var stage: SubViewport
var P: Node
var wide := false
var out_dir := ""


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	wide = args.has("--wide")
	var oi := args.find("--out")
	out_dir = String(args[oi + 1]) if oi >= 0 and oi + 1 < args.size() \
		else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(out_dir)

	P = get_root().get_node("Profile")
	# First, before anything can save. See the note on this in `shots.gd`.
	P.save_path = "user://profile-unveil-shots.cfg"
	P.owned = {}
	P.equipped = {}
	P.prefs = {"taught": true, "tutorial_offered": true, "premium_reveal": 1,
		"promo_seen": 99, "share_promo_seen": 99, "share_promo_day": "2999-01-01"}
	P.versus_matches = 3

	stage = SubViewport.new()
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.size = Vector2i(1280, 720) if wide else Vector2i(720, 1440)
	get_root().add_child(stage)
	game = load("res://scenes/main.tscn").instantiate()
	stage.add_child(game)
	await process_frame
	await process_frame
	if get_root().size_changed.is_connected(game._apply_orientation):
		get_root().size_changed.disconnect(game._apply_orientation)
	game.portrait = not wide
	game._measure_safe_area(stage.size)
	game._skip_splash()
	for i in 90:
		await process_frame
	game.phase = game.Phase.TITLE
	game.reveal_demo = true

	var tag := "wide" if wide else "tall"

	game._reveals = [{"kind": "board", "id": "subway",
		"how": game._reveal_how({"versus": 3}), "also": ["Rookie title"]}]
	for t in [0.9, 1.5, 1.75, 2.3, 4.0]:
		await _at(t)
		_save("board-%s-%.2f" % [tag, t])
	game._reveal_finish()

	# The owner from before: owned at boot, never shown.
	P.owned = {P.PACK_PREMIUM: true}
	P.prefs["premium_reveal"] = 0
	game._pack_at_boot = true
	for t in [1.3, 2.5, 3.6, 4.9, 7.0]:
		await _at(t)
		_save("pack-founder-%s-%.2f" % [tag, t])
	game._reveal_finish()

	# A purchase this session.
	P.prefs["premium_reveal"] = 0
	game._pack_at_boot = false
	await _at(7.0)
	_save("pack-fresh-%s" % tag)
	game._reveal_finish()

	for f in ["user://profile-unveil-shots.cfg", "user://profile-unveil-shots.cfg.bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	print("unveil frames in %s" % out_dir)
	quit(0)


## Let the front of the queue start on its own, give its scene a few frames to
## come up, then put its clock where the frame wants it.
func _at(t: float) -> void:
	while game._reveal_t <= 0.0:
		await process_frame
	for i in 12:
		await process_frame
	game._reveal_t = t
	# Beats between here and there are not what is being looked at.
	for beat: Array in game._reveal_beats():
		if float(beat[0]) <= t:
			game._reveal_heard[String(beat[1])] = true
	# The clock held while the frame is drawn, so the picture is of `t` and not
	# of however long a frame with two scenes in it took to render here. The
	# scene underneath keeps running; only the game's own tick stops.
	game.set_process(false)
	game.queue_redraw()
	game._overlay.queue_redraw()
	await process_frame
	await process_frame


func _save(name: String) -> void:
	var img := stage.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png("%s/%s.png" % [out_dir, name])
	game.set_process(true)
