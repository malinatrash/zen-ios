import Foundation

public struct RGB: Sendable, Equatable, Hashable {
    public var r: Double
    public var g: Double
    public var b: Double

    public init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    // Parses #rgb, #rrggbb and rgb(r, g, b).
    public init?(css: String) {
        let text = css.trimmingCharacters(in: .whitespaces).lowercased()
        if text.hasPrefix("#") {
            var hex = String(text.dropFirst())
            if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
            guard hex.count >= 6, let value = UInt32(hex.prefix(6), radix: 16) else { return nil }
            self.init(Double(value >> 16 & 0xFF), Double(value >> 8 & 0xFF), Double(value & 0xFF))
            return
        }
        let numbers = text.split(whereSeparator: { !"0123456789.".contains($0) }).compactMap { Double($0) }
        guard text.hasPrefix("rgb"), numbers.count >= 3 else { return nil }
        self.init(numbers[0], numbers[1], numbers[2])
    }

    var channels: [Double] { [r, g, b] }

    init(channels: [Double]) {
        self.init(channels[0], channels[1], channels[2])
    }
}

// A space theme as Zen puts it into the space record.
public struct SpaceTheme: Sendable, Equatable, Decodable {
    public var gradientColors: [GradientColor]
    public var opacity: Double
    public var texture: Double

    public struct GradientColor: Sendable, Equatable, Decodable {
        public var rgb: RGB
        public var isCustom: Bool
        public var isPrimary: Bool

        private enum CodingKeys: String, CodingKey {
            case c, isCustom, isPrimary
        }

        public init(rgb: RGB, isCustom: Bool = false, isPrimary: Bool = false) {
            self.rgb = rgb
            self.isCustom = isCustom
            self.isPrimary = isPrimary
        }

        public init(from decoder: Decoder) throws {
            let box = try decoder.container(keyedBy: CodingKeys.self)
            isCustom = try box.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
            isPrimary = try box.decodeIfPresent(Bool.self, forKey: .isPrimary) ?? false
            if let parts = try? box.decode([Double].self, forKey: .c), parts.count >= 3 {
                rgb = RGB(parts[0], parts[1], parts[2])
            } else if let css = try? box.decode(String.self, forKey: .c), let parsed = RGB(css: css) {
                rgb = parsed
            } else {
                rgb = RGB(0, 0, 0)
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case gradientColors, opacity, texture
    }

    public init(gradientColors: [GradientColor] = [], opacity: Double = 0.5, texture: Double = 0) {
        self.gradientColors = gradientColors
        self.opacity = opacity
        self.texture = texture
    }

    public init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        let colors = try box.decodeIfPresent([GradientColor?].self, forKey: .gradientColors) ?? []
        gradientColors = colors.compactMap { $0 }
        opacity = try box.decodeIfPresent(Double.self, forKey: .opacity) ?? 0.5
        texture = try box.decodeIfPresent(Double.self, forKey: .texture) ?? 0
    }

    // Builds the space background by the same rules as ZenGradientGenerator.getGradient.
    public func paint(dark: Bool) -> SpacePaint {
        let underlay = dark ? RGB(19, 19, 19) : RGB(255, 255, 255)
        let ordered = gradientColors.sorted { $0.isPrimary && !$1.isPrimary }
        guard let first = ordered.first else {
            let plain = dark ? RGB(19, 19, 19) : RGB(233, 233, 233)
            return SpacePaint(stops: [plain], overlay: nil, accent: plain)
        }
        let alpha = Self.layerAlpha(opacity: opacity)
        let painted: (GradientColor) -> RGB = { color in
            color.isCustom ? color.rgb : ColorMath.composite(color.rgb, over: underlay, alpha: alpha)
        }
        if ordered.count == 1 {
            return SpacePaint(stops: [painted(first)], overlay: nil, accent: first.rgb)
        }
        if ordered.contains(where: \.isCustom) {
            return SpacePaint(stops: gradientColors.map(painted), overlay: nil, accent: first.rgb, isDiagonal: false)
        }
        let stops = (0..<Self.stopCount).map { index -> RGB in
            let position = Double(index) / Double(Self.stopCount - 1)
            let mixed = ColorMath.mixOklab(first.rgb, ordered[1].rgb, min(1, position / Self.baseEnd))
            return ColorMath.composite(mixed, over: underlay, alpha: alpha)
        }
        let overlay = ordered.count > 2 ? ColorMath.composite(ordered[2].rgb, over: underlay, alpha: alpha) : nil
        return SpacePaint(stops: stops, overlay: overlay, accent: first.rgb)
    }

    static let stopCount = 12
    static let baseEnd = 0.75
    static let overlayMaxAlpha = 0.9

    static func layerAlpha(opacity: Double) -> Double {
        let intensity = min(1, max(0, (opacity - 0.30) / (0.8 - 0.30)))
        return 0.2 + (0.88 - 0.2) * intensity * intensity
    }
}

// Ready background colors: a single stop means a solid fill.
public struct SpacePaint: Sendable, Equatable {
    public var stops: [RGB]
    public var overlay: RGB?
    public var accent: RGB
    public var isDiagonal = true

    public var overlayMaxAlpha: Double { SpaceTheme.overlayMaxAlpha }

    // Whether the background is dark, to pick a text color on top.
    public var isDark: Bool {
        let middle = stops[stops.count / 2]
        return ColorMath.luminance(middle) < 0.4
    }
}

enum ColorMath {
    static func composite(_ color: RGB, over underlay: RGB, alpha: Double) -> RGB {
        RGB(channels: zip(color.channels, underlay.channels).map { ($0 * alpha + $1 * (1 - alpha)).rounded() })
    }

    static func mixOklab(_ from: RGB, _ to: RGB, _ t: Double) -> RGB {
        let a = oklab(from)
        let b = oklab(to)
        return rgb(oklab: zip(a, b).map { $0 + ($1 - $0) * t })
    }

    static func luminance(_ color: RGB) -> Double {
        let linear = color.channels.map { value -> Double in
            let v = value / 255
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722
    }

    static func oklab(_ color: RGB) -> [Double] {
        let lr = toLinear(color.r / 255)
        let lg = toLinear(color.g / 255)
        let lb = toLinear(color.b / 255)
        let l = cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb)
        let m = cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb)
        let s = cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb)
        return [
            0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s,
        ]
    }

    static func rgb(oklab: [Double]) -> RGB {
        let l = pow(oklab[0] + 0.3963377774 * oklab[1] + 0.2158037573 * oklab[2], 3)
        let m = pow(oklab[0] - 0.1055613458 * oklab[1] - 0.0638541728 * oklab[2], 3)
        let s = pow(oklab[0] - 0.0894841775 * oklab[1] - 1.291485548 * oklab[2], 3)
        return RGB(
            toSRGB(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
            toSRGB(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
            toSRGB(-0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s)
        )
    }

    static func toLinear(_ c: Double) -> Double {
        let a = abs(c)
        return (c < 0 ? -1 : 1) * (a <= 0.04045 ? a / 12.92 : pow((a + 0.055) / 1.055, 2.4))
    }

    static func toSRGB(_ c: Double) -> Double {
        let a = abs(c)
        let gamma = (c < 0 ? -1 : 1) * (a <= 0.0031308 ? a * 12.92 : 1.055 * pow(a, 1 / 2.4) - 0.055)
        return min(255, max(0, gamma * 255))
    }
}
