extends SceneTree
## The premium block faces, close up, on the boards they were drawn for.
##
##   godot --script tools/faceshots.gd                    every face
##   godot --script tools/faceshots.gd -- magma coral     just these
##   godot --script tools/faceshots.gd -- --out DIR       somewhere else
##   godot --script tools/faceshots.gd -- --at 3.5        at another moment
##
## One sheet per face. On the left, every tier down the columns and every size a
## block comes in across the rows; on the right, a small pile of them packed the
## way a board packs them, three pixels apart. Behind both, the board's own
## picture with its panel over it, and on the stamps the board's own lettering:
## the same inputs `board.gd` hands the painter, so what is judged here is what
## plays. `boardshots.gd` is the face in a match; this is the face close enough
## to judge, in seconds rather than minutes.
##
## Not `--headless`: the dummy renderer saves blank images.

const CELL := 42.0
const SCALE := 1.5
const DEFAULT_OUT := "res://build/faces"

const SIZES := [[1, 1], [2, 1], [2, 2], [3, 2], [4, 3]]
const STAMPS := ["E", "ING", "TION", "ED", "STR"]

## A pile on a six-wide board: x, y, w, h, tier, stamp.
const PILE := [
	[0, 0, 2, 1, 3, "PRE"], [2, 0, 2, 1, 1, "CON"], [4, 0, 2, 3, 5, "OUT"],
	[0, 1, 3, 2, 4, "MENT"], [3, 1, 1, 2, 0, "UN"],
	[0, 3, 2, 2, 5, "STR"], [2, 3, 2, 1, 2, "ENT"], [4, 3, 2, 1, 1, "ED"],
	[2, 4, 1, 1, 4, "AL"], [3, 4, 1, 1, 0, "RE"], [4, 4, 2, 2, 3, "TION"],
	[0, 5, 1, 1, 0, "E"], [1, 5, 2, 1, 1, "ING"], [3, 5, 1, 1, 2, "S"],
]

## Board id -> the scene its preview still is named after, where they differ.
const SCENE := {"clouds": "sky_islands", "cyber": "city"}

var tiers: Array = []
var canvas: Node2D
var stage: SubViewport
var style := ""
var board := ""


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var oi := args.find("--out")
	var out := String(args[oi + 1]) if oi >= 0 and oi + 1 < args.size() \
		else ProjectSettings.globalize_path(DEFAULT_OUT)
	var ti := args.find("--at")
	var at := float(args[ti + 1]) if ti >= 0 and ti + 1 < args.size() else 0.0
	DirAccess.make_dir_recursive_absolute(out)
	tiers = (load("res://scripts/board.gd") as GDScript).get_script_constant_map()["TIER_COLORS"]

	var want: Array = []
	for a: String in args:
		if Cosmetics.BLOCK_PAIRING.has(a):
			want.append(a)
	if want.is_empty():
		want = Cosmetics.BLOCK_PAIRING.keys()

	var grid_w := 6.0 * (4.0 * CELL + 10.0)
	var pile_w := 6.0 * CELL
	var size := Vector2(24.0 + grid_w + 30.0 + pile_w + 24.0, 64.0 + _rows_h() + 24.0)
	stage = SubViewport.new()
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.size = Vector2i(size * SCALE)
	stage.size_2d_override = Vector2i(size)
	stage.size_2d_override_stretch = true
	get_root().add_child(stage)
	canvas = Node2D.new()
	stage.add_child(canvas)
	canvas.draw.connect(_paint.bind(size))

	# The faces read the clock. Waiting it out is the only honest way to put
	# a frame at a given moment without changing what is being looked at.
	while Time.get_ticks_msec() / 1000.0 < at:
		await process_frame

	for s: String in want:
		style = s
		board = String(Cosmetics.BLOCK_PAIRING[s])
		canvas.queue_redraw()
		await process_frame
		await process_frame
		await process_frame
		var img := stage.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.save_png("%s/face-%s.png" % [out, s])
		print("[faces] %s/face-%s.png" % [out, s])
	quit(0)


func _rows_h() -> float:
	var h := 0.0
	for s: Array in SIZES:
		h += float(s[1]) * CELL + 10.0
	return h


