extends Node2D
class_name WWBoard
## One player's playfield. Holds rectangular garbage blocks, each stamped with a
## prefix. Type a word starting with that prefix and the block is gone.
##
## Logic is instant and grid-based; the visuals chase the grid with real falling
## motion, and everything that happens to a block — landing, shattering — throws
## debris. The particle work is all here so `game.gd` only has to react to the
## `block_landed` signal for whole-screen effects.

signal block_landed(tier: int, at: Vector2, impact: float)

const COLS := 6
const ROWS := 12
const CELL := 42.0
const GRAVITY := 3000.0
const SLIDE_SPEED := 700.0

## Debris is cheap but not free, and a big combo can ask for a lot at once.
const MAX_BITS := 900

const TIER_COLORS := [
	Color("#5390d9"),
	Color("#48bfe3"),
	Color("#64dfdf"),
	Color("#f9c74f"),
	Color("#f8961e"),
	Color("#f94144"),
]

enum { SHARD, SPARK, DUST, RING, GHOST }


class Blk extends RefCounted:
	var w := 1
	var h := 1
	var gx := 0
	var gy := 0
	var tier := 0
	var prefix := ""
	var vis := Vector2.ZERO
	var vel := 0.0
	var squash := 0.0

	func rect_cells(at_x: int, at_y: int) -> Array:
		var cells: Array = []
		for yy in h:
			for xx in w:
				cells.append(Vector2i(at_x + xx, at_y + yy))
		return cells


class Bit extends RefCounted:
	var kind := SHARD
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var size := Vector2.ONE
	var rot := 0.0
	var spin := 0.0
	var color := Color.WHITE
	var text := ""
	var life := 1.0
	var life_max := 1.0


var accent := Color("#7bdff2")
var blocks: Array = []
var bits: Array = []
var highlight_word := ""
## How many blocks the highlighted word can actually reach. Lighting up every
## match would promise clears the word cannot deliver.
var highlight_limit := 0
var shake := 0.0

var _font: Font
var _font_bold: Font
var _panel_sb: StyleBoxFlat
var _block_sb: Array = []
var _block_sb_hot: Array = []
var _jitter := Vector2.ZERO


func _ready() -> void:
	_font = ThemeDB.fallback_font
	var fv := FontVariation.new()
	fv.base_font = _font
	fv.variation_embolden = 0.55
	_font_bold = fv

	_panel_sb = StyleBoxFlat.new()
	_panel_sb.bg_color = Color("#0e142a")
	_panel_sb.set_corner_radius_all(10)
	_panel_sb.set_border_width_all(2)
	_panel_sb.border_color = Color(accent, 0.28)

	for c: Color in TIER_COLORS:
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(7)
		sb.set_border_width_all(2)
		sb.border_color = c.lightened(0.35)
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 5
		sb.shadow_offset = Vector2(0, 3)
		_block_sb.append(sb)

		var hot := StyleBoxFlat.new()
		hot.bg_color = c.lightened(0.25)
		hot.set_corner_radius_all(7)
		hot.set_border_width_all(3)
		hot.border_color = Color.WHITE
		hot.shadow_color = Color(c, 0.75)
		hot.shadow_size = 12
		_block_sb_hot.append(hot)


func set_accent(c: Color) -> void:
	accent = c
	if _panel_sb:
		_panel_sb.border_color = Color(accent, 0.28)


func board_size() -> Vector2:
	return Vector2(COLS * CELL, ROWS * CELL)


func reset() -> void:
	blocks.clear()
	bits.clear()
	highlight_word = ""
	shake = 0.0


# ---------------------------------------------------------------- grid queries

func _occupancy() -> Array:
	var g: Array = []
	for y in ROWS:
		var row: Array = []
		row.resize(COLS)
		g.append(row)
	for b: Blk in blocks:
		for c: Vector2i in b.rect_cells(b.gx, b.gy):
			if c.y >= 0 and c.y < ROWS and c.x >= 0 and c.x < COLS:
				g[c.y][c.x] = b
	return g


func _fits(b: Blk, at_x: int, at_y: int, grid: Array) -> bool:
	if at_x < 0 or at_x + b.w > COLS:
		return false
	for c: Vector2i in b.rect_cells(at_x, at_y):
		if c.y >= ROWS:
			return false
		if c.y < 0:
			continue  # above the ceiling is legal while falling in
		var occupant = grid[c.y][c.x]
		if occupant != null and occupant != b:
			return false
	return true


