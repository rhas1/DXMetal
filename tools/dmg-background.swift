// Draws the background of the disk image's window: "Drag to install Vapor", an arrow from where
// Finder shows Vapor to where it shows Applications, and how to open Vapor the first time, in the
// colours of Vapor's icon. (Finder writes the icons' names in black over any custom background,
// even in Dark Mode.) tools/dmg-window.sh runs it; the layout there must match the positions here.
// Usage: dmg-background OUT.png SCALE   (SCALE 1 for normal screens, 2 for Retina)
import AppKit

// The window's content is 640 x 400 points under macOS 26's title bar; older versions' shorter title
// bar shows a few more points, so the picture reaches a little further down.
let size = NSSize(width: 640, height: 410)
let appCenter = NSPoint(x: 170, y: 200)     // where Finder centres the icons, from the top left
let applicationsCenter = NSPoint(x: 470, y: 200)

let scale = CGFloat(Double(CommandLine.arguments[2])!)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale),
                           pixelsHigh: Int(size.height * scale), bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0,
                           bitsPerPixel: 0)!
rep.size = size  // draw in points; at scale 2 this also marks the image as 144 dpi
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// AppKit measures from the bottom left, Finder from the top left.
func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x, y: size.height - y) }
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}

// The icon tile's dark blue, deepening towards the bottom, with a soft light behind the icons so
// Vapor's dark tile stands out from it.
let bounds = NSRect(origin: .zero, size: size)
NSGradient(starting: color(0.035, 0.05, 0.095), ending: color(0.11, 0.16, 0.29))!.draw(in: bounds, angle: 90)
NSGradient(starting: color(0.33, 0.50, 0.85, 0.30), ending: color(0.33, 0.50, 0.85, 0))!
    .draw(fromCenter: point(320, 200), radius: 0, toCenter: point(320, 200), radius: 330, options: [])
let mist = color(0.85, 0.92, 1)  // the pale blue of the icon's wisps

// Faint wisps rising at the sides, like the ones on the icon.
func wisp(x: CGFloat, bottom: CGFloat, top: CGFloat, sway: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    let third = (top - bottom) / 3
    path.move(to: NSPoint(x: x, y: bottom))
    path.curve(to: NSPoint(x: x, y: bottom + 1.5 * third),
               controlPoint1: NSPoint(x: x + sway, y: bottom + 0.5 * third),
               controlPoint2: NSPoint(x: x + sway, y: bottom + third))
    path.curve(to: NSPoint(x: x, y: top),
               controlPoint1: NSPoint(x: x - sway, y: bottom + 2 * third),
               controlPoint2: NSPoint(x: x - sway, y: bottom + 2.5 * third))
    return path
}
for (x, top, sway) in [(46.0, 250.0, 22.0), (96.0, 170.0, 18.0), (544.0, 180.0, 18.0), (594.0, 260.0, 22.0)] {
    let line = wisp(x: x, bottom: -20, top: top, sway: sway)
    let outline = NSBezierPath(cgPath: line.cgPath.copy(strokingWithWidth: 16, lineCap: .round, lineJoin: .round, miterLimit: 10))
    NSGradient(starting: mist.withAlphaComponent(0.10), ending: mist.withAlphaComponent(0))!.draw(in: outline, angle: 90)
}

// Text, centred on the window.
func draw(_ text: NSAttributedString, centeredAt y: CGFloat) {
    let width = text.size().width
    text.draw(at: point((size.width - width) / 2, y - text.size().height / 2))
}
func text(_ parts: [(String, NSFont, NSColor)]) -> NSAttributedString {
    let result = NSMutableAttributedString()
    for (string, font, color) in parts {
        result.append(NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color]))
    }
    return result
}

let title = NSFont.systemFont(ofSize: 26, weight: .semibold)
draw(text([("Drag to install ", title, color(1, 1, 1, 0.96)), ("Vapor", title, color(0.62, 0.80, 1))]), centeredAt: 74)

// The arrow: a trail that brightens towards a rounded head, between the two icons.
let tail = point(appCenter.x + 84, appCenter.y), head = point(applicationsCenter.x - 84, applicationsCenter.y)
let shaft = NSBezierPath()
shaft.move(to: tail)
shaft.curve(to: head, controlPoint1: NSPoint(x: tail.x + 45, y: tail.y + 9), controlPoint2: NSPoint(x: head.x - 45, y: head.y - 9))
let shaftOutline = NSBezierPath(cgPath: shaft.cgPath.copy(strokingWithWidth: 5, lineCap: .round, lineJoin: .round, miterLimit: 10))
NSGradient(starting: mist.withAlphaComponent(0.15), ending: mist.withAlphaComponent(0.9))!.draw(in: shaftOutline, angle: 0)
let tip = NSBezierPath()
tip.move(to: NSPoint(x: head.x - 13, y: head.y + 12))
tip.line(to: head)
tip.line(to: NSPoint(x: head.x - 13, y: head.y - 12))
tip.lineWidth = 5
tip.lineCapStyle = .round
tip.lineJoinStyle = .round
mist.withAlphaComponent(0.9).setStroke()
tip.stroke()

// What to do if macOS blocks the first launch, since Vapor isn't notarized.
let note = NSFont.systemFont(ofSize: 12), strong = NSFont.systemFont(ofSize: 12, weight: .semibold)
let dim = color(1, 1, 1, 0.55), bright = color(1, 1, 1, 0.8)
draw(text([("If macOS blocks Vapor the first time you open it,", note, dim)]), centeredAt: 336)
draw(text([("click ", note, dim), ("Open Anyway", strong, bright), (" in ", note, dim),
           ("System Settings › Privacy & Security", strong, bright), (".", note, dim)]), centeredAt: 354)

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
