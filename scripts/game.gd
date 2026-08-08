extends Node2D
## Word Wars — match director.
##
## Rules in one breath: type a real word. Any block on your board whose stamp
## opens that word is destroyed. Whatever attack power is left over first cancels
## garbage already inbound at you, then the remainder is stamped with the LAST
## letters of your word and dropped on your opponent — your tail becomes the head
## they have to answer with.
##
## Block size comes from RHYTHM, not vocabulary: keep firing without letting the
## chain lapse and every hit lands bigger. Word length buys you nothing directly,
## it only earns you more time for the next link. Stamp length is independent of
## block size, so a 4x3 can perfectly well say A.

const BOARD_MARGIN_X := 120.0
const BOARD_TOP := 130.0
const CHIP_W := 82.0
const CHIP_H := 34.0
const CHIP_GAP := 6.0

const MIN_WORD_LEN := 3
## A stamp must have this many answers in the full dictionary, and this many in
## the common list. Tuned so a stamp reaches 3-4 letters as often as English
## allows while still leaving both sides something they can actually type.
const STAMP_MIN_VALID := 40
const STAMP_MIN_COMMON := 6
## How many recent stamps stay "spent". English endings cluster hard, so without
## this every board fills up with ING and LY.
const RECENT_STAMP_MEMORY := 8
const DROP_DELAY := 2.8
const PRESSURE_START := 22.0
const PRESSURE_MIN := 8.0
const PRESSURE_STEP := 1.5

## Block shapes by tier. Which one you send is decided by your chain, never by
## how long the word was.
const TIERS := [
	{"w": 1, "h": 1},
	{"w": 2, "h": 1},
	{"w": 2, "h": 2},
	{"w": 3, "h": 2},
	{"w": 3, "h": 3},
	{"w": 4, "h": 3},
]

## Every block aims for the same stamp length regardless of size — a 1x1 can
## carry SHIP and a 4x3 can carry A. What you get is whatever the word's tail
## can fairly support.
const STAMP_WANT := 4

## Chain length needed for each tier. The early steps come quickly so a short
## run still feels rewarding, then it stretches: the 4x3 wants nine clean words
## in a row. Combos stack on top, so a big clear mid-run is the shortcut.
const CHAIN_TIER_AT := [1, 2, 3, 5, 7, 9]

## Past the top of the ladder the chain does not simply keep paying out a 4x3
## forever — one flawless run would just end the match. The tenth word cashes the
## whole thing in as a scatter of single cells and puts you back to nothing.
const SALVO_AT := 10
const SALVO_BLOCKS := 10

## Topping out costs a life and wipes your board rather than ending the match.
## Ambient pressure keeps climbing across lives, so the board you get back is
## never as forgiving as the one you started with.
const LIVES := 3
## Nothing lands for a moment after a wipe, so you get to type before it rains.
const RESPITE := 2.5

## A word earns time proportional to its own length, so long words are not
## punished for taking longer to type — but they buy no extra block size.
const CHAIN_BASE := 1.8
const CHAIN_PER_CHAR := 0.2

const PLAYER_ACCENT := Color("#7bdff2")
const AI_ACCENT := Color("#ff8fa3")
const BG_TOP := Color("#0b1020")
const BG_BOTTOM := Color("#141a36")

## The whole scene shifts when something heavy lands, so the background is drawn
## this far past the viewport on every side to keep the edges covered.
const SHAKE_MARGIN := 56.0

enum Phase { TITLE, LOBBY, COUNTDOWN, PLAY, OVER }

## Both players stare at the same 3-2-1 before anyone can type, which matters far
## more over a network than it does alone: it is what makes the start fair.
const COUNTDOWN_TIME := 3.0


class Pending extends RefCounted:
	var tier := 0
	var prefix := ""
	var cells := 1
	var timer := 0.0


class SideState extends RefCounted:
	var board: WWBoard
	var label := ""
	var accent := Color.WHITE
	var pending: Array = []
	var used: Dictionary = {}
	var words_played := 0
	var blocks_cleared := 0
	var best_combo := 0
	var chain := 0
	var chain_timer := 0.0
	var chain_window := 1.0
	var best_chain := 0
	var lives := LIVES
	var respite := 0.0
	var life_flash := 0.0
	var salvos := 0
	var salvo_flash := 0.0
	var in_danger := false
	var flash := 0.0

	func pending_cells() -> int:
		var n := 0
		for p: Pending in pending:
			n += p.cells
		return n


var phase: int = Phase.TITLE
var player := SideState.new()
var ai_side := SideState.new()
var ai := AiOpponent.new()
var difficulty := "Duelist"

var typed := ""
var message := ""
var message_color := Color.WHITE
var message_life := 0.0
var events: Array = []
var recent_stamps: Array = []
var match_time := 0.0
var pressure_interval := PRESSURE_START
var pressure_timer := PRESSURE_START
var winner := ""

var shake := 0.0
var flash := 0.0
var flash_color := Color.WHITE
var show_rules := false
var decor: Array = []
var join_ip := "127.0.0.1"
var lobby_field := 1        # 0 = name, 1 = address
var lobby_backend := 0      # Link.Backend
var countdown := 0.0
var _last_count_beep := -1

var _font: Font
var _font_bold: Font
var _overlay: Node2D
var _chip_sb: StyleBoxFlat
var _ui_sb: StyleBoxFlat
var _hover_action := ""


func _ready() -> void:
	randomize()
	_font = ThemeDB.fallback_font
	var fv := FontVariation.new()
	fv.base_font = _font
	fv.variation_embolden = 0.6
	_font_bold = fv

	_chip_sb = StyleBoxFlat.new()
	_chip_sb.set_corner_radius_all(6)
	_ui_sb = StyleBoxFlat.new()
	_seed_decor()

	var size := get_viewport_rect().size
	var bw := WWBoard.COLS * WWBoard.CELL

	player.label = "YOU"
	player.accent = PLAYER_ACCENT
	player.board = WWBoard.new()
	player.board.position = Vector2(BOARD_MARGIN_X, BOARD_TOP)
	add_child(player.board)
	player.board.set_accent(PLAYER_ACCENT)

	ai_side.label = "CPU"
	ai_side.accent = AI_ACCENT
	ai_side.board = WWBoard.new()
	ai_side.board.position = Vector2(size.x - BOARD_MARGIN_X - bw, BOARD_TOP)
	add_child(ai_side.board)
	ai_side.board.set_accent(AI_ACCENT)

	player.board.block_landed.connect(_on_block_landed)
	ai_side.board.block_landed.connect(_on_block_landed)

	_overlay = Node2D.new()
	add_child(_overlay)
	_overlay.draw.connect(_draw_overlay)

	_net_setup()
	ai.configure(difficulty)


## Only the heavy stuff moves the whole screen — a 1x1 tapping down should not
## rattle the room, but a 4x3 arriving should be felt.
func _on_block_landed(tier: int, _at: Vector2, impact: float) -> void:
	if tier < 2:
		return
	shake = maxf(shake, (0.12 + 0.10 * (tier - 1)) * (0.55 + 0.45 * impact))
	if tier >= 4:
		_bloom(WWBoard.TIER_COLORS[tier], 0.16)


func _bloom(color: Color, amount: float) -> void:
	flash = maxf(flash, amount)
	flash_color = color


func start_match(diff: String) -> void:
	difficulty = diff
	ai.configure(diff)
	for s: SideState in [player, ai_side]:
		s.board.reset()
		s.pending.clear()
		s.used.clear()
		s.words_played = 0
		s.blocks_cleared = 0
		s.best_combo = 0
		s.chain = 0
		s.chain_timer = 0.0
		s.best_chain = 0
		s.lives = LIVES
		s.respite = 0.0
		s.life_flash = 0.0
		s.salvos = 0
		s.salvo_flash = 0.0
		s.in_danger = false
		s.flash = 0.0
	typed = ""
	message = ""
	message_life = 0.0
	events.clear()
	recent_stamps.clear()
	match_time = 0.0
	pressure_interval = PRESSURE_START
	pressure_timer = PRESSURE_START
	winner = ""
	shake = 0.0
	flash = 0.0
	_hover_action = ""
	position = Vector2.ZERO
	_overlay.position = Vector2.ZERO
	countdown = COUNTDOWN_TIME
	_last_count_beep = -1
	phase = Phase.COUNTDOWN
	_log("%s — get ready" % diff, Color("#c8d3f5"))


# ----------------------------------------------------------------------- input

