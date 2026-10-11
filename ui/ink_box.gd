class_name InkBox
extends StyleBox
## A 9-sliced hand-inked frame. The texture is rasterized at `tex_scale` texels per unit; `margins` are in units.

var texture: Texture2D
var tex_scale: float = 2.0
var margins: Array = [20, 20, 20, 20]  # left, top, right, bottom
var tint: Color = Color.WHITE

func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if texture == null:
		return
	var ts: Vector2 = texture.get_size()
	var l: float = float(margins[0])
	var t: float = float(margins[1])
	var r: float = float(margins[2])
	var b: float = float(margins[3])
	# shrink the corners if the rect is smaller than them
	var fx: float = minf(1.0, rect.size.x / maxf(1.0, l + r))
	var fy: float = minf(1.0, rect.size.y / maxf(1.0, t + b))
	var k: float = tex_scale
	var sx: Array = [0.0, l * k, ts.x - r * k, ts.x]
	var sy: Array = [0.0, t * k, ts.y - b * k, ts.y]
	var dx: Array = [rect.position.x, rect.position.x + l * fx, rect.end.x - r * fx, rect.end.x]
	var dy: Array = [rect.position.y, rect.position.y + t * fy, rect.end.y - b * fy, rect.end.y]
	var rid: RID = texture.get_rid()
	for i in 3:
		for j in 3:
			var dst: Rect2 = Rect2(dx[i], dy[j], dx[i + 1] - dx[i], dy[j + 1] - dy[j])
			if dst.size.x <= 0.0 or dst.size.y <= 0.0:
				continue
			var src: Rect2 = Rect2(sx[i], sy[j], sx[i + 1] - sx[i], sy[j + 1] - sy[j])
			RenderingServer.canvas_item_add_texture_rect_region(to_canvas_item, dst, rid, src, tint)
