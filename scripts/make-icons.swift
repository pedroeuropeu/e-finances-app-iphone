import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Gera o ícone do app (claro, escuro e tingido) e o logo da abertura: swift scripts/make-icons.swift <pasta de saída>
// Desenho do logo da web (viewBox 120): arco "M84 60 A24 24 0 1 0 77 77" e a barra "M36 60 H84".
func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func draw(size: Int, background: CGColor?, circle: CGColor?, ink: CGColor, bar: CGColor, glyphScale: CGFloat, stroke: CGFloat, to path: String) {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let s = CGFloat(size)
    // origem no topo, como no SVG
    ctx.translateBy(x: 0, y: s)
    ctx.scaleBy(x: 1, y: -1)
    if let background { ctx.setFillColor(background); ctx.fill(CGRect(x: 0, y: 0, width: s, height: s)) }
    let k = s / 120 * glyphScale
    let off = (s - 120 * k) / 2
    ctx.translateBy(x: off, y: off)
    if let circle { ctx.setFillColor(circle); ctx.fillEllipse(in: CGRect(x: 4 * k, y: 4 * k, width: 112 * k, height: 112 * k)) }
    ctx.setLineCap(.round)
    ctx.setLineWidth(stroke * k)
    // arco do "e": do ponto (84,60), raio 24, grande arco no sentido anti-horário (sweep 0) até (77,77)
    let center = CGPoint(x: 60 * k, y: 60 * k)
    let start = atan2(60.0 - 60.0, 84.0 - 60.0)
    let end = atan2(77.0 - 60.0, 77.0 - 60.0)
    ctx.setStrokeColor(ink)
    ctx.addArc(center: center, radius: 24 * k, startAngle: start, endAngle: end, clockwise: true)
    ctx.strokePath()
    ctx.setStrokeColor(bar)
    ctx.move(to: CGPoint(x: 36 * k, y: 60 * k))
    ctx.addLine(to: CGPoint(x: 84 * k, y: 60 * k))
    ctx.strokePath()
    let img = ctx.makeImage()!
    let url = URL(fileURLWithPath: path)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
}

let out = CommandLine.arguments[1]
let navy: UInt32 = 0x0B2545
// ícone: fundo azul-marinho inteiro (o iOS arredonda), glifo grande
draw(size: 1024, background: rgb(navy), circle: nil, ink: rgb(0xFFFFFF), bar: rgb(0x10B981), glyphScale: 1.22, stroke: 12, to: "\(out)/AppIcon.png")
// escuro (iOS 18): fundo transparente, verde mais claro
draw(size: 1024, background: nil, circle: nil, ink: rgb(0xFFFFFF), bar: rgb(0x34D399), glyphScale: 1.22, stroke: 12, to: "\(out)/AppIcon-Dark.png")
// tingido (iOS 18): tons de cinza sobre transparente
draw(size: 1024, background: nil, circle: nil, ink: rgb(0xFFFFFF), bar: rgb(0xB8B8B8), glyphScale: 1.22, stroke: 12, to: "\(out)/AppIcon-Tinted.png")
// abertura: o círculo do logo sobre o azul-marinho (3x de 96 pt)
draw(size: 288, background: nil, circle: rgb(0x16304F), ink: rgb(0xFFFFFF), bar: rgb(0x10B981), glyphScale: 1, stroke: 11, to: "\(out)/LaunchLogo.png")
print("ok")
