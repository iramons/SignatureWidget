//
//  Signature.swift
//  SignatureWidget
//
//  Created by Ramon Santos on 16/11/25.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Signature {
    @Attribute(.unique) var uuid: UUID
    var createdAt: Date
    var name: String?
    var strokeColorHex: String
    var strokeWidth: CGFloat
    var strokes: [Stroke]

    init(uuid: UUID = UUID(),
         createdAt: Date = Date(),
         name: String? = nil,
         strokeColor: Color = .primary,
         strokeWidth: CGFloat = 4.0,
         strokes: [Stroke] = []) {
        self.uuid = uuid
        self.createdAt = createdAt
        self.name = name
        self.strokeColorHex = strokeColor.toHexRGBA()
        self.strokeWidth = strokeWidth
        self.strokes = strokes
    }
}

// MARK: - Stroke Model

struct Stroke: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var points: [StrokePoint]
    var colorHex: String
    var lineWidth: CGFloat

    init(points: [StrokePoint] = [],
         color: Color = .primary,
         lineWidth: CGFloat = 4.0) {
        self.points = points
        self.colorHex = color.toHexRGBA()
        self.lineWidth = lineWidth
    }

    var color: Color {
        Color.fromHexRGBA(colorHex) ?? .primary
    }
}

struct StrokePoint: Codable, Hashable {
    var x: CGFloat
    var y: CGFloat
    var t: TimeInterval

    init(_ x: CGFloat, _ y: CGFloat, t: TimeInterval = Date().timeIntervalSince1970) {
        self.x = x
        self.y = y
        self.t = t
    }

    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

// MARK: - Color <-> Hex helpers

extension Color {
    func toHexRGBA() -> String {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        #else
        let ns = NSColor(self)
        let color = ns.usingColorSpace(.deviceRGB) ?? ns
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        let ri = Int(round(r * 255))
        let gi = Int(round(g * 255))
        let bi = Int(round(b * 255))
        let ai = Int(round(a * 255))
        return String(format: "#%02X%02X%02X%02X", ri, gi, bi, ai)
    }

    static func fromHexRGBA(_ hex: String) -> Color? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexSanitized.hasPrefix("#") { hexSanitized.removeFirst() }
        guard hexSanitized.count == 8,
              let value = UInt32(hexSanitized, radix: 16) else { return nil }
        let r = Double((value & 0xFF00_0000) >> 24) / 255.0
        let g = Double((value & 0x00FF_0000) >> 16) / 255.0
        let b = Double((value & 0x0000_FF00) >> 8) / 255.0
        let a = Double(value & 0x0000_00FF) / 255.0
        #if canImport(UIKit)
        return Color(UIColor(red: r, green: g, blue: b, alpha: a))
        #else
        return Color(NSColor(red: r, green: g, blue: b, alpha: a))
        #endif
    }
}
