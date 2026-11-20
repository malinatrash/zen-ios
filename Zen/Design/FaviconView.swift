import SwiftUI
import UIKit

// Site icon cache: apple-touch-icon first, then favicon.ico from the site itself.
actor FaviconLoader {
    static let shared = FaviconLoader()
    private var cache: [String: UIImage] = [:]
    private var missing: Set<String> = []

    func image(for url: URL) async -> UIImage? {
        guard let host = url.host() else { return nil }
        if let cached = cache[host] { return cached }
        if missing.contains(host) { return nil }
        for path in ["apple-touch-icon.png", "favicon.ico"] {
            guard let source = URL(string: "https://\(host)/\(path)"),
                  let (data, response) = try? await URLSession.shared.data(from: source),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let image = UIImage(data: data)
            else { continue }
            cache[host] = image
            return image
        }
        missing.insert(host)
        return nil
    }
}

// Site icon: embedded from sync, fetched from the site, or the domain letter.
struct FaviconView: View {
    let url: URL
    var dataURL: String?
    var size: CGFloat = 28
    @State private var loaded: UIImage?

    var body: some View {
        Group {
            if let image = Self.decode(dataURL) ?? loaded {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                letter
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: size * 0.24))
        .task(id: url.host()) {
            guard Self.decode(dataURL) == nil else { return }
            loaded = await FaviconLoader.shared.image(for: url)
        }
    }

    private var letter: some View {
        let name = AddressResolver.display(url)
        return RoundedRectangle(cornerRadius: size * 0.24)
            .fill(Color(hue: Double(abs(name.hashValue) % 360) / 360, saturation: 0.45, brightness: 0.75).gradient)
            .overlay {
                Text(name.prefix(1).uppercased())
                    .font(.system(size: size * 0.55, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
    }

    static func decode(_ dataURL: String?) -> UIImage? {
        guard let dataURL, let comma = dataURL.firstIndex(of: ","), dataURL[..<comma].contains("base64"),
              let data = Data(base64Encoded: String(dataURL[dataURL.index(after: comma)...]))
        else { return nil }
        return UIImage(data: data)
    }
}

#Preview("Letter instead of icon") {
    HStack(spacing: 16) {
        FaviconView(url: URL(string: "https://mail.example.com")!)
        FaviconView(url: URL(string: "https://jira.example.com")!, size: 40)
        FaviconView(url: URL(string: "https://www.wikipedia.org")!, size: 56)
    }
    .padding()
}
