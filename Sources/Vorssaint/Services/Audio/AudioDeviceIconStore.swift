// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import Foundation

/// One override per CoreAudio UID. Input/output views of the same device share
/// a choice; disconnecting a device never deletes it. No audio state is changed.
final class AudioDeviceIconStore: ObservableObject {
    static let shared = AudioDeviceIconStore()
    @Published private(set) var symbols: [String: String]
    private let images = NSCache<NSString, NSImage>()
    private let defaults: UserDefaults
    private var changes: AnyCancellable?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        symbols = defaults.dictionary(forKey: DefaultsKey.audioDeviceIcons) as? [String: String] ?? [:]
        changes = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification, object: defaults)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let updated = defaults.dictionary(forKey: DefaultsKey.audioDeviceIcons) as? [String: String] ?? [:]
                if updated != self.symbols { self.symbols = updated }
            }
    }

    @discardableResult func setSymbol(_ symbol: String?, for uid: String) -> Bool {
        guard !uid.isEmpty else { return false }
        if let symbol, NSImage(systemSymbolName: symbol, accessibilityDescription: nil) == nil { return false }
        // Read the current preference so a restore or another writer cannot be lost.
        var updated = defaults.dictionary(forKey: DefaultsKey.audioDeviceIcons) as? [String: String] ?? [:]
        updated[uid] = symbol
        defaults.set(updated, forKey: DefaultsKey.audioDeviceIcons)
        symbols = updated
        return true
    }

    func image(uid: String, iconURL: URL? = nil, fallback: String) -> NSImage {
        if let symbol = symbols[uid], let image = cachedImage(key: "symbol:" + symbol, source: {
            NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }) { return image }
        // AirPlay is a route, even when its driver supplies a generic speaker
        // asset. A user's saved symbol above still takes precedence.
        if fallback == "airplay.audio", let image = cachedImage(key: "symbol:airplay.audio", source: {
            NSImage(systemSymbolName: "airplay.audio", accessibilityDescription: nil)
        }) { return image }
        if let iconURL, let image = cachedImage(key: "url:" + iconURL.absoluteString, source: {
            NSImage(contentsOf: iconURL)
        }) { return image }
        return cachedImage(key: "symbol:" + fallback, source: {
            NSImage(systemSymbolName: fallback, accessibilityDescription: nil)
        }) ?? cachedImage(key: "symbol:speaker.wave.2.fill", source: {
            NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: nil)
        })!
    }

    private func cachedImage(key: String, source: () -> NSImage?) -> NSImage? {
        if let image = images.object(forKey: key as NSString) { return image }
        guard let source = source() else { return nil }
        let image = AudioDeviceIconRendering.normalized(source)
        images.setObject(image, forKey: key as NSString)
        return image
    }

    static func fallback(name: String, input: Bool, headphones: Bool = false, virtual: Bool = false) -> String {
        let name = name.lowercased()
        if name.contains("airplay") { return "airplay.audio" }
        if name.contains("airpods max") { return "airpodsmax" }
        if name.contains("airpods pro") { return "airpodspro" }
        if name.contains("airpods") { return "airpods" }
        if headphones || name.contains("headphone") || name.contains("headset") { return "headphones" }
        if virtual { return "square.stack.3d.up" }
        if input { return "mic.fill" }
        if name.contains("hdmi") || name.contains("display") { return "display" }
        if name.contains("macbook") { return "laptopcomputer" }
        return "speaker.wave.2.fill"
    }
}

/// The small audio palette is always available. The optional expanded catalog
/// comes only from the installed OS; no symbol catalog is bundled with the app.
enum AudioDeviceSymbolCatalog {
    static let curated = [
        "speaker.wave.2.fill", "hifispeaker", "hifispeaker.fill", "hifispeaker.2.fill",
        "homepod", "homepodmini", "headphones", "beats.headphones", "headset",
        "earbuds", "earbuds.case", "airpods", "airpodspro", "airpodsmax",
        "mic", "mic.fill", "mic.circle", "music.mic", "laptopcomputer",
        "desktopcomputer", "macmini", "macpro.gen3", "display", "tv",
        "hifispeaker.and.homepod", "square.stack.3d.up", "waveform", "cable.connector", "airplay.audio"
    ]

    static func names(catalogURL: URL = URL(fileURLWithPath:
        "/System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources/name_availability.plist")) -> [String] {
        guard let data = try? Data(contentsOf: catalogURL),
              let catalog = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let names = catalog["symbols"] as? [String: Any] else { return [] }
        return names.keys.sorted()
    }
}

/// Driver icons and SF Symbols have different intrinsic margins. Normalize
/// the visible alpha bounds once, rather than shrinking padded symbol canvases.
enum AudioDeviceIconRendering {
    static func raster(_ image: NSImage) -> NSBitmapImageRep? {
        let pixels = 64
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: pixels * 4, bitsPerPixel: 32),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        context.cgContext.clear(CGRect(x: 0, y: 0, width: 64, height: 64))
        let scale = CGFloat(pixels) / max(1, max(image.size.width, image.size.height))
        let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        image.draw(in: NSRect(x: (64 - size.width) / 2, y: (64 - size.height) / 2,
                              width: size.width, height: size.height))
        return bitmap
    }

    static func visibleBounds(_ bitmap: NSBitmapImageRep) -> CGRect? {
        guard let data = bitmap.bitmapData else { return nil }
        var minX = bitmap.pixelsWide, minY = bitmap.pixelsHigh, maxX = -1, maxY = -1
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide where data[y * bitmap.bytesPerRow + x * 4 + 3] > 8 {
                minX = min(minX, x); minY = min(minY, y)
                maxX = max(maxX, x); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    static func normalized(_ source: NSImage) -> NSImage {
        guard let bitmap = raster(source), let bounds = visibleBounds(bitmap),
              let cropped = bitmap.cgImage?.cropping(to: bounds) else { return source }
        let artwork = NSImage(cgImage: cropped, size: bounds.size)
        let scale = 16 / max(bounds.width, bounds.height)
        let size = NSSize(width: bounds.width * scale, height: bounds.height * scale)
        let result = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { _ in
            artwork.draw(in: NSRect(x: (16 - size.width) / 2, y: (16 - size.height) / 2,
                                   width: size.width, height: size.height))
            return true
        }
        result.isTemplate = source.isTemplate
        return result
    }
}
