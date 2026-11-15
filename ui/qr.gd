class_name Qr
extends RefCounted
## A QR code maker, small enough to live in the game: text in, a square of dark/light modules out.
## Byte mode, error correction level M (survives a scuffed TV screen), versions 1-15 (up to ~410 bytes).
## Follows the standard (ISO/IEC 18004) the way Project Nayuki's reference library lays it out.
## Checked against macOS's own QR reader in tests/qr_decode.swift (see scripts/run_tests.sh).

const ECC_PER_BLOCK: Array = [-1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24]   # level M
const NUM_BLOCKS: Array = [-1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10]                 # level M
const FORMAT_BITS_M: int = 0
const MAX_VERSION: int = 15

var size: int = 0
var version: int = 0
var modules: Array = []        # [y][x] -> bool (true = dark)
var _fn: Array = []            # [y][x] -> bool: part of a fixed pattern, never data

static func make(text: String) -> Qr:
	## {} -> null when the text is too long
	var q: Qr = Qr.new()
	return q if q._encode(text.to_utf8_buffer()) else null

# ---------------------------------------------------------------- building

static func _raw_modules(ver: int) -> int:
	var r: int = (16 * ver + 128) * ver + 64
	if ver >= 2:
		var na: int = ver / 7 + 2
		r -= (25 * na - 10) * na - 55
		if ver >= 7:
			r -= 36
	return r

static func _data_codewords(ver: int) -> int:
	return _raw_modules(ver) / 8 - int(ECC_PER_BLOCK[ver]) * int(NUM_BLOCKS[ver])

func _encode(data: PackedByteArray) -> bool:
	# the smallest version that holds it
	var ver: int = 0
	for v in range(1, MAX_VERSION + 1):
		var cc_bits: int = 8 if v <= 9 else 16
		if 4 + cc_bits + data.size() * 8 <= _data_codewords(v) * 8:
			ver = v
			break
	if ver == 0:
		return false
	version = ver
	size = ver * 4 + 17
	# the bit stream: mode, count, bytes, terminator, padding
	var bits: Array = []
	_append(bits, 0x4, 4)
	_append(bits, data.size(), 8 if ver <= 9 else 16)
	for b in data:
		_append(bits, b, 8)
	var cap: int = _data_codewords(ver) * 8
	_append(bits, 0, mini(4, cap - bits.size()))
	_append(bits, 0, (8 - bits.size() % 8) % 8)
	var pad: int = 0xEC
	while bits.size() < cap:
		_append(bits, pad, 8)
		pad = 0x11 if pad == 0xEC else 0xEC
	var words: PackedByteArray = PackedByteArray()
	words.resize(bits.size() / 8)
	for i in bits.size():
		words[i >> 3] = words[i >> 3] | (int(bits[i]) << (7 - (i & 7)))
	var all: PackedByteArray = _add_ecc(words)
	# the picture
	modules = []
	_fn = []
	for y in size:
		var r: Array = []
		var f: Array = []
		r.resize(size)
		f.resize(size)
		r.fill(false)
		f.fill(false)
		modules.append(r)
		_fn.append(f)
	_draw_patterns()
	_draw_codewords(all)
	# the mask with the lowest penalty
	var best: int = 0
	var best_score: int = 1 << 30
	for m in 8:
		_apply_mask(m)
		_draw_format(m)
		var sc: int = _penalty()
		if sc < best_score:
			best_score = sc
			best = m
		_apply_mask(m)   # masks undo themselves
	_apply_mask(best)
	_draw_format(best)
	return true

static func _append(bits: Array, val: int, n: int) -> void:
	for i in range(n - 1, -1, -1):
		bits.append((val >> i) & 1)

func _set_fn(x: int, y: int, dark: bool) -> void:
	modules[y][x] = dark
	_fn[y][x] = true

func _draw_patterns() -> void:
	for i in size:
		_set_fn(6, i, i % 2 == 0)
		_set_fn(i, 6, i % 2 == 0)
	_finder(3, 3)
	_finder(size - 4, 3)
	_finder(3, size - 4)
	var pos: Array = _align_positions()
	var n: int = pos.size()
	for i in n:
		for j in n:
			if (i == 0 and j == 0) or (i == 0 and j == n - 1) or (i == n - 1 and j == 0):
				continue
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					_set_fn(int(pos[i]) + dx, int(pos[j]) + dy, maxi(absi(dx), absi(dy)) != 1)
	_draw_format(0)    # reserve the format areas (redrawn with the real mask later)
	if version >= 7:
		var rem: int = version
		for i in 12:
			rem = (rem << 1) ^ ((rem >> 11) * 0x1F25)
		var vb: int = (version << 12) | rem
		for i in 18:
			var dark: bool = ((vb >> i) & 1) != 0
			var a: int = size - 11 + i % 3
			var b: int = i / 3
			_set_fn(a, b, dark)
			_set_fn(b, a, dark)

func _finder(cx: int, cy: int) -> void:
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var x: int = cx + dx
			var y: int = cy + dy
			if x >= 0 and x < size and y >= 0 and y < size:
				var d: int = maxi(absi(dx), absi(dy))
				_set_fn(x, y, d != 2 and d != 4)

func _align_positions() -> Array:
	if version == 1:
		return []
	var n: int = version / 7 + 2
	var step: int = (version * 8 + n * 3 + 5) / (n * 4 - 4) * 2
	var out: Array = [6]
	var p: int = size - 7
	for i in n - 1:
		out.insert(1, p)
		p -= step
	return out

