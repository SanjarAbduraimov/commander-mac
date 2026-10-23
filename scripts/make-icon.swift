// Draws the Commander app icon and writes a macOS AppIcon.appiconset.
// Usage: swift scripts/make-icon.swift App/Assets.xcassets/AppIcon.appiconset
import AppKit

let canvas: CGFloat = 1024

func color(_ hex: Int, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

/// Drawn in a 1024-point space (origin bottom-left) following Apple's macOS icon grid: an 824-point squircle
/// centred with room for its shadow.
func draw(in ctx: CGContext) {
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = roundedRect(tile, 185)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: color(0x000000, 0.35))
    ctx.addPath(tilePath)
    ctx.setFillColor(color(0x101A33))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let background = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [color(0x2C5BD8), color(0x14214A)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(background, start: CGPoint(x: 200, y: 924), end: CGPoint(x: 824, y: 100), options: [])
    // A soft top highlight gives the tile some depth without extra detail.
    let sheen = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [color(0xFFFFFF, 0.16), color(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(sheen, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 560), options: [])
    ctx.restoreGState()

    // Two panes: the active one solid, the other one translucent.
    let paneWidth: CGFloat = 262, paneHeight: CGFloat = 470, gap: CGFloat = 56
    let paneY = (canvas - paneHeight) / 2 - 6
    let leftPane = CGRect(x: (canvas - 2 * paneWidth - gap) / 2, y: paneY, width: paneWidth, height: paneHeight)
    let rightPane = leftPane.offsetBy(dx: paneWidth + gap, dy: 0)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 22, color: color(0x050A1A, 0.45))
    ctx.addPath(roundedRect(leftPane, 44))
    ctx.setFillColor(color(0xFFFFFF))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.addPath(roundedRect(rightPane, 44))
    ctx.setFillColor(color(0xFFFFFF, 0.22))
    ctx.fillPath()
    ctx.addPath(roundedRect(rightPane.insetBy(dx: 3, dy: 3), 41))
    ctx.setStrokeColor(color(0xFFFFFF, 0.45))
    ctx.setLineWidth(6)
    ctx.strokePath()

    // File rows; the first row of the active pane is the cursor.
    for (pane, rowColor, cursor) in [(leftPane, color(0x2C5BD8, 0.28), color(0x2C5BD8)), (rightPane, color(0xFFFFFF, 0.55), color(0xFFFFFF, 0.55))] {
        for index in 0..<3 {
            let width = pane.width - 76 - CGFloat(index % 2) * 52
            let row = CGRect(x: pane.minX + 38, y: pane.maxY - 92 - CGFloat(index) * 82, width: width, height: 30)
            ctx.addPath(roundedRect(row, 15))
            ctx.setFillColor(index == 0 ? cursor : rowColor)
            ctx.fillPath()
        }
    }

    // The copy arrow crossing from the active pane into the other one.
    let arrowY = paneY + 112
    let tip = CGPoint(x: rightPane.midX + 46, y: arrowY)
    let shaft = CGMutablePath()
    shaft.move(to: CGPoint(x: leftPane.midX, y: arrowY))
    shaft.addLine(to: CGPoint(x: tip.x - 60, y: arrowY))
    let head = CGMutablePath()
    head.move(to: tip)
    head.addLine(to: CGPoint(x: tip.x - 96, y: arrowY + 78))
    head.addLine(to: CGPoint(x: tip.x - 96, y: arrowY - 78))
    head.closeSubpath()
    ctx.saveGState()
    // One layer so the shadow falls once under the whole arrow instead of under each part.
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 16, color: color(0x3A1A00, 0.35))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.setStrokeColor(color(0xFFB238))
    ctx.setFillColor(color(0xFFB238))
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.addPath(shaft)
    ctx.setLineWidth(48)
    ctx.strokePath()
    ctx.addPath(head)
    ctx.setLineWidth(26)
    ctx.drawPath(using: .fillStroke)
    ctx.endTransparencyLayer()
    ctx.restoreGState()
}

func png(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    let ctx = context.cgContext
    ctx.interpolationQuality = .high
    ctx.scaleBy(x: CGFloat(pixels) / canvas, y: CGFloat(pixels) / canvas)
    draw(in: ctx)
    context.flushGraphics()
    return rep.representation(using: .png, properties: [:])!
}

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppIcon.appiconset", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try png(pixels: points * scale).write(to: output.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["version": 1, "author": "xcode"]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: output.appendingPathComponent("Contents.json"))
print("Wrote \(images.count) icons to \(output.path)")
