extends SceneTree
## Renders a Control-based script to a PNG for art review (needs a window, not --headless).
## godot --path . --resolution 1280x720 --script tools/shot.gd -- --ui=res://tools/fontboard.gd --out=/tmp/x.png

func _init() -> void:
	var args: Dictionary = {}
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var scr: GDScript = load(str(args.get("ui", "res://tools/fontboard.gd")))
	var node: Node = scr.new()
	if node is Control:
		(node as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(node)
	for i in int(args.get("frames", 12)):
		await process_frame
	var img: Image = root.get_texture().get_image()
	img.save_png(str(args.get("out", "/tmp/shot.png")))
	print("saved ", args.get("out", "/tmp/shot.png"), " ", img.get_size())
	quit(0)