func _draw_format(mask: int) -> void:
	var data: int = (FORMAT_BITS_M << 3) | mask
	var rem: int = data
	for i in 10:
		rem = (rem << 1) ^ ((rem >> 9) * 0x537)
	var bits: int = ((data << 10) | rem) ^ 0x5412
	for i in 6:
		_set_fn(8, i, _bit(bits, i))
	_set_fn(8, 7, _bit(bits, 6))
	_set_fn(8, 8, _bit(bits, 7))
	_set_fn(7, 8, _bit(bits, 8))
	for i in range(9, 15):
		_set_fn(14 - i, 8, _bit(bits, i))
	for i in 8:
		_set_fn(size - 1 - i, 8, _bit(bits, i))
	for i in range(8, 15):
		_set_fn(8, size - 15 + i, _bit(bits, i))
	_set_fn(8, size - 8, true)

static func _bit(v: int, i: int) -> bool:
	return ((v >> i) & 1) != 0

func _draw_codewords(data: PackedByteArray) -> void:
	var i: int = 0
	var right: int = size - 1
	while right >= 1:
		if right == 6:
			right = 5
		for vert in size:
			for j in 2:
				var x: int = right - j
				var upward: bool = ((right + 1) & 2) == 0
				var y: int = (size - 1 - vert) if upward else vert
				if not _fn[y][x] and i < data.size() * 8:
					modules[y][x] = ((data[i >> 3] >> (7 - (i & 7))) & 1) != 0
					i += 1
		right -= 2

func _apply_mask(m: int) -> void:
	for y in size:
		for x in size:
			if _fn[y][x]:
				continue
			var inv: bool = false
			match m:
				0: inv = (x + y) % 2 == 0
				1: inv = y % 2 == 0
				2: inv = x % 3 == 0
				3: inv = (x + y) % 3 == 0
				4: inv = (x / 3 + y / 2) % 2 == 0
				5: inv = x * y % 2 + x * y % 3 == 0
				6: inv = (x * y % 2 + x * y % 3) % 2 == 0
				7: inv = ((x + y) % 2 + x * y % 3) % 2 == 0
			if inv:
				modules[y][x] = not modules[y][x]

func _penalty() -> int:
	## the standard's rules 1 (long runs), 2 (2x2 blocks) and 4 (dark/light balance); any mask scans, this picks a tidy one
	var p: int = 0
	var dark: int = 0
	for y in size:
		var run_x: int = 1
		var run_y: int = 1
		for x in size:
			if modules[y][x]:
				dark += 1
			if x > 0:
				if modules[y][x] == modules[y][x - 1]:
					run_x += 1
					if run_x == 5:
						p += 3
					elif run_x > 5:
						p += 1
				else:
					run_x = 1
				if modules[x][y] == modules[x - 1][y]:
					run_y += 1
					if run_y == 5:
						p += 3
					elif run_y > 5:
						p += 1
				else:
					run_y = 1
			if x > 0 and y > 0:
				var c: bool = modules[y][x]
				if c == modules[y][x - 1] and c == modules[y - 1][x] and c == modules[y - 1][x - 1]:
					p += 3
	var total: int = size * size
	var k: int = int(ceil(absf(dark * 20.0 - total * 10.0) / total)) - 1
	p += maxi(0, k) * 10
	return p

# ---------------------------------------------------------------- error correction (Reed-Solomon over GF(256))

func _add_ecc(data: PackedByteArray) -> PackedByteArray:
	var nb: int = int(NUM_BLOCKS[version])
	var ecl: int = int(ECC_PER_BLOCK[version])
	var raw: int = _raw_modules(version) / 8
	var n_short: int = nb - raw % nb
	var short_len: int = raw / nb
	var div: PackedByteArray = _divisor(ecl)
	var blocks: Array = []
	var k: int = 0
	for i in nb:
		var take: int = short_len - ecl + (0 if i < n_short else 1)
		var dat: PackedByteArray = data.slice(k, k + take)
		k += take
		var ecc: PackedByteArray = _remainder(dat, div)
		if i < n_short:
			dat.append(0)
		dat.append_array(ecc)
		blocks.append(dat)
	var out: PackedByteArray = PackedByteArray()
	for i in (blocks[0] as PackedByteArray).size():
		for j in blocks.size():
			if i != short_len - ecl or j >= n_short:
				out.append((blocks[j] as PackedByteArray)[i])
	return out

static func _mul(x: int, y: int) -> int:
	var z: int = 0
	for i in range(7, -1, -1):
		z = (z << 1) ^ ((z >> 7) * 0x11D)
		z ^= ((y >> i) & 1) * x
	return z & 0xFF

static func _divisor(degree: int) -> PackedByteArray:
	var r: PackedByteArray = PackedByteArray()
	r.resize(degree)
	r.fill(0)
	r[degree - 1] = 1
	var root: int = 1
	for i in degree:
		for j in degree:
			r[j] = _mul(r[j], root)
			if j + 1 < degree:
				r[j] = r[j] ^ r[j + 1]
		root = _mul(root, 0x02)
	return r

static func _remainder(data: PackedByteArray, div: PackedByteArray) -> PackedByteArray:
	var r: PackedByteArray = PackedByteArray()
	r.resize(div.size())
	r.fill(0)
	for b in data:
		var factor: int = b ^ r[0]
		r.remove_at(0)
		r.append(0)
		for i in div.size():
			r[i] = r[i] ^ _mul(div[i], factor)
	return r

# ---------------------------------------------------------------- pictures

func to_image(px: int = 8, quiet: int = 4) -> Image:
	var n: int = (size + quiet * 2) * px
	var img: Image = Image.create(n, n, false, Image.FORMAT_L8)
	img.fill(Color.WHITE)
	for y in size:
		for x in size:
			if modules[y][x]:
				img.fill_rect(Rect2i((x + quiet) * px, (y + quiet) * px, px, px), Color.BLACK)
	return img