func _landing_row(b: Blk, at_x: int, grid: Array) -> int:
	var y := -b.h
	while _fits(b, at_x, y + 1, grid):
		y += 1
	return y


## Highest occupied row index, or ROWS when the board is empty.
func stack_top() -> int:
	var top := ROWS
	for b: Blk in blocks:
		top = mini(top, b.gy)
	return top


func cell_count() -> int:
	var n := 0
	for b: Blk in blocks:
		n += b.w * b.h
	return n


# ------------------------------------------------------------------ mutations

## Drop a block in. Returns false when it cannot fully fit — that is a top-out.
func add_garbage(prefix: String, tier: int, w: int, h: int) -> bool:
	var b := Blk.new()
	b.w = clampi(w, 1, COLS)
	b.h = maxi(h, 1)
	b.tier = clampi(tier, 0, TIER_COLORS.size() - 1)
	b.prefix = prefix

	var grid := _occupancy()
	var choices: Array = []
	for x in range(0, COLS - b.w + 1):
		choices.append(x)
	if choices.is_empty():
		return false
	choices.shuffle()

	var best_x: int = choices[0]
	var best_y := _landing_row(b, best_x, grid)
	for x in choices:
		var y := _landing_row(b, x, grid)
		if y > best_y:
			best_x = x
			best_y = y

	b.gx = best_x
	b.gy = best_y
	b.vis = Vector2(b.gx * CELL, (b.gy - 3) * CELL)
	blocks.append(b)

	if best_y < 0:
		return false
	return true


## How many blocks a word can take out, wherever they are. Every two letters
## buys one, so four blocks stamped AL need ALIGNMENT, not ALL. Lives here so
## the board, the HUD and the CPU all measure it the same way.
static func reach(word: String) -> int:
	return maxi(1, word.length() / 2)


## Blocks this word opens, in the order a limited word consumes them: hardest
## stamp first, then whichever sits highest, since that is the one crowding the
## ceiling.
func matching_blocks(word: String) -> Array:
	var lw := word.to_lower()
	var out: Array = []
	for b: Blk in blocks:
		if b.prefix != "" and lw.begins_with(b.prefix):
			out.append(b)
	out.sort_custom(func(a: Blk, c: Blk) -> bool:
		if a.prefix.length() != c.prefix.length():
			return a.prefix.length() > c.prefix.length()
		return a.gy < c.gy)
	return out


## Remove up to `limit` blocks whose stamp opens `word`. Returns how many fell.
func clear_matching(word: String, limit: int) -> int:
	var doomed := matching_blocks(word)
	if doomed.size() > maxi(limit, 0):
		doomed.resize(maxi(limit, 0))
	if doomed.is_empty():
		return 0

	var dying := {}
	for b: Blk in doomed:
		dying[b] = true
	var kept: Array = []
	for b: Blk in blocks:
		if dying.has(b):
			_shatter(b)
		else:
			kept.append(b)

	blocks = kept
	settle()
	shake = maxf(shake, minf(0.35 + doomed.size() * 0.15, 1.0))
	return doomed.size()


## How many blocks `word` would take out right now, without touching anything.
func would_clear(word: String, limit: int) -> int:
	return mini(matching_blocks(word).size(), maxi(limit, 0))


## Everything the word opens, ignoring how far it can actually reach.
func total_matching(word: String) -> int:
	return matching_blocks(word).size()


func prefixes() -> Array:
	var out: Array = []
	for b: Blk in blocks:
		out.append(b.prefix)
	return out


## Blow the whole board apart. Used when a player tops out and loses a life —
## losing everything should look like losing everything, not like a screen wipe.
func detonate() -> void:
	for b: Blk in blocks:
		_shatter(b)
	blocks.clear()
	shake = maxf(shake, 1.4)

	# A ring from the middle to tie the individual bursts into one event.
	var mid := board_size() * 0.5
	var ring := _spawn(RING, mid, 0.7)
	ring.size = Vector2(maxf(board_size().x, board_size().y) * 0.7, 0)
	ring.color = Color("#ff6b6b")
	_add_bit(ring)


