extends SceneTree
## A second player with no screen, for testing cross-play against a phone or
## the emulator from this machine. Uses MultiplayerManager exactly as the game
## does, so what it proves is the real path.
##
##   godot --headless --path . -s tools/eosprobe.gd -- quick
##   godot --headless --path . -s tools/eosprobe.gd -- host
##   godot --headless --path . -s tools/eosprobe.gd -- join K7QMX
##
## Once connected it answers every event with an echo and prints what arrives,
## then leaves after LINGER seconds.

const LINGER := 40.0
var mm: Node
var _t := 0.0
var _started := false


func _initialize() -> void:
	# The autoloads are added after this returns.
	await process_frame
	mm = root.get_node("/root/MultiplayerManager")
	var args := OS.get_cmdline_user_args()
	var how := args[0] if args.size() > 0 else "quick"
	mm.state_changed.connect(func(t): print("[probe] state: %s — %s" % [mm.State.keys()[mm.state], t]))
	mm.match_started.connect(_on_started)
	mm.match_ended.connect(_on_ended)
	mm.data_received.connect(func(p): print("[probe] got: ", JSON.stringify(p)))
	mm.invite_ready.connect(func(c): print("[probe] ROOM CODE ", c, "  ", mm.invite_link(c)))
	print("[probe] transport=%s mode=%s" % [mm.Transport.keys()[mm.transport], how])
	match how:
		"host": mm.host_invite()
		"join": mm.join_code(args[1])
		_: mm.find_match()


## Stays up a while after the match, because a real game does: a crash that
## only shows once the connection is torn down has to happen with us watching.
func _on_ended(reason: String) -> void:
	print("[probe] ended: ", reason)
	await create_timer(8.0).timeout
	print("[probe] still alive 8s after the match ended")
	quit()


func _on_started() -> void:
	_started = true
	print("[probe] MATCH STARTED — opponent '%s', first=%s" % [mm.peer_name, mm.is_first()])
	mm.send_event("probe", {"hello": "from the PC"})


func _process(delta: float) -> bool:
	_t += delta
	if mm == null:
		return false
	if _started and _t > LINGER:
		print("[probe] leaving")
		_started = false
		mm.leave_match()
		_on_ended("left")
	return _t > 300.0
