extends SceneTree
func _init() -> void:
	await process_frame
	var p = Engine.get_main_loop().root.get_node("Profile")
	print("PROBE path=%s" % ProjectSettings.globalize_path(p.save_path))
	print("PROBE loaded matches=%d xp=%d level=%d" % [p.matches, p.xp_total(), p.level()])
	if p.matches == 0:
		p.record_match({"won": true, "words": 25, "chars": 180, "wpm": 55.0,
			"chain": 6, "combo": 3, "salvos": 1, "longest": "shipments",
			"powers": {"COMBO": 2}})
		print("PROBE wrote matches=%d xp=%d" % [p.matches, p.xp_total()])
	quit()