## Replace this board's contents from a peer's serialized state. Existing blocks
## are reused where they match, so the mirror keeps its falling motion instead of
## teleporting, and anything that vanished shatters — a rival's clear should read
## as a clear on your screen too.
func mirror_blocks(specs: Array) -> void:
	var pool := blocks.duplicate()
	var rebuilt: Array = []

	for spec: Array in specs:
		var found: Blk = null
		for i in pool.size():
			var b: Blk = pool[i]
			if b.w == int(spec[2]) and b.h == int(spec[3]) and b.prefix == String(spec[5]):
				found = b
				pool.remove_at(i)
				break
		if found == null:
			found = Blk.new()
			found.w = int(spec[2])
			found.h = int(spec[3])
			found.tier = int(spec[4])
			found.prefix = String(spec[5])
			found.gx = int(spec[0])
			found.gy = int(spec[1])
			found.vis = Vector2(found.gx * CELL, (found.gy - 3) * CELL)
		else:
			found.gx = int(spec[0])
			found.gy = int(spec[1])
			found.tier = int(spec[4])
		rebuilt.append(found)

	for gone: Blk in pool:
		_shatter(gone)
	if not pool.is_empty():
		shake = maxf(shake, minf(0.35 + pool.size() * 0.15, 1.0))
	blocks = rebuilt


func settle() -> void:
	var moving := true
	var guard := 0
	while moving and guard < ROWS * 4:
		guard += 1
		moving = false
		blocks.sort_custom(func(a, b): return a.gy > b.gy)
		var grid := _occupancy()
		for b: Blk in blocks:
			if _fits(b, b.gx, b.gy + 1, grid):
				b.gy += 1
				moving = true
				grid = _occupancy()


# ------------------------------------------------------------------- particles

func _add_bit(p: Bit) -> void:
	if bits.size() < MAX_BITS:
		bits.append(p)


func _spawn(kind: int, pos: Vector2, life: float) -> Bit:
	var p := Bit.new()
	p.kind = kind
	p.pos = pos
	p.life_max = life
	p.life = life
	return p


## Break a block into quarter-cell shards thrown outward from its middle, plus a
## spray of sparks and its stamp drifting up as a ghost.
func _shatter(b: Blk) -> void:
	var col: Color = TIER_COLORS[b.tier]
	var full := Vector2(b.w * CELL, b.h * CELL)
	var mid := b.vis + full * 0.5
	var nx := b.w * 2
	var ny := b.h * 2
	var piece := Vector2(full.x / nx, full.y / ny)

	for iy in ny:
		for ix in nx:
			var at := b.vis + Vector2((ix + 0.5) * piece.x, (iy + 0.5) * piece.y)
			var p := _spawn(SHARD, at, randf_range(0.5, 0.95))
			var away := at - mid
			away = away.normalized() if away.length() > 1.0 else Vector2(randf_range(-1, 1), -1).normalized()
			p.vel = away * randf_range(110.0, 300.0) + Vector2(0, randf_range(-190.0, -50.0))
			p.size = piece * randf_range(0.55, 0.95)
			p.rot = randf_range(0.0, TAU)
			p.spin = randf_range(-10.0, 10.0)
			p.color = col.lightened(randf_range(0.0, 0.35))
			_add_bit(p)

	for i in 10 + b.w * b.h * 2:
		var p := _spawn(SPARK, mid, randf_range(0.20, 0.45))
		var dir := Vector2.RIGHT.rotated(randf_range(0.0, TAU))
		p.vel = dir * randf_range(200.0, 620.0)
		p.size = Vector2(randf_range(1.5, 3.2), 0)
		p.color = Color.WHITE.lerp(col, randf_range(0.0, 0.5))
		_add_bit(p)

	var ring := _spawn(RING, mid, 0.42)
	ring.size = Vector2(maxf(full.x, full.y) * 0.9 + 26.0, 0)
	ring.color = Color.WHITE.lerp(col, 0.5)
	_add_bit(ring)

	var ghost := _spawn(GHOST, mid, 0.65)
	ghost.text = b.prefix.to_upper()
	ghost.vel = Vector2(0, -70.0)
	ghost.color = Color.WHITE
	ghost.size = Vector2(20.0 + 4.0 * mini(b.h, 3), 0)
	_add_bit(ghost)


