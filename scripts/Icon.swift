import AppKit
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for (name, size) in [("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64), ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512), ("icon_512x512", 512), ("icon_512x512@2x", 1024)] {
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    let rect = NSRect(x: 60, y: 60, width: 904, height: 904)
    let path = NSBezierPath(roundedRect: rect, xRadius: 210, yRadius: 210)
    NSGradient(starting: NSColor(calibratedRed: 0.19, green: 0.78, blue: 0.50, alpha: 1), ending: NSColor(calibratedRed: 0.03, green: 0.43, blue: 0.29, alpha: 1))!.draw(in: path, angle: -80)
    context.setStrokeColor(NSColor.white.cgColor); context.setLineWidth(52); context.setLineCap(.round); context.setLineJoin(.round)
    for (x, y, dx, dy): (CGFloat, CGFloat, CGFloat, CGFloat) in [(284, 740, 140, -140), (740, 740, -140, -140), (284, 284, 140, 140), (740, 284, -140, 140)] {
        context.move(to: CGPoint(x: x, y: y + dy)); context.addLine(to: CGPoint(x: x, y: y)); context.addLine(to: CGPoint(x: x + dx, y: y)); context.strokePath()
    }
    context.setFillColor(NSColor.white.cgColor); context.fillEllipse(in: CGRect(x: 454, y: 454, width: 116, height: 116))
    NSGraphicsContext.restoreGraphicsState()
    let data = NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
    try data.write(to: directory.appendingPathComponent(name + ".png"))
}