func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return

	# Not a letter key — every one of those is needed for typing.
	if k.keycode == KEY_F1:
		_say("sound off" if Sfx.toggle_mute() else "sound on", Color("#8892b0"))
		Sfx.play("back", 1.4)
		return

	# The lobby's text fields own the keyboard while it is up.
	if phase == Phase.LOBBY:
		match k.keycode:
			KEY_ENTER, KEY_KP_ENTER:
				_activate("ready" if Link.connected else "join")
			KEY_ESCAPE:
				_activate("leave" if Link.connected else "title")
			KEY_TAB:
				lobby_field = 1 - lobby_field
				Sfx.play("key", 1.2)
			KEY_V when k.ctrl_pressed:
				if not Link.connected and lobby_field == 1:
					join_ip = DisplayServer.clipboard_get().strip_edges().substr(0, 48)
					Sfx.play("count", 1.2)
			KEY_C when k.ctrl_pressed:
				if Link.room_code != "":
					DisplayServer.clipboard_set(Link.room_code)
					Link.status = "code copied to your clipboard"
					Sfx.play("count", 1.3)
			KEY_BACKSPACE:
				_lobby_edit("", true)
			_:
				if Link.connected:
					return
				if k.keycode == KEY_H and lobby_field != 0:
					_activate("host")
					return
				if k.unicode > 0:
					_lobby_edit(String.chr(k.unicode), false)
		return

	if phase == Phase.TITLE or phase == Phase.OVER:
		match k.keycode:
			KEY_1: _activate("diff:Rookie")
			KEY_2: _activate("diff:Duelist")
			KEY_3: _activate("diff:Wordsmith")
			KEY_V: _activate("versus")
			KEY_R: _activate("rematch")
			KEY_H:
				show_rules = not show_rules
				Sfx.play("back", 1.2)
			KEY_ESCAPE:
				if phase == Phase.OVER:
					_activate("title")
				else:
					get_tree().quit()
		return

	# Nothing to type until GO.
	if phase == Phase.COUNTDOWN:
		return

	match k.keycode:
		KEY_BACKSPACE:
			if k.ctrl_pressed:
				typed = ""
			else:
				typed = typed.substr(0, maxi(0, typed.length() - 1))
			Sfx.play("back", randf_range(0.94, 1.06))
		KEY_ESCAPE:
			typed = ""
			Sfx.play("back", 0.8)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_TAB:
			_submit_player()
		_:
			# Modifiers and arrows report unicode 0; chr(0) builds a NUL string.
			if k.unicode <= 0:
				return
			var low := String.chr(k.unicode).to_lower()
			if low.length() == 1 and low >= "a" and low <= "z" and typed.length() < 20:
				typed += low
				# Slight per-key drift, or a held burst sounds like a machine.
				Sfx.play("key", randf_range(0.92, 1.10))


func _submit_player() -> void:
	var w := typed
	typed = ""
	# Firing an empty line is a slip, not an attempt — no penalty for it.
	if w.is_empty():
		return

	if w.length() < MIN_WORD_LEN:
		_reject(w, "too short — %d letters minimum" % MIN_WORD_LEN, Color("#ffb703"), 1.25)
		return
	if player.used.has(w):
		_reject(w, "\"%s\" already spent" % w, Color("#ffb703"), 1.1)
		return
	if not WordBank.is_valid(w):
		_reject(w, "\"%s\" is not a word" % w, Color("#ff6b6b"), 1.0)
		return
	_play_word(player, ai_side, w)


## A word you fired that did not qualify costs you the run. That is the whole
## tension of the chain: the longer it gets the more a wild guess is worth.
func _reject(word: String, reason: String, color: Color, pitch: float) -> void:
	var lost := player.chain
	player.chain = 0
	player.chain_timer = 0.0
	Sfx.play("reject", pitch)
	if lost >= 2:
		Sfx.play("lapse", 0.9)
		_say("%s — chain x%d broken" % [reason, lost], Color("#ff6b6b"))
		_log("YOU: %s rejected — chain x%d broken" % [word.to_upper(), lost], Color("#ff6b6b"))
	else:
		_say(reason, color)


# ------------------------------------------------------------------ core rules

func _play_word(attacker: SideState, defender: SideState, word: String) -> void:
	attacker.used[word] = true
	attacker.words_played += 1

	# One word only reaches so far. Blocks already on the board go first — they
	# are the ones crowding you right now — then anything still inbound.
	var budget := _reach(word)

	var cleared := attacker.board.clear_matching(word, budget)
	attacker.blocks_cleared += cleared
	budget -= cleared

	var intercepted := 0
	if budget > 0:
		var keep: Array = []
		for p: Pending in attacker.pending:
			if budget > 0 and p.prefix != "" and word.begins_with(p.prefix):
				intercepted += 1
				budget -= 1
			else:
				keep.append(p)
		attacker.pending = keep

	var combo := cleared + intercepted
	attacker.best_combo = maxi(attacker.best_combo, combo)

	# Rhythm decides the size of the hit. Fire again before the chain lapses and
	# it steps up a tier; the word you just played earns the time for the next.
	if attacker.chain_timer > 0.0:
		attacker.chain += 1
	else:
		attacker.chain = 1
	attacker.chain_window = CHAIN_BASE + word.length() * CHAIN_PER_CHAR
	attacker.chain_timer = attacker.chain_window
	attacker.best_chain = maxi(attacker.best_chain, attacker.chain)

	# Top of the ladder: cash the run in and start over.
	if attacker.chain >= SALVO_AT:
		_fire_salvo(attacker, defender, word, combo)
		return

	# Garbage is only ever removed by answering its letters, so the whole hit
	# goes out. Nothing is held back to defend with.
	var out_tier := clampi(_chain_tier(attacker.chain) + combo, 0, TIERS.size() - 1)

	if out_tier >= 0:
		if net_active():
			# The defender mints the stamp; only they know their own board.
			Link.send_attack(word, out_tier)
			defender.flash = 1.0
		else:
			var p := Pending.new()
			p.tier = out_tier
			p.prefix = _mint_stamp(word, STAMP_WANT, defender)
			p.cells = _cells(out_tier)
			p.timer = DROP_DELAY
			defender.pending.append(p)
			defender.flash = 1.0

	_voice_attack(attacker, cleared, intercepted, out_tier)
	_report(attacker, word, cleared, intercepted, out_tier)


## The audible shape of a turn. Firing rises with the chain and clears rise with
## the combo, so a good run sounds like it is climbing. The CPU is mixed well
## down — you want to hear that it acted, not compete with it.
func _voice_attack(attacker: SideState, cleared: int, intercepted: int, out_tier: int) -> void:
	var mine := attacker == player
	var quiet := 0.0 if mine else -9.0

	Sfx.play("fire", 1.0 + 0.07 * (attacker.chain - 1), quiet)

	var combo := cleared + intercepted
	if intercepted > 0:
		Sfx.play("zap", 1.0 + 0.06 * (intercepted - 1), quiet - 1.0)
	if cleared > 0:
		Sfx.play("clear", 1.0 + 0.11 * (combo - 1), quiet)
	if mine and combo >= 2:
		shake = maxf(shake, 0.14 + 0.06 * combo)
		_bloom(Color("#ffd166"), 0.10 + 0.05 * combo)
	if mine and out_tier >= 3:
		# A heavy hit going out deserves some weight behind it.
		Sfx.play("land", 0.8 - 0.05 * out_tier, -4.0)


## The payoff for a maxed chain: not one enormous block but a scatter of single
## cells, staggered so they rain in. Individually trivial to answer, collectively
## a mess — they land unevenly and clog the board in a way one big slab does not.
## Then the chain goes back to zero, so nobody rides a single run to victory.
func _fire_salvo(attacker: SideState, defender: SideState, word: String, combo: int) -> void:
	var power := SALVO_BLOCKS + combo

	if net_active():
		Link.send_salvo(word, power)
		defender.flash = 1.0
	else:
		for i in power:
			var p := Pending.new()
			p.tier = 0
			p.prefix = _mint_stamp(word, STAMP_WANT, defender)
			p.cells = 1
			p.timer = DROP_DELAY + i * 0.10
			defender.pending.append(p)
		if power > 0:
			defender.flash = 1.0

	attacker.salvos += 1
	attacker.salvo_flash = 1.0
	attacker.chain = 0
	attacker.chain_timer = 0.0

	_log("%s: %s — SALVO (%d blocks)" % [attacker.label, word.to_upper(), power],
		Color("#ffd166"))

	var mine := attacker == player
	Sfx.play("salvo", 1.0, 0.0 if mine else -8.0)
	if mine:
		_say("SALVO — %d blocks away, chain spent" % power, Color("#ffd166"))
		shake = maxf(shake, 0.5)
		_bloom(Color("#ffd166"), 0.30)


func _report(attacker: SideState, word: String, cleared: int, intercepted: int,
		out_tier: int) -> void:
	var bits: Array = []
	if cleared > 0:
		bits.append("cleared %d" % cleared)
	if intercepted > 0:
		bits.append("shot down %d" % intercepted)
	if out_tier >= 0:
		bits.append("sent %dx%d" % [TIERS[out_tier]["w"], TIERS[out_tier]["h"]])
	var tail := (" (%s)" % ", ".join(bits)) if not bits.is_empty() else " (fizzled)"

	var combo := cleared + intercepted
	var mark := " x%d" % attacker.chain if attacker.chain >= 2 else ""
	_log("%s: %s%s%s" % [attacker.label, word.to_upper(), mark, tail],
		Color("#ffd166") if combo >= 2 or attacker.chain >= 3 else attacker.accent)

	if attacker != player:
		return
	if combo >= 2:
		_say("%d-block combo!" % combo, Color("#ffd166"))
	elif cleared == 1:
		_say("block down", PLAYER_ACCENT)
	elif intercepted == 1:
		_say("shot it down", PLAYER_ACCENT)
	elif out_tier >= 0:
		_say("sent %s" % _tier_name(out_tier), PLAYER_ACCENT)
	else:
		_say("absorbed", Color("#8892b0"))


## Highest tier a chain of this length has earned on its own.
func _chain_tier(chain: int) -> int:
	var t := 0
	for i in CHAIN_TIER_AT.size():
		if chain >= int(CHAIN_TIER_AT[i]):
			t = i
		else:
			break
	return t