## Dust, skittering sparks and a shockwave where a block hits the stack.
func _impact(b: Blk, impact: float) -> void:
	var col: Color = TIER_COLORS[b.tier]
	var w := b.w * CELL
	var cells := b.w * b.h
	var floor_y := b.vis.y + b.h * CELL
	var mid := Vector2(b.vis.x + w * 0.5, floor_y)

	for i in 4 + cells:
		var p := _spawn(DUST, Vector2(b.vis.x + randf_range(0.0, w), floor_y - randf_range(0.0, 6.0)),
			randf_range(0.35, 0.70))
		p.vel = Vector2(randf_range(-80.0, 80.0), randf_range(-80.0, -15.0)) * (0.6 + impact)
		p.size = Vector2(randf_range(3.0, 9.0), 0)
		p.color = col.lightened(0.25)
		_add_bit(p)

	for i in 3 + cells:
		var p := _spawn(SPARK, mid + Vector2(randf_range(-w * 0.5, w * 0.5), 0),
			randf_range(0.16, 0.38))
		p.vel = Vector2(randf_range(-260.0, 260.0), randf_range(-170.0, -40.0)) * (0.5 + impact)
		p.size = Vector2(randf_range(1.5, 3.0), 0)
		p.color = Color.WHITE.lerp(col, 0.4)
		_add_bit(p)

	var ring := _spawn(RING, mid, 0.32)
	ring.size = Vector2(18.0 + cells * 3.5, 0)
	ring.color = col
	_add_bit(ring)

	shake = maxf(shake, minf(0.25 + cells * 0.06, 1.2) * (0.4 + impact))
	block_landed.emit(b.tier, mid, impact)


## A hit arriving from outside — an attack reaching this board rather than a
## block breaking on it. Debris only; nothing about the grid changes. Without
## this an attack that crossed the whole screen simply stops when it arrives,
## and the last thing it does is the one thing it does not sell.
func splash(at: Vector2, col: Color, force: float) -> void:
	for i in int(7.0 + 15.0 * force):
		var p := _spawn(SPARK, at, randf_range(0.18, 0.44))
		var dir := Vector2.RIGHT.rotated(randf_range(0.0, TAU))
		p.vel = dir * randf_range(140.0, 460.0) * (0.5 + force)
		p.size = Vector2(randf_range(1.5, 3.4), 0)
		p.color = Color.WHITE.lerp(col, randf_range(0.2, 0.8))
		_add_bit(p)

	var ring := _spawn(RING, at, 0.34)
	ring.size = Vector2(26.0 + 46.0 * force, 0)
	ring.color = col
	_add_bit(ring)
	shake = maxf(shake, 0.22 + 0.40 * force)


func _step_bits(delta: float) -> void:
	for i in range(bits.size() - 1, -1, -1):
		var p: Bit = bits[i]
		p.life -= delta
		if p.life <= 0.0:
			bits.remove_at(i)
			continue
		match p.kind:
			SHARD:
				p.vel.y += 1500.0 * delta
				p.vel *= 1.0 - minf(0.9, 1.2 * delta)
				p.pos += p.vel * delta
				p.rot += p.spin * delta
			SPARK:
				p.vel.y += 700.0 * delta
				p.vel *= 1.0 - minf(0.9, 3.0 * delta)
				p.pos += p.vel * delta
			DUST:
				p.vel *= 1.0 - minf(0.9, 2.2 * delta)
				p.pos += p.vel * delta
			GHOST:
				p.pos += p.vel * delta
			RING:
				pass


# -------------------------------------------------------------------- runtime

func _process(delta: float) -> void:
	for b: Blk in blocks:
		var tx: float = b.gx * CELL
		var ty: float = b.gy * CELL
		b.vis.x = move_toward(b.vis.x, tx, SLIDE_SPEED * delta)
		if b.vis.y < ty:
			b.vel += GRAVITY * delta
			b.vis.y += b.vel * delta
			if b.vis.y >= ty:
				b.vis.y = ty
				var impact := clampf(b.vel / 1600.0, 0.0, 1.0)
				b.squash = impact
				if b.vel > 300.0:
					_impact(b, impact)
				b.vel = 0.0
		else:
			b.vis.y = ty
			b.vel = 0.0
		b.squash = maxf(0.0, b.squash - delta * 4.5)

	_step_bits(delta)
	shake = maxf(0.0, shake - delta * 3.0)
	queue_redraw()


# -------------------------------------------------------------------- drawing

