class_name Art
extends RefCounted
## Loads the generated SVG art (assets/art) as crisp, mipmapped textures, and builds InkBox styles from the
## 9-slice margins in slices.json.

const DIR: String = "res://assets/art/"

static var _tex: Dictionary = {}
static var _slices: Dictionary = {}
static var _layout: Dictionary = {}

static func tex(name: String, scale: float = 2.0) -> Texture2D:
	## the SVG rasterized at `scale` texels per SVG unit
	var key: String = "%s@%.2f" % [name, scale]
	if _tex.has(key):
		return _tex[key]
	var path: String = DIR + name + ".svg"
	var t: Texture2D = null
	if FileAccess.file_exists(path):
		var img: Image = Image.new()
		if img.load_svg_from_buffer(FileAccess.get_file_as_bytes(path), scale) == OK:
			img.generate_mipmaps()
			t = ImageTexture.create_from_image(img)
	if t == null:
		push_warning("Art: missing %s" % name)
		var ph: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		ph.fill(Color(1, 0, 1, 0.5))
		t = ImageTexture.create_from_image(ph)
	_tex[key] = t
	return t

static func sized(name: String, px: float) -> Texture2D:
	## a texture rasterized so that it is about 2x `px` wide (crisp when drawn at px)
	var base: Texture2D = tex(name, 1.0)
	var s: float = clampf(2.0 * px / maxf(1.0, base.get_width()), 0.25, 8.0)
	s = snappedf(s, 0.25)
	return tex(name, s)

static func slices() -> Dictionary:
	if _slices.is_empty():
		var f: String = DIR + "slices.json"
		if FileAccess.file_exists(f):
			_slices = JSON.parse_string(FileAccess.get_file_as_string(f))
	return _slices

static func layout(key: String) -> Variant:
	if _layout.is_empty():
		var f: String = DIR + "layout.json"
		if FileAccess.file_exists(f):
			_layout = JSON.parse_string(FileAccess.get_file_as_string(f))
	return _layout.get(key)

static func box(name: String, tint: Color = Color.WHITE, extra_pad: Array = []) -> InkBox:
	var sl: Dictionary = slices().get(name, {"m": [20, 20, 20, 20], "c": [12, 12, 12, 12]})
	var b: InkBox = InkBox.new()
	b.texture = tex(name, 2.0)
	b.tex_scale = 2.0
	b.margins = sl.m
	b.tint = tint
	var c: Array = sl.c
	for i in 4:
		var e: float = float(extra_pad[i]) if i < extra_pad.size() else 0.0
		b.set_content_margin(i as Side, float(c[i]) + e)
	return b
