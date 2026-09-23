extends SceneTree
## The keyboard learning a player's aim, and the room-code number row.
##
##   godot --headless --path . --script tools/aimtest.gd
##
## What "learning your aim" in game.gd promises, checked with synthetic taps
## rather than thumbs: a new player gets exactly the plain geometry; a player
## whose thumb lands consistently to one side has that corrected once enough
## accepted words have shown it; the correction is capped so no key becomes
## unreachable; only accepted words teach it; and the two thumbs learn apart.
##
## The profile is redirected before anything can save — `set_pref` writes the
## file, and the learnt offset is saved through it.

var fails := 0
var game: Node
var stage: SubViewport
var profile: Node
const SAVE := "user://profile-aim-test.cfg"


func _expect(what: String, ok: bool) -> void:
	print("  %-58s %s" % [what, "ok" if ok else "FAILED"])
	if not ok:
		fails += 1


func _key(id: String) -> Rect2:
	for k: Dictionary in game._keyboard():
		if k["id"] == id:
			return k["rect"]
	return Rect2()


## A touch aimed at `id`, landing `frac` of a key width to the right of its
## centre (the vertical touch lift already undone, so only the sideways part is
## being tested).
func _touch(id: String, frac: float) -> Vector2:
	var r := _key(id)
	var lift: float = game._touch_lift(stage.size)
	return r.get_center() + Vector2(frac * r.size.x, lift)


func _type_word(word: String, frac: float) -> void:
	game.typed = ""
	game._word_taps = []
	for ch in word:
		var p := _touch(ch, frac)
		game._note_tap(ch, p)
		game.typed += ch


func _init() -> void:
	await process_frame
	profile = root.get_node("Profile")
	profile.save_path = SAVE
	profile.prefs.erase("aim")
	game = load("res://scenes/main.tscn").instantiate()
	stage = SubViewport.new()
	stage.size = Vector2i(720, 1440)
	root.add_child(stage)
	stage.add_child(game)
	await process_frame
	await process_frame
	game.portrait = true
	game.phase = game.Phase.PLAY
	game._touch_input = true
	game._thumb_aim = []
	game.typed = ""

	print("--- a new player gets the plain keyboard ---")
	_expect("a tap 0.65 right of J's centre is K", game._key_at(_touch("j", 0.65)) == "k")
	_expect("a tap on J's centre is J", game._key_at(_touch("j", 0.0)) == "j")

	print("--- a thumb that lands right is learnt ---")
	# Right-half words, typed with every tap landing 0.65 of a key right of the
	# key it meant — past the boundary, into the next key over.
	for i in 50:
		_type_word("hook", 0.65)
		game._aim_learn("hook", game._word_taps)
	_expect("that same off-centre tap now reads as J", game._key_at(_touch("j", 0.65)) == "j")
	_expect("a tap on K's centre is still K", game._key_at(_touch("k", 0.0)) == "k")
	var off: Vector2 = game._aim_offset(_touch("j", 0.0), _key("j").size)
	_expect("the correction is capped at a quarter key (%.2f)" % (off.x / _key("j").size.x),
		off.x / _key("j").size.x <= game.AIM_CAP + 0.001)

	print("--- the left thumb is its own ---")
	_expect("a tap 0.65 right of A's centre is still S", game._key_at(_touch("a", 0.65)) == "s")

	print("--- only a word that matches its taps teaches ---")
	var before: int = int(game._thumb_aim[0][2])
	_type_word("sad", -0.65)
	game._aim_learn("sat", game._word_taps)
	_expect("taps that spelt something else are thrown away", int(game._thumb_aim[0][2]) == before)
	_type_word("sad", -0.65)
	game._word_taps.pop_back()
	game._aim_learn("sad", game._word_taps)
	_expect("and so are too few taps", int(game._thumb_aim[0][2]) == before)

	print("--- a mouse is not corrected ---")
	game._touch_input = false
	_expect("with a mouse, 0.65 right of J is K again", game._key_at(_touch("j", 0.65)) == "k")

	print("--- the room-code keyboard ---")
	game.phase = game.Phase.LOBBY
	game._code_entry = true
	var ids: Array = []
	for k: Dictionary in game._keyboard():
		ids.append(k["id"])
	_expect("it has 2 to 9", ids.has("2") and ids.has("9"))
	_expect("and no 0 or 1", not ids.has("0") and not ids.has("1"))
	_expect("the letters have not moved", _key("q").position.y > _key("2").position.y)
	game._code_entry = false
	var plain: Array = []
	for k: Dictionary in game._keyboard():
		plain.append(k["id"])
	_expect("and it goes away after", not plain.has("2"))

	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	print("--- %s ---" % ("aim holds up" if fails == 0 else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)