func _cells(tier: int) -> int:
	return int(TIERS[tier]["w"]) * int(TIERS[tier]["h"])


func _tier_name(tier: int) -> String:
	return "%dx%d block" % [TIERS[tier]["w"], TIERS[tier]["h"]]


## Brand a block with the tail of `word`, steering away from stamps this player
## is already staring at or has just been hit with.
func _mint_stamp(word: String, want: int, defender: SideState) -> String:
	var avoid := {}
	for s: String in defender.board.prefixes():
		avoid[s] = true
	for p: Pending in defender.pending:
		avoid[p.prefix] = true
	for s: String in recent_stamps:
		avoid[s] = true

	var stamp := WordBank.stamp_from_tail(word, want, STAMP_MIN_VALID, STAMP_MIN_COMMON, avoid)
	recent_stamps.push_front(stamp)
	if recent_stamps.size() > RECENT_STAMP_MEMORY:
		recent_stamps.resize(RECENT_STAMP_MEMORY)
	return stamp


func _reach(word: String) -> int:
	return WWBoard.reach(word)


## Blocks `word` would remove right now: landed ones first, then interceptions,
## both drawing on the same reach.
func _preview_hits(side: SideState, word: String) -> int:
	if word.length() < MIN_WORD_LEN:
		return 0
	var budget := _reach(word)
	var n := side.board.would_clear(word, budget)
	budget -= n
	for p: Pending in side.pending:
		if budget <= 0:
			break
		if p.prefix != "" and word.begins_with(p.prefix):
			n += 1
			budget -= 1
	return n


## Everything the word opens, whether it can reach that far or not.
func _preview_matches(side: SideState, word: String) -> int:
	if word.length() < MIN_WORD_LEN:
		return 0
	var n := side.board.total_matching(word)
	for p: Pending in side.pending:
		if p.prefix != "" and word.begins_with(p.prefix):
			n += 1
	return n


# --------------------------------------------------------------------- runtime

func _process(delta: float) -> void:
	player.board.highlight_word = typed
	player.board.highlight_limit = _reach(typed) if typed.length() >= MIN_WORD_LEN else 0
	var ai_typing := net_typing if net_active() else ai.visible_text()
	ai_side.board.highlight_word = ai_typing
	ai_side.board.highlight_limit = _reach(ai_typing) if ai_typing.length() >= MIN_WORD_LEN else 0

	message_life = maxf(0.0, message_life - delta)

	# Shake the world, then hold the menus still on top of it.
	shake = maxf(0.0, shake - delta * 2.6)
	flash = maxf(0.0, flash - delta * 1.8)
	var kick := Vector2.ZERO
	if shake > 0.0:
		kick = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake * 16.0
	position = kick
	_overlay.position = -kick

	for e: Dictionary in events:
		e["life"] = maxf(0.0, e["life"] - delta * 0.12)
	player.flash = maxf(0.0, player.flash - delta * 2.0)
	ai_side.flash = maxf(0.0, ai_side.flash - delta * 2.0)
	player.salvo_flash = maxf(0.0, player.salvo_flash - delta * 2.2)
	ai_side.salvo_flash = maxf(0.0, ai_side.salvo_flash - delta * 2.2)
	player.life_flash = maxf(0.0, player.life_flash - delta * 0.9)
	ai_side.life_flash = maxf(0.0, ai_side.life_flash - delta * 0.9)

	# The playfields have nothing to say on the front-of-house screens.
	var showing_boards := phase != Phase.TITLE and phase != Phase.LOBBY
	player.board.visible = showing_boards
	ai_side.board.visible = showing_boards
	if phase != Phase.PLAY:
		_step_decor(delta)

	if phase == Phase.COUNTDOWN:
		countdown -= delta
		var mark := int(ceil(countdown))
		if mark != _last_count_beep and mark > 0:
			_last_count_beep = mark
			Sfx.play("count", 1.0 + 0.10 * (3 - mark))
		if countdown <= 0.0:
			phase = Phase.PLAY
			Sfx.play("start")
			_log("GO!", Color("#ffd166"))

	if phase == Phase.PLAY:
		match_time += delta
		for s: SideState in [player, ai_side]:
			if s.chain_timer > 0.0:
				s.chain_timer -= delta
				if s.chain_timer <= 0.0:
					# Losing a run you had going should sting audibly.
					if s == player and s.chain >= 2:
						Sfx.play("lapse")
					s.chain = 0
		_tick_danger(player)
		_tick_pending(player, delta)
		_tick_pressure(delta)
		if net_active():
			# The rival's queue and lives are mirrored, not simulated — they run
			# on their machine, where their board actually lives.
			_push_state(delta)
		else:
			_tick_pending(ai_side, delta)
			_tick_ai(delta)

	queue_redraw()
	_overlay.queue_redraw()


## Sound the alarm once on the way into the red, not every frame you sit there.
func _tick_danger(side: SideState) -> void:
	var danger := side.board.stack_top() <= 3
	if danger and not side.in_danger:
		Sfx.play("danger")
	side.in_danger = danger


func _tick_pending(side: SideState, delta: float) -> void:
	if side.respite > 0.0:
		side.respite -= delta
		return
	for i in range(side.pending.size() - 1, -1, -1):
		var p: Pending = side.pending[i]
		p.timer -= delta
		if p.timer <= 0.0:
			side.pending.remove_at(i)
			var spec: Dictionary = TIERS[p.tier]
			var fit: bool = side.board.add_garbage(p.prefix, p.tier, spec["w"], spec["h"])
			side.board.shake = maxf(side.board.shake, 0.5)
			# Bigger blocks land lower and louder.
			Sfx.play("land", 1.15 - 0.09 * p.tier,
				(-1.0 if side == player else -7.0) + p.tier * 0.6)
			if not fit:
				_lose_life(side)
				return


func _tick_pressure(delta: float) -> void:
	pressure_timer -= delta
	if pressure_timer > 0.0:
		return
	pressure_interval = maxf(PRESSURE_MIN, pressure_interval - PRESSURE_STEP)
	pressure_timer = pressure_interval

	# Both peers run the clock so both HUDs agree, but only the host decides when
	# it actually fires — otherwise the two boards drift apart.
	if net_active() and not Link.is_host:
		return
	var source := WordBank.random_common()
	if net_active():
		Link.send_pressure(source)
	_seed_pressure(source)


## One seed per board. Each side mints its own stamp from the shared word, so the
## stamps stay varied against whatever that player is already holding.
func _seed_pressure(source: String) -> void:
	var sides: Array = [player] if net_active() else [player, ai_side]
	for side: SideState in sides:
		var p := Pending.new()
		p.tier = 0
		p.prefix = _mint_stamp(source, STAMP_WANT, side)
		p.cells = _cells(0)
		p.timer = DROP_DELAY
		side.pending.append(p)
	_log("pressure rising — both boards seeded", Color("#8892b0"))


func _tick_ai(delta: float) -> void:
	var targets := ai_side.board.prefixes()
	for p: Pending in ai_side.pending:
		targets.append(p.prefix)
	var word := ai.update(delta, targets, ai_side.used)
	if ai.fumbled:
		ai.fumbled = false
		if ai_side.chain >= 2:
			_log("CPU: fumbled — chain x%d broken" % ai_side.chain, Color("#8892b0"))
		ai_side.chain = 0
		ai_side.chain_timer = 0.0
	if word != "":
		_play_word(ai_side, player, word)


## Hitting the ceiling wipes the board and costs a life. The wipe is the whole
## point: you get a clean board back, but the pressure clock never rewinds, so
## the third life is played under conditions the first never saw.
func _lose_life(side: SideState) -> void:
	side.lives -= 1
	side.chain = 0
	side.chain_timer = 0.0
	side.pending.clear()
	side.respite = RESPITE
	side.life_flash = 1.0
	side.in_danger = false

	# Take the whole board apart rather than blinking it out of existence.
	side.board.detonate()
	shake = maxf(shake, 0.7)

	if side.lives <= 0:
		_end_match(side)
		return

	var mine := side == player
	Sfx.play("lose" if mine else "land", 1.0 if mine else 0.7, 0.0 if mine else -6.0)
	if mine:
		_bloom(Color("#ff6b6b"), 0.35)
		_say("BOARD LOST — %d %s left" % [side.lives, "life" if side.lives == 1 else "lives"],
			Color("#ff6b6b"))
	_log("%s topped out — %d %s left" % [
		side.label, side.lives, "life" if side.lives == 1 else "lives"], Color("#ff6b6b"))


func _end_match(loser: SideState) -> void:
	phase = Phase.OVER
	if net_active():
		winner = ai_side.label if loser == player else "YOU"
		if loser == player:
			Link.send_topped_out()
	else:
		winner = "CPU" if loser == player else "YOU"
	loser.board.shake = 1.0
	Sfx.play("win" if winner == "YOU" else "lose")
	_log("%s is out of lives — %s wins" % [loser.label, winner], Color("#ffd166"))


func _say(text: String, color: Color) -> void:
	message = text
	message_color = color
	message_life = 2.2


func _log(text: String, color: Color) -> void:
	events.push_front({"text": text, "color": color, "life": 1.0})
	if events.size() > 7:
		events.resize(7)


# --------------------------------------------------------------------- drawing

