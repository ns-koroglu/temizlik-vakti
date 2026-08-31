#!/usr/bin/env swift
// Uygulama simgesini (1024x1024 PNG) çizer. Kullanım: swift Scripts/makeicon.swift out.png
import AppKit

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let S: CGFloat = 1024

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// Arka plan: yumuşak köşeli kare + gradyan
let inset: CGFloat = S * 0.06
let bgRect = CGRect(x: inset, y: inset, width: S - inset * 2, height: S - inset * 2)
let bgPath = CGPath(roundedRect: bgRect, cornerWidth: S * 0.225, cornerHeight: S * 0.225, transform: nil)
ctx.saveGState()
ctx.addPath(bgPath); ctx.clip()
let colors = [NSColor(calibratedRed: 0.20, green: 0.62, blue: 0.90, alpha: 1).cgColor,
              NSColor(calibratedRed: 0.10, green: 0.32, blue: 0.66, alpha: 1).cgColor] as CFArray
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0), options: [])
ctx.restoreGState()

// Sünger gövde
ctx.saveGState()
ctx.translateBy(x: S * 0.5, y: S * 0.47)
ctx.rotate(by: -0.13)
let bw = S * 0.52, bh = S * 0.40
let body = CGRect(x: -bw/2, y: -bh/2, width: bw, height: bh)
ctx.setShadow(offset: CGSize(width: 0, height: -S * 0.02), blur: S * 0.05,
              color: NSColor.black.withAlphaComponent(0.35).cgColor)
let bodyPath = CGPath(roundedRect: body, cornerWidth: S * 0.09, cornerHeight: S * 0.09, transform: nil)
ctx.addPath(bodyPath)
ctx.setFillColor(NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.30, alpha: 1).cgColor)
ctx.fillPath()
ctx.setShadow(offset: .zero, blur: 0, color: nil)

// Mavi ovma şeridi
ctx.saveGState()
ctx.addPath(bodyPath); ctx.clip()
ctx.setFillColor(NSColor(calibratedRed: 0.22, green: 0.50, blue: 0.86, alpha: 1).cgColor)
ctx.fill(CGRect(x: -bw/2, y: -bh/2, width: bw, height: bh * 0.3))
// Gözenekler
ctx.setFillColor(NSColor(calibratedRed: 0.86, green: 0.60, blue: 0.14, alpha: 0.75).cgColor)
for (x, y, r) in [(-0.30, 0.22, 0.055), (0.18, 0.26, 0.04), (-0.12, 0.10, 0.035),
                  (0.30, 0.10, 0.05), (-0.34, 0.34, 0.03)] as [(CGFloat, CGFloat, CGFloat)] {
    ctx.fillEllipse(in: CGRect(x: x * bw - r * S/2, y: y * bh - r * S/2, width: r * S, height: r * S))
}
ctx.restoreGState()

// Gözler
for dx in [-0.11, 0.11] as [CGFloat] {
    let ex = dx * bw * 2, ey = bh * 0.16
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillEllipse(in: CGRect(x: ex - S*0.045, y: ey - S*0.05, width: S*0.09, height: S*0.10))
    ctx.setFillColor(NSColor(calibratedWhite: 0.12, alpha: 1).cgColor)
    ctx.fillEllipse(in: CGRect(x: ex - S*0.02, y: ey - S*0.028, width: S*0.04, height: S*0.045))
}
// Gülümseme
ctx.setStrokeColor(NSColor(calibratedRed: 0.35, green: 0.16, blue: 0.16, alpha: 1).cgColor)
ctx.setLineWidth(S * 0.022)
ctx.setLineCap(.round)
ctx.move(to: CGPoint(x: -S * 0.06, y: -S * 0.005))
ctx.addQuadCurve(to: CGPoint(x: S * 0.06, y: -S * 0.005), control: CGPoint(x: 0, y: -S * 0.06))
ctx.strokePath()
ctx.restoreGState()

// Parıltılar
func sparkle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ alpha: CGFloat) {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: cx, y: cy + r))
    p.addQuadCurve(to: CGPoint(x: cx + r, y: cy), control: CGPoint(x: cx + r * 0.18, y: cy + r * 0.18))
    p.addQuadCurve(to: CGPoint(x: cx, y: cy - r), control: CGPoint(x: cx + r * 0.18, y: cy - r * 0.18))
    p.addQuadCurve(to: CGPoint(x: cx - r, y: cy), control: CGPoint(x: cx - r * 0.18, y: cy - r * 0.18))
    p.addQuadCurve(to: CGPoint(x: cx, y: cy + r), control: CGPoint(x: cx - r * 0.18, y: cy + r * 0.18))
    ctx.addPath(p)
    ctx.setFillColor(NSColor.white.withAlphaComponent(alpha).cgColor)
    ctx.fillPath()
}
sparkle(S * 0.755, S * 0.735, S * 0.085, 0.95)
sparkle(S * 0.655, S * 0.845, S * 0.045, 0.75)
sparkle(S * 0.265, S * 0.775, S * 0.055, 0.8)

NSGraphicsContext.restoreGraphicsState()
guard let data = rep.representation(using: .png, properties: [:]) else { exit(1) }
try! data.write(to: URL(fileURLWithPath: outPath))
print("yazıldı: \(outPath)")
