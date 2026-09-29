extends SceneTree
## A still of every 3D board, for the shop, the wardrobe and the title card.
##
##     godot --script tools/board3d_previews.gd
##
## Writes boards/3d/previews/<scene>.jpg, 900x1600. The previews are pictures
## rather than live scenes because the shop can show every board at once, and
## nine 3D scenes rendering behind a scrolling list is nine too many. Each is
## taken at a moment in its loop picked for having something in it (the bus
## at the stop, the comet in the sky), and they are regenerated whenever a
## scene changes: run this after `tools/blender/*.py`, then import.
##
## **Do not pass `--headless`**: the dummy renderer saves blank images.

const SIZE := Vector2i(900, 1600)
const OUT := "res://boards/3d/previews"

## The moment in each loop worth a still, in seconds.
const MOMENT := {
	"sky_islands": 6.0, "volcano": 3.0, "city": 12.5, "forest": 5.0, "aurora": 5.0,
	"desert": 7.5, "nexus": 5.0, "ocean": 5.0, "space": 8.0,
}


func _init() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var board3d: GDScript = load("res://scripts/board3d.gd")
	for scene: String in MOMENT:
		var vp := SubViewport.new()
		vp.size = SIZE
		vp.own_world_3d = true
		vp.msaa_3d = Viewport.MSAA_4X
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		get_root().add_child(vp)
		var b: Node3D = board3d.new("res://boards/3d/%s.glb" % scene)
		vp.add_child(b)
		for i in 4:
			await process_frame
		b.seek(float(MOMENT[scene]))
		for i in 6:
			await process_frame
		var path := "%s/%s.jpg" % [OUT, scene]
		vp.get_texture().get_image().save_jpg(ProjectSettings.globalize_path(path), 0.9)
		print("[previews] ", path)
		vp.queue_free()
		await process_frame
	quit()