func _draw() -> void:
	var size := get_viewport_rect().size
	var m := SHAKE_MARGIN
	draw_rect(Rect2(-m, -m, size.x + m * 2.0, size.y + m * 2.0), BG_TOP, true)
	# Soft vertical wash so the board area lifts off the background.
	for i in 24:
		var t := float(i) / 24.0
		draw_rect(Rect2(-m, size.y * t, size.x + m * 2.0, size.y / 24.0 + 1.0),
			BG_TOP.lerp(BG_BOTTOM, t), true)
	draw_rect(Rect2(-m, size.y, size.x + m * 2.0, m), BG_BOTTOM, true)

	if phase == Phase.TITLE or phase == Phase.LOBBY:
		return

	_draw_side_header(player, player.board.position)
	_draw_side_header(ai_side, ai_side.board.position)
	_draw_chain_meter(player)
	_draw_chain_meter(ai_side)
	_draw_pending(player, true)
	_draw_pending(ai_side, false)
	if phase != Phase.COUNTDOWN:
		_draw_center_hud(size)
	_draw_player_input(size)
	_draw_ai_input(size)


func _draw_side_header(side: SideState, board_pos: Vector2) -> void:
	var bw := WWBoard.COLS * WWBoard.CELL
	var center_x := board_pos.x + bw * 0.5
	_text_centered(_font_bold, Vector2(center_x, BOARD_TOP - 44.0), side.label, 26, side.accent)

	var sub := "%d words · %d cleared" % [side.words_played, side.blocks_cleared]
	_text_centered(_font, Vector2(center_x, BOARD_TOP - 20.0), sub, 13, Color("#7c88ad"))

	# Lives, as pips beside the board name. The last one pulses, because being on
	# your last life is the single most important thing on the screen.
	var pip := 13.0
	var gap := 7.0
	var span := LIVES * pip + (LIVES - 1) * gap
	for i in LIVES:
		var r := Rect2(center_x - span * 0.5 + i * (pip + gap), BOARD_TOP - 76.0, pip, pip)
		if i < side.lives:
			var tint := side.accent
			if side.lives == 1:
				tint = Color("#ff6b6b") * Color(1, 1, 1,
					0.65 + 0.35 * sin(Time.get_ticks_msec() / 150.0))
			draw_rect(r, tint, true)
		else:
			draw_rect(r, Color("#2a3355"), true)
			draw_rect(r, Color("#ff6b6b") * Color(1, 1, 1, 0.35), false, 1.0)

	# The board is being put back together; say so rather than leaving it blank.
	if side.respite > 0.0:
		_text_centered(_font_bold, side.board.position + side.board.board_size() * 0.5,
			"%d %s LEFT" % [side.lives, "LIFE" if side.lives == 1 else "LIVES"], 30,
			Color("#ff6b6b") * Color(1, 1, 1, clampf(side.respite, 0.0, 1.0)))

	if side.life_flash > 0.0:
		var lr := Rect2(board_pos - Vector2(13, 13),
			Vector2(bw + 26, WWBoard.ROWS * WWBoard.CELL + 26))
		draw_rect(lr, Color("#ff6b6b") * Color(1, 1, 1, side.life_flash * 0.8), false, 4.0)

	if side.flash > 0.0:
		var r := Rect2(board_pos - Vector2(13, 13), Vector2(bw + 26, WWBoard.ROWS * WWBoard.CELL + 26))
		draw_rect(r, Color(side.accent, side.flash * 0.35), false, 3.0)


## One segment per block size, lit up to the current chain. The live segment
## drains as the chain runs out, so you can see both how big your next hit will
## be and how long you have to keep it.
func _draw_chain_meter(side: SideState) -> void:
	var bw := WWBoard.COLS * WWBoard.CELL
	var x := side.board.position.x
	var y := BOARD_TOP + WWBoard.ROWS * WWBoard.CELL + 12.0
	var n := TIERS.size()
	var gap := 4.0
	var seg := (bw - gap * (n - 1)) / float(n)

	# The instant a salvo goes off, the whole meter whites out and empties.
	if side.salvo_flash > 0.0:
		for i in n:
			draw_rect(Rect2(x + i * (seg + gap), y, seg, 7.0),
				Color(1, 1, 1, side.salvo_flash), true)
		return

	# Tiers no longer arrive one per word, so the next segment fills gradually to
	# show how much of the run still stands between you and it.
	var earned: int = _chain_tier(side.chain) if side.chain > 0 else -1

	for i in n:
		var r := Rect2(x + i * (seg + gap), y, seg, 7.0)
		var col: Color = WWBoard.TIER_COLORS[i]
		if i <= earned:
			draw_rect(r, col, true)
			continue
		draw_rect(r, Color("#1a2140"), true)
		if i == earned + 1 and side.chain > 0:
			var from: float = float(CHAIN_TIER_AT[i - 1]) if i > 0 else 0.0
			var span: float = maxf(1.0, float(CHAIN_TIER_AT[i]) - from)
			var p := clampf((side.chain - from) / span, 0.0, 1.0)
			draw_rect(Rect2(r.position, Vector2(r.size.x * p, r.size.y)), Color(col, 0.45), true)

	# Time left on the run, spanning the whole meter.
	if side.chain > 0:
		var frac := clampf(side.chain_timer / maxf(side.chain_window, 0.001), 0.0, 1.0)
		draw_rect(Rect2(x, y + 10.0, bw, 2.0), Color("#1a2140"), true)
		draw_rect(Rect2(x, y + 10.0, bw * frac, 2.0), Color(side.accent, 0.9), true)


## Inbound garbage, shown on the inner edge of each board: stamp, a miniature of
## the shape that is coming, and a fuse. Answer the stamp before the fuse burns
## out and the block never lands.
func _draw_pending(side: SideState, on_right: bool) -> void:
	if side.pending.is_empty():
		return
	var bw := WWBoard.COLS * WWBoard.CELL
	var x: float = (side.board.position.x + bw + 16.0) if on_right else (side.board.position.x - 16.0 - CHIP_W)
	var y := BOARD_TOP
	var aiming: String = typed if side == player else (net_typing if net_active() else ai.visible_text())
	# Chips only light up while the word still has reach left after the board.
	var budget := 0
	if aiming.length() >= MIN_WORD_LEN:
		budget = _reach(aiming) - side.board.would_clear(aiming, _reach(aiming))

	for p: Pending in side.pending:
		var rect := Rect2(x, y, CHIP_W, CHIP_H)
		var locked: bool = budget > 0 and p.prefix != "" and aiming.begins_with(p.prefix)
		if locked:
			budget -= 1

		_chip_sb.bg_color = Color(WWBoard.TIER_COLORS[p.tier], 0.92)
		_chip_sb.border_color = Color.WHITE if locked else Color(0, 0, 0, 0.35)
		_chip_sb.set_border_width_all(3 if locked else 1)
		draw_style_box(_chip_sb, rect)

		_text_fit(_font_bold, Vector2(rect.position.x + 28.0, rect.get_center().y - 2.0),
			p.prefix.to_upper(), 15, 48.0, Color("#0b1020"), 8)
		_draw_shape_pip(Vector2(rect.end.x - 20.0, rect.get_center().y - 2.0), p.tier)

		var fuse := 1.0 - clampf(p.timer / DROP_DELAY, 0.0, 1.0)
		draw_rect(Rect2(x + 4, y + CHIP_H - 7, (CHIP_W - 8) * fuse, 3), Color("#0b1020"), true)

		y += CHIP_H + CHIP_GAP
		if y > BOARD_TOP + WWBoard.ROWS * WWBoard.CELL - CHIP_H:
			break


## Tiny w-by-h dot grid so the chip reads as "a 3x2 is coming", not just "a block".
func _draw_shape_pip(center: Vector2, tier: int) -> void:
	var w: int = TIERS[tier]["w"]
	var h: int = TIERS[tier]["h"]
	var dot := 3.0
	var step := dot + 1.0
	var origin := center - Vector2(w * step, h * step) * 0.5
	for cy in h:
		for cx in w:
			draw_rect(Rect2(origin + Vector2(cx * step, cy * step), Vector2(dot, dot)),
				Color(0, 0, 0, 0.55), true)


func _draw_center_hud(size: Vector2) -> void:
	var cx := size.x * 0.5

	_text_centered(_font_bold, Vector2(cx, BOARD_TOP + 6.0),
		"%d:%02d" % [int(match_time) / 60, int(match_time) % 60], 30, Color("#e6ecff"))
	_text_centered(_font, Vector2(cx, BOARD_TOP + 32.0), difficulty.to_upper(), 12, Color("#5d6a92"))

	var next_seed: int = int(ceil(pressure_timer))
	_text_centered(_font, Vector2(cx, BOARD_TOP + 62.0),
		"pressure in %ds" % next_seed, 12, Color("#7c88ad"))

	# Kept narrow enough to clear the inbound-garbage chips on either side.
	var log_width := size.x - 2.0 * (BOARD_MARGIN_X + WWBoard.COLS * WWBoard.CELL + 16.0 + CHIP_W) - 16.0
	var y := BOARD_TOP + 110.0
	for e: Dictionary in events:
		var alpha: float = 0.25 + 0.75 * float(e["life"])
		_text_fit(_font, Vector2(cx, y), e["text"], 13, log_width, Color(e["color"], alpha), 9)
		y += 22.0


