// Draws the NerdrKeys app icon at 1024×1024 and writes PNG to the path given.
// Compiled together with glassesPath() pulled from main.swift (see icon/make-icon.sh).
import AppKit

func hex(_ h: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((h >> 16) & 0xff) / 255, green: CGFloat((h >> 8) & 0xff) / 255,
            blue: CGFloat(h & 0xff) / 255, alpha: a)
}

let S: CGFloat = 1024
let space = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// macOS icon grid: 824×824 rounded square centred on the 1024 canvas.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

// Soft drop shadow under the tile.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: hex(0x000000, 0.45))
ctx.addPath(tilePath); ctx.setFillColor(hex(0x241b2f)); ctx.fillPath()
ctx.restoreGState()

// Tile background: deep Synthwave purple, lighter at the top.
ctx.saveGState()
ctx.addPath(tilePath); ctx.clip()
let bg = CGGradient(colorsSpace: space, colors: [hex(0x34294f), hex(0x241b2f), hex(0x171520)] as CFArray,
                    locations: [0, 0.55, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

// Faint horizon grid lines in the lower third, a nod to the theme.
ctx.setStrokeColor(hex(0xff7edb, 0.10)); ctx.setLineWidth(4)
for i in 0..<5 {
    let y = 130 + CGFloat(i * i) * 14 + CGFloat(i) * 20
    ctx.move(to: CGPoint(x: 100, y: y)); ctx.addLine(to: CGPoint(x: 924, y: y))
}
ctx.strokePath()
ctx.restoreGState()

// Glasses: fit 600 pt wide, centred slightly above middle.
let glasses = glassesPath()
let box = glasses.boundingBoxOfPath
let scale = 600 / box.width
var t = CGAffineTransform(translationX: (S - box.width * scale) / 2, y: (S - box.height * scale) / 2 + 30)
    .scaledBy(x: scale, y: scale)
    .translatedBy(x: -box.minX, y: -box.minY)
let placed = glasses.copy(using: &t)!

// Neon glow behind the glasses.
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 60, color: hex(0xff7edb, 0.85))
ctx.addPath(placed); ctx.setFillColor(hex(0xff7edb)); ctx.fillPath()
ctx.restoreGState()

// Glasses filled with a pink → cyan gradient.
ctx.saveGState()
ctx.addPath(placed); ctx.clip()
let neon = CGGradient(colorsSpace: space, colors: [hex(0xff7edb), hex(0x36f9f6)] as CFArray, locations: [0, 1])!
let pb = placed.boundingBoxOfPath
ctx.drawLinearGradient(neon, start: CGPoint(x: pb.minX, y: pb.maxY), end: CGPoint(x: pb.maxX, y: pb.minY), options: [])
ctx.restoreGState()

// Thin highlight around the tile edge.
ctx.addPath(tilePath); ctx.setStrokeColor(hex(0xffffff, 0.08)); ctx.setLineWidth(3); ctx.strokePath()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
