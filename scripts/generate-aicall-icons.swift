import AppKit
import CoreGraphics
import Foundation

// Superellipse (Apple continuous-curvature squircle approximation, n = 5.0)
func squirclePath(in rect: CGRect, cornerFraction: CGFloat = 0.45) -> CGPath {
    let path = CGMutablePath()
    let a = rect.width / 2.0
    let b = rect.height / 2.0
    let cx = rect.midX
    let cy = rect.midY
    let n: CGFloat = 4.6 // Smooth Apple icon squircle exponent
    let steps = 360
    for i in 0...steps {
        let t = CGFloat(i) * (2.0 * .pi / CGFloat(steps))
        let cosT = cos(t)
        let sinT = sin(t)
        let x = cx + a * (cosT >= 0 ? 1 : -1) * pow(abs(cosT), 2.0 / n)
        let y = cy + b * (sinT >= 0 ? 1 : -1) * pow(abs(sinT), 2.0 / n)
        if i == 0 {
            path.move(to: CGPoint(x: x, y: y))
        } else {
            path.addLine(to: CGPoint(x: x, y: y))
        }
    }
    path.closeSubpath()
    return path
}

func renderIcon(canvasSize: Int, squircleInset: CGFloat, withShadow: Bool, roundedCorners: Bool) -> Data {
    let size = CGFloat(canvasSize)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(
        data: nil,
        width: canvasSize,
        height: canvasSize,
        bitsPerComponent: 8,
        bytesPerRow: canvasSize * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    // Clear transparent canvas
    ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))

    let bodyRect = CGRect(
        x: squircleInset,
        y: squircleInset,
        width: size - squircleInset * 2.0,
        height: size - squircleInset * 2.0
    )
    let bodyPath: CGPath = roundedCorners
        ? squirclePath(in: bodyRect)
        : CGPath(rect: bodyRect, transform: nil)

    // 1. Optional macOS Dock Drop Shadow
    if withShadow {
        ctx.saveGState()
        ctx.setShadow(
            offset: CGSize(width: 0, height: -size * 0.014),
            blur: size * 0.032,
            color: CGColor(srgbRed: 0.01, green: 0.02, blue: 0.06, alpha: 0.46)
        )
        ctx.addPath(bodyPath)
        ctx.setFillColor(CGColor(srgbRed: 0.05, green: 0.07, blue: 0.14, alpha: 1.0))
        ctx.fillPath()
        ctx.restoreGState()
    }

    // 2. Clip inside body shape
    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()

    // Base deep obsidian -> midnight indigo diagonal gradient (top-left to bottom-right)
    let bgColors = [
        CGColor(srgbRed: 0.045, green: 0.065, blue: 0.145, alpha: 1.0),
        CGColor(srgbRed: 0.065, green: 0.090, blue: 0.195, alpha: 1.0),
        CGColor(srgbRed: 0.105, green: 0.075, blue: 0.225, alpha: 1.0)
    ] as CFArray
    let bgGrad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 0.52, 1.0])!
    ctx.drawLinearGradient(
        bgGrad,
        start: CGPoint(x: bodyRect.minX, y: bodyRect.maxY),
        end: CGPoint(x: bodyRect.maxX, y: bodyRect.minY),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )

    // Subtle top-left cyan aurora glow
    let cyanGlowColors = [
        CGColor(srgbRed: 0.14, green: 0.68, blue: 0.98, alpha: 0.30),
        CGColor(srgbRed: 0.14, green: 0.68, blue: 0.98, alpha: 0.0)
    ] as CFArray
    let cyanGlow = CGGradient(colorsSpace: colorSpace, colors: cyanGlowColors, locations: [0.0, 1.0])!
    ctx.drawRadialGradient(
        cyanGlow,
        startCenter: CGPoint(x: bodyRect.minX + bodyRect.width * 0.28, y: bodyRect.maxY - bodyRect.height * 0.22),
        startRadius: 0,
        endCenter: CGPoint(x: bodyRect.minX + bodyRect.width * 0.28, y: bodyRect.maxY - bodyRect.height * 0.22),
        endRadius: bodyRect.width * 0.68,
        options: []
    )

    // Subtle bottom-right violet aurora glow
    let violetGlowColors = [
        CGColor(srgbRed: 0.62, green: 0.30, blue: 0.98, alpha: 0.30),
        CGColor(srgbRed: 0.62, green: 0.30, blue: 0.98, alpha: 0.0)
    ] as CFArray
    let violetGlow = CGGradient(colorsSpace: colorSpace, colors: violetGlowColors, locations: [0.0, 1.0])!
    ctx.drawRadialGradient(
        violetGlow,
        startCenter: CGPoint(x: bodyRect.maxX - bodyRect.width * 0.22, y: bodyRect.minY + bodyRect.height * 0.24),
        startRadius: 0,
        endCenter: CGPoint(x: bodyRect.maxX - bodyRect.width * 0.22, y: bodyRect.minY + bodyRect.height * 0.24),
        endRadius: bodyRect.width * 0.65,
        options: []
    )

    // Normalize glyph coordinates relative to bodyRect
    let u = bodyRect.width
    let ox = bodyRect.minX
    let oy = bodyRect.minY
    func pt(_ nx: CGFloat, _ ny: CGFloat) -> CGPoint {
        return CGPoint(x: ox + nx * u, y: oy + ny * u)
    }

    // Center of the AI Coordinator Core (slightly left of center to balance outward Call Waves & Agent Nodes)
    let core = pt(0.39, 0.50)

    // Three Heterogeneous Agent Satellite Nodes on the outer orchestration arc
    let nodeTop = pt(0.73, 0.74)
    let nodeMid = pt(0.79, 0.50)
    let nodeBot = pt(0.73, 0.26)

    // 3. Subtle luminous link beams from Coordinator Core to the 3 Agent Nodes
    for (target, r, g, b) in [
        (nodeTop, CGFloat(0.22), CGFloat(0.78), CGFloat(0.99)),
        (nodeMid, CGFloat(0.50), CGFloat(0.56), CGFloat(0.99)),
        (nodeBot, CGFloat(0.75), CGFloat(0.42), CGFloat(0.99))
    ] {
        ctx.saveGState()
        let beamPath = CGMutablePath()
        beamPath.move(to: core)
        beamPath.addLine(to: target)
        ctx.addPath(beamPath)
        ctx.setLineCap(.round)
        ctx.setLineWidth(u * 0.022)
        ctx.setStrokeColor(CGColor(srgbRed: r, green: g, blue: b, alpha: 0.24))
        ctx.strokePath()
        ctx.restoreGState()
    }

    // 4. Dual Acoustic / Signal "Call" Broadcast Arcs sweeping right from Core
    let arcSpecs: [(radius: CGFloat, angleDeg: CGFloat, width: CGFloat, alpha: CGFloat)] = [
        (0.185, 50.0, 0.044, 0.96),
        (0.305, 44.0, 0.040, 0.84)
    ]

    for spec in arcSpecs {
        let rad = spec.angleDeg * .pi / 180.0
        let arcPath = CGMutablePath()
        arcPath.addArc(center: core, radius: u * spec.radius, startAngle: -rad, endAngle: rad, clockwise: false)

        // Soft outer bloom on the signal arc
        ctx.saveGState()
        ctx.setShadow(
            offset: .zero,
            blur: u * 0.035,
            color: CGColor(srgbRed: 0.30, green: 0.68, blue: 1.0, alpha: 0.55)
        )
        ctx.addPath(arcPath)
        ctx.setLineCap(.round)
        ctx.setLineWidth(u * spec.width)
        ctx.replacePathWithStrokedPath()
        ctx.clip()

        let arcColors = [
            CGColor(srgbRed: 0.76, green: 0.48, blue: 0.99, alpha: spec.alpha),
            CGColor(srgbRed: 0.45, green: 0.62, blue: 0.99, alpha: spec.alpha),
            CGColor(srgbRed: 0.22, green: 0.85, blue: 0.99, alpha: spec.alpha)
        ] as CFArray
        let arcGrad = CGGradient(colorsSpace: colorSpace, colors: arcColors, locations: [0.0, 0.5, 1.0])!
        ctx.drawLinearGradient(
            arcGrad,
            start: pt(0.39, 0.20),
            end: pt(0.39, 0.80),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
        ctx.restoreGState()
    }

    // 5. Central AI Spark / 4-Point Astroid Star Nexus at `core`
    func sparkPath(center: CGPoint, outerR: CGFloat, innerR: CGFloat) -> CGPath {
        let p = CGMutablePath()
        let top = CGPoint(x: center.x, y: center.y + outerR)
        let right = CGPoint(x: center.x + outerR, y: center.y)
        let bottom = CGPoint(x: center.x, y: center.y - outerR)
        let left = CGPoint(x: center.x - outerR, y: center.y)
        p.move(to: top)
        p.addQuadCurve(to: right, control: CGPoint(x: center.x + innerR, y: center.y + innerR))
        p.addQuadCurve(to: bottom, control: CGPoint(x: center.x + innerR, y: center.y - innerR))
        p.addQuadCurve(to: left, control: CGPoint(x: center.x - innerR, y: center.y - innerR))
        p.addQuadCurve(to: top, control: CGPoint(x: center.x - innerR, y: center.y + innerR))
        p.closeSubpath()
        return p
    }

    // Core glow halo
    let coreHaloColors = [
        CGColor(srgbRed: 0.35, green: 0.82, blue: 1.0, alpha: 0.60),
        CGColor(srgbRed: 0.35, green: 0.82, blue: 1.0, alpha: 0.0)
    ] as CFArray
    let coreHalo = CGGradient(colorsSpace: colorSpace, colors: coreHaloColors, locations: [0.0, 1.0])!
    ctx.drawRadialGradient(
        coreHalo,
        startCenter: core,
        startRadius: 0,
        endCenter: core,
        endRadius: u * 0.20,
        options: []
    )

    // Draw AI Spark Core
    ctx.saveGState()
    let spark = sparkPath(center: core, outerR: u * 0.145, innerR: u * 0.036)
    ctx.addPath(spark)
    ctx.clip()
    let sparkColors = [
        CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
        CGColor(srgbRed: 0.72, green: 0.93, blue: 1.0, alpha: 1.0),
        CGColor(srgbRed: 0.38, green: 0.78, blue: 1.0, alpha: 1.0)
    ] as CFArray
    let sparkGrad = CGGradient(colorsSpace: colorSpace, colors: sparkColors, locations: [0.0, 0.55, 1.0])!
    ctx.drawLinearGradient(
        sparkGrad,
        start: CGPoint(x: core.x - u * 0.10, y: core.y + u * 0.14),
        end: CGPoint(x: core.x + u * 0.10, y: core.y - u * 0.14),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
    ctx.restoreGState()

    // 6. Draw the 3 Orbiting Agent Nodes (Cyan, Indigo, Violet)
    let nodes: [(pos: CGPoint, radius: CGFloat, c1: (CGFloat, CGFloat, CGFloat), c2: (CGFloat, CGFloat, CGFloat))] = [
        (nodeTop, 0.052, (0.72, 0.96, 1.0), (0.14, 0.74, 0.98)),
        (nodeMid, 0.060, (0.86, 0.88, 1.0), (0.46, 0.52, 0.99)),
        (nodeBot, 0.052, (0.95, 0.80, 1.0), (0.72, 0.36, 0.98))
    ]

    for node in nodes {
        let nr = u * node.radius
        let nRect = CGRect(x: node.pos.x - nr, y: node.pos.y - nr, width: nr * 2, height: nr * 2)

        // Outer glow
        let glowCols = [
            CGColor(srgbRed: node.c2.0, green: node.c2.1, blue: node.c2.2, alpha: 0.55),
            CGColor(srgbRed: node.c2.0, green: node.c2.1, blue: node.c2.2, alpha: 0.0)
        ] as CFArray
        let glow = CGGradient(colorsSpace: colorSpace, colors: glowCols, locations: [0.0, 1.0])!
        ctx.drawRadialGradient(glow, startCenter: node.pos, startRadius: nr * 0.4, endCenter: node.pos, endRadius: nr * 2.1, options: [])

        // Sphere fill
        ctx.saveGState()
        ctx.addEllipse(in: nRect)
        ctx.clip()
        let fillCols = [
            CGColor(srgbRed: node.c1.0, green: node.c1.1, blue: node.c1.2, alpha: 1.0),
            CGColor(srgbRed: node.c2.0, green: node.c2.1, blue: node.c2.2, alpha: 1.0)
        ] as CFArray
        let fillGrad = CGGradient(colorsSpace: colorSpace, colors: fillCols, locations: [0.0, 1.0])!
        ctx.drawRadialGradient(
            fillGrad,
            startCenter: CGPoint(x: node.pos.x - nr * 0.32, y: node.pos.y + nr * 0.32),
            startRadius: 0,
            endCenter: node.pos,
            endRadius: nr * 1.15,
            options: [.drawsAfterEndLocation]
        )
        ctx.restoreGState()
    }

    // 7. Crisp Inner Specular Glass Rim Border
    if roundedCorners {
        let insetRimRect = bodyRect.insetBy(dx: size * 0.0025, dy: size * 0.0025)
        let rimPath = squirclePath(in: insetRimRect)
        ctx.saveGState()
        ctx.addPath(rimPath)
        ctx.setLineWidth(max(1.5, size * 0.004))
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        let rimCols = [
            CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.34),
            CGColor(srgbRed: 0.55, green: 0.72, blue: 1.0, alpha: 0.14),
            CGColor(srgbRed: 0.70, green: 0.45, blue: 1.0, alpha: 0.22)
        ] as CFArray
        let rimGrad = CGGradient(colorsSpace: colorSpace, colors: rimCols, locations: [0.0, 0.5, 1.0])!
        ctx.drawLinearGradient(
            rimGrad,
            start: CGPoint(x: bodyRect.midX, y: bodyRect.maxY),
            end: CGPoint(x: bodyRect.midX, y: bodyRect.minY),
            options: []
        )
        ctx.restoreGState()
    }

    ctx.restoreGState()

    let cgImg = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: cgImg)
    return rep.representation(using: .png, properties: [:])!
}