func _draw_player_input(size: Vector2) -> void:
	var bw := WWBoard.COLS * WWBoard.CELL
	var cx := player.board.position.x + bw * 0.5
	var base_y := BOARD_TOP + WWBoard.ROWS * WWBoard.CELL + 46.0

	var hits := _preview_hits(player, typed)
	var col := PLAYER_ACCENT
	if typed.length() >= MIN_WORD_LEN:
		if hits > 0:
			col = Color("#ffd166")
		elif not WordBank.is_valid(typed):
			col = Color("#7c88ad")

	var caret := "_" if fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.55 else " "
	_text_fit(_font_bold, Vector2(cx, base_y), typed.to_upper() + caret, 34, bw + 46.0, col)

	var status_y := base_y + 26.0
	if hits > 0:
		var matches := _preview_matches(player, typed)
		if matches > hits:
			# Teach the rule at the moment it bites.
			_text_centered(_font, Vector2(cx, status_y),
				"takes out %d of %d — a longer word reaches further" % [hits, matches],
				13, Color("#f8961e"))
		else:
			_text_centered(_font, Vector2(cx, status_y),
				"takes out %d block%s" % [hits, "" if hits == 1 else "s"], 13, Color("#ffd166"))
	elif player.chain + 1 >= SALVO_AT:
		# Telegraph the payoff, or it arrives out of nowhere.
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 110.0)
		_text_centered(_font_bold, Vector2(cx, status_y),
			"CHAIN x%d · NEXT HIT IS A SALVO" % player.chain, 14,
			Color("#ffd166") * Color(1, 1, 1, pulse))
	elif player.chain >= 2:
		var next_tier := _chain_tier(player.chain + 1)
		_text_centered(_font_bold, Vector2(cx, status_y),
			"CHAIN x%d · next hit %s" % [player.chain, _tier_name(next_tier)], 13,
			WWBoard.TIER_COLORS[next_tier])
	elif message_life > 0.0:
		_text_centered(_font, Vector2(cx, status_y), message, 13,
			Color(message_color, clampf(message_life, 0.0, 1.0)))
	else:
		_text_centered(_font, Vector2(cx, status_y),
			"keep firing without pausing — the chain makes blocks bigger", 12, Color("#4d5878"))


func _draw_ai_input(size: Vector2) -> void:
	var bw := WWBoard.COLS * WWBoard.CELL
	var cx := ai_side.board.position.x + bw * 0.5
	var base_y := BOARD_TOP + WWBoard.ROWS * WWBoard.CELL + 46.0

	var shown := (net_typing if net_active() else ai.visible_text()).to_upper()
	if shown == "":
		_text_centered(_font, Vector2(cx, base_y), "…", 34, Color("#3d4666"))
		return
	_text_fit(_font_bold, Vector2(cx, base_y), shown, 34, bw + 46.0, Color(AI_ACCENT, 0.9))

	# The CPU's bar shows how far through the word it is. A human rival has no
	# such tell, so their letters simply appear as they type them.
	if net_active():
		return
	var bar_w := 150.0
	var p := ai.progress()
	draw_rect(Rect2(cx - bar_w * 0.5, base_y + 27.0, bar_w, 4.0), Color("#232b4a"), true)
	draw_rect(Rect2(cx - bar_w * 0.5, base_y + 27.0, bar_w * p, 4.0), AI_ACCENT, true)


# ------------------------------------------------------------------- overlays

func _draw_overlay() -> void:
	var size := get_viewport_rect().size
	if flash > 0.0:
		_overlay.draw_rect(Rect2(-SHAKE_MARGIN, -SHAKE_MARGIN,
			size.x + SHAKE_MARGIN * 2.0, size.y + SHAKE_MARGIN * 2.0),
			Color(flash_color, flash * 0.5), true)
	if phase == Phase.TITLE:
		_draw_title(size)
	elif phase == Phase.LOBBY:
		_draw_lobby(size)
	elif phase == Phase.COUNTDOWN:
		_draw_countdown(size)
	elif phase == Phase.OVER:
		_draw_gameover(size)


## Big and unmissable, scaling down as each number's second runs out.
func _draw_countdown(size: Vector2) -> void:
	var cx := size.x * 0.5
	var cy := size.y * 0.42
	var mark := int(ceil(countdown))
	var frac: float = countdown - floor(countdown)
	var label := str(mark) if mark > 0 else "GO"
	var tint: Color = Color("#ffd166") if mark <= 1 else PLAYER_ACCENT

	# Ring closing in on the number.
	_overlay.draw_arc(Vector2(cx, cy), 78.0, 0.0, TAU, 48, Color(tint, 0.13), 4.0, true)
	_overlay.draw_arc(Vector2(cx, cy), 78.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 48,
		Color(tint, 0.7), 4.0, true)
	var pop: float = 1.0 + (1.0 - frac) * 0.35
	_otext(_font_bold, Vector2(cx, cy), label, int(96 * pop), Color(tint, 0.5 + 0.5 * frac))
	_otext(_font, Vector2(cx, cy + 96.0),
		"versus %s" % (ai_side.label if net_active() else difficulty), 16, Color("#8d99bd"))


func _draw_title(size: Vector2) -> void:
	var cx := size.x * 0.5
	_overlay.draw_rect(Rect2(-SHAKE_MARGIN, -SHAKE_MARGIN,
		size.x + SHAKE_MARGIN * 2.0, size.y + SHAKE_MARGIN * 2.0), Color(BG_TOP, 0.90), true)
	_draw_decor()

	# Wordmark, with the tail of WARS picked out — the whole game in one gag.
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 700.0)
	_otext(_font_bold, Vector2(cx, 96), "WORD WARS", 82, Color("#e6ecff"))
	var wm := _font_bold.get_string_size("WORD WARS", HORIZONTAL_ALIGNMENT_LEFT, -1, 82)
	_overlay.draw_rect(Rect2(cx - wm.x * 0.5, 138, wm.x, 3),
		Color(PLAYER_ACCENT, 0.25 + 0.35 * pulse), true)
	_otext(_font, Vector2(cx, 162), "your endings become their beginnings", 17, Color("#8d99bd"))

	if show_rules:
		_draw_rules_panel(size)
	else:
		_draw_how_cards(cx)

	_otext(_font_bold, Vector2(cx, 392), "CHOOSE YOUR OPPONENT", 15, Color("#7c88ad"))
	for b: Dictionary in _menu_buttons():
		_draw_menu_button(b)

	_otext(_font, Vector2(cx, 630), "click a card, or press 1 / 2 / 3", 14, Color("#5d6a92"))
	_otext(_font, Vector2(cx, 664),
		"%s — full rules      F1 — %s      ESC — quit" % [
			"H" if not show_rules else "H to hide", "sound on" if Sfx.muted else "mute"],
		13, Color("#4d5878"))


## Three worked examples instead of a wall of instructions. Each one shows the
## actual thing it is describing, drawn with the same routines the game uses.
func _draw_how_cards(cx: float) -> void:
	var card_w := 356.0
	var card_h := 178.0
	var top := 194.0
	for i in 3:
		var x: float = cx + (i - 1) * (card_w + 18.0) - card_w * 0.5
		var r := Rect2(x, top, card_w, card_h)
		_panel(r, Color("#141b33"), Color(PLAYER_ACCENT, 0.16), 12.0)
		var mid := r.position.x + card_w * 0.5
		var caption := top + 158.0

		match i:
			0:
				_otext(_font_bold, Vector2(mid, top + 24), "1 · BRAND", 14, PLAYER_ACCENT)
				_draw_split_word(mid, top + 64, "FRIEND", "SHIP", 26)
				_draw_arrow(mid, top + 86, 24.0, Color("#5d6a92"))
				_mini_block(Vector2(mid, top + 130), Vector2(66, 34), 2, "SHIP")
				_otext(_font, Vector2(mid, caption), "your word's tail brands their block",
					12, Color("#8d99bd"))
			1:
				_otext(_font_bold, Vector2(mid, top + 24), "2 · SMASH", 14, Color("#ffd166"))
				# A burst of shards, the way it actually looks in play.
				var at := Vector2(mid, top + 76)
				for s in 10:
					var a := TAU * s / 10.0 + Time.get_ticks_msec() / 900.0
					var d := 26.0 + 5.0 * sin(Time.get_ticks_msec() / 260.0 + s)
					_overlay.draw_rect(Rect2(at + Vector2(cos(a), sin(a)) * d
						- Vector2(2.5, 2.5), Vector2(5, 5)),
						Color(WWBoard.TIER_COLORS[2], 0.5), true)
				_mini_block(at, Vector2(66, 34), 2, "SHIP")
				_draw_split_word(mid, top + 128, "SHIP", "MENTS", 24, true)
				_otext(_font, Vector2(mid, caption), "longer words smash more at once",
					12, Color("#8d99bd"))
			2:
				_otext(_font_bold, Vector2(mid, top + 24), "3 · CHAIN", 14, Color("#f8961e"))
				var seg := 46.0
				var lit := 1 + int(Time.get_ticks_msec() / 420.0) % 6
				for k in 6:
					var sx := mid - (6 * seg + 5 * 4.0) * 0.5 + k * (seg + 4.0)
					_overlay.draw_rect(Rect2(sx, top + 50, seg, 9),
						WWBoard.TIER_COLORS[k] if k < lit else Color("#1a2140"), true)
				# Bottom-aligned so the escalation reads at a glance.
				var shapes := [Vector2(22, 22), Vector2(46, 22), Vector2(46, 46)]
				var base := top + 136.0
				for k in 3:
					var sz: Vector2 = shapes[k]
					_mini_block(Vector2(mid - 76.0 + k * 76.0, base - sz.y * 0.5), sz, k * 2, "")
				_otext(_font, Vector2(mid, caption), "a run hits harder, then detonates",
					12, Color("#8d99bd"))


