extends SceneTree
## Verifies the synthesised sound bank, since you cannot eyeball a waveform in a
## code review. Dumps every sound to user://sfx as a .wav — so they can actually
## be listened to, or measured with any audio tool — and checks that playback
## reaches the audio server and that mute really silences it.
##
##   godot --headless --script res://tools/audiocheck.gd

func _initialize() -> void:
	_run()


func _run() -> void:
	var sfx = load("res://scripts/audio.gd").new()
	root.add_child(sfx)
	await process_frame

	var out := "user://sfx"
	DirAccess.make_dir_recursive_absolute(out)

	var names: Array = sfx._bank.keys()
	names.sort()
	print("--- bank ---")
	for n in names:
		var stream: AudioStreamWAV = sfx._bank[n]
		var samples := stream.data.size() / 2
		var peak := 0
		for i in samples:
			peak = maxi(peak, absi(stream.data.decode_s16(i * 2)))
		var err := stream.save_to_wav("%s/%s.wav" % [out, n])
		var flag := "ok"
		if peak < 650:
			flag = "SILENT?"
		elif peak >= 32700:
			flag = "CLIPPING?"
		print("  %-8s %6d samples  %5.3fs  peak %.3f  save=%d  %s" % [
			n, samples, float(samples) / stream.mix_rate, peak / 32767.0, err, flag])

	print("--- playback ---")
	print("  mix rate %.0f  output %s" % [AudioServer.get_mix_rate(), AudioServer.get_output_device()])
	sfx.play("fire")
	await process_frame
	var live := 0
	for p in sfx._players:
		if p.playing:
			live += 1
	print("  play() -> %d voice(s) active  %s" % [live, "ok" if live > 0 else "NOT PLAYING"])

	sfx.toggle_mute()
	sfx.play("win")
	await process_frame
	var muted_live := 0
	for p in sfx._players:
		if p.playing:
			muted_live += 1
	print("  muted  -> %d voice(s) active  %s" % [
		muted_live, "ok" if muted_live == 0 else "MUTE FAILED"])

	print("  wavs written to ", ProjectSettings.globalize_path(out))
	quit()