func _draw() -> void:
	_jitter = Vector2.ZERO
	if shake > 0.0:
		_jitter = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake * 5.0
	draw_set_transform(_jitter, 0.0, Vector2.ONE)

	var size := board_size()
	draw_style_box(_panel_sb, Rect2(Vector2(-9, -9), size + Vector2(18, 18)))

	for x in range(1, COLS):
		draw_line(Vector2(x * CELL, 0), Vector2(x * CELL, size.y), Color(1, 1, 1, 0.035), 1.0)
	for y in range(1, ROWS):
		draw_line(Vector2(0, y * CELL), Vector2(size.x, y * CELL), Color(1, 1, 1, 0.035), 1.0)

	_draw_danger_zone(size)

	var hot := {}
	if highlight_word != "" and highlight_limit > 0:
		var reachable := matching_blocks(highlight_word)
		for i in mini(reachable.size(), highlight_limit):
			hot[reachable[i]] = true
	for b: Blk in blocks:
		_draw_block(b, hot.has(b))

	_draw_bits()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_danger_zone(size: Vector2) -> void:
	var top := stack_top()
	if top > 3:
		return
	var pulse := 0.10 + 0.10 * sin(Time.get_ticks_msec() / 160.0)
	var severity := 1.0 - (float(top) / 3.0)
	draw_rect(Rect2(0, 0, size.x, CELL * 3.0), Color("#f94144") * Color(1, 1, 1, pulse * severity), true)
	# A hard line at the ceiling you are about to cross.
	draw_line(Vector2(0, CELL * 0.5), Vector2(size.x, CELL * 0.5),
		Color("#f94144") * Color(1, 1, 1, 0.35 + pulse), 2.0)


func _draw_block(b: Blk, hot: bool) -> void:
	var w := b.w * CELL
	var h := b.h * CELL
	var squash := b.squash * 6.0
	var rect := Rect2(b.vis.x + 3.0 - squash * 0.5, b.vis.y + 3.0 + squash, w - 6.0 + squash, h - 6.0 - squash)

	# Motion streak, so a fast drop reads as speed rather than teleporting.
	if b.vel > 400.0:
		var tail: float = clampf(b.vel * 0.022, 5.0, 34.0)
		draw_rect(Rect2(rect.position - Vector2(0, tail), Vector2(rect.size.x, tail)),
			Color(TIER_COLORS[b.tier], 0.16), true)

	draw_style_box(_block_sb_hot[b.tier] if hot else _block_sb[b.tier], rect)

	# Inner bevel so bigger blocks do not read as flat slabs.
	draw_rect(Rect2(rect.position + Vector2(5, 5), rect.size - Vector2(10, 10)),
		Color(1, 1, 1, 0.10), false, 1.0)

	# Stamps run up to five letters, so the type has to give way on small tiles.
	var font_size := 17 + 5 * mini(b.h, 3)
	_draw_fit(_font_bold, rect.get_center(), b.prefix.to_upper(), font_size,
		rect.size.x - 10.0, Color("#0b1020"))

	if b.w * b.h > 2:
		var sub := "%d" % (b.w * b.h)
		_draw_centered(_font, rect.get_center() + Vector2(0, font_size * 0.85), sub,
			12, Color(0, 0, 0, 0.45))


func _draw_bits() -> void:
	for p: Bit in bits:
		var t := p.life / p.life_max
		match p.kind:
			SHARD:
				draw_set_transform(p.pos + _jitter, p.rot, Vector2.ONE)
				draw_rect(Rect2(-p.size * 0.5, p.size), Color(p.color, minf(1.0, t * 1.7)), true)
				draw_set_transform(_jitter, 0.0, Vector2.ONE)
			SPARK:
				var tail: float = clampf(p.vel.length() * 0.028, 3.0, 18.0)
				draw_line(p.pos, p.pos - p.vel.normalized() * tail,
					Color(p.color, minf(1.0, t * 1.8)), maxf(1.0, p.size.x * t))
			DUST:
				draw_circle(p.pos, p.size.x * (1.5 - t * 0.5), Color(p.color, t * 0.30))
			RING:
				var r: float = p.size.x * (1.0 - t) + 5.0
				draw_arc(p.pos, r, 0.0, TAU, 28, Color(p.color, t * 0.85), maxf(1.0, 3.5 * t), true)
			GHOST:
				_draw_centered(_font_bold, p.pos, p.text, int(p.size.x),
					Color(p.color, t * 0.9))


func _draw_fit(font: Font, center: Vector2, text: String, size: int, max_width: float,
		color: Color) -> void:
	if font == null or text == "":
		return
	var s := size
	while s > 9 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > max_width:
		s -= 1
	_draw_centered(font, center, text, s, color)


func _draw_centered(font: Font, center: Vector2, text: String, size: int, color: Color) -> void:
	if font == null or text == "":
		return
	var m := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var baseline := center.y - m.y * 0.5 + font.get_ascent(size)
	draw_string(font, Vector2(center.x - m.x * 0.5, baseline), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