func _draw_lobby(size: Vector2) -> void:
	var cx := size.x * 0.5
	_overlay.draw_rect(Rect2(-SHAKE_MARGIN, -SHAKE_MARGIN,
		size.x + SHAKE_MARGIN * 2.0, size.y + SHAKE_MARGIN * 2.0), Color(BG_TOP, 0.92), true)
	_draw_decor()

	_otext(_font_bold, Vector2(cx, 104), "VERSUS", 66, Color("#e6ecff"))
	_otext(_font, Vector2(cx, 150), "two keyboards, one word chain", 16, Color("#8d99bd"))

	if Link.connected:
		_draw_room(cx)
	else:
		_draw_lobby_setup(cx)

	for b: Dictionary in _menu_buttons():
		_draw_menu_button(b)

	if Link.status != "":
		var waiting := Link.active and not Link.connected
		var tint := Color("#ffd166") if waiting else Color("#8d99bd")
		if Link.status.begins_with("could not") or Link.status.contains("failed") \
				or Link.status.contains("not installed") or Link.status.contains("not wired"):
			tint = Color("#ff6b6b")
		var dots := ".".repeat(1 + int(Time.get_ticks_msec() / 400.0) % 3) if waiting else ""
		_otext(_font_bold, Vector2(cx, 620.0), Link.status + dots, 14, tint)


## Before anyone has connected: who you are, where they are, which backend.
func _draw_lobby_setup(cx: float) -> void:
	var caret := "_" if fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.55 else " "

	for i in 2:
		var is_name := i == 0
		var r: Rect2 = _lobby_field_rect(i)
		var focused: bool = lobby_field == i
		_panel(r, Color("#111730"), Color(PLAYER_ACCENT, 0.55 if focused else 0.2), 10.0,
			2.0 if focused else 1.0)
		var hosting_code: bool = Link.is_host and Link.room_code != ""
		var label := "YOUR NAME"
		if not is_name:
			label = "YOUR ROOM CODE" if hosting_code else (
				"THEIR ROOM CODE" if lobby_backend == Link.Backend.ROOM else "THEIR ADDRESS")
		_otext(_font, Vector2(r.get_center().x, r.position.y - 14.0), label, 11,
			Color("#7c88ad"))

		var body: String = Link.my_name if is_name else join_ip
		var tint := Color("#e6ecff")
		if not is_name and hosting_code:
			# Show the code to read out, not the field you type into.
			body = _chunk_code(Link.room_code)
			tint = Color("#ffd166")
			focused = false
		_text_fit_overlay(_font_bold, r.get_center(), body + (caret if focused else ""),
			22, r.size.x - 24.0, tint)

	var hint := "click a field to type in it · TAB switches · CTRL+V pastes"
	if Link.is_host and Link.room_code != "":
		hint = "click the code to copy it · they paste with CTRL+V"
	_otext(_font, Vector2(cx, 330.0), hint, 12, Color("#5d6a92"))

	# Backend picker. Room codes go through the lobby server; direct dials an address.
	var labels := ["ROOM CODE", "DIRECT"]
	var subs := ["works anywhere, no port forwarding", "LAN or a forwarded port"]
	var tints := [Color("#c77dff"), PLAYER_ACCENT]
	for i in 2:
		var r: Rect2 = _lobby_backend_rect(i)
		var picked: bool = lobby_backend == i
		_panel(r, Color("#1b2444") if picked else Color("#141b33"),
			Color(tints[i], 0.9 if picked else 0.25), 10.0, 2.0)
		_otext(_font_bold, Vector2(r.get_center().x, r.get_center().y - 8.0),
			labels[i], 16, tints[i])
		_otext(_font, Vector2(r.get_center().x, r.get_center().y + 14.0), subs[i], 11,
			Color("#7c88ad"))


## Once connected: who is in the room and who has readied up.
func _draw_room(cx: float) -> void:
	var names := [Link.my_name, Link.peer_name if Link.peer_name != "" else "…"]
	var readies := [Link.my_ready, Link.peer_ready]
	var tints := [PLAYER_ACCENT, AI_ACCENT]

	for i in 2:
		var r := Rect2(cx - 330.0 + i * 340.0, 232.0, 320.0, 128.0)
		var set_up: bool = readies[i]
		_panel(r, Color("#141b33"), Color(tints[i], 0.7 if set_up else 0.25), 12.0,
			3.0 if set_up else 2.0)
		_otext(_font, Vector2(r.get_center().x, r.position.y + 26.0),
			"YOU" if i == 0 else "CHALLENGER", 11, Color("#7c88ad"))
		_otext(_font_bold, Vector2(r.get_center().x, r.position.y + 60.0),
			String(names[i]).to_upper(), 28, Color("#e6ecff"))
		_otext(_font_bold, Vector2(r.get_center().x, r.position.y + 98.0),
			"READY" if set_up else "not ready", 15,
			tints[i] if set_up else Color("#5d6a92"))

	var waiting_on := ""
	if Link.my_ready and not Link.peer_ready:
		waiting_on = "waiting for %s" % String(names[1]).to_upper()
	elif not Link.my_ready:
		waiting_on = "ready up when you are"
	_otext(_font, Vector2(cx, 392.0), waiting_on, 14, Color("#8d99bd"))


## Both lobby fields go through here: names take anything printable, addresses
## only what an address can contain.
func _lobby_edit(ch: String, backspace: bool) -> void:
	if Link.connected:
		return
	if lobby_field == 0:
		var n := Link.my_name
		if backspace:
			n = n.substr(0, maxi(0, n.length() - 1))
		elif ch.length() == 1 and n.length() < 14 and ch.unicode_at(0) >= 32:
			n += ch.to_upper()
		else:
			return
		Link.set_name_and_save(n)
	else:
		if backspace:
			join_ip = join_ip.substr(0, maxi(0, join_ip.length() - 1))
		elif ch.length() == 1 and join_ip.length() < 40 and (
				ch.is_valid_int() or ch == "." or ch == ":" or ch == "-"
				or (ch.to_lower() >= "a" and ch.to_lower() <= "z")):
			join_ip += ch
		else:
			return
	Sfx.play("back" if backspace else "key", randf_range(0.92, 1.10))


## Codes arrive as one long run of characters. Grouping them is the difference
## between reading it out and losing your place halfway through.
func _chunk_code(code: String) -> String:
	# Never change the case: codes are case-sensitive, and a player reading an
	# upper-cased one off the screen would type something that does not exist.
	var out := ""
	for i in code.length():
		if i > 0 and i % 5 == 0:
			out += " "
		out += code[i]
	return out


## Overlay twin of `_text_fit`, since the lobby draws on the overlay layer.
func _text_fit_overlay(font: Font, center: Vector2, text: String, size: int,
		max_width: float, color: Color) -> void:
	if font == null or text == "":
		return
	var s := size
	while s > 9 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > max_width:
		s -= 1
	_otext(font, center, text, s, color)


func _lobby_field_rect(i: int) -> Rect2:
	var cx := get_viewport_rect().size.x * 0.5
	return Rect2(cx - 330.0 + i * 340.0, 234.0, 320.0, 52.0)


func _lobby_backend_rect(i: int) -> Rect2:
	var cx := get_viewport_rect().size.x * 0.5
	return Rect2(cx - 330.0 + i * 340.0, 368.0, 320.0, 56.0)


func _draw_rules_panel(size: Vector2) -> void:
	var r := Rect2(size.x * 0.5 - 430.0, 188.0, 860.0, 196.0)
	_panel(r, Color("#111730"), Color(PLAYER_ACCENT, 0.22), 12.0)
	var lines := [
		"Type a word, fire with SPACE or ENTER. Its LAST letters brand a block on your rival.",
		"Clear a block by typing a word that STARTS with its letters. Garbage is ONLY ever",
		"removed that way — nothing you send blocks it. Answer it while still inbound and it",
		"never lands. One word reaches one block per two letters: four AL blocks need ALIGNMENT.",
		"Block size comes only from your chain: 1, 2, 3, 5, 7, 9 words for each step up.",
		"A tenth word cashes the run in as a SALVO of single blocks and resets you to nothing.",
		"Pause or fire a non-word and the run is gone.",
		"Topping out costs one of THREE LIVES and wipes your board — it does not end the match.",
	]
	var y := 210.0
	for l: String in lines:
		_otext(_font, Vector2(size.x * 0.5, y), l, 14, Color("#aab4d4"))
		y += 26.0


