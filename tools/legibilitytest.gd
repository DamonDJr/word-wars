extends SceneTree
## The promises behind "the letters are too small": that a phone's board spends
## its spare width on its columns, that a four-letter stamp on a one-column block
## comes out bigger for it, that the rails still have room for their chips, and
## that nothing which is not a phone's portrait board (a three-rival match, say)
## changed shape.
##
##   godot --headless --script tools/legibilitytest.gd
##
## The layout is asked of a `SubViewport` of the size in question, as
## `tools/shots.gd` does, because the headless viewport is the 1280x720 desktop
## one and every rectangle would otherwise come back the wrong shape.

## Loaded by path rather than named: under `--script` the autoloads are not
## registered when a tool's dependencies compile, and these name them. See the
## note at the top of `tools/blocktest.gd`.
var WWB: GDScript
var COS: GDScript
var FONTS: GDScript

var game: Node
var stage: SubViewport
var fails := 0


func _init() -> void:
	await process_frame
	WWB = load("res://scripts/board.gd")
	COS = load("res://scripts/cosmetics.gd")
	FONTS = load("res://scripts/fonts.gd")
	var profile := get_root().get_node("Profile")
	profile.save_path = "user://profile-legibility-test.cfg"
	profile.prefs = {"taught": true, "tutorial_offered": true}

	stage = SubViewport.new()
	stage.size = Vector2i(720, 1440)
	get_root().add_child(stage)
	game = load("res://scenes/main.tscn").instantiate()
	stage.add_child(game)
	await process_frame
	await process_frame
	if get_root().size_changed.is_connected(game._apply_orientation):
		get_root().size_changed.disconnect(game._apply_orientation)

	_the_board_itself()
	await _a_phone()
	await _a_phone_that_is_taller()
	await _a_tablet()
	await _landscape()
	_stamps_get_room()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(
		"user://profile-legibility-test.cfg"))
	print("--- %s ---" % ("legibility holds" if fails == 0 else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)


## `cell_w` is the one number the rest hangs off.
func _the_board_itself() -> void:
	print("--- the board's columns ---")
	var b: Node2D = WWB.new()
	_expect("starts square", is_equal_approx(b.cell_w, WWB.CELL))
	_expect("and is as wide as it always was",
		b.board_size().is_equal_approx(Vector2(6.0 * 42.0, 12.0 * 42.0)))

	b.place("ing", 0, 3, 5, 1, 1)
	b.blocks[0].vis = Vector2(3.0 * WWB.CELL, 5.0 * WWB.CELL)
	b.set_cell_w(54.0)
	_expect("opens out", is_equal_approx(b.cell_w, 54.0))
	_expect("and the board with it", is_equal_approx(b.board_size().x, 6.0 * 54.0))
	_expect("rows are as tall as they were", is_equal_approx(b.board_size().y, 504.0))
	_expect("blocks are carried across rather than sliding there",
		is_equal_approx(b.blocks[0].vis.x, 3.0 * 54.0))

	b.set_cell_w(400.0)
	_expect("never wider than the cap",
		is_equal_approx(b.cell_w, WWB.CELL * WWB.CELL_ASPECT_MAX))
	b.set_cell_w(3.0)
	_expect("never narrower than a row is tall", is_equal_approx(b.cell_w, WWB.CELL))
	b.free()


func _a_phone() -> void:
	print("--- a phone, 720 x 1440 ---")
	await _lay_out(Vector2i(720, 1440), true, false)
	_phone_checks()


## What a current iPhone actually is: the design width, and more height.
func _a_phone_that_is_taller() -> void:
	print("--- a phone, 720 x 1564 ---")
	await _lay_out(Vector2i(720, 1564), true, false)
	_phone_checks()


func _phone_checks() -> void:
	var r: Rect2 = game._board_rect(game.player)
	var cw: float = game.player.board.cell_w
	var rail: float = game.PORTRAIT_RAIL_MIN
	_expect("the columns are wider than the rows are tall (%.1f)" % cw,
		cw > WWB.CELL + 4.0)
	_expect("but not past the cap",
		cw <= WWB.CELL * WWB.CELL_ASPECT_MAX + 0.01)
	_expect("the board is centred on the screen",
		absf((r.position.x + r.end.x) * 0.5 - 360.0) < 0.5)
	_expect("and leaves each rail its width (%.0f)" % r.position.x,
		r.position.x >= rail + 10.0 - 0.5 and 720.0 - r.end.x >= rail + 10.0 - 0.5)
	_expect("the board is more than half the width of the screen (%.0f)" % r.size.x,
		r.size.x > 720.0 * 0.5)
	_expect("every board shares the same columns",
		is_equal_approx(game.sides[1].board.cell_w, cw))
	var keys: float = game._portrait_board_bottom()
	_expect("and it ends above the typed line", r.end.y <= keys + 0.5)


func _a_tablet() -> void:
	print("--- a tablet ---")
	await _lay_out(Vector2i(1001, 1440), true, true)
	var r: Rect2 = game._board_rect(game.player)
	_expect("opens the columns here too (%.1f)" % game.player.board.cell_w,
		game.player.board.cell_w > WWB.CELL + 2.0)
	var rival: Rect2 = game._board_rect(game.sides[1])
	_expect("without the rival's board running off the glass (%.0f)" % rival.end.x,
		rival.end.x <= 1001.0)
	_expect("or into yours", rival.position.x >= r.end.x)


func _landscape() -> void:
	print("--- landscape ---")
	await _lay_out(Vector2i(1280, 720), false, false)
	game.start_match("Magpie", 1)
	game._layout_boards()
	_expect("a duel opens its columns (%.1f)" % game.player.board.cell_w,
		is_equal_approx(game.player.board.cell_w,
			WWB.CELL * game.LANDSCAPE_CELL_ASPECT))
	var mine: Rect2 = game._board_rect(game.player)
	var theirs: Rect2 = game._board_rect(game.sides[1])
	_expect("both of them", is_equal_approx(game.sides[1].board.cell_w,
		game.player.board.cell_w))
	_expect("and the one on the right still sits the margin in from the edge",
		is_equal_approx(1280.0 - theirs.end.x, game.BOARD_MARGIN_X))
	_expect("with a centre column left between them (%.0f)" % (theirs.position.x - mine.end.x),
		theirs.position.x - mine.end.x > 300.0)
	var band: Vector2 = game._center_band()
	_expect("which is the band the centre HUD is given",
		absf(band.x - (mine.end.x + 16.0)) < 0.5
		and absf(band.y - (theirs.position.x - 16.0)) < 0.5)

	game.start_match("Magpie", 3)
	game._layout_boards()
	_expect("three rivals keep square cells",
		is_equal_approx(game.player.board.cell_w, WWB.CELL))
	for i in range(1, 4):
		_expect("rival %d too" % i,
			is_equal_approx(game.sides[i].board.cell_w, WWB.CELL))


## A four-letter stamp on a one-column block is the case the feedback was about.
func _stamps_get_room() -> void:
	print("--- a four-letter stamp on one column ---")
	var font: Font = FONTS.display()
	var square: int = WWB.stamp_size(font, "MENT", 1, WWB.CELL - 6.0 - 6.0)
	var wide: int = WWB.stamp_size(font, "MENT", 1,
		WWB.CELL * 1.3 - 6.0 - 6.0)
	_expect("is set bigger on a wider column (%d -> %d)" % [square, wide],
		wide >= square + 3)
	_expect("and a short one is never set smaller than a long one",
		WWB.stamp_size(font, "ED", 1, WWB.CELL * 1.3 - 12.0)
			>= WWB.stamp_size(font, "MENT", 1, WWB.CELL * 1.3 - 12.0))
	_expect("and a taller block asks for bigger type",
		WWB.stamp_size(font, "ST", 3, 400.0) > WWB.stamp_size(font, "ST", 1, 400.0))

	# The rim is what turned small type to mud, so it goes away before the type
	# does rather than after.
	_expect("no rim on type under 14", COS.stamp_rim(11) == 0)
	_expect("a hairline rim at middling sizes", COS.stamp_rim(17) == 1)
	_expect("and the old rim at display size", COS.stamp_rim(30) == 3)


## Put the game into a shape and let it lay itself out.
func _lay_out(size: Vector2i, portrait: bool, tablet: bool) -> void:
	stage.size = size
	game.portrait = portrait
	game.tablet = tablet
	game.safe_top = 0.0 if tablet else 55.0
	game.safe_bottom = 24.0 if tablet else 20.0
	game.start_match("Rookie", 1)
	game.phase = game.Phase.PLAY
	await process_frame
	await process_frame
	game._layout_boards()


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-62s %s" % [what, "ok" if ok else "FAILED"])