func downscalePng(_ png2x: Data, to targetPx: Int) -> Data {
    let srcRep = NSBitmapImageRep(data: png2x)!
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(
        data: nil,
        width: targetPx,
        height: targetPx,
        bitsPerComponent: 8,
        bytesPerRow: targetPx * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.interpolationQuality = .high
    ctx.draw(srcRep.cgImage!, in: CGRect(x: 0, y: 0, width: targetPx, height: targetPx))
    return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

func encodeIco(pngs: [(size: Int, data: Data)]) -> Data {
    var header = Data(count: 6 + 16 * pngs.count)
    header[0] = 0; header[1] = 0
    header[2] = 1; header[3] = 0
    let count = UInt16(pngs.count)
    header[4] = UInt8(count & 0xff)
    header[5] = UInt8((count >> 8) & 0xff)

    var offset = UInt32(header.count)
    for (idx, item) in pngs.enumerated() {
        let base = 6 + idx * 16
        let szByte: UInt8 = item.size == 256 ? 0 : UInt8(item.size)
        header[base + 0] = szByte
        header[base + 1] = szByte
        header[base + 2] = 0
        header[base + 3] = 0
        header[base + 4] = 1; header[base + 5] = 0
        header[base + 6] = 32; header[base + 7] = 0
        let len = UInt32(item.data.count)
        header[base + 8] = UInt8(len & 0xff)
        header[base + 9] = UInt8((len >> 8) & 0xff)
        header[base + 10] = UInt8((len >> 16) & 0xff)
        header[base + 11] = UInt8((len >> 24) & 0xff)
        header[base + 12] = UInt8(offset & 0xff)
        header[base + 13] = UInt8((offset >> 8) & 0xff)
        header[base + 14] = UInt8((offset >> 16) & 0xff)
        header[base + 15] = UInt8((offset >> 24) & 0xff)
        offset += len
    }
    var out = header
    for item in pngs { out.append(item.data) }
    return out
}

let repoRoot = "/Users/natie/Documents/antigravity/T3code/Multi-Agent"
let artifactPreview = "/Users/natie/.gemini/antigravity/brain/c268e162-7e7f-4ee4-b7cd-3604283a2bef/aicall_icon_preview.png"

// 1) Supersample 2048 -> 1024 macOS Dock Squircle Icon (inset 200 on 2048 = 100px on 1024, Apple HIG standard!)
let mac2048 = renderIcon(canvasSize: 2048, squircleInset: 200.0, withShadow: true, roundedCorners: true)
let mac1024 = downscalePng(mac2048, to: 1024)

// 2) Supersample 2048 -> 1024 Rounded Badge Icon (zero outer margin, rounded squircle for web/UI/universal)
let badge2048 = renderIcon(canvasSize: 2048, squircleInset: 0.0, withShadow: false, roundedCorners: true)
let badge1024 = downscalePng(badge2048, to: 1024)

// 3) Supersample 2048 -> 1024 Full-Bleed Square Icon (for iOS / Apple Touch where OS masks corners)
let full2048 = renderIcon(canvasSize: 2048, squircleInset: 0.0, withShadow: false, roundedCorners: false)
let full1024 = downscalePng(full2048, to: 1024)

try mac1024.write(to: URL(fileURLWithPath: artifactPreview))

func writeAll(_ relPaths: [String], _ data: Data) throws {
    for rel in relPaths {
        try data.write(to: URL(fileURLWithPath: "\(repoRoot)/\(rel)"))
    }
}

// Write macOS 1024 icons across prod, nightly, dev so every build channel uses AICall
try writeAll([
    "assets/prod/black-macos-1024.png",
    "assets/nightly/nightly-macos-1024.png",
    "assets/dev/blueprint-macos-1024.png"
], mac1024)

// Write universal 1024 icons (rounded badge) and iOS 1024 icons (full bleed)
try writeAll([
    "assets/prod/black-universal-1024.png",
    "assets/nightly/nightly-universal-1024.png",
    "assets/dev/blueprint-universal-1024.png"
], badge1024)

try writeAll([
    "assets/prod/black-ios-1024.png",
    "assets/nightly/nightly-ios-1024.png",
    "assets/dev/blueprint-ios-1024.png"
], full1024)

// Generate crisp downscaled web/UI renditions (T3AppIcon.tsx uses t3-black-web-apple-touch-180.png -> use rounded badge so it looks sharp inside UI!)
let png512 = downscalePng(badge2048, to: 512)
let png192 = downscalePng(badge2048, to: 192)
let png180 = downscalePng(badge2048, to: 180)
let png32 = downscalePng(badge2048, to: 32)
let png16 = downscalePng(badge2048, to: 16)

try writeAll([
    "assets/prod/t3-black-web-icon-512x512.png",
    "assets/nightly/nightly-web-icon-512x512.png",
    "assets/dev/blueprint-web-icon-512x512.png",
    "apps/web/public/icon-512x512.png"
], png512)

try writeAll([
    "assets/prod/t3-black-web-icon-192x192.png",
    "assets/nightly/nightly-web-icon-192x192.png",
    "assets/dev/blueprint-web-icon-192x192.png",
    "apps/web/public/icon-192x192.png"
], png192)

try writeAll([
    "assets/prod/t3-black-web-apple-touch-180.png",
    "assets/nightly/nightly-web-apple-touch-180.png",
    "assets/dev/blueprint-web-apple-touch-180.png",
    "apps/web/public/apple-touch-icon.png"
], png180)

try writeAll([
    "assets/prod/t3-black-web-favicon-32x32.png",
    "assets/nightly/nightly-web-favicon-32x32.png",
    "assets/dev/blueprint-web-favicon-32x32.png",
    "apps/web/public/favicon-32x32.png"
], png32)

try writeAll([
    "assets/prod/t3-black-web-favicon-16x16.png",
    "assets/nightly/nightly-web-favicon-16x16.png",
    "assets/dev/blueprint-web-favicon-16x16.png",
    "apps/web/public/favicon-16x16.png"
], png16)

// Generate Windows & Web ICO files
let winSizes = [16, 24, 32, 48, 64, 128, 256]
let winIco = encodeIco(pngs: winSizes.map { ($0, downscalePng(badge2048, to: $0)) })
let webFaviconIco = encodeIco(pngs: [16, 32, 48].map { ($0, downscalePng(badge2048, to: $0)) })

try writeAll([
    "assets/prod/t3-black-windows.ico",
    "assets/nightly/nightly-windows.ico",
    "assets/dev/blueprint-windows.ico"
], winIco)

try writeAll([
    "assets/prod/t3-black-web-favicon.ico",
    "assets/nightly/nightly-web-favicon.ico",
    "assets/dev/blueprint-web-favicon.ico",
    "apps/web/public/favicon.ico"
], webFaviconIco)

print("SUCCESS: Generated all AICall icon assets!")