func _draw_gameover(size: Vector2) -> void:
	var cx := size.x * 0.5
	_overlay.draw_rect(Rect2(-SHAKE_MARGIN, -SHAKE_MARGIN,
		size.x + SHAKE_MARGIN * 2.0, size.y + SHAKE_MARGIN * 2.0), Color(BG_TOP, 0.93), true)

	var win := winner == "YOU"
	var tint := Color("#ffd166") if win else Color("#ff6b6b")
	_otext(_font_bold, Vector2(cx, 168), "YOU WIN" if win else "YOU LOSE", 84, tint)
	var wm := _font_bold.get_string_size("YOU WIN" if win else "YOU LOSE",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 84)
	_overlay.draw_rect(Rect2(cx - wm.x * 0.5, 214, wm.x, 3), Color(tint, 0.45), true)

	# Stat tiles read far better than one long sentence of numbers.
	var stats := [
		["TIME", "%d:%02d" % [int(match_time) / 60, int(match_time) % 60]],
		["WORDS", str(player.words_played)],
		["CLEARED", str(player.blocks_cleared)],
		["BEST CHAIN", "x%d" % player.best_chain],
		["BEST COMBO", "x%d" % player.best_combo],
		["SALVOS", str(player.salvos)],
	]
	var tw := 148.0
	var total := stats.size() * tw + (stats.size() - 1) * 12.0
	for i in stats.size():
		var x := cx - total * 0.5 + i * (tw + 12.0)
		var r := Rect2(x, 262, tw, 78)
		_panel(r, Color("#141b33"), Color(tint, 0.20), 10.0)
		_otext(_font, Vector2(r.get_center().x, 286), stats[i][0], 11, Color("#7c88ad"))
		_otext(_font_bold, Vector2(r.get_center().x, 315), stats[i][1], 26, Color("#e6ecff"))

	_otext(_font, Vector2(cx, 372), "on %s" % difficulty, 14, Color("#7c88ad"))

	for b: Dictionary in _menu_buttons():
		_draw_menu_button(b)

	_otext(_font, Vector2(cx, 640), "R — rematch      1 / 2 / 3 — change difficulty      V — versus      ESC — title",
		13, Color("#4d5878"))


# ------------------------------------------------------------------ networking
#
# The connection itself lives in the `Link` autoload. This half only translates
# between its signals and the match: incoming packets become garbage on our own
# board, and our own attacks become outgoing packets.

const NET_STATE_HZ := 15.0

var net_typing := ""
var _net_state_timer := 0.0


func net_active() -> bool:
	return Link.active


func _net_setup() -> void:
	Link.match_begin.connect(_on_net_match_begin)
	Link.peer_left.connect(_on_net_peer_left)
	Link.rematch_agreed.connect(_on_net_rematch)
	Link.attack_received.connect(_on_net_attack)
	Link.salvo_received.connect(_on_net_salvo)
	Link.pressure_received.connect(_seed_pressure)
	Link.opponent_topped_out.connect(func(): _end_match(ai_side))
	Link.state_received.connect(_on_net_state)


func _on_net_match_begin() -> void:
	ai_side.label = Link.peer_name if Link.peer_name != "" else "RIVAL"
	start_match("Versus")


func _on_net_peer_left(why: String) -> void:
	if phase == Phase.PLAY or phase == Phase.COUNTDOWN:
		_log(why, Color("#ff6b6b"))
		winner = "YOU"
		phase = Phase.OVER
		Sfx.play("win")
	elif phase != Phase.LOBBY:
		phase = Phase.TITLE


## A rematch puts both players back in the room to ready up again, rather than
## silently restarting on one player's say-so.
func _on_net_rematch() -> void:
	phase = Phase.LOBBY
	_hover_action = ""


func _on_net_attack(word: String, tier: int) -> void:
	var p := Pending.new()
	p.tier = clampi(tier, 0, TIERS.size() - 1)
	p.prefix = _mint_stamp(word, STAMP_WANT, player)
	p.cells = _cells(p.tier)
	p.timer = DROP_DELAY
	player.pending.append(p)
	player.flash = 1.0


func _on_net_salvo(word: String, count: int) -> void:
	for i in mini(count, 40):
		var p := Pending.new()
		p.tier = 0
		p.prefix = _mint_stamp(word, STAMP_WANT, player)
		p.cells = 1
		p.timer = DROP_DELAY + i * 0.10
		player.pending.append(p)
	player.flash = 1.0
	Sfx.play("salvo", 1.0, -6.0)


func _on_net_state(payload: Dictionary) -> void:
	ai_side.board.mirror_blocks(payload.get("b", []))

	ai_side.pending.clear()
	for spec: Array in payload.get("p", []):
		var p := Pending.new()
		p.tier = clampi(int(spec[0]), 0, TIERS.size() - 1)
		p.prefix = String(spec[1])
		p.cells = _cells(p.tier)
		p.timer = float(spec[2])
		ai_side.pending.append(p)

	net_typing = String(payload.get("t", ""))
	ai_side.chain = int(payload.get("c", 0))
	ai_side.chain_timer = float(payload.get("ct", 0.0))
	ai_side.chain_window = maxf(0.001, float(payload.get("cw", 1.0)))
	ai_side.words_played = int(payload.get("w", 0))
	ai_side.blocks_cleared = int(payload.get("cl", 0))
	ai_side.salvo_flash = float(payload.get("sf", 0.0))
	ai_side.lives = int(payload.get("lv", LIVES))
	ai_side.respite = float(payload.get("rs", 0.0))
	ai_side.life_flash = float(payload.get("lf", 0.0))


func _push_state(delta: float) -> void:
	_net_state_timer -= delta
	if _net_state_timer > 0.0:
		return
	_net_state_timer = 1.0 / NET_STATE_HZ

	var block_specs: Array = []
	for b in player.board.blocks:
		block_specs.append([b.gx, b.gy, b.w, b.h, b.tier, b.prefix])
	var pend_specs: Array = []
	for p: Pending in player.pending:
		pend_specs.append([p.tier, p.prefix, p.timer])

	Link.send_state({
		"b": block_specs, "p": pend_specs, "t": typed,
		"c": player.chain, "ct": player.chain_timer, "cw": player.chain_window,
		"w": player.words_played, "cl": player.blocks_cleared,
		"sf": player.salvo_flash, "lv": player.lives, "rs": player.respite,
		"lf": player.life_flash,
	})


# ----------------------------------------------------------------- menu pieces

## Menu buttons are built from one description so drawing and hit-testing can
## never disagree about where they are.
func _menu_buttons() -> Array:
	var out: Array = []
	var cx := get_viewport_rect().size.x * 0.5

	if phase == Phase.TITLE:
		var names := ["Rookie", "Duelist", "Wordsmith"]
		var notes := ["learning the ropes", "a fair fight", "brutal"]
		var tints := [Color("#64dfdf"), Color("#f9c74f"), Color("#f94144")]
		var w := 300.0
		for i in names.size():
			var d: Dictionary = AiOpponent.DIFFICULTIES[names[i]]
			out.append({
				"rect": Rect2(cx + (i - 1) * (w + 18.0) - w * 0.5, 408.0, w, 146.0),
				"key": str(i + 1), "label": names[i], "sub": "%d wpm" % int(d["wpm"]),
				"note": notes[i], "rating": i + 1, "accent": tints[i],
				"action": "diff:" + names[i],
			})
		out.append({
			"rect": Rect2(cx - 234.0, 570.0, 468.0, 48.0), "key": "V",
			"label": "Versus a friend", "sub": "", "note": "", "rating": 0,
			"accent": Color("#c77dff"), "action": "versus"})
	elif phase == Phase.LOBBY:
		if Link.connected:
			out.append({
				"rect": Rect2(cx - 170.0, 436.0, 340.0, 74.0), "key": "ENTER",
				"label": "Not ready" if Link.my_ready else "Ready up",
				"sub": "", "note": "", "rating": 0,
				"accent": Color("#ffd166") if Link.my_ready else PLAYER_ACCENT,
				"action": "ready"})
			out.append({
				"rect": Rect2(cx - 90.0, 526.0, 180.0, 44.0), "key": "ESC",
				"label": "Leave", "sub": "", "note": "", "rating": 0,
				"accent": Color("#8d99bd"), "action": "leave"})
		else:
			out.append({
				"rect": Rect2(cx - 330.0, 448.0, 320.0, 66.0), "key": "H",
				"label": "Host", "sub": "", "note": "", "rating": 0,
				"accent": PLAYER_ACCENT, "action": "host"})
			out.append({
				"rect": Rect2(cx + 10.0, 448.0, 320.0, 66.0), "key": "ENTER",
				"label": "Join", "sub": "", "note": "", "rating": 0,
				"accent": Color("#c77dff"), "action": "join"})
			out.append({
				"rect": Rect2(cx - 90.0, 530.0, 180.0, 44.0), "key": "ESC",
				"label": "Back", "sub": "", "note": "", "rating": 0,
				"accent": Color("#8d99bd"), "action": "title"})
	elif phase == Phase.OVER:
		var w := 264.0
		out.append({
			"rect": Rect2(cx - w - 10.0, 410.0, w, 96.0), "key": "R",
			"label": "Rematch", "sub": difficulty, "note": "", "rating": 0,
			"accent": PLAYER_ACCENT, "action": "rematch"})
		out.append({
			"rect": Rect2(cx + 10.0, 410.0, w, 96.0), "key": "ESC",
			"label": "Title", "sub": "pick a new opponent", "note": "", "rating": 0,
			"accent": Color("#8d99bd"), "action": "title"})
	return out