func _paint(size: Vector2) -> void:
	var full := Rect2(Vector2.ZERO, size)
	canvas.draw_rect(full, Cosmetics.theme_color(board, "top"), true)
	var pic := _art(board)
	if pic != null:
		var have := Vector2(pic.get_width(), pic.get_height())
		var src := Rect2(Vector2.ZERO, have)
		if have.x / have.y > size.x / size.y:
			src.size.x = have.y * size.x / size.y
			src.position.x = (have.x - src.size.x) * 0.5
		else:
			src.size.y = have.x * size.y / size.x
			src.position.y = (have.y - src.size.y) * 0.5
		canvas.draw_texture_rect_region(pic, full, src,
			Color(1, 1, 1, float(Cosmetics.theme_opt(board, "art_a"))))
	canvas.draw_rect(full, Color(Cosmetics.theme_color(board, "top"),
		float(Cosmetics.theme_opt(board, "art_dim")) * 0.45), true)

	var font: Font = Fonts.for_theme(board)
	var fscale := float(Cosmetics.theme_opt(board, "font_scale")) if font != null else 1.0
	if font == null:
		font = Fonts.display()
	canvas.draw_string(Fonts.bold(), Vector2(24, 40), "%s  ·  %s" % [
		style.to_upper(), board.to_upper()], HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
		Color.WHITE)

	var panel := Color(Cosmetics.theme_color(board, "panel"),
		float(Cosmetics.theme_opt(board, "panel_a")))
	var grid_w := 6.0 * (4.0 * CELL + 10.0)
	var gp := Vector2(24.0, 64.0)
	canvas.draw_rect(Rect2(gp - Vector2(6, 6), Vector2(grid_w + 2.0, _rows_h() + 6.0)),
		panel, true)
	var y := gp.y
	for si in SIZES.size():
		var s: Array = SIZES[si]
		for ti in tiers.size():
			var x := gp.x + float(ti) * (4.0 * CELL + 10.0)
			_block(Rect2(x, y, float(s[0]) * CELL, float(s[1]) * CELL), ti,
				int(s[1]), String(STAMPS[si]), font, fscale, si * 10 + ti)
		y += float(s[1]) * CELL + 10.0

	var pp := Vector2(gp.x + grid_w + 30.0, gp.y)
	canvas.draw_rect(Rect2(pp - Vector2(3, 3), Vector2(6.0 * CELL + 6.0, 6.0 * CELL + 6.0)),
		panel, true)
	var edge := Cosmetics.theme_tint(board, "frame", Color.WHITE)
	canvas.draw_rect(Rect2(pp - Vector2(3, 3), Vector2(6.0 * CELL + 6.0, 6.0 * CELL + 6.0)),
		Color(edge, 0.8), false, 2.0)
	for i in PILE.size():
		var b: Array = PILE[i]
		_block(Rect2(pp.x + float(b[0]) * CELL, pp.y + float(b[1]) * CELL,
			float(b[2]) * CELL, float(b[3]) * CELL), int(b[4]), int(b[3]),
			String(b[5]), font, fscale, 100 + i)
	# One of them hot, as the word being typed would make it.
	var hot: Array = PILE[6]
	_block(Rect2(pp.x + float(hot[0]) * CELL, pp.y + 6.0 * CELL + 24.0,
		float(hot[2]) * CELL, float(hot[3]) * CELL), int(hot[4]), int(hot[3]),
		String(hot[5]), font, fscale, 106, true)
	canvas.draw_string(Fonts.body(), Vector2(pp.x + float(hot[2]) * CELL + 12.0,
		pp.y + 6.0 * CELL + 24.0 + CELL * 0.6), "hot", HORIZONTAL_ALIGNMENT_LEFT,
		-1, 16, Color(1, 1, 1, 0.7))


## One block, inset the way `board.gd` insets it, with its stamp.
func _block(cell: Rect2, tier: int, rows: int, stamp: String, font: Font,
		fscale: float, key: int, hot := false) -> void:
	var rect := cell.grow(-3.0)
	var ink: Color = Cosmetics.draw_block_face(canvas, rect, tiers[tier], style, hot,
		float(key))
	var fs := int(float(22 + 6 * mini(rows, 3)) * fscale)
	while fs > 9 and font.get_string_size(stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x \
			> rect.size.x - 8.0:
		fs -= 1
	var m := font.get_string_size(stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	canvas.draw_string(font, Vector2(rect.get_center().x - m.x * 0.5,
		rect.get_center().y - m.y * 0.5 + font.get_ascent(fs)), stamp,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)


## Held, not just loaded. A texture loaded inside the draw callback and dropped
## at the end of it is freed before the frame is rendered, and the picture comes
## out as a white rectangle.
var _pics := {}


func _art(id: String) -> Texture2D:
	if _pics.has(id):
		return _pics[id]
	var still := "res://boards/3d/previews/%s.jpg" % String(SCENE.get(id, id))
	var path := still if ResourceLoader.exists(still) \
		else String(Cosmetics.theme_opt(id, "art"))
	_pics[id] = load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null
	return _pics[id]
