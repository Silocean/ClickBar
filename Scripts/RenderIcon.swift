import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fputs("usage: RenderIcon.swift AppIcon.iconset\n", stderr)
    exit(1)
}

let output = URL(fileURLWithPath: arguments[1], isDirectory: true)
let fileManager = FileManager.default
if fileManager.fileExists(atPath: output.path) {
    try fileManager.removeItem(at: output)
}
try fileManager.createDirectory(at: output, withIntermediateDirectories: true)

let files: [Int: [String]] = [
    16: ["icon_16x16.png"],
    32: ["icon_16x16@2x.png", "icon_32x32.png"],
    64: ["icon_32x32@2x.png"],
    128: ["icon_128x128.png"],
    256: ["icon_128x128@2x.png", "icon_256x256.png"],
    512: ["icon_256x256@2x.png", "icon_512x512.png"],
    1024: ["icon_512x512@2x.png"]
]

for (size, names) in files {
    let data = try png(size: size)
    for name in names {
        try data.write(to: output.appendingPathComponent(name))
    }
}

func png(size: Int) throws -> Data {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fputs("unable to allocate bitmap\n", stderr)
        exit(1)
    }
    rep.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let canvas = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor(srgbRed: 0.11, green: 0.36, blue: 0.86, alpha: 1).setFill()
    canvas.fill()

    let pointSize = CGFloat(size) * 0.46
    let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
    guard let base = NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration) else {
        fputs("mouse symbol is unavailable\n", stderr)
        exit(1)
    }
    let symbol = tintedWhite(base)
    let side = CGFloat(size) * 0.62
    let origin = (CGFloat(size) - side) / 2
    let destination = NSRect(x: origin, y: origin - CGFloat(size) * 0.03, width: side, height: side)
    symbol.draw(
        in: destination,
        from: NSRect(origin: .zero, size: symbol.size),
        operation: .sourceOver,
        fraction: 1
    )

    NSGraphicsContext.restoreGraphicsState()
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fputs("unable to encode png\n", stderr)
        exit(1)
    }
    return data
}

func tintedWhite(_ image: NSImage) -> NSImage {
    let copy = image.copy() as? NSImage ?? image
    copy.lockFocus()
    NSColor.white.setFill()
    NSRect(origin: .zero, size: copy.size).fill(using: .sourceAtop)
    copy.unlockFocus()
    copy.isTemplate = false
    return copy
}