func _draw_menu_button(b: Dictionary) -> void:
	var r: Rect2 = b["rect"]
	var accent: Color = b["accent"]
	var hot: bool = _hover_action == String(b["action"])
	if hot:
		# A small lift is enough to say "this one".
		r = Rect2(r.position - Vector2(0, 4), r.size)

	_panel(r, Color("#1b2444") if hot else Color("#141b33"),
		Color(accent, 0.9 if hot else 0.26), 12.0, 3.0 if hot else 2.0)

	var key: String = b["key"]
	var badge := Rect2(r.position.x + 14.0, r.position.y + 14.0,
		18.0 + 9.0 * key.length(), 22.0)
	_panel(badge, Color(accent, 0.35 if hot else 0.18), Color(accent, 0.55), 6.0, 1.0)
	_otext(_font_bold, badge.get_center(), key, 12, accent)

	var cx := r.get_center().x
	# Short buttons have no room for stacked lines. Centre the label in what is
	# left beside the key badge, or the two collide.
	if r.size.y < 70.0:
		_otext(_font_bold, Vector2((badge.end.x + r.end.x) * 0.5, r.get_center().y),
			String(b["label"]).to_upper(), 20, Color.WHITE if hot else Color("#e6ecff"))
		return

	_otext(_font_bold, Vector2(cx, r.position.y + 60.0), String(b["label"]).to_upper(), 26,
		Color.WHITE if hot else Color("#e6ecff"))
	_otext(_font, Vector2(cx, r.position.y + 86.0), b["sub"], 14, accent)
	if String(b["note"]) != "":
		_otext(_font, Vector2(cx, r.position.y + 108.0), b["note"], 12, Color("#7c88ad"))

	var rating: int = b["rating"]
	if rating > 0:
		for k in 3:
			_overlay.draw_rect(Rect2(cx - 23.0 + k * 16.0, r.position.y + 128.0, 10.0, 5.0),
				accent if k < rating else Color("#2a3355"), true)


func _panel(r: Rect2, bg: Color, border: Color, radius: float, width: float = 2.0) -> void:
	_ui_sb.bg_color = bg
	_ui_sb.set_corner_radius_all(int(radius))
	_ui_sb.set_border_width_all(int(width))
	_ui_sb.border_color = border
	_ui_sb.shadow_size = 7
	_ui_sb.shadow_color = Color(0, 0, 0, 0.35)
	_ui_sb.shadow_offset = Vector2(0, 3)
	_overlay.draw_style_box(_ui_sb, r)


## A block drawn the way the playfield draws them, for use inside the menus.
func _mini_block(center: Vector2, size: Vector2, tier: int, label: String) -> void:
	var col: Color = WWBoard.TIER_COLORS[tier]
	_ui_sb.bg_color = col
	# Scale the rounding with the tile, or a small one reads as a pill.
	_ui_sb.set_corner_radius_all(int(clampf(minf(size.x, size.y) * 0.18, 2.0, 7.0)))
	_ui_sb.set_border_width_all(2)
	_ui_sb.border_color = col.lightened(0.35)
	_ui_sb.shadow_size = 5
	_ui_sb.shadow_color = Color(0, 0, 0, 0.4)
	_ui_sb.shadow_offset = Vector2(0, 2)
	_overlay.draw_style_box(_ui_sb, Rect2(center - size * 0.5, size))
	if label != "":
		_otext(_font_bold, center, label, 15, Color("#0b1020"))


## One word with the significant half picked out, which is the entire mechanic.
func _draw_split_word(cx: float, y: float, head: String, tail: String, size: int,
		lit_head: bool = false) -> void:
	var hw := _font_bold.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var tw := _font_bold.get_string_size(tail, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var hh := _font_bold.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, size).y
	var start := cx - (hw + tw) * 0.5
	var base := y - hh * 0.5 + _font_bold.get_ascent(size)
	var dim := Color("#6c7899")
	var lit := Color("#ffd166")
	_overlay.draw_string(_font_bold, Vector2(start, base), head,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, lit if lit_head else dim)
	_overlay.draw_string(_font_bold, Vector2(start + hw, base), tail,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, dim if lit_head else lit)


func _draw_arrow(cx: float, y: float, length: float, color: Color) -> void:
	_overlay.draw_line(Vector2(cx, y), Vector2(cx, y + length - 7.0), color, 2.0)
	var tip := Vector2(cx, y + length)
	_overlay.draw_colored_polygon(PackedVector2Array([
		tip, tip + Vector2(-5.5, -8.0), tip + Vector2(5.5, -8.0)]), color)


# ----------------------------------------------------------- animated backdrop

class Decor extends RefCounted:
	var pos := Vector2.ZERO
	var size := Vector2.ONE
	var tier := 0
	var speed := 30.0
	var rot := 0.0
	var spin := 0.0


func _seed_decor() -> void:
	decor.clear()
	var size := get_viewport_rect().size
	for i in 18:
		var d := Decor.new()
		d.size = Vector2(randi_range(1, 3), randi_range(1, 3)) * 26.0
		d.pos = Vector2(randf_range(0.0, size.x), randf_range(-140.0, size.y))
		d.tier = randi_range(0, 5)
		d.speed = randf_range(12.0, 44.0)
		d.rot = randf_range(-0.35, 0.35)
		d.spin = randf_range(-0.22, 0.22)
		decor.append(d)


func _step_decor(delta: float) -> void:
	var size := get_viewport_rect().size
	for d: Decor in decor:
		d.pos.y += d.speed * delta
		d.rot += d.spin * delta
		if d.pos.y > size.y + 90.0:
			d.pos.y = -90.0
			d.pos.x = randf_range(0.0, size.x)
			d.tier = randi_range(0, 5)


func _draw_decor() -> void:
	for d: Decor in decor:
		var col: Color = WWBoard.TIER_COLORS[d.tier]
		_overlay.draw_set_transform(d.pos, d.rot, Vector2.ONE)
		_overlay.draw_rect(Rect2(-d.size * 0.5, d.size), Color(col, 0.07), true)
		_overlay.draw_rect(Rect2(-d.size * 0.5, d.size), Color(col, 0.15), false, 1.5)
		_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ----------------------------------------------------------------- mouse input

func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.PLAY:
		return
	if event is InputEventMouseMotion:
		var was := _hover_action
		_hover_action = _action_at(get_viewport().get_mouse_position())
		if _hover_action != "" and _hover_action != was:
			Sfx.play("key", 1.3, -6.0)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var act := _action_at(get_viewport().get_mouse_position())
			if act != "":
				_activate(act)


func _action_at(p: Vector2) -> String:
	for b: Dictionary in _menu_buttons():
		if (b["rect"] as Rect2).has_point(p):
			return String(b["action"])
	# The lobby's fields and backend tiles are clickable too.
	if phase == Phase.LOBBY and not Link.connected:
		for i in 2:
			if _lobby_field_rect(i).has_point(p):
				return "field:%d" % i
			if _lobby_backend_rect(i).has_point(p):
				return "backend:%d" % i
	return ""


func _activate(action: String) -> void:
	if action.begins_with("diff:"):
		Link.leave()
		start_match(action.substr(5))
	elif action == "rematch":
		# Still connected? Both players go back to the room and ready up again.
		if Link.connected:
			Link.request_rematch()
		elif net_active() or difficulty == "Versus":
			_activate("versus")
		else:
			start_match(difficulty)
	elif action == "versus":
		Link.leave()
		Link.status = ""
		phase = Phase.LOBBY
		_hover_action = ""
		Sfx.play("back", 1.2)
	elif action == "host":
		Link.host(lobby_backend)
		Sfx.play("count")
	elif action == "join":
		Link.join(lobby_backend, join_ip)
		Sfx.play("count")
	elif action == "ready":
		Link.set_ready(not Link.my_ready)
		Sfx.play("count", 1.2 if Link.my_ready else 0.9)
	elif action == "leave":
		Link.leave()
		Link.status = ""
		_hover_action = ""
		Sfx.play("back")
	elif action.begins_with("backend:"):
		lobby_backend = int(action.substr(8))
		Sfx.play("key", 1.2)
	elif action.begins_with("field:"):
		var which := int(action.substr(6))
		# While hosting, that field is the code to read out — clicking copies it.
		if which == 1 and Link.is_host and Link.room_code != "":
			DisplayServer.clipboard_set(Link.room_code)
			Link.status = "code copied to your clipboard"
			Sfx.play("count", 1.3)
		else:
			lobby_field = which
	elif action == "title":
		Link.leave()
		Link.status = ""
		phase = Phase.TITLE
		_hover_action = ""
		Sfx.play("back")


# ---------------------------------------------------------------- text helpers

func _text_centered(font: Font, center: Vector2, text: String, size: int, color: Color) -> void:
	if font == null or text == "":
		return
	var m := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	draw_string(font, Vector2(center.x - m.x * 0.5, center.y - m.y * 0.5 + font.get_ascent(size)),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Same, but shrinks the type until the line sits inside `max_width`. Words like
## MISUNDERSTANDING are exactly what this game rewards, so they must still fit.
func _text_fit(font: Font, center: Vector2, text: String, size: int, max_width: float,
		color: Color, min_size: int = 11) -> void:
	if font == null or text == "":
		return
	var s := size
	while s > min_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > max_width:
		s -= 1
	_text_centered(font, center, text, s, color)


func _otext(font: Font, center: Vector2, text: String, size: int, color: Color) -> void:
	if font == null or text == "":
		return
	var m := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	_overlay.draw_string(font,
		Vector2(center.x - m.x * 0.5, center.y - m.y * 0.5 + font.get_ascent(size)),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
