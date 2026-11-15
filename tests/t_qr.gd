extends SceneTree
## Writes QR codes for a spread of invite links (short to long, so several versions and block layouts) as PNGs,
## plus the text each should say, for tests/qr_decode.swift to read back with macOS's own QR reader.
## OUT=dir (default /tmp/yc_qr)

func _init() -> void:
	var out: String = OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "/tmp/yc_qr"
	DirAccess.make_dir_recursive_absolute(out)
	var texts: Array = [
		"BEGA",
		"http://192.168.0.6:8480/?room=BEGA",
		"https://localhost:8060/?room=ZQXW",
		"https://192-168-0-6.2c652723f8817cc5f10678fe47cb8289bfc09862.myunraid.net:8443/?room=KADI",
		"https://yescaptain.example/?room=TIKU&server=wss%3A%2F%2Fyescaptain.example%2Fws&name=Sam",
		"https://192-168-0-6.2c652723f8817cc5f10678fe47cb8289bfc09862.myunraid.net:8443/?room=KADI&server=wss%3A%2F%2F192-168-0-6.2c652723f8817cc5f10678fe47cb8289bfc09862.myunraid.net%3A8443%2Fws",
	]
	var f: FileAccess = FileAccess.open(out + "/expected.txt", FileAccess.WRITE)
	for i in texts.size():
		var q: Qr = Qr.make(str(texts[i]))
		if q == null:
			print("QR too long: ", texts[i])
			quit(1)
			return
		q.to_image(6).save_png("%s/qr%d.png" % [out, i])
		f.store_line(str(texts[i]))
		print("QR %d: version %d (%d modules) for %d chars" % [i, q.version, q.size, str(texts[i]).length()])
	f.close()
	quit(0)
