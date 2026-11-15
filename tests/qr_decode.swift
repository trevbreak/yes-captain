// Reads every qrN.png in a folder with macOS's built-in QR reader (CoreImage) and checks it says what
// expected.txt says. An independent check on ui/qr.gd. Usage: swift tests/qr_decode.swift <dir>
import CoreImage
import Foundation

let dir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/yc_qr"
let expected = (try? String(contentsOfFile: dir + "/expected.txt", encoding: .utf8))?
    .split(separator: "\n", omittingEmptySubsequences: false).map(String.init) ?? []
let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])!
var fails = 0
for (i, want) in expected.enumerated() where !want.isEmpty {
    let url = URL(fileURLWithPath: "\(dir)/qr\(i).png")
    guard let img = CIImage(contentsOf: url) else { print("QR \(i): can't open"); fails += 1; continue }
    let got = (detector.features(in: img).first as? CIQRCodeFeature)?.messageString ?? "<nothing>"
    let ok = got == want
    if !ok { fails += 1 }
    print("QR \(i): \(ok ? "ok  " : "FAIL") \(ok ? want : "wanted \(want), read \(got)")")
}
print(fails == 0 ? "QR DECODE PASS" : "QR DECODE FAIL (\(fails))")
exit(fails == 0 ? 0 : 1)
