extends SceneTree
## Every share card, rendered to PNG so it can be looked at.
##
##     godot --script tools/cardshots.gd
##
## Output lands in build/shots/share/, one 1080x1920 file per mode. The card is
## the only picture this game sends to people who do not play it, and it was
## being shipped unlooked-at — `sharetest.gd` checks that the headline is not
## empty, which is not the same as checking that the card is worth sending.
##
## **Do not pass `--headless`.** A card is a SubViewport render and the dummy
## renderer saves it blank, exactly as it does for `tools/shots.gd`.
##
## The state below is posed, not played. What the card draws is the handful of
## numbers `_share_card_data` reads, so setting those directly renders the same
## picture a real match would, in a second rather than a minute.

const OUT_DIR := "res://build/shots/share"

var game: Node
var stage: SubViewport
var _profile: Node


func _init() -> void:
	await process_frame
	_profile = get_root().get_node("Profile")

	stage = SubViewport.new()
	stage.size = Vector2i(720, 1440)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(stage)
	game = load("res://scenes/main.tscn").instantiate()
	stage.add_child(game)
	await process_frame
	await process_frame

	_pose_profile()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	await _card("survival", func():
		game.start_match("Duelist", 0, [], game.Mode.SURVIVAL)
		game.match_time = 252.0
		game.player.score = 14320
		_word("ENTRANCE", 2440))

	# The same run, but the one that took the record — the gold badge and the
	# brighter bloom behind the number only ever appear on this branch.
	await _card("survival-record", func():
		game.start_match("Duelist", 0, [], game.Mode.SURVIVAL)
		game.match_time = 421.0
		game.player.score = 22910
		game.survival_took = {"time": true, "score": true}
		_word("QUARTERLY", 3180))

	# A run played for a challenge. The badge is the whole point: it outranks
	# the record line the mode would otherwise have put there.
	await _card("survival-challenge", func():
		game.start_match("Duelist", 0, [], game.Mode.SURVIVAL)
		game.match_time = 305.0
		game.player.score = 18740
		game.challenge_run = {
			"board": "com.damonj.wordwars.survival", "score": 14320,
			"formatted": "14,320", "from": "Anna", "issued": 1750000000.0}
		_word("SCRAMBLE", 2870))

	await _card("daily", func():
		game.start_match("Duelist", 0, [], game.Mode.DAILY)
		game.player.score = 8150
		_word("BRIGHTEN", 1920))

	await _card("solo-win", func():
		game.start_match("Berserker", 1, [], game.Mode.NORMAL)
		game.player.score = 12400
		_rival(9860)
		game.winner = "YOU"
		_word("STAMPEDE", 2610))

	await _card("solo-loss", func():
		game.start_match("Berserker", 1, [], game.Mode.NORMAL)
		game.player.score = 6200
		_rival(11480)
		game.winner = "THEM"
		_word("MARGIN", 980))

	# The longest word the tiles ever have to swallow, on the card with the most
	# on it. If the letters fit here they fit anywhere.
	await _card("solo-longword", func():
		game.start_match("Magpie", 1, [], game.Mode.NORMAL)
		game.player.score = 131017
		_rival(9860)
		game.winner = "YOU"
		game.player.lives = game.LIVES
		_word("ENTERTAINMENT", 5120))

	# A versus loss to somebody with a long display name, which is the widest the
	# dare can ever get: "SOMEBODY TAKE <name> DOWN" is the one line on the card
	# built from something a stranger typed rather than something we wrote.
	await _card("versus-longname", func():
		game.start_match("Versus", 1, [], game.Mode.NORMAL)
		game.difficulty = "Versus"
		game.player.score = 7410
		_rival(19260)
		for s in game.sides:
			if s != game.player and s.in_match:
				s.label = "xX_stampcollector_Xx"
		game.winner = "THEM"
		_word("BLUSTERING", 2180))

	quit(0)


## Whoever is in the other seat, given a score worth comparing against. Their
## lives come down too, or every posed win reads as flawless.
func _rival(score: int) -> void:
	game.player.lives = game.LIVES - 1
	game.player.words_played = 34
	for s in game.sides:
		if s != game.player and s.in_match:
			s.score = score


func _word(word: String, worth: int) -> void:
	game.player.best_word = word
	game.player.best_word_score = worth


func _card(name: String, pose: Callable) -> void:
	pose.call()
	await process_frame
	var card_script := load("res://scripts/share_card.gd")
	var painter: Node = card_script.new(game._font, game._font_bold, game._font_title)
	get_root().add_child(painter)
	var path := "%s/%s.png" % [OUT_DIR, name]
	var ok: bool = await painter.render(game._share_card_data(), path)
	painter.queue_free()
	print("[card] %-10s %s" % [name, path if ok else "FAILED"])
	print("[card]   text: %s" % game._share_line())


## A player with a history, so the rows that read off the profile have something
## in them. A card whose "best run" is 0:00 is a card nobody would ever send.
func _pose_profile() -> void:
	_profile.survival_best_time = 402.0
	_profile.survival_runs = 37
	_profile.best_score = 131017
	_profile.daily_best = 34870
	_profile.daily_best_streak = 19
