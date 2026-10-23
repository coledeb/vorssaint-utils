// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum VolumeMenuBarIndicatorTests {
    static func run(_ suite: TestSuite) {
        for available in [false, true] {
            for enabled in [false, true] {
                for replace in [false, true] {
                    let placement = VolumeMenuBarPlacement(featureAvailable: available,
                                                           enabled: enabled, replaceMain: replace)
                    let expected: VolumeMenuBarPlacement = available && enabled
                        ? (replace ? .main : .separate) : .disabled
                    suite.expect(placement == expected,
                                 "placement respects feature availability, indicator toggle and replacement choice")
                }
            }
        }

        for (volume, waves) in [(0.0, 0), (0.01, 1), (0.33, 1), (0.34, 2),
                                (0.66, 2), (0.67, 3), (1.0, 3)] {
            let state = VolumeMenuBarState(volume: volume, muted: false)
            suite.expect(state.waveCount == waves, "\(volume) displays \(waves) waves")
        }
        suite.expect(VolumeMenuBarState(volume: -1, muted: false) == .level(0), "negative volume is bounded")
        suite.expect(VolumeMenuBarState(volume: 2, muted: false) == .level(100), "volume above 100% is bounded")
        for volume in [nil, .nan, .infinity, -.infinity] as [Double?] {
            suite.expect(VolumeMenuBarState(volume: volume, muted: false) == .unavailable,
                         "missing and invalid readings are unavailable")
            suite.expect(VolumeMenuBarState(volume: volume, muted: true) == .muted,
                         "mute takes precedence over missing volume")
        }
        suite.expect(VolumeMenuBarState(volume: 1, muted: true).waveCount == 0,
                     "mute has no waves even with a saved high volume")
        suite.expect(VolumeMenuBarState(volume: 0, muted: false) != .muted,
                     "zero volume alone does not activate the red mute indicator")

        // Rasterize the production glyphs, including a Retina-size rendering.
        for scale in [1, 2] {
            for state in [.level(0), .level(33), .level(66), .level(99), .level(100), .muted, .unavailable] as [VolumeMenuBarState] {
                let image = VolumeMenuBarGlyph.image(for: state)
                suite.expect(!image.isTemplate && image.size == VolumeMenuBarGlyph.size,
                             "glyph preserves its color and fixed menu bar dimensions")
                guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                    pixelsWide: 24 * scale, pixelsHigh: 20 * scale,
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
                    let context = NSGraphicsContext(bitmapImageRep: rep) else {
                    suite.expect(false, "bitmap context is available")
                    continue
                }
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = context
                image.draw(in: NSRect(x: 0, y: 0, width: 24 * scale, height: 20 * scale))
                NSGraphicsContext.restoreGraphicsState()
                let colors = (0..<rep.pixelsHigh).flatMap { y in
                    (0..<rep.pixelsWide).compactMap { x in rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) }
                }.filter { $0.alphaComponent > 0.5 }
                suite.expect(!colors.isEmpty || state == .unavailable, "available glyph contains bright visible pixels")
                if state == .muted {
                    suite.expect((rep.colorAt(x: 3 * scale, y: 10 * scale)?.alphaComponent ?? 0) > 0.9,
                                 "muted speaker stays in the same position as the other states")
                    suite.expect(colors.allSatisfy { $0.redComponent > $0.greenComponent && $0.redComponent > $0.blueComponent },
                                 "muted speaker and cross are red")
                    suite.expect((22..<24).allSatisfy { x in
                        (0..<20).allSatisfy { y in (rep.colorAt(x: x * scale, y: y * scale)?.alphaComponent ?? 0) == 0 }
                    }, "muted glyph does not draw the outer wave")
                    suite.expect((rep.colorAt(x: 17 * scale, y: 10 * scale)?.alphaComponent ?? 0) > 0.5,
                                 "mute cross is visible beside the speaker")
                } else if state == .level(100) {
                    suite.expect(colors.allSatisfy { $0.redComponent > $0.greenComponent && $0.redComponent > $0.blueComponent },
                                 "speaker and all waves turn red at 100%")
                } else if state != .unavailable {
                    suite.expect(colors.allSatisfy { $0.redComponent > 0.95 && $0.greenComponent > 0.95 && $0.blueComponent > 0.95 },
                                 "unmuted speaker and active waves below 100% are white")
                }
            }
        }
    }
}
