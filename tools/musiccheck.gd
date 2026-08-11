extends SceneTree
func _initialize() -> void: _run()
func _run() -> void:
	var m = load("res://scripts/music.gd").new()
	root.add_child(m)
	await process_frame
	print("--- tracks ---")
	for key in m.TRACKS:
		var s = m._stream(key)
		if s == null:
			print("  %-9s MISSING" % key); continue
		var loops: bool = s.loop if s is AudioStreamMP3 else false
		print("  %-9s %6.1fs  loop=%s  trim=%+.1f dB" % [
			key, s.get_length(), loops, float(m.TRIM.get(key, 0.0))])
	print("--- playback + crossfade ---")
	m.play("menu")
	await process_frame
	print("  menu started, live player %d" % m._live)
	m.play("clutch")
	for i in 3: await process_frame
	var a: float = m._players[0].volume_db
	var b: float = m._players[1].volume_db
	print("  mid-crossfade: %.1f dB / %.1f dB (both audible = crossfading)" % [a, b])
	m.muted = true
	await process_frame
	print("  muted -> live player at %.0f dB" % m._players[m._live].volume_db)
	quit()
