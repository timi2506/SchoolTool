// Color+Codable.swift
import SwiftUI

// Codable conformance for SwiftUI.Color supporting RGBA and CGColor component fallback (including transparency).
extension Color: @retroactive Codable {
    enum CodingKeys: String, CodingKey {
        case red, green, blue, alpha
        case cgColorComponents // For fallback
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        #if os(iOS) || os(tvOS) || os(watchOS)
        // Convert Color to UIColor, then to RGBA
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        let uiColor = UIColor(self)
        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            try container.encode(Double(red), forKey: .red)
            try container.encode(Double(green), forKey: .green)
            try container.encode(Double(blue), forKey: .blue)
            try container.encode(Double(alpha), forKey: .alpha)
        } else {
            // If it's a system color or cannot get RGBA, fallback to cgColor components
            let cgColor = UIColor(self).cgColor
            let components = cgColor.components ?? []
            try container.encode(components, forKey: .cgColorComponents)
        }
        #elseif os(macOS)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        let nsColor = NSColor(self)
        if let rgbColor = nsColor.usingColorSpace(.deviceRGB) {
            rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            try container.encode(Double(red), forKey: .red)
            try container.encode(Double(green), forKey: .green)
            try container.encode(Double(blue), forKey: .blue)
            try container.encode(Double(alpha), forKey: .alpha)
        } else {
            let cgColor = NSColor(self).cgColor
            let components = cgColor.components ?? []
            try container.encode(components, forKey: .cgColorComponents)
        }
        #endif
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let red = try? container.decode(Double.self, forKey: .red),
           let green = try? container.decode(Double.self, forKey: .green),
           let blue = try? container.decode(Double.self, forKey: .blue),
           let alpha = try? container.decode(Double.self, forKey: .alpha) {
            self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
            return
        }
        if let cgComponentsDoubles = try? container.decode([Double].self, forKey: .cgColorComponents), cgComponentsDoubles.count >= 4 {
            let r = cgComponentsDoubles[0]
            let g = cgComponentsDoubles[1]
            let b = cgComponentsDoubles[2]
            let a = cgComponentsDoubles[3]
            self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
            return
        }
        // Fallback: default to blue
        self = .blue
    }
}
