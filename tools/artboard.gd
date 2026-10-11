extends SceneTree
# Renders every SVG in assets/art into one contact sheet PNG (headless) for quick review.
func _init() -> void:
	var dir: String = OS.get_environment("ART_DIR") if OS.get_environment("ART_DIR") != "" else "res://assets/art/"
	var files: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".svg"):
			files.append(f)
	files.sort()
	var cell: int = int(OS.get_environment("CELL")) if OS.get_environment("CELL") != "" else 200
	var cols: int = int(OS.get_environment("COLS")) if OS.get_environment("COLS") != "" else 7
	var rows: int = int(ceil(float(files.size()) / cols))
	var sheet: Image = Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#f2e2c0"))
	var i: int = 0
	for f in files:
		var buf: PackedByteArray = FileAccess.get_file_as_bytes(dir + f)
		var img: Image = Image.new()
		var is_icon: bool = f.begins_with("icon_")
		img.load_svg_from_buffer(buf, float(OS.get_environment("SCALE")) if OS.get_environment("SCALE") != "" else (2.5 if is_icon else 0.7))
		img.convert(Image.FORMAT_RGBA8)
		var x: int = (i % cols) * cell + (cell - img.get_width()) / 2
		var y: int = (i / cols) * cell + (cell - img.get_height()) / 2
		sheet.blend_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(x, y))
		i += 1
	sheet.save_png(OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "/tmp/artboard.png")
	print("artboard ", files.size(), " files")
	quit(0)
