import AppKit
let destination = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
for size in [16,32,64,128,256,512,1024] {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(size)/128, y: CGFloat(size)/128)
    let tile = NSBezierPath(roundedRect: .init(x: 4, y: 4, width: 120, height: 120), xRadius: 30, yRadius: 30)
    NSGradient(starting: .init(calibratedRed: 0.96, green: 0.98, blue: 1, alpha: 1), ending: .init(calibratedRed: 0.86, green: 0.91, blue: 0.98, alpha: 1))!.draw(in: tile, angle: -45)
    NSColor.white.withAlphaComponent(0.85).setStroke(); tile.lineWidth = 1; tile.stroke()
    NSColor(calibratedRed: 0.25, green: 0.36, blue: 0.49, alpha: 1).setStroke()
    let back = NSBezierPath(); back.move(to: .init(x: 44, y: 49)); back.line(to: .init(x: 40, y: 49)); back.curve(to: .init(x: 32, y: 57), controlPoint1: .init(x: 32, y: 49), controlPoint2: .init(x: 32, y: 49)); back.line(to: .init(x: 32, y: 83)); back.curve(to: .init(x: 40, y: 91), controlPoint1: .init(x: 32, y: 91), controlPoint2: .init(x: 32, y: 91)); back.line(to: .init(x: 74, y: 91)); back.curve(to: .init(x: 82, y: 83), controlPoint1: .init(x: 82, y: 91), controlPoint2: .init(x: 82, y: 91)); back.line(to: .init(x: 82, y: 79)); back.lineWidth = 5.2; back.lineCapStyle = .round; back.stroke()
    let front = NSBezierPath(roundedRect: .init(x: 44, y: 35, width: 52, height: 44), xRadius: 9, yRadius: 9); front.lineWidth = 5.2; front.stroke()
    let t = NSBezierPath(); t.move(to: .init(x: 60, y: 65)); t.line(to: .init(x: 80, y: 65)); t.move(to: .init(x: 70, y: 65)); t.line(to: .init(x: 70, y: 47)); t.lineWidth = 5.2; t.lineCapStyle = .round; t.stroke()
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    if size <= 512 { try data.write(to: URL(fileURLWithPath: destination).appendingPathComponent("icon_\(size)x\(size).png")) }
    if size >= 32 { try data.write(to: URL(fileURLWithPath: destination).appendingPathComponent("icon_\(size/2)x\(size/2)@2x.png")) }
}
